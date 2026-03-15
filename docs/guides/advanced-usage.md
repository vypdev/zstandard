# Advanced Usage

This guide covers patterns for large data, chunking, concurrent compression, and memory optimization when using the Zstandard plugin and CLI.

## Large file handling

The plugin API works on in-memory buffers: `compress(Uint8List)` and `decompress(Uint8List)`. For very large files, loading the entire file into memory may be impractical. Use **chunking**: process the file in fixed-size chunks and compress or decompress each chunk separately.

### Chunked compression

1. Read a chunk of the file (e.g. 256 KB or 1 MB).
2. Compress the chunk with `compress(chunk, level)`.
3. Store the compressed chunk (e.g. write length then bytes so you can read back later).
4. Repeat until the file is done.

```dart
Future<void> compressFileChunked(String path, String outPath, int chunkSize) async {
  final file = File(path);
  final out = File(outPath);
  final z = Zstandard();
  final data = await file.readAsBytes();
  final sink = out.openWrite();
  for (var offset = 0; offset < data.length;) {
    final end = (offset + chunkSize).clamp(0, data.length);
    final chunk = Uint8List.sublistView(data, offset, end);
    offset = end;
    final compressed = await z.compress(chunk, 3);
    if (compressed == null) throw Exception('Compression failed');
    // Write length (4 bytes) then data
    sink.add(ByteData(4)..setUint32(0, compressed.length, Endian.big)..buffer.asUint8List());
    sink.add(compressed);
  }
  await sink.close();
}
```

For very large files, avoid loading the whole file with `readAsBytes()`; instead read in a loop using `RandomAccessFile.read()` with a fixed buffer size and compress each chunk.

### Chunked decompression

If you stored chunks as [length, bytes, length, bytes, ...], read back the same way:

1. Read 4 bytes (length).
2. Read that many bytes (one compressed chunk).
3. Call `decompress(chunk)` and use or write the result.
4. Repeat until the stream ends.

```dart
Future<void> decompressFileChunked(String path, String outPath) async {
  final file = File(path);
  final out = File(outPath);
  final z = Zstandard();
  final bytes = await file.readAsBytes();
  final sink = out.openWrite();
  int offset = 0;

  while (offset + 4 <= bytes.length) {
    final length = ByteData.view(bytes.buffer, bytes.offsetInBytes + offset, 4).getUint32(0, Endian.big);
    offset += 4;
    if (offset + length > bytes.length) break;
    final chunk = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    final decompressed = await z.decompress(chunk);
    if (decompressed == null) throw Exception('Decompression failed');
    sink.add(decompressed);
  }
  await sink.close();
}
```

### Chunk size trade-offs

- **Smaller chunks** (e.g. 64–256 KB): Lower peak memory, more overhead (frame headers per chunk), slightly worse ratio.
- **Larger chunks** (e.g. 1–4 MB): Better ratio, higher peak memory per chunk.
- Choose a size that fits your memory budget and performance needs.

## Streaming and chunking

The plugin does not expose a streaming API. To get streaming-like behaviour:

- **Producer**: Read input in chunks (file, network, etc.), compress each chunk, and send or write the compressed chunks (e.g. with length prefix as above).
- **Consumer**: Read length-prefixed compressed chunks, decompress each with `decompress()`, and process or write the decompressed bytes.

This gives you control over memory and back-pressure at the application level.

## Concurrent compression

You can run multiple `compress` or `decompress` calls in parallel (e.g. for different chunks or different inputs). The singleton `Zstandard()` is safe to use from multiple isolates or concurrent futures.

```dart
final z = Zstandard();
final futures = chunks.map((c) => z.compress(c, 3));
final results = await Future.wait(futures);
```

- **Pros**: Better CPU utilization on multi-core devices; useful when processing many chunks or files.
- **Cons**: Peak memory increases with the number of concurrent operations. Limit concurrency (e.g. with a pool or `Future.wait` on batches) to avoid OOM.

## Memory optimization

1. **Limit concurrency**: Process a fixed number of chunks at a time instead of all at once.
2. **Reuse buffers**: Where possible, reuse `Uint8List` buffers for reading chunks instead of allocating new ones every time.
3. **Choose level**: Lower levels (1–3) use less memory than high levels (19–22). Use lower levels for large data if memory is tight.
4. **Chunk size**: Smaller chunks reduce peak memory but increase overhead; tune for your environment.
5. **Release references**: After writing or sending a compressed/decompressed chunk, let the reference go so the GC can reclaim it before the next chunk.

## Web platform

On web, compression and decompression run on the main thread (no isolates). For large data:

- Prefer smaller chunks to keep the UI responsive.
- Consider moving work to a Web Worker and calling the same API from there if you run Dart in the worker.
- Lower compression levels reduce CPU time and improve responsiveness.

## CLI and batch processing

The CLI compresses or decompresses whole files. For very large files, split them first (e.g. with `split` on Unix or a custom script), compress each part with the CLI, then reassemble and decompress on the other side. Alternatively, use the Flutter plugin in a small Dart script with the chunked patterns above for full control.

## See also

- [Performance tips](performance-tips.md)
- [Compression levels](compression-levels.md)
- [Security](security.md) — validating and limiting input size
- [Error handling](error-handling.md)
