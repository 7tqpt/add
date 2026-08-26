import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// مقطعٌ صوتيٌّ سُجِّل، ببايتاته ومدّته.
class VoiceClip {
  const VoiceClip({required this.bytes, required this.seconds});
  final Uint8List bytes;
  final int seconds;
}

/// عطبٌ في التسجيل يُقال للمستخدم بالعربية.
///
/// **ولا يُترك خطأُ المنصّة كما هو:** `PlatformException(-11800, …)` أو
/// `PathNotFoundException` لا تقول لصاحب الجوال شيئاً، وهو لا يملك أن يفعل
/// بها شيئاً. والذي يملكه: أن يُعيد المحاولة.
class VoiceFailure implements Exception {
  const VoiceFailure(this.message);
  final String message;
  @override
  String toString() => message;
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

  /// أعطابٌ تقع **بعد** أن يبدأ التسجيل بنجاح.
  ///
  /// **وهذه ليست ترفاً:** خيطُ التسجيل في أندرويد يموت عند أوّل إطارٍ إن تعذّر
  /// فتحُ ملفّ الخرج، ولا يصل ذلك إلى `start` — فهي تكون قد عادت بنجاح. فبلا
  /// هذا المجرى تبقى الشاشة تعدّ الثواني على مُسجِّلٍ ميّت، ثم لا يخرج منها
  /// شيء. وهو ما رآه المستخدم: «التطبيق يعلّق».
  Stream<Object> get failures;

  Future<void> dispose();
}

/// حدُّ المقطع — والقاعدة تردّ ما تجاوزه (`message_attachment_seconds`).
///
/// **ودقيقتان لا خمس:** أطولُ من ذلك ليس رسالةً بل مكالمة، ويثقل تنزيلُه على
/// شبكةٍ يمنية. والحدُّ يُطبَّق هنا **بالإيقاف التلقائي** لا بالرفض بعد
/// التسجيل: من تكلّم ثلاث دقائق ثم قيل له «طويل» فقد كلامَه كلَّه.
const voiceMaxSeconds = 120;

/// أقصرُ ما يُعدّ رسالة. ما دونه ضغطةٌ عابرة على الزرّ لا كلام.
const voiceMinSeconds = 1;

/// أطولُ ما ننتظره ردَّ المنصّة على «أوقف» أو «ألغِ».
///
/// **وانتظارٌ بلا حدٍّ هو التجمّد نفسه.** في `record` ‏٧٫١٫١ ثغرةٌ مقروءةٌ في
/// مصدرها: `AudioRecorder.stop` تُنادي ردَّ النداء في حالتين فقط — أن يكون
/// الخيط يسجّل، أو أن يكون معدوماً. وبينهما حالةٌ ثالثة (خيطٌ قائمٌ توقّف عن
/// التسجيل) **لا يُنادى فيها الردُّ أصلاً**، فيبقى `await` معلّقاً إلى الأبد.
/// ولا أملك تعديل الحزمة، فالحدُّ هو الحارس.
const _platformWait = Duration(seconds: 10);

/// وانتظارُ الإذن أطول: نافذةُ النظام تبقى حتى يقرأها المستخدم ويقرّر.
const _permissionWait = Duration(seconds: 120);

