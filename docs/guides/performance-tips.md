# Performance Tips

Suggestions to get the best performance and resource usage when using the Zstandard plugin and CLI.

## Compression level

- Use **level 1–3** when speed matters (e.g. real-time, interactive). Level 3 is the default and is a good balance.
- Use **level 10+** only when you care more about size than speed (e.g. one-off backups, archival). Higher levels use more CPU and memory.

## Data size

- **Small data** (e.g. &lt; 100 bytes): Compression may not reduce size (zstd has frame overhead). Consider skipping compression for very small payloads.
- **Large data**: The plugin may use a background isolate on native platforms to avoid blocking the UI. For very large inputs (e.g. tens of MB), consider **chunking**: compress chunks and store/transmit separately, or use streaming if the API supports it in the future.
- **Empty data**: Handled quickly; no need to avoid.

## Memory

- Compress and decompress allocate buffers (input + output). For very large inputs, peak memory is roughly proportional to input size plus compressed/decompressed size. Chunking reduces peak usage.
- On native platforms, work may run in an isolate; the main isolate only holds the input and result bytes, which helps keep UI responsive.

## Reuse

- **Zstandard()** is a singleton; reusing it is efficient. No need to cache the instance yourself.
- **ZstandardCLI()**: Creating a new instance is cheap; the underlying native library is loaded once per process.

## Platform-specific

- **Web**: No isolates; compression/decompression run on the main thread. For large data on web, consider chunking or moving work to a Web Worker if you implement it.
- **Native (Android, iOS, macOS, Linux, Windows)**: The implementation may offload work to an isolate; you get non-blocking behavior without extra code.

## Measuring

- Use `Stopwatch` or your preferred profiler to measure compress/decompress time for your typical payload sizes and levels.
- Use the Dart DevTools or platform tools to observe memory usage if you suspect high allocation.

## See also

- [Compression levels](compression-levels.md)
- [Architecture — Isolate pattern](../architecture/isolate-pattern.md)
