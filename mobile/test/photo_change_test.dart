// **الصورةُ تتبدّل فعلاً — «حُفظت» و«تغيّرت» شيءٌ واحد.**
//
// ── العطلُ الذي أوجب هذا الملفّ ─────────────────────────────────────────────
//
// أخرج صاحبُ المنصّة عيباً: «لا يمكن تغيير الصورة، يقول تم حفظ ولا يتغيّر
// شيء». **والحفظُ كان يقع فعلاً** — تُرفع الصورةُ ويُحدَّث الملفّ. والذي لم
// يكن يقع هو **العرض**:
//
//   ١) كلُّ رفعةٍ باسمٍ ثابت `<معرّف>/avatar.jpg` تُكتب فوق سابقتها. فالبايتات
//      تتبدّل **والعنوانُ لا يتبدّل** — والقديمةُ محفوظةٌ بذلك العنوان في
//      ذاكرة التطبيق وفي مخبأ Supabase.
//
//   ٢) وكان الكسرُ بـ`?v=` من **عدّادٍ في الذاكرة يبدأ من صفرٍ في كلّ
//      تشغيل** — فما إن يُغلق التطبيقُ حتى يعود `?v=0`، وهو العنوانُ الذي
//      حُفظت تحته القديمة.
//
//   ٣) **وستّةُ مواضعَ لم تكن تمرّر العدّادَ أصلاً** — فكانت تعرض القديمةَ
//      أبداً.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **لا نجاحُ الرفع — بل تبدُّلُ العنوان.** سؤالُ «أرُفعت الصورة؟» كان يمرّ
// على العطل كلِّه: كانت تُرفع.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/data/api.dart';

void main() {
  group('**ولكلّ رفعةٍ مسارٌ جديد**', () {
    test('رفعتان للصورة نفسِها لا تتقاسمان عنواناً', () async {
      // **وهذا لبُّ الإصلاح.** لو تساوى المساران لَعرض المخبأُ القديمةَ
      // مهما حُفظ في القاعدة.
      final first = await Api.uploadAvatar(
        authUserId: 'u1',
        fileName: 'photo.jpg',
        bytes: Uint8List.fromList(const [1, 2, 3]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await Api.uploadAvatar(
        authUserId: 'u1',
        fileName: 'photo.jpg',
        bytes: Uint8List.fromList(const [4, 5, 6]),
      );

      expect(first, isNot(second),
          reason: 'مسارٌ واحدٌ لرفعتين — يعود المخبأُ يعرض القديمة');
    });

    test('**والغلافُ كذلك**', () async {
      final first = await Api.uploadCover(
        authUserId: 'u1',
        fileName: 'c.jpg',
        bytes: Uint8List.fromList(const [1]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await Api.uploadCover(
        authUserId: 'u1',
        fileName: 'c.jpg',
        bytes: Uint8List.fromList(const [2]),
      );

      expect(first, isNot(second));
    });

    test('**ويبقى المسارُ في مجلّد صاحبه**', () async {
      // سياسةُ السلّة تحصر الكتابة في `<auth_user_id>/…`. ومسارٌ يخرج منه
      // يُردّ من الخادم — فيُقال «تعذّر» على عملٍ سليم.
      final path = await Api.uploadAvatar(
        authUserId: 'u1',
        fileName: 'photo.png',
        bytes: Uint8List.fromList(const [1]),
      );
      expect(path.startsWith('u1/'), isTrue, reason: 'خرج المسارُ من مجلّد صاحبه');
      expect(path.endsWith('.png'), isTrue, reason: 'ضاع امتدادُ الملفّ');
    });

    test('**ولا يختلط غلافٌ بصورة**', () async {
      // اسمان في مجلّدٍ واحد: لو تشابها لَمحا أحدُهما الآخر.
      final avatar = await Api.uploadAvatar(
        authUserId: 'u1', fileName: 'a.jpg', bytes: Uint8List.fromList(const [1]));
      final cover = await Api.uploadCover(
        authUserId: 'u1', fileName: 'a.jpg', bytes: Uint8List.fromList(const [1]));

      expect(avatar.contains('/avatar-'), isTrue);
      expect(cover.contains('/cover-'), isTrue);
    });
  });
}
