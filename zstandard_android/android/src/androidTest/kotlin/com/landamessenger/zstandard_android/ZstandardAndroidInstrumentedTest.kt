package dev.vyp.zstandard_android

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Basic instrumented tests for the zstandard_android plugin. Native loading and
 * compression/decompression are covered by the native round-trip test class.
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
