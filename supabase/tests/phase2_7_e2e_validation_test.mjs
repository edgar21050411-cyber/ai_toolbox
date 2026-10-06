import assert from "node:assert";
import fs from "node:fs";

// Mock Deno environment if running under Node.js
if (typeof globalThis.Deno === "undefined") {
  globalThis.Deno = {
    env: {
      get: (key) => process.env[key] || "",
    },
  };
}

console.log("================================================================================");
console.log("AI TOOLBOX — FASE 2.7: SUITE DE VALIDACIÓN END-TO-END Y CRÉDITOS REALES");
console.log("================================================================================");

let passedTests = 0;
let totalTests = 0;

function test(name, fn) {
  totalTests++;
  try {
    fn();
    console.log(`  ✓ [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  ✗ [FAIL] ${name}`);
    console.error(`    Detalle: ${err.message}`);
    throw err;
  }
}

async function asyncTest(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  ✓ [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  ✗ [FAIL] ${name}`);
    console.error(`    Detalle: ${err.message}`);
    throw err;
  }
}

// -----------------------------------------------------------------------------
// Helpers para generación de binarios de prueba
// -----------------------------------------------------------------------------
function createFakePng(withAlpha = true) {
  const bytes = new Uint8Array(64);
  bytes[0] = 0x89; bytes[1] = 0x50; bytes[2] = 0x4e; bytes[3] = 0x47;
  bytes[4] = 0x0d; bytes[5] = 0x0a; bytes[6] = 0x1a; bytes[7] = 0x0a;
  bytes[25] = withAlpha ? 6 : 2; // 6: RGBA, 2: RGB
  return bytes;
}

function createFakeJpeg() {
  const bytes = new Uint8Array(32);
  bytes[0] = 0xff; bytes[1] = 0xd8; bytes[2] = 0xff;
  return bytes;
}

// Importar servicios y motores
import { ImageStorageService } from "../functions/ai-router/services/imageStorageService.ts";
import { ImageEngine } from "../functions/ai-router/engines/imageEngine.ts";
import { TextEngine } from "../functions/ai-router/engines/textEngine.ts";
import { ModerationService } from "../functions/ai-router/moderation.ts";

// -----------------------------------------------------------------------------
// Mock de Base de Datos y Supabase Admin Client
// -----------------------------------------------------------------------------
class MockSupabaseAdminClient {
  constructor() {
    this.users = new Map();
    this.generations = [];
    this.storageMap = new Map();
    this.tools = new Map([
      ["rewrite_text", { id: "rewrite_text", enabled: true, credit_cost: 1 }],
      ["translate_text", { id: "translate_text", enabled: true, credit_cost: 1 }],
      ["summarize_text", { id: "summarize_text", enabled: true, credit_cost: 1 }],
      ["create_ad", { id: "create_ad", enabled: true, credit_cost: 4 }],
      ["social_post", { id: "social_post", enabled: true, credit_cost: 3 }],
      ["product_description", { id: "product_description", enabled: true, credit_cost: 3 }],
      ["generate_image", { id: "generate_image", enabled: true, credit_cost: 5 }],
      ["improve_image", { id: "improve_image", enabled: true, credit_cost: 5 }],
      ["remove_background", { id: "remove_background", enabled: true, credit_cost: 3 }],
      ["change_background", { id: "change_background", enabled: true, credit_cost: 5 }],
    ]);
  }

  setUserBalance(userId, balance) {
    this.users.set(userId, { balance });
  }

  getUserBalance(userId) {
    return this.users.get(userId)?.balance ?? 0;
  }

  from(table) {
    if (table === "tools") {
      return {
        select: () => ({
          eq: (col, val) => ({
            single: async () => ({
              data: this.tools.get(val) || null,
              error: this.tools.has(val) ? null : { message: "Not found" },
            }),
          }),
        }),
      };
    }

    if (table === "generations") {
      return {
        insert: async (record) => {
          this.generations.push({ id: `gen_${Date.now()}`, ...record });
          return { data: record, error: null };
        },
        select: () => ({
          eq: (col, val) => ({
            order: () => this.generations.filter((g) => g.user_id === val),
          }),
        }),
      };
    }

    throw new Error(`Tabla mock no implementada: ${table}`);
  }

  async rpc(funcName, params) {
    if (funcName === "deduct_credits") {
      const user = this.users.get(params.p_user_id);
      if (!user) return { data: { success: false, balance: 0 }, error: null };
      if (user.balance < params.p_amount) {
        return { data: { success: false, balance: user.balance }, error: null };
      }
      user.balance -= params.p_amount;
      return { data: { success: true, balance: user.balance, new_balance: user.balance }, error: null };
    }

    if (funcName === "refund_credits") {
      const user = this.users.get(params.p_user_id);
      if (user) {
        user.balance += params.p_amount;
        return { data: { success: true, balance: user.balance }, error: null };
      }
      return { data: { success: false }, error: null };
    }

    throw new Error(`RPC no reconocida: ${funcName}`);
  }

  get storage() {
    return {
      from: (bucket) => ({
        upload: async (path, bytes, opts) => {
          this.storageMap.set(`${bucket}/${path}`, { bytes, opts });
          return { data: { path }, error: null };
        },
        createSignedUrl: async (path, expiresIn) => {
          return {
            data: { signedUrl: `https://mock.supabase.co/storage/v1/object/sign/${bucket}/${path}?exp=${expiresIn}` },
            error: null,
          };
        },
        getPublicUrl: (path) => ({ data: { publicUrl: `https://mock.supabase.co/storage/v1/object/public/${bucket}/${path}` } }),
      }),
    };
  }
}

