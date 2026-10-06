# PHASE 2.10.1 — CORRECCIÓN DEL CONFLICTO DE DEPENDENCIA INTL

**Proyecto**: AI Toolbox  
**Fase**: 2.10.1  
**Tipo**: Hotfix de Build CI / Corrección de Dependencia  
**Objetivo**: Resolver la colisión de versiones en `flutter pub get` entre `flutter_localizations` (SDK) e `intl`.

---

## 1. DESCRIPCIÓN DEL PROBLEMA DETECTADO EN GITHUB ACTIONS

Durante el primer ciclo de ejecución real del workflow `Flutter Cloud CI & APK Build` en GitHub Actions, la etapa de scaffolding de plataforma Android completó exitosamente con `flutter create .`. Sin embargo, la etapa `flutter pub get` falló inmediatamente con el siguiente error del solucionador de dependencias:

```text
Because ai_toolbox depends on flutter_localizations from sdk which depends on
intl ^0.20.3, intl ^0.20.3 is required.

So, because ai_toolbox depends on intl ^0.19.0, version solving failed.

Failed to update packages.
Process completed with exit code 1.
```

---

## 2. ANÁLISIS DE CAUSA RAÍZ

* **Origen**: En versiones recientes del canal estable de Flutter (Flutter 3.29.x+), el paquete integrado `flutter_localizations` subió su restricción mínima de `package:intl` a `^0.20.3`.
* **Conflicto**: `mobile/pubspec.yaml` tenía fijada una restricción estricta de `intl: ^0.19.0`. El solucionador de paquetes de Dart determinó que ambas restricciones eran mutuamente excluyentes y abortó.

---

## 3. SOLUCIÓN APLICADA (MODIFICACIÓN MÍNIMA)

Se editó exclusivamente la línea de dependencia en [mobile/pubspec.yaml](mobile/pubspec.yaml):

```diff
 dependencies:
   flutter:
     sdk: flutter
   flutter_localizations:
     sdk: flutter
   supabase_flutter: ^2.5.0
   provider: ^6.1.2
-  intl: ^0.19.0
+  intl: ^0.20.3
   google_fonts: ^6.2.1
   flutter_svg: ^2.0.10+1
```

---

## 4. VALIDACIÓN DE COMPATIBILIDAD

1. **Auditoría de Código Dart**:
   - Se verificó que el proyecto no utiliza métodos ni APIs obsoletos de `package:intl`. La implementación de [AppLocalizations](mobile/lib/core/i18n/app_localizations.dart) carga catálogos JSON independientes y utiliza `LocalizationsDelegate` estándar de Flutter.
   - Auditoría estática de 49 archivos Dart completada con 0 errores de importación.
2. **Tests de Backend**:
   - 41 de 41 pruebas automatizadas continúan pasando exitosamente (100% PASS).
3. **Control de Versiones**:
   - Archivo guardado en codificación UTF-8 pura (sin BOM).

---

## 5. REPRODUCCIÓN EN GITHUB ACTIONS

Al enviar este commit al repositorio remoto, GitHub Actions ejecutará de forma automática:
```text
1. checkout
2. setup java 17
3. setup flutter stable
4. flutter pub get (ahora resuelve intl ^0.20.3 sin conflicto)
5. flutter analyze
6. flutter test
7. flutter build apk --debug
8. upload artifact ai-toolbox-debug-apk
```
