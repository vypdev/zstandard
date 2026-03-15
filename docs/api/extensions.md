# Extensions API Reference

The **zstandard** package adds extension methods on `Uint8List?` so you can call `compress` and `decompress` directly on byte data.

## Import

```dart
import 'package:zstandard/zstandard.dart';
```

The extensions are exported from the main library.

## ZstandardExt on Uint8List?

Extension on nullable `Uint8List`. If the receiver is `null`, both methods return `null` without calling the platform.

### compress

```dart
Future<Uint8List?> compress({int compressionLevel = 3})
```

Compresses this byte list using the default (or specified) compression level.

- **compressionLevel**: Optional; defaults to **3**. Range 1–22.
- **Returns**: Compressed bytes, or `null` if the receiver is `null` or compression failed.

**Example:**

```dart
final data = Uint8List.fromList([10, 20, 30, 40, 50]);
final compressed = await data.compress();
final compressedHigh = await data.compress(compressionLevel: 10);
```

### decompress

```dart
Future<Uint8List?> decompress()
```

Decompresses this byte list, which must be Zstandard-compressed data.

- **Returns**: Decompressed bytes, or `null` if the receiver is `null` or decompression failed.

**Example:**

```dart
final compressed = await data.compress(compressionLevel: 3);
final decompressed = await compressed?.decompress();
```

## Null Safety

- On `null` receiver, `compress()` and `decompress()` return `null` and do not throw.
- Always check the result for `null` when the source might be null or when the operation can fail.

**Example:**

```dart
Uint8List? maybeData = ...;
final compressed = await maybeData.compress();
if (compressed != null) {
  final back = await compressed.decompress();
}
```

## See Also

- [Main API](main-api.md) — `Zstandard` class
- [Usage Examples](../guides/usage-examples.md)
