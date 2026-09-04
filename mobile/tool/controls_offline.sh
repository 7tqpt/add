#!/usr/bin/env bash
# ضوابطُ سالبةٌ لاختبارات انقطاع الشبكة.
#
# **و`flutter` ليست في المسار افتراضاً هنا** — وقد سبق أن نجحت ثمانيةُ
# ضوابطَ في هذا المشروع وهي كذبٌ كلُّها، لأنّ الغلاف قرأ «command not found»
# نجاحاً. فيُصدَّر المسار، ويُشترط أساسٌ أخضرُ أوّلاً، ويُشترط سطرُ فشلٍ
# حقيقيٌّ لا مجرّدُ رمز خروج.
set -u
export PATH=/opt/flutter/bin:$PATH
cd "$(dirname "$0")/.."

SB=lib/src/data/supabase.dart
KIT=lib/src/ui/kit.dart
ROOT=lib/src/screens/root.dart
TEST=test/offline_test.dart

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

echo "== الأساس =="
flutter test "$TEST" 2>&1 | grep -q 'All tests passed' \
  || { echo "الأساسُ أحمر"; exit 1; }
echo "أخضر."

for f in "$SB" "$KIT" "$ROOT"; do cp "$f" "/tmp/$(basename "$f").bak"; done
restore() { for f in "$SB" "$KIT" "$ROOT"; do cp "/tmp/$(basename "$f").bak" "$f"; done; }
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

control "أ) لا يُعرف الانقطاع أصلاً" \
  sub "$SB" "  final text = error.toString();
  return _offlineMarks.any(text.contains);" "  return false;"

control "ب) علامةُ SocketException تسقط" \
  sub "$SB" "  'SocketException',
" ""

control "ج) علامةُ ClientException تسقط — ومنها يصل أكثرُ ما يقع" \
  sub "$SB" "  'ClientException',
" ""

control "ج٢) علامةُ HttpException تسقط" \
  sub "$SB" "  'HttpException',
" ""

control "ج٣) علامةُ HandshakeException تسقط" \
  sub "$SB" "  'HandshakeException',
" ""

control "ج٤) علامةُ TimeoutException تسقط" \
  sub "$SB" "  'TimeoutException',
" ""

control 'د) messageOf تُخرج نصَّ العطب خاماً' \
  sub "$SB" '  if (isOffline(error)) return offlineMessage;
  if (error is PostgrestException) {' '  if (error is PostgrestException) {'

control 'هـ) errorCodeOf لا تعطي رمزَ الانقطاع' \
  sub "$SB" '  if (isOffline(error)) return offlineCode;
' ''

control "و) ردُّ الخادم يُقرأ انقطاعاً" \
  sub "$SB" '  if (error is PostgrestException) return false;
  if (error is StorageException) return false;
  if (error is AuthException && error.statusCode != null) return false;
' ''

control "ز) الخمسمئةُ تُقرأ انقطاعاً" \
  sub "$SB" '  if (error is AuthException && error.statusCode != null) return false;' ''

control "ح) لا وجهَ للانقطاع — يُعرض بوجه العطب" \
  sub "$KIT" '    if (message == offlineMessage) return _offline(context);' ''

control "ط) الرمزُ غيرُ العالميّ" \
  sub "$KIT" '              Icons.wifi_off_rounded,' '              Icons.error_outline,'

control "ي) النصُّ التقنيّ يظهر في وجه الانقطاع" \
  sub "$KIT" '    if (message == offlineMessage) return _offline(context);

    final technical = details?.trim();' '    final technical = details?.trim();
    if (message == offlineMessage && technical == null) return _offline(context);'

control "ك) المقطوعُ يُرسَل إلى مجلّد supabase/" \
  sub "$ROOT" '  offlineCode => offlineMessage,' ''

echo
echo "== الحصيلة: $pass سقطت، $fail لم تسقط =="
[ "$fail" -eq 0 ]
