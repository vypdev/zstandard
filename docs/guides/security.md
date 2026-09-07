# Security

## Treat output size as the primary decompression budget

Compressed input can expand dramatically. Every official implementation
therefore accepts `maxOutputSize` and defaults it to 256 MiB:

```dart
final decoded = await Zstandard().decompress(
  untrustedFrame,
  maxOutputSize: 8 * 1024 * 1024,
);
if (decoded == null) return rejectInput();
```

Native and Web implementations enforce the budget chunk-by-chunk with zstd's
streaming decoder, including for concatenated frames and frames whose content
size is unknown. Malformed, truncated, empty, or oversized input returns
`null`.

Set the lowest bound allowed by the application protocol. Also cap compressed
input size and concurrent operations: an output bound does not limit the bytes
already held as input, zstd's internal workspace, or the aggregate memory of
several simultaneous calls.

Third-party `ZstandardPlatform` implementations should implement
`BoundedZstandardPlatform`. The main package post-checks results from legacy
implementations for compatibility, but it cannot undo an oversized allocation
that a third-party decoder already made.

## Validate all external values

- Accept only compression levels 1–22. Official implementations return `null`
  outside this range.
- Treat `null` as operation failure; do not continue with fallback bytes that
  could be confused with authenticated content.
- Validate the decompressed application format, schema, lengths, and integrity.
  A valid zstd frame does not make JSON, images, archives, or protocol messages
  trustworthy.
- Authenticate data separately when integrity or origin matters. Compression
  is not encryption or authentication.

## Memory and execution safety

Public native APIs exchange Dart-owned `Uint8List` values with worker isolates;
native pointers are allocated, used, copied, and freed within the same isolate.
Deprecated pointer-level helpers are compatibility APIs and should not be used
for new code. Web transfers copied buffers to a dedicated Worker and frees WASM
allocations after copying each result.

Compression itself has no input-size limit. Large compression input and high
levels can consume substantial CPU and memory, so apply request, file, and
concurrency limits before invoking the codec.

## Vulnerability reporting

Do not disclose a suspected vulnerability in a public issue. Follow the
repository `SECURITY.md` and include a reproducer, affected versions, and impact
when possible. Upstream zstd vulnerabilities should also follow the
[upstream security policy](https://github.com/facebook/zstd/security).

See [Error handling](error-handling.md) and
[Best practices](best-practices.md).
