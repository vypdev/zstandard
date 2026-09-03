#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>
#include <zstd.h>

#include <memory>
#include <string>
#include <variant>
#include <vector>

#include "zstandard_windows_plugin.h"

// Unit tests for the Windows plugin's C++ portion and the native zstd library.
// The Dart integration tests additionally validate the complete FFI boundary.

namespace zstandard_windows {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(ZstandardWindowsPlugin, GetPlatformVersion) {
  ZstandardWindowsPlugin plugin;
  // Save the reply value from the success callback.
  std::string result_string;
  plugin.HandleMethodCall(
      MethodCall("getPlatformVersion", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&result_string](const EncodableValue* result) {
            result_string = std::get<std::string>(*result);
          },
          nullptr, nullptr));

  // Since the exact string varies by host, just ensure that it's a string
  // with the expected format.
  EXPECT_TRUE(result_string.rfind("Windows ", 0) == 0);
}

TEST(ZstandardWindowsPlugin, GetPlatformVersionNonEmpty) {
  ZstandardWindowsPlugin plugin;
  std::string result_string;
  plugin.HandleMethodCall(
      MethodCall("getPlatformVersion", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&result_string](const EncodableValue* result) {
            result_string = std::get<std::string>(*result);
          },
          nullptr, nullptr));
  EXPECT_FALSE(result_string.empty());
}

TEST(ZstandardWindowsPlugin, NativeZstdRoundTrip) {
  const std::string input =
      "Windows native zstd round trip: "
      "the source must be compressed and restored byte-for-byte.";
  ASSERT_FALSE(input.empty());

  const size_t compressed_capacity = ZSTD_compressBound(input.size());
  ASSERT_GT(compressed_capacity, 0u);
  std::vector<char> compressed(compressed_capacity);
  const size_t compressed_size = ZSTD_compress(
      compressed.data(), compressed.size(), input.data(), input.size(), 3);
  ASSERT_FALSE(ZSTD_isError(compressed_size));
  ASSERT_GT(compressed_size, 0u);

  std::vector<char> decompressed(input.size());
  const size_t decompressed_size = ZSTD_decompress(
      decompressed.data(), decompressed.size(), compressed.data(),
      compressed_size);
  ASSERT_FALSE(ZSTD_isError(decompressed_size));
  ASSERT_EQ(decompressed_size, input.size());
  EXPECT_EQ(std::string(decompressed.data(), decompressed_size), input);
}

}  // namespace test
}  // namespace zstandard_windows
