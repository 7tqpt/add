import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/media.dart';

/// وسائط الخدمة — ما يراه العميل قبل أن يدفع.
///
/// العميل يحجز قاعةً لم يرها ومطبخاً لم يذق طعامه وفرقةً لم يسمعها، وكلّ ما
/// كان أمامه سطرُ عنوانٍ وسعر. فمن يدفع عربوناً بثلاثمئة ألفٍ على وصفٍ في
/// سطرين إنما يقامر، ومن لا يقامر لا يحجز.
///
/// وثلاثةٌ لا واحد: **صورٌ** تُري المكان، و**مقطعُ دقيقة** يُري ما لا تُريه
/// صورةٌ ساكنة — القاعة وهي ممتلئة، الطبخ وهو يُقدَّم — و**مقطعٌ صوتيّ**،
/// وهذا للفنانين والفرق خاصّة: صورةُ مغنٍّ لا تقول شيئاً عن صوته، وهو كلُّ ما
/// يُشترى منه.
class ServiceMediaScreen extends StatefulWidget {
  const ServiceMediaScreen({
    super.key,
    required this.providerId,
    required this.serviceId,
    required this.serviceTitle,
  });

  final String providerId;
  final String serviceId;
  final String serviceTitle;

  @override
  State<ServiceMediaScreen> createState() => _ServiceMediaScreenState();
}

