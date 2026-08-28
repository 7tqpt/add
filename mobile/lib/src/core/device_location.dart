// موقعُ الجهاز — ويُقرأ في موضعٍ واحدٍ من التطبيق كلِّه.
//
// **وهذا الملفُّ هو الموضع.** لا `Geolocator` في شاشةٍ ولا في نموذج: من أراد
// أن يعرف أين يُقرأ الموقعُ يقرأ ملفّاً واحداً، ومن أراد تبديل الحزمة يبدّل
// جوفَ دالّةٍ واحدة.
//
// **ولا يُقرأ إلّا بضغطةٍ صريحة.** لا في الخلفيّة، ولا عند الإقلاع، ولا
// لترتيب البحث — ذاك من العنوان المحفوظ (انظر `nearby.sql`). وهذه ضغطةُ من
// يقف في القاعة يضع دبّوسها.
import 'package:geolocator/geolocator.dart';

import 'geo.dart';

/// بديلٌ يُركَّب في الاختبارات.
///
/// **ولماذا يُحتاج إليه:** `Geolocator` تنادي شيفرةً أصليّةً لا وجودَ لها في
/// `flutter test` — فبلا هذا الباب لا تُقاس أربعةُ مساراتٍ من الفشل إلّا
/// على جهاز، وهي بالضبط المساراتُ التي تُنسى: الإذنُ المرفوضُ نهائيّاً،
/// وخدمةُ الموقع المطفأة.
Future<LocationResult> Function()? locationOverride;

/// الموقعُ الحاليّ، أو سببٌ يُقال لصاحبه.
///
/// والترتيبُ مقصود: تُسأل الخدمةُ أوّلاً ثمّ الإذن. فمن أطفأ الموقعَ في جهازه
/// كلِّه يُقال له ذلك، ولا يُعرض عليه طلبُ إذنٍ يقبله ثمّ لا يصل شيء.
Future<LocationResult> currentLocation() async {
  final override = locationOverride;
  if (override != null) return override();

  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failed(LocationFailure.servicesOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failed(LocationFailure.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult.failed(LocationFailure.denied);
    }

    // **ومهلةٌ مكتوبة.** بلا حدٍّ يبقى الطلبُ معلّقاً إلى الأبد داخل بناءٍ
    // خرسانيّ، والدائرةُ تدور والزرُّ لا يعود — فيظنّ صاحبُه التطبيق معلّقاً.
    // وخمسَ عشرة ثانيةً تكفي قفلاً بارداً في مكانٍ مكشوف.
    //
    // و`medium` لا `best`: الفرقُ بينهما أمتارٌ قليلة ويكلّف ثوانيَ وبطّاريّة،
    // وما يُراد هنا تحريكُ الخريطة إلى المكان ثمّ يضبط الدبّوسَ بإصبعه.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    final point = GeoPoint(position.latitude, position.longitude);
    // ونقطةٌ خارج المدى — أو صفرٌ صفر — تُردّ ككلّ نقطةٍ غيرِ صالحة: بعضُ
    // المحاكيات تُعيد «جزيرة نُل» حين لا موقعَ لها.
    return point.isValid
        ? LocationResult.found(point)
        : const LocationResult.failed(LocationFailure.unavailable);
  } catch (_) {
    // المهلةُ تنتهي فترمي، وكذلك يفعل جهازٌ لا مستشعرَ فيه. والسببُ واحدٌ
    // من جهة صاحبه: لم يصل موقع.
    return const LocationResult.failed(LocationFailure.unavailable);
  }
}
