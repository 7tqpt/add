// زرُّ المشاركة، وما يفتح ورقةَ النظام.
//
// **والفعلُ خلف مقبضٍ يُبدَّل.** `SharePlus` تنادي قناةَ النظام، ولا نظامَ
// في `flutter test` — فلو نُوديت مباشرةً لَتعذّر قياسُ أيِّ شيءٍ في هذا
// الملفّ إلّا بجوالٍ في اليد. و[shareSink] تجعل الاختبارَ يلتقط ما كان
// سيُرسَل فيقرؤه حرفاً حرفاً.
library;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/share.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import 'kit.dart';

/// ما ينفّذ المشاركة فعلاً — يُبدَّل في الاختبار.
typedef ShareSink = Future<void> Function(String text);

ShareSink shareSink = _systemShare;

Future<void> _systemShare(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}

/// يُعيد المقبضَ إلى ورقة النظام — يُنادى في `tearDown`.
void resetShareSink() => shareSink = _systemShare;

// ---------------------------------------------------------------------------
//  الرابط
// ---------------------------------------------------------------------------

Future<String>? _urlOnce;

/// رابطُ الدعوة — يُقرأ مرّةً في عمر التشغيل لا مع كلّ ضغطة.
///
/// **ولا يُترك عطبُ القراءة في الذاكرة.** لو حُفظ `Future` فاشلٌ لَبقي فاشلاً
/// إلى أن يُغلق التطبيق: من ضغط «شارك» وشبكتُه منقطعةٌ لحظةً لا يُشارك بعدها
/// أبداً وإن عادت شبكتُه. فيُبتلع العطبُ إلى نصٍّ فارغ، ويُنسى المحفوظُ.
Future<String> cachedShareUrl() => _urlOnce ??= Api.shareUrl().catchError((_) {
      _urlOnce = null;
      return '';
    });

/// يُنسي الرابطَ المحفوظ — للاختبار ولتبديل الإعدادات.
void resetShareUrlCache() => _urlOnce = null;

// ---------------------------------------------------------------------------
//  الأزرار
// ---------------------------------------------------------------------------

/// زرُّ مشاركةٍ في شريط الشاشة.
///
/// و[compose] تأخذ الرابطَ وتُعيد النصّ — فيبقى بناءُ النصّ في `share.dart`
/// حيث يُقاس، ولا يتسرّب سطرٌ منه إلى الشاشات. (واسمُها ليس `build` لأنّ
/// `StatelessWidget` تحجزه.)
class ShareIconButton extends StatelessWidget {
  const ShareIconButton({super.key, required this.compose});

  final String Function(String url) compose;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('share-button'),
    tooltip: tr('شارك'),
    // `ios_share` هو السهمُ الخارجُ من الصندوق — ويُقرأ «أرسِل هذا» في
    // النظامين جميعاً.
    icon: const Icon(Icons.ios_share_rounded),
    onPressed: () async {
      final messenger = ScaffoldMessenger.of(context);
      final text = compose(await cachedShareUrl());
      if (text.isEmpty) return;
      try {
        await shareSink(text);
      } catch (_) {
        // ورقةُ النظام قد لا تُفتح — على جهازٍ بلا تطبيقِ مشاركةٍ واحد.
        // ولا يُترك الضغطُ بلا جواب.
        messenger.showSnackBar(
          SnackBar(content: Text(tr('تعذّرت المشاركة من هذا الجهاز.'))),
        );
      }
    },
  );
}

/// زرُّ مشاركة الخدمة.
class ShareServiceButton extends StatelessWidget {
  const ShareServiceButton({super.key, required this.item});
  final ServiceItem item;

  @override
  Widget build(BuildContext context) => ShareIconButton(
    compose: (url) => shareTextForService(item, url: url),
  );
}

/// بندُ «شارك التطبيق» في الإعدادات.
///
/// **ويغيب إن لم يُضبط الرابط.** بندٌ يُضغط فلا يقع شيء أسوأ من غيابه:
/// يُقرأ عطباً في التطبيق. و`share_url` فارغةٌ في القاعدة حتى يضعها صاحبُ
/// المنصّة، وفي النسخة التجريبيّة فارغةٌ دائماً.
class ShareAppTile extends StatelessWidget {
  const ShareAppTile({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: cachedShareUrl(),
    builder: (context, snap) {
      final url = snap.data ?? '';
      // **ويأخذ البندُ بطاقتَه وفراغَه معه.** لو تركهما لمن يعرضه لَبقيت
      // بطاقةٌ فارغةٌ مؤطَّرةٌ في رأس الإعدادات حين يغيب — وهي أظهرُ من
      // البند نفسِه.
      if (!isShareUrlValid(url)) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: AppCard(children: [_tile(context, url)]),
      );
    },
  );

  Widget _tile(BuildContext context, String url) => ListTile(
        key: const ValueKey('share-app'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.ios_share_rounded, color: AppColors.accent),
        title: Text(tr('شارك التطبيق')),
        subtitle: Muted(tr('أرسل «فرحتي» لمن يجهّز عرسه')),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final text = shareTextForApp(url: url);
          if (text.isEmpty) return;
          try {
            await shareSink(text);
          } catch (_) {
            messenger.showSnackBar(
              SnackBar(content: Text(tr('تعذّرت المشاركة من هذا الجهاز.'))),
            );
          }
        },
      );
}