class _ServiceMediaScreenState extends State<ServiceMediaScreen> {
  late Future<List<ServiceMedia>> _future;
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _future = Api.serviceMedia(widget.serviceId);
  }

  void _reload() {
    setState(() => _future = Api.serviceMedia(widget.serviceId));
  }

  // ── الالتقاط ───────────────────────────────────────────────────────────────

  Future<ImageSource?> _askSource(String what) => showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Space.sm),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
            title: Text('التقط $what الآن'),
            onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
            title: Text('اختر من المعرض'),
            onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
          ),
          const SizedBox(height: Space.sm),
        ],
      ),
    ),
  );

  Future<void> _addImage(int taken) async {
    final source = await _askSource('صورة');
    if (source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      // القياس قبل الرفع لا بعده: صورةُ جوالٍ حديثة تقارب الاثني عشر
      // ميجابايت، وثمانٍ منها ترفع فاتورة التخزين وتُبطئ فتحَ الخدمة على
      // شبكةٍ ضعيفة — ولا تُرى منها على شاشة الجوال إلّا ما يُرى من ‎١٦٠٠‎.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return; // إلغاءٌ لا خطأ
    await _upload(file, MediaKind.image, sortOrder: taken);
  }

  Future<void> _addVideo() async {
    final source = await _askSource('مقطعاً');
    if (source == null) return;
    final file = await ImagePicker().pickVideo(
      source: source,
      // الحدُّ هنا يقيّد الكاميرا وقت التصوير، ولا يقيّد ما يُختار من
      // المعرض — فالقياس بعده لا غنى عنه.
      maxDuration: const Duration(seconds: Api.mediaMaxSeconds),
    );
    if (file == null) return;
    await _upload(file, MediaKind.video);
  }

  Future<void> _addAudio() async {
    // `file_picker` لا `image_picker`: الثاني لا يفتح الصوت أصلاً. وهذه
    // نسخته الثانية عشرة، وهي أوّل نسخةٍ تُبنى مع AGP 9 — وقد كانت الحادية
    // عشرة سببَ العدول عنها في شاشة المستندات.
    final picked = await FilePicker.pickFile(
      type: FileType.audio,
      dialogTitle: 'اختر مقطعاً صوتياً',
    );
    if (picked == null) return;
    await _upload(picked.xFile, MediaKind.audio, uri: picked.uri);
  }

  // ── الرفع ──────────────────────────────────────────────────────────────────

  Future<void> _upload(XFile file, MediaKind kind, {Uri? uri, int sortOrder = 0}) async {
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > Api.mediaMaxBytes) {
        throw _Rejected(
          'الملف ${formatBytes(bytes.length)} والحدّ ${formatBytes(Api.mediaMaxBytes)}. '
          'صوّر بجودةٍ أقلّ أو اقصص المقطع.',
        );
      }

      var seconds = 0;
      if (kind != MediaKind.image) {
        seconds = await probeSeconds(uri ?? _uriOf(file));
        if (seconds <= 0) {
          throw const _Rejected('تعذّرت قراءة مدّة الملف. جرّب ملفاً آخر بصيغة MP4 أو M4A.');
        }
        if (seconds > Api.mediaMaxSeconds) {
          throw _Rejected(
            'المقطع ${formatSeconds(seconds)} والحدّ ${formatSeconds(Api.mediaMaxSeconds)}. '
            'اقصصه ثم أعد الرفع.',
          );
        }
      }

      await Api.uploadServiceMedia(
        providerId: widget.providerId,
        serviceId: widget.serviceId,
        kind: kind,
        fileName: file.name,
        bytes: bytes,
        durationSeconds: seconds,
        sortOrder: sortOrder,
      );
      if (!mounted) return;
      showMessage(context, 'تمّ الرفع');
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _note = e is _Rejected ? e.message : messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// مسار الملف بصيغةٍ يفتحها المشغّل على الجهاز وعلى الويب.
  ///
  /// ولا `dart:io` هنا: استيرادها يكسر بناء الويب كلَّه، والتطبيق يُبنى له.
  /// فعلى الويب المسار رابط `blob:` يُؤخذ كما هو، وعلى الجهاز مسارٌ يُلفّ في
  /// `file:`.
  static Uri _uriOf(XFile file) => kIsWeb ? Uri.parse(file.path) : Uri.file(file.path);

  // ── الحذف ──────────────────────────────────────────────────────────────────

  Future<void> _delete(ServiceMedia media) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('حذف الوسيط؟'),
        content: const Text('يُحذف من الخدمة ومن التخزين، ولا يُسترجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('احذف'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    setState(() => _busy = true);
    try {
      await Api.deleteServiceMedia(media);
      if (!mounted) return;
      showMessage(context, 'حُذف');
      _reload();
    } catch (e) {
      if (mounted) setState(() => _note = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('صور الخدمة ومقاطعها')),
      body: FutureBuilder<List<ServiceMedia>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final all = snap.data ?? const <ServiceMedia>[];
          final images = all.where((m) => m.kind == MediaKind.image).toList();
          final video = all.where((m) => m.kind == MediaKind.video).firstOrNull;
          final audio = all.where((m) => m.kind == MediaKind.audio).firstOrNull;

          return ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              Muted(widget.serviceTitle),
              const SizedBox(height: Space.md),
              if (_note != null) ...[
                _Note(_note!),
                const SizedBox(height: Space.md),
              ],
              _ImagesCard(
                images: images,
                busy: _busy,
                onAdd: () => _addImage(images.length),
                onDelete: _delete,
              ),
              const SizedBox(height: Space.md),
              _ClipCard(
                kind: MediaKind.video,
                media: video,
                busy: _busy,
                onAdd: _addVideo,
                onDelete: _delete,
              ),
              const SizedBox(height: Space.md),
              _ClipCard(
                kind: MediaKind.audio,
                media: audio,
                busy: _busy,
                onAdd: _addAudio,
                onDelete: _delete,
              ),
              const SizedBox(height: Space.lg),
            ],
          );
        },
      ),
    );
  }
}

/// رفضٌ من التطبيق لا من الخادم — رسالته للمستخدم كما هي.
class _Rejected implements Exception {
  const _Rejected(this.message);
  final String message;
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.md),
    decoration: BoxDecoration(
      color: AppColors.critical.withValues(alpha: 0.07),
      border: Border.all(color: AppColors.critical.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.critical, height: 1.6, fontSize: 13),
    ),
  );
}

