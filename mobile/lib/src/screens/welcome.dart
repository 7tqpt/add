import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../ui/kit.dart';
import 'auth.dart';

/// شاشة البداية — أوّلُ ما يراه من فتح التطبيق ولم يسجّل بعد.
///
/// **ولمن تُعرض ولمن لا تُعرض:** لمن لا جلسة له وحده. ومن سجّل دخوله مرّةً
/// يفتح التطبيق على شاشته مباشرةً — شاشةُ ترحيبٍ تسبق كلَّ فتحةٍ للتطبيق
/// عائقٌ يوميٌّ لا مقدّمة.
///
/// **والقوسُ مرسومٌ بالشيفرة لا صورةً مرفقة:** صورةٌ بحجم الشاشة تزيد الحزمة
/// مئاتِ الكيلوبايتات وتبهت على الشاشات العالية، والقوسُ المرسوم يخرج حادّاً
/// على كل كثافة. ولو أُريدت صورةُ صنعاء خلفه فمكانُها `assets/` — وتُطلب من
/// صاحبها لا تُؤخذ من الشبكة.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.accentDeep, AppColors.accent, AppColors.accentDeep],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              children: [
                const Spacer(),
                // القوسُ يحوي الاسم لا يجاوره: هكذا يُقرأ إطاراً لا زخرفةً
                // ملقاةً في الأعلى.
                Expanded(
                  flex: 6,
                  child: CustomPaint(
                    painter: _ArchPainter(),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 40,
                            color: AppColors.goldOnAccent,
                          ),
                          const SizedBox(height: Space.md),
                          const Text(
                            'فرحتي',
                            style: TextStyle(
                              fontSize: 44,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldOnAccent,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            'للأعراس اليمنية',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.goldOnAccent.withValues(alpha: 0.9),
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                          const SizedBox(height: Space.lg),
                          Text(
                            'كل خدمات زفافك في مكان واحد',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.7,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // زرٌّ ذهبيٌّ بحبرٍ نبيذيّ — لا نبيذيٌّ على نبيذيّ فيختفي.
                // والأبيضُ على الذهب لا يُقرأ (‎١٫٦٦:١‎)، والنبيذيُّ عليه
                // ‎٦٫٤٥:١‎.
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.goldOnAccent,
                    foregroundColor: AppColors.accentDeep,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RolePickerScreen(session: session)),
                  ),
                  child: const Text(
                    'ابدأ رحلتك',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// قوسٌ يمنيٌّ بخطٍّ ذهبيّ — قوسان متداخلان وتاجٌ مدبَّب.
class _ArchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.goldOnAccent.withValues(alpha: 0.75)
      ..strokeWidth = 2;

    void arch(double inset, double alpha, double width) {
      gold
        ..color = AppColors.goldOnAccent.withValues(alpha: alpha)
        ..strokeWidth = width;

      final w = size.width - inset * 2;
      final h = size.height - inset * 2;
      if (w <= 0 || h <= 0) return;

      final left = inset;
      final right = inset + w;
      final bottom = inset + h;
      // ثلثُ الارتفاع قوسٌ مدبَّب وثلثاه قائمان: نسبةُ القمرية الصنعانية.
      final shoulder = inset + h * 0.42;
      final peak = inset;

      final path = Path()
        ..moveTo(left, bottom)
        ..lineTo(left, shoulder)
        // ضلعان يلتقيان في رأسٍ مدبَّب لا نصفِ دائرة.
        ..quadraticBezierTo(left, peak + h * 0.10, size.width / 2, peak)
        ..quadraticBezierTo(right, peak + h * 0.10, right, shoulder)
        ..lineTo(right, bottom);
      canvas.drawPath(path, gold);
    }

    arch(0, 0.85, 2.2);
    arch(math.min(14, size.width * 0.06), 0.45, 1.2);
  }

  @override
  bool shouldRepaint(_ArchPainter oldDelegate) => false;
}

/// «اختر نوع الحساب» — ثلاثةُ أبوابٍ إلى بابٍ واحد.
///
/// **وهي طريقٌ لا قسمة:** الحسابُ واحدٌ في الحالات الثلاث. عروسٌ وعريسٌ
/// كلاهما عميل، ومقدّمُ الخدمة عميلٌ **زاد** عليه ملفَّ عرض — والشخص نفسه قد
/// يحجز لعرس أخيه ويبيع خدمة التصوير، فحبسه في أحد الطرفين يُلزمه بحسابين.
///
/// فما تفعله أنها تختصر الطريق: من قال «مقدّم خدمة» يُساق إلى إنشاء ملفّه فور
/// إكمال بياناته، بدل أن يبحث عنه في «حسابي» بعد أسبوع — وأكثرُهم لم يكن
/// يبحث، فيبقى مسجَّلاً عميلاً وهو جاء ليبيع.
class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key, required this.session});
  final Session session;

  void _go(BuildContext context, String intent) {
    session.signUpIntent = intent;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuthScreen(session: session, startOnSignUp: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.page, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
        children: [
          const Center(
            child: Text(
              'فرحتي',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          const Center(
            child: Text(
              'مرحباً بك في فرحتي',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          const Center(child: Muted('اختر نوع الحساب', size: 13)),
          const SizedBox(height: Space.xl),

          _RoleCard(
            icon: Icons.favorite_rounded,
            title: 'أنا عروس',
            body: 'أبحث عن خدمات وأخطّط لحفل زفافي',
            onTap: () => _go(context, 'bride'),
          ),
          const SizedBox(height: Space.md),
          _RoleCard(
            icon: Icons.favorite_border_rounded,
            title: 'أنا عريس',
            body: 'أبحث عن خدمات وأخطّط لحفل زفافي',
            onTap: () => _go(context, 'groom'),
          ),
          const SizedBox(height: Space.md),
          _RoleCard(
            icon: Icons.storefront_rounded,
            title: 'مقدّم خدمة',
            body: 'أعرض خدماتي وأستقبل الحجوزات',
            onTap: () => _go(context, 'provider'),
          ),

          const SizedBox(height: Space.lg),
          // **يُقال صراحةً:** الاختيارُ طريقٌ لا قفل. ومن لم يُقل له ذلك ظنّ
          // أنه يفتح حساباً من نوعٍ لا يُبدَّل، فتردّد أو فتح حسابين.
          const Center(
            child: Muted(
              'الحساب واحد — تستطيع أن تعرض خدماتك لاحقاً أو أن تحجز، أيّاً كان اختيارك',
              size: 12,
            ),
          ),
          const SizedBox(height: Space.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Muted('لديك حساب بالفعل؟', size: 13),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => AuthScreen(session: session)),
                ),
                child: const Text('تسجيل الدخول'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    children: [
      Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: Tint.disc),
            ),
            child: Icon(icon, size: 24, color: AppColors.accent),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Muted(body, size: 12.5),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, size: 22, color: AppColors.muted),
        ],
      ),
    ],
  );
}
