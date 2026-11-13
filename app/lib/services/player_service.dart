import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/models.dart';

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

  Future<void> playRef(AudioRef ref,
      {String title = 'Shadow Talk', String album = 'Bài học'}) async {
    final source = ref.isFile
        ? AudioSource.file(ref.path,
            tag: MediaItem(id: ref.path, album: album, title: title))
        : AudioSource.asset(ref.path,
            tag: MediaItem(id: ref.path, album: album, title: title));
    await player.setAudioSource(source);
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
