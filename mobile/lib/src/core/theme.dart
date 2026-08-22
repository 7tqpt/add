import 'package:flutter/material.dart';

/// ألوان المنصة ومقاييسها.
///
/// منقولة من لوحة التحكم ليبدو الطرفان منصةً واحدة: الأزرق نفسه والرمادي
/// المزرقّ نفسه. وكانت العائلة ذهبيةً على بيج، فصارت زرقاء على أبيضٍ منحازٍ
/// إلى الأزرق — الأبيض المحايد يبدو غير مقصود، والانحياز الخفيف نحو لون
/// العلامة يجعله مُختاراً.
///
/// **وما نُقل حرفياً وما لم يُنقل:**
///
/// الهويّة نُقلت كما هي — الأسطح والحبر واللون المميّز — فهي ما يجعل
/// الطرفين شيئاً واحداً.
///
/// أمّا الألوان الدلالية فلا: اللوحة تستعملها حشواً ونقاطاً، والتطبيق
/// يستعملها **نصّاً** — في شارات الحالة وفي رسائل ملف مقدّم الخدمة. وأصفر
/// اللوحة (‏`#fab219`‏) يعطي على أبيض **١٫٨٣:١**، وأخضرها ‎٣٫٣٥:١‎ — قِيسا
/// لا خُمّنا. فنُقلت عائلة اللون وأُغمقت حتى تُقرأ:
///
///   good ‎#0a7a35‎ → ‎٥٫٤٦:١‎ · warning ‎#976113‎ → ‎٥٫٢٠:١‎ ·
///   critical ‎#b3261e‎ → ‎٦٫٥٤:١‎
///
/// و`muted` أُغمق عن نظيره في اللوحة (‏`#7b8699`‏، ‎٣٫٦٨:١‎) إلى ‎#6b7689‎
/// (‎٤٫٥٩:١‎) وهو من العائلة نفسها: في اللوحة يُقرأ على شاشةٍ كبيرة، وهنا
/// يحمل نصّاً بحجم ‎١١‎ نقطة على جوالٍ بيد.
class AppColors {
  static const page = Color(0xFFF4F7FC);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFEEF2F9);
  static const hairline = Color(0xFFE3E9F3);
  static const ink = Color(0xFF0B1220);
  static const ink2 = Color(0xFF47536B);
  static const muted = Color(0xFF6B7689);

  static const accent = Color(0xFF1D4ED8);
  static const accentInk = Color(0xFFFFFFFF);

  static const good = Color(0xFF0A7A35);
  static const warning = Color(0xFF976113);
  static const critical = Color(0xFFB3261E);
}

/// شفافيّاتُ الأسطح المصبوغة بلون العلامة.
///
/// أرقامٌ هنا لا في كل موضعٍ يحتاجها: `0.08` مكتوبةً في خمسة ملفّات لا تُقاس
/// ولا تُغيَّر إلا بالبحث، وواحدةٌ منها ترتفع فيصير النصُّ عليها لا يُقرأ بلا
/// أن يظهر ذلك في سجلّ. وهي مقيسةٌ في `kit_test`: كلُّ سطحٍ منها والنصُّ
/// الذي عليه فوق ‎٤٫٥:١‎ — أدناها قرصُ الحرف عند ‎٥٫٢٧:١‎.
class Tint {
  /// شارةٌ صغيرة: قسمٌ، أو «فيديو»، أو «مقطع صوتي».
  static const chip = 0.08;

  /// قرصٌ يحمل حرفاً — بديلُ الصورة التي لا وجود لها.
  static const disc = 0.14;

  /// أرضيّةُ صفٍّ يُضغط داخل بطاقةٍ لا تُضغط.
  static const row = 0.05;
}

/// الخطّ العربي المرفق. يُذكر صراحةً في كل نمطٍ مكتوبٍ باليد: النمط الكامل
/// يحلّ محلّ الموروث ولا يرث احتياط الثيمة، فزرٌّ بنمطٍ خاص يفقد العربية
/// ويرسم مربّعات فارغة مكان النصّ.
const arabicFallback = ['NotoNaskhArabic'];

class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    // احتياطٌ لا أصل: يُترك خطّ النظام أوّلاً ليبقى المظهر مألوفاً على الجهاز
    // وبأوزانه الحقيقية، ويُلجأ إلى المرفق حين لا يغطّي النظام العربية — وهو
    // ما يقع على الويب وعلى بعض الأجهزة، فيختفي النصّ كلّه بلا رسالة.
    fontFamilyFallback: arabicFallback,
    scaffoldBackgroundColor: AppColors.page,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      onPrimary: AppColors.accentInk,
      surface: AppColors.surface,
      brightness: Brightness.light,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    ),
    // الورقة السفلية والزرّ العائم يشتقّان لونهما من البذرة في Material
    // فيخرجان بصبغةٍ لم يخترها أحد. اللونان يُثبَّتان هنا: بياض البطاقات
    // للورقة، والأزرق الصريح للزرّ.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.accentInk,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.14),
      // ارتفاع أوسع من الافتراضي: حروف العربية تنزل تحت السطر فتُقصّ في الضيّق.
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontSize: 11,
          height: 1.5,
          fontWeight: FontWeight.w500,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    ),
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink2, displayColor: AppColors.ink),
  );
}
