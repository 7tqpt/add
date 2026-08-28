import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../core/voice.dart';
import '../ui/kit.dart';
import '../ui/media.dart';
import '../ui/viewer.dart';
import 'chat_attach.dart';

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
    this.recorder,
    this.picker,
  });

  /// المُسجِّل — يُبدَّل بمزيّفٍ في الاختبار.
  ///
  /// **ولولا هذا لبقي أهمُّ ما في الشاشة بلا حارس:** الميكروفون لا يوجد في
  /// الاختبار، فشاشةٌ تنادي الجهاز رأساً لا يُقاس فيها ما يقع حين يُرفض
  /// الإذن ولا حين يفشل الرفع.
  final VoiceRecorder? recorder;

  /// منتقي المرفقات — يُبدَّل كذلك.
  final AttachmentPicker? picker;

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

  late final VoiceRecorder _recorder = widget.recorder ?? DeviceVoiceRecorder();
  late final AttachmentPicker _picker = widget.picker ?? const DeviceAttachmentPicker();

  /// جارٍ التسجيل — والثواني تُعرض للمستخدم.
  bool _recording = false;

  /// بين ضغطة الميكروفون وبدء التسجيل: الإذن يُطلب والمنصّة تُهيّئ.
  bool _starting = false;

  int _recorded = 0;
  Timer? _tick;
  StreamSubscription<Object>? _failure;

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
    _tick?.cancel();
    _failure?.cancel();
    _recorder.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// يرفع مرفقاً ويُرسله، ويقول ما وقع إن فشل.
  Future<void> _sendAttachment(PickedAttachment picked) async {
    setState(() => _sending = true);
    try {
      await Api.sendChatAttachment(
        conversationId: widget.conversationId,
        sender: widget.mySide,
        kind: picked.kind,
        bytes: picked.bytes,
        extension: picked.extension,
        contentType: picked.contentType,
        seconds: picked.seconds,
        name: picked.name,
      );
      // بلا بثٍّ لا يعود شيءٌ من الخادم — كما في إرسال النصّ.
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

  Future<void> _pick(Future<PickedAttachment?> Function() choose) async {
    try {
      final picked = await choose();
      if (picked == null || !mounted) return;
      await _sendAttachment(picked);
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    }
  }

  /// قائمةُ المرفقات — ورقةٌ سفلية بأربعة أبواب.
  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, icon, label) in const [
              ('gallery', Icons.photo_library_outlined, 'صورة من المعرض'),
              ('camera', Icons.photo_camera_outlined, 'التقاط صورة'),
              ('video', Icons.videocam_outlined, 'تصوير مقطع'),
              ('file', Icons.attach_file, 'ملف PDF'),
            ])
              ListTile(
                leading: Icon(icon, color: AppColors.accent),
                title: Text(label),
                onTap: () => Navigator.of(sheet).pop(value),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    switch (choice) {
      case 'gallery':
        await _pick(() => _picker.image(camera: false));
      case 'camera':
        await _pick(() => _picker.image(camera: true));
      case 'video':
        await _pick(_picker.video);
      case 'file':
        await _pick(_picker.document);
    }
  }

  /// يبدأ التسجيل — بعد الإذن.
  ///
  /// **والإذنُ يُسأل عنه ويُقال حين يُرفض:** زرٌّ يُضغط فلا يقع شيءٌ ولا تظهر
  /// رسالة يجعل المستخدم يظنّ التطبيق مكسوراً، وهو ممنوعٌ بإذنٍ يملك هو
  /// منحه.
  Future<void> _startRecording() async {
    // **ولا نداءان معاً.** طلبُ الإذن في أندرويد يحفظ ردَّ نداءٍ **واحد**،
    // فنداءٌ ثانٍ قبل أن يُجاب الأوّل يمحوه — ويبقى الأوّل معلّقاً إلى الأبد.
    // ونقرتان سريعتان على الميكروفون تكفيان لذلك.
    if (_starting || _recording) return;
    setState(() => _starting = true);

    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          showMessage(context, 'لم يُسمح للتطبيق بالميكروفون. افتح إعدادات التطبيق واسمح به.');
        }
        return;
      }
      await _recorder.start();
    } catch (e) {
      // **ولا تُدخَل حالةُ التسجيل إن لم يبدأ.** كانت `start` بلا حارس، فإن
      // رمت خرج الاستدعاء صامتاً: لا رسالة، ولا عدّاد، وزرٌّ يُضغط فلا يقع
      // شيء — وهو ما يُقرأ «التطبيق يعلّق».
      if (mounted) showMessage(context, messageOf(e));
      return;
    } finally {
      if (mounted) setState(() => _starting = false);
    }

    if (!mounted) return;
    setState(() {
      _recording = true;
      _recorded = 0;
    });

    // عطبٌ يقع **بعد** البدء لا يصل من `start` — فهي عادت بنجاح. وبلا هذا
    // يبقى العدّاد يعدّ على مُسجِّلٍ ميّت ولا مخرج من الشريط.
    _failure = _recorder.failures.listen((e) {
      if (!mounted || !_recording) return;
      _tick?.cancel();
      setState(() => _recording = false);
      showMessage(context, messageOf(e));
    });

    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recorded = timer.tick);
      // **إيقافٌ تلقائيٌّ عند الحدّ لا رفضٌ بعده:** من تكلّم ثلاث دقائق ثم
      // قيل له «طويل» فقد كلامَه كلَّه.
      if (timer.tick >= voiceMaxSeconds) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _tick?.cancel();
    if (!_recording) return;
    // الخروجُ من حالة التسجيل **قبل** انتظار المنصّة: لو انتظرنا ردَّها ثم
    // خرجنا لبقي الشريط معلّقاً طوال الانتظار بزرٍّ لا يستجيب.
    setState(() => _recording = false);
    _dropFailureWatch();
    try {
      final clip = await _recorder.stop();
      if (clip == null) {
        if (mounted) showMessage(context, 'التسجيل قصيرٌ جداً.');
        return;
      }
      await _sendAttachment(PickedAttachment(
        kind: ChatAttachment.audio,
        bytes: clip.bytes,
        extension: 'm4a',
        contentType: 'audio/mp4',
        seconds: clip.seconds,
      ));
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    }
  }

  Future<void> _cancelRecording() async {
    _tick?.cancel();
    if (!_recording) return;
    setState(() => _recording = false);
    _dropFailureWatch();
    await _recorder.cancel();
  }

  /// يفكّ الإنصات — **بلا `await`، وهذا مقصودٌ لا إهمال.**
  ///
  /// `cancel()` على اشتراكِ مجرًى إذاعيّ يُعيد `Future` لا تكتمل في المنطقة
  /// المزيّفة للاختبار، ولا تكتمل إلّا بعد دورة حدثٍ على الجهاز. فانتظارُها
  /// هنا كان يحبس «أوقف» و«ألغِ» قبل أن تصلا المُسجِّل أصلاً — أي **التجمّدُ
  /// نفسه الذي جئتُ أُصلحه، أعدتُ إدخاله داخل إصلاحه**. كشفه اختبارٌ سقط، لا
  /// قراءة.
  ///
  /// وفكُّ الاشتراك يقع فور النداء؛ إنما الـ`Future` إقرارٌ متأخّر لا شرط.
  void _dropFailureWatch() {
    final sub = _failure;
    _failure = null;
    unawaited(sub?.cancel() ?? Future<void>.value());
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
          _Composer(
            controller: _input,
            // والميكروفونُ يُطفأ وهو يُهيَّأ: ضغطةٌ ثانية عليه تمحو ردَّ
            // نداء الإذن الأوّل فيبقى معلّقاً.
            busy: _sending || _starting,
            onSend: _send,
            onAttach: _attach,
            onRecord: _startRecording,
            onStop: _stopRecording,
            onCancelRecording: _cancelRecording,
            recording: _recording,
            recorded: _recorded,
          ),
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
          // وصورةٌ في فقاعةٍ ضيّقةٍ لا تُرى: تُعطى أرضيّةً بحدٍّ أدنى.
          minWidth: message.attachment == ChatAttachment.image ? 180 : 0,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.accent : AppColors.surface,
          borderRadius: radius,
          border: mine ? null : Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasAttachment) ...[
              _Attachment(message: message, mine: mine),
              const SizedBox(height: Space.xs),
            ],
            // نصُّ رسالةٍ مرفَقة فارغ، فلا يُرسم سطرٌ خالٍ يزيد ارتفاع
            // الفقاعة بلا شيء فيه.
            if (message.body.isNotEmpty)
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
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onAttach,
    required this.onRecord,
    required this.onStop,
    required this.onCancelRecording,
    required this.recording,
    required this.recorded,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onCancelRecording;
  final bool recording;
  final int recorded;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, Space.sm),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        // أثناء التسجيل يختفي الحقلُ كلُّه ويحلّ محلّه شريطُ التسجيل: حقلُ
        // كتابةٍ ظاهرٌ والميكروفون يعمل يدعو إلى الكتابة أثناء الكلام، ثم
        // تضيع إحداهما.
        child: recording
            ? _RecordingBar(
                seconds: recorded,
                onStop: onStop,
                onCancel: onCancelRecording,
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: busy ? null : onAttach,
                    tooltip: 'أرفق',
                    icon: const Icon(Icons.add_circle_outline, size: 24),
                    color: AppColors.accent,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      // يكبر بالنصّ إلى خمسة أسطر ثم يقف: حقلٌ بسطرٍ واحد
                      // يُخفي أوّلَ كلامٍ طويل، وحقلٌ بلا حدٍّ يبتلع الشاشة.
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
                  const SizedBox(width: Space.xs),
                  // ميكروفونٌ إلى جانب الإرسال لا بدلاً منه: تبديلُ الزرّ
                  // بحسب امتلاء الحقل — كما تفعل تطبيقاتٌ أخرى — يجعل الزرّ
                  // يتحرّك تحت الإبهام فيُضغط غيرُ المقصود.
                  IconButton(
                    onPressed: busy ? null : onRecord,
                    tooltip: 'سجّل رسالة صوتية',
                    icon: const Icon(Icons.mic_none_rounded, size: 24),
                    color: AppColors.accent,
                  ),
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

/// شريطُ التسجيل — نقطةٌ حمراء وعدّادٌ ومخرجان.
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.seconds,
    required this.onStop,
    required this.onCancel,
  });

  final int seconds;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // **إلغاءٌ قبل الإرسال:** من ضغط الميكروفون بالخطأ أو تكلّم فأخطأ
        // يحتاج باباً يرمي به ما سجّل — وبلاه يُرسل ما لا يريد أو يُغلق
        // الشاشة فيضيع.
        IconButton(
          onPressed: onCancel,
          tooltip: 'ألغِ التسجيل',
          icon: const Icon(Icons.delete_outline, size: 22),
          color: AppColors.critical,
        ),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.critical,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            'يسجّل… ${formatClock(Duration(seconds: seconds))}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.ink,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ),
        IconButton.filled(
          onPressed: onStop,
          tooltip: 'أرسل التسجيل',
          icon: const Icon(Icons.send_rounded, size: 20),
        ),
      ],
    );
  }
}

