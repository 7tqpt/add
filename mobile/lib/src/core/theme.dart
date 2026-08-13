import 'package:flutter/material.dart';

/// ألوان المنصة ومقاييسها.
///
/// منقولة من لوحة التحكم ليبدو الطرفان منصةً واحدة: الذهبي نفسه والرمادي نفسه.
/// والألوان الدلالية هي التي فُحص تباينها هناك، فلا تُخترع هنا من جديد.
class AppColors {
  static const page = Color(0xFFFAF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF5F2EC);
  static const hairline = Color(0xFFE7E1D6);
  static const ink = Color(0xFF1C1A17);
  static const ink2 = Color(0xFF55504A);
  static const muted = Color(0xFF8A8375);

  static const accent = Color(0xFF9A6A00);
  static const accentInk = Color(0xFFFFFFFF);

  static const good = Color(0xFF2F7D52);
  static const warning = Color(0xFFA9761A);
  static const critical = Color(0xFFB3261E);
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
