import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'chat.dart';

/// قائمة المحادثات — للعميل ولمقدّم الخدمة معاً.
///
/// شاشةٌ واحدة للطرفين لا شاشتان: الفرق بينهما سطرٌ واحد — من هو «الطرف
/// الآخر» — وتحسبه القاعدة في `v_my_conversations`. وشاشتان متطابقتان تفترقان
/// بمرور الوقت، فيُصلَح عيبٌ في إحداهما ويبقى في الأخرى.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<Conversation>> _future = Api.myConversations();

  // كتلةٌ لا سهم: `setState(() => _future = …)` تُعيد قيمة الإسناد — وهي
  // `Future` — فيرمي الإطار «setState() callback argument returned a Future».
  // وهو تأكيدٌ في وضع التنقيح وحده، فيمرّ في الإصدار ويسقط عند المطوّر.
  void _reload() {
    setState(() {
      _future = Api.myConversations();
    });
  }

  Future<void> _open(Conversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: c.id,
          otherName: c.otherName,
          mySide: c.mySide,
        ),
      ),
    );
    // عند العودة: ما كان جديداً صار مقروءاً، فالعدّاد لا بدّ أن يصفر في
    // القائمة أيضاً.
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات')),
      body: FutureBuilder<List<Conversation>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final rows = snap.data ?? const <Conversation>[];
          if (rows.isEmpty) {
            return const EmptyBlock(
              title: 'لا محادثات بعد',
              description: 'افتح خدمةً واضغط «راسل مقدّم الخدمة» لتسأل قبل أن تحجز.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.accent,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.hairline, indent: 72),
              itemBuilder: (context, i) => _Row(conversation: rows[i], onTap: () => _open(rows[i])),
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.conversation, required this.onTap});
  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadCount > 0;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.accent.withValues(alpha: 0.10),
        child: Text(
          // أوّلُ حرفٍ من الاسم بدل أيقونةٍ واحدة للجميع: الصفُّ يُمسح بالعين،
          // وعشرةُ صفوفٍ بالأيقونة نفسها تُقرأ كتلةً.
          c.otherName.isEmpty ? '؟' : c.otherName.characters.first,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            fontFamilyFallback: arabicFallback,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              c.otherName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            formatRelative(c.lastMessageAt),
            style: TextStyle(
              fontSize: 10.5,
              color: unread ? AppColors.accent : AppColors.muted,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // «أنت: …» أمام كلامي: بلا هذه الكلمة يبدو آخرُ ما قلتُه أنا
                // وكأنه ردٌّ منه، فأنتظر جواباً وصل ولم يصل.
                c.lastMessageSender == c.mySide
                    ? 'أنت: ${c.lastMessageBody}'
                    : c.lastMessageBody,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: unread ? AppColors.ink2 : AppColors.muted,
                  fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (unread) ...[
              const SizedBox(width: Space.sm),
              UnreadDot(count: c.unreadCount),
            ],
          ],
        ),
      ),
    );
  }
}
