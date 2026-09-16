#!/usr/bin/env bash
# ضوابطُ سالبةٌ لرأس «حسابي» وصورِ الملفّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (أ): يعود للصورة اسمٌ ثابت.** وهو العطلُ الذي أخرجه
# صاحبُ المنصّة: «يقول تم حفظ ولا يتغيّر شيء». والحفظُ كان يقع — والعنوانُ
# لا يتبدّل، فيعرض المخبأُ القديمةَ أبداً.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

# **وأربعُ حزمٍ لا واحدة.** ضماناتُ هذا موزّعة: المسارُ في `photo_change`،
# والرأسُ في `account`، والغلافُ في `profile_cover`، والملفُّ في
# `edit_profile`، ونصُّ زرّ الورقة في `edit_profile_guard`. وضابطٌ يشغّل
# إحداها يمرّ على ما تحرسه الأخرى — **وقد وقع**: كُسر نصُّ الزرّ فبقيت
# الحزمةُ خضراءَ حتى أُضيف قياسُه.
SUITE="test/photo_change_test.dart test/account_test.dart \
test/profile_cover_test.dart test/edit_profile_test.dart \
test/edit_profile_guard_test.dart"

A=lib/src/data/api.dart
K=lib/src/ui/kit.dart
C=lib/src/screens/account.dart
E=lib/src/screens/edit_profile.dart
V=lib/src/screens/verify_phone.dart

FILES=("$A" "$K" "$C" "$E" "$V")
BACKUP=$(mktemp -d)
for i in "${!FILES[@]}"; do cp "${FILES[$i]}" "$BACKUP/$i"; done
restore() { for i in "${!FILES[@]}"; do cp "$BACKUP/$i" "${FILES[$i]}"; done; }
trap 'restore; rm -rf "$BACKUP"' EXIT
PASS=0; FAIL=0

sub() {
  local file="$1" old="$2" new="$3" n
  n=$(python3 - "$file" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1; fi
  python3 - "$file" "$old" "$new" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
}

run() {
  local name="$1"; shift
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  if timeout 600 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) يعود الاسمُ ثابتاً ───────────────────────────────────────────────────
#
# **وهذا أخطرُها** — وهو العطلُ بعينه. **ولا يسقط بسؤال «أرُفعت الصورة؟»**
# فقد كانت تُرفع. يسقط لأنّ المسارين يتساويان.
run "(أ) اسمٌ ثابتٌ لكلّ رفعة" \
  sub "$A" \
"    final path = '\$authUserId/\$kind-\$stamp.\$ext';" \
"    final path = '\$authUserId/\$kind.\$ext';"

# ── ب) والغلافُ يتقاسم اسمَ الصورة ──────────────────────────────────────────
#
# اسمان في مجلّدٍ واحد: لو تشابها لَمحا أحدُهما الآخر — فيضيع الغلافُ عند
# تبديل الصورة.
run "(ب) الغلافُ والصورةُ باسمٍ واحد" \
  sub "$A" \
"      _uploadImage(authUserId: authUserId, kind: 'cover', fileName: fileName," \
"      _uploadImage(authUserId: authUserId, kind: 'avatar', fileName: fileName,"

# ── ج) والمسارُ يخرج من مجلّد صاحبه ─────────────────────────────────────────
#
# سياسةُ السلّة تحصر الكتابة في `<auth_user_id>/…` — ومسارٌ خارجه يُردّ من
# الخادم، فيُقال «تعذّر» على عملٍ سليم.
run "(ج) المسارُ خارج مجلّد صاحبه" \
  sub "$A" \
"    final path = '\$authUserId/\$kind-\$stamp.\$ext';" \
"    final path = '\$kind-\$stamp.\$ext';"

# ── د) والشارةُ تعود تحت الاسم ──────────────────────────────────────────────
#
# **ولا يسقط هذا بسؤال «أموجودةٌ الشارة؟»** — موجودةٌ في الحالين. يسقط لأنّ
# الموضعَ يُقاس: أعلاهما واحدٌ في صفٍّ واحد.
run "(د) الشارةُ تحت الاسم لا يساره" \
  sub "$C" \
"          badgeBesideTitle: true," \
"          badgeBesideTitle: false,"

# ── هـ) ورقمُ الجوال يعود إلى الرأس ─────────────────────────────────────────
run "(هـ) الجوالُ يعود تحت الاسم" \
  sub "$C" \
"          subtitle: ''," \
"          subtitle: profile?.phone.trim() ?? '',"

# ── و) والغلافُ لا يُضغط ────────────────────────────────────────────────────
#
# **وهو ما حلَّ محلَّ الحبّة المرفوعة.** بلا ضغطةٍ لا يبقى للغلاف بابٌ
# أصلاً — لا حبّةَ ولا لمسة.
run "(و) الغلافُ لا يُضغط" \
  sub "$K" \
"                onTap: busy ? null : onView," \
"                onTap: null,"

# ── ملاحظةٌ: «لا يُضغط والرفعُ جارٍ» لها حارسٌ واحدٌ حقيقيّ ─────────────────
#
# جرّبتُ كسرَ `busy ? null : onView` وحدَه **فبقيت الحزمةُ خضراء**. وليس ذلك
# نقصاً في القياس: الدوّارةُ تُرسم فوق الشريط فتبتلع اللمسةَ سواءٌ كُسر
# الشرطُ أو لم يُكسر. فالحارسُ الحقيقيُّ هو الطبقةُ نفسُها — ويُسقطها
# الضابطُ (ح). والشرطُ بجانبها حرزٌ ثانٍ لا يُقاس وحدَه، ويُقال ذلك ولا
# يُدّعى له ضابط.

# ── ح) والدوّارةُ تُشال فيصير الرفعُ صامتاً ─────────────────────────────────
#
# **حبّةٌ ذهبت ودوّارةٌ بقيت.** رفعٌ صامتٌ يُقرأ تعطّلاً.
run "(ح) لا دوّارةَ أثناء الرفع" \
  sub "$K" \
"          if (busy)
            const Positioned.fill(" \
"          if (false)
            const Positioned.fill("

# ── ط) وتعود حبّةُ «تغيير الغلاف» ───────────────────────────────────────────
run "(ط) تعود الحبّةُ المكتوبة" \
  sub "$K" \
"          if (busy)
            const Positioned.fill(
              child: ColoredBox(" \
"          PositionedDirectional(
            bottom: 10,
            end: Space.lg,
            child: Text(tr('تغيير الغلاف')),
          ),
          if (busy)
            const Positioned.fill(
              child: ColoredBox("

# ── ي) والقرصُ يعود يُبدَّل من «الملف الشخصي» ───────────────────────────────
#
# موضعان لفعلٍ واحدٍ يفترقان: أحدُهما يرفع فوراً والآخرُ يؤجّل إلى «حفظ».
run "(ي) يعود زرُّ الكاميرا إلى الملفّ" \
  sub "$E" \
"                _ProfileArt(profile: _profile!)," \
"                Column(children: [
                  const Icon(Icons.photo_camera),
                  _ProfileArt(profile: _profile!),
                ]),"

# ── ك) والغلافُ يخرج من «الملف الشخصي» ──────────────────────────────────────
run "(ك) لا غلافَ في الملفّ الشخصيّ" \
  sub "$E" \
"                _ProfileArt(profile: _profile!)," \
"                const SizedBox.shrink(),"

# ── ل) وزرُّ ورقة الرقم يعود «حفظ» ──────────────────────────────────────────
run "(ل) الزرُّ يعود «حفظ»" \
  sub "$V" \
"            : Text(tr('تعديل'))," \
"            : Text(tr('حفظ')),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
