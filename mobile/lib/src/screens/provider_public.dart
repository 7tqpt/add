import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/media.dart';
import '../ui/service_card.dart';
import 'chat.dart';
import 'service_detail.dart';

/// ملفُّ مقدّم الخدمة كما يراه العميل.
///
/// **لماذا:** الخدمة تُعرض وحدها فيُحكَم عليها وحدها. ومن رأى «كوشة ورد» لا
/// يعرف أنّ صاحبها يعرض تنسيق المداخل والطاولات أيضاً، ولا كم عرساً نفّذ، ولا
/// ماذا قال من تعامل معه. فيقارن ثمناً بثمن، وهو لا يشتري ثمناً بل يشتري من
/// يُسلّمه ليلةً لا تُعاد.
///
/// **وشكلُها ليس زينة:** غلافٌ ملوّن وشعارٌ يطلّ عليه واسمٌ إلى جانبه علامةُ
/// التوثيق — هذه هي الواجهة التي يقيس بها العميل جِدّية من أمامه قبل أن يقرأ
/// سطراً واحداً. وصفحةٌ من بطاقاتٍ بيضاء متشابهة تقول إن هذا سجلٌّ إداريّ لا
/// محلٌّ يُشترى منه.
///
/// وغير `ProviderProfileScreen`: تلك شاشةُ المزوّد عن نفسه — يعدّل ملفَّه ويرى
/// حالة توثيقه. وهذه صفحتُه عند غيره: لا تعديلَ فيها ولا حالة، وليس فيها بريدٌ
/// ولا رقمُ جوال. والاتصالُ بها في المحادثة داخل المنصّة، فيبقى للكلام سجلٌّ
/// إن وقع نزاع.
class PublicProviderScreen extends StatefulWidget {
  const PublicProviderScreen({super.key, required this.providerId, this.name});

  final String providerId;

  /// الاسمُ إن كان معروفاً قبل الفتح — يُكتب في الشريط ريثما يصل الملفّ، فلا
  /// تُفتح الشاشة على عنوانٍ عامّ ثم يتبدّل.
  final String? name;

  @override
  State<PublicProviderScreen> createState() => _PublicProviderScreenState();
}

