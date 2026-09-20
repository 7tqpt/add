import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/motion.dart';
import '../ui/kit.dart';
import 'chat.dart';

/// قائمة المحادثات — للعميل ولمقدّم الخدمة معاً.
///
/// شاشةٌ واحدة للطرفين لا شاشتان: الفرق بينهما سطرٌ واحد — من هو «الطرف
/// الآخر» — وتحسبه القاعدة في `v_my_conversations`. وشاشتان متطابقتان تفترقان
/// بمرور الوقت، فيُصلَح عيبٌ في إحداهما ويبقى في الأخرى.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key, this.embedded = false});

  /// أهي تبويبٌ داخل قشرةٍ، أم شاشةٌ تُفتح طريقاً؟
  ///
  /// **وتبويباً يسقط شريطُها العلويّ**: القشرةُ ترسم رأسَها الزجاجيَّ فوقها،
  /// فلو بقي شريطُها لَاجتمع رأسان أحدُهما تحت الآخر.
  ///
  /// **وتأخذ مسافةَ الرأس والشريط السفليّ**: المحتوى يمرّ تحتهما معاً، فبلا
  /// المسافتين اختفى أوّلُ صفٍّ تحت الرأس وآخرُه خلفَ الزجاج.
  final bool embedded;

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
          // يُمرَّران ليُرسم الرأسُ كاملاً من أوّل إطار — ثمّ يُسألان من
          // القاعة على كلّ حال (`_loadHeader`).
          otherAvatar: c.otherAvatar,
          providerId: c.providerId,
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
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: widget.embedded ? null : AppBar(title: Text(tr('المحادثات'))),
      body: FutureBuilder<List<Conversation>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonList(rows: 4, thumb: true);
          }
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final rows = snap.data ?? const <Conversation>[];
          if (rows.isEmpty) {
            return EmptyBlock(
              title: tr('لا محادثات بعد'),
              description: tr('افتح خدمةً واضغط «راسل مقدّم الخدمة» لتسأل قبل أن تحجز.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppColors.accent,
            child: ListView.separated(
              padding: widget.embedded
                  // تبويباً: تحت الرأس الزجاجيّ وفوق الشريط السفليّ.
                  ? EdgeInsets.fromLTRB(0, glassHeaderTop(context), 0, glassNavSpace)
                  : const EdgeInsets.symmetric(vertical: Space.sm),
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.hairline, indent: 72),
              itemBuilder: (context, i) => FadeSlideIn(
                index: i,
                child: _Row(conversation: rows[i], onTap: () => _open(rows[i])),
              ),
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
      leading: _Avatar(name: c.otherName, path: c.otherAvatar),
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
            style: TextStyle(fontSize: 10.5, color: unread ? AppColors.accent : AppColors.muted),
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
                    ? trf('أنت: {0}', [c.lastMessageBody])
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
            if (unread) ...[const SizedBox(width: Space.sm), UnreadDot(count: c.unreadCount)],
          ],
        ),
      ),
    );
  }
}

/// قرصُ الطرف الآخر في القائمة — صورتُه، أو حرفُ اسمه.
///
/// **والصورةُ تصل الجانبين بعد `conversation_avatars.sql`.** كانت تصل العميلَ
/// وحدَه (شعارَ القاعة)، وكان مقدّمُ الخدمة يرى حروفاً أبداً لأنّ سياسةَ
/// `app_users` تمنعه من قراءة صفّ العميل. فرآها صاحبُ المنصّة وقال: «اجلب لي
/// صورة من ملف العميل، خلّه تظهر في المحادثة بدل الحروف».
///
/// **والحرفُ يبقى ولا يُحذف:** أكثرُ الحسابات بلا صورة، وهو ما يُرى غالباً.
/// وأوّلُ حرفٍ من الاسم بدل أيقونةٍ واحدة للجميع: الصفُّ يُمسح بالعين، وعشرةُ
/// صفوفٍ بالأيقونة نفسها تُقرأ كتلةً.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.path});

  final String name;
  final String path;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final url = Api.avatarUrl(path);
    final trimmed = name.trim();
    final letter = Text(
      trimmed.isEmpty ? tr('؟') : trimmed.characters.first,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.accent,
        fontFamilyFallback: arabicFallback,
      ),
    );

    return Container(
      key: const ValueKey('convo-avatar'),
      width: _size,
      height: _size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: url == null
          ? letter
          // **وصورةٌ تسقط تعود حرفاً لا مربّعاً مكسوراً** — الشبكةُ هنا
          // تُسقط الطلبَ كثيراً، والقائمةُ تبقى مقروءة.
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: _size,
              height: _size,
              errorBuilder: (_, _, _) => letter,
            ),
    );
  }
}