/// المرفقُ داخل الفقاعة — لكلِّ نوعٍ شكلُه.
///
/// **والرابطُ يُوقَّع عند العرض:** السلّة خاصّة، فلا رابط علنيّ لها. ويُطلب
/// التوقيعُ مرّةً لكل فقاعة وتُحفظ نتيجتُه في `_future` — لا في كل إعادة
/// رسمٍ للشاشة، وإلّا صار كلُّ تمريرٍ بالإبهام نداءً على الشبكة.
class _Attachment extends StatefulWidget {
  const _Attachment({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  State<_Attachment> createState() => _AttachmentState();
}

class _AttachmentState extends State<_Attachment> {
  late final Future<String?> _url = Api.chatMediaUrl(widget.message.attachmentPath);

  /// **يُفتح المرفقُ داخل التطبيق لا خارجه.**
  ///
  /// وكان يُسلَّم إلى `launchUrl` بـ`externalApplication`: وأندرويد لا يعرض
  /// PDF بنفسه، فيُنزّله إلى مجلّد التنزيلات ويترك صاحبَه يبحث عنه هناك —
  /// إن كان في جهازه قارئٌ أصلاً، وإلّا فلا شيء.
  void _openAttachment(String url) {
    final m = widget.message;
    switch (m.attachment!) {
      case ChatAttachment.image:
        openImageViewer(context, url: url,
            title: m.attachmentName.isEmpty ? 'صورة' : m.attachmentName);
      case ChatAttachment.video:
        openVideoViewer(context, url: url);
      case ChatAttachment.file:
        openPdfViewer(context, url: url,
            name: m.attachmentName.isEmpty ? 'ملف' : m.attachmentName);
      case ChatAttachment.audio:
        // الصوتُ يُسمع في مكانه؛ لا شاشةَ له.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snap) {
        final url = snap.data;
        final loading = snap.connectionState != ConnectionState.done;

        switch (m.attachment!) {
          case ChatAttachment.image:
            return InkWell(
              key: const ValueKey('chat-image'),
              onTap: url == null ? null : () => _openAttachment(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: loading
                      ? Container(color: AppColors.surface2)
                      : MediaThumb(url: url),
                ),
              ),
            );

          case ChatAttachment.video:
            // **والفقاعةُ معاينةٌ لا مشغّل.** مقطعٌ يُشغَّل في مربّعٍ بعرض
            // ٢٢٠ بكسل بين فقاعات المحادثة لا يُرى منه شيء، والضغطُ عليه
            // يملأ به الشاشة.
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 220,
                child: url == null
                    ? Container(height: 124, color: AppColors.surface2)
                    : VideoBox(
                        key: const ValueKey('chat-video'),
                        url: url,
                        seconds: m.attachmentSeconds,
                        onTap: () => _openAttachment(url),
                      ),
              ),
            );

          case ChatAttachment.audio:
            // **ورابطٌ لم يصل لا يعني فقاعةً فارغة.** التوقيع نداءٌ على
            // الشبكة قد يتأخّر أو يفشل، وصندوقٌ فارغٌ في الخيط لا يقول إن
            // هناك رسالةً أصلاً — فيظنّ المستقبِل أن المرسِل أرسل فراغاً.
            // فتُعرض المدّة دائماً، ويُضاف المشغّل حين يصل الرابط.
            return SizedBox(
              width: 220,
              child: url == null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          loading ? Icons.mic_none_rounded : Icons.mic_off_outlined,
                          size: 20,
                          color: widget.mine ? AppColors.accentInk : AppColors.muted,
                        ),
                        const SizedBox(width: Space.sm),
                        Text(
                          formatClock(Duration(seconds: m.attachmentSeconds)),
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.mine ? AppColors.accentInk : AppColors.ink2,
                          ),
                        ),
                      ],
                    )
                  : AudioBar(url: url, seconds: m.attachmentSeconds),
            );

          case ChatAttachment.file:
            // اسمُ الملفّ وحجمُه ثم يُفتح: «مرفق» وحدها لا تقول أهو العقد أم
            // قائمة الأسعار، ومن يفتح محادثةً بعد شهرٍ يبحث بالاسم.
            return InkWell(
              key: const ValueKey('chat-file'),
              onTap: url == null ? null : () => _openAttachment(url),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 26,
                    color: widget.mine ? AppColors.accentInk : AppColors.critical,
                  ),
                  const SizedBox(width: Space.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.attachmentName.isEmpty ? 'ملف' : m.attachmentName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.mine ? AppColors.accentInk : AppColors.ink,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                        if (m.attachmentSize > 0)
                          Text(
                            formatBytes(m.attachmentSize),
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.mine
                                  ? AppColors.accentInk.withValues(alpha: chatStampAlpha)
                                  : AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
        }
      },
    );
  }
}

