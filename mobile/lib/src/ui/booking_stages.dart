import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';

/// مراحلُ الحجز — سكّةٌ رأسيّةٌ تقول أين وصل الطلبُ وما التالي.
///
/// **وعلّتُها أنّ العميل كان يحجز ثمّ لا يدري ماذا ينتظر.** كانت البطاقةُ
/// تحمل شارةَ حالةٍ واحدةً — «بانتظار مقدّم الخدمة» — وهي تقول أين هو ولا
/// تقول ما قبلَه ولا ما بعدَه، ولا كم بقي. فصارت ثلاثَ مراحلَ ظاهرة:
///
///   ١) تفاصيل الطلب      — ما أرسله بيده، ومنقضيةٌ دائماً.
///   ٢) موافقة مقدّم الخدمة — وهي وحدَها التي تنتظر أحداً غيرَه.
///   ٣) دفع العربون        — وبها يثبت الحجز.
///
/// **والفعلُ في موضعه لا تحت البطاقة.** زرُّ الدفع يقع في صفّ مرحلته، تحت
/// السطر الذي يقول لماذا يُدفع — فيُقرأ السببُ والفعلُ في نظرةٍ واحدة.

/// علامةُ المرحلة.
///
/// و`stopped` ليست `todo`: الأولى تقول «وقف هنا ولن يمضي»، والثانية «لم
/// يبلغها بعد». وخلطُهما يجعل حجزاً اعتُذر عنه يبدو كأنّه ما زال يسير.
enum StageMark { done, current, todo, stopped }

typedef BookingStage = ({String title, String note, StageMark mark});

/// المراحلُ كما تُقرأ من الحجز — دالّةٌ محضةٌ تُقاس وحدَها.
///
/// **ولا عمودَ جديدٌ في القاعدة:** الحالةُ والمدفوعُ والعربونُ في `bookings`
/// أصلاً، وهي تكفي لتحديد المرحلة.
List<BookingStage> bookingStages(Booking b) {
  final details = (
    title: tr('تفاصيل الطلب'),
    note: tr('أرسلتَ التاريخ والضيوف والعنوان'),
    mark: StageMark.done,
  );

  // **والنهاياتُ تقطع السكّةَ ولا تُخمَّن.**
  //
  // من أُلغي حجزُه أو انقضت مهلتُه لا نعلم من الحالة وحدَها أكان المزوّد
  // قد وافق قبلها أم لا — فرسمُ «موافقة» منقضيةً أو منتظرةً تخمينٌ يكذب في
  // نصف الحالات. فيُكتفى بصفٍّ واحدٍ يقول ما وقع، وتُحذف بقيّةُ المراحل:
  // لا معنى لعرض ما لن يقع.
  BookingStage stop(String title, String note) =>
      (title: title, note: note, mark: StageMark.stopped);

  switch (b.status) {
    case BookingStatus.rejected:
      return [
        details,
        stop(tr('اعتذر مقدّم الخدمة'), tr('ما دفعتَه يُعاد إليك كاملاً')),
      ];
    case BookingStatus.cancelled:
      return [details, stop(tr('أُلغي الحجز'), tr('حسب سياسة الإلغاء وقُرب الموعد'))];
    case BookingStatus.expired:
      return [details, stop(tr('انقضت مهلة الردّ'), tr('لم يردّ مقدّم الخدمة في وقته'))];
    case BookingStatus.pendingProvider:
      return [
        details,
        (
          title: tr('موافقة مقدّم الخدمة'),
          note: tr('ينظر في طلبك، ويصلك إشعارٌ بردّه'),
          mark: StageMark.current,
        ),
        (
          title: tr('دفع العربون'),
          note: tr('يُفتح بعد الموافقة'),
          mark: StageMark.todo,
        ),
      ];
    case BookingStatus.confirmed:
    case BookingStatus.completed:
      final paid = b.paidAmount >= b.depositAmount;
      return [
        details,
        (
          title: tr('موافقة مقدّم الخدمة'),
          note: tr('وافق على حجزك'),
          mark: StageMark.done,
        ),
        (
          title: tr('دفع العربون'),
          note: paid ? tr('وصل العربون وثبت الحجز') : tr('الحجز يثبت بوصول العربون'),
          mark: paid ? StageMark.done : StageMark.current,
        ),
      ];
  }
}

