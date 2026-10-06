import fs from "node:fs";
import path from "node:path";

const mobileLib = "c:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/lib";
const mobileTest = "c:/Users/si/.gemini/antigravity/scratch/ai_toolbox/mobile/test";
let totalDartFiles = 0;
let errors = 0;

function scan(dir) {
  if (!fs.existsSync(dir)) return;
  for (const item of fs.readdirSync(dir)) {
    const full = path.join(dir, item);
    if (fs.statSync(full).isDirectory()) {
      scan(full);
    } else if (item.endsWith(".dart")) {
      totalDartFiles++;
      const content = fs.readFileSync(full, "utf8");
      const lines = content.split("\n");
      for (const line of lines) {
        const match = line.match(/^import\s+['"](\.\.?\/[^'"]+)['"];/);
        if (match) {
          const relTarget = match[1];
          const absTarget = path.normalize(path.join(path.dirname(full), relTarget));
          if (!fs.existsSync(absTarget)) {
            console.error("Broken import in " + full + ": " + relTarget);
            errors++;
          }
        }
      }
    }
  }
}

scan(mobileLib);
scan(mobileTest);
console.log(`Total archivos Dart auditados: ${totalDartFiles}`);
console.log(`Errores de importación detectados: ${errors}`);
if (errors === 0) {
  console.log("✓ Todos los imports relativos en mobile/lib y mobile/test resuelven correctamente a archivos existentes en disco.");
}
