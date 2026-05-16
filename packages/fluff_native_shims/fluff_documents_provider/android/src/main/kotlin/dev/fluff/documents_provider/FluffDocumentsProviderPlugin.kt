package dev.fluff.documents_provider

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Hosts the [MethodChannel] the [FluffDocumentsProvider] uses to talk to
 * the cached Dart isolate.
 *
 * Status: scaffold. The actual queryRoots / openDocument bridge is not
 * implemented yet — see PLAN.md §4.3 and Phase 6.
 */
class FluffDocumentsProviderPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            binding.binaryMessenger,
            "dev.fluff.documents_provider/bridge"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        // TODO(phase-6): route queryRoots / queryChildDocuments /
        // openDocument calls to/from the Dart side.
        result.notImplemented()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
