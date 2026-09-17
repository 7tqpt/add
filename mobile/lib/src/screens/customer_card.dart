import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

/// بطاقةُ العميل كما يراها مقدّمُ الخدمة من شريط المحادثة.
///
/// ── لماذا وُجدت ─────────────────────────────────────────────────────────
///
/// ضغط صاحبُ المنصّة شريطَ المحادثة بحساب مقدّم خدمةٍ فلم يُفتح شيء — وكان
/// ذلك اختيارَه قبلُ، إذ **لا ملفَّ عامّ للعميل في التطبيق**. ثمّ اختار أن
/// تُبنى «**بصورته ومحافظته عبر دالّةٍ ضيّقةٍ تُرجع هذين وحدَهما لطرفَي
/// محادثةٍ قائمة**».
///
/// ── وحدُّ ما فيها ليس ذوقاً ──────────────────────────────────────────────
///
/// سياسةُ `app_users` صريحة: «العميل يرى ويعدّل حسابه هو. لا يرى حسابات
/// غيره إطلاقاً» — وهي تشمل مقدّمَ الخدمة. **ولم تُوسَّع**: من طلب صورةً لا
/// يُعطى بريداً. فالصورةُ والمحافظةُ من `api_customer_card` وحدَها، وما
/// عداهما محسوبٌ من حجوزات مقدّم الخدمة نفسِه.
///
/// **ولا جوّالَ هنا ولا بريد.** لم يُطلبا، وليسا في الحجوزات أصلاً — ورقمُ
/// إنسانٍ لا يُعرض لأنّه «قد ينفع».
class CustomerCardScreen extends StatefulWidget {
  const CustomerCardScreen({
    super.key,
    required this.conversationId,
    required this.name,
  });

  final String conversationId;

  /// الاسمُ المعروفُ قبل الفتح — يُكتب في الشريط ريثما تصل البطاقة، فلا
  /// تُفتح الشاشةُ على عنوانٍ عامّ ثمّ يتبدّل.
  final String name;

  @override
  State<CustomerCardScreen> createState() => _CustomerCardScreenState();
}

class _CustomerCardScreenState extends State<CustomerCardScreen> {
  CustomerCard? _card;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final card = await Api.customerCard(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _card = card;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageOf(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('العميل'))),
    body: _loading
        ? const LoadingBlock()
        : _error != null
        ? ErrorBlock(message: _error!, onRetry: _load)
        : _card == null
        ? ErrorBlock(message: tr('لا بطاقةَ لهذه المحادثة.'), onRetry: _load)
        : ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [_Body(card: _card!)],
          ),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.card});
  final CustomerCard card;

  @override
  Widget build(BuildContext context) {
    final c = card;
    return AppCard(
      children: [
        Row(
          children: [
            _Disc(name: c.fullName, path: c.avatarPath),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.fullName.trim().isEmpty ? tr('عميل') : c.fullName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  // **ولا يُعرض سطرٌ فارغ:** من لم يُثبت محافظتَه لا يأخذ
                  // أيقونةً ومكاناً خالياً بجانبها.
                  if (c.governorate.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Muted(c.governorate, size: 12),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        const Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: Space.md),
        SectionTitle(tr('حجوزاته معك')),
        // **ومن راسلك ولم يحجز يُقال له ذلك**، لا تُعرض أصفارٌ تُقرأ عطباً.
        if (c.bookingsCount == 0) ...[
          const SizedBox(height: Space.sm),
          Muted(tr('راسلك ولم يحجز بعد.'), size: 12),
        ] else ...[
          if (c.firstBookingAt.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Muted(trf('أوّلُ حجزٍ في {0}', [formatDate(c.firstBookingAt)]),
                size: 12),
          ],
          const SizedBox(height: Space.md),
          const Divider(height: 1, color: AppColors.hairline),
          KeyValue(tr('الحجوزات'), formatCount(c.bookingsCount, bookingForms)),
          const Divider(height: 1, color: AppColors.hairline),
          KeyValue(tr('المكتملة'), '${c.completedCount}'),
          const Divider(height: 1, color: AppColors.hairline),
          KeyValue(tr('الملغاة'), '${c.cancelledCount}'),
          const Divider(height: 1, color: AppColors.hairline),
          KeyValue(tr('القادمة'), '${c.upcomingCount}'),
          const Divider(height: 1, color: AppColors.hairline),
          // **وما دُفع لا ما وُعد.** المجموعُ `paid − refunded`، فحجزٌ لم
          // يُدفع عربونُه يُظهر صفراً — وهو الصدق.
          KeyValue(tr('إجمالي ما دفعه لك'), formatMoney(c.totalPaid)),
        ],
      ],
    );
  }
}

/// قرصُ العميل — صورتُه، أو حرفُ اسمه.
///
/// **والحرفُ هو الغالب:** أكثرُ الحسابات بلا صورة.
class _Disc extends StatelessWidget {
  const _Disc({required this.name, required this.path});

  final String name;
  final String path;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final url = Api.avatarUrl(path);
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? tr('؟') : trimmed.characters.first;
    final fallback = Text(
      letter,
      style: const TextStyle(
        fontSize: _size * 0.4,
        fontWeight: FontWeight.w700,
        color: AppColors.accentInk,
        fontFamilyFallback: arabicFallback,
      ),
    );

    return Container(
      key: const ValueKey('customer-avatar'),
      width: _size,
      height: _size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: url == null
          ? fallback
          // **وصورةٌ تسقط تعود حرفاً لا مربّعاً مكسوراً** — الشبكةُ هنا
          // تُسقط الطلبَ كثيراً.
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: _size,
              height: _size,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
