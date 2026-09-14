#!/usr/bin/env bash
# ضوابطُ سالبةٌ لاستعادة كلمة المرور — الشاشةُ المستقلّة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/recover_test.dart test/auth_layout_test.dart"
R=lib/src/screens/recover_password.dart
A=lib/src/screens/auth.dart
T=lib/src/screens/root.dart

BACKUP=$(mktemp -d)
cp "$R" "$BACKUP/r"; cp "$A" "$BACKUP/a"; cp "$T" "$BACKUP/t"
restore() { cp "$BACKUP/r" "$R"; cp "$BACKUP/a" "$A"; cp "$BACKUP/t" "$T"; }
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
  # shellcheck disable=SC2086
  if timeout 400 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
# shellcheck disable=SC2086
if timeout 400 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) الضغطةُ تعود إلى ما كانت: ترسل بدل أن تفتح ────────────────────────────
#
# وهو العطبُ الذي طلب إصلاحَه بعينه.
run "(أ) «نسيت» ترسل بدل أن تفتح حقلاً" \
  sub "$A" \
"  void _openRecover() => openRecoverPassword(
    context,
    session: widget.session,
    seedEmail: _email.text.trim(),
  );" \
"  void _openRecover() {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = tr('اكتب بريدك أوّلاً.'));
      return;
    }
  }"

# ── ب) والمؤشّرُ لا يقع في الحقل ─────────────────────────────────────────────
#
# شاشةٌ فيها حقلٌ لا يُنقر إليه أوّلاً ليست أحسنَ من أمرٍ «اكتب بريدك».
run "(ب) الحقلُ يُفتح بلا مؤشّر" \
  sub "$R" \
"              autofocus: true,
              // البريد لاتينيّ: يُترك من اليسار وإلّا تبعثرت رموزه." \
"              autofocus: false,
              // البريد لاتينيّ: يُترك من اليسار وإلّا تبعثرت رموزه."

# ── ج) وما كُتب في الدخول لا يُبذَر ──────────────────────────────────────────
run "(ج) البريدُ المكتوبُ يُطلب مرّتين" \
  sub "$R" \
"  late final _email = TextEditingController(text: widget.seedEmail);" \
"  late final _email = TextEditingController();"

# ── د) والبريدُ يُعرض ولا يُرسَل ─────────────────────────────────────────────
#
# **ولا يُسأل الحقلُ عمّا فيه:** ضابطٌ يُرسل غيرَ ما كُتب يمرّ على اختبارٍ
# يقيس الحقلَ، ويسقط على اختبارٍ يقيس ما مضى به.
run "(د) يُرسَل غيرُ ما كُتب" \
  sub "$R" \
"      await widget.session.sendPasswordReset(mail);" \
"      await widget.session.sendPasswordReset('');"

# ── هـ) ويُقال إن كان البريدُ مسجّلاً ────────────────────────────────────────
#
# وهو بابٌ يعرف به الغريبُ من له حسابٌ في المنصّة ومن لا.
run "(هـ) الشاشةُ تُفصح عن المسجَّلين" \
  sub "$R" \
"        _note = trf('إن كان {0} مسجّلاً لدينا فقد وصله رمز.', [mail]);" \
"        _note = trf('البريد {0} غير مسجّل لدينا.', [mail]);"

# ── و) والجذرُ يطوي شاشةَ الاستعادة ──────────────────────────────────────────
#
# **وهذا أخطرُها.** `verifyOTP(type: recovery)` يفتح الجلسة قبل أن تُكتب
# الكلمةُ الجديدة، فطيٌّ بلا استثناءٍ يُلقي صاحبَها في التطبيق ولم يضع
# كلمتَه — ويعود عند أوّل خروجٍ إلى البابِ نفسِه، وهكذا أبداً.
run "(و) الجذرُ يطوي الاستعادةَ عند فتح الجلسة" \
  sub "$T" \
"          (route) => route.isFirst || route.settings.name == recoverRouteName," \
"          (route) => route.isFirst,"

# ── ز) والطريقُ بلا اسمٍ فلا يُعرف ───────────────────────────────────────────
#
# الاستثناءُ يقرأ الاسم، فطريقٌ بلا اسمٍ يُطوى كغيره — والكسرُ في الطرف
# الآخر من الحبل.
run "(ز) الطريقُ يُدفع بلا اسم" \
  sub "$R" \
"      settings: const RouteSettings(name: recoverRouteName)," \
"      settings: const RouteSettings(name: 'x'),"

# ── ح) ومخرجٌ في خطوة الكلمة الجديدة ─────────────────────────────────────────
run "(ح) سهمُ الرجوع يبقى فوق خطوة الكلمة" \
  sub "$R" \
"  bool get _canLeave => _step != RecoverStep.password;" \
"  bool get _canLeave => true;"

# ── ط) وزرُّ الجهاز يعمل حيث لا يعمل السهم ───────────────────────────────────
#
# سهمٌ مخفيٌّ وزرُّ جهازٍ يعمل ليس حرزاً — والخروجُ منه هو العطبُ نفسُه.
run "(ط) زرُّ الجهاز يخرج من خطوة الكلمة" \
  sub "$R" \
"      canPop: _canLeave," \
"      canPop: true,"

# ── ي) وحفظُ الكلمة يترك شاشةَ الدخول تحته ───────────────────────────────────
#
# الاستثناءُ أبقى الدخولَ تحتها، فطيُّ واحدةٍ يُنزل صاحبَها في شاشة دخولٍ
# وهو داخلٌ أصلاً.
run "(ي) الحفظُ يطوي واحدةً ويترك الدخول" \
  sub "$R" \
"      Navigator.of(context).popUntil((route) => route.isFirst);" \
"      Navigator.of(context).pop();"

# ── ك) و«بريدي خطأ» تُغلق الشاشةَ بدل الرجوع خطوة ────────────────────────────
run "(ك) «بريدي خطأ» تُغلق الشاشة كلَّها" \
  sub "$R" \
"                  : () => setState(() {
                        _step = RecoverStep.email;" \
"                  : () => setState(() {
                        _step = RecoverStep.code;"

# ── ل) والكلمةُ القصيرة تمرّ ─────────────────────────────────────────────────
run "(ل) الكلمةُ القصيرةُ تُرسَل" \
  sub "$R" \
"      await widget.session.setPassword(_newPassword.text);" \
'      await widget.session.setPassword("12345678");'

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
