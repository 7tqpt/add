import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';

/// مرفقٌ اختاره المستخدم، جاهزٌ للرفع.
class PickedAttachment {
  const PickedAttachment({
    required this.kind,
    required this.bytes,
    required this.extension,
    required this.contentType,
    this.seconds = 0,
    this.name = '',
  });

  final ChatAttachment kind;
  final Uint8List bytes;
  final String extension;
  final String contentType;
  final int seconds;
  final String name;
}

/// ما تحتاجه الشاشة لاختيار مرفق — لا أكثر.
///
/// **وواجهةٌ لا نداءٌ مباشر لأن الكاميرا ومنتقي الملفّات لا يوجدان في
/// الاختبار.** شاشةٌ تناديهما رأساً لا تُختبر إلا على جهاز، فيبقى ما يقع بعد
/// الاختيار — الرفع، والفشل، وشكلُ الفقاعة — بلا حارس.
abstract class AttachmentPicker {
  /// صورةٌ من المعرض أو الكاميرا.
  Future<PickedAttachment?> image({required bool camera});

  /// مقطعُ فيديو — **من الكاميرا وحدها**.
  ///
  /// **ولا اختيارَ من المعرض، وهذا تضييقٌ أُعلنه:** `maxDuration` تقيّد
  /// الكاميرا وقت التصوير ولا تقيّد ما يُختار من المعرض — وهو ما وقع في
  /// وسائط الخدمة من قبل، فمرّ مقطعُ عشر دقائق. ومدّةُ مقطعٍ جاهزٍ لا تُعرف
  /// إلا بفتحه في مشغّل، فالحدُّ عليه لا يُفرض إلا بحدّ الحجم وحده.
  Future<PickedAttachment?> video();

  /// ملفّ PDF.
  Future<PickedAttachment?> document();
}

/// الحدُّ الذي تفرضه القاعدة على الفيديو (`message_attachment_seconds`).
///
/// ويُقيَّد **وقت التصوير** لا بعده: من صوّر ثلاث دقائق ثم قيل له «طويل»
/// خسر ما صوّره.
const chatVideoMaxSeconds = 60;

class DeviceAttachmentPicker implements AttachmentPicker {
  const DeviceAttachmentPicker();

  @override
  Future<PickedAttachment?> image({required bool camera}) async {
    final picked = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      // ضغطٌ عند الالتقاط: صورةُ كاميرا الجوال بدقّتها الكاملة تُقارب عشرة
      // ميجابايت، ويُنزّلها الطرف الآخر كاملةً على شبكةٍ يمنية ليرى كوشة.
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked == null) return null;
    return PickedAttachment(
      kind: ChatAttachment.image,
      bytes: await picked.readAsBytes(),
      extension: 'jpg',
      contentType: 'image/jpeg',
      name: picked.name,
    );
  }

  @override
  Future<PickedAttachment?> video() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: chatVideoMaxSeconds),
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    return PickedAttachment(
      kind: ChatAttachment.video,
      bytes: bytes,
      extension: 'mp4',
      contentType: 'video/mp4',
      // **والمدّةُ تُترك فارغة عمداً:** لا تُعرف إلا بفتح المقطع في مشغّل،
      // وخزنُ رقمٍ لم يُقَس أسوأ من تركه فارغاً — المشغّل يقولها حين يُفتح،
      // والرقم الكاذب يبقى. والقاعدة تقبل غيابها للفيديو وحده.
      name: picked.name,
    );
  }

  @override
  Future<PickedAttachment?> document() async {
    // `pickFile` لا `pickFiles`: ملفٌّ واحدٌ في الرسالة، والثانية مهجورةٌ
    // لاختيارٍ مفرد في هذه النسخة.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      dialogTitle: 'اختر ملفاً',
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;
    return PickedAttachment(
      kind: ChatAttachment.file,
      bytes: bytes,
      extension: 'pdf',
      contentType: 'application/pdf',
      name: picked.name,
    );
  }
}
