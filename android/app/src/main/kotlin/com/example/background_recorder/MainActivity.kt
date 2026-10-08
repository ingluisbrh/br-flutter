package com.example.background_recorder

import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var volumeChannel: MethodChannel
    private lateinit var remoteTriggerChannel: MethodChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        volumeChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "volume_buttons")
        remoteTriggerChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "remote_trigger")
        
        // Set up the PhoneCallReceiver's method channel
        PhoneCallReceiver.methodChannel = remoteTriggerChannel
        
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                volumeChannel.invokeMethod("start", null)
                true // Consume the event
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                volumeChannel.invokeMethod("stop", null)
                true // Consume the event
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }
}
