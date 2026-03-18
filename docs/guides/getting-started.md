# Getting Started

This guide gets you from zero to compressing and decompressing data with the Zstandard Flutter plugin in a few minutes.

## Add the dependency

In your Flutter app’s `pubspec.yaml`:

```yaml
dependencies:
  zstandard: ^1.4.0
```

Then run:

```bash
flutter pub get
```

## Basic usage

Import and use the main class:

```dart
import 'package:flutter/foundation.dart';
import 'package:zstandard/zstandard.dart';

void main() async {
  final zstandard = Zstandard();
  final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

  // Compress with default-like level (e.g. 3)
  final compressed = await zstandard.compress(data, 3);
  if (compressed == null) return; // handle failure

  // Decompress
  final decompressed = await zstandard.decompress(compressed);
  if (decompressed != null && listEquals(data, decompressed)) {
    print('Roundtrip OK');
  }
}
```

Or use the extension methods on `Uint8List?`:

```dart
final compressed = await data.compress(compressionLevel: 3);
final decompressed = await compressed?.decompress();
```

## Command-line (CLI)

For a pure Dart app on macOS, Windows, or Linux (no Flutter):

```yaml
dependencies:
  zstandard_cli: ^1.4.0
```

```dart
import 'package:zstandard_cli/zstandard_cli.dart';

void main() async {
  final data = Uint8List.fromList([1, 2, 3, 4, 5]);
  final compressed = await data.compress(compressionLevel: 3);
  final decompressed = await compressed?.decompress();
}
```

Or run the CLI from the shell:

```bash
dart run zstandard_cli:compress myfile.txt 3
dart run zstandard_cli:decompress myfile.txt.zstd
```

## Next steps

- [Installation](installation.md) — Platform-specific setup (e.g. web assets).
- [Usage examples](usage-examples.md) — More examples and patterns.
- [Compression levels](compression-levels.md) — Choose the right level for speed vs ratio.
- [API — Main](../api/main-api.md) — Full API reference.
