#!/usr/bin/env bash
# ضوابطُ سالبةٌ لرحلة «تأكيد التنفيذ» في التطبيق.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **والحارسُ الحقيقيُّ ليس هنا.** أن يعجز المزوّدُ عن إتمام حجزه محرزٌ في
# القاعدة و مقيسٌ في `supabase/tests/controls_completion_review.sh`. وهذه
# الشاشةُ يُتجاوَز حارسُها بملفِّ APK مفكوك — فما يُقاس هنا **ما يراه
# المزوّدُ ويفعله**، لا المنع.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/completion_review_test.dart
R=lib/src/screens/requests.dart
D=lib/src/data/demo.dart

BACKUP=$(mktemp -d)
cp "$R" "$BACKUP/r"; cp "$D" "$BACKUP/d"
restore() { cp "$BACKUP/r" "$R"; cp "$BACKUP/d" "$D"; }
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

# ── أ) الزرُّ يعود نبيذيّاً ─────────────────────────────────────────────────
run "(أ) الزرُّ ليس أخضر" \
  sub "$R" \
"                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.good,
                        )," \
"                        style: null,"

# ── ب) والسؤالُ يُشال ──────────────────────────────────────────────────────
#
# **وهذا أخطرُ ما في هذه الحزمة.** ضغطةٌ عابرةٌ في جيبٍ تُرسل طلبَ اعتمادٍ
# إلى الإدارة عن حجزٍ لم يُنفَّذ.
run "(ب) لا سؤالَ قبل الإرسال" \
  sub "$R" \
"    final ok = await confirmChoice(
      context,
      title: tr('تأكيد التنفيذ')," \
"    final ok = true == true ? true : await confirmChoice(
      context,
      title: tr('تأكيد التنفيذ'),"

# ── ج) و«لا» تُرسل كما تُرسل «نعم» ─────────────────────────────────────────
#
# كسرٌ أخبث: السؤالُ يُطرح ويُرى، والجوابُ لا يُقرأ.
run "(ج) الجوابُ لا يُقرأ" \
  sub "$R" \
"    if (ok != true || !mounted) return;

    setState(() => _busyId = id);
    try {
      await Api.requestCompletion(id);" \
"    if (!mounted) return;

    setState(() => _busyId = id);
    try {
      await Api.requestCompletion(id);"

# ── د) والسؤالُ يصير «هل أنت متأكّد؟» وحدَها ───────────────────────────────
#
# من لا يعرف أنّ مالَه ينتظر مراجعةً يظنّ التطبيقَ معطوباً حين لا يصله شيء،
# فيُعيد الضغطَ ثمّ يشكو.
run "(د) السؤالُ لا يقول ما سيقع" \
  sub "$R" \
"      body: tr('هل أنت متأكّد أنّ الحجز نُفِّذ؟ يُرسَل إلى الإدارة للمراجعة، '
          'وتُحتسب مستحقّاتك بعد موافقتها.')," \
"      body: tr('هل أنت متأكّد؟')," \

# ── هـ) وشريطُ الانتظار يُشال ──────────────────────────────────────────────
#
# فيبقى الزرُّ بعد الضغط كأنّ شيئاً لم يقع — فيُضغط ثانيةً وثالثة.
run "(هـ) لا يُعرض انتظارُ الإدارة" \
  sub "$R" \
"                    if (b.awaitingCompletionReview)
                      const _ReviewBar()
                    else ...[" \
"                    if (false)
                      const _ReviewBar()
                    else ...["

# ── و) وشريطُ الانتظار يصير أخضرَ كشريط التنفيذ ────────────────────────────
#
# **ولا يسقط هذا بسؤال «أموجودٌ الشريط؟».** الأخضرُ يقول «تمّ»، وهذا لم
# يتمّ — فيظنّ المزوّدُ أنّ مالَه احتُسب فلا يسأل حين يتأخّر.
run "(و) انتظارُ الإدارة بلون التنفيذ" \
  sub "$R" \
"      color: AppColors.warning.withValues(alpha: Tint.chip)," \
"      color: AppColors.good.withValues(alpha: Tint.chip),"

# ── ز) وسببُ الردّ لا يُعرض ────────────────────────────────────────────────
#
# فيُعيد المزوّدُ طلبَه كما هو، ويدور الطابورُ على نفسه.
run "(ز) سببُ الردّ لا يُعرض" \
  sub "$R" \
"                      if (b.completionRejectReason.isNotEmpty) ...[" \
"                      if (false) ...["

# ── ح) والسببُ يُعرض تحت الزرّ لا فوقه ─────────────────────────────────────
#
# فيُضغط الزرُّ قبل أن يُقرأ السبب.
run "(ح) السببُ تحت الزرّ" \
  sub "$R" \
"                      if (b.completionRejectReason.isNotEmpty) ...[
                        _RejectNote(b.completionRejectReason),
                        const SizedBox(height: Space.sm),
                      ],
                      FilledButton(" \
"                      FilledButton("

# ── ط) ووضعُ العرض يُتمّ الحجزَ بدل أن يطلب ────────────────────────────────
#
# **والمحاكاةُ تكذب حين تُعطي ما لا تُعطيه القاعدة.** من جرّب التطبيقَ بلا
# قاعدةٍ رأى «تم تنفيذ الحجز» فوراً، فبنى توقّعَه على شيءٍ لا يقع.
run "(ط) وضعُ العرض يُتمّ الحجز" \
  sub "$D" \
"      completionRequestedAt: DateTime.now().toIso8601String()," \
"      status: BookingStatus.completed,
      completionRequestedAt: DateTime.now().toIso8601String(),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
