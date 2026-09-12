#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحاجز تحقّق الرقم.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/verify_phone_test.dart
R=lib/src/screens/root.dart
V=lib/src/screens/verify_phone.dart
S=lib/src/core/session.dart
M=lib/src/data/models.dart

# **وكلُّ ملفٍّ يُكسَر يُنسَخ.** ضابطٌ سابقٌ كسر ملفّاً خارج قائمة النسخ
# فبقي الكسرُ في الشجرة بعد انتهاء السير — عيبٌ في أداة القياس لا في المقيس.
BACKUP=$(mktemp -d)
cp "$R" "$BACKUP/r"; cp "$V" "$BACKUP/v"; cp "$S" "$BACKUP/s"; cp "$M" "$BACKUP/m"
restore() {
  cp "$BACKUP/r" "$R"; cp "$BACKUP/v" "$V"; cp "$BACKUP/s" "$S"; cp "$BACKUP/m" "$M"
}
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
  if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# أ) الحاجزُ يُشال من بوّابة الإقلاع — وهي الضمانةُ التي طلبها صاحبُ المنصّة
#    بعينها: من لم يؤكّد رقمه لا يرى التطبيق.
run "أ) لا حاجزَ في البوّابة" sub "$R" \
  "        if (session.needsPhoneVerification) {
          return VerifyPhoneScreen(session: session);
        }" \
  ""

# ب) وحاسبُ الجلسة يُسقط شرطَ «بعد الملفّ».
#
#    **ولم يسقط هذا الضابطُ أوّلَ مرّة:** ترتيبُ `root.dart` يُعيد الملفَّ
#    قبل الحاجز، فيحمي الحالةَ ولو كُسر الحاسب. فأُضيف اختبارٌ يسأل الحاسبَ
#    نفسَه — والضمانةُ مكتوبةٌ في موضعين فتُقاس في موضعين.
run "ب) الحاسبُ يُسقط شرطَ الملفّ" sub "$S" \
  "      signedIn && !needsProfile && phoneGate.blocks;" \
  "      signedIn && phoneGate.blocks;"

# ب٢) والترتيبُ في البوّابة يُقلَب فيسبق الحاجزُ الملفَّ — فيُسأل من لم
#     يكتب رقمَه بعدُ عن تأكيد رقمٍ لا وجود له.
run "ب٢) الحاجزُ قبل الملفّ في البوّابة" sub "$R" \
  "        if (session.needsProfile) return OnboardingScreen(session: session);" \
  "        if (session.phoneGate.blocks) {
          return VerifyPhoneScreen(session: session);
        }
        if (session.needsProfile) return OnboardingScreen(session: session);"

# ج) ويحجز من أكّد رقمه — فلا يدخل أحدٌ أبداً ولو أكّد.
run "ج) يحجز من أكّد" sub "$M" \
  "  bool get blocks => required_ && !verified;" \
  "  bool get blocks => required_;"

# د) ويحجز والمفتاحُ مطفأ — فيقف الناسُ كلُّهم على شاشةٍ لم تُشغَّل بعد.
run "د) يحجز والمفتاحُ مطفأ" sub "$M" \
  "  bool get blocks => required_ && !verified;" \
  "  bool get blocks => !verified;"

# هـ) وتُرسَل رسالةٌ عند الفتح بلا ضغطة — مالٌ يُنفَق على كلّ من فتح
#     التطبيقَ وأغلقه، والحاجزُ يقف في كلّ فتحةٍ حتى يؤكّد.
run "هـ) إرسالٌ تلقائيٌّ عند الفتح" sub "$V" \
  "  @override
  void dispose() {
    _tick?.cancel();" \
  "  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _tick?.cancel();"

# و) و«أعد الإرسال» يُتاح بلا مهلة — فتُستنزف رسائلُ الرصيد بضغطاتٍ متتابعة.
run "و) إعادةُ إرسالٍ بلا مهلة" sub "$V" \
  "                  onPressed: _busy || _wait > 0 ? null : _send," \
  "                  onPressed: _busy ? null : _send,"

# ز) ورمزٌ خاطئٌ يُقبل — وهو أخطرُ ما يُكسَر: الحاجزُ كلُّه يصير زينةً.
run "ز) رمزٌ خاطئٌ يُقبل" sub "$V" \
  "      if (!ok) {
        setState(() => _error = tr('الرمزُ غير صحيح أو انتهت مدّته.'));
        return;
      }" \
  ""

# ح) ويُشال المخرجُ لمن كتب رقمه خطأً — فيُحبس على شاشةٍ تنتظر رمزاً لا
#    يأتي أبداً إلى رقمٍ ليس له، و«حسابي» خلف الحاجز.
run "ح) لا مخرجَ لمن أخطأ رقمَه" sub "$V" \
  "          TextButton(
            key: const ValueKey('otp-edit-phone')," \
  "          if (false) TextButton(
            key: const ValueKey('otp-edit-phone'),"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
