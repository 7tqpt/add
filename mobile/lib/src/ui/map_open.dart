// فتحُ نقطةٍ في تطبيق الخرائط على الجهاز.
//
// **ولا خريطةَ داخل التطبيق هنا.** ما يحتاجه من يريد الوصول هو **الملاحة** —
// صوتٌ يقول «انعطف يميناً» — وهي في تطبيق الخرائط لا في شاشةٍ نرسمها. ورسمُ
// خريطةٍ ثمّ وضعُ زرٍّ فيها يفتح خرائطَ الجهاز خطوةٌ زائدةٌ بين الرجل وطريقه.
//
// **وهنا لا في شاشةٍ منهما:** يفتحها مقدّمُ الخدمة ليصل إلى بيت العرس، ويفتحها
// العميلُ ليعرف أين المحلّ. ونسختان متطابقتان تفترقان بمرور الوقت — وهذا وقع
// في هذا المشروع مرّتين.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/geo.dart';
import 'kit.dart';

Future<void> openMap(BuildContext context, GeoPoint point) async {
  final ok = await launchUrl(
    Uri.parse(mapsUrl(point)),
    mode: LaunchMode.externalApplication,
  );
  // **والإحداثيّتان في الرسالة عمداً:** من لا تطبيقَ خرائطَ في جهازه يستطيع
  // نسخهما وإرسالهما، وهو خيرٌ من «تعذّر» مجرّدة.
  if (!ok && context.mounted) {
    showMessage(context, 'تعذّر فتح الخرائط — الموقع: ${point.text}');
  }
}
