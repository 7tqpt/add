#!/usr/bin/env bash
# ضوابطُ سالبةٌ لشاشة الدفع.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/payment_test.dart test/account_extras_test.dart"
F=lib/src/screens/payment.dart
D=lib/src/data/demo.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"; cp "$D" "$BACKUP/d"
restore() { cp "$BACKUP/f" "$F"; cp "$BACKUP/d" "$D"; }
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
  if timeout 900 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 900 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== ولا وسيلةَ مضبوطة =="

# ── أ) يعود النصُّ بلا بابٍ يُفتح ────────────────────────────────────────
#
# **«راسل الدعم» بلا زرٍّ نصفُ رسالة**: يُؤمر صاحبُه بشيءٍ ولا يُعطى ما
# ينفّذه به، فعليه أن يخرج ويبحث عن الدعم في شاشةٍ أخرى.
run "(أ) يُقال (راسل الدعم) بلا زرّ" \
  sub "$F" \
"              if (s == null || !s.any) return _NoMethods(session: widget.session);" \
"              if (s == null || !s.any) {
                return EmptyBlock(
                  title: tr('لم تُضبط وسائل التحويل بعد'),
                  description: tr('راسل الدعم لإتمام الدفع — ولا تحوّل إلى '
                      'رقمٍ غير معلن هنا.'),
                );
              }"

# ── ب) والزرُّ مرسومٌ لا يفتح شيئاً ──────────────────────────────────────
run "(ب) زرُّ الدعم لا يفتح شيئاً" \
  sub "$F" \
"            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SupportScreen(session: me)),
            )," \
"            onPressed: () {},"

# ── ج) ويظهر الزرُّ بلا جلسةٍ يفتح بها ──────────────────────────────────
#
# فيُضغط فتسقط الشاشةُ التي وراءه.
run "(ج) زرُّ دعمٍ بلا جلسة" \
  sub "$F" \
"        if (me != null) ...[" \
"        if (me == null || true) ...["

# ── د) ويُعرض نموذجُ الإبلاغ بلا أرقامٍ يُحوَّل إليها ────────────────────
#
# **ومن حوّل إلى رقمٍ لا وجود له فقَدَ ماله.**
run "(د) نموذجُ الإبلاغ بلا أرقام" \
  sub "$F" \
"              if (s == null || !s.any) return _NoMethods(session: widget.session);" \
"              if (s == null) return _NoMethods(session: widget.session);"

echo; echo "== ورقمُ الحجز =="

# ── هـ) ويُنسخ غيرُه ─────────────────────────────────────────────────────
#
# وهو الذي يُكتب في خانة الملاحظة عند التحويل، ومن لصق غيرَه تأخّرت مطابقةُ
# حوالته.
run "(هـ) يُنسخ غيرُ رقم الحجز" \
  sub "$F" \
"                  await Clipboard.setData(ClipboardData(text: value));" \
"                  await Clipboard.setData(const ClipboardData(text: ''));"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
