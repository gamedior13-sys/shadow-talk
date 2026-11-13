package vn.phong.shadow_talk

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var audioRecord: AudioRecord? = null
    private var recordThread: Thread? = null
    private var recording = false
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Kênh tổng: SCO Bluetooth + xin quyền ghi âm
        MethodChannel(messenger, "shadow_talk/audio").setMethodCallHandler { call, result ->
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            try {
                when (call.method) {
                    "startBluetoothSco" -> {
                        if (Build.VERSION.SDK_INT >= 31) {
                            val bt = am.availableCommunicationDevices.firstOrNull {
                                it.type == android.media.AudioDeviceInfo.TYPE_BLUETOOTH_SCO
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
                    "hasPermission" -> {
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 4242)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("AUDIO_ERR", e.message, null)
            }
        }

        // Kênh điều khiển ghi âm: start / stop
        MethodChannel(messenger, "shadow_talk/recorder").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        startRecording()
                        result.success(true)
                    }
                    "stop" -> {
                        stopRecording()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("REC_ERR", e.message, null)
            }
        }

        // Kênh stream PCM: native đẩy chunk Uint8List về Dart
        EventChannel(messenger, "shadow_talk/recorder_stream").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }

                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            }
        )
    }

    @SuppressLint("MissingPermission")
    private fun startRecording() {
        if (recording) return
        val minBuf = AudioRecord.getMinBufferSize(
            16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        val rec = AudioRecord(
            MediaRecorder.AudioSource.MIC, 16000,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBuf, 32000)
        )
        audioRecord = rec
        // Hiệu ứng chống ồn của hệ thống (WebRTC built-in)
        try {
            NoiseSuppressor.create(rec.audioSessionId)?.setEnabled(true)
        } catch (_: Exception) {}
        try {
            AcousticEchoCanceler.create(rec.audioSessionId)?.setEnabled(true)
        } catch (_: Exception) {}
        try {
            AutomaticGainControl.create(rec.audioSessionId)?.setEnabled(true)
        } catch (_: Exception) {}

        // Foreground service type microphone -> tắt màn hình vẫn ghi được
        val svc = Intent(this, RecordingService::class.java)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(svc) else startService(svc)

        recording = true
        rec.startRecording()
        recordThread = Thread {
            val buf = ByteArray(3200) // 100 ms @ 16 kHz mono 16-bit
            while (recording) {
                val r = audioRecord ?: break
                val n = r.read(buf, 0, buf.size)
                if (n > 0) {
                    val chunk = buf.copyOf(n)
                    runOnUiThread { eventSink?.success(chunk) }
                } else if (n < 0) {
                    break
                }
            }
        }
        recordThread?.start()
    }

    private fun stopRecording() {
        if (!recording && audioRecord == null) return
        recording = false
        try {
            audioRecord?.stop()
        } catch (_: Exception) {}
        try {
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
        recordThread = null
        try {
            stopService(Intent(this, RecordingService::class.java))
        } catch (_: Exception) {}
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4242) {
            val r = pendingPermissionResult
            pendingPermissionResult = null
            r?.success(
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
        }
    }

    override fun onDestroy() {
        stopRecording()
        super.onDestroy()
    }
}
