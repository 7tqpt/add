import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../screens/notifications.dart' show notificationLook;
import 'kit.dart';

/// شريطٌ ينزل من أعلى الشاشة حين يصل إشعارٌ **والتطبيق مفتوح**.
///
/// **ولماذا:** إشعار شريط النظام لا يظهر أصلاً والتطبيق أمام صاحبه. فمن كان
/// يتصفّح الخدمات لحظةَ قَبولِ حجزه لم يكن يعلم — يزيد رقمٌ في جرسٍ لا ينظر
/// إليه أحد، ويبقى ينتظر جواباً وصل قبل دقيقة.
///
/// **ولا يحتاج Firebase ولا إعداداً:** يستمع إلى صفوف `notifications`
/// مباشرةً عبر بثّ Supabase — والجدول في نشرة البثّ منذ `notifications.sql`.
/// فالدفعُ إلى شريط النظام لِما بعد الإغلاق، وهذا لِما قبله.
class AlertBanner extends StatefulWidget {
  const AlertBanner({super.key, required this.child, required this.onOpen, this.source});

  final Widget child;

  /// مصدرُ الإشعارات. يُترك فارغاً فيؤخذ بثُّ القاعدة — ويُمرَّر في الاختبار
  /// وحده. وبلا هذا لا سبيل إلى إثبات ما يقع عند وصول إشعار: البثّ يحتاج
  /// خادماً، ووضعُ العرض لا بثَّ فيه.
  final Stream<List<AppNotification>>? source;

  /// ما يقع عند الضغط على الشريط — الحمولةُ نفسها التي تفتح بها الإشعارات.
  final void Function(Map<String, dynamic> data) onOpen;

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  StreamSubscription<List<AppNotification>>? _sub;
  Timer? _hide;
  AppNotification? _showing;

  /// أحدثُ إشعارٍ رأيناه عند الاشتراك.
  ///
  /// **حارسٌ لا زينة:** أوّل دفعةٍ من البثّ تحمل الصفوف الموجودة أصلاً، فبلا
  /// هذا ينزل الشريط عند كل فتحٍ للتطبيق بإشعارٍ قديمٍ قُرئ من أسبوع.
  String? _seen;
  bool _primed = false;

  @override
  void initState() {
    super.initState();
    final stream = widget.source ?? Api.notificationStream();
    if (stream == null) return;
    _sub = stream.listen(_onRows, onError: (_) {});
  }

  void _onRows(List<AppNotification> rows) {
    if (rows.isEmpty) return;
    final top = rows.first;
    if (!_primed) {
      // الدفعة الأولى تُحفظ ولا تُعرض.
      _primed = true;
      _seen = top.id;
      return;
    }
    if (top.id == _seen) return;
    _seen = top.id;
    // والمقروءُ لا يُعرض: قد يصل الصفّ نفسه بعد تعليمه مقروءاً من شاشةٍ
    // أخرى، وشريطٌ ينزل بخبرٍ قرأه صاحبه للتوّ إزعاجٌ لا خدمة.
    if (!top.isUnread) return;
    _show(top);
  }

  void _show(AppNotification n) {
    setState(() => _showing = n);
    _hide?.cancel();
    // خمسُ ثوانٍ: أقلُّ منها لا يكفي لقراءة سطرين بالعربية، وأكثرُ منها يقف
    // فوق ما يفعله المستخدم.
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showing = null);
    });
  }

  void _dismiss() {
    _hide?.cancel();
    setState(() => _showing = null);
  }

  void _open(AppNotification n) {
    _dismiss();
    widget.onOpen(n.data);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _showing;
    return Stack(
      children: [
        widget.child,
        // فوق كل شيءٍ حتى الشريط الزجاجي: هو خبرٌ عاجل، ولو مرّ تحت شيءٍ
        // لَما رُئي.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: n == null ? const Offset(0, -1.4) : Offset.zero,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: n == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: n == null ? const SizedBox.shrink() : _Card(notification: n, onTap: _open,
                  onDismiss: _dismiss),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.notification, required this.onTap, required this.onDismiss});
  final AppNotification notification;
  final void Function(AppNotification n) onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final look = notificationLook(n.kind);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
        // السحبُ إلى أعلى يُخفيه: أسرعُ من البحث عن زرٍّ صغير، وهو ما تعوّدته
        // الأصابع من إشعارات النظام نفسها.
        child: Dismissible(
          key: ValueKey(n.id),
          direction: DismissDirection.up,
          onDismissed: (_) => onDismiss(),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            elevation: 8,
            shadowColor: AppColors.ink.withValues(alpha: 0.18),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(n),
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: look.tone.withValues(alpha: Tint.disc),
                      ),
                      child: Icon(look.icon, size: 20, color: look.tone),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          if (n.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: AppColors.ink2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Muted(formatRelative(n.createdAt), size: 10.5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
