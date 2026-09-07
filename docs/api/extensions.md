# Extensions API Reference

Import `package:zstandard/zstandard.dart` to add these methods to
`Uint8List?`. A null receiver returns `null` without invoking a platform.

```dart
Future<Uint8List?> compress({int compressionLevel = 3})

Future<Uint8List?> decompress({
  int maxOutputSize = Zstandard.defaultMaxDecompressedSize,
})
```

The methods have the same behavior as `Zstandard.compress` and
`Zstandard.decompress`. In particular, decompression defaults to a 256 MiB
output limit and supports unknown-size and concatenated frames.

```dart
final compressed = await data.compress(compressionLevel: 5);
final original = await compressed.decompress(maxOutputSize: 8 * 1024 * 1024);
if (original == null) {
  // Null receiver, invalid input, output-limit violation, or codec failure.
}
```

See the [main API](main-api.md) for the execution and error contract.
