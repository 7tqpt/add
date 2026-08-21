import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// تُحمَّل الخطوط الحقيقية قبل كل اختبار في هذا المجلّد.
///
/// وليست زينةً للّقطات: إطار الاختبار يرسم بخطٍّ بديلٍ مقاساتُه غير مقاسات
/// الخطّ المرفق، فالنصّ العربي يخرج بعرضٍ وارتفاعٍ غير اللذين يخرج بهما على
/// الجهاز. وبطاقةُ قسمٍ أفاضت خليّتَها ‎١٫٣‎ بكسل مرّت في كل الاختبارات ولم
/// تظهر إلّا حين رُسمت بـ«نوتو نسخ» نفسه — أي على أجهزة الناس وحدها.
///
/// و`flutter_test_config.dart` باسمه هذا: الإطار يبحث عنه ويلفّ به كل ملفّات
/// الاختبار في المجلّد، فلا يحتاج ملفٌّ جديدٌ أن يتذكّر شيئاً.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _load('NotoNaskhArabic', ['assets/fonts/NotoNaskhArabic-Regular.ttf']);
  await _load('Roboto', [
    'assets/fonts/Roboto-Regular.ttf',
    'assets/fonts/Roboto-Medium.ttf',
  ]);

  // أيقونات Material من مخبأ Flutter — بها تُرسم اللقطات بأيقوناتها لا
  // بمربّعاتٍ فارغة. وغيابُها لا يُسقط شيئاً: مقاس الأيقونة ثابتٌ لا يتبع
  // الخطّ، فالتخطيط واحدٌ معها وبدونها.
  // صعودٌ حتى يُعثر عليه لا عدُّ درجات: المنفّذ قد يكون `dart` وقد يكون
  // `flutter_tester`، وبينهما فرقٌ في العمق — فعدَّ الدرجاتُ أخطأ، ومرّ
  // الخطأ صامتاً وخرجت اللقطات بمربّعاتٍ مكان الأيقونات.
  for (var dir = File(Platform.resolvedExecutable).parent; ; dir = dir.parent) {
    final font = File('${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (font.existsSync()) {
      await _load('MaterialIcons', [font.path]);
      break;
    }
    if (dir.path == dir.parent.path) break;
  }

  await testMain();
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) return;
    loader.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}
