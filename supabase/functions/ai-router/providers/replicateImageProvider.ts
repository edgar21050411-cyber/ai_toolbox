/**
 * Proveedor especializado para operaciones de visión y edición con Replicate.
 * Procesa imágenes reales mediante inferencia sincronizada con modelos oficiales:
 * - bria/remove-background (Segmentación de fondo y canal alfa)
 * - nightmareai/real-esrgan (Super-resolution y upscale 2x/4x)
 * - bria/generate-background (Reemplazo e inpainting de fondo preservando sujeto)
 */

export interface ProcessedImageOutput {
  bytes: Uint8Array;
  format: 'png' | 'jpeg' | 'webp';
  provider: string;
  model: string;
  estimatedCost: number;
}

export class ReplicateImageProvider {
  private apiToken: string;

  constructor(token?: string) {
    this.apiToken = token || (typeof Deno !== 'undefined' ? Deno.env.get('REPLICATE_API_TOKEN') || '' : '');
  }

  isAvailable(): boolean {
    return Boolean(this.apiToken && this.apiToken.trim().length > 0);
  }

  /**
   * Ejecuta una predicción en Replicate utilizando sincronización 'Prefer: wait'
   * con sondeo de respaldo ante tareas que tarden más de unos segundos.
   */
  private async runModelPrediction(
    modelOwner: string,
    modelName: string,
    input: Record<string, any>,
    timeoutMs: number = 55000
  ): Promise<string> {
    if (!this.isAvailable()) {
      throw new Error(
        'El procesamiento real de imágenes requiere la variable REPLICATE_API_TOKEN configurada en Supabase Secrets.'
      );
    }

    const endpoint = `https://api.replicate.com/v1/models/${modelOwner}/${modelName}/predictions`;

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiToken.trim()}`,
        'Content-Type': 'application/json',
        'Prefer': 'wait',
      },
      body: JSON.stringify({ input }),
    });

    if (!response.ok) {
      let errDetail = `HTTP ${response.status}: ${response.statusText}`;
      try {
        const errJson = await response.json();
        errDetail = errJson.detail || errJson.error || errDetail;
      } catch {
        // Ignorar error de parsing
      }
      throw new Error(`Error en API de Replicate (${modelOwner}/${modelName}): ${errDetail}`);
    }

    let prediction = await response.json();

    // Si completó sincrónicamente con Prefer: wait
    if (prediction.status === 'succeeded' && prediction.output) {
      return Array.isArray(prediction.output) ? prediction.output[0] : prediction.output;
    }

    if (prediction.status === 'failed' || prediction.status === 'canceled') {
      throw new Error(`Inferencia de Replicate fallida: ${prediction.error || 'Estado ' + prediction.status}`);
    }

    // Sondeo (polling) de respaldo si la tarea quedó en procesamiento
    const pollUrl = prediction.urls?.get;
    if (!pollUrl) {
      throw new Error('Replicate no proporcionó URL de sondeo para obtener el resultado.');
    }

    const startTime = Date.now();
    while (Date.now() - startTime < timeoutMs) {
      await new Promise((resolve) => setTimeout(resolve, 1500));

      const pollRes = await fetch(pollUrl, {
        headers: {
          'Authorization': `Bearer ${this.apiToken.trim()}`,
        },
      });

      if (!pollRes.ok) continue;

      prediction = await pollRes.json();
      if (prediction.status === 'succeeded' && prediction.output) {
        return Array.isArray(prediction.output) ? prediction.output[0] : prediction.output;
      }

      if (prediction.status === 'failed' || prediction.status === 'canceled') {
        throw new Error(`Inferencia de Replicate fallida: ${prediction.error || prediction.status}`);
      }
    }

    throw new Error(`Tiempo de espera agotado (${timeoutMs / 1000}s) procesando imagen en Replicate.`);
  }

  /**
   * Descarga los bytes reales de la URL resultante proporcionada por Replicate.
   */
  private async downloadImageBytes(url: string): Promise<Uint8Array> {
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`No se pudo descargar la imagen procesada desde Replicate: HTTP ${res.status}`);
    }
    const buffer = await res.arrayBuffer();
    return new Uint8Array(buffer);
  }

  /**
   * 9. Quitar fondo (remove_background)
   * Modelo: bria/remove-background
   * Salida: PNG con canal alfa y transparencia real
   */
  async removeBackground(imageUrl: string): Promise<ProcessedImageOutput> {
    const outputUrl = await this.runModelPrediction(
      'bria',
      'remove-background',
      { image: imageUrl }
    );

    const bytes = await this.downloadImageBytes(outputUrl);

    return {
      bytes,
      format: 'png',
      provider: 'replicate',
      model: 'bria/remove-background',
      estimatedCost: 0.005,
    };
  }

  /**
   * 8. Mejorar imagen (improve_image)
   * Modelo: nightmareai/real-esrgan
   * Salida: Super-resolución / nitidez 2x o 4x
   */
  async improveImage(imageUrl: string, factor: number = 2): Promise<ProcessedImageOutput> {
    const outputUrl = await this.runModelPrediction(
      'nightmareai',
      'real-esrgan',
      {
        image: imageUrl,
        scale: factor,
        face_enhance: true,
      }
    );

    const bytes = await this.downloadImageBytes(outputUrl);

    return {
      bytes,
      format: 'png',
      provider: 'replicate',
      model: 'nightmareai/real-esrgan',
      estimatedCost: 0.006,
    };
  }

  /**
   * 10. Cambiar fondo (change_background)
   * Modelo: bria/generate-background
   * Salida: Composición e inpainting fotográfico preservando el sujeto
   */
  async changeBackground(imageUrl: string, backgroundDescription: string): Promise<ProcessedImageOutput> {
    const outputUrl = await this.runModelPrediction(
      'bria',
      'generate-background',
      {
        image: imageUrl,
        prompt: backgroundDescription.trim(),
      }
    );

    const bytes = await this.downloadImageBytes(outputUrl);

    return {
      bytes,
      format: 'png',
      provider: 'replicate',
      model: 'bria/generate-background',
      estimatedCost: 0.015,
    };
  }
}
