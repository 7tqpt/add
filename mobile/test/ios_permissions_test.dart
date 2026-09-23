// أذونُ آيفون: كلُّ حزمةٍ تطلب إذناً لها تفسيرٌ في `Info.plist`.
//
// ── ما كُشف ────────────────────────────────────────────────────────────────
//
// في الفحص الأمنيّ: `record` في `pubspec.yaml` و`voice.dart` تناديها،
// و`local_auth` في `biometrics.dart` — وفي `Info.plist` ثلاثةُ تفسيراتٍ لا
// خمسة. فينقص `NSMicrophoneUsageDescription` و`NSFaceIDUsageDescription`.
//
// ── ولماذا هذا أخطرُ ممّا يبدو ─────────────────────────────────────────────
//
// iOS **لا يرفض الإذنَ** حين ينقص التفسير: يقتل العمليّة. فلا رسالةَ حمراء
// يقرؤها صاحبُه، ولا سطرَ في سجلّ، ولا استثناءَ يلتقطه `try` — التطبيقُ
// يختفي من يده لحظةَ ضغطه زرَّ التسجيل. ومراجعةُ App Store تردّ الحزمةَ قبل
// ذلك.
//
// ── ولا يُقاس بشيءٍ سوى هذا ────────────────────────────────────────────────
//
// **لا `flutter analyze` يراه ولا `flutter test` ولا بناءُ الحزمة**: المفتاحُ
// نصٌّ في ملفِّ XML، ولا شيءَ في Dart يشير إليه. ولا يظهر على أندرويد بحال.
// فلا يبلغه إلّا جهازُ آيفون حقيقيٌّ — أو هذا.
//
// ── ويُقاس ما سيقع لا ما كُتب ──────────────────────────────────────────────
//
// «أفي `Info.plist` خمسةُ مفاتيح؟» سؤالٌ يُجاب بنعم اليوم ويبقى نعم بعد أن
// تدخل حزمةٌ سادسةٌ بلا مفتاحها. **فتُقرأ `pubspec.yaml`**: كلُّ حزمةٍ فيها
// من الجدول أدناه تُطالَب بمفاتيحها. فما أُضيفت `camera` أو `contacts` غداً
// إلّا وحمّرت الحزمةُ حتى يُكتب تفسيرُها.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// الحزمةُ ← المفاتيحُ التي يشترطها iOS لمن ضمّها.
///
/// والقائمةُ تنمو بنموّ `pubspec.yaml`، لا بما في `Info.plist` اليوم.
const _required = <String, List<String>>{
  'record': ['NSMicrophoneUsageDescription'],
  'local_auth': ['NSFaceIDUsageDescription'],
  'geolocator': ['NSLocationWhenInUseUsageDescription'],
  'image_picker': ['NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription'],
  'file_picker': ['NSPhotoLibraryUsageDescription'],
  'camera': ['NSCameraUsageDescription'],
  'permission_handler': <String>[],
};

/// **ولا `expect` هنا**: هذه تُنادى قبل أن يبدأ أيُّ اختبار، و`expect` خارجَ
/// اختبارٍ ترمي `OutsideTestException` فيسقط الملفُّ كلُّه عند التحميل برسالةٍ
/// لا تقول ما العلّة. فالملفُّ الناقصُ يُرمى بنصّه.
String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('لا ملفَّ $path');
  return file.readAsStringSync();
}

/// أسماءُ الحزم المعتمَدة في `pubspec.yaml` — من `dependencies` وحدَها.
///
/// وتُقرأ بلا حزمة YAML: السطرُ المعتمَدُ مسافتان ثمّ اسمٌ ثمّ نقطتان، ولا
/// حاجةَ إلى أكثر. (و`dev_dependencies` تُترك: ما لا يُشحَن لا يطلب إذناً.)
Set<String> _dependencies(String pubspec) {
  final out = <String>{};
  var inside = false;
  for (final line in pubspec.split('\n')) {
    if (line.startsWith('dependencies:')) {
      inside = true;
      continue;
    }
    // أيُّ مفتاحٍ في العمود الأوّل يُنهي القسم — `dev_dependencies` أو `flutter`.
    if (inside && line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) break;
    if (!inside) continue;
    final match = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (match != null) out.add(match.group(1)!);
  }
  return out;
}

/// قيمةُ مفتاحٍ نصّيٍّ في `Info.plist`، أو `null` إن لم يكن فيه.
///
/// **ووجودُ المفتاح لا يكفي**: `<string></string>` فارغةٌ تمرّ على أيّ فحصٍ
/// يسأل «أهو موجود؟» — ويردّها App Store، ويرى صاحبُ الجهاز نافذةَ إذنٍ
/// بيضاءَ لا تقول لماذا.
String? _plistString(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>(.*?)</string>',
    dotAll: true,
  ).firstMatch(plist);
  return match?.group(1);
}

void main() {
  final pubspec = _read('pubspec.yaml');
  final plist = _read('ios/Runner/Info.plist');
  final deps = _dependencies(pubspec);

  group('أذونُ آيفون', () {
    test('**لا تُشحن حزمةٌ تطلب إذناً بلا تفسيرٍ لإذنها**', () {
      // ولا يُصدَّق أنّ القراءةَ وقعت: قائمةٌ فارغةٌ تُمرّر كلَّ شيء.
      expect(deps, contains('flutter_secure_storage'),
          reason: 'لم تُقرأ `dependencies` أصلاً — فالفحصُ كلُّه فارغ');

      final missing = <String>[];
      for (final entry in _required.entries) {
        if (!deps.contains(entry.key)) continue;
        for (final key in entry.value) {
          final value = _plistString(plist, key);
          if (value == null) {
            missing.add('${entry.key} تشترط $key — وليس في Info.plist');
          } else if (value.trim().isEmpty) {
            missing.add('${entry.key} تشترط $key — وهو فارغٌ في Info.plist');
          }
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('**والميكروفونُ بعينه — فهو الذي كان ناقصاً**', () {
      expect(deps, contains('record'),
          reason: 'شِيلت `record`؟ فيُشال هذا الاختبارُ معها');
      expect(_plistString(plist, 'NSMicrophoneUsageDescription'), isNotNull,
          reason: 'التطبيقُ يُقتل عند أوّل ضغطةٍ على زرّ التسجيل');
    });

    test('**والوجهُ كذلك**', () {
      expect(deps, contains('local_auth'));
      expect(_plistString(plist, 'NSFaceIDUsageDescription'), isNotNull,
          reason: 'التطبيقُ يُقتل عند أوّل نداءٍ لـFace ID');
    });

    test('**والنصُّ عربيٌّ يقول لماذا لا ماذا**', () {
      // نافذةُ الإذن تعرض هذا النصَّ حرفاً لصاحب الجهاز. ونصٌّ إنجليزيٌّ من
      // قالبٍ أو «We need microphone access» يُقرأ تطبيقاً غيرَ مكتمل.
      for (final key in const [
        'NSMicrophoneUsageDescription',
        'NSFaceIDUsageDescription',
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'NSLocationWhenInUseUsageDescription',
      ]) {
        final value = _plistString(plist, key)!;
        expect(RegExp('[؀-ۿ]').hasMatch(value), isTrue,
            reason: '$key ليس نصّاً عربيّاً: «$value»');
        expect(value.trim().length, greaterThan(20),
            reason: '$key أقصرُ من أن يقول سبباً: «$value»');
      }
    });
  });
}
