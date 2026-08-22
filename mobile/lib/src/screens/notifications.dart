import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

/// صندوق الإشعارات.
///
/// **وقد كان يُكتب ولا يُقرأ:** سبعةُ مواضع في `api.sql` تكتب في جدول
/// `notifications` منذ اليوم الأول — طلبُ حجزٍ جديد، وتأكيدُه، والاعتذار عنه،
/// وإلغاؤه، وتأكيدُ الدفعة، وطلبُ التقييم، ووصولُه — ولم يكن للصندوق باب.
/// فصاحبُ القاعة الذي وصله طلبُ حجزٍ لا يعلم حتى يفتح شاشة الطلبات من تلقاء
/// نفسه.
///
/// وكلُّ إشعارٍ يُفتح على شيء: `data` تحمل `booking_id` أو `conversation_id`،
/// وإشعارٌ لا يُفتح على شيءٍ خبرٌ لا فعل.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onOpen});

  /// ما يفعله الضغط على إشعار. تُمرَّر من القشرة لأنها مالكةُ التبويبات:
  /// «قُبل حجزك» يُفتح على تبويب الحجوزات، ولا سبيل إلى تبويبٍ من شاشةٍ
  /// مدفوعةٍ فوقه.
  final void Function(BuildContext context, AppNotification notification) onOpen;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future = Api.myNotifications();
  bool _busy = false;

  // كتلةٌ لا سهم: قيمة الإسناد `Future`، ويرفض `setState` أن تُعيد closure
  // شيئاً من هذا النوع.
  void _reload() {
    setState(() {
      _future = Api.myNotifications();
    });
  }

  Future<void> _open(AppNotification n) async {
    // التعليم أولاً ثم الفتح: لو فُتحت الشاشة أولاً لعاد المستخدم فوجد
    // الإشعار ما زال جديداً، فظنّ أن شيئاً آخر وصل.
    if (n.isUnread) {
      try {
        await Api.markNotificationRead(n.id);
      } catch (_) {
        // التعليم زينةٌ لا شرط: فشلُه لا يمنع فتح ما يشير إليه.
      }
    }
    if (!mounted) return;
    _reload();
    widget.onOpen(context, n);
  }

  Future<void> _markAll() async {
    setState(() => _busy = true);
    try {
      await Api.markAllNotificationsRead();
      if (mounted) _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final rows = snap.data ?? const <AppNotification>[];
          if (rows.isEmpty) {
            return const EmptyBlock(
              title: 'لا إشعارات',
              description: 'هنا يصلك ما يخصّ حجوزاتك ومدفوعاتك ورسائلك.',
            );
          }
          final unread = rows.where((n) => n.isUnread).length;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.accent,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: Space.lg),
              itemCount: rows.length + 1,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.hairline, indent: 68),
              itemBuilder: (context, i) {
                if (i == 0) {
                  // الزرّ يغيب حين لا شيء يُعلَّم: زرٌّ لا أثر لضغطه يجعل
                  // المستخدم يظنّ أن شيئاً تعطّل.
                  if (unread == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.xs),
                    child: Row(
                      children: [
                        Expanded(child: Muted('$unread جديد')),
                        TextButton(
                          onPressed: _busy ? null : _markAll,
                          child: const Text('علّم الكلّ مقروءاً'),
                        ),
                      ],
                    ),
                  );
                }
                return _Row(notification: rows[i - 1], onTap: () => _open(rows[i - 1]));
              },
            ),
          );
        },
      ),
    );
  }
}

/// أيقونةُ النوع ولونُه.
///
/// اللون علامةٌ ثانية غير الأيقونة، والنصُّ ثالثة: صندوقٌ من عشرين سطراً
/// بأيقونةٍ واحدة يُقرأ كتلةً تُبحث بالقراءة.
({IconData icon, Color tone}) notificationLook(NotificationKind kind) => switch (kind) {
  NotificationKind.booking => (icon: Icons.event_available_rounded, tone: AppColors.accent),
  NotificationKind.payment => (icon: Icons.payments_outlined, tone: AppColors.good),
  NotificationKind.message => (icon: Icons.forum_outlined, tone: Color(0xFF7C3AED)),
  NotificationKind.review => (icon: Icons.star_rounded, tone: AppColors.warning),
  NotificationKind.dispute => (icon: Icons.gavel_rounded, tone: AppColors.critical),
  NotificationKind.account => (icon: Icons.person_outline, tone: AppColors.ink2),
  NotificationKind.reminder => (icon: Icons.alarm, tone: Color(0xFF0E7490)),
  NotificationKind.general => (icon: Icons.notifications_none, tone: AppColors.ink2),
};

class _Row extends StatelessWidget {
  const _Row({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final look = notificationLook(n.kind);
    return ListTile(
      onTap: onTap,
      // الجديد بأرضيةٍ خفيفة: علامةٌ تُمسح بالعين قبل قراءة سطرٍ واحد.
      tileColor: n.isUnread ? AppColors.accent.withValues(alpha: 0.05) : null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: look.tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(look.icon, size: 20, color: look.tone),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              n.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: n.isUnread ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            formatRelative(n.createdAt),
            style: TextStyle(
              fontSize: 10.5,
              color: n.isUnread ? AppColors.accent : AppColors.muted,
            ),
          ),
        ],
      ),
      subtitle: n.body.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                n.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: n.isUnread ? AppColors.ink2 : AppColors.muted,
                ),
              ),
            ),
    );
  }
}
