#!/usr/bin/env bash
# ضوابطُ سالبةٌ لترتيب الحجوزات ولحمولة الإشعار ولتقييد البطّاريّة.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

A=lib/src/data/api.dart
D=lib/src/data/demo.dart
M=lib/src/data/models.dart
K=android/app/src/main/kotlin/ye/aras/aras/MainActivity.kt
X=android/app/src/main/res/values/strings.xml
E=../supabase/functions/push/index.ts
S=lib/src/screens/account_extras.dart
T=lib/src/core/notification_tone.dart
X2=android/app/src/main/AndroidManifest.xml
P=lib/src/screens/provider_shell.dart

BACKUP=$(mktemp -d)
for f in "$A" "$D" "$M" "$K" "$X" "$E" "$S" "$T" "$X2" "$P"; do
  cp "$f" "$BACKUP/$(echo "$f" | tr '/.' '__')"
done
restore() {
  for f in "$A" "$D" "$M" "$K" "$X" "$E" "$S" "$T" "$X2" "$P"; do
    cp "$BACKUP/$(echo "$f" | tr '/.' '__')" "$f"
  done
}
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

# الحزمتان معاً: الترتيبُ في إحداهما والإشعارُ في الأخرى.
SUITES="test/booking_order_test.dart test/notification_tone_test.dart"

