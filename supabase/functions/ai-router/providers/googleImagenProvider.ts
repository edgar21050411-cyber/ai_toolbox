/**
 * Proveedor para Google Imagen 3 (Generación de imágenes con IA).
 * Devuelve bytes binarios reales decodificados desde Base64.
 */

export interface GeneratedImageOutput {
  bytes: Uint8Array;
  format: 'png';
  provider: string;
  model: string;
  estimatedCost: number;
}

export class GoogleImagenProvider {
  private apiKey: string;

  constructor(apiKey?: string) {
    this.apiKey = apiKey || (typeof Deno !== 'undefined' ? Deno.env.get('GEMINI_API_KEY') || '' : '');
  }

  isAvailable(): boolean {
    return Boolean(this.apiKey && this.apiKey.trim().length > 0);
  }

  async generateImage(prompt: string, style?: string): Promise<GeneratedImageOutput> {
    if (!this.isAvailable()) {
      throw new Error(
        'Google Imagen 3 requiere la variable GEMINI_API_KEY configurada en Supabase Secrets.'
      );
    }

    const styledPrompt = `${prompt.trim()}${style ? `, in style ${style}` : ''}`;
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=${this.apiKey}`;

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        instances: [{ prompt: styledPrompt }],
        parameters: { sampleCount: 1, aspectRatio: '1:1' },
      }),
    });

    if (!response.ok) {
      let errDetail = 'Error al comunicarse con Google Imagen 3';
      try {
        const errJson = await response.json();
        errDetail = errJson.error?.message || errDetail;
      } catch {
        errDetail = `HTTP ${response.status}: ${response.statusText}`;
      }
      throw new Error(`Google Imagen 3 API error: ${errDetail}`);
    }

    const resData = await response.json();
    const base64Data = resData.predictions?.[0]?.bytesBase64Encoded;

    if (!base64Data) {
      throw new Error('Google Imagen 3 no devolvió datos de imagen válidos.');
    }

    // Decodificar Base64 a Uint8Array
    const binaryString = atob(base64Data);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    return {
      bytes,
      format: 'png',
      provider: 'google_imagen',
      model: 'imagen-3.0-generate-002',
      estimatedCost: 0.03,
    };
  }
}
