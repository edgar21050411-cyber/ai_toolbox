import type { AIProviderResult } from "../../_shared/types.ts";

export class OpenAIAdapter {
  private apiKey: string;
  private baseUrl = "https://api.openai.com/v1";

  constructor(apiKey?: string) {
    this.apiKey = apiKey || Deno.env.get("OPENAI_API_KEY") || "";
  }

  async generateText(
    prompt: string,
    systemInstruction?: string,
    model = "gpt-4o-mini"
  ): Promise<AIProviderResult> {
    if (!this.apiKey) {
      throw new Error("OPENAI_API_KEY is not configured in backend environment");
    }

    const messages = [];
    if (systemInstruction) {
      messages.push({ role: "system", content: systemInstruction });
    }
    messages.push({ role: "user", content: prompt });

    const response = await fetch(`${this.baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`OpenAI API Error (${response.status}): ${errBody}`);
    }

    const data = await response.json();
    const outputText = data.choices?.[0]?.message?.content || "";
    const totalTokens = data.usage?.total_tokens || 200;

    // GPT-4o-mini cost estimate (~$0.0006 per 1k tokens)
    const estimatedCost = (totalTokens / 1000) * 0.0006;

    return {
      data: { text: outputText.trim() },
      provider: "openai",
      model,
      estimatedApiCost: Number(estimatedCost.toFixed(6)),
      tokensUsed: totalTokens,
    };
  }
}
