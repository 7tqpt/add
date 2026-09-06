#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«خدماتٌ لك» — بطاقتان في السطر.
#
# كلُّ ضابطٍ يكسر ضمانةً واحدةً في الشيفرة الحيّة ثمّ يشغّل الحزمة: إن بقيت
# خضراءَ فالحارسُ لا يحرس. والملفُّ يُعاد كما كان في كلّ حال.
set -uo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

HOME_DART=lib/src/screens/home.dart
BACKUP=$(mktemp -d)
cp "$HOME_DART" "$BACKUP/home.dart"
restore() { cp "$BACKUP/home.dart" "$HOME_DART"; }
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
  if timeout 300 flutter test test/polish_test.dart >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 flutter test test/polish_test.dart >/dev/null 2>&1; then
  echo "أخضر."
else
  echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1
fi

echo
echo "== الضوابط =="

# أ) بطاقةٌ واحدةٌ في السطر — كما كانت.
#
# (وكان الكسرُ أوّلاً `i += 1` بدل `i += 2`. وهو لا يكسر شيئاً: السطرُ يبقى
# فيه بطاقتان وإنّما تتكرّر السطور. أبلغ الحارسُ أنّ الحزمةَ خضراء، فكان
# العيبُ في الضابط لا في الحارس.)
run "أ) بطاقةٌ واحدةٌ في السطر" sub "$HOME_DART" \
  '                    const SizedBox(width: Space.sm),
                    // خليّةٌ فارغةٌ للفردِ الأخير — لا بطاقةٌ تتمدّد على
                    // السطر كلِّه فتُقرأ صنفاً آخرَ من البطاقات.
                    Expanded(
                      child: i + 1 < items.length
                          ? _SuggestedCard(
                              item: items[i + 1],
                              isFavourite: _favourites.contains(items[i + 1].id),
                              onToggleFavourite: () =>
                                  _toggleFavourite(items[i + 1].id),
                            )
                          : const SizedBox.shrink(),
                    ),' \
  ''

# ب) ثلاثٌ لا أربع — فتبقى خليّةٌ فارغةٌ في السطر الثاني.
#
# (وكان الكسرُ أوّلاً في شرط الحلقة. وهو لم يكسر شيئاً لأنّ العددَ كان
# محدوداً في موضعين: الحلقةِ وشرطِ البطاقة الثانية — فالرابعةُ تأتي من
# الآخر. فصار الحدُّ ثابتاً واحداً `_shown`، والضابطُ يبدّله.)
run "ب) ثلاثُ خدماتٍ فتبقى خليّةٌ فارغة" sub "$HOME_DART" \
  'static const _shown = 4;' \
  'static const _shown = 3;'

# ج) بلا `IntrinsicHeight` — فتتفاوت البطاقتان في الارتفاع.
run "ج) بطاقتان مختلفتا الارتفاع" sub "$HOME_DART" \
  '              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,' \
  '              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,'

# د) ارتفاعٌ ثابتٌ بدل ما يتبع المحتوى — فيفيض على الشاشة الضيّقة.
run "د) ارتفاعٌ ثابتٌ يفيض" sub "$HOME_DART" \
  '              IntrinsicHeight(' \
  '              SizedBox(
                height: 150,'

# هـ) الخليّةُ الفارغةُ تُملأ ببطاقةٍ متمدّدة — فيختلف عرضُ البطاقتين.
run "هـ) بطاقةٌ أعرضُ من جارتها" sub "$HOME_DART" \
  '                    Expanded(
                      child: _SuggestedCard(
                        item: items[i],' \
  '                    Expanded(
                      flex: 2,
                      child: _SuggestedCard(
                        item: items[i],'

# و) القلبُ يذهب من البطاقة.
run "و) بطاقةٌ بلا قلبِ مفضّلة" sub "$HOME_DART" \
  '                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: _HeartButton(
                      isFavourite: isFavourite,
                      onTap: onToggleFavourite,
                    ),
                  ),' \
  ''

# ز) القلبُ بلا حَلبةِ إيماءاتٍ خاصّة — فتُفتح صفحةُ الخدمة بدل الحفظ.
run "ز) الضغطُ على القلب يفتح صفحةَ الخدمة" sub "$HOME_DART" \
  '      child: InkWell(
        onTap: onTap,' \
  '      child: IgnorePointer(
        child: Builder(builder: (_) =>'

# ح) القلبُ لا يتبدّل بالضغط — يُحفظ في الخادم ولا يُرى أثرٌ في الشاشة.
run "ح) القلبُ لا يتبدّل بالضغط" sub "$HOME_DART" \
  '    setState(() {
      if (!_favourites.remove(serviceId)) _favourites.add(serviceId);
    });
    try {' \
  '    try {'

# ط) اللافتةُ بمقاسٍ آخر — لا بمقاس البطاقة التي كانت مكانها.
run "ط) مقاسٌ غيرُ مقاس البطاقة" sub "$HOME_DART" \
  '          height: 196,
          child: PageView(' \
  '          height: 140,
          child: PageView('

# ي) شارةُ «إعلان» تُرفع عن اللافتة.
run "ي) لافتةٌ بلا شارة «إعلان»" sub "$HOME_DART" \
  "                  'إعلان'," \
  "                  '',"

# ك) لا دوران: المؤقّتُ لا يُسلَّح.
run "ك) لافتةٌ لا تدور وحدها" sub "$HOME_DART" \
  '    _tick = Timer.periodic(const Duration(seconds: 3), (_) => _next());' \
  ''

# ل) الدورانُ أبطأُ من ثلاث ثوانٍ — «كل ٣ ثوانٍ» رقمٌ لا تقريب.
run "ل) دورانٌ كلَّ عشر ثوانٍ" sub "$HOME_DART" \
  'Timer.periodic(const Duration(seconds: 3), (_) => _next())' \
  'Timer.periodic(const Duration(seconds: 10), (_) => _next())'

# م) المؤقّتُ لا يُلغى عند زوال الشاشة.
run "م) مؤقّتٌ يبقى بعد زوال الشاشة" sub "$HOME_DART" \
  '    _tick?.cancel();
    _controller.dispose();' \
  '    _controller.dispose();'

echo
echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
