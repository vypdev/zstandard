# Main API Reference

The main package **zstandard** exposes a single public class and re-exports the extension methods. Applications should only depend on this package.

## Zstandard Class

**Library:** `package:zstandard/zstandard.dart`

### Constructor

```dart
factory Zstandard()
```

Creates or returns the singleton instance. Use this to obtain the shared `Zstandard` instance.

**Example:**

```dart
final zstandard = Zstandard();
```

### Instance Property

```dart
ZstandardPlatform get instance
```

Returns the currently registered platform implementation. Typically you do not need to access this; use `compress` and `decompress` on the `Zstandard` instance instead. Useful for testing (mock the platform) or for calling `getPlatformVersion`.

### getPlatformVersion

```dart
Future<String?> getPlatformVersion()
```

Returns a platform-specific version or identifier string (e.g. for display or debugging). May be `null` if the platform does not provide one.

### compress

```dart
Future<Uint8List?> compress(Uint8List data, int compressionLevel)
```

Compresses `data` using Zstandard with the given `compressionLevel`.

- **data**: Raw bytes to compress. Can be any length; empty input is allowed (behavior is platform-dependent).
- **compressionLevel**: Integer from **1** (fastest, least compression) to **22** (slowest, best compression). Default in extensions is **3**.
- **Returns**: Compressed bytes as `Uint8List`, or `null` if compression failed.

**Example:**

```dart
final zstandard = Zstandard();
final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
final compressed = await zstandard.compress(bytes, 3);
if (compressed != null) {
  // use compressed
}
```

### decompress

```dart
Future<Uint8List?> decompress(Uint8List data)
```

Decompresses Zstandard-compressed `data`.

- **data**: Bytes produced by `compress` (or any valid zstd frame).
- **Returns**: Decompressed bytes as `Uint8List`, or `null` if decompression failed (e.g. invalid or corrupted input).

**Example:**

```dart
final decompressed = await zstandard.decompress(compressed!);
if (decompressed != null) {
  // use decompressed
}
```

## Compression Levels

| Level | Typical use      | Speed   | Ratio   |
|-------|------------------|--------|--------|
| 1     | Real-time, low latency | Fastest | Lower  |
| 3     | Default balance  | Fast   | Good   |
| 10–19 | High compression | Slower | Higher |
| 20–22 | Maximum ratio    | Slowest | Best   |

Invalid levels (e.g. &lt; 1 or &gt; 22) may be accepted or rejected depending on the platform; avoid them for portability.

## Threading and Performance

- All methods return `Future`s. Heavy work may be offloaded to a background isolate on native platforms to avoid blocking the UI.
- For large data, prefer using the main plugin API (which can use isolates) rather than blocking the main thread.

## See Also

- [Extensions](extensions.md) — `compress` and `decompress` on `Uint8List?`
- [Platform Interface](platform-interface.md) — Contract implemented by each platform
- [Compression Levels Guide](../guides/compression-levels.md)
