import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

/// صورةٌ اختارها صاحبُها — اسمُها لامتدادها، وبايتاتُها للرفع.
typedef PickedImage = ({String name, Uint8List bytes});

/// ورقةُ «التقاط صورة / اختيار من المعرض»، ثمّ الاختيارُ مقيساً ومضغوطاً.
///
/// **وواحدةٌ لا ثلاثُ نسخ.** كانت الورقةُ نفسُها مكتوبةً في «تعديل بياناتي»
/// وفي شعار المزوّد، وكان الغلافُ سيكون ثالثَها. ونسخةٌ رابعةٌ تعني حدّاً
/// يُرفع في واحدةٍ ويُنسى في أخواتها.
///
/// **ويُقاس عند الالتقاط لا بعده:** صورةُ كاميرا الجوال تتجاوز خمسة
/// ميجابايت، وحدُّ السلّة اثنان — ورفعُها على شبكةٍ يمنية عذاب.
///
/// **والغلافُ أعرضُ من القرص**، فمقاسُه يُمرَّر ولا يُفترض: قرصٌ يُقصّ إلى
/// ‎٨٠٠×٨٠٠‎ كافٍ، وغلافٌ عرضُه الشاشةُ كلُّها بـ‎٨٠٠‎ يخرج مشوّشاً على جوالٍ
/// عرضُه ‎١٠٨٠‎.
///
/// ويعود `null` لمن ألغى — **وهو إلغاءٌ لا خطأ**، فلا رسالةَ حمراء.
Future<PickedImage?> pickImage(
  BuildContext context, {
  required double maxWidth,
  required double maxHeight,
  int quality = 85,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
            title: Text(tr('التقاط صورة')),
            onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
            title: Text(tr('اختيار من المعرض')),
            onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
          ),
          const SizedBox(height: Space.sm),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    imageQuality: quality,
  );
  if (file == null) return null;
  return (name: file.name, bytes: await file.readAsBytes());
}

/// مقاسُ الغلاف: عريضٌ ومنخفض — نسبةُ الشريط في الرأس تقريباً.
const coverMaxWidth = 1600.0;
const coverMaxHeight = 900.0;
