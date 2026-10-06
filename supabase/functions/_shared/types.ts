export interface RouterRequest {
  tool: string;
  user_id?: string;
  input: {
    text?: string;
    image_url?: string;
    document_url?: string;
    target_language?: string;
    tone?: string;
    product_name?: string;
    product_price?: string;
    platform?: string;
    target_audience?: string;
    goal?: string;
    [key: string]: any;
  };
  parameters?: Record<string, any>;
}

export interface RouterResponse {
  success: boolean;
  tool: string;
  result: any;
  credits_used: number;
  credits_remaining: number;
  processing_time_ms: number;
  provider: string;
  model: string;
  error?: string;
}

export interface AIProviderResult {
  data: any;
  provider: string;
  model: string;
  estimatedApiCost: number;
  tokensUsed?: number;
}
