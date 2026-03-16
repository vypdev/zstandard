package com.landamessenger.zstandard_android

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented tests for the zstandard_android plugin.
 * Compression and decompression are exercised by Dart code via FFI; these tests
 * verify the native library and plugin are loadable in an Android context.
 */
@RunWith(AndroidJUnit4::class)
class ZstandardAndroidInstrumentedTest {

  @Test
  fun contextIsNotNull() {
    val context = InstrumentationRegistry.getInstrumentation().targetContext
    assertNotNull(context)
  }

  @Test
  fun pluginClassCanBeInstantiated() {
    val plugin = ZstandardAndroidPlugin()
    assertNotNull(plugin)
  }
}
