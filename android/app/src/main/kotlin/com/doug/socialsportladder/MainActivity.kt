package com.doug.socialsportladder

import android.app.Activity
import android.content.Context
import android.view.View
import androidx.core.locationbutton.LocationButton
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

// FlutterFragmentActivity is a ComponentActivity, which LocationButton needs
// for its permission 
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME
        )
        channel.setMethodCallHandler { call, result ->
            if (call.method == "getSdkInt") {
                result.success(android.os.Build.VERSION.SDK_INT)
            } else {
                result.notImplemented()
            }
        }
        flutterEngine.platformViewsController.registry
            .registerViewFactory(VIEW_TYPE, LocationButtonFactory(this, channel))
    }

    companion object {
        const val CHANNEL_NAME = "social_sport_ladder/location_button"
        const val VIEW_TYPE = "social_sport_ladder/location_button_view"
    }
}

private class LocationButtonFactory(
    private val activity: Activity,
    private val channel: MethodChannel,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        // The button reads theme attributes, so use the activity's themed context.
        return LocationButtonPlatformView(activity, activity, channel)
    }
}

private class LocationButtonPlatformView(
    context: Context,
    activity: Activity,
    channel: MethodChannel,
) : PlatformView {
    private val button: View = try {
        LocationButton(context).apply {
            parentActivity = activity
            setTextType(LocationButton.TEXT_TYPE_NONE)
            setOnPermissionResultListener { granted ->
                channel.invokeMethod("onPermissionResult", granted)
            }
            setOnErrorListener { error ->
                channel.invokeMethod("onError", error.toString())
            }
        }
    } catch (e: Throwable) {
        channel.invokeMethod("onError", "create failed: $e")
        View(context)
    }

    override fun getView(): View = button

    override fun dispose() {}
}
