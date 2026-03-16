# Security

This guide covers security considerations when using the Zstandard plugin and CLI: input validation, handling untrusted data, memory safety, and how to report vulnerabilities.

## Input validation

### Compression

- **Input data**: The plugin accepts `Uint8List` for compression. No inherent size limit is enforced by the API; very large inputs may cause high memory usage or platform-specific limits. Validate or cap input size in your application when processing user-controlled data.
- **Compression level**: Valid levels are **1–22**. Levels outside this range may be accepted by some implementations but can produce non-portable or unexpected behaviour. Always validate the level (e.g. clamp to 1–22) before calling `compress`.

```dart
int safeLevel(int level) {
  if (level < 1) return 1;
  if (level > 22) return 22;
  return level;
}
final compressed = await zstandard.compress(data, safeLevel(userLevel));
```

### Decompression

- **Untrusted compressed data**: Data that is not a valid Zstandard frame (random bytes, truncated data, or crafted payloads) will typically result in a **null** return from `decompress`, not an exception. The native zstd library is designed to fail safely on invalid input.
- **Bomb resistance**: Zstandard frames contain size information; the library uses bounded memory during decompression. Very large stored sizes in a malicious frame could still lead to large allocations. Prefer validating or limiting input size when decompressing data from untrusted sources.

## Handling untrusted data

When decompressing data from untrusted sources (network, user uploads, third-party files):

1. **Check for null**: Always treat a null result as failure and do not use the result.

```dart
final decompressed = await zstandard.decompress(receivedBytes);
if (decompressed == null) {
  // Invalid or malicious input; reject
  return;
}
// Only use decompressed after null check
```

2. **Limit input size**: Reject or refuse to decompress payloads above a size you are willing to allocate (e.g. cap at 10 MB or 100 MB depending on your use case).

3. **Validate after decompression**: If the decompressed data has a known format (JSON, protocol buffer, etc.), validate it before use. The plugin only guarantees that the bytes are a valid zstd decompression result, not that the content is safe for your application.

4. **Avoid trusting compressed size blindly**: If you expose decompressed size or progress to users, ensure it comes from the library’s result (e.g. length of the returned `Uint8List`) rather than from unvalidated metadata.

## Memory safety

- **Native code**: The plugin uses the official Zstandard C library via FFI (and WebAssembly on web). The library is widely used and maintained; buffer overflows and similar issues in zstd are addressed by upstream.
- **Dart/Flutter**: The Dart API uses `Uint8List`; no raw pointers are exposed. Memory is managed by the Dart VM and the native allocator used by zstd.
- **Large allocations**: Compression and decompression allocate memory proportional to input and output. To avoid out-of-memory conditions, limit input size and consider processing large files in chunks if supported by your workflow (see [Advanced usage](advanced-usage.md)).

## Vulnerability reporting

If you discover a security vulnerability in this plugin, its dependencies, or the way it uses the Zstandard library:

1. **Do not** open a public GitHub issue for security-sensitive findings.
2. Report privately to the maintainers (e.g. via the repository’s contact or security policy, if stated).
3. Include a clear description, steps to reproduce, and impact if possible.
4. Allow a reasonable time for a fix before any public disclosure.

For issues in the **upstream Zstandard library** (Facebook/Meta), follow the [Zstandard project’s security policy](https://github.com/facebook/zstd/security).

## See also

- [Error handling](error-handling.md) — null semantics and failure handling
- [Advanced usage](advanced-usage.md) — large data and memory considerations
- [Best practices](best-practices.md) — production checklist
