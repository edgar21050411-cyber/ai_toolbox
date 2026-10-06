import { GeminiAdapter } from "../adapters/gemini.ts";
import { OpenAIAdapter } from "../adapters/openai.ts";
import type { AIProviderResult } from "../../_shared/types.ts";

export class TextEngine {
  private gemini: GeminiAdapter;
  private openai: OpenAIAdapter;

  constructor() {
    this.gemini = new GeminiAdapter();
    this.openai = new OpenAIAdapter();
  }

  /**
   * Ejecuta con fallback selectivo y seguro.
   * Conmuta a OpenAI Ãºnicamente en fallos de infraestructura (5xx, timeout, 429).
   */
  private async executeWithFallback(
    prompt: string,
    systemInstruction?: string,
    preferEconomic = true
  ): Promise<AIProviderResult> {
    try {
      const model = preferEconomic ? "gemini-1.5-flash" : "gemini-1.5-pro";
      return await this.gemini.generateText(prompt, systemInstruction, model);
    } catch (primaryErr: any) {
      const errMsg = (primaryErr?.message || "").toLowerCase();

      const isContentOrUserError =
        errMsg.includes("safety") ||
        errMsg.includes("blocked") ||
        errMsg.includes("harm") ||
        errMsg.includes("invalid") ||
        errMsg.includes("bad request") ||
        errMsg.includes("400");

      if (isContentOrUserError) {
        throw primaryErr;
      }

      console.warn("Primary provider (Gemini) failed with server error. Falling back to OpenAI...", primaryErr);

      try {
        return await this.openai.generateText(prompt, systemInstruction, "gpt-4o-mini");
      } catch (fallbackErr: any) {
        throw new Error(`Ambos proveedores fallaron: Primary: ${primaryErr.message} | Fallback: ${fallbackErr.message}`);
      }
    }
  }

  private async executeStructuredJson(
    prompt: string,
    systemInstruction?: string,
    model = "gemini-1.5-flash"
  ): Promise<AIProviderResult> {
    try {
      return await this.gemini.generateStructuredJson(prompt, systemInstruction, model);
    } catch (primaryErr: any) {
      const errMsg = (primaryErr?.message || "").toLowerCase();
      if (errMsg.includes("safety") || errMsg.includes("blocked") || errMsg.includes("400")) {
        throw primaryErr;
      }
      // Fallback a OpenAI con formateo JSON
      const res = await this.openai.generateText(
        `${prompt}\n\nIMPORTANTE: Responde ÃšNICAMENTE en formato JSON vÃ¡lido.`,
        systemInstruction,
        "gpt-4o-mini"
      );
      let parsed = {};
      try {
        parsed = JSON.parse(res.data.text);
      } catch {
        parsed = { text: res.data.text };
      }
      return {
        data: parsed,
        provider: res.provider,
        model: res.model,
        estimatedApiCost: res.estimatedApiCost,
        tokensUsed: res.tokensUsed,
      };
    }
  }

  // ----------------------------------------------------------------------------
  // ETAPA 1: HERRAMIENTAS DE TEXTO
  // ----------------------------------------------------------------------------

  /**
   * 1. Reescribir texto
   */
  async rewriteText(params: { text: string; tone?: string }): Promise<AIProviderResult> {
    if (!params.text || params.text.trim().length === 0) {
      throw new Error("El texto a reescribir no puede estar vacÃ­o.");
    }
    const tone = params.tone || "Profesional";
    const prompt = `Reescribe el siguiente texto con un tono ${tone}. Conserva el significado original pero optimiza la claridad, redacciÃ³n y estilo:\n\n"${params.text}"`;
    const sys = `Eres un asistente de redacciÃ³n experto. Devuelve Ãºnicamente el texto reescrito, sin introducciones ni comentarios adicionales.`;
    return this.executeWithFallback(prompt, sys, true);
  }

  /**
   * 2. Traducir texto
   */
  async translateText(params: {
    text: string;
    sourceLanguage?: string;
    targetLanguage?: string;
  }): Promise<AIProviderResult> {
    if (!params.text || params.text.trim().length === 0) {
      throw new Error("El texto a traducir no puede estar vacÃ­o.");
    }
    const source = params.sourceLanguage || "detecciÃ³n automÃ¡tica";
    const target = params.targetLanguage || "InglÃ©s";

    const prompt = `Traduce el siguiente texto desde ${source} hacia ${target}. AsegÃºrate de mantener la naturalidad idiomÃ¡tica y el contexto cultural:\n\n"${params.text}"`;
    const sys = `Eres un traductor profesional multilingÃ¼e de alta precisiÃ³n. Devuelve Ãºnicamente la traducciÃ³n exacta, sin aÃ±adir notas ni texto explicativo.`;
    return this.executeWithFallback(prompt, sys, true);
  }

