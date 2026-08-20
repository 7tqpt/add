#!/usr/bin/env python3
"""يولّد أيقونات أندرويد من صورةٍ واحدة.

    python3 tool/make_icons.py assets/brand/app_icon.png
    python3 tool/make_icons.py <صورة> --out /tmp/preview   # للتجربة بلا مساس

ويكتب:
  · mipmap-{mdpi..xxxhdpi}/ic_launcher.png            — الأجهزة قبل أندرويد ٨
  · mipmap-{...}/ic_launcher_foreground.png           — طبقة الواجهة المتكيّفة
  · drawable/ic_launcher_background.xml               — أرضيةٌ بلون الصورة

لماذا سكربتٌ لا خطواتٌ باليد: المقاسات خمسة وطبقتان، وأيُّ واحدةٍ تُنسى
تظهر أيقونةً مشوّهة على طرازٍ واحدٍ من الأجهزة لا يملكه أحدٌ في الفريق.
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit('يلزم Pillow:  pip install Pillow')

RES = Path(__file__).resolve().parent.parent / 'android/app/src/main/res'
DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

def trim_margin(im: Image.Image, fill: float = 0.5) -> Image.Image:
    """يقصّ الهامش المعتم أو الشفّاف حول العمل.

    صور المولّدات تأتي بمربّعٍ مستدير الزوايا داخل خلفيةٍ سوداء، وعليها أحياناً
    شارةُ «Made with AI» في زاويةٍ من تلك الخلفية.

    **والقاعدة أغلبيةٌ لا وجودٌ مفرد**، وهذا ما تعلّمتُه بتشغيلها: أوّل نسخةٍ
    قالت «أيُّ بكسلٍ فاتحٍ فهو من العمل»، فأنقذت الشارةُ الفاتحة الهامشَ كلّه من
    القصّ — لأنها تقع في أعلاه — وخرج لون الأرضية أسود. فصار الصفّ يُعدّ من
    العمل إذا كان أكثرُ نصفِه غيرَ معتم؛ والشارة تشغل جزءاً يسيراً من صفّها
    فتسقط معه.
    """
    rgba = im.convert('RGBA')
    w, h = rgba.size
    px = rgba.load()
    step = max(1, min(w, h) // 400)  # عيّنةٌ تكفي: الحافّة لا تحتاج كل بكسل

    def lit(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        return a > 24 and (r + g + b) > 70

    xs = range(0, w, step)
    ys = range(0, h, step)
    rows = [sum(lit(x, y) for x in xs) / len(xs) for y in ys]
    cols = [sum(lit(x, y) for y in ys) / len(ys) for x in xs]

    def span(fractions: list[float]) -> tuple[int, int] | None:
        hits = [i for i, f in enumerate(fractions) if f >= fill]
        return (hits[0], hits[-1]) if hits else None

    v, hspan = span(rows), span(cols)
    if v is None or hspan is None:
        return rgba  # لا شيء يُقصّ — تُعاد كما هي بدل أن تُفرَّغ
    return rgba.crop((hspan[0] * step, v[0] * step, (hspan[1] + 1) * step, (v[1] + 1) * step))


def dominant_edge_colour(im: Image.Image) -> tuple[int, int, int]:
    """أكثرُ لونٍ على حافّة العمل — وهو لون أرضيّته غالباً.

    والتقريبُ للعدّ وحده، والقيمةُ المعادة متوسّطُ الألوان الحقيقية في السلّة
    الفائزة. وأوّل نسخةٍ أعادت الدرجة المقرَّبة نفسها فاختلفت عن لون الأرضية
    بخمس وحدات — قدرٌ لا يُذكر في جدول، لكنه ظهر في المعاينة خطَّ وصلٍ رفيعاً
    حول العمل.
    """
    small = im.convert('RGB').resize((64, 64), Image.LANCZOS)
    px = small.load()

    # الحلقة عند ⅛ من الطرف لا عند الطرف نفسه: العمل مربّعٌ مستدير الزوايا،
    # وحافّتُه تمرّ بالزوايا المعتمة الواقعة خارجه. قِستُ الصورة الحقيقية
    # فوجدت الزاوية تمتدّ نحو سُبع العرض، فالحلقة تقع داخلها.
    ring = 8
    buckets: dict[tuple[int, int, int], list[tuple[int, int, int]]] = {}
    for i in range(ring, 64 - ring):
        for x, y in ((i, ring), (i, 63 - ring), (ring, i), (63 - ring, i)):
            value = px[x, y]
            # المعتم لا يصوّت: هو أرضية الصورة لا أرضية العمل. وبدون هذا يفوز
            # الأسود بالتشتّت لا بالكثرة — تدرّجُ الأزرق يتفرّق على سلالٍ عدّة
            # بينما الأسود يجتمع في سلّةٍ واحدة، فيغلبها وهو أقلّ منها عدداً.
            if sum(value) < 90:
                continue
            key = tuple(v // 32 * 32 for v in value)
            buckets.setdefault(key, []).append(value)

    if not buckets:  # عملٌ معتمٌ كلّه — يُصوَّت بلا استثناء
        for i in range(ring, 64 - ring):
            for x, y in ((i, ring), (i, 63 - ring), (ring, i), (63 - ring, i)):
                buckets.setdefault(tuple(v // 32 * 32 for v in px[x, y]), []).append(px[x, y])

    winner = max(buckets.values(), key=len)
    return tuple(round(sum(c[i] for c in winner) / len(winner)) for i in range(3))


def colour_rgba(c: tuple[int, int, int]) -> tuple[int, int, int, int]:
    return (c[0], c[1], c[2], 255)


def square(im: Image.Image) -> Image.Image:
    """يضع العمل في مربّعٍ بلون أرضيّته — لا تشويهَ بتمديدٍ غير متناسب."""
    w, h = im.size
    if w == h:
        return im
    side = max(w, h)
    canvas = Image.new('RGBA', (side, side), dominant_edge_colour(im) + (255,))
    canvas.paste(im, ((side - w) // 2, (side - h) // 2), im)
    return canvas


def main() -> None:
    args = sys.argv[1:]
    global RES
    if '--out' in args:
        i = args.index('--out')
        RES = Path(args[i + 1])
        RES.mkdir(parents=True, exist_ok=True)
        del args[i:i + 2]
    if len(args) != 1:
        sys.exit(__doc__)
    src = Path(args[0])
    if not src.exists():
        sys.exit(f'لا ملف: {src}')

    art = square(trim_margin(Image.open(src)))
    bg = dominant_edge_colour(art)
    print(f'العمل بعد القصّ: {art.size} — لون الأرضية: #{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}')

    # ── القديمة: العمل كما هو بزواياه المستديرة ─────────────────────────────
    for name, px in DENSITIES.items():
        out = art.resize((px, px), Image.LANCZOS)
        mask = Image.new('L', (px, px), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, px - 1, px - 1], radius=max(2, round(px * 0.17)), fill=255
        )
        shaped = Image.new('RGBA', (px, px), (0, 0, 0, 0))
        shaped.paste(out, mask=mask)
        path = RES / f'mipmap-{name}/ic_launcher.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        shaped.save(path)
        print(f'  ✓ {path.relative_to(RES)}')

    # ── المتكيّفة: العمل يملأ الطبقة، وقناعُ الجهاز هو الذي يشكّله ───────────
    #
    # ملءٌ كامل لا حشرٌ في منطقة الأمان. ومنطقةُ الأمان قاعدةٌ لشعارٍ يجب ألّا
    # يُقصّ منه شيء؛ وهذه الصورة **أيقونةٌ كاملةٌ بذاتها** — لها إطارها
    # واستدارتها وحاشيتها. فحشرُها في ⅔ الطبقة يُظهر أيقونةً داخل أيقونة،
    # وحول الداخلة زواياها المعتمة. جرّبتُه فرأيتُه: أربع لطخاتٍ سوداء.
    #
    # وبالملء يقصّ الجهاز حاشيتها بقناعه — وهي حاشيةٌ زخرفية — ويبقى ما في
    # وسطها: العروس والاسم والقلب. وقِستُ ذلك: الوسط يشغل نحو ثمانين في
    # المئة، فالدائرة المحيطة بالمربّع لا تبلغه.
    for name, px in DENSITIES.items():
        side = round(px * 108 / 48)
        layer = Image.new('RGBA', (side, side), colour_rgba(bg))
        layer.alpha_composite(art.resize((side, side), Image.LANCZOS).convert('RGBA'))
        path = RES / f'mipmap-{name}/ic_launcher_foreground.png'
        layer.save(path)
        print(f'  ✓ {path.relative_to(RES)}')

    xml = RES / 'drawable/ic_launcher_background.xml'
    xml.parent.mkdir(parents=True, exist_ok=True)
    xml.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- أرضية الأيقونة المتكيّفة — لونٌ مأخوذٌ من حافّة العمل نفسه،\n'
        '     فما يظهر خلف القناع امتدادٌ للأيقونة لا لونٌ غريبٌ عنها.\n'
        f'     يولّده tool/make_icons.py — لا يُحرَّر باليد. -->\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:shape="rectangle">\n'
        f'    <solid android:color="#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}" />\n'
        '</shape>\n',
        encoding='utf-8',
    )
    print(f'  ✓ {xml.relative_to(RES)}')
    print('\nتمّ. أعِد بناء الحزمة لترى الأيقونة على الجهاز.')


if __name__ == '__main__':
    main()
