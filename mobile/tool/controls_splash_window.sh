#!/usr/bin/env bash
# ضوابطُ سالبةٌ لنافذة الإقلاع.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وكسورُ هذه الجولة ملفّاتٌ لا أسطر**: العطبُ الأصليُّ كان ملفّاً زائداً
# يغلب المرئيَّ، وكثافةٌ تُنسى ملفٌّ ناقص. فالضابطُ يزيد ويحذف كما يبدّل.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/splash_window_test.dart"
RES=android/app/src/main/res

BACKUP=$(mktemp -d)
cp -r "$RES" "$BACKUP/res"
restore() { rm -rf "$RES"; cp -r "$BACKUP/res" "$RES"; }
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
  if timeout 600 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== العطبُ الأصليُّ يعود =="

# ── أ) يعود الملفُّ الثاني الذي يغلب المرئيّ ──────────────────────────────
#
# **وهو ما شكا منه بعينه**: ملفٌّ لا ينظر إليه أحدٌ يغلب على كلّ جهازٍ
# صُنع بعد ٢٠١٤، ويسأل النظامَ عن لونه فيعطيه أبيض.
revive_v21() {
  mkdir -p "$RES/drawable-v21"
  cat > "$RES/drawable-v21/launch_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="?android:colorBackground" />
</layer-list>
XML
}
run "(أ) يعود ملفُّ drawable-v21" revive_v21

# ── ب) ويعود توأمٌ صحيحُ اللون ─────────────────────────────────────────────
#
# **والضابطُ الأدقُّ من سابقه**: توأمٌ بلونٍ سليمٍ لا يُمسك بسؤال «أبيضُ
# هو؟» — ويُمسك بأنّ النافذةَ مكتوبةٌ مرّتين. ولولاه لَكانت الضمانةُ
# «لا بياضَ» لا «لا توأمَ»، ولعاد الافتراقُ من بابٍ آخر.
twin_ok() {
  mkdir -p "$RES/drawable-v21"
  cp "$RES/drawable/launch_background.xml" "$RES/drawable-v21/launch_background.xml"
}
run "(ب) توأمٌ صحيحُ اللون" twin_ok

echo; echo "== ما في النافذة =="

# ── ج) وتذهب العلامةُ فيبقى اللونُ وحدَه ──────────────────────────────────
#
# أي يعود الخيارُ (أ) وقد اختار (ب) — تبديلٌ صامتٌ لقرارٍ اتُّخذ.
run "(ج) لا علامةَ في النافذة" \
  sub "$RES/drawable/launch_background.xml" \
"    <item android:bottom=\"58dp\">
        <bitmap
            android:gravity=\"center\"
            android:src=\"@drawable/launch_mark\" />
    </item>" \
"    <!-- ذهبت -->"

# ── د) وتُمدّ العلامةُ على الشاشة بدل أن تتوسّطها ─────────────────────────
run "(د) العلامةُ ممدودةٌ لا متوسّطة" \
  sub "$RES/drawable/launch_background.xml" \
"            android:gravity=\"center\"" \
"            android:gravity=\"fill\""

# ── هـ) وتتوسّط العلامةُ تماماً فتقفز عند أوّل إطار ───────────────────────
#
# **وهذه تنكسر بصمت**: النافذةُ سليمةٌ وحدَها والشاشةُ سليمةٌ وحدَها،
# والعيبُ قفزةٌ صغيرةٌ بينهما لا يُعرف سببُها.
run "(هـ) العلامةُ متوسّطةٌ فتقفز" \
  sub "$RES/drawable/launch_background.xml" \
"    <item android:bottom=\"58dp\">" \
"    <item>"

# ── و) وترتفع بقدرٍ خطأ ───────────────────────────────────────────────────
#
# الضابطُ الأدقُّ من سابقه: وجودُ الحشوة لا يكفي — يجب أن تساوي ضعفَ ما
# ترتفعه العلامةُ في `BootScreen`، وذاك مقيسٌ من الشاشة لا مكتوبٌ حفظاً.
run "(و) ترتفع بقدرٍ خطأ" \
  sub "$RES/drawable/launch_background.xml" \
"    <item android:bottom=\"58dp\">" \
"    <item android:bottom=\"120dp\">"

echo; echo "== الألوان =="

# ── ز) ويفترق لونُ النافذة عن لون الشاشة التي تليها ───────────────────────
#
# **وهذه تنكسر بصمت**: لا بناءَ يسقط ولا اختبارَ يحمرّ، وتُرى ومضةً في
# عُشر ثانيةٍ لا يراها من عدّلها.
run "(ز) لونٌ غيرُ لون BootScreen" \
  sub "$RES/values/colors.xml" \
"<color name=\"brand_splash\">#5C0820</color>" \
"<color name=\"brand_splash\">#7B0F2E</color>"

# ── ح) ويعود ما بعد النافذة كريماً ────────────────────────────────────────
run "(ح) ومضةٌ فاتحةٌ بعد النافذة" \
  sub "$RES/values/styles.xml" \
"    <style name=\"NormalTheme\" parent=\"@android:style/Theme.Light.NoTitleBar\">
        <item name=\"android:windowBackground\">@color/brand_splash</item>" \
"    <style name=\"NormalTheme\" parent=\"@android:style/Theme.Light.NoTitleBar\">
        <item name=\"android:windowBackground\">@color/brand_page</item>"

echo; echo "== أندرويد ١٢ =="

# ── ط) وتذهب شاشةُ النظام فيعود بياضُه على الأجهزة الحديثة ────────────────
#
# **وهو أخطرُ ما في الجولة**: إصلاحُ النافذة وحدَه يُرى أخضرَ هنا ويُبقي
# الشكوى قائمةً على جوّاله هو.
drop_v31() { rm -f "$RES/values-v31/styles.xml"; }
run "(ط) لا لونَ لشاشة أندرويد ١٢" drop_v31

echo; echo "== الكثافات =="

# ── ي) وتُنسى كثافةٌ واحدة ────────────────────────────────────────────────
drop_density() { rm -f "$RES/drawable-xxhdpi/launch_mark.png"; }
run "(ي) كثافةٌ ناقصة" drop_density

# ── ك) وتُكتب بمقاسٍ خطأ ──────────────────────────────────────────────────
#
# الضابطُ المعكوس لسابقه: ملفٌّ موجودٌ بمقاسٍ خطأ يُبنى ويعمل ويخرج
# مشوَّهاً — فلا يكفي أن يُسأل «أموجودٌ هو؟».
wrong_size() {
  python3 - <<'PY'
from PIL import Image
p = 'android/app/src/main/res/drawable-xxhdpi/launch_mark.png'
Image.open(p).resize((208, 208), Image.LANCZOS).save(p)
PY
}
run "(ك) مقاسٌ خطأ لكثافة" wrong_size

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
