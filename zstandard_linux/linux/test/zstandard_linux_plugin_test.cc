#include <cstring>
#include <vector>

#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <zstd.h>

#include "include/zstandard_linux/zstandard_linux_plugin.h"
#include "zstandard_linux_plugin_private.h"

// Unit tests for the Linux plugin's C++ portion (method channel, platform version).
// Compression and decompression are implemented in Dart via FFI against the zstd
// library; see the main plugin's integration_test/ and platform unit tests for
// compression roundtrip and error handling.

namespace zstandard_linux {
namespace test {

TEST(ZstandardLinuxPlugin, GetPlatformVersion) {
  g_autoptr(FlMethodResponse) response = get_platform_version();
  ASSERT_NE(response, nullptr);
  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  ASSERT_EQ(fl_value_get_type(result), FL_VALUE_TYPE_STRING);
  // The full string varies, so just validate that it has the right format.
  EXPECT_THAT(fl_value_get_string(result), testing::StartsWith("Linux "));
}

TEST(ZstandardLinuxPlugin, GetPlatformVersionReturnsNonEmpty) {
  g_autoptr(FlMethodResponse) response = get_platform_version();
  ASSERT_NE(response, nullptr);
  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  const gchar* str = fl_value_get_string(result);
  ASSERT_NE(str, nullptr);
  EXPECT_GT(strlen(str), 0u);
}

TEST(ZstandardNative, CompressesAndDecompressesContent) {
  const std::vector<unsigned char> input = {1, 2, 3, 4, 5, 6, 7, 8, 9};
  ASSERT_FALSE(input.empty());

  const size_t compressed_capacity = ZSTD_compressBound(input.size());
  std::vector<unsigned char> compressed(compressed_capacity);
  const size_t compressed_size = ZSTD_compress(
      compressed.data(), compressed.size(), input.data(), input.size(), 3);
  ASSERT_FALSE(ZSTD_isError(compressed_size));
  ASSERT_GT(compressed_size, 0u);

  std::vector<unsigned char> decompressed(input.size());
  const size_t decompressed_size = ZSTD_decompress(
      decompressed.data(), decompressed.size(), compressed.data(),
      compressed_size);
  ASSERT_FALSE(ZSTD_isError(decompressed_size));
  ASSERT_EQ(decompressed_size, input.size());
  EXPECT_EQ(0, std::memcmp(decompressed.data(), input.data(), input.size()));
}

}  // namespace test
}  // namespace zstandard_linux
