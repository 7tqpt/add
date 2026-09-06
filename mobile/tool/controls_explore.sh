#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحقل البحث ومرشِّح المحافظات.
#
# **و`flutter` ليست في المسار افتراضاً هنا** — وقد نجحت ثمانيةُ ضوابطَ في هذا
# المشروع مرّةً وهي كذبٌ كلُّها لأنّ الغلاف قرأ «command not found» نجاحاً.
#
# **ومهلةٌ على كلّ تشغيل:** كسرٌ جعل اختباراً يدور بلا نهاية مرّةً، فبقي
# `flutter test` معلَّقاً إحدى وأربعين دقيقةً والسكربتُ ينتظره صامتاً.
set -u
export PATH=/opt/flutter/bin:$PATH
cd "$(dirname "$0")/.."

EXP=lib/src/screens/explore.dart
TEST=test/explore_filter_test.dart

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

echo "== الأساس =="
flutter test "$TEST" 2>&1 | grep -q 'All tests passed' \
  || { echo "الأساسُ أحمر"; exit 1; }
echo "أخضر."

cp "$EXP" /tmp/exp.bak
restore() { cp /tmp/exp.bak "$EXP"; }
trap restore EXIT

pass=0; fail=0
control() {
  local name="$1"; shift
  restore
  "$@" || { echo "✗ $name — لم يُطبَّق الكسرُ أصلاً"; fail=$((fail+1)); return; }
  local out; out=$(timeout 180 flutter test "$TEST" 2>&1)
  local code=$?
  if [ "$code" -eq 124 ]; then
    echo "⏱ $name — عُلِّق ولم يسقط"; fail=$((fail+1)); return
  fi
  if echo "$out" | grep -qE '^\s*[0-9:]+ \+[0-9]+ -[1-9]'; then
    echo "✓ $name — سقط"; pass=$((pass+1))
  elif echo "$out" | grep -q 'Error:'; then
    echo "✗ $name — لم يُترجَم (الكسرُ خاطئ لا الاختبار)"; fail=$((fail+1))
  else
    echo "✗ $name — بقي أخضرَ: الحارسُ لا يحرس"; fail=$((fail+1))
  fi
}

sub() { python3 - "$@" <<'PY'
import sys, pathlib
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path); t = p.read_text()
if t.count(old) != 1:
    sys.exit(f'الكسرُ لا ينطبق مرّةً واحدة ({t.count(old)})')
p.write_text(t.replace(old, new))
PY
}

echo
echo "== الضوابط =="

# ── حقلُ البحث ────────────────────────────────────────────────────────────

control "أ) يعود النصُّ الطويلُ الذي يُقصّ في الحقل" \
  sub "$EXP" "              hintText: 'ابحث عن…'," \
             "              hintText: 'ابحث عن قاعة، مصوّر، طبّاخ…',"

control "ب) يعود الحدُّ مربّعاً فلا يشبه ما طُلب" \
  sub "$EXP" '  borderRadius: BorderRadius.circular(999),
  borderSide: const BorderSide(color: AppColors.hairline),' \
             '  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: AppColors.hairline),'

# ── مرشِّحُ المحافظات ──────────────────────────────────────────────────────

control "ج) المغلقُ لا يكتب المختارَ فلا يُعرف أنّ النتائج مقصوصة" \
  sub "$EXP" '                value ?? _all,' '                _all,'

control "د) لا علامةَ صحٍّ في المفتوح فلا يُعرف أين هو" \
  sub "$EXP" '              if (active)
                const Icon(Icons.check_rounded, size: 18, color: AppColors.accent),' \
             ''

control "هـ) إغلاقُ الورقة يُقرأ «كل المحافظات» فيضيع المرشِّح" \
  sub "$EXP" '    if (picked == null) return;
    onPick(picked == _all ? null : picked);' \
             '    onPick(picked == null || picked == _all ? null : picked);'

control "و) «كل المحافظات» تُرسَل نصّاً فتُطلب محافظةٌ بهذا الاسم" \
  sub "$EXP" '    onPick(picked == _all ? null : picked);' '    onPick(picked);'

control "ز) الورقةُ لا تعرض إلّا «كل المحافظات» — القائمةُ لا تُمرَّر" \
  sub "$EXP" '                  for (final g in options) _row(sheet, g, value == g),' ''

control "ح) يعود صفُّ الشرائح مع الزرّ" \
  sub "$EXP" '              if (_myPoint != null) ...[
                const SizedBox(width: Space.sm),
                PickChip(' \
             '              for (final g in const ["عدن", "تعز"]) ...[
                const SizedBox(width: Space.sm),
                PickChip(label: g, active: false, onTap: () {}),
              ],
              if (_myPoint != null) ...[
                const SizedBox(width: Space.sm),
                PickChip('

control "ط) الزرُّ بلا مفتاحٍ فلا يُمكن قصدُه" \
  sub "$EXP" "      key: const ValueKey('governorate-field')," ''

echo
echo "== الحصيلة: $pass سقطت، $fail لم تسقط =="
[ "$fail" -eq 0 ]
