import type { AIProviderResult } from "../../_shared/types.ts";
import { GoogleImagenProvider } from "../providers/googleImagenProvider.ts";
import { ReplicateImageProvider } from "../providers/replicateImageProvider.ts";
import { RemoveBgProvider } from "../providers/removeBgProvider.ts";
import { ImageStorageService } from "../services/imageStorageService.ts";

export interface ImageExecutionParams {
  userId: string;
  adminClient: any;
}

export class ImageEngine {
  private imagenProvider: GoogleImagenProvider;
  private replicateProvider: ReplicateImageProvider;
  private removeBgProvider: RemoveBgProvider;

  constructor() {
    this.imagenProvider = new GoogleImagenProvider();
    this.replicateProvider = new ReplicateImageProvider();
    this.removeBgProvider = new RemoveBgProvider();
  }

  /**
   * 7. Crear imagen con IA (generate_image)
   * Proveedor: Google Imagen 3 (imagen-3.0-generate-002)
   * Salida: Archivo PNG real persistido en Supabase Storage (generated-files)
   */
  async generateImage(params: {
    prompt: string;
    style?: string;
    userId: string;
    adminClient: any;
  }): Promise<AIProviderResult> {
    if (!params.prompt || params.prompt.trim().length === 0) {
      throw new Error("El prompt de la imagen no puede estar vacío.");
    }

    if (params.prompt.length > 1000) {
      throw new Error("El prompt excede el límite permitido de 1000 caracteres.");
    }

    if (!this.imagenProvider.isAvailable()) {
      throw new Error(
        "La generación real de imágenes requiere configurar GEMINI_API_KEY en Supabase Secrets."
      );
    }

    // 1. Invocación de API real de Google Imagen 3
    const generated = await this.imagenProvider.generateImage(params.prompt, params.style);

    // 2. Persistencia real de bytes en Supabase Storage (bucket 'generated-files')
    const stored = await ImageStorageService.uploadGeneratedImage({
      adminClient: params.adminClient,
      userId: params.userId,
      bytes: generated.bytes,
      format: generated.format,
      toolId: "generate_image",
    });

    return {
      data: {
        image_url: stored.signedUrl,
        storage_path: stored.storagePath,
        prompt: params.prompt.trim(),
        style: params.style || "realistic",
        format: "png",
        is_real_generation: true,
      },
      provider: generated.provider,
      model: generated.model,
      estimatedApiCost: generated.estimatedCost,
    };
  }

  /**
   * 8. Mejorar imagen (improve_image)
   * Proveedor: Real-ESRGAN (nightmareai/real-esrgan) vía Replicate
   * Salida: Archivo de super-resolución / upscale persistido en Supabase Storage
   */
  async improveImage(params: {
    imageUrl: string;
    factor?: number;
    userId: string;
    adminClient: any;
  }): Promise<AIProviderResult> {
    if (!params.imageUrl || params.imageUrl.trim().length === 0) {
      throw new Error("Se requiere la URL o Data URL de la imagen a mejorar.");
    }

    if (!this.replicateProvider.isAvailable()) {
      throw new Error(
        "El procesamiento real de improve_image requiere configurar REPLICATE_API_TOKEN en Supabase Secrets."
      );
    }

    // 1. Preparación y validación de entrada (anti-SSRF y carga controlada)
    const resolvedInput = await ImageStorageService.resolveInputImage({
      adminClient: params.adminClient,
      userId: params.userId,
      imageUrl: params.imageUrl,
    });

    // 2. Procesamiento real de super-resolución (2x por defecto)
    const factor = params.factor || 2;
    const processed = await this.replicateProvider.improveImage(resolvedInput.secureUrl, factor);

    // 3. Persistencia de imagen mejorada en Supabase Storage
    const stored = await ImageStorageService.uploadGeneratedImage({
      adminClient: params.adminClient,
      userId: params.userId,
      bytes: processed.bytes,
      format: processed.format,
      toolId: "improve_image",
    });

    return {
      data: {
        image_url: stored.signedUrl,
        enhanced_image_url: stored.signedUrl,
        storage_path: stored.storagePath,
        original_url: params.imageUrl,
        factor: `${factor}x`,
        action: "improve_image",
        format: processed.format,
      },
      provider: processed.provider,
      model: processed.model,
      estimatedApiCost: processed.estimatedCost,
    };
  }

