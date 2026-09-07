# Main API Reference

Applications should import `package:zstandard/zstandard.dart`. It exposes the
cross-platform `Zstandard` singleton and the `Uint8List?` extensions.

## `Zstandard`

```dart
factory Zstandard()
```

Returns the process singleton. `instance` exposes the registered platform
implementation for diagnostics and tests; application code normally calls the
methods below.

### `compress`

```dart
Future<Uint8List?> compress(Uint8List data, int compressionLevel)
```

Creates one valid zstd frame. Empty input is supported. Levels 1–22 are
portable across the official implementations; an invalid level or codec
failure returns `null`.

### `decompress`

```dart
Future<Uint8List?> decompress(
  Uint8List data, {
  int maxOutputSize = Zstandard.defaultMaxDecompressedSize,
})
```

Decompresses complete zstd input, including concatenated frames and frames
without a declared content size. The default maximum output is 256 MiB.
Malformed, truncated, empty, or oversized input returns `null`.

Official platforms enforce the limit while producing output, before an
oversized result can be allocated. For source compatibility, third-party
platform implementations that only implement the original `decompress`
method are post-checked; their allocation cannot be bounded by the main
package. Such implementations should add `BoundedZstandardPlatform` before
handling untrusted data.

Choose a smaller budget whenever the application has a known protocol limit:

```dart
final decompressed = await Zstandard().decompress(
  compressed,
  maxOutputSize: 8 * 1024 * 1024,
);
if (decompressed == null) {
  // Invalid/truncated frame, codec error, or more than 8 MiB of output.
}
```

### `getPlatformVersion`

```dart
Future<String?> getPlatformVersion()
```

Returns a platform identifier intended for diagnostics, or `null` when it is
not available.

## Execution model

The official native implementations run byte-oriented codec work in a worker
isolate. The web implementation sends it to a dedicated Web Worker. Results
are asynchronous and `null` represents an expected operation failure; setup
errors such as using an unsupported platform can still throw.

See [Extensions](extensions.md), [Platform interface](platform-interface.md),
and [Security](../guides/security.md).