class _PublicProviderScreenState extends State<PublicProviderScreen> {
  late Future<PublicProvider?> _future;
  late Future<List<ServiceItem>> _services;
  late Future<List<Review>> _reviews;
  late Future<List<ServiceMedia>> _gallery;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // ثلاثةٌ متوازية لا متتابعة: شبكةُ الجوال هنا ليست سخيّة، وتتابعُها يجمع
    // زمنها كلَّه بلا سبب.
    _future = Api.provider(widget.providerId);
    _services = Api.providerServices(widget.providerId);
    _reviews = Api.providerReviews(widget.providerId);
    _gallery = Api.providerGallery(widget.providerId);
  }

  void _reload() {
    setState(_load);
  }

  Future<void> _message(PublicProvider p) async {
    setState(() => _busy = true);
    try {
      final id = await Api.openConversation(p.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            otherName: p.businessName,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // الشريط شفّافٌ فوق الغلاف: عنوانٌ بأرضيّةٍ بيضاء يقطع الغلاف بخطٍّ
      // ويجعله شريطاً ملوّناً لا واجهة.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.accentInk,
        title: const Text(''),
      ),
      body: FutureBuilder<PublicProvider?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final p = snap.data;
          // غيرُ الموثَّق لا يُفتح ملفُّه: سياسةُ القراءة تُخفيه فتعود القراءة
          // فارغة. والرسالة تقول ما وقع بلا أن تقول عن أحدٍ إنه مرفوض.
          if (p == null) {
            return const EmptyBlock(
              title: 'الملفّ غير متاح',
              description: 'قد يكون مقدّم الخدمة قد أوقف عرضه أو لم تُوثّقه الإدارة بعد.',
            );
          }

          // أربعةُ تبويبات لا صفحةٌ واحدة طويلة.
          //
          // **والسبب أن الزائر يأتي بسؤالٍ واحد:** «كم؟» أو «كيف يبدو
          // المكان؟» أو «ماذا قال من جرّبه؟». والصفحةُ الطويلة تُلزمه أن يمرّ
          // على الثلاثة ليجد واحداً — ومعرضُ الصور وحده قد يكون أربعين صورة
          // بينه وبين التقييمات.
          return DefaultTabController(
            length: 4,
            child: NestedScrollView(
              // الرأسُ يزحف مع التمرير والتبويباتُ تثبت: لو ثبت الرأسُ كلُّه
              // لبقي ثلثُ الشاشة غلافاً في كل تبويب.
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Head(provider: p),
                      _pad(
                        Padding(
                          padding: const EdgeInsets.only(top: Space.lg, bottom: Space.md),
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => _message(p),
                            icon: const Icon(Icons.forum_outlined, size: 19),
                            label: Text('راسل ${p.businessName}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // `SliverAppBar` لا `SliverPersistentHeader`: الثاني داخل
                // `NestedScrollView` يحسب ارتفاعه بالشريط العلوي فوقه فيخرج
                // `layoutExtent` أكبر من `paintExtent` ببكسلين — فيرمي
                // الرسمُ عند أوّل إطار. و`primary: false` تُلغي حسابَ شريط
                // الحالة الذي هو أصلُ البكسلين.
                const SliverAppBar(
                  pinned: true,
                  primary: false,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 0,
                  backgroundColor: AppColors.page,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  bottom: _ProviderTabs(),
                ),
              ],
              body: TabBarView(
                children: [
                  _About(provider: p, alsoServes: _alsoServes(p)),
                  _TabList(children: [_Services(future: _services, onRetry: _reload)]),
                  _Gallery(future: _gallery),
                  _TabList(children: [_Reviews(future: _reviews, total: p.reviewsCount)]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static List<String> _alsoServes(PublicProvider p) =>
      p.coverageAreas.where((a) => a != p.governorate).toList();

  static Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: Space.lg), child: child);
}

/// الغلافُ والشعارُ والاسمُ وعلامتُه، ثم ثلاثةُ أرقام.
class _Head extends StatelessWidget {
  const _Head({required this.provider});
  final PublicProvider provider;

  /// ارتفاع الغلاف، ومقدارُ ما يطلّ به الشعار عليه.
  static const double _cover = 148;
  static const double _avatar = 92;
  static const double _overlap = 46;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Stack(
      children: [
        // الغلاف: تدرّجٌ من لون العلامة لا صورة — الجدول لا يحمل غلافاً،
        // وصورةٌ عامّة من الشبكة تُشبه صورةَ كل ملفٍّ آخر وتحتاج تحميلاً قد
        // لا يصل.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: _cover,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.accentLift, AppColors.accentDeep],
              ),
            ),
            child: const _CoverBlobs(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: _cover - _overlap),
          child: Column(
            children: [
              ProviderAvatar(
                name: p.businessName,
                imageUrl: Api.avatarUrl(p.logoPath),
                size: _avatar,
                ring: 4,
              ),
              const SizedBox(height: Space.sm),
              // الاسمُ والعلامةُ في صفٍّ واحد. و`Flexible` على النصّ وحده:
              // اسمٌ طويل يقصّ نفسَه ولا يدفع العلامةَ خارج الشاشة.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        p.businessName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (p.isVerified) ...[
                      const SizedBox(width: 6),
                      const VerifiedMark(size: 19),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (p.governorate.isNotEmpty) ...[
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 3),
                    Muted(p.governorate),
                  ],
                  if (p.isFeatured) ...[
                    const SizedBox(width: Space.sm),
                    const StatusBadge('مميّز', color: AppColors.warning),
                  ],
                ],
              ),
              const SizedBox(height: Space.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: _Stats(provider: p),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// قرصان زجاجيّان في الغلاف — عمقٌ بلا صورة.
class _CoverBlobs extends StatelessWidget {
  const _CoverBlobs();

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [
        Positioned(top: -50, left: -30, child: _blob(160, 0.10)),
        Positioned(bottom: -70, right: -20, child: _blob(140, 0.07)),
      ],
    ),
  );

  Widget _blob(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

/// ثلاثةُ أرقامٍ في بطاقةٍ واحدة: التقييم، والحجوزات المنفَّذة، وعددُ التقييمات.
///
/// ولا عددَ للخدمات فيها: هي تحته بعناوينها وأسعارها، ورقمٌ يقول «٣ خدمات»
/// فوق قائمةٍ من ثلاثٍ حشوٌ لا خبر.
class _Stats extends StatelessWidget {
  const _Stats({required this.provider});
  final PublicProvider provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return AppCard(
      children: [
        Row(
          children: [
            _Cell(
              value: p.rating > 0 ? '${p.rating}' : '—',
              label: 'التقييم',
              icon: Icons.star_rounded,
              tone: AppColors.warning,
            ),
            const _Divider(),
            _Cell(
              value: formatNumber(p.completedBookings),
              label: 'حجزاً منفَّذاً',
              icon: Icons.verified_outlined,
              tone: AppColors.good,
            ),
            const _Divider(),
            _Cell(
              value: formatNumber(p.reviewsCount),
              label: 'تقييماً',
              icon: Icons.forum_outlined,
              tone: AppColors.accent,
            ),
          ],
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: AppColors.hairline);
}

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.label, required this.icon, required this.tone});
  final String value;
  final String label;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        Muted(label, size: 10.5),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: Tint.chip),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11.5, color: AppColors.accent, fontWeight: FontWeight.w600),
    ),
  );
}

class _Services extends StatelessWidget {
  const _Services({required this.future, required this.onRetry});
  final Future<List<ServiceItem>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceItem>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(Space.lg), child: LoadingBlock());
        }
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: onRetry);
        }
        final rows = snap.data ?? const <ServiceItem>[];
        if (rows.isEmpty) {
          return const EmptyBlock(
            title: 'لا خدمات معروضة الآن',
            description: 'راسله لتسأل عمّا يقدّمه.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in rows) ...[
              ServiceListCard(
                item: item,
                // اسمُ المزوّد لا يُكرَّر في صفحته: القارئ فيها يعرف عند من هو.
                showProvider: false,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id)),
                ),
              ),
              const SizedBox(height: Space.md),
            ],
          ],
        );
      },
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.future, required this.total});
  final Future<List<Review>> future;
  final int total;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: future,
      builder: (context, snap) {
        final rows = snap.data ?? const <Review>[];
        // لا كتلةَ خطأ هنا: التقييمات مكمّلة، وعطبُ قراءتها لا يجوز أن يُفسد
        // صفحةً بقيّتُها سليمة. تغيب بصمتٍ ويبقى ما فوقها.
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('آراء العملاء')),
                if (total > rows.length) Muted('من ${formatNumber(total)}'),
              ],
            ),
            const SizedBox(height: Space.sm),
            for (final r in rows) ...[
              AppCard(
                children: [
                  Row(
                    children: [
                      ProviderAvatar(name: r.userName, size: 30),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          r.userName.isEmpty ? 'عميل' : r.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Rating(r.rating),
                    ],
                  ),
                  if (r.comment.isNotEmpty) ...[
                    const SizedBox(height: Space.sm),
                    Text(r.comment, style: const TextStyle(height: 1.7, fontSize: 13.5)),
                  ],
                  const SizedBox(height: Space.xs),
                  Muted(formatDate(r.createdAt), size: 11),
                ],
              ),
              const SizedBox(height: Space.sm),
            ],
          ],
        );
      },
    );
  }
}

