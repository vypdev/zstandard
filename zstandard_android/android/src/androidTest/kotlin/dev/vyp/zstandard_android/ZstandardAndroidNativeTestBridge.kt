package dev.vyp.zstandard_android

/** JNI bridge used only by the Android instrumentation tests. */
internal object ZstandardAndroidNativeTestBridge {
    init {
        // Loading this library is part of the assertion: if the packaged
        // native artifact is absent or has the wrong ABI, the test fails here.
        System.loadLibrary("zstandard_android")
    }

    @JvmStatic
    external fun nativeCompress(input: ByteArray, compressionLevel: Int): ByteArray?

    @JvmStatic
    external fun nativeDecompress(input: ByteArray): ByteArray?
}
