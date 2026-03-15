# iOS/macOS: uso de symlinks para zstd compartido

Este documento resume cómo funcionaría referenciar el `zstd/` del repo mediante **symlinks** en iOS y macOS, y qué limitaciones hay según la documentación y el código de CocoaPods.

## Objetivo

Tener una única copia de zstd en `zstd/` (raíz del repo) y que los pods de iOS y macOS la usen sin duplicar código. Dos opciones sin symlinks son: (1) rutas `../` en el podspec (CocoaPods **no** lo permite) y (2) script de sync que copia `zstd/` a `Classes/zstd/`.

## Cómo funcionaría con symlinks

### Estructura

1. **Un solo código fuente**: `zstd/` en la raíz del repo (como ahora).
2. **Symlinks dentro del pod**:
   - iOS: `zstandard_ios/ios/Classes/zstd` → symlink a `../../../zstd`.
   - macOS: `zstandard_macos/macos/Classes/zstd` → symlink a `../../../zstd`.

Desde la raíz del repo:

```bash
# iOS
ln -sfn ../../../zstd zstandard_ios/ios/Classes/zstd

# macOS
ln -sfn ../../../zstd zstandard_macos/macos/Classes/zstd
```

3. **Podspec**: Sin referencias a `..`; todo bajo el árbol del pod:

   - iOS: `s.source_files = 'Classes/zstd/**/*.c', 'Classes/zstd/**/*.h', 'Classes/*.swift'`.
   - macOS: mismo enfoque con los mismos paths relativos a `Classes/zstd/`.

4. **Compilación**: El compilador (clang) y Xcode **sí** siguen symlinks, así que los `.c`/`.h` se compilarían correctamente una vez que CocoaPods los incluya en el target.

### El problema: CocoaPods y el glob

CocoaPods usa **Ruby** para resolver los patrones de `source_files` (p. ej. `Classes/zstd/**/*`). En Ruby:

- **`Dir.glob('**/*')` no sigue symlinks por defecto** (comportamiento estándar de Ruby).
- Si `Classes/zstd` es un symlink a un directorio, muchos versiones de Ruby/CocoaPods **no** recorren su contenido al hacer el glob, por lo que la lista de archivos del pod puede quedar vacía o incompleta.

Referencias:

- [Stack Overflow: How can I symlink source directories into a Cocoapods pod?](https://stackoverflow.com/questions/74191623/how-can-i-symlink-source-directories-into-a-cocoapods-pod) — mismo problema: no se añaden los archivos al proyecto de Xcode.
- [CocoaPods PR #9451](https://github.com/CocoaPods/CocoaPods/pull/9451) — añade seguir symlinks **un nivel** con un patrón especial (`**{,/[^.]*/**}/*`). El PR está **abierto**, no mergeado en la rama estable.
- Documentación CocoaPods: [File patterns do not support traversing the parent directory (`..`)](https://guides.cocoapods.org/syntax/podspec.html).

Conclusión: **con CocoaPods actual, los symlinks a directorios no son fiables** para `source_files`: depende de la versión de Ruby y de CocoaPods, y en la práctica muchos usuarios ven que los archivos no se incluyen.

### Si en el futuro CocoaPods siguiera symlinks (p. ej. con un PR como el #9451)

- El flujo sería: crear el symlink `Classes/zstd` → `../../../zstd`, mantener el podspec con `Classes/zstd/**/*` y ejecutar un script (o `prepare_command` si se usara con fuentes descargadas) que cree el symlink.
- El script de sync actual podría **sustituir** la copia por la creación de symlinks:

  ```bash
  rm -rf "$IOS_ZSTD" "$MACOS_ZSTD"
  ln -s "$(cd "$ROOT" && pwd)/zstd" "$IOS_ZSTD"   # desde ios/Classes
  ln -s "$(cd "$ROOT" && pwd)/zstd" "$MACOS_ZSTD" # desde macos/Classes
  ```

- Tras eso, `pod install` y el build de Xcode usarían los mismos fuentes que el resto del repo.

## Git y symlinks en Windows

Si se commitearan los symlinks:

- En **Windows**, por defecto `git clone` **no** crea symlinks reales; crea un archivo de texto con la ruta del target. Quien clone en Windows podría no tener un directorio válido y el build podría fallar.
- Opciones:
  - Clonar con `git clone -c core.symlinks=true` (requiere permisos/Developer Mode en Windows).
  - **No** commitear los symlinks y crearlos en un script (p. ej. `sync_zstd_ios_macos.sh`) después de clonar; entonces solo afecta a desarrolladores que ejecuten el script (típicamente en macOS/Linux).

Referencias:

- [What happens when I clone a repository with symlinks on Windows?](https://stackoverflow.com/questions/11662868/what-happens-when-i-clone-a-repository-with-symlinks-on-windows)
- [Git for Windows - Symbolic Links](https://gitforwindows.org/symbolic-links.html)

## Automatización: script_phases en el podspec (before_compile / after_compile)

CocoaPods resuelve `source_files` en **pod install** (con un glob). Si en ese momento `Classes/zstd` no existe, la lista de archivos del target queda vacía. Por eso el sync debe ejecutarse **antes** de que CocoaPods haga el glob; en la práctica eso se hace en un **script_phase** con `execution_position => :before_compile`, que corre en cada compilación del target del pod (y así `Classes/zstd` existe cuando se compila).

Cada plataforma solo sincroniza y borra su propia copia:

- **iOS**: el podspec de `zstandard_ios` tiene una fase "Sync zstd" que ejecuta `scripts/sync_zstd_ios_macos.sh ios` (solo copia a `zstandard_ios/ios/Classes/zstd/`) y otra "Remove synced zstd" que borra esa carpeta tras compilar.
- **macOS**: el podspec de `zstandard_macos` hace lo mismo con `sync_zstd_ios_macos.sh macos` (solo copia a `zstandard_macos/macos/Classes/zstd/`) y borra su copia en after_compile.

El script acepta `ios`, `macos` o sin argumentos (sincroniza ambas plataformas, útil al ejecutarlo manualmente desde la raíz). No hace falta **pre_install** en el Podfile: el plugin se encarga del sync en sus script_phases.

## Recomendación práctica

- **Hoy**: Usar el **script de sync** que copia `zstd/` a `Classes/zstd/` solo para la plataforma que se está compilando (single source of truth en `zstd/`). Cada pod ejecuta el script con su plataforma en before_compile y borra su copia en after_compile; no se depende del Podfile.
- **Symlinks**: Solo serían una alternativa estable cuando CocoaPods soporte seguir symlinks en los globs y se defina cómo manejar Git en Windows.
