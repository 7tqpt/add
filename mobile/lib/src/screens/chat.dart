import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

/// خيط المحادثة.
///
/// **ولماذا تُفتح المحادثة أصلاً:** بين «كم السعر؟» و«حجزتُ» عشرةُ أسئلة لا
/// يحملها نموذجُ حجز — أيوجد موقف؟ وهل الإضاءة تكفي التصوير؟ وهل تُقبل زيادةُ
/// خمسين ضيفاً؟ ومن لا يجد أين يسأل يذهب إلى واتساب، فيخرج الحجز من المنصّة
/// كلّه ومعه سجلُّه: فإذا وقع نزاعٌ لم يبقَ للإدارة ما تنظر فيه.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherName,
    required this.mySide,
  });

  final String conversationId;

  /// اسم الطرف الآخر — تحسبه القاعدة لأن لكلٍّ «آخرَ» غير آخر صاحبه.
  final String otherName;
  final ChatSide mySide;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<List<ChatMessage>>? _live;

  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    // البثّ إن وُجد، والقراءة الواحدة إن لم يوجد: وضعُ العرض بلا خادم، وبعض
    // القواعد لم يُضَف إليها الجدول إلى نشرة البثّ. وفي الحالين تظهر الرسائل.
    final stream = Api.conversationStream(widget.conversationId);
    if (stream != null) {
      _live = stream.listen(
        (rows) {
          if (!mounted) return;
          setState(() {
            _messages = rows;
            _loading = false;
            _error = null;
          });
          _toBottom();
          _markRead();
        },
        onError: (Object e) {
          if (mounted) {
            setState(() {
              _error = messageOf(e);
              _loading = false;
            });
          }
        },
      );
      return;
    }

    try {
      final rows = await Api.conversationMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _loading = false;
      });
      _toBottom();
      _markRead();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageOf(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _markRead() async {
    try {
      await Api.markConversationRead(widget.conversationId);
    } catch (_) {
      // شارةُ «جديد» زينةٌ لا شرط: فشلُ تعليمها مقروءةً لا يمنع القراءة نفسها.
    }
  }

  void _toBottom() {
    // بعد الإطار لا فيه: الشريط لم يُقَس بعدُ أثناء البناء، فالقفز إليه الآن
    // يقع إلى حدٍّ قديم ويقف قبل آخر رسالة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await Api.sendChatMessage(
        conversationId: widget.conversationId,
        sender: widget.mySide,
        body: body,
      );
      _input.clear();
      // بلا بثٍّ لا يعود شيءٌ من الخادم: تُقرأ الرسائل ثانيةً كي تظهر ما
      // أُرسل. ومع البثّ يصل الصفُّ وحده فلا حاجة.
      if (_live == null) {
        final rows = await Api.conversationMessages(widget.conversationId);
        if (mounted) setState(() => _messages = rows);
      }
      _toBottom();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(child: _body()),
          _Composer(controller: _input, busy: _sending, onSend: _send),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingBlock();
    if (_error != null) return ErrorBlock(message: _error!, onRetry: _open);
    if (_messages.isEmpty) {
      return const EmptyBlock(
        title: 'ابدأ الحديث',
        description: 'اسأل عن الموعد والسعر وما تشمله الخدمة قبل أن تحجز.',
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(Space.lg),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        // اليومُ يُكتب مرّةً فوق أوّل رسالةٍ منه: تكرارُه فوق كل رسالة ضجيج،
        // وغيابُه يجعل رسالةَ الأمس ورسالةَ اليوم شيئاً واحداً.
        final previous = i == 0 ? null : _messages[i - 1];
        final newDay = previous == null || !_sameDay(previous.createdAt, m.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay) _DayMark(m.createdAt),
            _Bubble(message: m, mine: m.sender == widget.mySide),
          ],
        );
      },
    );
  }

  static bool _sameDay(String a, String b) =>
      a.length >= 10 && b.length >= 10 && a.substring(0, 10) == b.substring(0, 10);
}

class _DayMark extends StatelessWidget {
  const _DayMark(this.iso);
  final String iso;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.md),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          formatDate(iso),
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ),
    ),
  );
}

/// شفافية ختم الوقت على فقاعتي أنا. ثابتٌ لأن الاختبار يقيسه.
const double chatStampAlpha = 0.85;

/// فقاعةُ رسالة.
///
/// وجهتان لا لونان فقط: من لا يفرّق الألوان يعرف صاحب الرسالة من موضعها —
/// كلامي إلى اليسار وكلامه إلى اليمين — والزاويةُ المسطّحة عند الطرف علامةٌ
/// ثالثة.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 4 : 16),
      bottomRight: Radius.circular(mine ? 16 : 4),
    );
    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.sm),
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        constraints: BoxConstraints(
          // ثلاثةُ أرباع العرض: فقاعةٌ بعرض الشاشة كاملاً تُلغي الفرق بين
          // الطرفين، فيصير الخيطُ صفحةَ نصٍّ لا حواراً.
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.accent : AppColors.surface,
          borderRadius: radius,
          border: mine ? null : Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: mine ? AppColors.accentInk : AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatTimeOf(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                // ‎٠٫٨٥‎ لا ‎٠٫٧٥‎: الثانية تعطي ‎٤٫٤٨:١‎ على أزرق العلامة —
                // تحت العتبة بقليل، وهو القدر الذي «يبدو واضحاً» على شاشةِ من
                // يكتب ويختفي في شمسِ من يستعمل. وقياسٌ لا ذوق.
                color: mine
                    ? AppColors.accentInk.withValues(alpha: chatStampAlpha)
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.busy, required this.onSend});
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                // يكبر بالنصّ إلى خمسة أسطر ثم يقف: حقلٌ بسطرٍ واحد يُخفي
                // أوّلَ كلامٍ طويل، وحقلٌ بلا حدٍّ يبتلع الشاشة.
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            IconButton.filled(
              onPressed: busy ? null : onSend,
              tooltip: 'أرسل',
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
