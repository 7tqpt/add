#!/usr/bin/env bash
# ضوابطُ سالبةٌ للشريط العلوي.
#
# كلُّ ضابطٍ يكسر ضمانةً واحدةً في الشيفرة الحيّة ثمّ يشغّل الحزمة: إن بقيت
# خضراءَ فالحارسُ لا يحرس. والملفّاتُ تُعاد كما كانت في كلّ حال.
set -uo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

KIT=lib/src/ui/kit.dart
SHELL=lib/src/screens/customer_shell.dart
BACKUP=$(mktemp -d)
cp "$KIT" "$BACKUP/kit.dart"
cp "$SHELL" "$BACKUP/shell.dart"
restore() { cp "$BACKUP/kit.dart" "$KIT"; cp "$BACKUP/shell.dart" "$SHELL"; }
trap 'restore; rm -rf "$BACKUP"' EXIT

PASS=0; FAIL=0

# sub <ملف> <قديم> <جديد> — ويرفض ما لا يطابق مرّةً واحدةً بالضبط.
sub() {
  local file="$1" old="$2" new="$3"
  local n
  n=$(python3 - "$file" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then
    echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1
  fi
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
  if timeout 300 flutter test test/header_test.dart >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 flutter test test/header_test.dart >/dev/null 2>&1; then
  echo "أخضر."
else
  echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1
fi

echo
echo "== الضوابط =="

# أ) الجرسُ يُنقل إلى يسار الشريط والرسائلُ إلى يمينه.
run "أ) الجرسُ يساراً والرسائلُ يميناً" sub "$SHELL" \
  'start: BellIconButton(unread: _alerts, onTap: _openAlerts),
          end: ChatIconButton(unread: _unread, onTap: _openChats),' \
  'start: ChatIconButton(unread: _unread, onTap: _openChats),
          end: BellIconButton(unread: _alerts, onTap: _openAlerts),'

# ب) حشوةُ العنوان تصير من جانبٍ واحد، فيميل وسطُه عن وسط الشريط.
#
# (وكانت المرساةُ أوّلاً `alignment: Alignment.center` — وهي مكتوبةٌ في أربعة
# مواضعَ من الملفّ، فلم يقع كسرٌ أصلاً وبقيت الحزمةُ خضراءَ بلا معنى. أبلغ
# الحارسُ عن ذلك ولم يمرّ صامتاً.)
run "ب) العنوانُ يميل عن وسط الشريط" sub "$KIT" \
  'padding: const EdgeInsets.symmetric(horizontal: 56),' \
  'padding: const EdgeInsets.only(right: 56),'

# ج) حشوةُ العنوان تُلغى فيزحف تحت الرموز.
run "ج) العنوانُ يزحف تحت الأيقونات" sub "$KIT" \
  'padding: const EdgeInsets.symmetric(horizontal: 56),' \
  'padding: EdgeInsets.zero,'

# د) السطحُ ثابتٌ فيظهر فوق شاشةٍ لم تُمرَّر.
run "د) سطحٌ ثابتٌ فوق شاشةٍ لم تُمرَّر" sub "$KIT" \
  'color: Colors.white.withValues(alpha: scrolled ? 0.82 : 0),' \
  'color: Colors.white.withValues(alpha: 0.82),'

# هـ) السطحُ لا يظهر أبداً فيمرّ المحتوى تحت رأسٍ بلا زجاج.
run "هـ) لا سطحَ أبداً ولو مرّ المحتوى" sub "$KIT" \
  'color: Colors.white.withValues(alpha: scrolled ? 0.82 : 0),' \
  'color: Colors.white.withValues(alpha: 0),'

# هـ٢) التمويهُ يعمل في الحالتين — فتبيضّ حافّتُه فوق شاشةٍ لم تُمرَّر.
run "هـ٢) تمويهٌ يعمل بلا سطح" sub "$KIT" \
  'sigmaX: scrolled ? 20 : 0,
          sigmaY: scrolled ? 20 : 0,' \
  'sigmaX: 20,
          sigmaY: 20,'

# و) الشعرةُ لا تظهر.
run "و) لا شعرةَ تفصل الرأسَ عن المحتوى" sub "$KIT" \
  'color: scrolled ? AppColors.hairline : Colors.transparent,' \
  'color: Colors.transparent,'

# ز) الإصغاءُ يقبل التمرير الأفقيّ كذلك.
run "ز) تمريرةٌ أفقيّةٌ تُظهر الزجاج" sub "$KIT" \
  'if (n.metrics.axis != Axis.vertical) return false;' \
  ''

# ح) تبديلُ التبويب لا يعيد الرأسَ إلى حاله.
run "ح) الزجاجُ يبقى بعد تبديل التبويب" sub "$KIT" \
  'if (old.tab != widget.tab) _under = false;' \
  ''

# ط) المسافةُ تساوي الشريط، فيبدأ المحتوى خلف الزجاج.
run "ط) المحتوى يبدأ خلف الزجاج" sub "$KIT" \
  'const double glassHeaderSpace = glassHeaderBar + Space.sm;' \
  'const double glassHeaderSpace = glassHeaderBar;'

# ي) القرصُ الأبيضُ يعود تحت الرموز.
run "ي) عودةُ القرص الأبيض تحت الرمز" sub "$KIT" \
  'style: IconButton.styleFrom(foregroundColor: AppColors.ink2),' \
  'style: IconButton.styleFrom(foregroundColor: AppColors.ink2, backgroundColor: Colors.white),'

# ك) الرمزُ يُصبغ أبيضَ — وهو ما كان يمرّ حين كانت الألوانُ تُقرأ من اللوح.
run "ك) رمزٌ أبيضُ لا يُقرأ" sub "$KIT" \
  'style: IconButton.styleFrom(foregroundColor: AppColors.ink2),' \
  'style: IconButton.styleFrom(foregroundColor: Colors.white),'

# ل) حبّةُ العدد تطفو بعيداً عن رمزها.
run "ل) الحبّةُ تطفو بعيداً عن رمزها" sub "$KIT" \
  'top: 7,
          left: 7,' \
  'top: -30,
          left: -30,'

echo
echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
