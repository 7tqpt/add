#!/usr/bin/env python3
"""يولّد علامةَ نافذة الإقلاع بمقاسات الكثافات الخمس.

    cd mobile
    python3 tool/make_splash.py
    python3 tool/make_splash.py --out /tmp/preview   # للمعاينة بلا مساس

ويكتب:  drawable-{mdpi..xxxhdpi}/launch_mark.png

── ما هذه النافذة ─────────────────────────────────────────────────────────

ما يرسمه **أندرويد** بين ضغط الأيقونة وأوّل إطارٍ يرسمه Flutter. و`main()`
تنتظر قبله خمسةَ أشياء، فعلى شبكةٍ بطيئةٍ تبقى ثوانيَ. وكانت بيضاءَ فشكا
صاحبُ المنصّة، واختار (ب): نبيذيٌّ وعليه العلامة.

── ولماذا `app_mark.png` بعينه لا اشتقاقٌ من الأيقونة ────────────────────

جرّبتُ اشتقاقَ العلامة من `app_icon.png` (١٠٢٤ بكسلاً) بقاعدة التشبّع
المكتوبة في `assets/brand/README.md` — عزلُ ما تشبّعُه منخفضٌ ثمّ إسقاطُ
ما يتّصل بالحافّة — **فخرج الإطارُ يكاد يشمل الصورة كلَّها**: خيطُ اللمعان
في حافّة المربّع منخفضُ التشبّع فيوصل الشعارَ بالهامش الأبيض، وهو العيبُ
الذي يحذّر منه الملفُّ نفسُه.

و`app_mark.png` هو الشعارُ معزولاً وقد صحّ، **وهو الملفُّ الذي ترسمه
`BootScreen` بعينه**. فالمشتقُّ منه يطابق ما يفتح عليه التطبيقُ مطابقةً
تامّة — وهي غايةُ الخيار (ب): ألّا يُرى انتقالٌ أصلاً.

── والتكبيرُ مقصودٌ ومقولٌ ────────────────────────────────────────────────

الأصلُ ٢٥٦ بكسلاً والعلامةُ تُرسم بـ١٠٤ نقطة، فالكثافةُ الرابعةُ (xxxhdpi)
تحتاج ٤١٦ — أي تكبيرَ ١٫٦٣. وهو مقبولٌ هنا **لأنّ `BootScreen` تفعله
أصلاً**: تعرض الملفَّ نفسَه بـ١٠٤ نقطةً على الجهاز نفسِه. فالمقاسان
متطابقان في النعومة كما هما في الشكل — ولو جُلب أصلٌ أكبرُ للنافذة وحدَها
لَبانت العلامةُ في النافذة أنعمَ منها في الشاشة التي تليها.
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit('يلزم Pillow:  pip install Pillow')

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'assets/brand/app_mark.png'

# قياسُ العلامة بالنقاط — **وهو قياسُ `BootScreen` نفسُه** (`welcome.dart`).
# ولو افترقا لَقفزت العلامةُ قفزةً صغيرةً عند أوّل إطار، وهي أسوأُ من ثباتٍ
# على قياسٍ واحد.
MARK_DP = 104

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=None, help='مجلّدٌ للمعاينة بدل res/')
    args = ap.parse_args()

    if not SRC.exists():
        sys.exit(f'لا أصلَ في {SRC}')
    mark = Image.open(SRC).convert('RGBA')
    if mark.size != (256, 256):
        print(f'تنبيه: الأصل {mark.size} لا ٢٥٦×٢٥٦')

    base = Path(args.out) if args.out else ROOT / 'android/app/src/main/res'
    for name, scale in DENSITIES.items():
        px = round(MARK_DP * scale)
        out = base / f'drawable-{name}'
        out.mkdir(parents=True, exist_ok=True)
        # LANCZOS في الاتّجاهين: أنعمُ ما في Pillow تصغيراً وتكبيراً.
        mark.resize((px, px), Image.LANCZOS).save(out / 'launch_mark.png')
        print(f'  drawable-{name}/launch_mark.png  {px}×{px}')


if __name__ == '__main__':
    main()
