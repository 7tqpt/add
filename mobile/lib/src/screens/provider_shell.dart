import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/presence.dart';
import '../core/push.dart';
import '../core/session.dart';
import '../data/api.dart';
import '../ui/alert_banner.dart';
import '../ui/kit.dart';
import '../data/models.dart';
import 'chat.dart';
import 'conversations.dart';
import 'notifications.dart';
import 'availability.dart';
import 'requests.dart';
import 'services.dart';
import 'provider_profile.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key, required this.session});
  final Session session;
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;
  int _unread = 0;
  int _alerts = 0;

  @override
  void initState() {
    super.initState();
    _countUnread();
    _countAlerts();
    Push.start(onOpened: (data) => _openFrom(data));
    // ونبضةُ الحضور: هنا آكدُ منها في قشرة العميل — «متّصل الآن» تحت اسم
    // القاعة هي ما يجعل العميل يسأل بدل أن ينصرف.
    Presence.start();
    // **ولا يُطلب إعفاءُ البطّاريّة هنا، ولا في أيّ موضع.**
    //
    // كان يُطلب بعد الدخول فيفتح حوارَ أندرويد: «هل تريد إيقاف تحسين
    // استخدام البطّاريّة؟». وقال صاحبُ المنصّة: «العميل يحسب فيه شيءٌ غلط
    // — ما أريدها تظهر». فشِيل.
    //
    // **وثمنُه أقلُّ ممّا يبدو**: الإشعارُ يُرسَل بكتلة `notification`
    // بأولويّة تسليمٍ عالية (`supabase/functions/push/index.ts`)، فيعرضه
    // نظامُ أندرويد بنفسه ولا ينتظر أن يستيقظ التطبيق.
    //
    // **والطريقُ باقٍ لمن احتاجه**: صفُّ «جهازك يقيّد التطبيق في الخلفيّة»
    // في «الإعدادات» — لا يظهر إلّا لمن جهازُه مقيِّدٌ فعلاً، وضغطتُه تفتح
    // الموضع. فلا شيءَ يُعرض على من لم يسأل.
  }

  @override
  void dispose() {
    Presence.stop();
    super.dispose();
  }

  /// صاحبُ القاعة أحوجُ إلى هذه الحبّة من العميل: العميل يفتح التطبيق ليسأل،
  /// وهذا يفتحه ليعمل — فرسالةٌ بلا علامةٍ ظاهرة تبقى بلا ردٍّ يوماً كاملاً.
  Future<void> _countUnread() async {
    try {
      final rows = await Api.myConversations();
      if (!mounted) return;
      setState(() => _unread = rows.fold<int>(0, (n, c) => n + c.unreadCount));
    } catch (_) {}
  }

  Future<void> _countAlerts() async {
    try {
      final rows = await Api.myNotifications();
      if (!mounted) return;
      setState(() => _alerts = rows.where((n) => n.isUnread).length);
    } catch (_) {}
  }

  Future<void> _openAlerts() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NotificationsScreen(onOpen: _followUp)));
    if (!mounted) return;
    _countAlerts();
    _countUnread();
  }

  /// «وصلك طلب حجز جديد» يُفتح على تبويب الطلبات — وهو أوّل تبويباته.
  ///
  /// وطريقٌ واحد للصندوق ولشريط النظام: الحمولة واحدة، ولو كُتب لكلٍّ مسارٌ
  /// لافترقا عند أوّل نوعٍ يُضاف.
  Future<void> _openFrom(Map<String, dynamic> data, {BuildContext? popFrom}) async {
    final conversationId = data['conversation_id'] as String?;
    if (conversationId != null) {
      try {
        final rows = await Api.myConversations();
        final convo = rows.where((c) => c.id == conversationId).firstOrNull;
        if (convo == null || !mounted) return;
        await Navigator.of(popFrom ?? context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convo.id,
              otherName: convo.otherName,
              // يُمرَّران ليُرسم الرأسُ كاملاً من أوّل إطار — ثمّ يُسألان
              // من القاعة على كلّ حال (`_loadHeader`).
              otherAvatar: convo.otherAvatar,
              providerId: convo.providerId,
              mySide: convo.mySide,
            ),
          ),
        );
      } catch (_) {}
      return;
    }
    if (data['booking_id'] != null) {
      if (popFrom != null && popFrom.mounted) Navigator.of(popFrom).pop();
      setState(() => _index = 0);
    }
  }

  void _followUp(BuildContext context, AppNotification n) => _openFrom(n.data, popFrom: context);

  /// موضعُ «الرسائل» في الشريط — يُسمّى ولا يُكتب رقمُه في موضعين.
  static const _chatTab = 3;

  /// **ويُعاد عدُّ ما لم يُقرأ عند دخول تبويب الرسائل وعند الخروج منه.**
  /// الحبّةُ على البند، ومن قرأ رسائلَه ثمّ انتقل يجب ألّا يجدها كما كانت.
  /// ولا يُعدّ عند كلّ نقلة: نداءُ شبكةٍ لا يفيد من ينتقل بين الطلبات
  /// والتقويم.
  void _select(int i) {
    final was = _index;
    setState(() => _index = i);
    if (was == _chatTab || i == _chatTab) _countUnread();
  }

  @override
  Widget build(BuildContext context) {
    // **خمسةُ بنودٍ بترتيب صاحب المنصّة**، ودخلت «الرسائل» رابعةً — وكانت
    // شاشةً تُفتح من أيقونةٍ في الرأس.
    final titles = [
      tr('الطلبات'),
      tr('خدماتي'),
      tr('تقويمي'),
      tr('الرسائل'),
      tr('ملفي'),
    ];
    final pages = [
      RequestsScreen(session: widget.session),
      ServicesScreen(session: widget.session),
      AvailabilityScreen(session: widget.session),
      // **تبويباً لا طريقاً**: يسقط شريطُها العلويُّ لئلّا يجتمع رأسان.
      const ConversationsScreen(embedded: true),
      ProviderProfileScreen(session: widget.session),
    ];

    return Scaffold(
      // **والمحتوى يمرّ تحت الشريط لا فوقه** — وهذا ما يعطي التمويهَ ما
      // يموّهه. ولذلك تُنهي كلُّ شاشةٍ من الأربع محتواها بمسافة
      // `glassNavSpace`، وإلّا اختفى آخرُ سطرٍ فيها خلف الزجاج.
      extendBody: true,
      // الشريط العلوي في `Stack` لا في خانة `appBar`: خانة Scaffold تحجز
      // ارتفاعها وتدفع المحتوى تحتها، فلا يمرّ شيءٌ خلف الزجاج ولا يجد
      // التمويهُ ما يموّهه. وهنا يطفو فوقه كما يطفو الشريط السفلي.
      body: AlertBanner(
        // الحمولةُ نفسها التي يفتح بها إشعارُ شريط النظام: طريقٌ واحد لِما
        // يقع أمام المستخدم ولِما يصله وهو خارج التطبيق، فلا يفترقان عند
        // أوّل نوعٍ يُضاف.
        onOpen: (data) {
          _openFrom(data);
          _countAlerts();
        },
        child: GlassHeaderHost(
          title: titles[_index],
          tab: _index,
          // **والجرسُ وحدَه في الرأس، ويقف مكانَ الرسائل** — بطلب صاحب
          // المنصّة. وأيقونةُ الرسائل رُفعت: صارت بنداً في الشريط السفليّ،
          // وبابان لغرفةٍ واحدةٍ يُحتار فيهما.
          end: BellIconButton(unread: _alerts, onTap: _openAlerts),
          child: pages[_index],
        ),
      ),
      // **وشريطُ المزوّد زجاجيٌّ كشريط العميل** — بطلب صاحب المنصّة. وكان
      // `NavigationBar` مادّيّاً يقف تحت المحتوى ويحجز ارتفاعَه، فكانت
      // الشاشتان تفترقان في أظهر ما فيهما.
      bottomNavigationBar: GlassNavBar(
        index: _index,
        onSelect: _select,
        items: [
          GlassNavItem(
            label: tr('الطلبات'),
            icon: Icons.inbox_outlined,
            activeIcon: Icons.inbox,
          ),
          GlassNavItem(
            label: tr('خدماتي'),
            icon: Icons.sell_outlined,
            activeIcon: Icons.sell,
          ),
          GlassNavItem(
            label: tr('تقويمي'),
            icon: Icons.event_note_outlined,
            activeIcon: Icons.event_note,
          ),
          // **فقّاعةٌ فيها برق** — اختارها صاحبُ المنصّة من ستٍّ عُرضت عليه،
          // وهي أقربُ ما في أيقونات التطبيق إلى شكل مسنجر. وأيقونةُ فيسبوك
          // نفسُها لا تُوضع: علامةٌ تجاريّةٌ لغيرنا تُوهم صلةً لا وجودَ لها.
          //
          // **وعليها عدّادُ ما لم يُقرأ**: كان في أيقونة الرأس، فلمّا رُفعت
          // لم يبقَ في الشاشة موضعٌ يقول «عندك رسالة».
          GlassNavItem(
            label: tr('الرسائل'),
            icon: Icons.quickreply_outlined,
            activeIcon: Icons.quickreply_rounded,
            unread: _unread,
          ),
          GlassNavItem(
            label: tr('ملفي'),
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront,
          ),
        ],
      ),
    );
  }
}
