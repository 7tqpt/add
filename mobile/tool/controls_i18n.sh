#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحارس الترجمة.
#
# **وهذا حارسٌ يحرس حارساً.** الحزمةُ كلُّها تبقى خضراءَ ولو كانت الترجمةُ
# ميّتة — لا شيءَ في التطبيق ينكسر حين يُعرض نصٌّ بالعربيّة في شاشةٍ
# إنجليزيّة. فإن لم يبِنْ هذا الحارسُ عن العطب فلا شيءَ يبين.
set -uo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/i18n_test.dart

FILES=(
  lib/src/core/format.dart
  lib/src/ui/kit.dart
  lib/src/screens/home.dart
  lib/src/screens/customer_shell.dart
  lib/src/core/strings_en.dart
)
BACKUP=$(mktemp -d)
for f in "${FILES[@]}"; do cp "$f" "$BACKUP/$(basename "$f")"; done
restore() { for f in "${FILES[@]}"; do cp "$BACKUP/$(basename "$f")" "$f"; done; }
trap 'restore; rm -rf "$BACKUP"' EXIT

PASS=0; FAIL=0

sub() {
  local file="$1" old="$2" new="$3" n
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
  if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

K=lib/src/ui/kit.dart
H=lib/src/screens/home.dart
S=lib/src/screens/customer_shell.dart
E=lib/src/core/strings_en.dart
F=lib/src/core/format.dart

echo "== الأساس =="
if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
  echo "أخضر."
else
  echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1
fi

echo
echo "== الضوابط =="

# أ) نصٌّ يُنزع عنه النداءُ في ملفٍّ أُعلن أنّه مترجَم.
run "أ) نصٌّ يعود بلا ترجمة" sub "$H" \
  "                Expanded(child: SectionTitle(tr('خدماتٌ لك')))," \
  "                const Expanded(child: SectionTitle('خدماتٌ لك')),"

# ب) نصٌّ **جديدٌ** يُضاف بلا نداء — وهو الطريقُ الذي تعود منه العلّةُ فعلاً:
#    لا أحدَ ينزع `tr` من نصٍّ قائم، وإنّما يُكتب نصٌّ جديدٌ فيُنسى.
run "ب) نصٌّ جديدٌ يُكتب بلا نداء" sub "$S" \
  "  void _goTo(int i) => setState(() => _index = i);" \
  "  static const _hint = 'اسحب لليمين';
  void _goTo(int i) => setState(() => _index = i);"

# ج) نصٌّ منادىً عليه ولا مدخلَ له — **وهو أخطرُها**: `tr` لا ترمي حين لا
#    تجد بل تعيد العربيّ، فتبقى الشاشةُ عربيّةً بلا شكوى.
run "ج) نداءٌ بلا مدخلٍ في المعجم" sub "$E" \
  "  'خدماتٌ لك': 'Services for you'," \
  "  'خدماتٌ لكم': 'Services for you',"

# د) مدخلٌ يُضاف ولا يُنادى — معجمٌ يكبر بما لا يُستعمل يوهم بتغطيةٍ لا
#    وجودَ لها، وهي الحالُ التي كانت: ٢٩٣ مدخلاً وأربعةُ ملفّاتٍ تنادي.
run "د) مداخلُ ميّتةٌ تزداد" sub "$E" \
  "const Map<String, String> englishStrings = {" \
  "const Map<String, String> englishStrings = {
  'نصٌّ لا ينادى به ١': 'x1',
  'نصٌّ لا ينادى به ٢': 'x2',"

# هـ) علامةُ الإعفاء تُوضع على نصِّ واجهةٍ حقيقيّ — لو قُبلت بلا سببٍ
#     لَصارت باباً يُهرَّب منه كلُّ نصّ.
#
#     (ولم يسقط أوّلَ مرّة: الحارسُ لا يقرأ السببَ ولا يستطيع. فأُضيف إليه
#     **عدُّ الإعفاءات وسقفٌ لها** — لا يُقرأ السببُ ولكن تُعدّ العلامات،
#     وزيادةُ واحدةٍ تُسقط الحزمةَ حتى يُرفع السقفُ بيدٍ ظاهرة.)
run "هـ) إعفاءٌ يُوضع على نصِّ واجهة" sub "$H" \
  "                TextButton(onPressed: widget.onExplore, child: Text(tr('المزيد')))," \
  "                // i18n-ignore
                TextButton(onPressed: widget.onExplore, child: const Text('المزيد')),"

# ── صيغُ العدد ───────────────────────────────────────────────────────────────

# و) الإنجليزيّةُ تمرّ بالفرع العربيّ — وهي العلّةُ التي بُني هذا كلُّه لأجلها:
#    نصٌّ يصحّ صدفةً وبنيةٌ خاطئة.
run "و) الإنجليزيّةُ من فرع العربيّة" sub "$F" \
  "  if (appLocale.value == AppLocale.en) {
    return n == 1 ? forms.enOne : '\${_int.format(n)} \${forms.enMany}';
  }
" \
  ""

# ز) المثنّى يُلغى فيُقرأ «2 يوم» — نصٌّ مكسورٌ لا تقريبٌ مقبول.
run "ز) المثنّى العربيُّ يسقط" sub "$F" \
  "  if (n == 2) return forms.two;" \
  ""

# ح) جمعُ القلّة يُوسَّع إلى ما فوق العشرة — «11 أيام».
run "ح) جمعُ القلّة يتجاوز العشرة" sub "$F" \
  "  if (n >= 3 && n <= 10) return '\${_int.format(n)} \${forms.few}';" \
  "  if (n >= 3) return '\${_int.format(n)} \${forms.few}';"

# ط) «منذ» تعود سابقةً تُلصق بالجمع — فتخرج «ago 3 hours».
run "ط) «منذ» تُلصق بالجمع" sub "$F" \
  "  String said(String amount) =>
      future ? trf('بعد {0}', [amount]) : trf('منذ {0}', [amount]);" \
  "  String said(String amount) => '\${future ? tr('بعد') : tr('منذ')} \$amount';"

# ي) اسمُ الشهر يُثبَّت على العربيّة.
run "ي) الشهرُ عربيٌّ في الإنجليزيّة" sub "$F" \
  "DateFormat get _month => DateFormat('MMMM', _intlLocale);" \
  "DateFormat get _month => DateFormat('MMMM', 'ar');"

# (وكان هنا ضابطٌ سادس: يُشقّ نصٌّ ملصوقٌ `'أ' 'ب'` فيُنتظَر سقوطُ الحزمة.
# ولم تسقط — **وهي على حقّ**: Dart تلصق المتلاصقات قبل أن تُمرَّر، فتصل
# `tr()` النصَّ نفسَه ويُوجد في المعجم. أي أنّ الكسرَ لا يكسر شيئاً على
# الجهاز، فضابطٌ يطلب سقوطاً من حارسٍ يقول الصدقَ ضابطٌ خاطئ. حُذف.)

echo
echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
