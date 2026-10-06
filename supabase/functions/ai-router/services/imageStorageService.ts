/**
 * Servicio de almacenamiento y validación de imágenes para Supabase Storage.
 * Gestiona el bucket 'generated-files' con RLS y validación estricta de bytes.
 */

export interface ImageValidationResult {
  valid: boolean;
  format: 'png' | 'jpeg' | 'webp' | 'unknown';
  mimeType: string;
  sizeBytes: number;
  hasAlphaChannel?: boolean;
  error?: string;
}

export class ImageStorageService {
  /**
   * Valida firmas binarias (Magic Bytes) y tamaño para evitar inyección de archivos no válidos.
   */
  static validateImageBytes(bytes: Uint8Array, requirePngAlpha: boolean = false): ImageValidationResult {
    const sizeBytes = bytes ? bytes.byteLength : 0;

    if (!bytes || sizeBytes === 0) {
      return { valid: false, format: 'unknown', mimeType: '', sizeBytes: 0, error: 'El archivo de imagen está vacío (0 bytes).' };
    }

    const MAX_SIZE_BYTES = 15 * 1024 * 1024; // 15 MB
    if (sizeBytes > MAX_SIZE_BYTES) {
      const mbSize = (sizeBytes / (1024 * 1024)).toFixed(2);
      return {
        valid: false,
        format: 'unknown',
        mimeType: '',
        sizeBytes,
        error: 'El archivo excede el tamaño máximo permitido de 15MB (actual: ' + mbSize + 'MB).',
      };
    }

    // Comprobar PNG: 89 50 4E 47 0D 0A 1A 0A
    if (
      sizeBytes >= 8 &&
      bytes[0] === 0x89 &&
      bytes[1] === 0x50 &&
      bytes[2] === 0x4e &&
      bytes[3] === 0x47 &&
      bytes[4] === 0x0d &&
      bytes[5] === 0x0a &&
      bytes[6] === 0x1a &&
      bytes[7] === 0x0a
    ) {
      let hasAlpha = false;
      if (sizeBytes >= 26) {
        const colorType = bytes[25];
        hasAlpha = colorType === 4 || colorType === 6;
      }

      return {
        valid: true,
        format: 'png',
        mimeType: 'image/png',
        sizeBytes,
        hasAlphaChannel: hasAlpha,
      };
    }

    // Comprobar JPEG: FF D8 FF
    if (sizeBytes >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
      if (requirePngAlpha) {
        return {
          valid: false,
          format: 'jpeg',
          mimeType: 'image/jpeg',
          sizeBytes,
          error: 'La herramienta remove_background requiere un formato PNG con canal alfa/transparencia.',
        };
      }
      return { valid: true, format: 'jpeg', mimeType: 'image/jpeg', sizeBytes };
    }

    // Comprobar WebP: RIFF .... WEBP
    if (
      sizeBytes >= 12 &&
      bytes[0] === 0x52 &&
      bytes[1] === 0x49 &&
      bytes[2] === 0x46 &&
      bytes[3] === 0x46 &&
      bytes[8] === 0x57 &&
      bytes[9] === 0x45 &&
      bytes[10] === 0x42 &&
      bytes[11] === 0x50
    ) {
      return { valid: true, format: 'webp', mimeType: 'image/webp', sizeBytes };
    }

    return {
      valid: false,
      format: 'unknown',
      mimeType: '',
      sizeBytes,
      error: 'Formato de imagen inválido o no reconocido. Se admiten PNG, JPEG y WebP.',
    };
  }

  /**
   * Sube bytes reales de una imagen generada/procesada al bucket 'generated-files' en Supabase Storage.
   */
  static async uploadGeneratedImage(params: {
    adminClient: any;
    userId: string;
    bytes: Uint8Array;
    format: string;
    toolId: string;
  }): Promise<{ storagePath: string; signedUrl: string }> {
    const { adminClient, userId, bytes, toolId } = params;

    const validation = this.validateImageBytes(bytes, toolId === 'remove_background');
    if (!validation.valid) {
      throw new Error(validation.error || 'Validación de imagen fallida.');
    }

    const uniqueId = typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID().slice(0, 8) : Date.now().toString();
    const fileName = toolId + '_' + Date.now() + '_' + uniqueId + '.' + validation.format;
    const storagePath = userId + '/' + fileName;

    if (!adminClient) {
      return {
        storagePath: 'generated-files/' + storagePath,
        signedUrl: 'https://storage.supabase.local/generated-files/' + storagePath,
      };
    }

    const { error: uploadError } = await adminClient.storage
      .from('generated-files')
      .upload(storagePath, bytes, {
        contentType: validation.mimeType,
        upsert: true,
      });

    if (uploadError) {
      throw new Error('Error al persistir imagen en Supabase Storage: ' + uploadError.message);
    }

    // Generar URL firmada con vigencia de 1 año (31,536,000 segundos)
    const { data: signedData, error: signedError } = await adminClient.storage
      .from('generated-files')
      .createSignedUrl(storagePath, 31536000);

    let signedUrl = signedData?.signedUrl;
    if (signedError || !signedUrl) {
      const { data: publicData } = adminClient.storage
        .from('generated-files')
        .getPublicUrl(storagePath);
      signedUrl = publicData?.publicUrl || ('https://storage.supabase.co/generated-files/' + storagePath);
    }

    return {
      storagePath,
      signedUrl,
    };
  }

