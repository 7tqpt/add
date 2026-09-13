/// البصمة: بابٌ ثانٍ لقفل التطبيق — **لا بديلٌ عن رمزه**.
///
/// ── لماذا لا تُلغي الرمز ────────────────────────────────────────────────────
///
/// الحسّاسُ يُخفق، والإصبعُ يُبلَّل، والجهازُ يُبدَّل، ومن رُقّي نظامُه قد
/// تُمحى بصماتُه المسجّلة. فبلا رمزٍ يبقى صاحبُ الحساب محبوساً عن حجوزاته
/// ومحادثاته — **وهو أذىً أكبرُ من الذي يمنعه القفل**، وهي العلّةُ نفسُها
/// التي من أجلها كُتب «نسيتُ الرمز» في `app_lock.dart`.
///
/// فالبصمةُ طريقٌ أسرعُ إلى القفل نفسِه، والرمزُ باقٍ تحتها أبداً.
///
/// ── وما تحرسه وما لا تحرسه ─────────────────────────────────────────────────
///
/// **حرزٌ على هذا الجهاز وحدَه** — كالرمز تماماً: تمنع من يفتح جوالك أن يرى
/// حجوزاتك ومحادثاتك. ولا تحرس الخادمَ بشيء: من ملك بريدَك وكلمةَ مرورك
/// دخل من جهازٍ آخرَ ولا بصمةَ تُسأل. وما يحرس الخادمَ كلمةُ المرور وRLS.
///
/// ── وشرطٌ في أندرويد لا يقرؤه محلّلٌ ولا اختبار ─────────────────────────────
///
/// `local_auth` تشترط أن يرث `MainActivity` من `FlutterFragmentActivity` لا
/// `FlutterActivity` — وإلّا رمت `no_fragment_activity` عند أوّل نداء.
/// **ولا `flutter analyze` ولا الاختباراتُ تقرأ ملفّاً في `android/`**، فهذا
/// من صنف العطب الذي لا يظهر إلّا في حزمةٍ حقيقيّةٍ على جهازٍ حقيقيّ.
library;

import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import 'i18n.dart';

/// بديلٌ يُركَّب في الاختبارات — **لا حسّاسَ في `flutter test`**.
///
/// ولولاه لَما قِيس شيءٌ من هذا: الحزمةُ شيفرةٌ أصليّةٌ لا وجودَ لها في بيئة
/// الاختبار، فكلُّ نداءٍ يرمي. وهو نظيرُ `lockStorageOverride`.
Biometrics? biometricsOverride;

/// ما يعرفه التطبيقُ عن البصمة — واجهةٌ تُركَّب وتُبدَّل.
class Biometrics {
  const Biometrics();

  /// أفي الجهاز حسّاسٌ مُسجَّلةٌ فيه بصمة؟
  ///
  /// **وثلاثةُ أسئلةٍ لا واحد:** جهازٌ يدعم، وحسّاسٌ يُسأل، و**بصمةٌ مسجّلةٌ
  /// فعلاً**. ومن لم يسجّل بصمةً في جهازه يرى زرّاً يضغطه فلا يقع شيء.
  Future<bool> available() async {
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported()) return false;
      if (!await auth.canCheckBiometrics) return false;
      return (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      // جهازٌ لا يجيب: لا بصمةَ فيه، ولا يُسقَط التطبيق لأجل ذلك.
      return false;
    }
  }

  /// يسأل الجهازَ البصمةَ، ويعيد `true` إن طابقت.
  ///
  /// **و`biometricOnly` مقصودة:** الزرُّ يقول «افتح بالبصمة»، فلو قَبِل
  /// نمطَ قفلِ الجهاز أو رمزَه لَفتح القفلَ بشيءٍ لم يَعِد به — ومن أعطى
  /// جوالَه مفتوحاً لأخيه أعطاه معه كلَّ شيء.
  Future<bool> authenticate() async {
    final auth = LocalAuthentication();
    try {
      return await auth.authenticate(
        localizedReason: tr('ضع بصمتك لفتح فرحتي'),
        authMessages: [
          AndroidAuthMessages(
            signInTitle: tr('فتح فرحتي'),
            biometricHint: '',
            biometricNotRecognized: tr('لم تُعرَف البصمة'),
            biometricRequiredTitle: tr('لا بصمةَ مسجّلة'),
            cancelButton: tr('إلغاء'),
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true,
          // **ولا `stickyAuth`:** يُبقي الحوارَ قائماً بعد عودة التطبيق من
          // الخلفيّة — وقفلُنا يُقفل عند العودة، فيجتمع حوارٌ قديمٌ وشاشةُ
          // قفلٍ جديدة.
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      // **وكلُّ إخفاقٍ يُقرأ «لم تُفتح» لا «عطب».** الرمزُ تحتها، وشاشةُ
      // خطإٍ في وجه من يريد أن يدخل حسابَه لا تفيده بشيء.
      return false;
    }
  }
}

/// النسخةُ التي يناديها التطبيق — أو البديلُ في الاختبارات.
Biometrics get biometrics => biometricsOverride ?? const Biometrics();
