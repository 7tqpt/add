#!/usr/bin/env bash
# ضوابطُ سالبةٌ لاختبارات المشاركة.
#
# **و`flutter` ليست في المسار افتراضاً هنا** — وقد نجحت ثمانيةُ ضوابطَ في هذا
# المشروع مرّةً وهي كذبٌ كلُّها لأنّ الغلاف قرأ «command not found» نجاحاً.
#
# **ومهلةٌ على كلّ تشغيل:** كسرٌ جعل اختباراً يدور بلا نهاية مرّةً، فبقي
# `flutter test` معلَّقاً إحدى وأربعين دقيقةً والسكربتُ ينتظره صامتاً.
set -u
export PATH=/opt/flutter/bin:$PATH
cd "$(dirname "$0")/.."

SHARE=lib/src/core/share.dart
BTN=lib/src/ui/share_button.dart
TEST=test/share_test.dart

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

echo "== الأساس =="
flutter test "$TEST" 2>&1 | grep -q 'All tests passed' \
  || { echo "الأساسُ أحمر"; exit 1; }
echo "أخضر."

for f in "$SHARE" "$BTN"; do cp "$f" "/tmp/$(basename "$f").bak"; done
restore() { for f in "$SHARE" "$BTN"; do cp "/tmp/$(basename "$f").bak" "$f"; done; }
trap restore EXIT

pass=0; fail=0
control() {
  local name="$1"; shift
  restore
  "$@" || { echo "✗ $name — لم يُطبَّق الكسرُ أصلاً"; fail=$((fail+1)); return; }
  local out; out=$(timeout 180 flutter test "$TEST" 2>&1)
  local code=$?
  if [ "$code" -eq 124 ]; then
    echo "⏱ $name — عُلِّق ولم يسقط (يحتاج نظراً على حدة)"
    fail=$((fail+1)); return
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

control "أ) يُقبل http:// — ورابطٌ يُنذر يُقرأ احتيالاً" \
  sub "$SHARE" "  if (!u.startsWith('https://')) return false;" ""

control "ب) يُقبل رابطٌ فيه فراغٌ فينقطع في واتساب" \
  sub "$SHARE" "  return !u.contains(' ');" '  return true;'

control "ج) يُقبل https:// عاريةً بلا مضيف" \
  sub "$SHARE" "  if (u.length <= 'https://'.length) return false;" ""

control "د) تخرج دعوةٌ بلا رابطٍ لها — «حمّل تطبيق فرحتي:» ثمّ فراغ" \
  sub "$SHARE" "    isShareUrlValid(url) ? '\\n\\nحمّل تطبيق فرحتي:\\n\${url.trim()}' : '';" \
               "    '\\n\\nحمّل تطبيق فرحتي:\\n\${url.trim()}';"

control "هـ) الخدمةُ تضيع مع الرابط فلا يبقى اسمٌ ولا سعر" \
  sub "$SHARE" "  return '\${lines.join('\\n')}\${_invite(url)}';
}

/// نصُّ مشاركة ملفّ مقدّم خدمة." \
               "  return _invite(url);
}

/// نصُّ مشاركة ملفّ مقدّم خدمة."

control "و) الوصفُ لا يُقصّ فيُطوى الرابطُ خلف «قراءة المزيد»" \
  sub "$SHARE" '  if (clean.length <= max) return clean;' '  return clean;'

control "ز) يُقصّ في وسط الكلمة" \
  sub "$SHARE" "  final space = cut.lastIndexOf(' ');" '  final space = -1;'

control "ح) المدى يُكتب مبلغاً واحداً فيبدو أرخصَ ممّا هو" \
  sub "$SHARE" 'item.priceTo == null' 'true'

control "ط) نجومٌ لمن لم يُقيَّم بعد — ٠٫٠ تُقرأ رداءةً" \
  sub "$SHARE" '    if (reviewsCount > 0)' '    if (reviewsCount >= 0)'

control "ي) التطبيقُ يُشارَك بلا رابطٍ — رسالةٌ لا يفعل بها مستقبلُها شيئاً" \
  sub "$SHARE" "  return invite.isEmpty ? '' : '\$pitch\$invite';" "  return '\$pitch\$invite';"

control "ك) رقمُ المقدّم يخرج في النصّ" \
  sub "$SHARE" "    if (governorate.trim().isNotEmpty) '📍 \${governorate.trim()}'," \
               "    if (governorate.trim().isNotEmpty) '📍 \${governorate.trim()}',
    '📞 771234567',"

control "ل) زرُّ الخدمة يُرسل شيئاً غيرَ النصّ المبنيّ" \
  sub "$BTN" '      final text = compose(await cachedShareUrl());' \
             "      final text = 'فرحتي';"

control "م) بندُ «شارك التطبيق» يظهر بلا رابط — يُضغط فلا يقع شيء" \
  sub "$BTN" '      if (!isShareUrlValid(url)) return const SizedBox.shrink();' ''

echo
echo "== الحصيلة: $pass سقطت، $fail لم تسقط =="
[ "$fail" -eq 0 ]
