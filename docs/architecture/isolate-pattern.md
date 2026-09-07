# Native Isolate Pattern

All official native platform implementations keep CPU-heavy zstd work away
from the Flutter UI isolate with `Isolate.run`.

## Safety boundary

The public platform method captures a Dart-owned `Uint8List` and scalar
options. Inside the worker isolate it constructs or uses the shared
`ZstandardNativeCodec`, allocates native buffers, performs the FFI calls,
copies the result into a new Dart byte list, and frees every native allocation
before completion.

Native `Pointer` values are never sent between isolates. This matters because
pointer lifetime, ownership, and concurrent access cannot be inferred from a
numeric address. The historical `compressAsync` and `decompressAsync`
pointer helpers remain only for source compatibility: they are deprecated and
execute synchronously in their caller's isolate before their Future completes.

```text
UI isolate                    Worker isolate
-----------                   --------------
Uint8List + options  ───────▶ allocate native input/output
                              call zstd
new Uint8List         ◀────── copy result and free native memory
```

Compression emits one frame. Decompression uses `ZSTD_decompressStream`, so
it can consume unknown-size and concatenated frames while checking the output
budget after every produced chunk. A no-progress condition with exhausted
input is treated as a truncated frame.

Applications only await `Zstandard().compress` or `decompress`; they do not
manage isolates or pointers. For the browser execution model, see
[Web implementation](web-implementation.md).