  /**
   * 3. Resumir texto
   */
  async summarizeText(params: { text: string; length?: string }): Promise<AIProviderResult> {
    if (!params.text || params.text.trim().length === 0) {
      throw new Error("El texto a resumir no puede estar vacÃ­o.");
    }
    const length = params.length || "Medio";
    const instructionsByLength: Record<string, string> = {
      Corto: "un resumen ultracompacto en 1 a 2 oraciones clave",
      Medio: "un resumen equilibrado de 1 pÃ¡rrafo y viÃ±etas con las ideas principales",
      Detallado: "un resumen estructurado y exhaustivo con desglose de puntos clave",
    };

    const requirement = instructionsByLength[length] || instructionsByLength["Medio"];
    const prompt = `Genera ${requirement} a partir del siguiente texto:\n\n"${params.text}"`;
    const sys = `Eres un analista de informaciÃ³n de primer nivel. Condensa la informaciÃ³n manteniendo la mÃ¡xima fidelidad a los hechos esenciales.`;
    return this.executeWithFallback(prompt, sys, true);
  }

  // ----------------------------------------------------------------------------
  // ETAPA 2: HERRAMIENTAS DE MARKETING
  // ----------------------------------------------------------------------------

  /**
   * 4. Crear anuncio
   */
  async createAd(params: {
    productService: string;
    targetAudience?: string;
    mainBenefit?: string;
    tone?: string;
    platform?: string;
  }): Promise<AIProviderResult> {
    if (!params.productService || params.productService.trim().length === 0) {
      throw new Error("El nombre o descripciÃ³n del producto/servicio es requerido.");
    }
    const platform = params.platform || "Instagram";
    const prompt = `
DiseÃ±a una pieza publicitaria de alta conversiÃ³n para la plataforma ${platform}.
Detalles:
- Producto / Servicio: ${params.productService}
- PÃºblico objetivo: ${params.targetAudience || "PÃºblico interesado"}
- Beneficio principal: ${params.mainBenefit || "Calidad y valor superior"}
- Tono: ${params.tone || "Persuasivo y directo"}

Responde ÃšNICAMENTE en JSON con esta estructura exacta:
{
  "title": "Titular impactante de menos de 60 caracteres",
  "main_text": "Texto principal del anuncio optimizado para ${platform}",
  "cta": "Llamado a la acciÃ³n claro y persuasivo",
  "platform": "${platform}"
}
`;
    const sys = `Eres un copywriter senior especializado en marketing digital de alto rendimiento.`;
    return this.executeStructuredJson(prompt, sys, "gemini-1.5-flash");
  }

  /**
   * 5. Crear publicaciÃ³n para redes
   */
  async createSocialPost(params: {
    topicProduct: string;
    platform?: string;
    tone?: string;
    goal?: string;
  }): Promise<AIProviderResult> {
    if (!params.topicProduct || params.topicProduct.trim().length === 0) {
      throw new Error("El tema o producto de la publicaciÃ³n es requerido.");
    }
    const platform = params.platform || "Instagram";
    const prompt = `
Crea una publicaciÃ³n para redes sociales para ${platform}.
Detalles:
- Tema / Producto: ${params.topicProduct}
- Tono: ${params.tone || "Cercano y dinÃ¡mico"}
- Objetivo: ${params.goal || "Generar interacciÃ³n y engagement"}

Responde ÃšNICAMENTE en JSON con esta estructura exacta:
{
  "post": "Cuerpo completo de la publicaciÃ³n con formato y emojis adecuados para ${platform}",
  "cta": "Llamado a la acciÃ³n o pregunta para interactuar",
  "hashtags": ["#tag1", "#tag2", "#tag3", "#tag4"],
  "platform": "${platform}"
}
`;
    const sys = `Eres un community manager senior experto en engagement y viralidad en redes.`;
    return this.executeStructuredJson(prompt, sys, "gemini-1.5-flash");
  }

  /**
   * 6. DescripciÃ³n de producto
   */
  async createProductDescription(params: {
    name: string;
    features?: string;
    benefits?: string;
    audience?: string;
    tone?: string;
  }): Promise<AIProviderResult> {
    if (!params.name || params.name.trim().length === 0) {
      throw new Error("El nombre del producto es requerido.");
    }
    const prompt = `
Genera una ficha y descripciÃ³n comercial completa de producto para e-commerce.
Detalles:
- Nombre: ${params.name}
- CaracterÃ­sticas: ${params.features || "No especificadas"}
- Beneficios esperados: ${params.benefits || "SatisfacciÃ³n garantizada"}
- PÃºblico objetivo: ${params.audience || "Consumidor general"}
- Tono: ${params.tone || "Comercial y convincente"}

Responde ÃšNICAMENTE en JSON con esta estructura exacta:
{
  "title": "TÃ­tulo comercial optimizado para ventas",
  "short_description": "Resumen conciso del producto en 2 oraciones",
  "full_description": "DescripciÃ³n detallada y persuasiva de 2 a 3 pÃ¡rrafos",
  "benefits": ["Beneficio clave 1", "Beneficio clave 2", "Beneficio clave 3", "Beneficio clave 4"],
  "cta": "Llamado a la acciÃ³n para comprar o agregar al carrito"
}
`;
    const sys = `Eres un especialista en conversiÃ³n de comercio electrÃ³nico y redacciÃ³n publicitaria.`;
    return this.executeStructuredJson(prompt, sys, "gemini-1.5-flash");
  }
}
