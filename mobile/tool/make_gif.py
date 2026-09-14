#!/usr/bin/env python3
"""يجمع إطاراتِ `splash_proposal_test.dart` فيديوَ GIF.

    python3 tool/make_gif.py <مجلّد الإطارات> [اسم الملفّ]

ولا ffmpeg في هذه البيئة، وPIL تكفي: الإطاراتُ متقاربةٌ في ألوانها —
نبيذيٌّ وذهبيٌّ وورقةٌ باهتة — فلوحُ ٢٥٦ لوناً لا يُفقد منها شيئاً يُرى.

**ولوحٌ واحدٌ لكلّ الإطارات لا لوحٌ لكلّ إطار:** لوحٌ يُحسب لكلّ إطارٍ على
حدةٍ يتبدّل بين إطارٍ وآخر فترتجف الألوانُ في العرض — وهو عيبٌ يُرى في
التدرّج النبيذيّ خاصّةً.
"""
import sys
from pathlib import Path

from PIL import Image

src = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/shots')
name = sys.argv[2] if len(sys.argv) > 2 else 'splash.gif'
out = src / name

paths = sorted(src.glob('frame_*.png'))
if not paths:
    sys.exit(f'لا إطاراتِ frame_*.png في {src}')

frames = [Image.open(p).convert('RGB') for p in paths]

# اللوحُ يُحسب من إطارٍ في منتصف الحركة: أوّلُ إطارٍ شبهُ فارغٍ من الذهب،
# فلوحٌ منه يُفقر الألوانَ التي تأتي بعده.
palette = frames[len(frames) // 2].quantize(colors=255, method=Image.MEDIANCUT)
quantised = [f.quantize(palette=palette, dither=Image.FLOYDSTEINBERG)
             for f in frames]

quantised[0].save(
    out,
    save_all=True,
    append_images=quantised[1:],
    duration=1000 // 24,   # أربعٌ وعشرون إطاراً في الثانية
    loop=0,
    optimize=True,
)
print(f'{out}  —  {len(frames)} إطاراً، {out.stat().st_size // 1024} ك.ب')
