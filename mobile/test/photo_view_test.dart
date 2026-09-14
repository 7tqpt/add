// الصورةُ ملءَ الشاشة — الضغطةُ تُكبّر لا تُبدّل.
//
// قال صاحبُ المنصّة: «صور شخصية وغلاف خليهم قابل للضغط وليس متحجر»، واختار
// من ثلاثٍ عُرضت عليه **(ب): الصورةُ ملءَ الشاشة**.
//
// ── وأخطرُ ما يُقاس هنا ──────────────────────────────────────────────────────
//
// **١) «تغيير» لصاحبها وحدَه.** العارضُ نفسُه يُفتح في الصفحة العامّة حيث
// يرى العميلُ قاعةً ليست له. وزرٌّ يُعرض لمن لا يملكه يُضغط فيرتدّ عليه
// الطلبُ بخطأٍ لا يفهمه — أو أسوأ: يظنّ أنّه يملك ما لا يملك.
//
// **٢) ومن لا صورةَ له لا يُفتح له عارض.** شاشةٌ سوداءُ فارغةٌ لا تقول
// شيئاً، والضغطةُ عنده تعني «أضِف» لا «انظر». فيمضي إلى الاختيار مباشرةً.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/photo_view.dart';

const _url = 'https://example.test/u1/cover.jpg';

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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// شاشةٌ فيها زرٌّ يفتح العارض — كي يُقاس الفتحُ لا الشاشةُ وحدَها.
class _Opener extends StatelessWidget {
  const _Opener({required this.url, this.onEdit});
  final String? url;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const ValueKey('open'),
        onPressed: () => openPhoto(context, url: url, onEdit: onEdit),
        child: const Text('افتح'),
      ),
    ),
  );
}

void main() {
  group('العارض', () {
    testWidgets('**وأرضيّتُه سوداءُ لا نبيذيّة**', (tester) async {
      // لونُ العلامة يصبغ ما يُنظر إليه فيُرى غيرَ لونه. وهو الموضعُ الوحيد
      // الذي يخرج عن اللوح عن قصد.
      _phone(tester);
      await tester.pumpWidget(_wrap(const PhotoViewScreen(url: _url)));
      await _settle(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('**وتُقرَّب بالإصبعين — وهو معنى «ليس متحجراً»**',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const PhotoViewScreen(url: _url)));
      await _settle(tester);

      final zoom = tester.widget<InteractiveViewer>(
          find.byKey(const ValueKey('photo-zoom')));
      expect(zoom.maxScale, greaterThan(1));
    });

    testWidgets('**ولا «تغيير» لمن يرى صورةَ غيره**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const PhotoViewScreen(url: _url)));
      await _settle(tester);

      expect(find.byKey(const ValueKey('photo-edit')), findsNothing);
      expect(find.text('تغيير'), findsNothing);
    });

    testWidgets('ويُعرض لصاحبها', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
          _wrap(PhotoViewScreen(url: _url, onEdit: () {})));
      await _settle(tester);

      expect(find.byKey(const ValueKey('photo-edit')), findsOneWidget);
      expect(find.text('تغيير'), findsOneWidget);
    });

    testWidgets('**والضغطةُ تُغلق العارضَ ثمّ تُبدّل**', (tester) async {
      // ورقةُ الاختيار تُدفع فوق العارض، فمن لم يُغلق يعود بعد الرفع إلى
      // صورةٍ قديمةٍ ملءَ الشاشة ويظنّ أنّ شيئاً لم يقع.
      _phone(tester);
      var edits = 0;
      await tester.pumpWidget(
          _wrap(_Opener(url: _url, onEdit: () => edits++)));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('photo-edit')));
      await tester.pumpAndSettle();

      expect(edits, 1);
      expect(find.byType(PhotoViewScreen), findsNothing,
          reason: 'بقي العارضُ مفتوحاً تحت ورقة الاختيار');
    });
  });

  group('من لا صورةَ له', () {
    testWidgets('**ولا يُفتح له عارض — يمضي إلى الاختيار**', (tester) async {
      _phone(tester);
      var edits = 0;
      await tester.pumpWidget(
          _wrap(_Opener(url: null, onEdit: () => edits++)));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewScreen), findsNothing);
      expect(edits, 1, reason: 'لم يُنادَ التبديل');
    });

    testWidgets('والفراغُ كالغياب', (tester) async {
      _phone(tester);
      var edits = 0;
      await tester.pumpWidget(_wrap(_Opener(url: '', onEdit: () => edits++)));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewScreen), findsNothing);
      expect(edits, 1);
    });

    testWidgets('**ولا صورةَ ولا تبديل: لا يقع شيءٌ ولا رسالةَ خطأ**',
        (tester) async {
      // حالُ عميلٍ يفتح صفحةَ قاعةٍ لم يرفع صاحبُها شعاراً. **ولم يُخطئ أحد.**
      _phone(tester);
      await tester.pumpWidget(_wrap(const _Opener(url: null)));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
