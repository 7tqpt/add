// نغمةُ الإشعار.
//
// شُكي أنّ النغمة لا تشتغل. والعلّةُ في موضعين:
//
//   ١. **القناةُ أُنشئت بلا `AudioAttributes`** — فبعضُ الأجهزة تشغّل نغمتَها
//      على مجرى الوسائط لا مجرى الإشعارات، فتُكتم مع كتم الوسائط.
//   ٢. **وأندرويد لا يبدّل قناةً بعد إنشائها** — يقرأ التبديلَ ويتجاهله بلا
//      خطأ. فمن وصلته صامتةً بقيت صامتةً مهما صُلّحت الشيفرة، والعلاجُ
//      الوحيد معرّفٌ جديدٌ للقناة والقديمُ يُحذف.
//
// **وأكثرُ ما يُقاس هنا نصوصٌ لا ودجات.** المعرّفُ مكتوبٌ في ثلاثة ملفّات —
// `strings.xml` و`AndroidManifest.xml` و`MainActivity.kt` — واختلافُ حرفٍ
// بينها يعني إشعاراً بلا قناة، ولا يظهر إلّا على جهازٍ حقيقيّ. وهي علّةُ
// `SHARE_URL` نفسُها: اسمٌ في موضعٍ واسمٌ في آخر.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/notification_tone.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account_extras.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  final strings = _read('android/app/src/main/res/values/strings.xml');
  final manifest = _read('android/app/src/main/AndroidManifest.xml');
  final activity =
      _read('android/app/src/main/kotlin/ye/aras/aras/MainActivity.kt');

  /// معرّفُ القناة الحيّ كما هو مكتوبٌ في `strings.xml`.
  final live = RegExp(r'<string name="notification_channel_id">([^<]+)<')
      .firstMatch(strings)
      ?.group(1);

  group('معرّفُ القناة', () {
    test('**مكتوبٌ في `strings.xml`**', () {
      expect(live, isNotNull, reason: 'لا معرّفَ قناةٍ في موارد أندرويد');
      expect(live, isNotEmpty);
    });

    test('**والبيانُ يشير إليه لا إلى غيره**', () {
      // ولو أشار البيانُ إلى موردٍ غير موجودٍ لَما فشل البناء — يُحلّ إلى
      // فراغ، فيقع الإشعارُ في قناة «Miscellaneous».
      expect(
        manifest,
        contains('android:value="@string/notification_channel_id"'),
        reason: 'البيانُ يشير إلى موردٍ آخر — أو إلى معرّفٍ مكتوبٍ بيده',
      );
    });

    test('**والشيفرةُ الأصليّةُ تقرؤه من المورد ولا تكتبه نصّاً**', () {
      expect(activity, contains('getString(R.string.notification_channel_id)'));
      // **ولا يُكتفى بوجود القراءة.** الاسمُ مقروءٌ في موضعين — عند الإنشاء
      // وعند فتح الشاشة — فـ`contains` يرضيها بقاءُ أحدهما. كسرتُ الأوّلَ
      // إلى نصٍّ مكتوبٍ بيده فبقي الاختبارُ أخضر.
      //
      // فيُقاس المقصودُ بعينه: **ألّا يظهر المعرّفُ الحيُّ نصّاً في كوتلن
      // أصلاً**. ونصٌّ مكتوبٌ بيده يعتّق صامتاً حين يُبدَّل المورد.
      expect(activity, isNot(contains('"$live"')),
          reason: 'المعرّفُ «$live» مكتوبٌ نصّاً في كوتلن بدل قراءته');
    });

    test('**والقديمُ يُحذف، وهو غيرُ الحيّ**', () {
      // **ولولا الحذفُ لَبقيت قناتان باسمٍ واحدٍ في إعدادات الجهاز**، إحداهما
      // صامتةٌ لا تُستعمل — فيُسكت المستخدمُ الحيّةَ ظنّاً منه أنّها هي.
      final legacy = RegExp(r'LEGACY_CHANNEL\s*=\s*"([^"]+)"')
          .firstMatch(activity)
          ?.group(1);
      expect(legacy, isNotNull, reason: 'لا معرّفَ قديمٌ يُحذف');
      expect(activity, contains('deleteNotificationChannel(LEGACY_CHANNEL)'));
      // **والمساواةُ تُبطل الإصلاحَ كلَّه**: حذفُ القناة الحيّة ثمّ إنشاؤها
      // يعيدها بالإعدادات نفسها في كلّ مرّة.
      expect(legacy, isNot(live),
          reason: 'القديمُ هو الحيُّ نفسُه — فلا قناةَ جديدةَ أصلاً');
    });
  });

  group('إعدادُ القناة', () {
    test('**النغمةُ تُضبط بمجرى الإشعارات لا الوسائط**', () {
      // وهذه هي العلّةُ الأولى: بلا `AudioAttributes` تُشغَّل على مجرى
      // الوسائط في بعض الأجهزة فتُكتم معها.
      expect(activity, contains('AudioAttributes.USAGE_NOTIFICATION'));
      expect(activity, contains('DEFAULT_NOTIFICATION_URI'));
      expect(activity, contains('channel.setSound('));
    });

    test('وأهمّيتُها عاليةٌ فتُسمع ولا تُطوى صامتة', () {
      expect(activity, contains('IMPORTANCE_HIGH'));
    });
  });

  group('جسرُ فتح الشاشة', () {
    test('**واسمُه واحدٌ في دارت وفي كوتلن**', () {
      // اسمٌ هنا واسمٌ هناك يعني جسراً لا يعبر أحد — ولا يظهر إلّا على جهاز.
      expect(activity, contains('"${notificationBridge.name}"'));
    });

    testWidgets('**ويُنادى بالضغط على «نغمة الإشعار»**', (tester) async {
      var called = 0;
      toneOpener = () async {
        called++;
        return true;
      };
      addTearDown(resetToneOpener);

      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SettingsScreen(session: Session()),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      await tester.ensureVisible(find.byKey(const ValueKey('notification-sound')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notification-sound')));
      await tester.pumpAndSettle();

      expect(called, 1, reason: 'الضغطةُ لا تفتح شيئاً');
    });

    test('**وتعذّرُ الفتح يُعيد `false` ولا يرمي**', () async {
      // فيسقط النداءُ إلى إعدادات التطبيق. ولو رمى لَخرجت شاشةٌ حمراءُ في
      // الإعدادات على كلّ جهازٍ لا يملك تلك الشاشة — وأكثرُها أجهزةُ آيفون.
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationBridge, (call) async {
        throw PlatformException(code: 'ERR');
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationBridge, null));

      resetToneOpener();
      expect(await openNotificationTone(), isFalse);
    });
  });
}
