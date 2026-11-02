#include "zstandard_ffi.h"
#include <zstd.h>

// Mach-O's used attribute protects this table and its references from Release
// dead stripping. Registration pulls this object into the statically linked app.
// Keep this project-owned shim outside the vendored upstream zstd source tree.
__attribute__((used))
static void (*const zstandard_ffi_symbols[])(void) = {
    (void (*)(void))ZSTD_compress,
    (void (*)(void))ZSTD_decompress,
    (void (*)(void))ZSTD_compressBound,
    (void (*)(void))ZSTD_isError,
    (void (*)(void))ZSTD_getFrameContentSize,
    (void (*)(void))ZSTD_createDStream,
    (void (*)(void))ZSTD_initDStream,
    (void (*)(void))ZSTD_decompressStream,
    (void (*)(void))ZSTD_freeDStream,
    (void (*)(void))ZSTD_DStreamOutSize,
};

void ZstandardNativeRetainSymbols(void) {
    // Linking this object retains the used symbol table; no zstd call is needed.
}
