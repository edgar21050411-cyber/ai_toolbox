import fs from "node:fs";

const envDart = fs.readFileSync("mobile/lib/core/config/environment.dart", "utf8");
const supaDart = fs.readFileSync("mobile/lib/core/config/supabase_config.dart", "utf8");

console.log("=== VERIFICACION REGLA 6: DART-DEFINE Y PLACEHOLDERS ===");

console.log("\n1. Verificando ausencia de placeholders:");
const hasDevPlaceholder = envDart.includes("dev.supabase.co") || supaDart.includes("dev.supabase.co");
const hasXyzPlaceholder = envDart.includes("xyzcompany") || supaDart.includes("xyzcompany");

console.log("  - dev.supabase.co:", hasDevPlaceholder ? "DETECTADO (FALLO)" : "ELIMINADO (PASS)");
console.log("  - xyzcompany.supabase.co:", hasXyzPlaceholder ? "DETECTADO (FALLO)" : "ELIMINADO (PASS)");

console.log("\n2. Verificando lectura compilada de variables via dart-define:");
const readsUrl = envDart.includes("String.fromEnvironment('SUPABASE_URL')");
const readsKey = envDart.includes("String.fromEnvironment('SUPABASE_ANON_KEY')");
const readsEnv = envDart.includes("String.fromEnvironment('ENVIRONMENT')");

console.log("  - String.fromEnvironment('SUPABASE_URL'):", readsUrl ? "PASS" : "FAIL");
console.log("  - String.fromEnvironment('SUPABASE_ANON_KEY'):", readsKey ? "PASS" : "FAIL");
console.log("  - String.fromEnvironment('ENVIRONMENT'):", readsEnv ? "PASS" : "FAIL");

console.log("\n3. Verificando construccion dinamica de apiBaseUrl:");
const buildsDynamicApi = envDart.includes("/functions/v1");
console.log("  - Construccion dinamica de apiBaseUrl:", buildsDynamicApi ? "PASS" : "FAIL");

if (!hasDevPlaceholder && !hasXyzPlaceholder && readsUrl && readsKey && readsEnv && buildsDynamicApi) {
  console.log("\n========================================================");
  console.log("✓ VERIFICACION EXITOSA: La aplicacion opera 100% via dart-define.");
  console.log("========================================================");
  process.exit(0);
} else {
  console.error("\n❌ Error en la verificacion.");
  process.exit(1);
}
