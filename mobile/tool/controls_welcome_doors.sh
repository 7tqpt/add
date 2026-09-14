#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبابَي شاشة الترحيب.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/welcome_test.dart test/recover_test.dart"
W=lib/src/screens/welcome.dart

BACKUP=$(mktemp -d)
cp "$W" "$BACKUP/w"
restore() { cp "$BACKUP/w" "$W"; }
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

# ── أ) الذهبيُّ يعود يفتح الإنشاء ────────────────────────────────────────────
#
# وهو ما بُدّل بعينه: «خلّه ينطلق إلى تسجيل الدخول وليس العكس».
run "(أ) الذهبيُّ يفتح الإنشاءَ كما كان" \
  sub "$W" \
"                      onPressed: () => _open(signUp: false)," \
"                      onPressed: () => _open(signUp: true),"

# ── ب) والمحاطُ يفتح الدخول ──────────────────────────────────────────────────
#
# فيصير البابان باباً واحداً مكرّراً، ويُسدّ بابُ القادم الجديد.
run "(ب) المحاطُ يفتح الدخولَ كذلك" \
  sub "$W" \
"                      onPressed: () => _open(signUp: true)," \
"                      onPressed: () => _open(signUp: false),"

# ── ج) والبابُ الثاني يُشال ──────────────────────────────────────────────────
run "(ج) لا بابَ لإنشاء الحساب" \
  sub "$W" \
"                      key: const ValueKey('welcome-sign-up')," \
"                      key: const ValueKey('welcome-sign-up-x'),"

# ── د) وبابُ الدخول يُشال ────────────────────────────────────────────────────
run "(د) لا بابَ للدخول" \
  sub "$W" \
"                      key: const ValueKey('welcome-sign-in')," \
"                      key: const ValueKey('welcome-sign-in-x'),"

# ── هـ) والمحاطُ يُترك بلونه الافتراضيّ ──────────────────────────────────────
#
# **وهذا ما لا تراه الصورةُ وحدَها.** إطارٌ باهتٌ وحبرٌ افتراضيٌّ على تدرّجٍ
# نبيذيٍّ يُقرأ نصّاً لا باباً — والزرُّ موجودٌ يُضغط، فالاختبارُ الذي يبحث
# عن وجوده وحدَه يمرّ.
run "(هـ) المحاطُ بلونه الافتراضيّ على النبيذيّ" \
  sub "$W" \
"                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.goldOnAccent,
                        side: BorderSide(color: AppColors.goldOnAccent),
                        minimumSize: Size.fromHeight(52),
                      )," \
"                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(52),
                      ),"

# ── و) والذهبيُّ يفقد ذهبَه ──────────────────────────────────────────────────
run "(و) الذهبيُّ نبيذيٌّ على نبيذيّ" \
  sub "$W" \
"                        backgroundColor: AppColors.goldOnAccent,
                        foregroundColor: AppColors.accentDeep," \
"                        backgroundColor: AppColors.accentDeep,
                        foregroundColor: AppColors.goldOnAccent,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
