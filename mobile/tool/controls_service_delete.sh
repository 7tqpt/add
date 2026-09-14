#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحذف الخدمة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (ج): السؤالُ يُشال.** الحذفُ بلا رجعة، وزرٌّ أحمرُ
# يُزال بلمسةٍ عابرةٍ في جيبٍ يمحو خدمةً وصورَها. والاختبارُ الذي يبحث عن
# وجود الزرّ وحدَه يمرّ وقد صار الحذفُ بضغطةٍ واحدة.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/service_delete_test.dart
S=lib/src/screens/services.dart
D=lib/src/data/demo.dart

BACKUP=$(mktemp -d)
cp "$S" "$BACKUP/s"; cp "$D" "$BACKUP/d"
restore() { cp "$BACKUP/s" "$S"; cp "$BACKUP/d" "$D"; }
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

# ── أ) الزرُّ يُشال من البطاقة ───────────────────────────────────────────────
run "(أ) لا زرَّ حذفٍ في البطاقة" \
  sub "$S" \
"                    key: ValueKey('service-delete-\${s.id}')," \
"                    key: ValueKey('service-delete-x-\${s.id}'),"

# ── ب) والحذفُ لا يُنادى أصلاً ──────────────────────────────────────────────
#
# زرٌّ يُضغط ولا يفعل شيئاً — والشاشةُ ساكنةٌ لا رسالةَ فيها.
run "(ب) الزرُّ لا ينادي الحذف" \
  sub "$S" \
"                    onPressed: _busyId == null ? () => _delete(s) : null," \
"                    onPressed: _busyId == null ? () {} : null,"

# ── ج) والسؤالُ يُشال — فيصير الحذفُ بضغطةٍ واحدة ───────────────────────────
#
# **وهذا أخطرُها.** «ورسالة تأكيد الحذف هل تريد حذف نعم أم لا» — طلبها
# صاحبُ المنصّة نصّاً. وبلا ضابطٍ يسقط بها يُنقل الزرُّ يوماً ويُنسى
# `confirmDanger`، والحزمةُ خضراء.
run "(ج) لا سؤالَ قبل الحذف" \
  sub "$S" \
"    final ok = await confirmDanger(
      context,
      title: tr('حذف الخدمة'),
      body: trf('هل تريد حذف «{0}»؟ لا رجعة بعدها — وتُحذف صورُها ومقاطعُها معها.',
          [service.title]),
      confirm: tr('نعم، احذفها'),
    );
    if (ok != true || !mounted) return;" \
"    const ok = true;
    if (ok != true || !mounted) return;"

# ── د) و«إلغاء» تحذف كما تحذف «نعم» ─────────────────────────────────────────
#
# كسرٌ أخبث: السؤالُ يُطرح ويُرى، والجوابُ لا يُقرأ. فمن قال «لا» ضاعت
# خدمتُه وقد ظنّ أنّه منع.
run "(د) الجوابُ لا يُقرأ" \
  sub "$S" \
"    if (ok != true || !mounted) return;" \
"    if (!mounted) return;"

# ── هـ) والمنعُ يُلغى: الحجزُ القادمُ لا يمنع ───────────────────────────────
#
# اختار صاحبُ المنصّة **(١) يُمنع الحذفُ ما دام عليها حجزٌ قادم**. وبلا
# هذا تختفي الخدمةُ من تحت عرسٍ بعد أسبوعين.
run "(هـ) الحجزُ القادمُ لا يمنع" \
  sub "$D" \
"  if (blocking != null) return (deleted: false, blockingDate: blocking);" \
"  blocking = null;
  if (blocking != null) return (deleted: false, blockingDate: blocking);"

# ── و) والحجزُ الماضي يمنع كالقادم ──────────────────────────────────────────
#
# عرسٌ انتهى قبل سنةٍ يحبس القائمةَ إلى الأبد — والشاشةُ تقول «أوقِفها»
# لخدمةٍ لا حجزَ عليها.
run "(و) الحجزُ الماضي يمنع كذلك" \
  sub "$D" \
"    if (date == null || date.isBefore(startOfDay)) continue;" \
"    if (date == null) continue;"

# ── ز) والملغى يمنع ─────────────────────────────────────────────────────────
run "(ز) الملغى والمرفوض يمنعان" \
  sub "$D" \
"    if (b.status != BookingStatus.pendingProvider &&
        b.status != BookingStatus.confirmed) {
      continue;
    }" \
"    if (false) {
      continue;
    }"

# ── ح) والخدمةُ لا تُطابَق: أيُّ حجزٍ يمنع أيَّ خدمة ────────────────────────
run "(ح) لا تُطابَق الخدمةُ بحجزها" \
  sub "$D" \
"    if (!b.serviceTitle.contains(service.title)) continue;" \
"    if (false) continue;"

# ── ط) والتاريخُ لا يُقال — «مُنعت» وحدَها ──────────────────────────────────
#
# **ولا يُقال «فشل الحذف».** من لا يعرف أيُّ حجزٍ يمنعه يظنّ العطلَ في
# التطبيق، فيعيد المحاولةَ ثمّ يشكو.
run "(ط) لا يُقال تاريخُ الحجز المانع" \
  sub "$S" \
"              : trf('عليها حجزٌ في {0}. أوقِفها بدل أن تحذفها.',
                  [formatDay(date)])," \
"              : tr('عليها حجزٌ قادم. أوقِفها بدل أن تحذفها.'),"

# ── ي) والحذفُ يقع وإن مُنع ─────────────────────────────────────────────────
#
# الردُّ يقول «لم تُحذف» والشاشةُ تمضي فتُنقص القائمةَ — وهي الحالُ التي
# لا يكشفها إلّا سؤالُ ما بقي.
run "(ي) الشاشةُ تمضي رغم المنع" \
  sub "$S" \
"      if (!result.deleted) {" \
"      if (false) {"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
