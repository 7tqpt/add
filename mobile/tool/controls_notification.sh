#!/usr/bin/env bash
# ضوابطُ سالبةٌ لنغمة الإشعار وقناتها.
#
# **و`flutter` ليست في المسار افتراضاً هنا** — وقد نجحت ثمانيةُ ضوابطَ في هذا
# المشروع مرّةً وهي كذبٌ كلُّها لأنّ الغلاف قرأ «command not found» نجاحاً.
#
# **ومهلةٌ على كلّ تشغيل:** كسرٌ جعل اختباراً يدور بلا نهاية مرّةً، فبقي
# `flutter test` معلَّقاً إحدى وأربعين دقيقةً والسكربتُ ينتظره صامتاً.
set -u
export PATH=/opt/flutter/bin:$PATH
cd "$(dirname "$0")/.."

KT=android/app/src/main/kotlin/ye/aras/aras/MainActivity.kt
XML=android/app/src/main/res/values/strings.xml
MAN=android/app/src/main/AndroidManifest.xml
DART=lib/src/core/notification_tone.dart
SCR=lib/src/screens/account_extras.dart
TEST=test/notification_tone_test.dart

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

echo "== الأساس =="
flutter test "$TEST" 2>&1 | grep -q 'All tests passed' \
  || { echo "الأساسُ أحمر"; exit 1; }
echo "أخضر."

FILES=("$KT" "$XML" "$MAN" "$DART" "$SCR")
for f in "${FILES[@]}"; do cp "$f" "/tmp/ntf.$(basename "$f").bak"; done
restore() { for f in "${FILES[@]}"; do cp "/tmp/ntf.$(basename "$f").bak" "$f"; done; }
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

# ── معرّفُ القناة في ثلاثة ملفّات ──────────────────────────────────────────

control "أ) البيانُ يشير إلى موردٍ آخر — إشعارٌ بلا قناة" \
  sub "$MAN" 'android:value="@string/notification_channel_id"' \
             'android:value="@string/app_name"'

control "ب) الشيفرةُ الأصليّةُ تكتب المعرّفَ نصّاً بدل قراءته من المورد" \
  sub "$KT" '        val id = getString(R.string.notification_channel_id)' \
            '        val id = "farhati_alerts"'

control "ج) القناةُ القديمةُ لا تُحذف فتبقى قناتان باسمٍ واحد" \
  sub "$KT" '        manager.deleteNotificationChannel(LEGACY_CHANNEL)' ''

control "د) القديمُ هو الحيُّ نفسُه — فلا قناةَ جديدةَ أصلاً" \
  sub "$KT" '        const val LEGACY_CHANNEL = "farhati_default"' \
            '        const val LEGACY_CHANNEL = "farhati_alerts"'

# ── إعدادُ الصوت ───────────────────────────────────────────────────────────

control "هـ) النغمةُ بلا مجرًى فتُشغَّل على مجرى الوسائط وتُكتم معه" \
  sub "$KT" '        channel.setSound(
            Settings.System.DEFAULT_NOTIFICATION_URI,
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )' ''

control "و) الأهمّيةُ تنزل فيُطوى الإشعارُ صامتاً" \
  sub "$KT" 'NotificationManager.IMPORTANCE_HIGH,' \
            'NotificationManager.IMPORTANCE_LOW,'

# ── الجسر ──────────────────────────────────────────────────────────────────

control "ز) اسمُ الجسر يختلف بين دارت وكوتلن فلا يعبر أحد" \
  sub "$DART" "const notificationBridge = MethodChannel('ye.aras.aras/notifications');" \
              "const notificationBridge = MethodChannel('ye.aras.aras/notifs');"

control "ح) الضغطةُ لا تفتح شاشةَ القناة" \
  sub "$SCR" '                        if (await openNotificationTone()) return;' ''

control "ط) تعذّرُ الفتح يرمي بدل أن يُعيد `false`" \
  sub "$DART" '  } on PlatformException {
    return false;' '  } on PlatformException {
    rethrow;'

echo
echo "== الحصيلة: $pass سقطت، $fail لم تسقط =="
[ "$fail" -eq 0 ]