  /**
   * 9. Quitar fondo (remove_background)
   * Proveedor: RMBG / bria/remove-background (Replicate) o remove.bg
   * Salida: Archivo PNG real con canal alfa y transparencia en Supabase Storage
   */
  async removeBackground(params: {
    imageUrl: string;
    userId: string;
    adminClient: any;
  }): Promise<AIProviderResult> {
    if (!params.imageUrl || params.imageUrl.trim().length === 0) {
      throw new Error("Se requiere la URL o Data URL de la imagen para quitar el fondo.");
    }

    const hasReplicate = this.replicateProvider.isAvailable();
    const hasRemoveBg = this.removeBgProvider.isAvailable();

    if (!hasReplicate && !hasRemoveBg) {
      throw new Error(
        "El procesamiento real de remove_background requiere configurar REPLICATE_API_TOKEN (o REMOVE_BG_API_KEY) en Supabase Secrets."
      );
    }

    // 1. Resolución segura de la imagen de entrada
    const resolvedInput = await ImageStorageService.resolveInputImage({
      adminClient: params.adminClient,
      userId: params.userId,
      imageUrl: params.imageUrl,
    });

    // 2. Procesamiento real de segmentación de primer plano
    let processed: { bytes: Uint8Array; format: string; provider: string; model: string; estimatedCost: number };

    if (hasRemoveBg) {
      processed = await this.removeBgProvider.removeBackground(resolvedInput.secureUrl);
    } else {
      processed = await this.replicateProvider.removeBackground(resolvedInput.secureUrl);
    }

    // 3. Subir el archivo PNG transparente a 'generated-files'
    const stored = await ImageStorageService.uploadGeneratedImage({
      adminClient: params.adminClient,
      userId: params.userId,
      bytes: processed.bytes,
      format: "png",
      toolId: "remove_background",
    });

    return {
      data: {
        image_url: stored.signedUrl,
        storage_path: stored.storagePath,
        original_url: params.imageUrl,
        format: "png",
        transparency: true,
        has_alpha: true,
        action: "remove_background",
      },
      provider: processed.provider,
      model: processed.model,
      estimatedApiCost: processed.estimatedCost,
    };
  }

  /**
   * 10. Cambiar fondo (change_background)
   * Proveedor: bria/generate-background vía Replicate
   * Pipeline: Segmentación de sujeto + Inpainting con prompt de escenario
   */
  async changeBackground(params: {
    imageUrl: string;
    backgroundDescription: string;
    userId: string;
    adminClient: any;
  }): Promise<AIProviderResult> {
    if (!params.imageUrl || params.imageUrl.trim().length === 0) {
      throw new Error("Se requiere la URL o Data URL de la imagen base.");
    }
    if (!params.backgroundDescription || params.backgroundDescription.trim().length === 0) {
      throw new Error("Se requiere la descripción del nuevo fondo.");
    }

    if (!this.replicateProvider.isAvailable()) {
      throw new Error(
        "El procesamiento real de change_background requiere configurar REPLICATE_API_TOKEN en Supabase Secrets."
      );
    }

    // 1. Resolución segura de la imagen de entrada
    const resolvedInput = await ImageStorageService.resolveInputImage({
      adminClient: params.adminClient,
      userId: params.userId,
      imageUrl: params.imageUrl,
    });

    // 2. Ejecución real de inpainting / background swap
    const processed = await this.replicateProvider.changeBackground(
      resolvedInput.secureUrl,
      params.backgroundDescription
    );

    // 3. Persistencia de la composición final en 'generated-files'
    const stored = await ImageStorageService.uploadGeneratedImage({
      adminClient: params.adminClient,
      userId: params.userId,
      bytes: processed.bytes,
      format: processed.format,
      toolId: "change_background",
    });

    return {
      data: {
        image_url: stored.signedUrl,
        storage_path: stored.storagePath,
        original_url: params.imageUrl,
        background_description: params.backgroundDescription.trim(),
        action: "change_background",
        format: processed.format,
      },
      provider: processed.provider,
      model: processed.model,
      estimatedApiCost: processed.estimatedCost,
    };
  }
}
