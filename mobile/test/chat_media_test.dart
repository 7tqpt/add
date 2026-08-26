// مرفقاتُ المحادثة: صورةٌ وصوتٌ وفيديو وملفّ.
//
// **ولماذا مُسجِّلٌ ومنتقٍ مزيّفان:** الميكروفون والكاميرا لا يوجدان في
// الاختبار. وشاشةٌ تناديهما رأساً لا تُختبر إلا على جهاز، فيبقى أهمُّ ما فيها
// بلا حارس: ماذا يقع حين **يُرفض إذن الميكروفون**، وماذا يقع حين **يفشل
// الرفع**، وهل تصل مدّةُ التسجيل إلى القاعدة أصلاً.
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

/// مُسجِّلٌ مزيّف: يقول ما يُطلب منه أن يقول.
class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.permitted = true, this.clip});

  final bool permitted;
  final VoiceClip? clip;

  bool started = false;
  bool cancelled = false;

  @override
  Future<bool> hasPermission() async => permitted;
  @override
  Future<void> start() async => started = true;
  @override
  Future<VoiceClip?> stop() async => clip;
  @override
  Future<void> cancel() async => cancelled = true;
  @override
  Future<void> dispose() async {}
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
}
