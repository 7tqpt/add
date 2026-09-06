#!/usr/bin/env bash
# ضوابطُ سالبةٌ لأربعةِ إصلاحاتٍ جاءت من لقطاتِ جهازٍ حقيقيّ.
set -u
export PATH=/opt/flutter/bin:$PATH
cd "$(dirname "$0")/.."

DET=lib/src/screens/service_detail.dart
LOCK=lib/src/screens/lock.dart
CORE=lib/src/core/app_lock.dart
KIT=lib/src/ui/kit.dart
EXTRAS=lib/src/screens/account_extras.dart
SHELL=lib/src/screens/customer_shell.dart
ACC=lib/src/screens/account.dart
VER=lib/src/core/app_version.dart
TEST=test/polish_test.dart

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

echo "== الأساس =="
flutter test "$TEST" 2>&1 | grep -q 'All tests passed' \
  || { echo "الأساسُ أحمر"; exit 1; }
echo "أخضر."

FILES=("$DET" "$LOCK" "$CORE" "$KIT" "$EXTRAS" "$SHELL" "$ACC" "$VER")
for f in "${FILES[@]}"; do cp "$f" "/tmp/pol.$(basename "$f").bak"; done
restore() { for f in "${FILES[@]}"; do cp "/tmp/pol.$(basename "$f").bak" "$f"; done; }
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

# ── ١) الصورة المكرّرة ──────────────────────────────────────────────────────

control "أ) الصورةُ تعود إلى موضعين — غلافاً ومعرضاً" \
  sub "$DET" '                showImages: widget.coverPath == null,' \
             '                showImages: true,'

control "ب) الغلافُ داخل انتظارِ الخدمة فلا موضعَ للطيران" \
  sub "$DET" '          if (widget.coverPath != null)
            Hero(' '          if (widget.coverPath != null && false)
            Hero('

# ── ٢) لوحة القفل ─────────────────────────────────────────────────────────

control "ج) المفتاحُ يعود إلى مقاسٍ ثابتٍ صغير" \
  sub "$LOCK" '        final w = (available / 3).clamp(64.0, 104.0);' \
              '        final w = 72.0;'

control "د) المفتاحُ يتمدّد بلا سقفٍ على الشاشات العريضة" \
  sub "$LOCK" '        final w = (available / 3).clamp(64.0, 104.0);' \
              '        final w = available / 3;'

# ── ٣) مهلة القفل ─────────────────────────────────────────────────────────

control "هـ) المغادرةُ لا تقفل" \
  sub "$CORE" '    if (!_enabled || _locked || !_left) return;
    _locked = true;' '    if (!_enabled || _locked || !_left) return;
    _locked = false;'

control "و) خياراتُ المهلة تعود إلى الإعدادات" \
  sub "$EXTRAS" "                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded," \
                 "                      Text(tr('بعد ربع ساعة')),
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded,"

# ── ٤) علامة التوثيق ──────────────────────────────────────────────────────

control "ز) العلامةُ تعود نبيذيّة" \
  sub "$KIT" 'const verifiedBlue = Color(0xFF1D9BF0);' \
             'const verifiedBlue = AppColors.accent;'

control "ح) صحُّها ليس أبيض فلا يُقرأ على الأزرق" \
  sub "$KIT" '            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}' '            color: AppColors.accentDeep,
          ),
        ),
      ),
    ),
  );
}'

control "ط) حجمُها ثابتٌ لا يتبع ما تجاوره" \
  sub "$KIT" '    child: SizedBox(
      width: size,
      height: size,' '    child: SizedBox(
      width: 18,
      height: 18,'

# ── ٥) الأيقونات ──────────────────────────────────────────────────────────

control "ي) رمزان متطابقان في قسمين" \
  sub "$KIT" "  'catering' => Icons.restaurant_outlined," \
             "  'catering' => Icons.festival_outlined,"

control "ك) قسمٌ يقع على الرمز الاحتياطيّ" \
  sub "$KIT" "  'printing' => Icons.print_outlined," \
             "  'printing' => Icons.category_outlined,"

control "ل) قسمٌ يأخذ رمزَ تبويبٍ من الشريط" \
  sub "$KIT" "  'planners' => Icons.celebration_outlined," \
             "  'planners' => Icons.fact_check_outlined,"

control "م) تقويمان متجاوران في الشريط كما كانا" \
  sub "$SHELL" '            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long,' '            icon: Icons.fact_check_outlined,
            activeIcon: Icons.fact_check,'

# ── ٦) رقمُ النسخة ────────────────────────────────────────────────────────

control "ن) «حسابي» تكتب رقماً بيدها كما كانت" \
  sub "$ACC" '        Center(child: Muted(appVersionLabel, size: 11)),' \
             "        const Center(child: Muted('الإصدار 1.0.0', size: 11)),"

control "ه٢) الإعدادات تكتب رقماً بيدها كما كانت" \
  sub "$EXTRAS" '                Center(child: Muted(appVersionLabel, size: 11)),' \
                "                Center(child: Muted(tr('الإصدار 1.0.0'), size: 11)),"

control "و٢) السطرُ لا يحمل رقمَ البناء فلا تُعرف الحزمة" \
  sub "$VER" "String get appVersionLabel => 'الإصدار \$appVersionName (\$appBuild)';" \
             "String get appVersionLabel => 'الإصدار \$appVersionName';"

# ── بطاقةُ القسم ─────────────────────────────────────────────────────────

control "ز٢) الاسمُ لا يُشقّ فيعود لفّاً في ثلاثة أسطرٍ متساوية" \
  sub "$KIT" "  final at = clean.indexOf(' و');" '  final at = -1;'

control "ح٢) يُشقّ عند واوٍ في وسط كلمةٍ لا في أوّلها" \
  sub "$KIT" "  final at = clean.indexOf(' و');" "  final at = clean.indexOf('و');"

control "ط٢) تتمّةٌ من حرفٍ تُقبل فيخرج سطرٌ لا يقول شيئاً" \
  sub "$KIT" '  if (tail.length < 3) return (head: clean, tail: '"''"');' ''

control "ي٢) أصلٌ من حرفٍ واحدٍ يُشقّ فيخرج سطرٌ لا يقول شيئاً" \
  sub "$KIT" '  if (at < 2) return (head: clean, tail: '"''"');' \
             '  if (at < 0) return (head: clean, tail: '"''"');'

control "ك٢) أرضيّةُ البطاقة تعود مصبوغةً بلون القسم" \
  sub "$KIT" '                  color: Colors.white,
                  border: Border.all(' \
             '                  gradient: LinearGradient(colors: [
                    Colors.white,
                    tone.withValues(alpha: 0.12),
                  ]),
                  border: Border.all('

control "ل٢) الأصلُ يُلفّ سطرين وله تتمّةٌ تحته" \
  sub "$KIT" '          maxLines: parts.tail.isEmpty ? 2 : 1,' '          maxLines: 2,'

control "م٢) الحشوةُ تعود اثني عشرَ فتفيض على شاشة ٣٢٠" \
  sub "$KIT" '                  vertical: Space.sm,
                ),' \
             '                  vertical: Space.md,
                ),'

control "ن٢) القرصُ يكبر فيفيض ما تحته" \
  sub "$KIT" '                      width: 34,
                      height: 34,' \
             '                      width: 48,
                      height: 48,'

echo
echo "== الحصيلة: $pass سقطت، $fail لم تسقط =="
[ "$fail" -eq 0 ]
