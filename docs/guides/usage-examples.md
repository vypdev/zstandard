# Usage Examples

This page shows common usage patterns for the Zstandard plugin and CLI.

## Flutter: compress and decompress

```dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:zstandard/zstandard.dart';

Future<void> roundtrip() async {
  final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
  final z = Zstandard();

  final compressed = await z.compress(data, 3);
  if (compressed == null) return;

  final decompressed = await z.decompress(compressed);
  assert(decompressed != null && listEquals(data, decompressed!));
}
```

## Using extensions

```dart
final data = Uint8List.fromList([1, 2, 3, 4, 5]);
final compressed = await data.compress(compressionLevel: 5);
final decompressed = await compressed?.decompress();
```

## Different compression levels

```dart
final data = Uint8List.fromList(List.filled(10000, 42));

// Fast, less compression
final fast = await data.compress(compressionLevel: 1);

// Default balance
final balanced = await data.compress(compressionLevel: 3);

// High compression
final high = await data.compress(compressionLevel: 19);
```

## Handling null and errors

```dart
Uint8List? compressSafely(Uint8List? input) async {
  if (input == null) return null;
  final compressed = await input.compress(compressionLevel: 3);
  return compressed; // may be null on failure
}

void example() async {
  final compressed = await compressSafely(someData);
  if (compressed != null) {
    final back = await compressed.decompress();
    if (back != null) {
      // use back
    }
  }
}
```

## CLI in code

```dart
import 'package:zstandard_cli/zstandard_cli.dart';

void main() async {
  final cli = ZstandardCLI();
  final data = Uint8List.fromList([1, 2, 3, 4, 5]);
  final compressed = await cli.compress(data, compressionLevel: 3);
  final decompressed = await cli.decompress(compressed ?? Uint8List(0));
}
```

## File compression (conceptual)

Read file → compress → write; read compressed file → decompress → use:

```dart
import 'dart:io';
import 'package:zstandard/zstandard.dart';

Future<void> compressFile(File file, File outFile) async {
  final bytes = await file.readAsBytes();
  final compressed = await bytes.compress(compressionLevel: 3);
  if (compressed != null) {
    await outFile.writeAsBytes(compressed);
  }
}

Future<Uint8List?> decompressFile(File file) async {
  final bytes = await file.readAsBytes();
  return bytes.decompress();
}
```

For production, use streaming or chunking for large files to control memory use.

## See also

- [API — Main](../api/main-api.md)
- [Compression levels](compression-levels.md)
- [Error handling](error-handling.md)
