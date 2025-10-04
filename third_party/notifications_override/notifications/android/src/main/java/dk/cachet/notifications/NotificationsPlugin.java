package dk.cachet.notifications;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class NotificationsPlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private static final String TAG = "NotificationsPlugin";
    private static final String METHOD_CHANNEL = "notifications.methodChannel";
    private static final String EVENT_CHANNEL = "notifications.eventChannel";

    private Context applicationContext;
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private static EventChannel.EventSink eventSink;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        applicationContext = flutterPluginBinding.getApplicationContext();
        
        methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);
        
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        result.notImplemented();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        methodChannel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
        methodChannel = null;
        eventChannel = null;
        applicationContext = null;
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        eventSink = events;
    }

    @Override
    public void onCancel(Object arguments) {
        eventSink = null;
    }

    /**
     * Called from NotificationListener to send events to Flutter
     */
    public static void sendNotificationEvent(String packageName, String title, String message, long timeStamp) {
        if (eventSink != null) {
            try {
                Map<String, Object> event = new HashMap<>();
                event.put("packageName", packageName != null ? packageName : "");
                event.put("title", title != null ? title : "");
                event.put("message", message != null ? message : "");
                event.put("timeStamp", timeStamp);
                
                eventSink.success(event);
            } catch (Exception e) {
                Log.e(TAG, "Error sending notification event", e);
            }
        }
    }
}
