#!/usr/bin/env python3
"""Generate Google Play Feature Graphic for tsundoku-quest (1024x500)."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
ICON_PATH = os.path.join(PROJECT_DIR, "assets", "icon.png")
OUTPUT_PATH = os.path.join(PROJECT_DIR, "assets", "store", "feature_graphic.png")

FONT_PATH = "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"
FONT_BOLD = "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"  # Same font, use larger size for emphasis

W, H = 1024, 500

def create_gradient_bg(w, h):
    """Dark RPG dungeon gradient: deep navy → dark purple."""
    img = Image.new("RGB", (w, h))
    for y in range(h):
        ratio = y / h
        r = int(10 + (30 - 10) * ratio)      # 10→30
        g = int(5 + (10 - 5) * ratio)        # 5→10
        b = int(20 + (50 - 20) * ratio)      # 20→50
        for x in range(w):
            img.putpixel((x, y), (r, g, b))
    return img


def add_vignette(img):
    """Add a vignette effect (darker edges)."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for i in range(30):
        alpha = int(180 * (1 - i / 30))
        draw.rectangle([i, i, W - i - 1, H - i - 1], outline=(0, 0, 0, alpha), width=1)
    img.paste(overlay, (0, 0), overlay)
    return img


def add_decorative_lines(draw):
    """Add golden decorative lines."""
    gold = (218, 165, 32)
    gold_dim = (180, 140, 30)
    # Top line
    draw.line([(80, 60), (W - 80, 60)], fill=gold_dim, width=2)
    # Bottom line
    draw.line([(80, H - 60), (W - 80, H - 60)], fill=gold_dim, width=2)
    # Small diamond ornaments
    for cx, cy in [(80, 60), (W - 80, 60), (80, H - 60), (W - 80, H - 60)]:
        draw.polygon([(cx, cy - 8), (cx + 6, cy), (cx, cy + 8), (cx - 6, cy)], fill=gold_dim)


def add_particle_effects(draw):
    """Add small glowing particles."""
    from random import seed, randint
    seed(42)
    gold_alpha = [(218, 165, 32), (255, 215, 0), (180, 130, 20)]
    for _ in range(40):
        x, y = randint(20, W - 20), randint(10, H - 10)
        r = randint(1, 3)
        color = gold_alpha[randint(0, 2)]
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def create_feature_graphic():
    """Create the Play Store Feature Graphic (1024x500)."""
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    # Background
    bg = create_gradient_bg(W, H)
    bg = bg.convert("RGBA")

    # Add vignette
    bg = add_vignette(bg)

    draw = ImageDraw.Draw(bg)

    # Decorative lines
    add_decorative_lines(draw)

    # Particles
    add_particle_effects(draw)

    # Load and place icon (resized to ~200x200)
    icon = Image.open(ICON_PATH).convert("RGBA")
    icon = icon.resize((180, 180), Image.Resampling.LANCZOS)

    # Place icon on the left side, vertically centered
    icon_x = 100
    icon_y = (H - 180) // 2
    bg.paste(icon, (icon_x, icon_y), icon)

    # Add glow behind icon
    glow = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for i in range(15):
        alpha = 80 - i * 5
        glow_draw.ellipse([i, i, 219 - i, 219 - i], fill=(218, 165, 32, max(alpha, 0)))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=8))
    bg.paste(glow, (icon_x - 20, icon_y - 20), glow)
    # Re-paste icon on top
    bg.paste(icon, (icon_x, icon_y), icon)

    # Title text
    title_font = ImageFont.truetype(FONT_PATH, 56)
    subtitle_font = ImageFont.truetype(FONT_PATH, 28)

    # Draw title with shadow
    title = "ツンドクエスト"
    title_x = icon_x + 200
    title_y = 120

    # Shadow
    draw.text((title_x + 3, title_y + 3), title, font=title_font, fill=(0, 0, 0, 160))
    # Gold text
    draw.text((title_x, title_y), title, font=title_font, fill=(255, 215, 0, 255))

    # Subtitle
    subtitle = "積読を冒険に変えよ"
    sub_x = icon_x + 200
    sub_y = title_y + 70
    draw.text((sub_x + 2, sub_y + 2), subtitle, font=subtitle_font, fill=(0, 0, 0, 160))
    draw.text((sub_x, sub_y), subtitle, font=subtitle_font, fill=(200, 180, 140, 255))

    # Small description line
    desc_font = ImageFont.truetype(FONT_PATH, 18)
    desc = "本を読み、経験値を得て、ダンジョンを踏破せよ"
    desc_x = icon_x + 200
    desc_y = sub_y + 50
    draw.text((desc_x + 1, desc_y + 1), desc, font=desc_font, fill=(0, 0, 0, 160))
    draw.text((desc_x, desc_y), desc, font=desc_font, fill=(160, 140, 110, 255))

    # Convert to RGB for final output (no alpha for Play Store)
    bg_rgb = bg.convert("RGB")
    bg_rgb.save(OUTPUT_PATH, "PNG", quality=95)
    print(f"✅ Feature Graphic saved: {OUTPUT_PATH}")
    print(f"   Size: {bg_rgb.size}")


if __name__ == "__main__":
    create_feature_graphic()
