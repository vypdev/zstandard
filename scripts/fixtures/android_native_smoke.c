#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zstd.h"

static int round_trip(size_t length, int level) {
    unsigned char *input = malloc(length ? length : 1);
    unsigned char *output = malloc(length ? length : 1);
    size_t capacity = ZSTD_compressBound(length);
    void *frame = malloc(capacity);
    if (!input || !output || !frame) return 1;
    for (size_t i = 0; i < length; ++i) input[i] = (unsigned char)(i % 251);
    size_t compressed = ZSTD_compress(frame, capacity, input, length, level);
    int failed = ZSTD_isError(compressed) || compressed == 0;
    if (!failed) {
        size_t restored = ZSTD_decompress(output, length, frame, compressed);
        failed = ZSTD_isError(restored) || restored != length || memcmp(input, output, length);
    }
    free(frame);
    free(output);
    free(input);
    if (failed) fprintf(stderr, "Round trip failed: length=%zu level=%d\n", length, level);
    return failed;
}

int main(void) {
    if (ZSTD_versionNumber() != ZSTD_VERSION_NUMBER) return 1;
    if (round_trip(0, 3) || round_trip(100000, 3)) return 1;
    const int levels[] = {1, 3, 10, 22};
    for (unsigned i = 0; i < sizeof(levels) / sizeof(levels[0]); ++i) {
        if (round_trip(128, levels[i])) return 1;
    }
    char output[128];
    const unsigned char invalid[] = {1, 2, 3, 4, 5};
    if (!ZSTD_isError(ZSTD_decompress(output, sizeof(output), invalid, sizeof(invalid)))) return 1;
    puts("PASS: Android shared library version, empty/large round trips, levels 1/3/10/22 and corrupt input");
    return 0;
}
