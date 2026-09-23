#!/usr/bin/env bash
# ضوابطُ سالبةٌ لأذون آيفون: كلُّ حزمةٍ تطلب إذناً لها تفسيرٌ في `Info.plist`.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وهذه الضمانةُ بالذات لا يقيسها شيءٌ غيرُها**: لا محلّلٌ ولا بناءُ حزمةٍ
# ولا جهازُ أندرويد. ونقصُها يقتل التطبيقَ على آيفون بلا رسالةٍ ولا سجلّ.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/ios_permissions_test.dart"
I=ios/Runner/Info.plist
B=pubspec.yaml

BACKUP=$(mktemp -d)
cp "$I" "$BACKUP/i"; cp "$B" "$BACKUP/b"
restore() { cp "$BACKUP/i" "$I"; cp "$BACKUP/b" "$B"; }
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

# ── أ) يُشال تفسيرُ الميكروفون ────────────────────────────────────────────
#
# **وهو العطبُ الذي كشفه الفحص.** التطبيقُ يُقتل عند أوّل ضغطةٍ على زرّ
# التسجيل في المحادثة، ولا يُقال لصاحبه لماذا.
run "(أ) لا تفسيرَ للميكروفون" \
  sub "$I" \
"	<key>NSMicrophoneUsageDescription</key>
	<string>لتسجيل رسالة صوتية ترسلها في المحادثة بدل كتابتها. ولا يُفتح الميكروفون إلا وأنت ضاغطٌ على زرّ التسجيل.</string>
" ""

# ── ب) ويُشال تفسيرُ Face ID ──────────────────────────────────────────────
run "(ب) لا تفسيرَ لبصمة الوجه" \
  sub "$I" \
"	<key>NSFaceIDUsageDescription</key>
	<string>لتفتح قفل «فرحتي» بوجهك بدل كتابة الرمز في كل مرة. والبصمة لا تُقرأ ولا تُحفظ عندنا ولا تُرسل إلى أي خادم.</string>
" ""

# ── ج) ويُشال تفسيرُ الموقع — وهو الذي كان موجوداً ─────────────────────────
#
# الضابطُ الذي يثبت أنّ الفحصَ يمرّ على القائمة كلِّها لا على الجديدَين.
run "(ج) لا تفسيرَ للموقع" \
  sub "$I" \
"	<key>NSLocationWhenInUseUsageDescription</key>" \
"	<key>NSLocationWhenInUseUsageDescriptionX</key>"

# ── د) ويُفرَّغ التفسيرُ ولا يُشال ────────────────────────────────────────
#
# **وهذه تنكسر بصمت.** فحصٌ يسأل «أالمفتاحُ موجود؟» يمرّ على `<string></string>`
# فارغة — ويردّها App Store، ويرى صاحبُ الجهاز نافذةَ إذنٍ بيضاءَ لا تقول
# لماذا يُطلب منه شيء.
run "(د) تفسيرُ الميكروفون فارغ" \
  sub "$I" \
"	<string>لتسجيل رسالة صوتية ترسلها في المحادثة بدل كتابتها. ولا يُفتح الميكروفون إلا وأنت ضاغطٌ على زرّ التسجيل.</string>" \
"	<string></string>"

# ── هـ) ويصير التفسيرُ إنجليزيّاً من قالب ─────────────────────────────────
#
# ونافذةُ الإذن تعرضه حرفاً لصاحب الجهاز — فيُقرأ تطبيقاً غيرَ مكتمل.
run "(هـ) تفسيرٌ إنجليزيٌّ من قالب" \
  sub "$I" \
"	<string>لتفتح قفل «فرحتي» بوجهك بدل كتابة الرمز في كل مرة. والبصمة لا تُقرأ ولا تُحفظ عندنا ولا تُرسل إلى أي خادم.</string>" \
"	<string>We need Face ID access for authentication purposes.</string>"

echo; echo "== والقائمةُ تنمو بنموّ pubspec =="

# ── و) ويُعمى الفحصُ عن `pubspec.yaml` كلِّه ──────────────────────────────
#
# **وهذا هو ما يحرسه الاختبارُ فعلاً**: ليس أنّ في `Info.plist` خمسةَ
# مفاتيحَ اليوم، بل أنّ كلَّ حزمةٍ في `pubspec.yaml` تُطالَب بمفاتيحها —
# فما دخلت سادسةٌ غداً إلّا وحمّرت الحزمةُ حتى يُكتب تفسيرُها.
#
# وقائمةُ حزمٍ فارغةٌ تُمرّر كلَّ شيءٍ وتخضرّ، وهي ضمانةٌ كاذبةٌ تامّة.
# فيُكسر رأسُ القسم ويُتأكَّد أنّ الحزمةَ تحمرّ.
#
# (ولا يُكسر باسم حزمةٍ لا وجودَ لها: `pub get` يسقط قبل الاختبار، فتحمرّ
# الحزمةُ لعطبٍ في الاعتماد لا لضمانةٍ سقطت — وهو ضابطٌ كاذبٌ يُقرأ صادقاً.)
run "(و) قسمُ dependencies لا يُقرأ" \
  sub "$B" \
"dependencies:
  flutter:
    sdk: flutter" \
"dependencies_x:
  flutter:
    sdk: flutter"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