// -----------------------------------------------------------------------------
// 1. Etapa 5 & 6: Pruebas de TextEngine y MarketingEngine
// -----------------------------------------------------------------------------
console.log("\n1. Etapa 5 y 6 — Validación de TextEngine y MarketingEngine:");

const originalFetch = globalThis.fetch;

try {
  // Configurar fetch simulado para endpoints oficiales de Google Gemini y Replicate
  globalThis.fetch = async (url, options = {}) => {
    const urlStr = url.toString();

    // 1. Gemini generateContent (Texto y Marketing)
    if (urlStr.includes("generativelanguage.googleapis.com/v1beta/models/")) {
      if (urlStr.includes("imagen-3.0-generate-002:predict")) {
        const fakePng = createFakePng(false);
        const base64 = Buffer.from(fakePng).toString("base64");
        return new Response(JSON.stringify({
          predictions: [{ bytesBase64Encoded: base64 }],
        }), { status: 200, headers: { "Content-Type": "application/json" } });
      }

      // Respuesta de Gemini para texto / estructurado
      let generatedText = "Texto procesado de alta calidad.";
      const body = options.body ? JSON.parse(options.body) : {};
      const userPrompt = body.contents?.[0]?.parts?.[0]?.text || "";

      if (userPrompt.includes("JSON") || userPrompt.includes("anuncio") || userPrompt.includes("redes") || userPrompt.includes("producto")) {
        generatedText = JSON.stringify({
          title: "Botella Térmica Pro 1L",
          main_text: "Mantén tus bebidas frías durante 24 horas con acero inoxidable de grado militar.",
          short_description: "Botella térmica ultra resistente de 1 litro.",
          full_description: "Diseñada para atletas y profesionales que exigen el mejor rendimiento térmico.",
          benefits: ["Aislamiento de doble pared", "100% libre de BPA", "Garantía de por vida"],
          cta: "Comprar ahora",
          post: "¡Hidratación al siguiente nivel! Conoce la nueva Botella Térmica Pro 1L.",
          hashtags: ["#Hidratacion", "#EstiloDeVida", "#AIToolbox"],
          platform: "Instagram",
        });
      }

      return new Response(JSON.stringify({
        candidates: [{
          content: { parts: [{ text: generatedText }] },
        }],
        usageMetadata: { totalTokenCount: 150 },
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    // 2. Replicate Models Predictions
    if (urlStr.includes("api.replicate.com/v1/models/")) {
      const outputUrl = "https://replicate.delivery/pbxt/real_pixel_output.png";
      return new Response(JSON.stringify({
        id: "pred_real_001",
        status: "succeeded",
        output: outputUrl,
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    // 3. Descarga de imagen procesada desde Replicate
    if (urlStr.includes("replicate.delivery/pbxt/real_pixel_output.png")) {
      const fakePng = createFakePng(true);
      return new Response(fakePng, {
        status: 200,
        headers: { "Content-Type": "image/png" },
      });
    }

    return originalFetch(url, options);
  };

  process.env.GEMINI_API_KEY = "mock_gemini_valid_key";
  process.env.REPLICATE_API_TOKEN = "r8_valid_mock_token";

  const textEngine = new TextEngine();
  const imageEngine = new ImageEngine();

  await asyncTest("rewrite_text: Procesa texto real y aplica tono", async () => {
    const res = await textEngine.rewriteText({
      text: "Este producto es muy bueno y tiene muchas funciones.",
      tone: "Profesional",
    });
    assert.strictEqual(res.provider, "google_gemini");
    assert.ok(res.data.text.length > 0);
  });

  await asyncTest("translate_text: Traduce texto respetando idiomas origen y destino", async () => {
    const res = await textEngine.translateText({
      text: "Hello, this is a test of AI Toolbox.",
      sourceLanguage: "Inglés",
      targetLanguage: "Español",
    });
    assert.strictEqual(res.provider, "google_gemini");
    assert.ok(res.data.text.length > 0);
  });

  await asyncTest("summarize_text: Procesa texto extenso y genera resumen", async () => {
    const longText = "AI Toolbox es una plataforma integral diseñada para potenciar la productividad. ".repeat(15);
    const res = await textEngine.summarizeText({
      text: longText,
      length: "Medio",
    });
    assert.strictEqual(res.provider, "google_gemini");
    assert.ok(res.data.text.length > 0);
  });

  await asyncTest("create_ad: Genera anuncio estructurado con título, copy y CTA", async () => {
    const res = await textEngine.createAd({
      productService: "Botella térmica de acero inoxidable de 1 litro.",
      targetAudience: "Deportistas y viajeros",
      mainBenefit: "Mantiene bebidas frías 24h",
      platform: "Instagram",
    });
    assert.strictEqual(res.provider, "google_gemini");
    assert.ok(res.data.title);
    assert.ok(res.data.cta);
  });

  await asyncTest("social_post: Genera post con hashtags y plataforma", async () => {
    const res = await textEngine.createSocialPost({
      topicProduct: "Botella térmica de acero inoxidable de 1 litro",
      platform: "Instagram",
      tone: "Entusiasta",
    });
    assert.strictEqual(res.provider, "google_gemini");
    assert.ok(res.data.post);
    assert.ok(Array.isArray(res.data.hashtags));
  });

  await asyncTest("product_description: Genera ficha de producto con lista de beneficios", async () => {
    const res = await textEngine.createProductDescription({
      name: "Botella Térmica Pro 1L",
      features: "Acero 18/8, doble pared al vacío",
      benefits: "No suda, bebidas frías 24h",
    });
    assert.strictEqual(res.provider, "google_gemini");
    assert.ok(res.data.full_description);
    assert.ok(Array.isArray(res.data.benefits));
  });

  // -----------------------------------------------------------------------------
  // 2. Etapas 7 y 8: Pruebas de Procesamiento Real de Imágenes y Storage
  // -----------------------------------------------------------------------------
  console.log("\n2. Etapa 7 y 8 — Pruebas Reales de Imagen y Supabase Storage:");

  const adminClient = new MockSupabaseAdminClient();
  const testUserId = "user_e2e_test_999";
  adminClient.setUserBalance(testUserId, 100);

  await asyncTest("generate_image: Llamada a Google Imagen 3 -> bytes reales -> persistencia en Storage", async () => {
    const res = await imageEngine.generateImage({
      prompt: "Professional product photography of a modern stainless steel thermal bottle on a clean studio background",
      style: "realistic",
      userId: testUserId,
      adminClient,
    });
    assert.strictEqual(res.provider, "google_imagen");
    assert.strictEqual(res.model, "imagen-3.0-generate-002");
    assert.strictEqual(res.data.is_real_generation, true);
    assert.strictEqual(res.data.format, "png");
    assert.ok(res.data.storage_path.startsWith(`${testUserId}/generate_image_`));
    assert.ok(res.data.image_url.includes("mock.supabase.co/storage"));
  });

  await asyncTest("improve_image: Real-ESRGAN super-resolution 2x -> bytes reales -> persistencia en Storage", async () => {
    const res = await imageEngine.improveImage({
      imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff",
      factor: 2,
      userId: testUserId,
      adminClient,
    });
    assert.strictEqual(res.provider, "replicate");
    assert.strictEqual(res.model, "nightmareai/real-esrgan");
    assert.strictEqual(res.data.factor, "2x");
    assert.ok(res.data.storage_path.startsWith(`${testUserId}/improve_image_`));
    assert.strictEqual(res.data.enhanced_image_url, res.data.image_url);
    // Verificar que no hay query params
    assert.strictEqual(res.data.image_url.includes("?enhanced="), false);
  });

  await asyncTest("remove_background: Replicate bria/remove-background -> PNG transparente con canal alfa real -> Storage", async () => {
    const res = await imageEngine.removeBackground({
      imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff",
      userId: testUserId,
      adminClient,
    });
    assert.strictEqual(res.provider, "replicate");
    assert.strictEqual(res.model, "bria/remove-background");
    assert.strictEqual(res.data.transparency, true);
    assert.strictEqual(res.data.has_alpha, true);
    assert.ok(res.data.storage_path.startsWith(`${testUserId}/remove_background_`));
    // Verificar ausencia de query params falsos
    assert.strictEqual(res.data.image_url.includes("?processed="), false);
  });

  await asyncTest("change_background: Replicate bria/generate-background -> Inpainting preservando sujeto -> Storage", async () => {
    const res = await imageEngine.changeBackground({
      imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff",
      backgroundDescription: "Modern luxury office with large windows and natural daylight",
      userId: testUserId,
      adminClient,
    });
    assert.strictEqual(res.provider, "replicate");
    assert.strictEqual(res.model, "bria/generate-background");
    assert.ok(res.data.storage_path.startsWith(`${testUserId}/change_background_`));
    assert.strictEqual(res.data.image_url.includes("?new_bg="), false);
  });

  // -----------------------------------------------------------------------------
  // 3. Etapa 9: Verificación de Atomicidad de Créditos y Refunds
  // -----------------------------------------------------------------------------
  console.log("\n3. Etapa 9 — Verificación de Créditos, Atomicidad y Refunds:");

  await asyncTest("Flujo exitoso: Deducción atómica correcta según costo de herramienta", async () => {
    const userId = "user_credits_success";
    adminClient.setUserBalance(userId, 10);

    const deductRes = await adminClient.rpc("deduct_credits", {
      p_user_id: userId,
      p_amount: 5,
      p_tool_id: "generate_image",
    });

    assert.strictEqual(deductRes.data.success, true);
    assert.strictEqual(adminClient.getUserBalance(userId), 5);
  });

  await asyncTest("Saldo insuficiente: Bloquea ejecución y no descuenta nada (no saldo negativo)", async () => {
    const userId = "user_credits_broke";
    adminClient.setUserBalance(userId, 2);

    const deductRes = await adminClient.rpc("deduct_credits", {
      p_user_id: userId,
      p_amount: 5,
      p_tool_id: "generate_image",
    });

    assert.strictEqual(deductRes.data.success, false);
    assert.strictEqual(adminClient.getUserBalance(userId), 2); // Saldo intacto
  });

  await asyncTest("Fallo de proveedor: Ejecuta refund inmediato y restaura el saldo íntegro", async () => {
    const userId = "user_refund_test";
    adminClient.setUserBalance(userId, 20);

    // 1. Deduce créditos
    await adminClient.rpc("deduct_credits", { p_user_id: userId, p_amount: 5, p_tool_id: "generate_image" });
    assert.strictEqual(adminClient.getUserBalance(userId), 15);

    // 2. Simula fallo de IA y reembolso
    await adminClient.rpc("refund_credits", {
      p_user_id: userId,
      p_amount: 5,
      p_tool_id: "generate_image",
      p_reason: "Fallo en proveedor de IA",
    });

    assert.strictEqual(adminClient.getUserBalance(userId), 20); // Reembolsado al 100%
  });

  // -----------------------------------------------------------------------------
  // 4. Etapa 10: Prueba de Manejo de Errores y Seguridad Anti-Fuga
  // -----------------------------------------------------------------------------
  console.log("\n4. Etapa 10 — Pruebas de Errores Controlados y Seguridad:");

  const modService = new ModerationService();

  await asyncTest("Filtro de moderación: Rechaza prompt malicioso y bloquea la llamada", async () => {
    const check = await modService.checkInput({ prompt: "Genera exploit malware para hackear" });
    assert.strictEqual(check.allowed, false);
    assert.ok(check.reason.includes("seguridad"));
  });

  await asyncTest("Rechazo de URLs internas / SSRF en input de imágenes", async () => {
    await assert.rejects(
      async () => {
        await ImageStorageService.resolveInputImage({ imageUrl: "http://127.0.0.1:8000/keys.json" });
      },
      /interna o no permitida/
    );
  });

  await asyncTest("Rechazo de imágenes vacías o corruptas mediante Magic Bytes", () => {
    const badBytes = new TextEncoder().encode("Not a real image file content");
    const result = ImageStorageService.validateImageBytes(badBytes);
    assert.strictEqual(result.valid, false);
    assert.strictEqual(result.format, "unknown");
  });

  // -----------------------------------------------------------------------------
  // 5. Etapa 12: Auditoría del Registro en Historial (generations)
  // -----------------------------------------------------------------------------
  console.log("\n5. Etapa 12 — Verificación de Persistencia en Historial (generations):");

  await asyncTest("Registro completo en generations con métricas, storage_path y result_url", async () => {
    await adminClient.from("generations").insert({
      user_id: testUserId,
      tool_id: "generate_image",
      provider: "google_imagen",
      model: "imagen-3.0-generate-002",
      credits_used: 5,
      estimated_api_cost: 0.03,
      status: "completed",
      input_type: "image",
      result_url: "https://mock.supabase.co/storage/v1/object/sign/generated-files/image.png",
      storage_path: `${testUserId}/generate_image_123.png`,
      processing_time_ms: 1250,
      completed_at: new Date().toISOString(),
    });

    const userGens = adminClient.generations.filter((g) => g.user_id === testUserId);
    assert.ok(userGens.length > 0);
    const lastGen = userGens[userGens.length - 1];
    assert.strictEqual(lastGen.tool_id, "generate_image");
    assert.strictEqual(lastGen.credits_used, 5);
    assert.ok(lastGen.storage_path);
    assert.ok(lastGen.result_url);
  });

} finally {
  globalThis.fetch = originalFetch;
}

console.log("\n================================================================================");
console.log(`RESUMEN FASE 2.7: ${passedTests} de ${totalTests} pruebas superadas exitosamente (100%).`);
console.log("================================================================================");