/// نصُّ زرِّ الدفع في المرحلة الجارية — أو `null` فلا زرّ.
///
/// **والدفعُ بعد الموافقة لا قبلها.** كان الزرّ يظهر والحجزُ ما زال منتظراً،
/// فمن دفع ثمّ اعتُذر عنه صار له مالٌ يُستردّ — احتكاكٌ لا داعي له، وهو ما
/// اختاره صاحبُ المنصّة حين رتّب المراحل.
String? bookingPayLabel(Booking b) {
  if (b.status != BookingStatus.confirmed) return null;
  if (b.paidAmount >= b.totalPrice) return null;
  return b.paidAmount < b.depositAmount
      ? trf('ادفع العربون {0}', [formatMoney(b.depositAmount - b.paidAmount)])
      : trf('أكمل المبلغ {0}', [formatMoney(b.totalPrice - b.paidAmount)]);
}

class BookingStages extends StatelessWidget {
  const BookingStages({super.key, required this.stages, this.action, this.onAction});

  final List<BookingStage> stages;

  /// نصُّ الزرّ الذي يُرسم داخل المرحلة الجارية — أو `null` فلا زرّ.
  final String? action;
  final VoidCallback? onAction;

  static Color _colour(StageMark m) => switch (m) {
    StageMark.done => AppColors.good,
    StageMark.current => AppColors.accent,
    StageMark.todo => AppColors.hairline,
    StageMark.stopped => AppColors.critical,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stages.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // السكّة: قرصٌ وخيطٌ إلى الذي بعده.
                Column(
                  children: [
                    _Disc(mark: stages[i].mark),
                    if (i < stages.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          // الخيطُ يأخذ لونَ ما قبلَه: ما قُطع ملوَّن، وما
                          // لم يُقطع رمادي.
                          color: stages[i].mark == StageMark.done
                              ? AppColors.good
                              : AppColors.hairline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < stages.length - 1 ? Space.lg : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stages[i].title,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: stages[i].mark == StageMark.current
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: switch (stages[i].mark) {
                              StageMark.todo => AppColors.muted,
                              StageMark.stopped => AppColors.critical,
                              _ => AppColors.ink,
                            },
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stages[i].note,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.muted,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                        if (stages[i].mark == StageMark.current &&
                            action != null) ...[
                          const SizedBox(height: Space.sm),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FilledButton.icon(
                              onPressed: onAction,
                              icon: const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 19,
                              ),
                              label: Text(action!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// قرصُ المرحلة — صحٌّ لما مضى، ونقطةٌ لما يجري، وفراغٌ لما لم يأتِ.
///
/// **والشكلُ يفرّق كما يفرّق اللون:** من لا يميّز الأخضرَ من النبيذيّ يقرأ
/// الصحَّ من النقطة، والصليبَ من كليهما.
class _Disc extends StatelessWidget {
  const _Disc({required this.mark});
  final StageMark mark;

  @override
  Widget build(BuildContext context) {
    final colour = BookingStages._colour(mark);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: mark == StageMark.todo ? AppColors.surface2 : colour,
        border: Border.all(color: colour, width: 2),
      ),
      alignment: Alignment.center,
      child: switch (mark) {
        StageMark.done =>
          const Icon(Icons.check_rounded, size: 13, color: Colors.white),
        StageMark.stopped =>
          const Icon(Icons.close_rounded, size: 13, color: Colors.white),
        StageMark.current => Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
        StageMark.todo => const SizedBox.shrink(),
      },
    );
  }
}
