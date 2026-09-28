#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقةِ الخدمة — «استكشف» و«المفضّلة» وقائمةُ خدمات المزوّد.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`
# ثمّ يعيدها، فحزمةٌ تجري في أثناء ذلك تقرأ شيفرةً مكسورةً وتحمرّ بلا سبب.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/service_card_test.dart test/nearest_test.dart test/favourites_test.dart"
F=lib/src/ui/service_card.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"
restore() { cp "$BACKUP/f" "$F"; }
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
  if timeout 900 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 900 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الغلاف =="

# ── أ) يعود مربّعاً إلى جانب الاسم ──────────────────────────────────────
#
# **وهو ما كان قبل تصميم صاحب المنصّة**: ‎٧٦×٧٦‎ إلى جانب العنوان.
run "(أ) الغلافُ مربّعٌ لا بعرض البطاقة" \
  sub "$F" \
"      height: coverHeight,
      width: double.infinity," \
"      height: coverHeight,
      width: 76,"

# ── ب) ويقصر ارتفاعُه عن المعلن ────────────────────────────────────────
#
# فتتعرّج القائمةُ: بطاقةٌ بغلافٍ عالٍ وأخرى بغلافٍ قصير.
run "(ب) ارتفاعُ الغلاف غيرُ المعلن" \
  sub "$F" \
"      height: coverHeight,
      width: double.infinity," \
"      height: coverHeight - 20,
      width: double.infinity,"

# ── ج) ومن لا غلافَ له يعود إلى المربّع الباهت ─────────────────────────
#
# **وهذا ما تسقطه قراءةُ البكسلات وحدَها**: `MediaThumb` بلا رابطٍ يرسم
# لوحَ `surface2` بأيقونة صورة — عنصرٌ قائمٌ كالتدرّج، والشجرةُ لا تفرّق.
run "(ج) لوحٌ باهتٌ مكان التدرّج" \
  sub "$F" \
"          _LetterGround(title: item.title),
          if (item.coverPath != null)
            MediaThumb(url: Api.mediaUrl(item.coverPath), blank: true)," \
"          MediaThumb(url: Api.mediaUrl(item.coverPath)),"

# ── د) والحرفُ يذهب فيبقى التدرّجُ أصمّ ────────────────────────────────
#
# تدرّجٌ بلا حرفٍ لا يقول أيَّ خدمةٍ هو — وهو نصفُ الضمانة.
run "(د) تدرّجٌ بلا حرف" \
  sub "$F" \
"        title.trim().isEmpty ? tr('؟') : title.trim().characters.first," \
"        ''," 

echo; echo "== الزرّ والقلب =="

# ── هـ) ويفقد الزرُّ مفتاحَه ───────────────────────────────────────────
#
# **فيُقاس بالنصّ**: عشرون بطاقةً في الشاشة بالنصّ نفسِه، فيُلتقط أوّلُها
# ويُظنّ أنّ كلَّ زرٍّ قيس.
run "(هـ) زرُّ التفاصيل بلا مفتاح" \
  sub "$F" \
"                key: ValueKey('open-\${item.id}')," \
"                key: const ValueKey('open'),"

# ── و) والزرُّ زينةٌ لا باب ────────────────────────────────────────────
#
# **وهذا يخرج زرّاً يُضغط ولا يفعل**: البطاقةُ كلُّها تُضغط فتُفتح الخدمةُ
# من حولِه، فلا يُرى العطبُ بالعين.
run "(و) زرُّ التفاصيل لا يفتح" \
  sub "$F" \
"                key: ValueKey('open-\${item.id}'),
                onPressed: onOpen," \
"                key: ValueKey('open-\${item.id}'),
                onPressed: () {},"

# ── ز) والقلبُ يفقد سطحَه فتذهب ضغطتُه إلى البطاقة ────────────────────
#
# **وهذا أرجحُ ما يقع**: قرصٌ مرسومٌ بلا `InkWell` يبدو كالزرّ ولا يلتقط
# شيئاً، فتنزل الضغطةُ إلى `Pressable` البطاقةِ وتُفتح الخدمة.
run "(ز) القلبُ رسمٌ لا يلتقط" \
  sub "$F" \
"    child: InkWell(
      onTap: onTap," \
"    child: InkWell(
      onTap: null,"

echo; echo "== ما أسقطه التصميمُ وما أبقاه =="

# ── ح) ويعود القسمُ إلى السطر ──────────────────────────────────────────
run "(ح) القسمُ عاد إلى البطاقة" \
  sub "$F" \
"          '\${item.providerGovernorate}'
          '\${distanceSuffix(from, item.providerPoint)}'," \
"          '\${item.categoryName} · \${item.providerGovernorate}'
          '\${distanceSuffix(from, item.providerPoint)}',"

# ── ط) وتعود الوحدةُ إلى العربون ───────────────────────────────────────
run "(ط) الوحدةُ عادت إلى العربون" \
  sub "$F" \
"                  Muted(trf('العربون {0}٪', ['\${item.depositPercent}']), size: 12)," \
"                  Muted(trf('العربون {0}٪ · {1}', ['\${item.depositPercent}', item.unit]), size: 12),"

# ── ي) وتسقط شارتا فيديو وصوت ──────────────────────────────────────────
#
# أبقاهما صاحبُ المنصّة صراحةً حين أسقط ما عداهما.
run "(ي) شارتا فيديو وصوت سقطتا" \
  sub "$F" \
"                  if (item.hasVideo || item.hasAudio) ...[" \
"                  if (false) ...["

# ── ك) وتذهب المسافةُ من السطر ─────────────────────────────────────────
#
# **ومن رفع «الأقرب إليّ» يرى القائمةَ تتبدّل ولا يعرف لماذا.**
run "(ك) المسافةُ لا تُكتب" \
  sub "$F" \
"  if (from == null || to == null) return '';
  return ' · \${distanceLabel(distanceKm(from, to))}';" \
"  if (from == null || to == null) return '';
  return '';"

echo; echo "== الخطّ والشارة =="

# ── ل) ويعود الأسلوبُ العاري إلى `styleFrom` ──────────────────────────
#
# **فتُرسم «عرض التفاصيل» مربّعاتٍ بيضاء**: أسلوبٌ عارٍ يحلّ محلَّ أسلوب
# الثيمة كلِّه، ومعه عائلةُ الخطّ. وقد وقع في زرّ «إعادة فتح» وخرج في لقطة.
run "(ل) أسلوبٌ عارٍ يُذهب عائلةَ الخطّ" \
  sub "$F" \
"                  minimumSize: const Size.fromHeight(46),
                )," \
"                  minimumSize: const Size.fromHeight(46),
                  textStyle: const TextStyle(fontSize: 15.5),
                ),"

# ── م) وتعود «مميّز» إطاراً شفّافاً على الصورة ────────────────────────
#
# حدٌّ كهرمانيٌّ بحرفٍ كهرمانيٍّ فوق قاعةٍ مضاءةٍ بالذهب يذوب فيها.
run "(م) «مميّز» إطارٌ شفّافٌ على الغلاف" \
  sub "$F" \
"                    child: _FeaturedPill()," \
"                    child: StatusBadge('مميّز', color: AppColors.warning),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
