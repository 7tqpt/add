#!/usr/bin/env bash
# ضوابطُ سالبةٌ لشاشة تفصيل الحجز وبطاقتِها.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُحرس هنا فعلٌ يضيع في النقل.** الأزرارُ نُقلت من ملفٍّ إلى
# ملف؛ وزرٌّ يسقط في النقل لا يُرى نقصُه: البطاقةُ تبدو أنظفَ والشاشةُ تبدو
# كاملة، ولا يكتشفه إلّا من أراد أن يُلغي حجزَه فلم يجد كيف.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/booking_detail_test.dart"

D=lib/src/screens/booking_detail.dart
M=lib/src/screens/my_bookings.dart

FILES=("$D" "$M")
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

echo; echo "== أفعالٌ تضيع في النقل =="

# ── أ) يسقط الإلغاء ───────────────────────────────────────────────────────
run "(أ) لا زرَّ إلغاء" \
  sub "$D" \
"        OutlinedButton(
          key: const ValueKey('booking-cancel')," \
"        const SizedBox.shrink(),
        if (false) OutlinedButton( // ignore: dead_code
          key: const ValueKey('booking-cancel'),"

# ── ب) ويُعرض الإلغاءُ بعد التنفيذ ────────────────────────────────────────
#
# القاعدةُ ترفضه، فالزرُّ يَعِد بما سيرفضه الخادم — وهو أسوأُ من غيابه.
run "(ب) إلغاءٌ بعد التنفيذ" \
  sub "$D" \
"      if (_b.status == BookingStatus.pendingProvider ||
          _b.status == BookingStatus.confirmed) ...[" \
"      if (true) ...["

# ── ج) ويُعرض التقييمُ لمن قيّم ───────────────────────────────────────────
#
# القاعدةُ تمنع الثانيةَ بقيدٍ فريد.
run "(ج) تقييمٌ ثانٍ" \
  sub "$D" \
"      if (_b.status == BookingStatus.completed && !_reviewed) ...[" \
"      if (_b.status == BookingStatus.completed) ...["

echo; echo "== الشريطُ الثابت =="

# ── د) ينزل زرُّ الدفع مع الصفحة ──────────────────────────────────────────
#
# اختار صاحبُ المنصّة (ب): الفعلُ الأوّل لا ينزل. **ولا يكشفه اختبارٌ يسأل
# «أثَمّ زرُّ دفع؟»** — ثَمّ زرٌّ في الحالين؛ يُسأل: أهو خارجَ القائمة؟
run "(د) زرُّ الدفع داخل القائمة" \
  sub "$D" \
"        bottomNavigationBar: payLabel == null ? null : _payBar(payLabel)," \
"        bottomNavigationBar: null,"

echo; echo "== البطاقة =="

# ── هـ) وتعود البطاقةُ ساكنةً لا تُفتح ────────────────────────────────────
run "(هـ) البطاقةُ لا تُفتح" \
  sub "$M" \
"                  onTap: () => _open(b)," \
"                  onTap: null,"

# ── و) وتعود أزرارُها إليها ───────────────────────────────────────────────
#
# **والفعلُ في موضعين يجعل أحدَهما يبدو غيرَ الآخر** — وهو ما اختار نقلَه.
run "(و) أزرارٌ تعود إلى البطاقة" \
  sub "$M" \
"                    const SizedBox(height: Space.md),
                    BookingStages(stages: bookingStages(b))," \
"                    const SizedBox(height: Space.md),
                    BookingStages(stages: bookingStages(b)),
                    OutlinedButton(
                      onPressed: () {},
                      child: Text(tr('إلغاء الحجز')),
                    ),"

# ── ز) ويذهب السهمُ عنها ──────────────────────────────────────────────────
run "(ز) لا سهمَ على البطاقة" \
  sub "$M" \
"                        const Icon(Icons.chevron_left, size: 20, color: AppColors.muted)," \
"                        const SizedBox.shrink(),"

echo; echo "== إعادةُ القراءة =="

# ── ح) وتُعاد القراءةُ بلا سبب ────────────────────────────────────────────
#
# من فتح ورجع لم يغيّر شيئاً؛ وقراءةٌ بلا سببٍ ومضةٌ وطلبٌ على الشبكة.
# **ويُقاس عكسُه**: لو لم تُعَد القراءةُ بعد تغييرٍ بقيت الأرقامُ قديمة.
run "(ح) لا تُعاد القراءةُ بعد تغيير" \
  sub "$M" \
"    if (changed == true && mounted) _reload();" \
"    if (false && mounted) _reload(); // ignore: dead_code"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
