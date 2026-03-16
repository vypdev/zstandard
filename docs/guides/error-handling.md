# Error Handling

This guide describes how errors and edge cases are represented when using the Zstandard plugin and CLI, and how to handle them in your code.

## Null as failure

The main plugin and CLI return `Future<Uint8List?>` for compress and decompress. A **null** result means the operation failed (e.g. compression error, corrupted or invalid input for decompression).

Always check for null before using the result:

```dart
final compressed = await zstandard.compress(data, 3);
if (compressed == null) {
  // Compression failed; log or show an error
  return;
}

final decompressed = await zstandard.decompress(compressed);
if (decompressed == null) {
  // Decompression failed; data may be corrupted or not zstd
  return;
}
```

## Extension methods and null

- Calling `compress()` or `decompress()` on a **null** `Uint8List?` returns **null** (no throw).
- If the underlying operation fails, the Future completes with **null**.

```dart
Uint8List? maybeData = ...;
final compressed = await maybeData.compress(); // null if maybeData is null
final decompressed = await compressed?.decompress(); // null if compressed is null or decompress fails
```

## Invalid input

- **Decompression**: Passing data that is not a valid Zstandard frame (e.g. random bytes, truncated data) typically results in a **null** return. The plugin does not throw in this case.
- **Compression**: Invalid compression level (e.g. out of range) may or may not be validated by the implementation; behavior can differ by platform. Use levels 1–22 for portability.

## Exceptions

- **UnimplementedError**: Thrown by the default platform implementation (method channel) when `compress` or `decompress` is called without a registered native implementation. In normal use with the full plugin and a supported platform, this should not occur.
- **MissingPluginException**: Can occur if the method channel is used but no implementation is registered (e.g. in tests). Register a mock platform or the real implementation to avoid it.
- **DynamicLibrary loading**: On native platforms, if the zstd library fails to load, the first FFI call may throw. Ensure the app is built and run on a supported platform/architecture.

## Best practices

1. **Check null** after every `compress` and `decompress` when failure is possible.
2. **Use null-safe chains** with extensions: `compressed?.decompress()`.
3. **Log or report** null results in production (e.g. analytics, user message) instead of ignoring them.
4. **Validate input** when it comes from untrusted sources (e.g. file upload); invalid data will usually yield null on decompress.

## See also

- [API — Main](../api/main-api.md)
- [Troubleshooting — Common issues](../troubleshooting/common-issues.md)
