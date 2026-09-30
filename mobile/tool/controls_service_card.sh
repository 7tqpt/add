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

# ── أ) يعود لوحاً بعرض البطاقة فتطول ───────────────────────────────────
#
# **وهو ما شكا منه صاحبُ المنصّة**: «صار حجم البطاقة كبير جدن» — ‎٣٩٧‎
# بكسلاً، لا يظهر في الشاشة إلّا اثنتان ونصف.
run "(أ) الغلافُ لوحٌ بعرض البطاقة فتطول" \
  sub "$F" \
"      height: coverSide,
      width: coverSide," \
"      height: 168,
      width: double.infinity,"

# ── ب) ويكبر ضلعُه عن المعلن ───────────────────────────────────────────
#
# فتتعرّج القائمةُ: بطاقةٌ بمربّعٍ كبيرٍ وأخرى بصغير.
run "(ب) ضلعُ الغلاف غيرُ المعلن" \
  sub "$F" \
"      height: coverSide,
      width: coverSide," \
"      height: coverSide + 24,
      width: coverSide + 24,"

# ── ج) ومن لا غلافَ له يعود إلى المربّع الباهت ─────────────────────────
#
# **وهذا ما تسقطه قراءةُ البكسلات وحدَها**: `MediaThumb` بلا رابطٍ يرسم
# لوحَ `surface2` بأيقونة صورة — عنصرٌ قائمٌ كالتدرّج، والشجرةُ لا تفرّق.
run "(ج) لوحٌ باهتٌ مكان التدرّج" \
  sub "$F" \
"            _LetterGround(title: item.title),
            if (item.coverPath != null)
              MediaThumb(url: Api.mediaUrl(item.coverPath), blank: true)," \
"            MediaThumb(url: Api.mediaUrl(item.coverPath)),"

# ── د) والحرفُ يذهب فيبقى التدرّجُ أصمّ ────────────────────────────────
#
# تدرّجٌ بلا حرفٍ لا يقول أيَّ خدمةٍ هو — وهو نصفُ الضمانة.
run "(د) تدرّجٌ بلا حرف" \
  sub "$F" \
"        title.trim().isEmpty ? tr('؟') : title.trim().characters.first," \
"        ''," 

echo; echo "== الزرّ والقلب =="

# ── هـ) ويذهب الحرفُ الذي يقول إنّ البطاقةَ تُضغط ──────────────────────
#
# **وزرُّ «عرض التفاصيل» ذهب حين قُصّرت البطاقة**، فبقي «التفاصيل ›» وحدَه
# يقول للعين إنّ هنا باباً. وبلا هذا بابٌ لا يُرى.
run "(هـ) لا حرفَ يقول إنّ البطاقةَ تُضغط" \
  sub "$F" \
"                            Text(
                              tr('التفاصيل')," \
"                            Text(
                              ''," 

# ── و) والبطاقةُ نفسُها تفقد بابَها ────────────────────────────────────
#
# **وهذا يخرج بطاقةً كتبت «التفاصيل ›» ولا تُفتح** — وعدٌ مرسوم.
run "(و) البطاقةُ لا تُفتح بالضغط" \
  sub "$F" \
"    return Pressable(
      onTap: onOpen," \
"    return Pressable(
      onTap: () {},"

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
"                            trf('العربون {0}٪', ['\${item.depositPercent}'])," \
"                            trf('العربون {0}٪ · {1}', ['\${item.depositPercent}', item.unit]),"

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

# ── ل) ويعود التقييمُ إلى سطر السعر فيضيق عليه ────────────────────────
#
# **وهذا وقع فعلاً في أوّل رسمةٍ للبطاقة القصيرة**: عمودُ النصّ إلى جانب
# مربّعٍ ‎٩٦‎ يضيق عن النطاق ومعه التقييم، فخرج «850,000 – 1,400…» —
# والطرفُ الأعلى هو نصفُ الخبر.
run "(ل) التقييمُ في سطر السعر فيضيق عليه" \
  sub "$F" \
"                    Text(
                      formatMoneyRange(item.price, item.priceTo),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    )," \
"                    Row(children: [
                      Expanded(child: Text(
                        formatMoneyRange(item.price, item.priceTo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      )),
                      Rating(item.providerRating, count: item.providerReviewsCount),
                    ]),"

# ── م) وتصير صبغةُ «مميّز» شفّافةً فلا تُرى على البطاقة البيضاء ───────
run "(م) «مميّز» شفّافةٌ على الأبيض" \
  sub "$F" \
"      color: AppColors.warning.withValues(alpha: Tint.chip)," \
"      color: Colors.transparent,"

echo; echo "== الجوالُ الضيّق =="

# ── ن) وتُكتب «التفاصيل» على كلّ عرض ──────────────────────────────────
#
# **فتفيض البطاقةُ بسبعةَ عشرَ بكسلاً على جوالٍ بعرض ‎٣٢٠‎** — وقد فاضت.
run "(ن) الكلمةُ على الضيّق فتفيض" \
  sub "$F" \
"                      final roomy = box.maxWidth >= _detailsWordMinWidth;" \
"                      final roomy = box.maxWidth >= 0;"

# ── س) ويسقط السهمُ مع الكلمة ──────────────────────────────────────────
#
# **فلا تفيض، ولا يبقى ما يقول إنّ البطاقةَ تُضغط** — بابٌ لا يُرى.
run "(س) السهمُ يسقط مع الكلمة" \
  sub "$F" \
"                          const Icon(Icons.arrow_forward_ios,
                              size: 11, color: AppColors.accent)," \
"                          if (roomy)
                            const Icon(Icons.arrow_forward_ios,
                                size: 11, color: AppColors.accent),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