// ── الصور ────────────────────────────────────────────────────────────────────
class _ImagesCard extends StatelessWidget {
  const _ImagesCard({
    required this.images,
    required this.busy,
    required this.onAdd,
    required this.onDelete,
  });

  final List<ServiceMedia> images;
  final bool busy;
  final VoidCallback onAdd;
  final void Function(ServiceMedia) onDelete;

  @override
  Widget build(BuildContext context) {
    final full = images.length >= Api.mediaMaxImages;
    return AppCard(
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('الصور')),
            Muted('${images.length}/${Api.mediaMaxImages}'),
          ],
        ),
        const SizedBox(height: Space.xs),
        // الترتيب ليس تفصيلاً: الأولى هي التي تظهر في بطاقة الاستكشاف، وهي
        // كلُّ ما يراه من لم يفتح الخدمة بعد.
        const Muted('الأولى غلافُ الخدمة في قائمة الاستكشاف.'),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final m in images)
              _Thumb(media: m, onDelete: busy ? null : () => onDelete(m)),
            if (!full)
              _AddTile(
                icon: Icons.add_a_photo_outlined,
                label: 'أضف صورة',
                onTap: busy ? null : onAdd,
              ),
          ],
        ),
        if (full) ...[
          const SizedBox(height: Space.sm),
          const Muted('بلغتَ الحدّ. احذف صورةً لتضيف غيرها.'),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.media, required this.onDelete});
  final ServiceMedia media;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final url = Api.mediaUrl(media.path);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MediaThumb(url: url),
            ),
          ),
          // زرُّ الحذف على الصورة بأرضيةٍ داكنة: أيقونةٌ بيضاء على صورةٍ
          // فاتحة لا تُرى، والصورة ليست تحت سيطرتنا.
          Positioned(
            top: 2,
            left: 2,
            child: Material(
              color: AppColors.ink.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: onTap == null ? AppColors.muted : AppColors.accent, size: 22),
          const SizedBox(height: Space.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.ink2),
          ),
        ],
      ),
    ),
  );
}

// ── المقطعان ─────────────────────────────────────────────────────────────────
class _ClipCard extends StatelessWidget {
  const _ClipCard({
    required this.kind,
    required this.media,
    required this.busy,
    required this.onAdd,
    required this.onDelete,
  });

  final MediaKind kind;
  final ServiceMedia? media;
  final bool busy;
  final VoidCallback onAdd;
  final void Function(ServiceMedia) onDelete;

  bool get _video => kind == MediaKind.video;

  @override
  Widget build(BuildContext context) {
    final m = media;
    return AppCard(
      children: [
        SectionTitle(_video ? 'مقطع فيديو' : 'مقطع صوتي'),
        const SizedBox(height: Space.xs),
        Muted(
          _video
              ? 'دقيقةٌ على الأكثر. أرِ ما لا تُريه صورة: القاعة وهي ممتلئة، أو الطبخ وهو يُقدَّم.'
              : 'دقيقةٌ على الأكثر. للفنانين والفرق: صورتُك لا تقول شيئاً عن صوتك.',
        ),
        const SizedBox(height: Space.md),
        if (m == null)
          OutlinedButton.icon(
            onPressed: busy ? null : onAdd,
            icon: Icon(_video ? Icons.videocam_outlined : Icons.mic_none, size: 20),
            label: Text(_video ? 'أضف مقطع فيديو' : 'أضف مقطعاً صوتياً'),
          )
        else
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _video ? Icons.movie_outlined : Icons.graphic_eq,
                  color: AppColors.accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatSeconds(m.durationSeconds),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Muted(formatBytes(m.sizeBytes), size: 11),
                  ],
                ),
              ),
              IconButton(
                onPressed: busy ? null : () => onDelete(m),
                tooltip: 'احذف',
                icon: const Icon(Icons.delete_outline, color: AppColors.critical, size: 20),
              ),
            ],
          ),
      ],
    );
  }
}
