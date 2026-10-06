import { TextEngine } from "./textEngine.ts";
import { ImageEngine } from "./imageEngine.ts";
import { GeminiAdapter } from "../adapters/gemini.ts";
import type { AIProviderResult } from "../../_shared/types.ts";

export class MarketingEngine {
  private textEngine: TextEngine;
  private imageEngine: ImageEngine;
  private gemini: GeminiAdapter;

  constructor() {
    this.textEngine = new TextEngine();
    this.imageEngine = new ImageEngine();
    this.gemini = new GeminiAdapter();
  }

  async createAd(params: {
    product_name: string;
    product_price?: string;
    description?: string;
    platform?: string;
    style?: string;
    image_url?: string;
    language?: string;
  }): Promise<AIProviderResult> {
    const lang = params.language || "es";
    const platform = params.platform || "Instagram";
    const prompt = `
Genera un anuncio de marketing de alta conversiÃ³n para la plataforma ${platform}.
Detalles del producto:
- Nombre: ${params.product_name}
${params.product_price ? `- Precio: ${params.product_price}` : ""}
${params.description ? `- DescripciÃ³n base: ${params.description}` : ""}
- Estilo: ${params.style || "Persuasivo y profesional"}

Responde ÃšNICAMENTE en formato JSON con la siguiente estructura:
{
  "title": "Titular llamativo (menos de 60 caracteres)",
  "ad_text": "Cuerpo persuasivo del anuncio adaptado al formato de ${platform}",
  "benefits": ["Beneficio clave 1", "Beneficio clave 2", "Beneficio clave 3"],
  "cta": "Llamado a la acciÃ³n directo",
  "hashtags": ["#tag1", "#tag2", "#tag3"]
}
`;

    const sys = `Eres el director creativo de una agencia de marketing digital de primer nivel en idioma ${lang}.`;
    const aiRes = await this.gemini.generateStructuredJson(prompt, sys, "gemini-1.5-flash");

    return {
      data: {
        ...aiRes.data,
        platform,
        image_url: params.image_url || null,
      },
      provider: aiRes.provider,
      model: aiRes.model,
      estimatedApiCost: aiRes.estimatedApiCost,
      tokensUsed: aiRes.tokensUsed,
    };
  }

  async createSocialPost(params: {
    topic: string;
    platform?: string;
    tone?: string;
    language?: string;
  }): Promise<AIProviderResult> {
    const lang = params.language || "es";
    const platform = params.platform || "Instagram";
    const prompt = `Crea una publicaciÃ³n para ${platform} sobre el tema: "${params.topic}". Tono: ${params.tone || "amigable y atractivo"}. Incluye emojis, llamado a interacciÃ³n y hashtags. Idioma: ${lang}.`;
    return this.textEngine.expand(prompt, params.tone || "creativo", lang);
  }

  async productDescription(params: {
    product_name: string;
    features?: string;
    price?: string;
    language?: string;
  }): Promise<AIProviderResult> {
    const lang = params.language || "es";
    const prompt = `Escribe una ficha de producto irresistible para e-commerce.
Producto: ${params.product_name}
${params.features ? `CaracterÃ­sticas: ${params.features}` : ""}
${params.price ? `Precio: ${params.price}` : ""}
Devuelve un tÃ­tulo atractivo, una descripciÃ³n de 2 pÃ¡rrafos y una lista de 4 viÃ±etas con beneficios clave. Idioma: ${lang}.`;
    return this.textEngine.expand(prompt, "comercial", lang);
  }

  async createCampaign(params: {
    product_name: string;
    target_audience: string;
    goal: string;
    price?: string;
    platform?: string;
    image_url?: string;
    language?: string;
  }): Promise<AIProviderResult> {
    const lang = params.language || "es";
    const prompt = `
DiseÃ±a una campaÃ±a publicitaria completa:
- Producto: ${params.product_name}
- PÃºblico objetivo: ${params.target_audience}
- Objetivo: ${params.goal}
- Plataforma: ${params.platform || "Multiplataforma"}
${params.price ? `- Precio: ${params.price}` : ""}

Responde ÃšNICAMENTE en JSON con la siguiente estructura:
{
  "concept": "Concepto central de la campaÃ±a",
  "slogan": "Slogan pegadizo principal",
  "headlines": ["Titular variante 1", "Titular variante 2", "Titular variante 3"],
  "ads": [
    { "variant": "Enfoque Emocional", "copy": "Texto del anuncio...", "cta": "..." },
    { "variant": "Enfoque Beneficios Directos", "copy": "Texto del anuncio...", "cta": "..." },
    { "variant": "Enfoque Urgencia / Descuento", "copy": "Texto del anuncio...", "cta": "..." }
  ],
  "ctas": ["CTA 1", "CTA 2", "CTA 3"],
  "recommended_schedule": "Estrategia de publicaciÃ³n"
}
`;
    const sys = `Eres un estratega senior de campaÃ±as publicitarias digitales de escala global. Idioma: ${lang}.`;
    const aiRes = await this.gemini.generateStructuredJson(prompt, sys, "gemini-1.5-pro");

    return {
      data: {
        ...aiRes.data,
        image_url: params.image_url || null,
      },
      provider: aiRes.provider,
      model: aiRes.model,
      estimatedApiCost: aiRes.estimatedApiCost,
      tokensUsed: aiRes.tokensUsed,
    };
  }
}
