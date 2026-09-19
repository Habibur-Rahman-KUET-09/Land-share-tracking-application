"""Regenerates the Play Console graphics from the app's own icon assets.

    python3 store/make_graphics.py     (run from the repository root)

Both images are derived, not drawn by hand, so the store artwork cannot
drift from the icon the app actually ships. Needs Pillow built with raqm —
without it the Bangla text renders in logical order, which is wrong and
obvious: the i-kar sits after its consonant instead of before it.
"""

from PIL import Image, ImageDraw, ImageFont, features

NAVY = (27, 42, 74)      # AppColors.heading
GOLD = (229, 179, 71)    # AppColors.gold
WHITE = (255, 255, 255)
MUTED = (205, 212, 224)

BN_BOLD = 'assets/fonts/NotoSansBengali-Bold.ttf'
BN_REGULAR = 'assets/fonts/NotoSansBengali-Regular.ttf'
# The Bangla font carries no Latin glyphs, so the wordmark needs its own.
LATIN_BOLD = '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf'


def main() -> None:
    assert features.check('raqm'), 'Pillow without raqm cannot shape Bangla'

    # Play masks the icon itself, so hand it a plain square: no rounded
    # corners, no drop shadow, no transparency.
    icon = Image.open('assets/icon/icon_full.png').convert('RGB')
    icon.resize((512, 512), Image.LANCZOS).save('store/icon-512.png')

    banner = Image.new('RGB', (1024, 500), NAVY)
    rings = Image.open('assets/icon/icon_foreground.png').convert('RGBA')
    rings = rings.resize((340, 340), Image.LANCZOS)
    banner.paste(rings, (80, 80), rings)

    draw = ImageDraw.Draw(banner)
    draw.text((470, 140), 'Kistify', font=ImageFont.truetype(LATIN_BOLD, 92), fill=WHITE)
    draw.text((473, 258), 'কিস্তি রাখুন গুছিয়ে', font=ImageFont.truetype(BN_BOLD, 50), fill=GOLD)
    draw.text((475, 338), 'বন্ধুদের কিস্তি, সঞ্চয় ও সমিতির হিসাব',
              font=ImageFont.truetype(BN_REGULAR, 31), fill=MUTED)
    banner.save('store/feature-graphic-1024x500.png')


if __name__ == '__main__':
    main()
