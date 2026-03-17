# Performance

This document describes performance characteristics of the Zstandard plugin and CLI, optimization techniques, and how to measure and compare behaviour across platforms.

## Overview

- **Compression** and **decompression** speed and memory use depend on:
  - **Compression level** (1 = fastest, 22 = best ratio)
  - **Input size** and **content** (repetitive data compresses better)
  - **Platform** (native FFI vs WebAssembly, isolate usage)
- **Decompression** is typically faster than compression and largely independent of the level used to compress.

## Compression levels

| Level | Relative speed | Relative ratio | Typical use |
|-------|----------------|----------------|-------------|
| 1     | Fastest        | Lowest         | Real-time, interactive |
| 3     | Fast           | Good           | **Default**; general use |
| 5–9   | Medium         | Better         | Balanced |
| 10–19 | Slower         | High           | Storage, archival |
| 20–22 | Slowest        | Highest        | Maximum ratio |

Higher levels use more CPU and memory during compression; decompression memory and speed are less affected.

## Platform behaviour

- **Native (Android, iOS, macOS, Windows, Linux)**: Work runs in a **background isolate** by default, so the UI thread is not blocked. Throughput is comparable to the underlying zstd C library; some builds disable assembly optimizations for portability (e.g. Android, iOS).
- **Web**: Runs on the **main thread** (no isolates). For large data, prefer smaller chunks or offload to a Web Worker if you implement it. Throughput is generally lower than native.
- **CLI**: Runs in the **current isolate**; suitable for CLI/server where blocking is acceptable. Throughput is similar to native.

See the [platform guides](../platforms/) for platform-specific performance notes.

## Optimization techniques

1. **Choose the right level**: Use 1–3 for speed, 10+ for size when CPU and time allow.
2. **Chunk large data**: Process in fixed-size chunks to limit peak memory and (on web) keep the UI responsive. See [Advanced usage](../guides/advanced-usage.md).
3. **Reuse the instance**: `Zstandard()` is a singleton; no need to cache it. Same for `ZstandardCLI()`.
4. **Limit concurrency**: Many simultaneous compress/decompress calls increase peak memory; batch or limit parallelism if needed.
5. **Avoid compressing very small payloads**: Frame overhead can make compressed output larger than input; consider a size threshold below which you skip compression.

## Measuring performance

- **Time**: Use `Stopwatch` (or platform equivalents) around `compress`/`decompress` for your typical payload sizes and levels.
- **Memory**: Use Dart DevTools, Xcode Instruments, or Android Profiler to observe allocations and peak usage.
- **Benchmarks**: The repo can include a benchmark suite (e.g. under `benchmark/`) to measure throughput and detect regressions; run it locally or in CI.

## Benchmarks and regression detection

If a benchmark suite is present (e.g. `dart run benchmark/compression_benchmark.dart` or similar), run it before releases and after changes to compression paths. Compare:

- Compression throughput (MB/s or similar) for levels 1, 3, 10, 22.
- Decompression throughput.
- Roundtrip (compress then decompress) correctness and time.

Setting baseline numbers and comparing in CI helps catch performance regressions.

## See also

- [Compression levels](../guides/compression-levels.md)
- [Performance tips](../guides/performance-tips.md)
- [Advanced usage](../guides/advanced-usage.md)
- [Platform guides](../platforms/)
