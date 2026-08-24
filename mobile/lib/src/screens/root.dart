import 'package:flutter/material.dart';

import '../core/session.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'auth.dart';
import 'onboarding.dart';
import 'customer_shell.dart';
import 'provider_shell.dart';

/// بوّابة الإقلاع: جلسة، ثم ملف، ثم دور.
///
/// الترتيب مقصود — من لا جلسة له لا معنى لسؤاله عن دوره، ومن لا ملف له لا
/// يستطيع الحجز ولو كان مسجَّل الدخول.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.loading) {
          return const Scaffold(body: LoadingBlock(label: 'جارٍ التحقق…'));
        }
        if (!session.signedIn) return AuthScreen(session: session);
        // قبل شاشة الإكمال: من تعذّرت قراءة هويته لعطبٍ في القاعدة ليس
        // «مستخدماً بلا ملف»، وسَوقُه إلى الإكمال يُخفي السبب ويُفشل الحفظ.
        if (session.identityError != null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('تعذّرت قراءة حسابك'),
              actions: [TextButton(onPressed: session.signOut, child: const Text('خروج'))],
            ),
            body: ErrorBlock(
              message:
                  'دخولك نجح، لكن قراءة ملفك من قاعدة البيانات فشلت:\n\n'
                  '${session.identityError}\n\n'
                  '${identityHint(session.identityErrorCode, session.clockDrift)}',
              onRetry: session.refreshIdentity,
            ),
          );
        }
        if (session.needsProfile) return OnboardingScreen(session: session);
        return session.asProvider
            ? ProviderShell(session: session)
            : CustomerShell(session: session);
      },
    );
  }
}

/// ما يُقال لصاحب الجهاز عن العطب — **بحسب رمزه لا تخميناً**.
///
/// كانت الشاشة تقول لكل عطبٍ «الغالب أن ملفات المخطّط لم تُطبَّق»، فمن وقع
/// عليه فرقُ ساعةٍ بين جهازه والخادم بحث في مجلّد `supabase/` وهو سليم.
/// والتشخيص الخاطئ أسوأ من الصمت: يُرسل صاحبَه إلى مكانٍ لا شيء فيه.
String identityHint(String? code, [Duration? drift]) => switch (code) {
  // الرمز «صادرٌ في المستقبل»: ساعةُ من أصدره تسبق ساعةَ من يقرؤه. وقد حاول
  // التطبيق وحده مرّتين بينهما ثانيتان قبل أن يصل إلى هنا.
  jwtIssuedAtFuture =>
    'السبب فرقٌ في الساعة بين جهازك والخادم — رمزُ دخولك يبدو «صادراً في '
        'المستقبل».\n\n'
        // الرقم المقيس إن أمكن قياسه: «سبع دقائق» تُفعَل، و«فرقٌ في الساعة»
        // لا تُفعَل.
        '${clockSkewLabel(drift) ?? ''}${clockSkewLabel(drift) == null ? '' : '\n\n'}'
        'افتح إعدادات جوالك ← التاريخ والوقت، وفعّل **الضبط التلقائي** '
        '(الوقت والمنطقة الزمنية من الشبكة)، ثم أعد المحاولة.\n\n'
        'وإن كانت ساعة جوالك مضبوطةً أصلاً فالفرق من الخادم، وهو يمضي وحده '
        'خلال دقيقة — أعد المحاولة بعدها.',
  // جدولٌ أو طريقةٌ غير موجودة.
  '42P01' || 'PGRST205' =>
    'الغالب أن ملفات المخطّط في مجلّد supabase/ لم تُطبَّق على المشروع بعد — '
        'المصادقة تعمل بلا جداولنا، فالدخول ينجح وحده ثم يقف كل شيء.',
  // عمودٌ غير موجود: مخطّطٌ أقدمُ من التطبيق.
  '42703' =>
    'قاعدتك أقدمُ من هذه النسخة من التطبيق: عمودٌ يطلبه غيرُ موجود. شغّل '
        'ملفات supabase/ الأحدث ثم أعد المحاولة.',
  // صلاحية.
  '42501' || 'PGRST301' =>
    'القاعدة رفضت القراءة لسياسة صلاحيات. تأكّد من تطبيق policies.sql على '
        'المشروع.',
  _ =>
    'إن كنت لم تُطبّق ملفات مجلّد supabase/ على المشروع بعد فابدأ بها — '
        'المصادقة تعمل بلا جداولنا، فالدخول ينجح وحده ثم يقف كل شيء.',
};
