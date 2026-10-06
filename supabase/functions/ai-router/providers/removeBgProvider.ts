/**
 * Proveedor alternativo para segmentación con API de Remove.bg
 * Devuelve bytes directos de PNG con transparencia.
 */

export class RemoveBgProvider {
  private apiKey: string;

  constructor(apiKey?: string) {
    this.apiKey = apiKey || (typeof Deno !== 'undefined' ? Deno.env.get('REMOVE_BG_API_KEY') || '' : '');
  }

  isAvailable(): boolean {
    return Boolean(this.apiKey && this.apiKey.trim().length > 0);
  }

  async removeBackground(imageUrl: string): Promise<{
    bytes: Uint8Array;
    format: 'png';
    provider: string;
    model: string;
    estimatedCost: number;
  }> {
    if (!this.isAvailable()) {
      throw new Error('Remove.bg requiere la variable REMOVE_BG_API_KEY en Supabase Secrets.');
    }

    const endpoint = 'https://api.remove.bg/v1.0/removebg';

    const formData = new FormData();
    formData.append('image_url', imageUrl);
    formData.append('size', 'auto');
    formData.append('format', 'png');

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'X-Api-Key': this.apiKey.trim(),
      },
      body: formData,
    });

    if (!response.ok) {
      let errDetail = `HTTP ${response.status}: ${response.statusText}`;
      try {
        const errJson = await response.json();
        errDetail = errJson.errors?.[0]?.title || errDetail;
      } catch {
        // Ignorar
      }
      throw new Error(`Remove.bg error: ${errDetail}`);
    }

    const buffer = await response.arrayBuffer();
    return {
      bytes: new Uint8Array(buffer),
      format: 'png',
      provider: 'remove_bg',
      model: 'removebg-v1.0',
      estimatedCost: 0.009,
    };
  }
}
