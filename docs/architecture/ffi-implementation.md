# Native FFI Implementation

`zstandard_native` is the single native-code package. It contains the pinned
upstream C source, generated Dart bindings, and the shared
`ZstandardNativeCodec` used by Android, iOS, macOS, Linux, Windows, and the
desktop CLI.

## Compression

The codec validates levels 1–22, allocates at least one source byte so an empty
input is safe to pass through FFI, obtains `ZSTD_compressBound`, compresses into
a native buffer, copies the exact result into Dart memory, and frees both
allocations in `finally`. Empty input therefore produces a normal zstd frame.

## Decompression

The codec uses this streaming surface:

```text
ZSTD_createDStream     ZSTD_initDStream
ZSTD_DStreamOutSize    ZSTD_decompressStream
ZSTD_isError           ZSTD_freeDStream
```

Input is copied into native memory once. Output is produced into the zstd
recommended chunk size and copied into a `BytesBuilder`. Before accepting each
chunk, the implementation verifies that the cumulative result cannot exceed
`maxOutputSize`. It accepts content-size-omitting and concatenated frames and
rejects errors, truncation, or a no-progress loop. All stream state and buffers
are freed on every return path.

The older one-shot `ZSTD_decompress` and frame-size symbols remain exported for
low-level compatibility, but public byte decompression does not trust frame
metadata to choose an unbounded allocation.

## Linking and source resolution

Native build systems compile only upstream `common`, `compress`, and
`decompress` C files from the exact `zstandard_native` package resolved by the
application. Repository checkouts may use the adjacent package; published
consumers resolve it through Dart's package configuration. Build scripts never
select an arbitrary matching Pub-cache directory.

SwiftPM force-loads the complete FFI symbol surface because its static linker
could otherwise remove Dart-only entry points. CocoaPods builds the equivalent
C set in an embedded framework. CLI tests open every required symbol; runtime
roundtrips exercise the same codec.

See [Native isolate pattern](isolate-pattern.md) and
[`UPSTREAM_ZSTD.md`](../../zstandard_native/UPSTREAM_ZSTD.md).