run() {
  local name="$1"; shift
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  # shellcheck disable=SC2086
  if timeout 300 flutter test $SUITES >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
# shellcheck disable=SC2086
if timeout 300 flutter test $SUITES >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الترتيب =="

# أ) «حجوزاتي» تعود إلى تاريخ العرس — فمن حجز للتوّ لا يجد حجزَه.
run "أ) حجوزاتي بتاريخ العرس" sub "$A" \
  "    if (!isSupabaseConfigured) return demoDelay(_newestFirst(demoBookings));" \
  "    if (!isSupabaseConfigured) return demoDelay([...demoBookings]..sort((a, b) => a.eventDate.compareTo(b.eventDate)));"

# ب) وطلباتُ المزوّد كذلك — وهي آكد: الشاشةُ تُفتح للردّ على ما وصل.
run "ب) الطلبات بتاريخ العرس" sub "$A" \
  "    if (!isSupabaseConfigured) return demoDelay(_newestFirst(demoProviderRequests));" \
  "    if (!isSupabaseConfigured) return demoDelay([...demoProviderRequests]..sort((a, b) => a.eventDate.compareTo(b.eventDate)));"

# ج) الترتيبُ يُقلَب: الأقدمُ أوّلاً.
run "ج) الأقدمُ أوّلاً" sub "$A" \
  "      [...rows]..sort((a, b) => b.createdAt.compareTo(a.createdAt));" \
  "      [...rows]..sort((a, b) => a.createdAt.compareTo(b.createdAt));"

# د) الطرازُ يكفّ عن قراءة وقت الإنشاء — فيصير الترتيبُ على فراغٍ لا يفرّق.
run "د) الطرازُ لا يقرأ وقتَ الإنشاء" sub "$M" \
  "    point: _pointOf(m),
    createdAt: (m['created_at'] ?? '') as String," \
  "    point: _pointOf(m),
    createdAt: '',"

# هـ) وقتُ الإنشاء يُشال من بيانات العرض — فيتساوى الجميعُ ولا يُقاس ترتيب.
run "هـ) لا وقتَ إنشاءٍ في العرض" sub "$D" \
  "    reference: 'BK-2026-000517',
    createdAt: _at(2)," \
  "    reference: 'BK-2026-000517',"

echo; echo "== الإشعار =="

# و) القناةُ في حمولة FCM تخالف القناةَ في أندرويد — فيسقط أندرويد إلى قناته
#    المجهولة، وهي بلا نغمة.
run "و) قناةُ الحمولة تخالف قناةَ الجهاز" sub "$E" \
  "                  channel_id: 'farhati_alerts'," \
  "                  channel_id: 'farhati_default',"

# ز) وتُشال أصلاً — فيُعتمد على وسم البيان وحده، وهو ما كان.
run "ز) لا قناةَ في الحمولة" sub "$E" \
  "                  channel_id: 'farhati_alerts'," \
  ""

# ح) أولويّةُ العرض تُشال — فيصل الإشعارُ صامتاً إلى الدرج ولا يظهر لافتة.
run "ح) لا أولويّةَ عرض" sub "$E" \
  "                  notification_priority: 'PRIORITY_HIGH'," \
  ""

# ط) والنغمةُ تُشال من الحمولة.
run "ط) لا نغمةَ في الحمولة" sub "$E" \
  "                  sound: 'default'," \
  ""

# ي) والقناةُ في أندرويد تُبدَّل ولا تُبدَّل في الحمولة — الكسرُ نفسُه من
#    الطرف الآخر، وهو الأرجحُ وقوعاً: من بدّل المعرّفَ في `strings.xml` نسي
#    دالّةَ الدفع.
run "ي) معرّفُ أندرويد يُبدَّل وحدَه" sub "$X" \
  "<string name=\"notification_channel_id\">farhati_alerts</string>" \
  "<string name=\"notification_channel_id\">farhati_alerts_v3</string>"

echo; echo "== تقييدُ البطّاريّة =="

# ك) جسرُ البطّاريّة يُعاد تسميتُه في كوتلن ولا يُعاد في دارت — جسرٌ لا يعبره
#    أحد، ولا يظهر إلّا على جهاز.
run "ك) اسمُ الجسر يختلف بين الطرفين" sub "$K" \
  "                    \"batteryUnrestricted\" -> result.success(batteryUnrestricted())" \
  "                    \"isBatteryUnrestricted\" -> result.success(batteryUnrestricted())"

# ل) إذنُ الحوار يُشال من البيان — فلا يُفتح الحوارُ أصلاً ويعود صاحبُ الجهاز
#    يبحث في قائمةٍ طويلة، وهو ما شكا منه صاحبُ المنصّة بعينه.
run "ل) لا إذنَ للحوار في البيان" sub "$X2" \
  "    <uses-permission android:name=\"android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS\"/>" \
  ""

# ل٢) والحوارُ يُسأل في كلّ فتحة — يُقرأ إلحاحاً فيُرفض أسرع، ثمّ يُطفأ
#     التطبيقُ كلُّه من الإشعارات.
run "ل٢) الحوارُ يعود في كلّ فتحة" sub "$T" \
  "  if (prefs.getBool(_askedKey) ?? false) return false;
  await prefs.setBool(_askedKey, true);" \
  ""

# ل٣) ويُسأل من هو معفىً أصلاً — فتُستهلك «المرّةُ الواحدة» على من لا حاجةَ
#     به، ولو قُيِّد جهازُه بعد شهرٍ لم يُسأل أبداً.
run "ل٣) يُسأل من لا قيدَ عليه" sub "$T" \
  "  if (await batteryProbe()) return false;" \
  ""

# ل٤) وقشرةُ المزوّد تكفّ عن السؤال — وهو الطرفُ الذي يصله طلبُ الحجز.
run "ل٤) قشرةُ المزوّد لا تسأل" sub "$P" \
  "    askBatteryExemptionOnce();" \
  ""

# م) والتحذيرُ يُعرض للجميع — صفُّ طمأنةٍ تُدرَّب العينُ على تخطّيه.
run "م) التحذيرُ يُعرض للجميع" sub "$S" \
  "                if (!_batteryOk) ...[" \
  "                if (true) ...["

# ن) والغيابُ يُقرأ تقييداً — فيظهر لكلّ صاحب آيفون تحذيرٌ عن شاشةٍ لا وجودَ
#    لها في جهازه.
run "ن) الجسرُ الغائبُ يُقرأ تقييداً" sub "$T" \
  "Future<bool> _batteryUnrestricted() => _ask('batteryUnrestricted', whenAbsent: true);" \
  "Future<bool> _batteryUnrestricted() => _ask('batteryUnrestricted', whenAbsent: false);"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
