# Platform Interface API Reference

The **zstandard_platform_interface** package defines the contract that every platform implementation (Android, iOS, macOS, Linux, Windows, Web) must satisfy. Application code typically uses the main **zstandard** package and does not depend on this package directly.

## ZstandardPlatform

**Library:** `package:zstandard_platform_interface/zstandard_platform_interface.dart`

Abstract base class for all platform implementations. Extends `PlatformInterface` from the plugin_platform_interface package.

### instance (static getter)

```dart
static ZstandardPlatform get instance
```

Returns the current platform implementation. Defaults to `MethodChannelZstandardPlatform`.

### instance (static setter)

```dart
static set instance(ZstandardPlatform instance)
```

Sets the platform implementation. Only instances created with the correct token (from this package) can be set. Platform packages call this in their `registerWith()`.

### getPlatformVersion

```dart
Future<String?> getPlatformVersion()
```

Returns a platform-specific version or identifier string. Base implementation throws `UnimplementedError`.

### compress

```dart
Future<Uint8List?> compress(Uint8List data, int compressionLevel)
```

Compresses `data` at the given `compressionLevel` (1–22). Base implementation throws `UnimplementedError`.

### decompress

```dart
Future<Uint8List?> decompress(Uint8List data)
```

Decompresses Zstandard-compressed `data`. Base implementation throws `UnimplementedError`.

---

## MethodChannelZstandardPlatform

Default implementation used when no native implementation is registered (e.g. in tests or unsupported platforms).

- **getPlatformVersion()**: Implemented; invokes the method channel `plugins.flutter.io/zstandard` with method `getPlatformVersion`.
- **compress()**: Not implemented; throws `UnimplementedError`.
- **decompress()**: Not implemented; throws `UnimplementedError`.

So in environments where only the method channel is available, only `getPlatformVersion` is usable unless a test sets a mock platform.

## Implementing the Interface

Platform packages:

1. Extend `ZstandardPlatform`.
2. Implement `getPlatformVersion`, `compress`, and `decompress`.
3. In registration, set `ZstandardPlatform.instance = MyPlatform()` (with the token from the interface).

See [Architecture — Platform Interface](../architecture/platform-interface.md) for the registration flow.

## See Also

- [Architecture — Platform Interface](../architecture/platform-interface.md)
- [Main API](main-api.md)
