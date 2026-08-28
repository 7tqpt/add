import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'kit.dart';

/// عناصر عرض الوسائط ومشغّلاها.
///
/// ومشغّلٌ واحدٌ للاثنين: `video_player` يفتح الصوت كما يفتح الصورة المتحرّكة
/// — تحته على أندرويد ExoPlayer وعلى iOS ‏AVPlayer، وكلاهما يقرأ MP3 و‏M4A.
/// وإضافةُ حزمةٍ ثانيةٍ للصوت وحده تعني شيفرةً أصليةً ثانية في التطبيق،
/// وبناءً أطول، وبابَ عطبٍ آخر عند ترقية Gradle. فالمقطع الصوتي هنا فيديو
/// بلا صورة، ونرسم له شريطاً بدل الإطار.

/// يقرأ مدّة ملفٍ قبل رفعه.
///
/// **ولماذا يُقرأ أصلاً:** `maxDuration` في منتقي الصور يقيّد الكاميرا وقت
/// التصوير ولا يقيّد ما يُختار من المعرض — فمقطعُ عشر دقائق يمرّ منه بلا
/// اعتراض. والقاعدة لا ترى الملف بل الرقم المصرَّح به. فهذه هي القراءة
/// الوحيدة التي تقع على الملف نفسه.
///
/// ويعيد صفراً إن تعذّر — والصفر يُعامَل رفضاً لا سماحاً.
Future<int> probeSeconds(Uri uri) async {
  // `networkUrl` لا `file`: الثانية تحتاج `dart:io` وهي تكسر بناء الويب.
  // والمشغّل تحته يفتح `file:` و`content:` و`blob:` كما يفتح `https:`.
  final probe = VideoPlayerController.networkUrl(uri);
  try {
    await probe.initialize();
    final ms = probe.value.duration.inMilliseconds;
    // التقريب لأعلى: مقطعٌ من ‎٤٠٠‎ جزءٍ من الثانية ليس «صفر ثانية»، والصفر
    // يرفضه قيد القاعدة.
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  } catch (_) {
    return 0;
  } finally {
    await probe.dispose();
  }
}

/// صورةٌ مصغّرة برابطها، أو مربّعٌ ساكن حين لا رابط.
///
/// و«لا رابط» حالٌ حقيقية لا فرضية: وضعُ العرض بلا Supabase لا سلّة فيه،
/// وشبكةُ المستخدم قد تسقط. وفي الحالين تُرسم أيقونةٌ لا مربّعٌ رماديّ مكسور.
class MediaThumb extends StatelessWidget {
  const MediaThumb({super.key, required this.url, this.icon = Icons.image_outlined});
  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.surface2,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.muted, size: 22),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: AppColors.surface2),
    );
  }
}

/// مشغّل الفيديو — إطارٌ يُضغط فيبدأ.
class VideoBox extends StatefulWidget {
  const VideoBox({super.key, required this.url, this.seconds = 0, this.onTap});
  final String? url;
  final int seconds;

  /// ما يقع عند الضغط — أو `null` فيُشغَّل في مكانه.
  ///
  /// **والفرقُ بين الموضعين حقيقيّ:** في صفحة الخدمة الإطارُ عريضٌ يُرى فيه
  /// العرضُ فيُشغَّل حيث هو، وفي فقاعة المحادثة عرضُه ٢٢٠ بكسلاً بين الرسائل
  /// فلا يُرى منه شيء — فيُفتح على الشاشة كلِّها.
  final VoidCallback? onTap;

  @override
  State<VideoBox> createState() => _VideoBoxState();
}

class _VideoBoxState extends State<VideoBox> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final url = widget.url;
    if (url == null) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final open = widget.onTap;
    if (open != null) {
      open();
      return;
    }
    final c = _controller;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return _Frame(
        child: Center(
          child: _failed || widget.url == null
              ? const Muted('تعذّر تشغيل المقطع')
              : const CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    return _Frame(
      ratio: c.value.aspectRatio,
      child: GestureDetector(
        onTap: _toggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
            // زرُّ التشغيل يغيب أثناء العرض ويعود عند الوقوف: لو بقي لغطّى
            // وجهَ ما يُعرض، ولو غاب دائماً لما عرف أحدٌ أن الإطار يُضغط.
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, value, _) => AnimatedOpacity(
                opacity: value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: AppColors.ink.withValues(alpha: 0.28),
                  alignment: Alignment.center,
                  child: const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 30),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: AppColors.accent,
                  bufferedColor: Colors.white.withValues(alpha: 0.45),
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.ratio = 16 / 9});
  final Widget child;
  final double ratio;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: AspectRatio(
      aspectRatio: ratio <= 0 ? 16 / 9 : ratio,
      child: Container(color: AppColors.surface2, child: child),
    ),
  );
}

/// شريط الصوت — زرٌّ ومؤشّرُ تقدّمٍ ورقمان.
///
/// وشريطٌ لا إطار: الصوت بلا صورة، وإطارٌ أسود فارغٌ بحجم الفيديو يوحي بعطب.
class AudioBar extends StatefulWidget {
  const AudioBar({super.key, required this.url, this.seconds = 0, this.label = 'مقطع صوتي'});
  final String? url;
  final int seconds;
  final String label;

  @override
  State<AudioBar> createState() => _AudioBarState();
}

class _AudioBarState extends State<AudioBar> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final url = widget.url;
    if (url == null) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: c == null
          ? Row(
              children: [
                const Icon(Icons.graphic_eq, color: AppColors.muted, size: 20),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Muted(
                    _failed || widget.url == null
                        ? 'تعذّر تشغيل المقطع'
                        : 'جارٍ تجهيز المقطع…',
                  ),
                ),
                if (widget.seconds > 0) Muted(formatSeconds(widget.seconds), size: 11),
              ],
            )
          : ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, value, _) => Row(
                children: [
                  IconButton(
                    onPressed: () => value.isPlaying ? c.pause() : c.play(),
                    tooltip: value.isPlaying ? 'إيقاف' : 'تشغيل',
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: AppColors.accent,
                      size: 34,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.ink),
                        ),
                        const SizedBox(height: Space.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: value.duration.inMilliseconds == 0
                                ? 0
                                : value.position.inMilliseconds /
                                      value.duration.inMilliseconds,
                            minHeight: 5,
                            backgroundColor: AppColors.hairline,
                            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Muted(
                    '${formatClock(value.position)} / ${formatClock(value.duration)}',
                    size: 11,
                  ),
                ],
              ),
            ),
    );
  }
}
