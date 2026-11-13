import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Phát audio nền — tắt màn hình vẫn chạy, hiện trên media notification,
/// nút tai nghe Bluetooth điều khiển được (play/pause).
class PlayerService {
  final AudioPlayer player = AudioPlayer();

  /// Gọi 1 lần khi khởi động app (trước runApp).
  static Future<void> initBackground() => JustAudioBackground.init(
        androidNotificationChannelId: 'vn.phong.shadowtalk.audio',
        androidNotificationChannelName: 'Shadow Talk',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      );

  Future<void> playAsset(String asset,
      {String title = 'Shadow Talk', String album = 'Bài học'}) async {
    await player.setAudioSource(AudioSource.asset(asset,
        tag: MediaItem(id: asset, album: album, title: title)));
    await player.play();
  }

  Future<void> playFile(String path, {String title = 'Giọng của mình'}) async {
    await player.setAudioSource(AudioSource.file(path,
        tag: MediaItem(id: path, album: 'Shadow Talk', title: title)));
    await player.play();
  }

  Future<void> setSpeed(double s) => player.setSpeed(s);
  Future<void> stop() => player.stop();
  Future<void> dispose() => player.dispose();
}
