# Platform Interface API Reference

`zstandard_platform_interface` defines the federated plugin contract.
Applications should use the main `zstandard` package.

## `ZstandardPlatform`

Implementations extend `ZstandardPlatform`, provide `getPlatformVersion`,
`compress`, and the legacy-compatible `decompress`, then register themselves:

```dart
ZstandardPlatform.instance = MyZstandardPlatform();
```

The default `MethodChannelZstandardPlatform` only implements platform-version
lookup. Codec operations throw `UnimplementedError` until an implementation is
registered.

## Bounded decompression capability

New and official implementations should additionally implement:

```dart
abstract interface class BoundedZstandardPlatform {
  Future<Uint8List?> decompressWithOptions(
    Uint8List data, {
    int maxOutputSize = ZstandardPlatform.defaultMaxDecompressedSize,
  });
}
```

`ZstandardPlatform.defaultMaxDecompressedSize` is 256 MiB. Implementations
must enforce the limit during decompression, not only after allocating the
result. Keeping this as a separate optional interface avoids a source-breaking
method addition for existing third-party platform implementations.

The main package uses the bounded capability when present. Its compatibility
fallback calls legacy `decompress` and rejects an oversized returned value,
but cannot prevent the third-party implementation's earlier allocation.

See [Platform interface architecture](../architecture/platform-interface.md).
