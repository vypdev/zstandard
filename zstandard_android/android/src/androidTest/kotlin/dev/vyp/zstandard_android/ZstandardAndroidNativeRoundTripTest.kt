package dev.vyp.zstandard_android

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented tests for the native shared library loaded by Dart FFI.
 *
 * These tests intentionally use byte arrays so the assertions cover the
 * native boundary directly: non-empty input, non-empty compressed output,
 * and an exact decompression round-trip.
 */
@RunWith(AndroidJUnit4::class)
class ZstandardAndroidNativeRoundTripTest {

    @Test
    fun nativeLibraryCompressesAndDecompressesContent() {
        val input = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8, 9)
        assertTrue("test input must contain content", input.isNotEmpty())

        val compressed =
            ZstandardAndroidNativeTestBridge.nativeCompress(input, 3)
        assertNotNull("native compression returned null", compressed)
        assertTrue("compressed output must contain bytes", compressed!!.isNotEmpty())
        assertFalse(
            "compressed output should not equal the source bytes",
            input.contentEquals(compressed),
        )

        val decompressed =
            ZstandardAndroidNativeTestBridge.nativeDecompress(compressed)
        assertNotNull("native decompression returned null", decompressed)
        assertArrayEquals(input, decompressed)
    }

    @Test
    fun nativeLibraryRoundTripsLargeContent() {
        val input = ByteArray(100_000) { (it % 256).toByte() }
        assertTrue("test input must contain content", input.isNotEmpty())

        val compressed =
            ZstandardAndroidNativeTestBridge.nativeCompress(input, 3)
        assertNotNull(compressed)
        assertTrue(compressed!!.isNotEmpty())

        val decompressed =
            ZstandardAndroidNativeTestBridge.nativeDecompress(compressed)
        assertNotNull(decompressed)
        assertArrayEquals(input, decompressed)
    }
}
