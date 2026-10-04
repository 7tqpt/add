// **عددُ محاولات الرمز يعيش بين الإقلاعين** — وبياناتُ التطبيق لا تُنسخ.
//
// كشف فحصٌ أمنيٌّ أنّ العدّادَ كان في الذاكرة وحدَها: من يمسك الجوالَ يجرّب
// أربعاً، ثمّ يغلق التطبيقَ ويفتحه فيعود العدُّ صفراً — فعشرةُ آلاف رمزٍ
// تُجرَّب أربعاً أربعاً ولا يُخرَج الحسابُ أبداً.
//
// **و«الإقلاعُ» هنا نسخةٌ جديدةٌ من `AppLock` على الخزنة نفسِها** — وهو ما
// يقع فعلاً: الذاكرةُ تُمحى، والخزنةُ تبقى.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';

void main() {
  late Map<String, String> storage;

  setUp(() async {
    storage = {};
    lockStorageOverride = storage;
    await lockSetPin('1234');
  });
  tearDown(() => lockStorageOverride = null);

  /// يُقلع التطبيقُ من جديد: نسخةٌ جديدةٌ والخزنةُ كما هي.
  Future<AppLock> relaunch() async {
    final lock = AppLock();
    await lock.boot();
    return lock;
  }

  test('**أربعُ محاولاتٍ ثمّ إغلاقٌ وفتح — يبقى العدُّ أربعاً**', () async {
    final first = await relaunch();
    for (final pin in ['0000', '1111', '2222', '3333']) {
      expect(await first.unlock(pin), isFalse);
    }

    final second = await relaunch();
    expect(second.wrongAttempts, 4, reason: 'عاد العدُّ صفراً بالإغلاق');
    expect(second.attemptsLeft, 1);

    expect(await second.unlock('4444'), isFalse);
    expect(second.exhausted, isTrue, reason: 'الخامسةُ بعد الإقلاع لم تبلغ الحدّ');
  });

  test('**ومن بلغ الحدَّ ثمّ أُغلق قبل الإخراج لا يفتح ولو أصاب**', () async {
    // يقع حين يُغلق التطبيقُ بين الخطأ الخامس وإخراج الحساب.
    final first = await relaunch();
    for (var i = 0; i < lockMaxAttempts; i++) {
      await first.unlock('0000');
    }

    final second = await relaunch();
    expect(second.exhausted, isTrue);
    expect(await second.unlock('1234'), isFalse, reason: 'فُتح بعد الحدّ');
    expect(second.locked, isTrue);
  });

  test('والرمزُ الصحيحُ يمحو العدَّ من الخزنة لا من الذاكرة وحدها', () async {
    final first = await relaunch();
    await first.unlock('0000');
    await first.unlock('0000');
    expect(await first.unlock('1234'), isTrue);

    final second = await relaunch();
    expect(second.wrongAttempts, 0, reason: 'بقي عدُّ الأمس بعد فتحٍ صحيح');
  });

  test('وإزالةُ القفل تمحوه — فلا يرث قفلٌ جديدٌ أخطاءَ القديم', () async {
    final first = await relaunch();
    await first.unlock('0000');
    await first.unlock('0000');
    await first.disable();
    expect(storage.containsKey('lock_wrong'), isFalse);

    await first.enable('5678');
    final second = await relaunch();
    expect(second.wrongAttempts, 0);
  });

  // ── ولا نسخَ احتياطيّاً لبيانات التطبيق ───────────────────────────────────
  //
  // جلسةُ الدخول تسكن ملفّاتِ التطبيق، والنسخُ الاحتياطيُّ يحملها إلى جهازٍ
  // آخر فيفتح الحسابَ بلا كلمة مرور.
  test('**أندرويد لا ينسخ بيانات التطبيق ولا ينقلها**', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final application = RegExp(r'<application[^>]*>').firstMatch(manifest)!.group(0)!;
    expect(application, contains('android:allowBackup="false"'));
    expect(application, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));

    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section>([\\s\\S]*?)</$section>').firstMatch(rules)?.group(1) ?? '';
      for (final domain in ['root', 'file', 'database', 'sharedpref']) {
        expect(body, contains('<exclude domain="$domain" />'), reason: '$section يحمل $domain');
      }
    }
  });
}
