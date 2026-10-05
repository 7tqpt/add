// «مستندات التوثيق» على صورة صاحب المنصّة — «غير لي».
//
// ثلاثُ خاناتٍ لكلٍّ صندوقُ «إضافة صورة»، والرفعُ كلُّه بزرٍّ واحد: «رفع
// المستندات». **فالاختيارُ لا يرفع** — يُقاس ما وصل الخادمَ لا ما في الشاشة.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/documents.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

Widget _wrap(Widget child, {double scale = 1}) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, {double scale = 1, double w = 392, double h = 2400}) async {
  tester.view.physicalSize = Size(w * 3, h * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(DocumentsScreen(session: _session()), scale: scale));
  await _settle(tester);
}

/// صورةٌ صغيرةٌ تُختار بدل منتقي النظام — بحجمٍ يُختار.
void _picker({String name = 'صورة.jpg', int bytes = 64}) {
  documentPickerOverride = (_) async => (name: name, bytes: Uint8List(bytes));
}

Future<void> _pick(WidgetTester tester, String type) async {
  final add = find.byKey(ValueKey('doc-add-$type'));
  await tester.ensureVisible(add);
  await _settle(tester);
  await tester.tap(add);
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('doc-source-gallery')));
  await _settle(tester);
}

Future<void> _upload(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('docs-upload'));
  await tester.ensureVisible(button);
  await _settle(tester);
  await tester.tap(button);
  await _settle(tester);
}

void main() {
  setUp(() => demoDocuments = []);
  tearDown(() {
    demoDocuments = [];
    documentPickerOverride = null;
  });

  testWidgets('**ثلاثُ خاناتٍ بكلماته، ولكلٍّ صندوقُ «إضافة صورة»**', (tester) async {
    await _open(tester);
    for (final (type, title, hint) in [
      ('id_card', 'البطاقة الشخصية', 'صورة واضحة للوجهين'),
      ('commercial_register', 'السجل التجاري', 'إن وجد'),
      ('certificate', 'صورة خاصة بالقسم المطلوب', 'لا تظهر للعملاء'),
    ]) {
      final slot = find.byKey(ValueKey('doc-slot-$type'));
      expect(find.descendant(of: slot, matching: find.text(title)), findsOneWidget, reason: title);
      expect(find.descendant(of: slot, matching: find.text(hint)), findsOneWidget, reason: hint);
      expect(find.descendant(of: slot, matching: find.text('إضافة صورة')), findsOneWidget);
    }
    expect(find.text('ما المطلوب؟'), findsOneWidget);
    expect(find.text('تُظهر هذه الصور للإدارة فقط'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'رفع المستندات'), findsOneWidget);
    // **ولا زرَّ عائماً قديم** — «رفع مستند» ذهب مع ورقة اختيار النوع.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('**والأيقوناتُ من صورته** — أقنعةٌ مقصوصةٌ لا أيقوناتُ المكتبة', (tester) async {
    await _open(tester);
    String asset(String key) =>
        (tester.widget<Image>(find.byKey(ValueKey(key)).first).image as AssetImage).assetName;
    expect(asset('mark-doc_shield'), 'assets/brand/doc_shield.png');
    expect(asset('mark-doc_idcard'), 'assets/brand/doc_idcard.png');
    expect(asset('mark-doc_fileplus'), 'assets/brand/doc_fileplus.png');
    expect(find.byKey(const ValueKey('mark-doc_fileplus')), findsNWidgets(3));
  });

  testWidgets('**الاختيارُ لا يرفع** — يظهر مصغَّراً، والخادمُ لم يصله شيء', (tester) async {
    _picker(name: 'هوية.jpg');
    await _open(tester);
    await _pick(tester, 'id_card');
    expect(find.byKey(const ValueKey('doc-picked-id_card-0')), findsOneWidget);
    expect(demoDocuments, isEmpty, reason: 'رُفع عند الاختيار');
  });

  testWidgets('**و«رفع المستندات» يرفع كلَّ ما اختير — كلٌّ بنوع خانته**', (tester) async {
    _picker(name: 'هوية.jpg');
    await _open(tester);
    await _pick(tester, 'id_card');
    await _pick(tester, 'id_card'); // الوجهُ الثاني
    _picker(name: 'ترخيص.jpg');
    await _pick(tester, 'certificate');
    await _upload(tester);
    expect(demoDocuments.map((d) => (d.type, d.fileName)).toList()..sort((a, b) => a.$1.compareTo(b.$1)), [
      ('certificate', 'ترخيص.jpg'),
      ('id_card', 'هوية.jpg'),
      ('id_card', 'هوية.jpg'),
    ]);
    // وما رُفع خرج من المختار، وظهر في خانته «قيد المراجعة».
    expect(find.byKey(const ValueKey('doc-picked-id_card-0')), findsNothing);
    expect(
      find.descendant(of: find.byKey(const ValueKey('doc-slot-id_card')), matching: find.text('قيد المراجعة')),
      findsNWidgets(2),
    );
  });

  testWidgets('**والمُزالُ لا يُرفع، وبلا صورةٍ لا رفع**', (tester) async {
    _picker();
    await _open(tester);
    await _pick(tester, 'commercial_register');
    await tester.tap(find.byKey(const ValueKey('doc-remove-commercial_register-0')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('doc-picked-commercial_register-0')), findsNothing);
    await _upload(tester);
    expect(demoDocuments, isEmpty);
    expect(find.text('أضف صورةً واحدةً على الأقلّ.'), findsOneWidget);
  });

  testWidgets('**وما رُفع من قبلُ يُرى في خانته بحاله وسببِ رفضه**', (tester) async {
    demoDocuments = [
      const ProviderDocument(
        id: 'd1', type: 'id_card', fileName: 'قديمة.jpg', fileUrl: '', status: 'rejected',
        note: 'الصورة غير واضحة', uploadedAt: '2026-10-01T10:00:00Z',
      ),
    ];
    await _open(tester);
    final slot = find.byKey(const ValueKey('doc-slot-id_card'));
    expect(find.descendant(of: slot, matching: find.text('مرفوض')), findsOneWidget);
    expect(find.descendant(of: slot, matching: find.text('الصورة غير واضحة')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('doc-slot-commercial_register')), matching: find.text('مرفوض')),
      findsNothing,
      reason: 'ظهر في غير خانته',
    );
  });

  testWidgets('**وما فوق عشرة ميغابايت يُردّ قبل أن يُختار**', (tester) async {
    _picker(bytes: 10 * 1024 * 1024 + 1);
    await _open(tester);
    await _pick(tester, 'id_card');
    expect(find.byKey(const ValueKey('doc-picked-id_card-0')), findsNothing);
    expect(find.textContaining('أكبر من 10 ميغابايت'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('**لا يفيض على جوالٍ صغيرٍ بخطّ ×$scale**', (tester) async {
      _picker();
      await _open(tester, scale: scale, w: 320, h: 3200);
      await _pick(tester, 'id_card');
      expect(tester.takeException(), isNull);
    });
  }
}
