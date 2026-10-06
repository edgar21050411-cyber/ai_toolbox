import type { AIProviderResult } from "../../_shared/types.ts";

export class GeminiAdapter {
  private apiKey: string;
  private baseUrl = "https://generativelanguage.googleapis.com/v1beta";

  constructor(apiKey?: string) {
    this.apiKey = apiKey || Deno.env.get("GEMINI_API_KEY") || "";
  }

  async generateText(
    prompt: string,
    systemInstruction?: string,
    model = "gemini-1.5-flash"
  ): Promise<AIProviderResult> {
    if (!this.apiKey) {
      throw new Error("GEMINI_API_KEY is not configured in backend environment");
    }

    const endpoint = `${this.baseUrl}/models/${model}:generateContent?key=${this.apiKey}`;
    const payload: any = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
      },
    };

    if (systemInstruction) {
      payload.systemInstruction = {
        parts: [{ text: systemInstruction }],
      };
    }

    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`Gemini API Error (${response.status}): ${errBody}`);
    }

    const data = await response.json();
    const candidate = data.candidates?.[0];
    const outputText = candidate?.content?.parts?.[0]?.text || "";
    const totalTokens = data.usageMetadata?.totalTokenCount || 200;

    // Cost calculation (Gemini Flash estimate: ~$0.0001 per 1K tokens)
    const estimatedCost = (totalTokens / 1000) * 0.0001;

    return {
      data: { text: outputText.trim() },
      provider: "google_gemini",
      model,
      estimatedApiCost: Number(estimatedCost.toFixed(6)),
      tokensUsed: totalTokens,
    };
  }

  async generateStructuredJson(
    prompt: string,
    systemInstruction?: string,
    model = "gemini-1.5-flash"
  ): Promise<AIProviderResult> {
    if (!this.apiKey) {
      throw new Error("GEMINI_API_KEY is not configured in backend environment");
    }

    const endpoint = `${this.baseUrl}/models/${model}:generateContent?key=${this.apiKey}`;
    const payload: any = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.5,
        responseMimeType: "application/json",
      },
    };

    if (systemInstruction) {
      payload.systemInstruction = {
        parts: [{ text: systemInstruction }],
      };
    }

    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`Gemini API Error (${response.status}): ${errBody}`);
    }

    const data = await response.json();
    const candidate = data.candidates?.[0];
    const rawJson = candidate?.content?.parts?.[0]?.text || "{}";
    const totalTokens = data.usageMetadata?.totalTokenCount || 300;
    const estimatedCost = (totalTokens / 1000) * 0.0001;

    let parsed = {};
    try {
      parsed = JSON.parse(rawJson);
    } catch {
      parsed = { text: rawJson };
    }

    return {
      data: parsed,
      provider: "google_gemini",
      model,
      estimatedApiCost: Number(estimatedCost.toFixed(6)),
      tokensUsed: totalTokens,
    };
  }
}