/// شريطُ التبويبات مثبّتاً تحت الرأس.
class _ProviderTabs extends StatelessWidget implements PreferredSizeWidget {
  const _ProviderTabs();

  // ارتفاعٌ أوسع من الافتراضي: حروف العربية تنزل تحت السطر فتُقصّ في الضيّق.
  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  Widget build(BuildContext context) => Container(
    // أرضيّةٌ صريحة: الشريط يثبت والمحتوى يمرّ تحته، وبلا أرضيّةٍ يُقرأ
    // النصّان فوق بعضهما.
    color: AppColors.page,
    child: const TabBar(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.accent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: arabicFallback,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 13,
        fontFamilyFallback: arabicFallback,
      ),
      tabs: [
        Tab(text: 'النبذة'),
        Tab(text: 'الخدمات'),
        Tab(text: 'الصور'),
        Tab(text: 'التقييمات'),
      ],
    ),
  );
}

/// قائمةٌ داخل تبويب — بحشوةٍ واحدة لا تتكرّر في أربعة مواضع.
class _TabList extends StatelessWidget {
  const _TabList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xl),
    children: children,
  );
}

class _About extends StatelessWidget {
  const _About({required this.provider, required this.alsoServes});
  final PublicProvider provider;
  final List<String> alsoServes;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return _TabList(
      children: [
        if (p.bio.isEmpty)
          const EmptyBlock(
            title: 'لا نبذة بعد',
            description: 'لم يكتب مقدّم الخدمة تعريفاً بعد. تصفّح خدماته أو راسله.',
          )
        else
          AppCard(
            children: [
              const SectionTitle('عن المزوّد'),
              const SizedBox(height: Space.sm),
              Text(p.bio, style: const TextStyle(height: 1.9, fontSize: 14)),
              if (p.categories.isNotEmpty) ...[
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [for (final c in p.categories) _Tag(c)],
                ),
              ],
              // مناطقُ التغطية تُذكر إن زادت على محافظته: «يخدم تعز» لمن هو
              // في تعز خبرٌ لا يفيد، وذكرُها لمن هو في إبّ هو الفرق بين أن
              // يحجز ولا يحجز.
              if (alsoServes.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Muted('يخدم أيضاً: ${alsoServes.join(' · ')}', size: 11),
              ],
            ],
          ),
      ],
    );
  }
}

/// معرضُ صور المزوّد — من خدماته كلِّها.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.future});
  final Future<List<ServiceMedia>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceMedia>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        final items = snap.data ?? const <ServiceMedia>[];
        if (items.isEmpty) {
          return const _TabList(
            children: [
              EmptyBlock(
                title: 'لا صور بعد',
                description: 'لم يرفع مقدّم الخدمة صوراً لخدماته بعد.',
              ),
            ],
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xl),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MediaThumb(url: Api.mediaUrl(items[i].path)),
          ),
        );
      },
    );
  }
}
