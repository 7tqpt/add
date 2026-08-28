// عارضُ المرفقات: يُفتح المرفقُ **داخل التطبيق** لا خارجه.
//
// **وما كان يقع قبل هذا:** الصورةُ تصل فتُعرض في فقاعةٍ بعرض ٢٢٠ بكسل ولا
// تُفتح بضغطها — فمن أُرسلت إليه صورةُ العقد لا يقرأ سطراً منه. والمقطعُ
// يُشغَّل في الفقاعة نفسها بحجمها. وملفُّ PDF كان يُسلَّم إلى `launchUrl`
// بـ`externalApplication`، وأندرويد لا يعرض PDF بنفسه — فيُنزّله إلى مجلّد
// التنزيلات ويترك صاحبَه يبحث عنه هناك، إن كان في جهازه قارئٌ أصلاً.
//
// فصار الثلاثةُ تُفتح بضغطةٍ في شاشةٍ سوداء: الصورةُ تُكبَّر بالإصبعين،
// والمقطعُ يملأ الشاشة، والملفُّ يُقرأ صفحةً صفحة.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';

import '../core/theme.dart';

/// شاشةُ عرضٍ سوداء لها زرُّ إغلاقٍ وعنوان.
///
/// **والأسودُ لا لونُ التطبيق:** ما يُعرض هنا صورةٌ أو مقطعٌ أو ورقة، وأيُّ
/// لونٍ حولها يغيّر ما تُرى عليه. وهو عرفُ كلّ عارضٍ يعرفه الناس.
class _ViewerShell extends StatelessWidget {
  const _ViewerShell({required this.title, required this.child, this.actions});

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
        actions: actions,
      ),
      body: child,
    );
  }
}

Widget _viewerError(String message) => Center(
  child: Padding(
    padding: const EdgeInsets.all(Space.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.white54, size: 40),
        const SizedBox(height: Space.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.7),
        ),
      ],
    ),
  ),
);

const _spinner = Center(
  child: CircularProgressIndicator(color: Colors.white70),
);

// ============================================================================
//  الصورة
// ============================================================================

Future<void> openImageViewer(
  BuildContext context, {
  required String url,
  String title = 'صورة',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _ImageViewer(url: url, title: title),
    ),
  );
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _ViewerShell(
      title: title,
      // **تُكبَّر بالإصبعين حتى أربعة أضعاف.** ومن أُرسل إليه عقدٌ مصوَّرٌ
      // بخطٍّ صغير يقرؤه هنا أو لا يقرؤه أبداً.
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _viewerError('تعذّر تحميل الصورة.'),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _spinner,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  المقطع
// ============================================================================

Future<void> openVideoViewer(BuildContext context, {required String url}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => _VideoViewer(url: url)),
  );
}

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.url});
  final String url;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      // **يبدأ التشغيلُ من نفسه.** من ضغط المقطع في الدردشة قد ضغط ليشاهد،
      // فزرُّ تشغيلٍ ثانٍ في شاشةٍ فُتحت لأجله خطوةٌ زائدة.
      await c.play();
      setState(() => _c = c);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return _ViewerShell(
      title: 'مقطع',
      child: c == null
          ? (_failed ? _viewerError('تعذّر تشغيل المقطع.') : _spinner)
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => c.value.isPlaying ? c.pause() : c.play()),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPlayer(c),
                            ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: c,
                              builder: (context, value, _) => AnimatedOpacity(
                                opacity: value.isPlaying ? 0 : 1,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  color: Colors.black26,
                                  alignment: Alignment.center,
                                  child: const CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.white,
                                    child: Icon(Icons.play_arrow_rounded,
                                        color: AppColors.accent, size: 34),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg, vertical: Space.lg),
                  colors: VideoProgressColors(
                    playedColor: AppColors.accent,
                    bufferedColor: Colors.white.withValues(alpha: 0.45),
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================================
//  الملفّ (PDF)
// ============================================================================

Future<void> openPdfViewer(
  BuildContext context, {
  required String url,
  String name = 'ملف',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => _PdfViewer(url: url, name: name)),
  );
}

class _PdfViewer extends StatefulWidget {
  const _PdfViewer({required this.url, required this.name});
  final String url;
  final String name;

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  PdfControllerPinch? _controller;
  String? _error;
  int _pages = 0;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// يجلب البايتات ثمّ يفتحها من الذاكرة.
  ///
  /// **ولا ملفَّ على القرص.** `pdfx` تفتح من البايتات مباشرةً، وكتابةُ نسخةٍ
  /// في مجلّد التطبيق تترك عقودَ الناس ومستنداتِهم على الجهاز بعد إغلاق
  /// الشاشة — ولا أحدَ ينظّفها.
  ///
  /// والرابطُ موقَّعٌ بساعة، فيُجلب هنا لا يُخزَّن.
  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode != 200) {
        throw 'تعذّر تحميل الملف (${res.statusCode}).';
      }
      final bytes = Uint8List.fromList(res.bodyBytes);
      final controller = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is String ? e : 'تعذّر فتح الملف.');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return _ViewerShell(
      title: widget.name,
      actions: [
        if (controller != null && _pages > 1)
          Padding(
            padding: const EdgeInsets.only(left: Space.lg),
            child: Center(
              child: Text(
                // «٣ من ١٢» — ومن فتح ملفاً من اثنتي عشرة صفحةً يريد أن يعرف
                // أين هو منه.
                '$_page من $_pages',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
      ],
      child: _error != null
          ? _viewerError(_error!)
          : controller == null
              ? _spinner
              : PdfViewPinch(
                  controller: controller,
                  onDocumentLoaded: (doc) =>
                      setState(() => _pages = doc.pagesCount),
                  onPageChanged: (page) => setState(() => _page = page),
                ),
    );
  }
}
