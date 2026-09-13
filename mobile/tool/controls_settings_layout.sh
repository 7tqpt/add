#!/usr/bin/env bash
# ضوابطُ سالبةٌ لترتيب «الإعدادات».
#
# **وما لا يسقط بالكسر ضمانةٌ كاذبة.** وأدقُّها هنا الأوّل: بندُ «شارك
# التطبيق» يغيب من نفسه في وضع العرض، فاختبارٌ يسأل الشجرةَ يمرّ سواءٌ حُذف
# أم لم يُحذف. فيُكسر بإعادته كاملاً — مستورداً ومُنادىً — ويُنظر أتحمرّ.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/settings_layout_test.dart
A=lib/src/screens/account_extras.dart
B=lib/src/ui/share_button.dart
C=lib/src/core/share.dart

BACKUP=$(mktemp -d); cp "$A" "$BACKUP/a"; cp "$B" "$BACKUP/b"; cp "$C" "$BACKUP/c"
restore() { cp "$BACKUP/a" "$A"; cp "$BACKUP/b" "$B"; cp "$BACKUP/c" "$C"; }
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

# أ) **البندُ يعود كاملاً** — صنفاً في `share_button.dart`، ومستورداً
#    ومُنادىً في الإعدادات. ولا يُكتفى بإعادة النداء وحدَه: شيفرةٌ لا
#    تُصرَّف تُحمِّر الحزمةَ بلا أن تقول شيئاً عن الضمانة.
break_share() {
  sub "$B" "/// ما ينفّذ المشاركة فعلاً — يُبدَّل في الاختبار." \
           "class ShareAppTile extends StatelessWidget {
  const ShareAppTile({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// ما ينفّذ المشاركة فعلاً — يُبدَّل في الاختبار." || return 1
  sub "$A" "import '../core/theme.dart';" \
           "import '../core/theme.dart';
import '../ui/share_button.dart';" || return 1
  sub "$A" "                SectionTitle(tr('الإشعارات'))," \
           "                const ShareAppTile(),
                SectionTitle(tr('الإشعارات'))," || return 1
}
run "أ) بندُ «شارك التطبيق» يعود" break_share

# ب) **ونغمةُ الإشعار تخرج إلى بطاقةٍ ثانية** تحت العنوان نفسِه — فتُقرأ
#    قسماً بلا اسم، وهو ما شكا منه صاحبُ المنصّة بلفظ «رتّبها».
run "ب) النغمةُ في بطاقةٍ ثانية" sub "$A" \
  "                    const Divider(height: 1, color: AppColors.hairline),
                    // ── نغمةُ الإشعار ─────────────────────────────────────" \
  "                  ],
                ),
                const SizedBox(height: Space.sm),
                AppCard(
                  children: [
                    // ── نغمةُ الإشعار ─────────────────────────────────────"

# ج) **والعنوانُ يعود «قفل التطبيق»** — فيضيق عن البصمة التي تحته.
run "ج) العنوانُ يضيق" sub "$A" \
  "                SectionTitle(tr('الخصوصية والأمان'))," \
  "                SectionTitle(tr('قفل التطبيق')),"

# د) **ورقمُ النسخة يخرج إلى الفراغ** تحت آخر بطاقة — فيُقرأ بقيّةً نُسيت.
run "د) رقمُ النسخة في الفراغ" sub "$A" \
  "                    const Divider(height: 1, color: AppColors.hairline),
                    // **ورقمُ النسخة داخلَ البطاقة لا معلّقاً في الفراغ.**" \
  "                  ],
                ),
                const SizedBox(height: Space.xl),
                Center(child: Muted(appVersionLabel, size: 11)),
                if (false) AppCard(
                  children: [
                    // **ورقمُ النسخة داخلَ البطاقة لا معلّقاً في الفراغ.**"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
