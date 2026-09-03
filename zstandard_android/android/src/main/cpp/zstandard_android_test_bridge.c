#include <jni.h>
#include <stdint.h>
#include <stdlib.h>

#include "zstd.h"

// This bridge is used by the Android instrumentation tests to exercise the
// same shared library that Dart FFI loads. It is deliberately small and keeps
// the production plugin API unchanged.

static jbyteArray copy_to_byte_array(JNIEnv *env, const void *data,
                                     size_t size) {
  if (size > INT32_MAX) {
    return NULL;
  }

  jbyteArray result = (*env)->NewByteArray(env, (jsize)size);
  if (result == NULL) {
    return NULL;
  }
  if (size > 0) {
    (*env)->SetByteArrayRegion(env, result, 0, (jsize)size,
                               (const jbyte *)data);
  }
  return result;
}

JNIEXPORT jbyteArray JNICALL
Java_dev_vyp_zstandard_1android_ZstandardAndroidNativeTestBridge_nativeCompress(
    JNIEnv *env, jclass clazz, jbyteArray input, jint compression_level) {
  (void)clazz;
  if (input == NULL) {
    return NULL;
  }

  const jsize input_size = (*env)->GetArrayLength(env, input);
  const size_t source_capacity = input_size > 0 ? (size_t)input_size : 1;
  unsigned char *source = (unsigned char *)malloc(source_capacity);
  if (source == NULL) {
    return NULL;
  }
  if (input_size > 0) {
    (*env)->GetByteArrayRegion(env, input, 0, input_size, (jbyte *)source);
  }

  const size_t output_capacity = ZSTD_compressBound((size_t)input_size);
  unsigned char *output = (unsigned char *)malloc(output_capacity);
  if (output == NULL) {
    free(source);
    return NULL;
  }

  const size_t compressed_size =
      ZSTD_compress(output, output_capacity, source, (size_t)input_size,
                    compression_level);
  jbyteArray result = NULL;
  if (!ZSTD_isError(compressed_size)) {
    result = copy_to_byte_array(env, output, compressed_size);
  }

  free(output);
  free(source);
  return result;
}

JNIEXPORT jbyteArray JNICALL
Java_dev_vyp_zstandard_1android_ZstandardAndroidNativeTestBridge_nativeDecompress(
    JNIEnv *env, jclass clazz, jbyteArray input) {
  (void)clazz;
  if (input == NULL) {
    return NULL;
  }

  const jsize input_size = (*env)->GetArrayLength(env, input);
  const size_t source_capacity = input_size > 0 ? (size_t)input_size : 1;
  unsigned char *source = (unsigned char *)malloc(source_capacity);
  if (source == NULL) {
    return NULL;
  }
  if (input_size > 0) {
    (*env)->GetByteArrayRegion(env, input, 0, input_size, (jbyte *)source);
  }

  const unsigned long long content_size =
      ZSTD_getFrameContentSize(source, (size_t)input_size);
  if (content_size == ZSTD_CONTENTSIZE_UNKNOWN ||
      content_size == ZSTD_CONTENTSIZE_ERROR || content_size > INT32_MAX) {
    free(source);
    return NULL;
  }

  const size_t output_capacity = content_size > 0 ? (size_t)content_size : 1;
  unsigned char *output = (unsigned char *)malloc(output_capacity);
  if (output == NULL) {
    free(source);
    return NULL;
  }

  const size_t decompressed_size =
      ZSTD_decompress(output, output_capacity, source, (size_t)input_size);
  jbyteArray result = NULL;
  if (!ZSTD_isError(decompressed_size) && decompressed_size == content_size) {
    result = copy_to_byte_array(env, output, decompressed_size);
  }

  free(output);
  free(source);
  return result;
}
