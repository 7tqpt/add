import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

/// الصورةُ ملءَ الشاشة — تُقرَّب بالإصبعين، وفيها بابٌ إلى التبديل.
///
/// اختار صاحبُ المنصّة (ب) من ثلاثٍ عُرضت عليه: «صور شخصية وغلاف خليهم قابل
/// للضغط وليس متحجر».
///
/// ── وثلاثةُ قراراتٍ تستحقّ أن تُقرأ ────────────────────────────────────────
///
/// **١) أرضيّةٌ سوداء لا نبيذيّة.** الشاشةُ هنا للصورة وحدَها، ولونُ العلامة
/// يصبغ ما يُنظر إليه فيُرى غيرَ لونه. وهو الموضعُ الوحيد في التطبيق الذي
/// يخرج عن اللوح عن قصد — كما خرجت علامةُ التوثيق إلى الأزرق.
///
/// **٢) و«تغيير» لصاحبها وحدَه.** العارضُ نفسُه يُفتح في الصفحة العامّة حيث
/// يرى العميلُ قاعةً ليست له — فيُمرَّر `onEdit` فارغاً ويسقط الزرّ. وزرٌّ
/// يُعرض لمن لا يملكه يُضغط فيرتدّ عليه الطلبُ بخطأٍ لا يفهمه.
///
/// **٣) والشبكةُ تسقط فيُقال ذلك.** صورةٌ لا تصل على شبكةٍ يمنيّة تُخرج
/// شاشةً سوداءَ فارغةً يظنّها صاحبُها عطباً في التطبيق. فيُكتب السبب.
class PhotoViewScreen extends StatelessWidget {
  const PhotoViewScreen({super.key, required this.url, this.onEdit});

  /// رابطُ الصورة — وهي موجودةٌ يقيناً: من لا صورةَ له لا يُفتح له عارض.
  final String url;

  /// يُنادى حين يُطلب التبديل. `null` يُسقط الزرَّ — وهي حالُ من يرى صورةَ
  /// غيره.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (onEdit != null)
            TextButton.icon(
              key: const ValueKey('photo-edit'),
              onPressed: () {
                // **وتُغلق الشاشةُ قبل أن تُفتح الورقة.** ورقةُ الاختيار
                // تُدفع فوق العارض، فيعود صاحبُها بعد الرفع إلى صورةٍ قديمةٍ
                // ملءَ الشاشة ويظنّ أنّ شيئاً لم يقع.
                Navigator.of(context).pop();
                onEdit!();
              },
              icon: const Icon(Icons.photo_camera_outlined,
                  size: 18, color: Colors.white),
              label: Text(
                tr('تغيير'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: Center(
        // **وتُقرَّب بالإصبعين** — وهو معنى «ليس متحجراً»: صورةُ قاعةٍ في
        // شريطٍ عرضُه الشاشة لا يُرى منها تفصيل.
        child: InteractiveViewer(
          key: const ValueKey('photo-zoom'),
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Padding(
                    padding: EdgeInsets.all(Space.xl),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, _, _) => Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text(
                tr('تعذّر تحميل الصورة. تحقّق من اتصالك.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.8,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// يفتح العارضَ إن كانت ثَمّ صورة، وإلّا مضى إلى التبديل مباشرةً.
///
/// **وقاعدةٌ واحدةٌ في موضعٍ واحد.** الغلافُ والقرصُ في أربع شاشاتٍ يسألان
/// السؤالَ نفسَه: أثَمّ صورةٌ تُعرض؟ ولو كُتب الجوابُ في كلٍّ منها لَاختلفت
/// أربعتُها بمرور الوقت.
///
/// **ومن لا صورةَ له لا يُفتح له عارض**: شاشةٌ سوداءُ فارغة لا تقول شيئاً،
/// والضغطةُ عنده تعني «أضِف» لا «انظر».
///
/// **ومن لا صورةَ له ولا تبديلَ لا يقع شيء** — وهي حالُ عميلٍ يفتح صفحةَ
/// قاعةٍ لم يرفع صاحبُها شعاراً. ولا رسالةَ خطأٍ: لم يُخطئ أحد.
Future<void> openPhoto(
  BuildContext context, {
  required String? url,
  VoidCallback? onEdit,
}) async {
  if (url == null || url.isEmpty) {
    onEdit?.call();
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PhotoViewScreen(url: url, onEdit: onEdit)),
  );
}
