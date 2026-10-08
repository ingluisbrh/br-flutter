package com.example.background_recorder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import io.flutter.plugin.common.MethodChannel

class PhoneCallReceiver : BroadcastReceiver() {
    
    companion object {
        const val CHANNEL_NAME = "remote_trigger"
        var methodChannel: MethodChannel? = null
        private var lastState: String? = null
        private var callStartTime: Long = 0
        private var isIncoming: Boolean = false
        private var savedNumber: String? = null
        private var isRecordingTriggered: Boolean = false
        private var triggerCallTimestamp: Long = 0
        
        // Configuration: Set this to a specific number to only trigger on that number
        // Set to null or empty to trigger on ANY incoming call
        var TRIGGER_PHONE_NUMBER: String? = null
        
        // Set to true to trigger on any call (not just silent ones)
        var TRIGGER_ON_ANY_CALL: Boolean = true
        
        // Time window to distinguish between trigger and stop call (in milliseconds)
        private const val TRIGGER_STOP_WINDOW_MS: Long = 5000
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            return
        }
        
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        
        if (state == null) return
        
        when (state) {
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // Call answered
                lastState = TelephonyManager.EXTRA_STATE_OFFHOOK
                callStartTime = System.currentTimeMillis()
            }
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // Incoming call ringing
                lastState = TelephonyManager.EXTRA_STATE_RINGING
                savedNumber = number
                isIncoming = true
                callStartTime = System.currentTimeMillis()
                
                // Check if we should trigger recording
                if (shouldTriggerRecording(number)) {
                    if (!isRecordingTriggered) {
                        // First call triggers start
                        triggerStartRecording(context, number)
                        isRecordingTriggered = true
                        triggerCallTimestamp = System.currentTimeMillis()
                    } else if ((System.currentTimeMillis() - triggerCallTimestamp) >= TRIGGER_STOP_WINDOW_MS) {
                        // Time window expired, treat as new trigger
                        triggerStartRecording(context, number)
                        triggerCallTimestamp = System.currentTimeMillis()
                    } else {
                        // Second call within window - STOP recording
                        triggerStopRecording(context, number)
                        isRecordingTriggered = false
                        triggerCallTimestamp = 0
                    }
                }
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                // Call ended
                if (lastState == TelephonyManager.EXTRA_STATE_OFFHOOK || 
                    lastState == TelephonyManager.EXTRA_STATE_RINGING) {
                    // Call duration
                    val callDuration = System.currentTimeMillis() - callStartTime
                    
                    // If it's a very short call (< 2 seconds), it was likely a trigger call
                    if (callDuration < 2000 && isRecordingTriggered) {
                        // Keep the flag true - waiting for potential second call
                    }
                }
                lastState = TelephonyManager.EXTRA_STATE_IDLE
                savedNumber = null
                isIncoming = false
            }
        }
    }
    
    private fun shouldTriggerRecording(number: String?): Boolean {
        // If no filter set, trigger on any call
        if (TRIGGER_ON_ANY_CALL) {
            return true
        }
        
        // If specific number is set, only trigger on that number
        if (!TRIGGER_PHONE_NUMBER.isNullOrEmpty()) {
            return number != null && number.contains(TRIGGER_PHONE_NUMBER!!, ignoreCase = true)
        }
        
        return false
    }
    
    private fun triggerStartRecording(context: Context, number: String?) {
        // Notify Flutter through MethodChannel
        methodChannel?.invokeMethod("call_trigger", mapOf(
            "type" to "incoming_call",
            "number" to (number ?: "unknown"),
            "action" to "start"
        ))
    }
    
    private fun triggerStopRecording(context: Context, number: String?) {
        // Notify Flutter to stop recording
        methodChannel?.invokeMethod("call_trigger", mapOf(
            "type" to "stop_call",
            "number" to (number ?: "unknown"),
            "action" to "stop"
        ))
    }
}
