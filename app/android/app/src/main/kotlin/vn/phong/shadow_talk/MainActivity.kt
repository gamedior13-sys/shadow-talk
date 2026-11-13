package vn.phong.shadow_talk

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shadow_talk/audio")
            .setMethodCallHandler { call, result ->
                val am = getSystemService(AUDIO_SERVICE) as AudioManager
                try {
                    when (call.method) {
                        "startBluetoothSco" -> {
                            if (Build.VERSION.SDK_INT >= 31) {
                                val bt = am.availableCommunicationDevices.firstOrNull {
                                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
                                }
                                result.success(bt != null && am.setCommunicationDevice(bt))
                            } else {
                                am.startBluetoothSco()
                                am.isBluetoothScoOn = true
                                result.success(true)
                            }
                        }
                        "stopBluetoothSco" -> {
                            if (Build.VERSION.SDK_INT >= 31) {
                                am.clearCommunicationDevice()
                            } else {
                                am.isBluetoothScoOn = false
                                am.stopBluetoothSco()
                            }
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("AUDIO_ERR", e.message, null)
                }
            }
    }
}
