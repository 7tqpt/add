// اختيارُ النسخة التي تُعرض، ورقمُ البناء الذي يُقارَن به.
//
// **وأخطرُ ما يُقاس هنا حالتان متقابلتان:** ألّا يُعرض تحديثٌ على من هو
// عليه أصلاً — فيدور في حلقةٍ ينزّل ما عنده — وألّا يُحبس أحدٌ خلف شاشةٍ
// إجباريّةٍ زرُّها لا يفتح شيئاً.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_update.dart';
import 'package:aras/src/core/app_version.dart';

AppRelease _r(
  int build, {
  String url = 'https://sdd.company/farhati.apk',
  bool force = false,
  int rollout = 100,
  String version = '',
}) =>
    AppRelease(
      build: build,
      version: version.isEmpty ? '1.0.$build' : version,
      notes: '',
      downloadUrl: url,
      forceUpdate: force,
      rolloutPercent: rollout,
    );

void main() {
  // ==========================================================================
  //  **رقمُ البناء لا يفترق عن `pubspec.yaml`**
  // ==========================================================================

  test('**والثابتُ هنا هو الذي في pubspec بعينه**', () {
    // ولولا هذا الحارس لَكان الثابتُ أسوأَ من حزمةٍ أصليّة: رقمٌ يُنسى
    // تحديثُه فيظنّ التطبيق نفسَه قديماً أبداً — أو حديثاً أبداً فلا يُخبر
    // أحداً بشيء.
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final value = line.split(':')[1].trim();
    final parts = value.split('+');

    expect(appVersionName, parts[0], reason: 'اسمُ النسخة افترق عن pubspec');
    expect(appBuild, int.parse(parts[1]), reason: 'رقمُ البناء افترق عن pubspec');
  });

  // ==========================================================================
  //  **لا يُعرض على من هو عليه**
  // ==========================================================================

  group('ما لا يُعرض', () {
    test('**ولا نسخةٌ تُعرض على من هو عليها**', () {
      // ولولا ذلك لَنزّل صاحبُ الجهاز ما عنده، ثمّ عاد فوجد الشريطَ كما هو.
      expect(pickUpdate([_r(7)], installedBuild: 7, bucket: 0), isNull);
    });

    test('ولا أقدمُ منه', () {
      expect(pickUpdate([_r(3)], installedBuild: 7, bucket: 0), isNull);
    });

    test('**ولا نسخةٌ بلا رابطٍ يُنزَّل منه**', () {
      // شريطٌ يقول «نزّلها» وزرُّه لا يفتح شيئاً وعدٌ يُخلَف.
      expect(pickUpdate([_r(9, url: '')], installedBuild: 1, bucket: 0), isNull);
    });

    test('**ولا رابطٌ بمخطّطٍ غير https**', () {
      for (final bad in [
        'http://sdd.company/a.apk',
        'javascript:alert(1)',
        'file:///data/a.apk',
        'intent://x',
        'https://',
      ]) {
        expect(
          pickUpdate([_r(9, url: bad)], installedBuild: 1, bucket: 0),
          isNull,
          reason: bad,
        );
      }
    });

    test('ولا شيءَ من قائمةٍ فارغة', () {
      expect(pickUpdate([], installedBuild: 1, bucket: 0), isNull);
    });
  });

  // ==========================================================================
  //  الطرحُ التدريجيّ
  // ==========================================================================

  group('نسبةُ الطرح', () {
    test('من كان في الحصّة رآها', () {
      expect(pickUpdate([_r(9, rollout: 10)], installedBuild: 1, bucket: 4)?.build, 9);
    });

    test('ومن كان خارجها لم يرَها', () {
      expect(pickUpdate([_r(9, rollout: 10)], installedBuild: 1, bucket: 40), isNull);
    });

    test('والحدُّ نفسُه خارجُها — ١٠٪ عشرةٌ لا أحدَ عشرَ', () {
      expect(pickUpdate([_r(9, rollout: 10)], installedBuild: 1, bucket: 9)?.build, 9);
      expect(pickUpdate([_r(9, rollout: 10)], installedBuild: 1, bucket: 10), isNull);
    });

    test('وطرحُ صفرٍ لا يصل أحداً', () {
      expect(pickUpdate([_r(9, rollout: 0)], installedBuild: 1, bucket: 0), isNull);
    });

    test('**ويُعرض أحدثُ ما يستحقّه لا أحدثُ ما وُجد**', () {
      // ٣ مطروحةٌ على عشرةٍ وهو ليس منها، و٢ على الجميع. فالصوابُ أن يُنقل
      // إلى ٢ لا أن يُترك على ١ لأنّ الأحدثَ لا يشمله.
      final picked = pickUpdate(
        [_r(3, rollout: 10), _r(2, rollout: 100)],
        installedBuild: 1,
        bucket: 50,
      );
      expect(picked?.build, 2);
    });

    test('وإن شملته الأحدثُ أخذها هي', () {
      final picked = pickUpdate(
        [_r(3, rollout: 10), _r(2, rollout: 100)],
        installedBuild: 1,
        bucket: 5,
      );
      expect(picked?.build, 3);
    });

    test('**والإجباريُّ لا تحجبه نسبةُ الطرح**', () {
      // من أُشعل عليه «إجباريّ» فلأنّ ما قبله لا يصلح، وطرحُه على عشرةٍ في
      // المئة يترك تسعين في المئة على المكسور.
      expect(
        pickUpdate([_r(9, rollout: 10, force: true)],
            installedBuild: 1, bucket: 90)?.build,
        9,
      );
    });
  });

  // ==========================================================================
  //  **المنع**
  // ==========================================================================

  group('التحديثُ الإجباريّ', () {
    test('يمنع من كان دونه', () {
      expect(mustUpdate([_r(9, force: true)], installedBuild: 1), isTrue);
    });

    test('ولا يمنع من بلغه', () {
      expect(mustUpdate([_r(9, force: true)], installedBuild: 9), isFalse);
    });

    test('**ولا يمنع إجباريٌّ في الماضي مضى عليه صاحبُه**', () {
      expect(mustUpdate([_r(2, force: true)], installedBuild: 5), isFalse);
    });

    test('**ويمنع إجباريٌّ متخطًّى وإن لم يكن الأحدث**', () {
      // من كان على ١ وصدرت ٢ إجباريّةً ثمّ ٣ عاديّة: الإجباريّةُ في طريقه،
      // وقد أُشعلت لأنّ ١ لا يصلح — وذلك لم يتغيّر.
      expect(
        mustUpdate([_r(3), _r(2, force: true)], installedBuild: 1),
        isTrue,
      );
    });

    test('وعاديٌّ وحده لا يمنع', () {
      expect(mustUpdate([_r(9)], installedBuild: 1), isFalse);
    });
  });

  // ==========================================================================
  //  حارسُ الرابط
  // ==========================================================================

  test('وحارسُ الرابط يقبل https بمضيفٍ ويردّ ما عداه', () {
    expect(safeDownloadUrl('https://sdd.company/a.apk'), isTrue);
    expect(safeDownloadUrl('https://github.com/7tqpt/add/releases'), isTrue);
    for (final bad in ['', 'http://x.com', 'https://', 'ftp://x', 'x.com']) {
      expect(safeDownloadUrl(bad), isFalse, reason: bad);
    }
  });

  test('والمنصّةُ اسمٌ من اثنين لا غير', () {
    expect(['android', 'ios'], contains(appPlatform));
  });
}
