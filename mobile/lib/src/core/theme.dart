import 'package:flutter/material.dart';

/// ألوان المنصة ومقاييسها.
///
/// **نبيذيٌّ على كريم، وذهبٌ للزينة** — هويّةُ «فرحتي» كما رُسمت في لوحة
/// التصميم، لا زرقةُ لوحة التحكم. وكان التطبيق يحمل أزرقها ليبدو الطرفان
/// منصّةً واحدة، وهذا صحيحٌ في التقنية خطأٌ في السوق: من يشتري عرساً لا
/// يرى لوحةَ الإدارة أبداً، ويرى تطبيقاً بلون المصارف بينما هو يجهّز فرحاً.
/// فالوحدة تُطلب مع من يراهما معاً — والمسؤول وحده يراهما.
///
/// والكريم لا الأبيض: الأبيض المحايد يبدو غير مقصود، وانحيازُه الخفيف نحو
/// دفء العلامة يجعله مُختاراً — وهي القاعدة نفسها التي كانت تُميل الأبيض
/// إلى الزرقة من قبل، مطبَّقةً على عائلةٍ أخرى.
///
/// **وكلُّ لونٍ هنا مقيسٌ لا مذوق** (`kit_test` يعيد القياس في كل تشغيل):
///
///   ink ‎١٧٫٦١:١‎ · ink2 ‎١٠٫٤٢:١‎ · muted ‎٥٫٩٣:١‎ · accent ‎١٠٫٧٧:١‎
///   والأبيضُ على النبيذيّ ‎١٠٫٧٧:١‎.
///
/// وذهبان لا ذهبٌ واحد، لأن الذهب الواحد لا يُقرأ في الموضعين: ذهبُ لوحة
/// التصميم (‏`#c9a227`‏) على النبيذيّ يعطي ‎٤٫٤٥:١‎ — تحت العتبة بقليل —
/// وعلى الأبيض ‎٢٫٢٥:١‎ وهو غيرُ مقروءٍ أصلاً. فصار `gold` للحبر على الفاتح
/// (‎٤٫٦٨:١‎) و`goldOnAccent` للحبر على النبيذيّ (‎٥٫٤٥:١‎).
///
/// أمّا الألوان الدلالية فبقيت كما هي: الأخضر والأحمر والكهرماني معانٍ لا
/// أذواق، وصبغُها بالنبيذيّ يجعل «مرفوض» و«مؤكَّد» أخوين في اللون.
class AppColors {
  static const page = Color(0xFFFBF4EF);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF6E9E6);
  static const hairline = Color(0xFFEBDCD4);
  static const ink = Color(0xFF2A1119);
  static const ink2 = Color(0xFF54383F);
  static const muted = Color(0xFF7A5C64);

  static const accent = Color(0xFF7B0F2E);
  static const accentInk = Color(0xFFFFFFFF);

  /// طرفا التدرّج النبيذيّ — رأسُ الشاشة والبطاقات الكبيرة.
  static const accentLift = Color(0xFF9A1B3E);
  static const accentDeep = Color(0xFF5C0820);

  /// ذهبٌ على الفاتح (‎٤٫٦٨:١‎)، وذهبٌ على النبيذيّ (‎٥٫٤٥:١‎).
  static const gold = Color(0xFF9A6B18);
  static const goldOnAccent = Color(0xFFD9B45C);

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

/// خطُّ العلامة — IBM Plex Sans Arabic، وهو خطُّ لوحة التحكم نفسه.
///
/// **ولماذا يُشحن بدل خطّ النظام:** كان التطبيق يترك خطّ الجهاز أوّلاً،
/// فيخرج الشكلُ مختلفاً على كل جوال — نُسخُ سامسونج بخطّها، وشاومي بخطّها،
/// ومن غيّر خطّ نظامه بخطّه هو. وهويّةٌ تتبدّل بتبدّل الجهاز ليست هويّة.
/// فصار المرفقُ أصلاً لا احتياطاً، بأربعة أوزان لأن نصفَ التصميم وزنٌ:
/// عنوانٌ ثقيلٌ فوق سطرٍ خفيف يُقرأ سُلَّماً، وكلاهما بوزنٍ واحد يُقرأ
/// كتلةً.
///
/// ورخصتُه SIL OFL — مفتوحةٌ تُشحن في التطبيقات، ونصُّها في
/// `assets/fonts/IBMPlexSansArabic-OFL.txt`.
const brandFont = 'IBMPlexSansArabic';

/// احتياطُ العربية. يُذكر صراحةً في كل نمطٍ مكتوبٍ باليد: النمط الكامل
/// يحلّ محلّ الموروث ولا يرث احتياط الثيمة، فزرٌّ بنمطٍ خاص يفقد العربية
/// ويرسم مربّعات فارغة مكان النصّ.
const arabicFallback = [brandFont, 'NotoNaskhArabic'];

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
    // أصلٌ لا احتياط — انظر `brandFont`. والاحتياط يبقى خلفه: النسخُ يغطّي
    // ما لا يغطّيه Plex من محارف، فلا يختفي نصٌّ بلا رسالة.
    fontFamily: brandFont,
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
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    ),
    // الورقة السفلية والزرّ العائم يشتقّان لونهما من البذرة في Material
    // فيخرجان بصبغةٍ لم يخترها أحد. اللونان يُثبَّتان هنا: بياض البطاقات
    // للورقة، والنبيذيّ الصريح للزرّ.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
