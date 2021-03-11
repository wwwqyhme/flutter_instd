package com.example.flutter_application_3;


import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity implements MethodChannel.MethodCallHandler {
    private static final String CHANNEL = "plugins.flutter.io/windowFocusChangedListener";

    private MethodChannel windowFocusChangedListenChannel;

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (windowFocusChangedListenChannel != null)
            windowFocusChangedListenChannel.invokeMethod("onWindowFocusChanged", hasFocus);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        windowFocusChangedListenChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        windowFocusChangedListenChannel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "onWindowFocusChanged":
                result.success(call.arguments);
                break;
            default:
                result.notImplemented();
        }
    }
}
