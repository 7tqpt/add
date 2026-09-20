#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقاتِ القوائم التي تُفتح بالضغط.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/card_opens_test.dart"

S=lib/src/screens/services.dart
K=lib/src/ui/kit.dart

FILES=("$S" "$K")
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

# ── أ) تعود البطاقةُ ساكنةً ────────────────────────────────────────────────
#
# **وهو الحالُ الذي شُكي منه بعينه**: تُضغط فلا يقع شيء، ويُبحث عن زرٍّ في
# أسفلها.
run "(أ) البطاقةُ تعود ساكنة" \
  sub "$S" \
"                onTap: _busyId == null ? () => _edit(s) : null," \
"                onTap: null,"

# ── ب) وتُوصل بفعلٍ آخر ───────────────────────────────────────────────────
#
# `onTap` في الشجرة لا يعني أنّها تفتح ما وُعد به: هذه تفتح الوسائط لا
# التعديل — والحزمةُ التي تسأل «أثَمّ ضغطة؟» تمرّ.
run "(ب) تفتح غيرَ ما وُعد به" \
  sub "$S" \
"                onTap: _busyId == null ? () => _edit(s) : null," \
"                onTap: _busyId == null ? () => _media(s) : null,"

# ── ج) ويذهب السهمُ عن شريط عنوانها ───────────────────────────────────────
#
# الانخفاضُ تحت الإصبع لا يُعلم إلّا بعد أن يُجرَّب، والسهمُ يُعلم قبله.
run "(ج) لا سهمَ يقول إنّها تُفتح" \
  sub "$S" \
"                    opens: true," \
"                    opens: false,"

# ── د) ويُرسم السهمُ في كلّ شريطٍ ─────────────────────────────────────────
#
# **وسهمٌ يَعِد بما لا يقع أسوأُ من غيابه**: `CardTitleBar` في مواضعَ كثيرةٍ
# لا تُفتح، فسهمٌ عامٌّ فيها يكذب في كلّها.
run "(د) السهمُ في كلّ شريط" \
  sub "$K" \
"        if (opens) ...[" \
"        if (true) ...[ // ignore: dead_code"

# ── هـ) ولا يتبع السهمُ اتّجاهَ اللغة ─────────────────────────────────────
#
# سهمٌ إلى اليمين في العربيّة يقول «ارجع» لا «تقدّم».
run "(هـ) السهمُ يخالف الاتّجاه" \
  sub "$K" \
"            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left
                : Icons.chevron_right," \
"            Icons.chevron_right,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
