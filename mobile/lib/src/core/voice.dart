import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:record/record.dart';

/// مقطعٌ صوتيٌّ سُجِّل، ببايتاته ومدّته.
class VoiceClip {
  const VoiceClip({required this.bytes, required this.seconds});
  final Uint8List bytes;
  final int seconds;
}

/// ما تحتاجه الشاشة من المُسجِّل — لا أكثر.
///
/// **وواجهةٌ لا نداءٌ مباشر لأن الميكروفون لا يوجد في الاختبار.** شاشةٌ تنادي
/// `AudioRecorder` رأساً لا تُختبر إلا على جهاز، فيبقى أهمُّ ما فيها — ماذا
/// يقع حين يُرفض الإذن، وماذا يقع حين يفشل الرفع — بلا حارس. وهذه تُبدَّل
/// بمزيّفةٍ في الاختبار فتُقاس المسارات كلُّها.
abstract class VoiceRecorder {
  /// أمعنا إذنُ الميكروفون؟ يطلبه إن لم يكن.
  Future<bool> hasPermission();

  Future<void> start();

  /// يوقف ويُعيد المقطع — أو `null` إن لم يُسجَّل شيءٌ يُذكر.
  Future<VoiceClip?> stop();

  /// يوقف ويرمي ما سُجِّل.
  Future<void> cancel();

  Future<void> dispose();
}

/// حدُّ المقطع — والقاعدة تردّ ما تجاوزه (`message_audio_length`).
///
/// **ودقيقتان لا خمس:** أطولُ من ذلك ليس رسالةً بل مكالمة، ويثقل تنزيلُه على
/// شبكةٍ يمنية. والحدُّ يُطبَّق هنا **بالإيقاف التلقائي** لا بالرفض بعد
/// التسجيل: من تكلّم ثلاث دقائق ثم قيل له «طويل» فقد كلامَه كلَّه.
const voiceMaxSeconds = 120;

/// أقصرُ ما يُعدّ رسالة. ما دونه ضغطةٌ عابرة على الزرّ لا كلام.
const voiceMinSeconds = 1;

/// المُسجِّل الحقيقي — فوق حزمة `record`.
class DeviceVoiceRecorder implements VoiceRecorder {
  DeviceVoiceRecorder({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Stopwatch _clock = Stopwatch();
  String? _path;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    // `m4a/aac` لا `wav`: الأخير غير مضغوط — دقيقةٌ منه عشرةُ أضعاف، وهو ما
    // يدفعه المستخدم من باقته مرّتين: مرّةً حين يرفع ومرّةً حين يُنزَّل عند
    // الطرف الآخر. والنوع مذكورٌ في `allowed_mime_types` للسلّة.
    _path = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, numChannels: 1),
      path: _path!,
    );
    _clock
      ..reset()
      ..start();
  }

  @override
  Future<VoiceClip?> stop() async {
    _clock.stop();
    final path = await _recorder.stop();
    if (path == null) return null;

    // المدّةُ من الساعة لا من تقديرٍ على حجم الملف: معدّلُ البتّ متغيّرٌ في
    // aac، فحسابُها من الحجم يخطئ بثوانٍ — والرقم يُعرض للمستمع.
    final seconds = _clock.elapsed.inSeconds;
    if (seconds < voiceMinSeconds) return null;

    // `XFile` لا `dart:io`: استيرادُ الثانية يكسر بناء الويب، وهذه تقرأ
    // البايتات في المنصّتين.
    final bytes = await XFile(path).readAsBytes();
    if (bytes.isEmpty) return null;

    return VoiceClip(bytes: bytes, seconds: seconds.clamp(1, voiceMaxSeconds));
  }

  @override
  Future<void> cancel() async {
    _clock.stop();
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
