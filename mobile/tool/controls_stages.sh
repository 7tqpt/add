#!/usr/bin/env bash
# ضوابطُ سالبةٌ لمراحل الحجز — كلُّ ضمانةٍ تُكسر عمداً، ومن لا تسقط بكسرها
# ضمانةٌ لا تقيس شيئاً.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/booking_stages_test.dart
S=lib/src/ui/booking_stages.dart
M=lib/src/screens/my_bookings.dart
D=lib/src/data/demo.dart

BACKUP=$(mktemp -d)
cp "$S" "$BACKUP/s"; cp "$M" "$BACKUP/m"; cp "$D" "$BACKUP/d"
restore() { cp "$BACKUP/s" "$S"; cp "$BACKUP/m" "$M"; cp "$BACKUP/d" "$D"; }
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

# أ) الدفعُ يعود قبل الموافقة — وهو الترتيبُ الذي أبطله صاحبُ المنصّة: من
#    دفع ثمّ اعتُذر عنه صار له مالٌ يُستردّ.
run "أ) الدفعُ يعود قبل الموافقة" sub "$S" \
  "  if (b.status != BookingStatus.confirmed) return null;" \
  "  if (b.status == BookingStatus.completed) return null;"

# ب) عربونٌ نصفيٌّ يُقفل المرحلة — فيُقال لمن حوّل ثلثَه إنّه فرغ.
run "ب) نصفُ العربون يُقفل المرحلة" sub "$S" \
  "      final paid = b.paidAmount >= b.depositAmount;" \
  "      final paid = b.paidAmount > 0;"

# ج) النهايةُ تُخمَّن: يُرسم للمعتذَر عنه ثلاثُ مراحلَ كأنّ الموافقة وقعت.
run "ج) النهايةُ تُخمِّن ما لا تعرف" sub "$S" \
  "        stop(tr('اعتذر مقدّم الخدمة'), tr('ما دفعتَه يُعاد إليك كاملاً')),
      ];" \
  "        stop(tr('اعتذر مقدّم الخدمة'), tr('ما دفعتَه يُعاد إليك كاملاً')),
        (title: tr('دفع العربون'), note: '', mark: StageMark.todo),
      ];"

# د) المقطوعُ يُرسم كالماضي — أخضرَ بصحٍّ، فيظنّ صاحبُه حجزَه سائراً.
run "د) المقطوعُ أخضرُ كالماضي" sub "$S" \
  "    StageMark.todo => AppColors.hairline,
    StageMark.stopped => AppColors.critical," \
  "    StageMark.todo => AppColors.hairline,
    StageMark.stopped => AppColors.good,"

# هـ) والصليبُ يصير صحّاً — فمن لا يميّز الألوان لا يبقى له فارق.
run "هـ) لا صليبَ للمقطوع" sub "$S" \
  "        StageMark.stopped =>
          const Icon(Icons.close_rounded, size: 13, color: Colors.white)," \
  "        StageMark.stopped =>
          const Icon(Icons.check_rounded, size: 13, color: Colors.white),"

# و) الزرُّ يخرج من السكّة إلى أسفل البطاقة — وهي الحال التي شكا منها.
run "و) الزرُّ يخرج من السكّة" sub "$M" \
  "                  BookingStages(
                    stages: bookingStages(b),
                    action: bookingPayLabel(b),
                    onAction: _busyId == null ? () => _pay(b) : null,
                  )," \
  "                  BookingStages(stages: bookingStages(b)),
                  if (bookingPayLabel(b) != null)
                    FilledButton(
                      onPressed: _busyId == null ? () => _pay(b) : null,
                      child: Text(bookingPayLabel(b)!),
                    ),"

# ز) المستحقُّ يعود كاملَ العربون لا الباقي — فيُطلب ممّن حوّل ثلثَه ثلاثةُ
#    أثلاثٍ أخرى.
run "ز) المستحقُّ كاملُ العربون" sub "$S" \
  "      ? trf('ادفع العربون {0}', [formatMoney(b.depositAmount - b.paidAmount)])" \
  "      ? trf('ادفع العربون {0}', [formatMoney(b.depositAmount)])"

# ح) السكّةُ تُشال من البطاقة — العودةُ إلى شارةِ حالةٍ واحدةٍ لا تقول ما بعدَها.
run "ح) لا سكّةَ في البطاقة" sub "$M" \
  "                  BookingStages(
                    stages: bookingStages(b)," \
  "                  if (false) BookingStages(
                    stages: bookingStages(b),"

# ط) حجزُ العرض الموافَقُ عليه بلا عربونٍ يُشال — فلا يُرى زرُّ الدفع في وضع
#    العرض أصلاً، ويخرج التطبيقُ التجريبيُّ بلا بابٍ إلى الدفع.
run "ط) لا حجزَ موافَقاً بلا عربون" sub "$D" \
  "    status: BookingStatus.confirmed,
    totalPrice: 150000,
    depositAmount: 45000,
    paidAmount: 0," \
  "    status: BookingStatus.confirmed,
    totalPrice: 150000,
    depositAmount: 45000,
    paidAmount: 45000,"

# ي) والمعتذَرُ عنه يُشال من العرض — فلا تُرى السكّةُ مقطوعةً قطّ.
run "ي) لا حجزَ معتذَراً عنه في العرض" sub "$D" \
  "    status: BookingStatus.rejected," \
  "    status: BookingStatus.completed,"

# ك) الخيطُ يُلوَّن كلُّه — فما لم يُقطع يبدو مقطوعاً.
run "ك) الخيطُ ملوَّنٌ كلُّه" sub "$S" \
  "                          color: stages[i].mark == StageMark.done
                              ? AppColors.good
                              : AppColors.hairline," \
  "                          color: AppColors.good,"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