/// المُسجِّل الحقيقي — فوق حزمة `record`.
class DeviceVoiceRecorder implements VoiceRecorder {
  DeviceVoiceRecorder({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Stopwatch _clock = Stopwatch();
  final StreamController<Object> _failures = StreamController<Object>.broadcast();
  StreamSubscription<RecordState>? _state;

  @override
  Stream<Object> get failures => _failures.stream;

  @override
  Future<bool> hasPermission() =>
      _recorder.hasPermission().timeout(_permissionWait, onTimeout: () => false);

  @override
  Future<void> start() async {
    _listenForFailure();

    await _recorder.start(
      // `m4a/aac` لا `wav`: الأخير غير مضغوط — دقيقةٌ منه عشرةُ أضعاف، وهو ما
      // يدفعه المستخدم من باقته مرّتين: مرّةً حين يرفع ومرّةً حين يُنزَّل عند
      // الطرف الآخر. والنوع مذكورٌ في `allowed_mime_types` للسلّة.
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, numChannels: 1),
      path: await _outputPath(),
    );
    _clock
      ..reset()
      ..start();
  }

  /// مسارُ ملفّ الخرج — **مطلقٌ لا اسمٌ مجرّد، وهذا كان أصلَ العطب.**
  ///
  /// كان الاسم يُمرَّر وحده (`voice_1724…m4a`)، و`MediaMuxer` في أندرويد يفتح
  /// المسار كما جاء: والمسارُ النسبيّ يُحسب من مجلّد العملية — وهو `/` في
  /// أندرويد، لا يُكتب فيه. فيفشل الفتح عند **أوّل إطارٍ مشفَّر**، أي بعد أن
  /// تكون `start` قد عادت بنجاح والشاشةُ قد دخلت حالة التسجيل. ثمّ يموت خيطُ
  /// التسجيل، فتقع «أوقف» في الحالة الثالثة الموصوفة فوق ولا تعود أبداً.
  ///
  /// فالعطب لم يكن في الإذن ولا في الميكروفون: كان في سطرٍ واحدٍ بلا مجلّد.
  Future<String> _outputPath() async {
    final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    // **والويب لا مجلّدات فيه:** `record_web` يسجّل في الذاكرة ويتجاهل المسار،
    // و`getTemporaryDirectory` ترمي `MissingPluginException` هناك — فنداؤها
    // على الويب يكسر ما يعمل.
    if (kIsWeb) return name;
    return '${(await getTemporaryDirectory()).path}/$name';
  }

  @override
  Future<VoiceClip?> stop() async {
    _clock.stop();
    // المدّةُ من الساعة لا من تقديرٍ على حجم الملف: معدّلُ البتّ متغيّرٌ في
    // aac، فحسابُها من الحجم يخطئ بثوانٍ — والرقم يُعرض للمستمع.
    final seconds = _clock.elapsed.inSeconds;

    final String? path;
    try {
      path = await _recorder.stop().timeout(_platformWait);
    } on TimeoutException {
      // ولا نتركه ممسكاً بالميكروفون: الشاشة ستخرج من حالة التسجيل، فلو بقي
      // المُسجِّل عاملاً لظلّ الميكروفون مشغولاً وفشل كلُّ تسجيلٍ بعده.
      await cancel();
      throw const VoiceFailure('تعذّر إنهاء التسجيل. جرّب مرّةً أخرى.');
    } finally {
      _stopListening();
    }

    if (path == null) return null;
    if (seconds < voiceMinSeconds) return null;

    // `XFile` لا `dart:io`: استيرادُ الثانية يكسر بناء الويب، وهذه تقرأ
    // البايتات في المنصّتين.
    final Uint8List bytes;
    try {
      bytes = await XFile(path).readAsBytes();
    } catch (_) {
      // ملفٌّ لم يُكتب — وهو ما كان يقع بالمسار النسبيّ. ويبقى الحارس بعد
      // إصلاحه: قرصٌ ممتلئ يعطي النتيجة نفسها.
      throw const VoiceFailure('لم يُحفظ التسجيل. جرّب مرّةً أخرى.');
    }
    if (bytes.isEmpty) return null;

    return VoiceClip(bytes: bytes, seconds: seconds.clamp(1, voiceMaxSeconds));
  }

  @override
  Future<void> cancel() async {
    _clock.stop();
    _stopListening();
    try {
      await _recorder.cancel().timeout(_platformWait);
    } catch (_) {
      // **والإلغاءُ لا يُبلَّغ عطبُه:** المستخدم طلب رميَ ما سجّل، فإخبارُه
      // أنّ الرمي فشل ضجيجٌ لا يملك له فعلاً — والشاشة خرجت من التسجيل.
    }
  }

  /// يلتقط الأعطاب التي تقع بعد البدء.
  ///
  /// وهي تصل على مجرى الحالة **بوصفها أخطاءً** لا قيماً، فلولا `onError` لما
  /// وصل منها شيء.
  void _listenForFailure() {
    _state ??= _recorder.onStateChanged().listen(
      (_) {},
      onError: (Object e) {
        if (!_failures.isClosed) _failures.add(e);
      },
    );
  }

  /// **بلا `await`، وهذا مقصودٌ لا إهمال.** `cancel()` على اشتراكِ مجرًى
  /// إذاعيّ — ومجرى القناة من المنصّة كذلك — يُعيد `Future` قد لا تكتمل إلّا
  /// بعد دورة حدث، وانتظارُها داخل `stop` يحبس الإيقاف نفسه.
  void _stopListening() {
    final sub = _state;
    _state = null;
    unawaited(sub?.cancel() ?? Future<void>.value());
  }

  @override
  Future<void> dispose() async {
    _stopListening();
    await _failures.close();
    await _recorder.dispose();
  }
}
