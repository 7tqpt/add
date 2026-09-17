#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقة العميل في التطبيق.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وحدُّ الدالّة في القاعدة له ضوابطُه** (`supabase/tests/controls_customer_card.sh`).
# وهذه لما فوقه: أنّ الشاشةَ تعرض ما جاء ولا تزيد، وأنّ كلَّ جانبٍ يذهب إلى
# وجهته.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/customer_card_test.dart test/chat_bar_test.dart"

S=lib/src/screens/customer_card.dart
C=lib/src/screens/chat.dart

FILES=("$S" "$C")
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

# ── أ) لا تُفتح البطاقةُ لمقدّم الخدمة ──────────────────────────────────────
#
# **وهو ما شكا منه:** يضغط فلا يقع شيء.
run "(أ) الشريطُ لا يفتح البطاقة" \
  sub "$C" \
"    if (widget.mySide == ChatSide.provider) {" \
"    if (false) {"

# ── ب) وتُفتح للعميل بطاقةُ عميل ────────────────────────────────────────────
#
# **وهو خلطُ الوجهتين.** العميلُ وجهتُه ملفُّ القاعة، لا بطاقةُ عميلٍ عن
# نفسه. ولا يسقط هذا بسؤال «أتُفتح شاشة؟» — تُفتح.
run "(ب) تُخلط الوجهتان" \
  sub "$C" \
"    if (widget.mySide == ChatSide.provider) {" \
"    if (true) {"

# ── ج) وتُعرض أصفارٌ على من لم يحجز ─────────────────────────────────────────
#
# «الحجوزات ٠ · المكتملة ٠ · إجمالي ما دفعه ٠» تبدو شاشةً مكسورة، وهي حالٌ
# سليمة: راسلك ولم يحجز.
run "(ج) أصفارٌ لمن لم يحجز" \
  sub "$S" \
"        if (c.bookingsCount == 0) ...[" \
"        if (false) ...["

# ── د) ويُعرض سطرُ محافظةٍ فارغ ─────────────────────────────────────────────
#
# أيقونةُ موقعٍ بجانبها فراغٌ تُقرأ عطباً.
run "(د) سطرُ محافظةٍ فارغ" \
  sub "$S" \
"                  if (c.governorate.trim().isNotEmpty) ...[" \
"                  if (true) ...["

# ── هـ) ويُبتلع خطأُ الخادم ─────────────────────────────────────────────────
#
# **ومن استدعى محادثةً ليست له يُردّ** — فإن ابتُلع الردُّ رأى شاشةً فارغةً
# بلا سبب، وهو أسوأُ من رسالةٍ حمراء.
run "(هـ) يُبتلع خطأُ الخادم" \
  sub "$S" \
"    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageOf(e);
        _loading = false;
      });
    }" \
"    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }"

# ── و) وتُحسب الأرقامُ في الشاشة لا تُعرض كما جاءت ──────────────────────────
#
# **وهو ما يجعل البطاقةَ تكذب بلا أن تُخطئ.** رقمٌ يُشتقّ هنا يفترق عمّا في
# القاعدة يوم تتبدّل القاعدة.
run "(و) رقمٌ من عند الشاشة" \
  sub "$S" \
"          KeyValue(tr('المكتملة'), '\${c.completedCount}')," \
"          KeyValue(tr('المكتملة'), '\${c.bookingsCount - c.cancelledCount}'),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
