import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/service_card.dart';
import 'provider_public.dart';
import 'service_detail.dart';

/// المفضّلة — ما حفظه المستخدم ليعود إليه.
///
/// **والقلب كان يعمل بلا هذه الشاشة:** يُضغط في الاستكشاف فيُحفظ الصفّ في
/// `favourites` فعلاً — ثم لا يوجد في التطبيق كلِّه مكانٌ يعرض ما حُفظ. فمن
/// حفظ ستّ قاعاتٍ ليقارن بينها كان عليه أن يبحث عنها واحدةً واحدة من جديد،
/// وهو بالضبط ما حفظها ليتجنّبه. زرٌّ يعِد بشيءٍ ولا يفي به أسوأ من غيابه:
/// الغائب يُبحث له عن بديل، والكاذب يُوثَق به.
class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  late Future<({List<ServiceItem> items, int missing})> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.favouriteServices();
  }

  void _reload() {
    setState(() {
      _future = Api.favouriteServices();
    });
  }

  /// الإزالة من داخل المفضّلة تحذف الصفّ من الشاشة، لا تُطفئ قلباً ويبقى.
  ///
  /// والفرقُ عن الاستكشاف مقصود: هناك القائمةُ نتائجُ بحثٍ والقلب حالةٌ فيها،
  /// وهنا القائمةُ **هي** المفضّلة — فصفٌّ بقلبٍ مطفأ فيها تناقض.
  Future<void> _remove(ServiceItem item) async {
    try {
      await Api.toggleFavourite(item.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('أُزيلت «${item.title}» من المفضّلة'),
          action: SnackBarAction(
            label: 'تراجع',
            // التراجع يُعيد الصفّ فعلاً: الإزالة بضغطةٍ واحدة بلا سؤال،
            // فلا بدّ من بابٍ للرجوع — وإلّا ضاع ما حُفظ بلمسةٍ خاطئة.
            onPressed: () async {
              await Api.toggleFavourite(item.id);
              if (mounted) _reload();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageOf(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<({List<ServiceItem> items, int missing})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final data = snap.data!;
          if (data.items.isEmpty && data.missing == 0) {
            return const EmptyBlock(
              title: 'لا شيء في المفضّلة بعد',
              description: 'اضغط القلب على أي خدمة في الاستكشاف لتحفظها هنا وتقارن بينها.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, glassNavSpace),
            children: [
              // **الناقصُ يُقال لا يُحذف بصمت:** خدمةٌ حُفظت ثم أُوقفت تختفي
              // من `v_services`، فتنقص القائمة بلا سبب. ومن حفظ ستّاً فرأى
              // خمساً يظنّ أن التطبيق أضاع حفظه.
              if (data.missing > 0) ...[
                AppCard(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: AppColors.muted),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Muted(
                            data.missing == 1
                                ? 'خدمةٌ واحدة في مفضّلتك لم تعد متاحة — أوقفها صاحبها أو حذفها.'
                                : '${data.missing} خدماتٍ في مفضّلتك لم تعد متاحة.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
              ],
              for (final item in data.items) ...[
                ServiceListCard(
                  item: item,
                  isFavourite: true,
                  onToggleFavourite: () => _remove(item),
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id)),
                  ),
                  onOpenProvider: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublicProviderScreen(
                        providerId: item.providerId,
                        name: item.providerName,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
              ],
            ],
          );
        },
      ),
    );
  }
}
