import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import type { RouterRequest, RouterResponse, AIProviderResult } from "../_shared/types.ts";
import { TextEngine } from "./engines/textEngine.ts";
import { ImageEngine } from "./engines/imageEngine.ts";
import { ModerationService } from "./moderation.ts";

const textEngine = new TextEngine();
const imageEngine = new ImageEngine();
const moderation = new ModerationService();

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";

  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(JSON.stringify({ error: "Configuración interna de backend incompleta" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // 1. Validar autenticación de usuario
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Encabezado de autorización ausente" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Sesión inválida o expirada" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Extraer cuerpo de la solicitud
    const body: RouterRequest = await req.json();
    const { tool, input, parameters = {} } = body;

    if (!tool || !input) {
      return new Response(JSON.stringify({ error: "Parámetros requeridos: tool e input" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Consultar herramienta en la tabla tools
    const { data: toolRecord, error: toolErr } = await adminClient
      .from("tools")
      .select("id, enabled, credit_cost, beta")
      .eq("id", tool)
      .single();

    if (toolErr || !toolRecord || !toolRecord.enabled) {
      return new Response(JSON.stringify({ error: "La herramienta solicitada no está disponible actualmente." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Validar límites de entrada en el backend
    const rawText = input.text || input.prompt || input.product_service || input.topic_product || "";
    if (rawText.length > 10000) {
      return new Response(JSON.stringify({ error: "El contenido excede el límite máximo de 10,000 caracteres." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const creditCost = toolRecord.credit_cost;

    // 5. Cobro atómico de créditos antes de llamar a la IA (service_role)
    const { data: deductResult, error: deductErr } = await adminClient.rpc("deduct_credits", {
      p_user_id: user.id,
      p_amount: creditCost,
      p_tool_id: tool,
      p_description: `Ejecución de herramienta: ${tool}`,
    });

    if (deductErr || !deductResult?.success) {
      return new Response(JSON.stringify({
        error: "insufficient_credits",
        message: "No tienes saldo suficiente de créditos para esta operación.",
        required: creditCost,
        balance: deductResult?.balance || 0,
      }), {
        status: 402,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 6. Moderación preventiva de contenido
    const modCheck = await moderation.checkInput(input);
    if (!modCheck.allowed) {
      // Reembolso inmediato si no pasa moderación
      await adminClient.rpc("refund_credits", {
        p_user_id: user.id,
        p_amount: creditCost,
        p_tool_id: tool,
        p_reason: "Reembolso por rechazo en filtro de moderación",
      });

      await adminClient.from("generations").insert({
        user_id: user.id,
        tool_id: tool,
        provider: "moderation",
        model: "internal-filter",
        credits_used: 0,
        estimated_api_cost: 0,
        status: "failed",
        error_code: "MODERATION_REJECTED",
        processing_time_ms: Date.now() - startTime,
        completed_at: new Date().toISOString(),
      });

      return new Response(JSON.stringify({ error: modCheck.reason }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 7. Enrutador de ejecución para las 10 herramientas
    let aiResult: AIProviderResult;

    try {
      switch (tool) {
        // --- ETAPA 1: TEXTO ---
        case "rewrite_text":
          aiResult = await textEngine.rewriteText({
            text: input.text || "",
            tone: input.tone,
          });
          break;

        case "translate_text":
          aiResult = await textEngine.translateText({
            text: input.text || "",
            sourceLanguage: input.source_language,
            targetLanguage: input.target_language,
          });
          break;

        case "summarize_text":
          aiResult = await textEngine.summarizeText({
            text: input.text || "",
            length: input.length,
          });
          break;

        // --- ETAPA 2: MARKETING ---
        case "create_ad":
          aiResult = await textEngine.createAd({
            productService: input.product_service || input.text || "",
            targetAudience: input.target_audience,
            mainBenefit: input.main_benefit,
            tone: input.tone,
            platform: input.platform,
          });
          break;

        case "social_post":
          aiResult = await textEngine.createSocialPost({
            topicProduct: input.topic_product || input.text || "",
            platform: input.platform,
            tone: input.tone,
            goal: input.goal,
          });
          break;

        case "product_description":
          aiResult = await textEngine.createProductDescription({
            name: input.name || input.product_name || input.text || "",
            features: input.features,
            benefits: input.benefits,
            audience: input.audience || input.target_audience,
            tone: input.tone,
          });
          break;

        // --- ETAPA 3: GENERACIÓN DE IMAGEN CON PERSISTENCIA EN STORAGE ---
        case "generate_image":
          aiResult = await imageEngine.generateImage({
            prompt: input.prompt || input.text || "",
            style: input.style,
            userId: user.id,
            adminClient,
          });
          break;

        // --- ETAPA 4: EDICIÓN REAL DE IMAGEN CON PERSISTENCIA EN STORAGE ---
        case "improve_image":
          aiResult = await imageEngine.improveImage({
            imageUrl: input.image_url || input.image || "",
            factor: input.factor ? Number(input.factor) : 2,
            userId: user.id,
            adminClient,
          });
          break;

        case "remove_background":
          aiResult = await imageEngine.removeBackground({
            imageUrl: input.image_url || input.image || "",
            userId: user.id,
            adminClient,
          });
          break;

        case "change_background":
          aiResult = await imageEngine.changeBackground({
            imageUrl: input.image_url || input.image || "",
            backgroundDescription: input.background_description || input.prompt || input.text || "",
            userId: user.id,
            adminClient,
          });
          break;

        default:
          throw new Error(`Herramienta no reconocida en el enrutador: ${tool}`);
      }
    } catch (engineError: any) {
      // Reembolso automático si el proveedor de IA o procesamiento falla
      await adminClient.rpc("refund_credits", {
        p_user_id: user.id,
        p_amount: creditCost,
        p_tool_id: tool,
        p_reason: "Reembolso por fallo en procesamiento de IA",
      });

      // Registrar fallo en tabla generations
      await adminClient.from("generations").insert({
        user_id: user.id,
        tool_id: tool,
        provider: "unknown",
        model: "unknown",
        credits_used: 0,
        estimated_api_cost: 0,
        status: "failed",
        error_code: engineError.message || "ENGINE_ERROR",
        processing_time_ms: Date.now() - startTime,
        completed_at: new Date().toISOString(),
      });

      return new Response(JSON.stringify({
        error: engineError.message || "Hubo una interrupción temporal con el proveedor de IA. Tus créditos han sido reembolsados automáticamente.",
      }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 8. Registro exitoso en tabla generations
    const processingTime = Date.now() - startTime;
    const isImageTool = tool.includes("image") || tool.includes("background");
    const resultUrl = isImageTool ? (aiResult.data?.image_url || null) : null;
    const storagePath = isImageTool ? (aiResult.data?.storage_path || null) : null;

    await adminClient.from("generations").insert({
      user_id: user.id,
      tool_id: tool,
      provider: aiResult.provider,
      model: aiResult.model,
      credits_used: creditCost,
      estimated_api_cost: aiResult.estimatedApiCost,
      status: "completed",
      input_type: isImageTool ? "image" : "text",
      result_url: resultUrl,
      storage_path: storagePath,
      metadata: isImageTool ? { format: aiResult.data?.format, original_url: aiResult.data?.original_url } : {},
      processing_time_ms: processingTime,
      completed_at: new Date().toISOString(),
    });

    const responsePayload: RouterResponse = {
      success: true,
      tool,
      result: aiResult.data,
      credits_used: creditCost,
      credits_remaining: deductResult.new_balance,
      processing_time_ms: processingTime,
      provider: aiResult.provider,
      model: aiResult.model,
    };

    return new Response(JSON.stringify(responsePayload), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: "Error interno del servidor" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
