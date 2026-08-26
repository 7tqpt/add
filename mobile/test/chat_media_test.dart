// مرفقاتُ المحادثة: صورةٌ وصوتٌ وفيديو وملفّ.
//
// **ولماذا مُسجِّلٌ ومنتقٍ مزيّفان:** الميكروفون والكاميرا لا يوجدان في
// الاختبار. وشاشةٌ تناديهما رأساً لا تُختبر إلا على جهاز، فيبقى أهمُّ ما فيها
// بلا حارس: ماذا يقع حين **يُرفض إذن الميكروفون**، وماذا يقع حين **يفشل
// الرفع**، وهل تصل مدّةُ التسجيل إلى القاعدة أصلاً.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/voice.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/chat.dart';
import 'package:aras/src/screens/chat_attach.dart';
import 'package:aras/src/ui/media.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// الزرّ نفسه لا غلافُ التلميح: `byTooltip` تجد `Tooltip`، وحالةُ التعطيل
/// (`onPressed == null`) على `IconButton` فوقه.
Finder _button(String tooltip) =>
    find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton));

/// مُسجِّلٌ مزيّف: يقول ما يُطلب منه أن يقول.
class FakeRecorder implements VoiceRecorder {
  FakeRecorder({
    this.permitted = true,
    this.clip,
    this.startError,
    this.startGate,
    this.stopError,
  });

  final bool permitted;
  final VoiceClip? clip;

  /// يجعل `start` ترمي — كما ترمي المنصّة حين يكون الميكروفون مشغولاً.
  final String? startError;

  /// يحبس `start` حتى يُفتح: به تُقاس اللحظةُ بين الضغطة والبدء.
  final Completer<void>? startGate;

  final String? stopError;

  final _failures = StreamController<Object>.broadcast();

  bool started = false;
  bool cancelled = false;

  /// كم مرّةً دخلت `start` فعلاً — به يُقاس أن نقرتين لا تُنتجان نداءين.
  int startCalls = 0;

  /// عطبٌ يقع بعد أن يكون التسجيل قد بدأ — كموت خيط التسجيل في أندرويد.
  void failMidway(String message) => _failures.add(VoiceFailure(message));

  @override
  Stream<Object> get failures => _failures.stream;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start() async {
    startCalls++;
    if (startError != null) throw VoiceFailure(startError!);
    if (startGate != null) await startGate!.future;
    started = true;
  }

  @override
  Future<VoiceClip?> stop() async {
    if (stopError != null) throw VoiceFailure(stopError!);
    return clip;
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> dispose() async => _failures.close();
}

class FakePicker implements AttachmentPicker {
  FakePicker({this.result});
  final PickedAttachment? result;
  String? asked;

  @override
  Future<PickedAttachment?> image({required bool camera}) async {
    asked = camera ? 'camera' : 'gallery';
    return result;
  }

  @override
  Future<PickedAttachment?> video() async {
    asked = 'video';
    return result;
  }

  @override
  Future<PickedAttachment?> document() async {
    asked = 'file';
    return result;
  }
}

PickedAttachment _picked(ChatAttachment kind, {int seconds = 0, String name = ''}) =>
    PickedAttachment(
      kind: kind,
      bytes: Uint8List.fromList(List.filled(64, 7)),
      extension: 'bin',
      contentType: 'application/octet-stream',
      seconds: seconds,
      name: name,
    );

Widget _chat({VoiceRecorder? recorder, AttachmentPicker? picker}) => ChatScreen(
  conversationId: 'cv1',
  otherName: 'قاعة التاج',
  mySide: ChatSide.customer,
  recorder: recorder,
  picker: picker,
);

void main() {
  setUp(demoResetChat);

  testWidgets('الشريط السفلي فيه بابُ مرفقٍ وميكروفون', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_chat()));
    await _settle(tester);

