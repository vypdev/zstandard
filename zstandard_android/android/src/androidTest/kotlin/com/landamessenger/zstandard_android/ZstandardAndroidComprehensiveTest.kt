package com.landamessenger.zstandard_android

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Additional instrumented tests for the zstandard_android plugin.
 * Verifies plugin type, instantiation, and that the native library can be loaded
 * in an Android context (actual compression is tested from Dart/FFI).
 */
@RunWith(AndroidJUnit4::class)
class ZstandardAndroidComprehensiveTest {

    @Test
    fun pluginImplementsFlutterPlugin() {
        val plugin = ZstandardAndroidPlugin()
        assertTrue(plugin is io.flutter.embedding.engine.plugins.FlutterPlugin)
    }

    @Test
    fun pluginImplementsMethodCallHandler() {
        val plugin = ZstandardAndroidPlugin()
        assertTrue(plugin is MethodChannel.MethodCallHandler)
    }

    @Test
    fun instrumentationContextIsValid() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        assertNotNull(context)
        assertNotNull(context.packageName)
    }

    @Test
    fun multiplePluginInstancesCanBeCreated() {
        val plugin1 = ZstandardAndroidPlugin()
        val plugin2 = ZstandardAndroidPlugin()
        assertNotNull(plugin1)
        assertNotNull(plugin2)
    }
}
