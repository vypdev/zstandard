#ifndef ZSTANDARD_FFI_H
#define ZSTANDARD_FFI_H

#ifdef __cplusplus
extern "C" {
#endif

// Call during SwiftPM plugin registration to link the Dart FFI entry points.
void ZstandardNativeRetainSymbols(void);

#ifdef __cplusplus
}
#endif

#endif