    expect(find.byTooltip('أرفق'), findsOneWidget);
    expect(find.byTooltip('سجّل رسالة صوتية'), findsOneWidget);
    expect(find.byTooltip('أرسل'), findsOneWidget);
  });

  testWidgets('وقائمةُ المرفقات أربعةُ أبواب', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_chat()));
    await _settle(tester);

    await tester.tap(find.byTooltip('أرفق'));
    await _settle(tester);

    expect(find.text('صورة من المعرض'), findsOneWidget);
    expect(find.text('التقاط صورة'), findsOneWidget);
    expect(find.text('تصوير مقطع'), findsOneWidget);
    expect(find.text('ملف PDF'), findsOneWidget);
  });

  testWidgets('واختيارُ صورةٍ يُرسلها فقاعةً', (tester) async {
    _phone(tester);
    final picker = FakePicker(result: _picked(ChatAttachment.image));
    await tester.pumpWidget(_wrap(_chat(picker: picker)));
    await _settle(tester);

    await tester.tap(find.byTooltip('أرفق'));
    await _settle(tester);
    await tester.tap(find.text('صورة من المعرض'));
    await _settle(tester);

    expect(picker.asked, 'gallery');
    expect(find.byType(MediaThumb), findsOneWidget);
  });

  testWidgets('وملفُّ PDF يظهر باسمه لا بكلمة «مرفق»', (tester) async {
    _phone(tester);
    final picker = FakePicker(
      result: _picked(ChatAttachment.file, name: 'عقد القاعة.pdf'),
    );
    await tester.pumpWidget(_wrap(_chat(picker: picker)));
    await _settle(tester);

    await tester.tap(find.byTooltip('أرفق'));
    await _settle(tester);
    await tester.tap(find.text('ملف PDF'));
    await _settle(tester);

    expect(find.text('عقد القاعة.pdf'), findsOneWidget);
  });

  testWidgets('والميكروفون المرفوضُ إذنُه يقول ذلك ولا يصمت', (tester) async {
    // **وهذا ما ينكسر بصمت:** زرٌّ يُضغط فلا يقع شيءٌ ولا تظهر رسالة يجعل
    // المستخدم يظنّ التطبيق مكسوراً، وهو ممنوعٌ بإذنٍ يملك هو منحه.
    _phone(tester);
    final recorder = FakeRecorder(permitted: false);
    await tester.pumpWidget(_wrap(_chat(recorder: recorder)));
    await _settle(tester);

    await tester.tap(find.byTooltip('سجّل رسالة صوتية'));
    await _settle(tester);

    expect(recorder.started, isFalse);
    expect(find.textContaining('الميكروفون'), findsOneWidget);
    // ولا يدخل الشاشةَ في حالة تسجيلٍ لم تبدأ.
    expect(find.byTooltip('أرسل التسجيل'), findsNothing);
  });

  testWidgets('والتسجيلُ يقلب الشريط إلى عدّادٍ بمخرجين', (tester) async {
    _phone(tester);
    final recorder = FakeRecorder(
      clip: VoiceClip(bytes: Uint8List.fromList([1, 2, 3]), seconds: 9),
    );
    await tester.pumpWidget(_wrap(_chat(recorder: recorder)));
    await _settle(tester);

    await tester.tap(find.byTooltip('سجّل رسالة صوتية'));
    await tester.pump();

    expect(recorder.started, isTrue);
    expect(find.textContaining('يسجّل'), findsOneWidget);
    expect(find.byTooltip('ألغِ التسجيل'), findsOneWidget);
    expect(find.byTooltip('أرسل التسجيل'), findsOneWidget);
    // وحقلُ الكتابة يختفي: ميكروفونٌ يعمل وحقلٌ يدعو إلى الكتابة معاً
    // يجعل إحداهما تضيع.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byTooltip('أرسل التسجيل'));
    await _settle(tester);

    // المدّةُ تُعرض سواءٌ وصل الرابطُ أم لم يصل — والوضع التجريبي بلا سلّة،
    // فما يُقاس هنا أن **الرسالة وصلت الخيط بمدّتها**.
    expect(find.text('0:09'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('والإلغاءُ يرمي ما سُجّل ولا يُرسله', (tester) async {
    // من ضغط الميكروفون بالخطأ أو تكلّم فأخطأ يحتاج باباً يرمي به ما سجّل.
    _phone(tester);
    final recorder = FakeRecorder(
      clip: VoiceClip(bytes: Uint8List.fromList([1]), seconds: 5),
    );
    await tester.pumpWidget(_wrap(_chat(recorder: recorder)));
    await _settle(tester);

    await tester.tap(find.byTooltip('سجّل رسالة صوتية'));
    await tester.pump();
    await tester.tap(find.byTooltip('ألغِ التسجيل'));
    await _settle(tester);

    expect(recorder.cancelled, isTrue);
    expect(find.text('0:05'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('وتسجيلٌ قصيرٌ جداً يُقال لا يُرسَل فارغاً', (tester) async {
    _phone(tester);
    // `stop` تُعيد `null` حين لا يُسجَّل شيءٌ يُذكر.
    final recorder = FakeRecorder(clip: null);
    await tester.pumpWidget(_wrap(_chat(recorder: recorder)));
    await _settle(tester);

    await tester.tap(find.byTooltip('سجّل رسالة صوتية'));
    await tester.pump();
    await tester.tap(find.byTooltip('أرسل التسجيل'));
    await _settle(tester);

    expect(find.textContaining('قصير'), findsOneWidget);
    expect(find.byType(AudioBar), findsNothing);
    expect(find.byIcon(Icons.mic_off_outlined), findsNothing);
  });

  // ==========================================================================
  //  التجمّد: ثلاثةُ أبوابٍ كان يدخل منها
  // ==========================================================================

  testWidgets('وبدايةٌ فاشلة تُقال ولا تُدخِل الشاشةَ في تسجيلٍ لم يبدأ', (tester) async {
    // **هذا هو العطب الذي رآه المستخدم.** كانت `start` بلا حارس: فإن رمت
    // المنصّةُ خرج الاستدعاء صامتاً — لا رسالة، ولا عدّاد، وزرٌّ يُضغط فلا
    // يقع شيء. وأسوأ منه أن تُقلب الشاشة إلى شريط تسجيلٍ على مُسجِّلٍ لم
    // يبدأ، فلا يخرج منه إلا بإلغاء.
    _phone(tester);
    final recorder = FakeRecorder(startError: 'الميكروفون مشغول بتطبيقٍ آخر.');
    await tester.pumpWidget(_wrap(_chat(recorder: recorder)));
    await _settle(tester);

    await tester.tap(find.byTooltip('سجّل رسالة صوتية'));
    await _settle(tester);

    expect(find.text('الميكروفون مشغول بتطبيقٍ آخر.'), findsOneWidget);
    // لا شريطَ تسجيل، والحقلُ باقٍ — أي أن الشاشة ما زالت تعمل.
    expect(find.byTooltip('أرسل التسجيل'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    // ويُعاد الضغطُ عليه: زرٌّ عُطِّل ولم يُعَد تشغيله سجنٌ آخر.
    expect(tester.widget<IconButton>(_button('سجّل رسالة صوتية')).onPressed, isNotNull);
  });

  testWidgets('وعطبٌ بعد البدء يُخرج الشاشة من التسجيل ولا يتركها تعدّ', (tester) async {
    // خيطُ التسجيل في أندرويد يموت عند أوّل إطارٍ إن تعذّر فتحُ ملفّ الخرج،
    // و`start` تكون قد عادت بنجاح — فلا يصل العطبُ منها. وبلا الإنصات إلى
    // مجرى الأعطاب يبقى العدّاد يعدّ على مُسجِّلٍ ميّت، ثم لا تعود «أوقف»
    // أبداً. وهو التجمّد بعينه.
    _phone(tester);
    final recorder = FakeRecorder(
      clip: VoiceClip(bytes: Uint8List.fromList([1]), seconds: 3),
    );
    await tester.pumpWidget(_wrap(_chat(recorder: recorder)));
    await _settle(tester);

    await tester.tap(find.byTooltip('سجّل رسالة صوتية'));
    await tester.pump();
    expect(find.byTooltip('أرسل التسجيل'), findsOneWidget);

    recorder.failMidway('توقّف التسجيل.');
    await _settle(tester);

    expect(find.text('توقّف التسجيل.'), findsOneWidget);
    expect(find.byTooltip('أرسل التسجيل'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('والميكروفون يُطفأ بين الضغطة والبدء فلا يُنقَر نقرتين', (tester) async {
    // طلبُ الإذن في أندرويد يحفظ ردَّ نداءٍ **واحد**: فنداءٌ ثانٍ قبل أن
    // يُجاب الأوّل يمحوه، ويبقى الأوّل معلّقاً إلى الأبد. ونقرتان سريعتان
    // على الميكروفون تكفيان.
    _phone(tester);
    final gate = Completer<void>();
    final recorder = FakeRecorder(
      startGate: gate,
      clip: VoiceClip(bytes: Uint8List.fromList([1]), seconds: 4),
    );
    await tester.pumpWidget(_wrap(_chat(recorder: recorder)));
    await _settle(tester);

    await tester.tap(find.byTooltip('سجّل رسالة صوتية'));
    await tester.pump();

    expect(
      tester.widget<IconButton>(_button('سجّل رسالة صوتية')).onPressed,
      isNull,
      reason: 'الميكروفون يجب أن يكون مُطفأً وهو يُهيَّأ',
    );
    // ولو نُقر ثانيةً — بزرٍّ مُطفأ أو بغيره — فنداءٌ واحدٌ لا نداءان.
    await tester.tap(_button('سجّل رسالة صوتية'), warnIfMissed: false);
    await tester.pump();
    expect(recorder.startCalls, 1);

    gate.complete();
    await _settle(tester);
    expect(find.byTooltip('أرسل التسجيل'), findsOneWidget);
  });

  testWidgets('وفشلُ الإيقاف يُقال ولا يُبقي الشريط معلّقاً', (tester) async {
    _phone(tester);
    final recorder = FakeRecorder(stopError: 'تعذّر إنهاء التسجيل. جرّب مرّةً أخرى.');
    await tester.pumpWidget(_wrap(_chat(recorder: recorder)));
    await _settle(tester);

    await tester.tap(find.byTooltip('سجّل رسالة صوتية'));
    await tester.pump();
    await tester.tap(find.byTooltip('أرسل التسجيل'));
    await _settle(tester);

    expect(find.textContaining('تعذّر إنهاء التسجيل'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
