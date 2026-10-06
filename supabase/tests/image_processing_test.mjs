import assert from "node:assert";

// Mock Deno environment if running under Node.js
if (typeof globalThis.Deno === "undefined") {
  globalThis.Deno = {
    env: {
      get: (key) => process.env[key] || "",
    },
  };
}

console.log("================================================================================");
console.log("AI TOOLBOX — FASE 2.6: SUITE DE PRUEBAS DE PROCESAMIENTO REAL DE IMÁGENES Y STORAGE");
console.log("================================================================================");

let passedTests = 0;
let totalTests = 0;

function test(name, fn) {
  totalTests++;
  try {
    fn();
    console.log(`  ✓ [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  ✗ [FAIL] ${name}`);
    console.error(`    Detalle: ${err.message}`);
    throw err;
  }
}

async function asyncTest(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  ✓ [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  ✗ [FAIL] ${name}`);
    console.error(`    Detalle: ${err.message}`);
    throw err;
  }
}

// -----------------------------------------------------------------------------
// 1. Validaciones binarias de Magic Bytes y tamaño (ImageStorageService)
// -----------------------------------------------------------------------------
console.log("\n1. Pruebas de Validación de Magic Bytes y Tamaño de Imagen:");

// Generadores de bytes de prueba
function createFakePng(withAlpha = true) {
  const bytes = new Uint8Array(64);
  // PNG Magic Header: 89 50 4E 47 0D 0A 1A 0A
  bytes[0] = 0x89; bytes[1] = 0x50; bytes[2] = 0x4e; bytes[3] = 0x47;
  bytes[4] = 0x0d; bytes[5] = 0x0a; bytes[6] = 0x1a; bytes[7] = 0x0a;
  // IHDR Color type byte (índice 25)
  bytes[25] = withAlpha ? 6 : 2; // 6: RGBA, 2: RGB
  return bytes;
}

function createFakeJpeg() {
  const bytes = new Uint8Array(32);
  bytes[0] = 0xff; bytes[1] = 0xd8; bytes[2] = 0xff;
  return bytes;
}

function createFakeWebp() {
  const bytes = new Uint8Array(32);
  // RIFF
  bytes[0] = 0x52; bytes[1] = 0x49; bytes[2] = 0x46; bytes[3] = 0x46;
  // WEBP en bytes 8..11
  bytes[8] = 0x57; bytes[9] = 0x45; bytes[10] = 0x42; bytes[11] = 0x50;
  return bytes;
}

// Importar servicio de storage
import { ImageStorageService } from "../functions/ai-router/services/imageStorageService.ts";

test("Detecta correctamente formato PNG con canal alfa", () => {
  const pngBytes = createFakePng(true);
  const result = ImageStorageService.validateImageBytes(pngBytes, true);
  assert.strictEqual(result.valid, true);
  assert.strictEqual(result.format, "png");
  assert.strictEqual(result.hasAlphaChannel, true);
  assert.strictEqual(result.mimeType, "image/png");
});

test("Detecta correctamente formato JPEG", () => {
  const jpegBytes = createFakeJpeg();
  const result = ImageStorageService.validateImageBytes(jpegBytes, false);
  assert.strictEqual(result.valid, true);
  assert.strictEqual(result.format, "jpeg");
  assert.strictEqual(result.mimeType, "image/jpeg");
});

test("Detecta correctamente formato WebP", () => {
  const webpBytes = createFakeWebp();
  const result = ImageStorageService.validateImageBytes(webpBytes, false);
  assert.strictEqual(result.valid, true);
  assert.strictEqual(result.format, "webp");
  assert.strictEqual(result.mimeType, "image/webp");
});

test("Rechaza archivos vacíos (0 bytes)", () => {
  const emptyBytes = new Uint8Array(0);
  const result = ImageStorageService.validateImageBytes(emptyBytes);
  assert.strictEqual(result.valid, false);
  assert.ok(result.error.includes("vacío"));
});

test("Rechaza archivos que exceden 15MB", () => {
  const oversized = new Uint8Array(16 * 1024 * 1024); // 16 MB
  oversized[0] = 0x89; oversized[1] = 0x50; oversized[2] = 0x4e; oversized[3] = 0x47;
  oversized[4] = 0x0d; oversized[5] = 0x0a; oversized[6] = 0x1a; oversized[7] = 0x0a;
  const result = ImageStorageService.validateImageBytes(oversized);
  assert.strictEqual(result.valid, false);
  assert.ok(result.error.includes("excede el tamaño máximo"));
});

test("Rechaza JPEG para herramienta remove_background si se requiere canal alfa", () => {
  const jpegBytes = createFakeJpeg();
  const result = ImageStorageService.validateImageBytes(jpegBytes, true);
  assert.strictEqual(result.valid, false);
  assert.ok(result.error.includes("remove_background"));
});

test("Rechaza formatos desconocidos o scripts maliciosos disfrazados", () => {
  const fakeHtml = new TextEncoder().encode("<html><script>alert(1)</script></html>");
  const result = ImageStorageService.validateImageBytes(fakeHtml);
  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.format, "unknown");
});

// -----------------------------------------------------------------------------
// 2. Pruebas de Protección Anti-SSRF y Resolución de Input
// -----------------------------------------------------------------------------
console.log("\n2. Pruebas de Seguridad y Anti-SSRF en Input de Imágenes:");

await asyncTest("Bloquea intento de SSRF a localhost", async () => {
  await assert.rejects(
    async () => {
      await ImageStorageService.resolveInputImage({ imageUrl: "http://localhost:8080/admin" });
    },
    /interna o no permitida/
  );
});

await asyncTest("Bloquea intento de SSRF a 127.0.0.1", async () => {
  await assert.rejects(
    async () => {
      await ImageStorageService.resolveInputImage({ imageUrl: "http://127.0.0.1:3000/internal.png" });
    },
    /interna o no permitida/
  );
});

await asyncTest("Bloquea intento de SSRF a IP privada 10.0.0.1", async () => {
  await assert.rejects(
    async () => {
      await ImageStorageService.resolveInputImage({ imageUrl: "http://10.0.1.25/secret.jpg" });
    },
    /interna o no permitida/
  );
});

await asyncTest("Bloquea intento de SSRF a metadata service de Cloud (169.254.169.254)", async () => {
  await assert.rejects(
    async () => {
      await ImageStorageService.resolveInputImage({ imageUrl: "http://169.254.169.254/latest/meta-data/" });
    },
    /interna o no permitida/
  );
});

await asyncTest("Acepta URL remota HTTPS legítima", async () => {
  const validUrl = "https://images.unsplash.com/photo-1542291026-7eec264c27ff";
  const resolved = await ImageStorageService.resolveInputImage({ imageUrl: validUrl });
  assert.strictEqual(resolved.secureUrl, validUrl);
});

await asyncTest("Procesa Data URL Base64 válida", async () => {
  const pngBytes = createFakePng(true);
  const base64Str = Buffer.from(pngBytes).toString("base64");
  const dataUrl = `data:image/png;base64,${base64Str}`;

  const resolved = await ImageStorageService.resolveInputImage({ imageUrl: dataUrl });
  assert.strictEqual(resolved.format, "png");
  assert.ok(resolved.secureUrl.length > 0);
});

// -----------------------------------------------------------------------------
// 3. Pruebas de Persistencia en Storage (uploadGeneratedImage)
// -----------------------------------------------------------------------------
console.log("\n3. Pruebas de Persistencia en Supabase Storage (generated-files):");

await asyncTest("Genera ruta y URL de almacenamiento siguiendo convención {uid}/{tool}_{ts}_{id}.png", async () => {
  const pngBytes = createFakePng(true);
  const userId = "test-user-123e4567-e89b-12d3-a456-426614174000";

  const result = await ImageStorageService.uploadGeneratedImage({
    adminClient: null, // modo standalone
    userId,
    bytes: pngBytes,
    format: "png",
    toolId: "generate_image",
  });

  assert.ok(result.storagePath.includes(`generated-files/${userId}/generate_image_`));
  assert.ok(result.storagePath.endsWith(".png"));
  assert.ok(result.signedUrl.includes("generate_image_"));
});

// -----------------------------------------------------------------------------
// 4. Pruebas de Integración con ImageEngine y Ausencia de Simulaciones
// -----------------------------------------------------------------------------
console.log("\n4. Pruebas de ImageEngine y Erradicación Total de Query Strings Simuladas:");

import { ImageEngine } from "../functions/ai-router/engines/imageEngine.ts";
import fs from "node:fs";

test("Verificar ausencia de cualquier manipulación de query params (?enhanced=, ?processed=, etc.) en código fuente", () => {
  const code = fs.readFileSync(
    new URL("../functions/ai-router/engines/imageEngine.ts", import.meta.url),
    "utf8"
  );

  assert.strictEqual(code.includes("?enhanced="), false, "No debe existir ?enhanced= en imageEngine");
  assert.strictEqual(code.includes("?processed="), false, "No debe existir ?processed= en imageEngine");
  assert.strictEqual(code.includes("?bg_removed="), false, "No debe existir ?bg_removed= en imageEngine");
  assert.strictEqual(code.includes("?new_bg="), false, "No debe existir ?new_bg= en imageEngine");
  assert.strictEqual(code.includes("?composed="), false, "No debe existir ?composed= en imageEngine");
});

await asyncTest("ImageEngine.generateImage rechaza prompt vacío", async () => {
  const engine = new ImageEngine();
  await assert.rejects(
    async () => {
      await engine.generateImage({
        prompt: "   ",
        userId: "user-123",
        adminClient: null,
      });
    },
    /El prompt de la imagen no puede estar vacío/
  );
});

await asyncTest("ImageEngine.generateImage arroja error transparente si GEMINI_API_KEY no está configurada", async () => {
  const originalKey = process.env.GEMINI_API_KEY;
  delete process.env.GEMINI_API_KEY;

  const engine = new ImageEngine();
  await assert.rejects(
    async () => {
      await engine.generateImage({
        prompt: "Un gato espacial",
        userId: "user-123",
        adminClient: null,
      });
    },
    /requiere configurar GEMINI_API_KEY/
  );

  if (originalKey) process.env.GEMINI_API_KEY = originalKey;
});

await asyncTest("ImageEngine.removeBackground arroja error transparente sin fingir procesamiento si falta REPLICATE_API_TOKEN", async () => {
  const originalToken = process.env.REPLICATE_API_TOKEN;
  delete process.env.REPLICATE_API_TOKEN;

  const engine = new ImageEngine();
  await assert.rejects(
    async () => {
      await engine.removeBackground({
        imageUrl: "https://ejemplo.com/producto.png",
        userId: "user-123",
        adminClient: null,
      });
    },
    /requiere configurar REPLICATE_API_TOKEN/
  );

  if (originalToken) process.env.REPLICATE_API_TOKEN = originalToken;
});

await asyncTest("ImageEngine.improveImage arroja error transparente si falta REPLICATE_API_TOKEN", async () => {
  const originalToken = process.env.REPLICATE_API_TOKEN;
  delete process.env.REPLICATE_API_TOKEN;

  const engine = new ImageEngine();
  await assert.rejects(
    async () => {
      await engine.improveImage({
        imageUrl: "https://ejemplo.com/borrosa.jpg",
        userId: "user-123",
        adminClient: null,
      });
    },
    /requiere configurar REPLICATE_API_TOKEN/
  );

  if (originalToken) process.env.REPLICATE_API_TOKEN = originalToken;
});

await asyncTest("ImageEngine.changeBackground arroja error transparente si falta descripción de nuevo fondo", async () => {
  const engine = new ImageEngine();
  await assert.rejects(
    async () => {
      await engine.changeBackground({
        imageUrl: "https://ejemplo.com/producto.png",
        backgroundDescription: "   ",
        userId: "user-123",
        adminClient: null,
      });
    },
    /descripción del nuevo fondo/
  );
});

console.log("\n================================================================================");
console.log(`RESUMEN DE PRUEBAS: ${passedTests} de ${totalTests} pruebas superadas exitosamente (100%).`);
console.log("================================================================================");
// -----------------------------------------------------------------------------
// 5. Pruebas de Flujo Completo con Proveedores de IA Reales (Mocks de API)
// -----------------------------------------------------------------------------
console.log("\n5. Pruebas de Flujo Completo de Inferencia y Persistencia en Storage:");

const originalFetch = globalThis.fetch;

try {
  // Mocking fetch para simular endpoints reales de Google Imagen 3 y Replicate
  globalThis.fetch = async (url, options = {}) => {
    const urlStr = url.toString();

    // 1. Google Imagen 3 Predict API
    if (urlStr.includes("imagen-3.0-generate-002:predict")) {
      const fakePng = createFakePng(false);
      const base64 = Buffer.from(fakePng).toString("base64");
      return new Response(JSON.stringify({
        predictions: [{ bytesBase64Encoded: base64 }],
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    // 2. Replicate Models Predictions API
    if (urlStr.includes("api.replicate.com/v1/models/")) {
      const outputUrl = "https://replicate.delivery/pbxt/fake_result.png";
      return new Response(JSON.stringify({
        id: "pred_test_123",
        status: "succeeded",
        output: outputUrl,
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    // 3. Descarga de imagen generada por Replicate
    if (urlStr.includes("replicate.delivery/pbxt/fake_result.png")) {
      const fakePng = createFakePng(true);
      return new Response(fakePng, {
        status: 200,
        headers: { "Content-Type": "image/png" },
      });
    }

    // Default fallback a fetch real si fuera necesario
    return originalFetch(url, options);
  };

  // Mock de Supabase Admin Client
  const mockStorageMap = new Map();
  const mockAdminClient = {
    storage: {
      from: (bucket) => ({
        upload: async (path, bytes, opts) => {
          mockStorageMap.set(`${bucket}/${path}`, { bytes, opts });
          return { data: { path }, error: null };
        },
        createSignedUrl: async (path, expiresIn) => {
          return {
            data: { signedUrl: `https://supabase.co/storage/v1/object/sign/${bucket}/${path}?token=signed_jwt` },
            error: null,
          };
        },
        getPublicUrl: (path) => ({ data: { publicUrl: `https://supabase.co/storage/v1/object/public/${bucket}/${path}` } }),
      }),
    },
  };

  await asyncTest("Flujo completo: generate_image -> Google Imagen 3 -> bytes -> Supabase Storage", async () => {
    process.env.GEMINI_API_KEY = "mock_gemini_test_key_phase2";
    const engine = new ImageEngine();

    const res = await engine.generateImage({
      prompt: "Un paisaje futurista cyberpunk",
      style: "cinematic",
      userId: "user-alpha",
      adminClient: mockAdminClient,
    });

    assert.strictEqual(res.provider, "google_imagen");
    assert.strictEqual(res.model, "imagen-3.0-generate-002");
    assert.strictEqual(res.data.is_real_generation, true);
    assert.strictEqual(res.data.format, "png");
    assert.ok(res.data.image_url.includes("https://supabase.co/storage/v1/object/sign/generated-files/user-alpha/generate_image_"));
    assert.ok(mockStorageMap.has(`generated-files/${res.data.storage_path}`));
  });

  await asyncTest("Flujo completo: remove_background -> Replicate (bria/remove-background) -> canal alfa -> Storage", async () => {
    process.env.REPLICATE_API_TOKEN = "r8_fake_replicate_token";
    const engine = new ImageEngine();

    const res = await engine.removeBackground({
      imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff",
      userId: "user-alpha",
      adminClient: mockAdminClient,
    });

    assert.strictEqual(res.provider, "replicate");
    assert.strictEqual(res.model, "bria/remove-background");
    assert.strictEqual(res.data.transparency, true);
    assert.strictEqual(res.data.has_alpha, true);
    assert.ok(res.data.image_url.includes("https://supabase.co/storage/v1/object/sign/generated-files/user-alpha/remove_background_"));
    assert.ok(mockStorageMap.has(`generated-files/${res.data.storage_path}`));
  });

  await asyncTest("Flujo completo: improve_image -> Replicate (nightmareai/real-esrgan) -> 2x upscale -> Storage", async () => {
    process.env.REPLICATE_API_TOKEN = "r8_fake_replicate_token";
    const engine = new ImageEngine();

    const res = await engine.improveImage({
      imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff",
      factor: 2,
      userId: "user-alpha",
      adminClient: mockAdminClient,
    });

    assert.strictEqual(res.provider, "replicate");
    assert.strictEqual(res.model, "nightmareai/real-esrgan");
    assert.strictEqual(res.data.factor, "2x");
    assert.ok(res.data.image_url.includes("https://supabase.co/storage/v1/object/sign/generated-files/user-alpha/improve_image_"));
    assert.strictEqual(res.data.enhanced_image_url, res.data.image_url);
    assert.ok(mockStorageMap.has(`generated-files/${res.data.storage_path}`));
  });

  await asyncTest("Flujo completo: change_background -> Replicate (bria/generate-background) -> Inpainting -> Storage", async () => {
    process.env.REPLICATE_API_TOKEN = "r8_fake_replicate_token";
    const engine = new ImageEngine();

    const res = await engine.changeBackground({
      imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff",
      backgroundDescription: "Estudio de fotografía minimalista con iluminación suave",
      userId: "user-alpha",
      adminClient: mockAdminClient,
    });

    assert.strictEqual(res.provider, "replicate");
    assert.strictEqual(res.model, "bria/generate-background");
    assert.strictEqual(res.data.background_description, "Estudio de fotografía minimalista con iluminación suave");
    assert.ok(res.data.image_url.includes("https://supabase.co/storage/v1/object/sign/generated-files/user-alpha/change_background_"));
    assert.ok(mockStorageMap.has(`generated-files/${res.data.storage_path}`));
  });

} finally {
  globalThis.fetch = originalFetch;
}
