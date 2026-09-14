#!/usr/bin/env bash
# ضوابطُ سالبةٌ لخَتم الحجز المنفَّذ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (ج): الشرطُ بالمقلوب.** سطرٌ واحدٌ يُعكس فتُقطع
# المراسلةُ عن كلّ حجزٍ في التطبيق ويُختم ما لم يُنفَّذ بعد — واختبارٌ يقيس
# «الشريطُ موجود» وحدَه يمرّ على ذلك.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/booking_done_test.dart
R=lib/src/screens/requests.dart

BACKUP=$(mktemp -d)
cp "$R" "$BACKUP/r"
restore() { cp "$BACKUP/r" "$R"; }
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

# ── أ) الخَتمُ يُشال ويعود زرُّ المراسلة ─────────────────────────────────────
#
# وهي الحالُ التي كانت قبل الطلب.
run "(أ) لا خَتمَ للمنفَّذ" \
  sub "$R" \
"                  if (b.status == BookingStatus.completed)
                    _DoneBar(session: widget.session)
                  else
                    OutlinedButton.icon(" \
"                  if (false)
                    _DoneBar(session: widget.session)
                  else
                    OutlinedButton.icon("

# ── ب) والخَتمُ يُضاف والزرُّ يبقى تحته ──────────────────────────────────────
#
# **وهذا نصفُ الطلب الذي لا يقيسه وجودُ الشريط.** «شيل أيقون راسل هدى» —
# فشريطٌ يُضاف وزرٌّ باقٍ تحته يُرضي عيناً تنظر إلى أعلى البطاقة ولا يُرضي
# ما طُلب.
run "(ب) الخَتمُ يُضاف والزرُّ باقٍ" \
  sub "$R" \
"                  if (b.status == BookingStatus.completed)
                    _DoneBar(session: widget.session)
                  else
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _message(b),
                      icon: const Icon(Icons.forum_outlined, size: 19),
                      label: Text(trf('راسل {0}', [b.userName])),
                    )," \
"                  if (b.status == BookingStatus.completed)
                    _DoneBar(session: widget.session),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _message(b),
                    icon: const Icon(Icons.forum_outlined, size: 19),
                    label: Text(trf('راسل {0}', [b.userName])),
                  ),"

# ── ج) والشرطُ بالمقلوب ─────────────────────────────────────────────────────
#
# **وهذا أخطرُها.** سطرٌ واحدٌ يُعكس: يُختم كلُّ حجزٍ لم يُنفَّذ، وتُقطع
# المراسلةُ عن الطلب الجديد الذي هو أحوجُ ما يكون إليها.
run "(ج) الشرطُ بالمقلوب" \
  sub "$R" \
"                  if (b.status == BookingStatus.completed)" \
"                  if (b.status != BookingStatus.completed)"

# ── د) والكلمةُ تُشال وتبقى الأيقونة ────────────────────────────────────────
#
# من لا يفرّق الأخضرَ من الأحمر لا يبقى له ما يقرأ.
run "(د) أيقونةٌ بلا كلمة" \
  sub "$R" \
"              child: Text(
                tr('تم تنفيذ الحجز')," \
"              child: Text(
                tr('')," \

# ── هـ) والشريطُ يصير بلا لون ───────────────────────────────────────────────
run "(هـ) الشريطُ بلا خُضرة" \
  sub "$R" \
"    color: AppColors.good.withValues(alpha: Tint.chip)," \
"    color: AppColors.surface2,"

# ── و) والصبغةُ تصير خضرةً صمّاء ────────────────────────────────────────────
#
# كسرٌ أخبث: اللونُ صحيحٌ والشفافيّةُ ذهبت — فيصرخ القاعُ بأخضرَ كاملٍ
# والحبرُ الأخضرُ عليه يذوب.
run "(و) خضرةٌ صمّاءُ لا صبغة" \
  sub "$R" \
"    color: AppColors.good.withValues(alpha: Tint.chip)," \
"    color: AppColors.good,"

# ── ز) والخَتمُ يصير زرّاً يُلمَس ولا يفعل ──────────────────────────────────
run "(ز) الشريطُ لا يقود إلى المستحقّات" \
  sub "$R" \
"      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EarningsScreen(session: session)),
      )," \
"      onTap: () {},"

# ── ح) والسهمُ يُشال فلا يعرف أحدٌ أنّه باب ──────────────────────────────────
#
# **وهذا ما لا يسقط بسؤال «هل يُضغط؟».** الشريطُ يُضغط ويعمل، ولا علامةَ
# تقول ذلك — فيبقى الطريقُ إلى المستحقّات مقفولاً وهو مفتوح.
run "(ح) لا سهمَ ولا كلمةَ «مستحقّاتي»" \
  sub "$R" \
"            Text(
              tr('مستحقّاتي')," \
"            Text(
              tr('')," \

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
