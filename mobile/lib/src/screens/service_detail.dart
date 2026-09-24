import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/service_card.dart';
import '../ui/share_button.dart';
import '../ui/kit.dart';
import 'booking_flow.dart';
import '../ui/media.dart';
import '../ui/photo_view.dart';
import 'chat.dart';
import 'provider_public.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key, required this.serviceId, this.coverPath});
  final String serviceId;

  /// غلافُ الخدمة كما تعرفه البطاقةُ التي فُتحت منها.
  ///
  /// **ويُمرَّر ليُرسم في أوّل إطار.** الخدمةُ تُقرأ من الشبكة، فكانت
  /// الشاشةُ تفتح فارغةً حتى تصل — ثمّ يظهر كلُّ شيءٍ دفعةً. والغلافُ
  /// معروفٌ عند المنادي، فيُرسم فوراً ويطير إليه من البطاقة.
  final String? coverPath;
  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late Future<ServiceItem?> _future;

  /// فتحُ المحادثة يجري الآن — ويُعطَّل به زرُّ «راسل» فلا يُفتح خيطان.
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _future = Api.service(widget.serviceId);
  }

  /// يفتح المحادثة مع صاحب الخدمة ثم يدخلها.
  ///
  /// والفتح من القاعدة: الضغطُ مرّتين بسرعة كان سينتج خيطين لو بحث التطبيق
  /// ثم أنشأ بنفسه، فتنقسم الرسائل بينهما ولا يرى أحدٌ نصفها.
  Future<void> _message(ServiceItem item) async {
    setState(() => _busy = true);
    try {
      final id = await Api.openConversation(item.providerId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            otherName: item.providerName,
            // **ولا شعارَ في بيانة الخدمة** — فيبقى الحرفُ حتى يصل
            // `_loadHeader`. والمعرّفُ يُمرَّر فيُضغط الشريطُ من أوّل إطار.
            providerId: item.providerId,
            mySide: ChatSide.customer,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ارتفاعُ صندوق الغلاف — واحدٌ قبل وصول الصور وبعده، فلا يقفز ما تحته.
  static const _coverHeight = 230.0;

  /// ارتفاعُ كتلة الانتظار والعطب والفراغ داخلَ الممرّ.
  static const _blockHeight = 260.0;

  /// **ومستقبلٌ واحدٌ للوسائط يشترك فيه الغلافُ والجسم.** لو كان لكلٍّ نداؤه
  /// لَقُرئت وسائطُ الخدمة مرّتين في كلّ فتحة.
  late final Future<List<ServiceMedia>> _media = Api.serviceMedia(widget.serviceId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('تفاصيل الخدمة')),
        // **و`_future` نفسُها لا نداءٌ ثانٍ.** `FutureBuilder` على المستقبل
        // عينِه يشترك في نتيجته، فلا تُقرأ الخدمةُ مرّتين لأجل زرّ.
        actions: [
          FutureBuilder<ServiceItem?>(
            future: _future,
            builder: (context, snap) {
              final item = snap.data;
              // ولا زرَّ قبل أن تصل الخدمة: زرٌّ يُضغط فلا يقع شيء.
              if (item == null) return const SizedBox.shrink();
              return ShareServiceButton(item: item);
            },
          ),
        ],
      ),
      // **وممرَّرٌ واحدٌ يضمّ الغلافَ والمحتوى.**
      //
      // كان عموداً: الغلافُ بارتفاعٍ ثابتٍ ثمّ `Expanded` فيه القائمة — أي
      // أنّ الغلافَ **خارجَ الممرَّر**، فيمشي المحتوى تحته وهو لا يتزحزح
      // مهما مُرِّر. وقال صاحبُ المنصّة: «ليش صورة ثابتة؟ أريدها ما تكون
      // ثابتة»، واختار (أ) من ثلاث: أن يدخل الغلافُ القائمةَ نفسَها فيخرج
      // بالتمرير وتتّسع الشاشةُ للتفاصيل.
      //
      // **والغلافُ أوّلُ الأبناء لا داخلَ `FutureBuilder`** — وهو الشرطُ
      // الذي كان يحفظه العمود، ويُحفظ هنا كما هو: القائمةُ تبني ما يُرى،
      // وأوّلُ أبنائها يُرى في أوّل إطار.
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // **والغلافُ خارجَ `FutureBuilder` عمداً.** لو كان داخلَه لَما وُجد
          // أثناء التحميل — ووقتُ التحميل هو وقتُ الانتقال بعينه، فيطير
          // الغلافُ من البطاقة إلى فراغٍ ويرتدّ. وخارجَه يُرسم في أوّل إطار
          // فيجد الطائرُ موضعَه، ويرى صاحبُ الشاشة ما ضغط عليه بدل بياض.
          //
          // **والمعرضُ هو الغلافُ نفسُه لا شيءٌ تحته.** كانا اثنين: غلافٌ في
          // الأعلى ومعرضٌ تحته يعرض الصورَ كلَّها — والغلافُ أوّلُ تلك الصور.
          // فكانت الصورةُ الواحدة تُعرض مرّتين متلاصقتين، وخدمةٌ لها صورةٌ
          // واحدةٌ تملأ نصفَ الشاشة بنسختين منها.
          //
          // فصار الصندوقُ واحداً: يُرسم فيه الغلافُ في أوّل إطار (فيجد
          // الطائرُ موضعَه)، فإذا وصلت الصورُ حلّ محلَّه معرضٌ يُقلَّب — بلا
          // قفزةٍ في التخطيط، لأنّ الارتفاع واحدٌ قبلُ وبعد.
          if (widget.coverPath != null)
            Hero(
              tag: serviceHeroTag(widget.serviceId),
              child: SizedBox(
                height: _coverHeight,
                width: double.infinity,
                child: FutureBuilder<List<ServiceMedia>>(
                  future: _media,
                  builder: (context, snap) {
                    final images = (snap.data ?? const <ServiceMedia>[])
                        .where((m) => m.kind == MediaKind.image)
                        .toList();
                    // **والغلافُ يُفتح بالضغط ملءَ الشاشة.** «صورة غير قابلة
                    // للضغط هنا» — وكانت هذه وحدَها الباقيةَ ساكنةً: صورُ
                    // معرض المزوّد وشعارُه وغلافُه تُفتح منذ جولةٍ سابقة.
                    //
                    // **ويُقلَّب فيه بين الصور كلِّها** — اختار صاحبُ المنصّة
                    // (ج) من ثلاث. ومن لم يكن لخدمته إلّا صورةٌ واحدةٌ فُتحت
                    // وحدَها بلا عدّاد.
                    if (images.length < 2) {
                      return GestureDetector(
                        key: const ValueKey('service-cover-tap'),
                        onTap: () => openGallery(
                          context,
                          urls: [Api.mediaUrl(widget.coverPath) ?? ''],
                        ),
                        child: MediaThumb(url: Api.mediaUrl(widget.coverPath)),
                      );
                    }
                    // **ويُفتح على المعروضة الآن لا على أوّلها**: من قلّب
                    // إلى الثالثة وضغط يريد الثالثة.
                    return _Gallery(
                      images: images,
                      onOpen: (i) => openGallery(
                        context,
                        urls: [
                          for (final m in images) Api.mediaUrl(m.path) ?? '',
                        ],
                        initialIndex: i,
                      ),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: _body(context),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return FutureBuilder<ServiceItem?>(
      future: _future,
      builder: (context, snap) {
        // **ومساحةٌ محجوزةٌ للحالات الثلاث.** صارت هذه الكتلُ داخلَ ممرَّرٍ
        // يلتفّ على ابنه، فتنكمش على قدر الدوّار وتلتصق بأسفل الغلاف. وكانت
        // في `Expanded` يتوسّطها ما بقي من الشاشة.
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: _blockHeight, child: LoadingBlock());
        }
        if (snap.hasError) {
          return SizedBox(
            height: _blockHeight,
            child: ErrorBlock(message: messageOf(snap.error!)),
          );
        }
        final item = snap.data;
        if (item == null) {
          return SizedBox(
            height: _blockHeight,
            child: EmptyBlock(title: tr('الخدمة غير موجودة')),
          );
        }

        final deposit = (item.price * item.depositPercent / 100).round();

        // **عمودٌ لا قائمةٌ ثانية**: الممرُّ صار واحداً في الأعلى يضمّ
        // الغلافَ وهذا، وقائمةٌ داخلَ قائمةٍ لا ارتفاعَ لها.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الوسائط فوق كل شيء: من فتح الخدمة يريد أن يرى ما يشتريه قبل
            // أن يقرأ عنه. والسعرُ تحتها لأن السعر يُحكَم عليه بعد الرؤية
            // لا قبلها.
            _Media(
              media: _media,
              // **والصورُ تُعرض هنا فقط لمن جاء بلا غلاف.** من فُتحت له
              // الشاشةُ من بطاقةٍ تحمل غلافَها يراها في الأعلى، ومن جاء
              // من موضعٍ لا يعرف الغلافَ (إشعارٌ، رابط) لا يرى صورةً
              // أصلاً لولا هذا.
              showImages: widget.coverPath == null,
            ),
            AppCard(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SectionTitle(item.title)),
                    if (item.providerIsFeatured) ...[
                      const SizedBox(width: Space.sm),
                      StatusBadge(tr('مميّز'), color: AppColors.warning),
                    ],
                  ],
                ),
                const SizedBox(height: Space.md),
                // صاحبُ الخدمة بابٌ لا سطرَ نصّ.
                //
                // كان اسمُه هنا حرفاً رمادياً لا يُضغط، فمن أعجبته الخدمة لم
                // يجد سبيلاً إلى بقيّة ما يعرضه صاحبُها ولا إلى ما قاله من
                // تعامل معه. وهو لا يشتري خدمةً بل يشتري من يُسلّمه ليلةً لا
                // تُعاد.
                _ProviderRow(item: item),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  Text(item.description, style: const TextStyle(height: 1.8)),
                ],
                const SizedBox(height: Space.md),
                // في بطاقة المزوّد لا عند زرّ الحجز: السؤال يسبق الحجز ولا
                // يليه. ومن لا يجد أين يسأل يذهب إلى واتساب، فيخرج الحجز
                // من المنصّة كلّه ومعه سجلُّه.
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _message(item),
                  icon: const Icon(Icons.forum_outlined, size: 19),
                  label: Text(trf('راسل {0}', [item.providerName])),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            AppCard(
              children: [
                SectionTitle(tr('السعر')),
                KeyValue(
                  tr('السعر'),
                  item.priceTo == null
                      ? formatMoney(item.price)
                      : '${formatMoney(item.price)} – ${formatMoney(item.priceTo!)}',
                ),
                KeyValue(tr('الوحدة'), item.unit),
                KeyValue(trf('العربون {0}٪', ['${item.depositPercent}']), formatMoney(deposit)),
                if (item.cancellationPolicyName != null)
                  KeyValue(tr('سياسة الإلغاء'), item.cancellationPolicyName!),
                const SizedBox(height: Space.sm),
                // السعر المعروض للاطّلاع، والمعتمد ما يحسبه الخادم عند الحجز:
                // لو قبِل سعراً من التطبيق لأمكن حجز قاعة بريال واحد.
                Muted(tr('المبلغ النهائي يحسبه النظام عند تأكيد الحجز.'), size: 11),
              ],
            ),
            const SizedBox(height: Space.md),
            AppCard(
              children: [
                SectionTitle(tr('احجز')),
                const SizedBox(height: Space.sm),
                // **والنموذجُ خرج من هنا إلى ثلاث خطوات.** كان في ذيل هذه
                // الصفحة نموذجٌ واحدٌ طويل — تاريخٌ ووقتٌ وضيوفٌ وعنوانٌ
                // ونقطةٌ وخطّةٌ وكودٌ وملاحظات — ثمّ «تأكيد الحجز» مباشرةً.
                // **ولا مراجعةَ بينه وبين الإرسال**: من أخطأ في التاريخ أو
                // العنوان لم يُعرض عليه ما سيُرسل قبل أن يُرسَل، ولم يرَ ما
                // سيدفعه إلّا بعد أن وقع الحجز.
                //
                // وصفحةُ الخدمة تبقى لما جاء له القارئ: ما هي الخدمة، ومن
                // صاحبُها، وبكم. والحجزُ فعلٌ يُفتح له مسارُه.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Muted(
                    tr('ثلاث خطوات: تفاصيل مناسبتك، ثم الموعد والعنوان، ثم مراجعةٌ قبل الإرسال.'),
                  ),
                ),
                const SizedBox(height: Space.md),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BookingFlowScreen(item: item)),
                  ),
                  child: Text(tr('ابدأ الحجز')),
                ),
                const SizedBox(height: Space.sm),
                Muted(
                  tr('الحجز يبقى «بانتظار مقدّم الخدمة» حتى يقبله. لو اعتذر، يُستردّ كل ما دفعته.'),
                  size: 11,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// صفُّ المزوّد: حرفُه في قرص، واسمُه، وتقييمُه، وسهمٌ إلى ملفّه.
///
/// وله أرضيّةٌ وحدٌّ لأنه داخل بطاقةٍ بيضاء: عنصرٌ يُضغط داخل بطاقةٍ لا تُضغط
/// يجب أن يقول عن نفسه إنه يُضغط، وإلا بقي حرفاً بين حروف.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.item});
  final ServiceItem item;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: AppColors.accent.withValues(alpha: Tint.row),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PublicProviderScreen(providerId: item.providerId, name: item.providerName),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: Tint.disc),
                ),
                child: Text(
                  item.providerName.isEmpty ? tr('؟') : item.providerName.characters.first,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.providerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (item.providerVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedMark(size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(child: Muted(item.providerGovernorate, size: 11)),
                        if (item.providerRating > 0) ...[
                          const SizedBox(width: Space.sm),
                          Rating(item.providerRating, count: item.providerReviewsCount, size: 11),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.xs),
              Muted(tr('عرض ملفّه'), size: 11),
              // «forward» لا «back»: أيقونات الأسهم تنعكس مع اتجاه النصّ، فـ
              // «back» في العربية يشير يميناً — أي رجوعاً.
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// وسائط الخدمة في شاشة العميل — صورٌ تُمرَّر، ثم المقطعان.
///
/// **وغيابُها غيابٌ صامت:** خدمةٌ بلا وسائط لا تعرض إطاراً فارغاً ولا رسالة
/// «لا صور» — تلك تقول للعميل إن شيئاً ينقص، وهو لا يملك إصلاحه. تختفي
/// الكتلة كلّها وتبقى الشاشة كما كانت.
///
/// ونداءٌ مستقلٌّ عن الخدمة: عطبُ الوسائط لا يجوز أن يمنع الحجز — من فتح
/// الشاشة ليحجز يحجز، ولو تعذّرت الصور.
class _Media extends StatefulWidget {
  const _Media({required this.media, required this.showImages});

  /// مستقبلُ الوسائط — يأتي من الشاشة فيشترك فيه الغلافُ وهذا الجسم.
  final Future<List<ServiceMedia>> media;

  /// أتُعرض الصورُ هنا؟ لا تُعرض لمن رأى الغلافَ في الأعلى — وإلّا كُرِّرت.
  final bool showImages;

  @override
  State<_Media> createState() => _MediaState();
}

class _MediaState extends State<_Media> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceMedia>>(
      future: widget.media,
      builder: (context, snap) {
        final all = snap.data ?? const <ServiceMedia>[];
        if (all.isEmpty) return const SizedBox.shrink();

        final images = all.where((m) => m.kind == MediaKind.image).toList();
        final video = all.where((m) => m.kind == MediaKind.video).firstOrNull;
        final audio = all.where((m) => m.kind == MediaKind.audio).firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showImages && images.isNotEmpty) ...[
              // **وهذه تُفتح كأختها في الأعلى.** يراها من جاء من موضعٍ لا
              // يعرف الغلافَ — إشعارٌ أو رابط — وهو أحوجُ إلى أن يرى.
              SizedBox(
                height: 230,
                child: _Gallery(
                  images: images,
                  onOpen: (i) => openGallery(
                    context,
                    urls: [for (final m in images) Api.mediaUrl(m.path) ?? ''],
                    initialIndex: i,
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
            ],
            if (video != null) ...[
              VideoBox(url: Api.mediaUrl(video.path), seconds: video.durationSeconds),
              const SizedBox(height: Space.md),
            ],
            if (audio != null) ...[
              AudioBar(
                url: Api.mediaUrl(audio.path),
                seconds: audio.durationSeconds,
                label: audio.title.isEmpty ? tr('استمع قبل أن تحجز') : audio.title,
              ),
              const SizedBox(height: Space.md),
            ],
          ],
        );
      },
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.onOpen});
  final List<ServiceMedia> images;

  /// يُنادى بفهرس الصورة المعروضة حين تُضغط.
  final void Function(int index) onOpen;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final (i, m) in widget.images.indexed)
                GestureDetector(
                  key: ValueKey('service-cover-tap-$i'),
                  onTap: () => widget.onOpen(i),
                  child: MediaThumb(url: Api.mediaUrl(m.path)),
                ),
            ],
          ),
        ),
        // النقاط تغيب مع الصورة الواحدة: نقطةٌ واحدة تحت صورةٍ واحدة تقول
        // شيئاً لا معنى له.
        if (widget.images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: Space.sm,
            child: Center(
              // **وقرصٌ داكنٌ تحت النقاط.** صورةُ فستانٍ بيضاء تبتلع نقاطاً
              // بيضاء وصورةٌ داكنةٌ تبتلع نقاطاً نبيذيّة — والقرصُ يجعلها
              // تُرى على كلّ صورة.
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.images.length; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 16 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i == _page ? Colors.white : Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