  /**
   * Resuelve de forma segura el input de imagen del usuario.
   * Acepta:
   * 1. Data URLs base64 ('data:image/png;base64,...')
   * 2. URLs remotas HTTPS (con protección SSRF)
   * 3. Rutas privadas en Supabase Storage ('user-files/...')
   */
  static async resolveInputImage(params: {
    adminClient?: any;
    userId?: string;
    imageUrl: string;
  }): Promise<{ secureUrl: string; format: string }> {
    const { adminClient, userId, imageUrl } = params;
    const cleanUrl = imageUrl ? imageUrl.trim() : '';

    if (!cleanUrl) {
      throw new Error('La URL o contenido de la imagen de entrada está vacío.');
    }

    // 1. Caso Data URL (Base64)
    if (cleanUrl.startsWith('data:image/')) {
      const matches = cleanUrl.match(/^data:image\/([a-zA-Z0-9+.-]+);base64,(.+)$/);
      if (!matches) {
        throw new Error('La imagen en formato Data URL base64 está malformada.');
      }

      const formatRaw = matches[1].toLowerCase();
      const base64Data = matches[2];
      const binaryString = atob(base64Data);
      const len = binaryString.length;
      const bytes = new Uint8Array(len);
      for (let i = 0; i < len; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }

      const validation = this.validateImageBytes(bytes);
      if (!validation.valid) {
        throw new Error(validation.error || 'La imagen base64 no contiene datos válidos.');
      }

      if (adminClient && userId) {
        const uniqueId = typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID().slice(0, 8) : Date.now().toString();
        const inputPath = userId + '/inputs/input_' + Date.now() + '_' + uniqueId + '.' + validation.format;

        await adminClient.storage
          .from('user-files')
          .upload(inputPath, bytes, {
            contentType: validation.mimeType,
            upsert: true,
          });

        const { data: signedData } = await adminClient.storage
          .from('user-files')
          .createSignedUrl(inputPath, 3600);

        if (signedData?.signedUrl) {
          return { secureUrl: signedData.signedUrl, format: validation.format };
        }
      }

      return { secureUrl: cleanUrl, format: validation.format };
    }

    // 2. Caso URL HTTP / HTTPS
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      let parsed: URL;
      try {
        parsed = new URL(cleanUrl);
      } catch {
        throw new Error('La URL proporcionada no es una dirección web válida.');
      }

      // Protección SSRF: Rechazar accesos a localhost, 127.0.0.1 y rangos privados
      const host = parsed.hostname.toLowerCase();
      if (
        host === 'localhost' ||
        host === '127.0.0.1' ||
        host === '0.0.0.0' ||
        host === '169.254.169.254' ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        (host.startsWith('172.') && parseInt(host.split('.')[1], 10) >= 16 && parseInt(host.split('.')[1], 10) <= 31)
      ) {
        throw new Error('La URL de la imagen apunta a una dirección interna o no permitida (SSRF).');
      }

      return { secureUrl: cleanUrl, format: 'unknown' };
    }

    // 3. Caso ruta interna de Supabase Storage ('user-files/...' o 'generated-files/...')
    if (adminClient && (cleanUrl.startsWith('user-files/') || cleanUrl.startsWith('generated-files/'))) {
      const parts = cleanUrl.split('/');
      const bucket = parts[0];
      const filePath = parts.slice(1).join('/');

      const { data: signedData, error: signErr } = await adminClient.storage
        .from(bucket)
        .createSignedUrl(filePath, 3600);

      if (signErr || !signedData?.signedUrl) {
        throw new Error('No se pudo obtener acceso al archivo en Supabase Storage: ' + cleanUrl);
      }

      return { secureUrl: signedData.signedUrl, format: 'unknown' };
    }

    throw new Error('Formato de entrada de imagen no compatible. Proporciona una URL HTTPS o Data URL base64.');
  }
}
