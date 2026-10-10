#!/usr/bin/env bash
# ضوابطُ سالبةٌ لشاشة «تعذّر فتح حسابك» (ب): يُكسر كلُّ ضمانٍ كسراً واحداً
# بشيفرةٍ صالحة، ويُشترط أن تحمرّ الحزمةُ لا أن يتعطّل البناء.
set -u
export PATH=/opt/flutter/bin:$PATH
cd "$(dirname "$0")/.."

SB=lib/src/data/supabase.dart
ROOT=lib/src/screens/root.dart
TEST=test/account_error_test.dart

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

echo "== الأساس =="
flutter test "$TEST" 2>&1 | grep -q 'All tests passed' \
  || { echo "الأساسُ أحمر"; exit 1; }
echo "أخضر."

for f in "$SB" "$ROOT"; do cp "$f" "/tmp/$(basename "$f").bak"; done
restore() { for f in "$SB" "$ROOT"; do cp "/tmp/$(basename "$f").bak" "$f"; done; }
trap restore EXIT

pass=0; fail=0
control() {
  local name="$1"; shift
  restore
  "$@" || { echo "✗ $name — لم يُطبَّق الكسرُ أصلاً"; fail=$((fail+1)); return; }
  local out; out=$(flutter test "$TEST" 2>&1)
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

control "أ) رقمُ الحالة 401 يُقرأ رمزاً — فلا يعمل العلاجُ الصامت" \
  sub "$SB" '  if (status != null && !_httpStatus.hasMatch(status)) return status;' \
            '  if (status != null) return status;'

control "ب) الرسالةُ تبقى JSON خاماً" \
  sub "$SB" "    return '\$prefix\${_bodyMessage(error.message) ?? error.message}\$hint';" \
            "    return '\$prefix\${error.message}\$hint';"

control "ج) المحاولاتُ الصامتةُ تعود اثنتين" \
  sub "$SB" '  Duration(seconds: 3),
  Duration(seconds: 4),
' ''

control "د) نصُّ المطوّر يعود لما لا رمزَ له" \
  sub "$ROOT" "  _ => tr('انقطاعٌ مؤقّتٌ من جهتنا، وبياناتك محفوظة.\\nأعد المحاولة بعد لحظات.')," \
            "  _ => 'إن كنت لم تُطبّق ملفات مجلّد supabase/ على المشروع بعد فابدأ بها.',"

control "هـ) التفاصيلُ التقنيّةُ تعود إلى الشاشة" \
  sub "$ROOT" '                ? ErrorBlock(message: offlineMessage, onRetry: session.refreshIdentity)
                : QuietError(' '                ? ErrorBlock(message: offlineMessage, onRetry: session.refreshIdentity)
                : session.identityError != null
                ? ErrorBlock(message: identityHint(code, drift), details: session.identityError)
                : QuietError('

control "و) نجمتا التنسيق تُرسمان حرفاً" \
  sub "$ROOT" "[clockSkewLabel(drift)!.replaceAll('**', '')]" "[clockSkewLabel(drift)!]"

control "ز) عنوانُ الساعة لا يظهر لمن ساعتُه هو المتقدّمة" \
  sub "$ROOT" "    _clockIsOff(code, drift) ? tr('ساعة جوالك غير مضبوطة') : tr('تعذّر فتح حسابك الآن');" \
              "    tr('تعذّر فتح حسابك الآن');"

echo
echo "== الحصيلة: $pass سقطت، $fail لم تسقط =="
[ "$fail" -eq 0 ]
