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
      body: Center(child: ZoomablePhoto(url: url)),
    );
  }
}

/// صورةٌ تُقرَّب بالإصبعين — **وواحدةٌ في موضعين لا نسختان**.
///
/// يستعملها العارضُ المفرد والعارضُ المقلَّب. ونسختان متطابقتان تفترقان
/// بمرور الوقت: تُصلَح رسالةُ العطب في إحداهما وتبقى الأخرى.
class ZoomablePhoto extends StatelessWidget {
  const ZoomablePhoto({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        // **وتُقرَّب بالإصبعين** — وهو معنى «ليس متحجراً»: صورةُ قاعةٍ في
        // شريطٍ عرضُه الشاشة لا يُرى منها تفصيل.
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
      );
}

/// عارضٌ يُقلَّب فيه بين صور الخدمة كلِّها ملءَ الشاشة.
///
/// ── لماذا ─────────────────────────────────────────────────────────────────
///
/// شكا صاحبُ المنصّة أنّ غلافَ صفحة الخدمة «غير قابل للضغط»، واختار (ج) من
/// ثلاثٍ: لا أن تُفتح صورةٌ واحدةٌ ويُرجَع ليُقلَّب ويُضغط من جديد، بل أن
/// **يُقلَّب داخلَ العارض** — وهو ما يفعله من يريد أن يرى ما يشتريه.
///
/// ── وثلاثةُ قراراتٍ فيه ──────────────────────────────────────────────────
///
/// **١) ويُفتح على ما كان معروضاً.** من قلّب إلى الثالثة وضغط يريد الثالثة،
/// وعارضٌ يبدأ من الأولى يُلزمه أن يقلّب مرّتين ليعود إلى حيث كان.
///
/// **٢) والعدّادُ يقول أين هو من كم.** بلا رقمٍ لا يدري أبقيت صورةٌ أم انتهت،
/// فيقلّب في فراغٍ ليتأكّد.
///
/// **٣) والتقليبُ يُعطَّل حين تُقرَّب الصورة**؟ لا: `PageView` و
/// `InteractiveViewer` يتنازعان السحبَ أفقيّاً، والمقرَّبةُ تُسحب لتُتصفَّح
/// لا لتُقلَّب. **والحلُّ أنّ التقريبَ لا يُقفل التقليب** — فمن قرّب ثمّ سحب
/// قلّب، وهو سلوكُ أكثر التطبيقات؛ ومن أراد التجوّل في المقرَّبة سحب رأسيّاً.
class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  late int _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
  late final PageController _controller = PageController(initialPage: _index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        // **والعدّادُ في العنوان لا فوق الصورة**: ما فوقها يُقرأ جزءاً منها.
        title: widget.urls.length < 2
            ? null
            : Text(
                '${_index + 1} / ${widget.urls.length}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
      body: PageView.builder(
        key: const ValueKey('photo-gallery-pages'),
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => Center(child: ZoomablePhoto(url: widget.urls[i])),
      ),
    );
  }
}

/// يفتح العارضَ المقلَّب — **ولا يُفتح على لا شيء**.
Future<void> openGallery(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) async {
  final clean = urls.where((u) => u.isNotEmpty).toList();
  if (clean.isEmpty) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PhotoGalleryScreen(urls: clean, initialIndex: initialIndex),
    ),
  );
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
