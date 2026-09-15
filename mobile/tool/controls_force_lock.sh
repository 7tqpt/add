#!/usr/bin/env bash
# ضوابطُ سالبةٌ لإجبار قفل التطبيق.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (أ): البابُ يُشال فيدخل من لا قفلَ له.** وهو لبُّ
# الطلب كلِّه: سطرٌ واحدٌ يُشال فيصير كلُّ ما بُني — الشاشةُ ونصُّها
# وتبديلُ الرمز — زينةً فوق بابٍ مفتوح.
#
# **وحزمتان لا واحدة.** ضماناتُ هذا موزّعةٌ: البابُ وتبديلُ الرمز في
# `force_lock_test.dart`، والقفلُ نفسُه في `biometric_test.dart` — وضابطٌ
# يشغّل إحداهما يمرّ على ما تحرسه الأخرى.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/force_lock_test.dart test/biometric_test.dart"
R=lib/src/screens/root.dart
L=lib/src/screens/lock.dart
A=lib/src/screens/account_extras.dart
K=lib/src/core/app_lock.dart

# **وكلُّ ملفٍّ يُكسر يُنسَخ — وإلّا بقي مكسوراً في الشجرة.**
#
# كسرتُ `app_lock.dart` في ضابطين ونسيتُ إدراجَه هنا، فلم يُستعَد: بقيت
# `verify` تمرّ على `unlock` و`notifyListeners` محذوفةً في شيفرة المصدر،
# وسقطت اختباراتٌ بعدها فظننتُ العطلَ فيها. **وسكربتُ ضوابطَ يترك أثراً
# أخطرُ من ضمانةٍ لا تُقاس.**
FILES=("$R" "$L" "$A" "$K")
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
  if timeout 400 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 400 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) البابُ يُشال ─────────────────────────────────────────────────────────
#
# **وهذا أخطرُها** — وشرحُه في رأس الملفّ.
#
# **ولم يسقط أوّلَ مرّة** — وكان ذلك نقصاً في القياس لا في الشيفرة: كلُّ
# اختباراتي كانت تبني `LockGateScreen` مباشرةً، فشُلَّ الشرطُ من `root.dart`
# وبقيت الحزمةُ خضراء. **وحارسٌ لا يمرّ من الطريق الذي يحرسه لا يحرس.**
# فأُضيفت ثلاثةُ اختباراتٍ تمرّ من `RootScreen` كما يمرّ المستخدم.
run "(أ) لا بابَ في الجذر" \
  sub "$R" \
"          if (!lock.enabled) {" \
"          if (false) {"

# ── ب) وزرُّ «لاحقاً» يعود ──────────────────────────────────────────────────
#
# **وهو الفرقُ بين الإجبار والتشجيع.** بابٌ يُتخطّى ليس باباً.
run "(ب) بابٌ يُتخطّى" \
  sub "$L" \
"                    TextButton(
                      key: const ValueKey('gate-sign-out')," \
"                    TextButton(
                      onPressed: () {},
                      child: Text(tr('لاحقاً')),
                    ),
                    TextButton(
                      key: const ValueKey('gate-sign-out'),"

# ── ج) والمخرجُ يُشال فيصير التطبيقُ سجناً ─────────────────────────────────
#
# من لم يُرد قفلاً يُترك في شاشةٍ بلا باب — وهو أذىً لا حماية.
run "(ج) لا مخرجَ لمن لم يُرد قفلاً" \
  sub "$L" \
"                      onPressed: _busy ? null : () => widget.onSignOut()," \
"                      onPressed: null,"

# ── د) والرمزُ يُضبط بخطوةٍ واحدة ───────────────────────────────────────────
#
# من ضبط رمزاً بإصبعٍ زلّ ثمّ أُقفل عليه لا سبيلَ له إلّا الخروج. **ولا
# يسقط هذا بسؤال «أضُبط الرمز؟»** — يُضبط. يسقط لأنّ الرمزين المختلفين
# يجب ألّا يُضبطا.
run "(د) لا تأكيدَ للرمز" \
  sub "$L" \
"    if (pin != again) {
      note = tr('الرمزان لم يتطابقا. اختر رمزاً من جديد.');
      continue;
    }" \
""

# ── هـ) ومن أخطأ التأكيدَ يُطرَد بلا سبب ───────────────────────────────────
#
# **والصمتُ أسوأُ من الخطأ:** تُغلق الورقةُ ولا يُقال لماذا، فيظنّ صاحبُها
# أنّ شيئاً تعطّل.
run "(هـ) يُطرَد بلا سببٍ يُقرأ" \
  sub "$L" \
"      note = tr('الرمزان لم يتطابقا. اختر رمزاً من جديد.');
      continue;" \
"      return false;"

# ── و) والبابُ يبقى بعد ضبط الرمز ───────────────────────────────────────────
#
# **ولا يكفي أن يُضبط الرمز:** لو لم يُخبَر المستمعون لَبقي البابُ قائماً
# على قفلٍ مضبوط، ولَظنّ صاحبُه أنّ الضبطَ لم يقع فأعاده.
run "(و) لا يُخبَر أحدٌ أنّ القفلَ ضُبط" \
  sub "$K" \
"    _locked = false;
    _left = false;
    _wrong = 0;
    notifyListeners();
  }

  Future<void> disable() async {" \
"    _locked = false;
    _left = false;
    _wrong = 0;
  }

  Future<void> disable() async {"

# ── ز) وزرُّ الإطفاء يعود إلى الإعدادات ────────────────────────────────────
#
# **ولولا هذا لَكان الفرضُ زينةً:** يُضبط عند الدخول ويُطفأ بعد دقيقة،
# فيعود البابُ عند الفتحة التالية ويُقرأ عطلاً لا سياسة.
run "(ز) يعود الإطفاءُ إلى الإعدادات" \
  sub "$A" \
"                        TextButton(
                          key: const ValueKey('lock-change-pin')," \
"                        TextButton(
                          key: const ValueKey('lock-toggle'),
                          onPressed: () {},
                          child: Text(tr('أطفئه')),
                        ),
                        TextButton(
                          key: const ValueKey('lock-change-pin'),"

# ── ح) وتبديلُ الرمز لا يسأل القديم ────────────────────────────────────────
#
# من وجد الجوالَ مفتوحاً يضع رمزاً جديداً فيقفله على صاحبه.
run "(ح) يُبدَّل الرمزُ بلا سؤال القديم" \
  sub "$A" \
"    if (!await lock.verify(old)) {
      if (mounted) showMessage(context, tr('الرمز الحالي خاطئ.'));
      return;
    }" \
""

# ── ط) والتبديلُ يُعدّ محاولةَ فتحٍ فيُخرج الحساب ──────────────────────────
#
# من أخطأ خمساً وهو يبدّل رمزَه في إعداداته يُخرَج حسابُه — وهو في تطبيقه
# مفتوحاً بيده.
run "(ط) التبديلُ يُعدّ محاولةً خاطئة" \
  sub "$K" \
"  Future<bool> verify(String pin) => lockVerify(pin);" \
"  Future<bool> verify(String pin) => unlock(pin);"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
