"""
Creates App Store screenshots for SignatureWidget.
Composites the simulator screenshot into a styled frame with title + subtitle.
Output: 1290x2796 PNG (iPhone 6.7" App Store size)
"""

from PIL import Image, ImageDraw, ImageFont
import os

OUTPUT_DIR = "/sessions/eloquent-adoring-galileo/mnt/SignatureWidget"

# App Store 6.7" size
W, H = 1290, 2796

# Brand purple (from app's nav bar color)
BG_PURPLE  = (88, 66, 185)
BG_DARK    = (22, 18, 48)
BG_TEAL    = (38, 120, 140)
TEXT_COLOR = (255, 255, 255)
SUBTITLE_COLOR = (220, 215, 255)

SLIDES = [
    {
        "title": "Draw your\nsignature.",
        "subtitle": "Natural canvas, smooth strokes.\nUndo, refine, perfect.",
        "screenshot": f"{OUTPUT_DIR}/screenshot_list.png",
        "bg": BG_PURPLE,
        "output": f"{OUTPUT_DIR}/appstore_1.png",
    },
    {
        "title": "Save as many\nas you like.",
        "subtitle": "Multiple signatures, always\nready to switch between.",
        "screenshot": f"{OUTPUT_DIR}/screenshot_list.png",
        "bg": BG_DARK,
        "output": f"{OUTPUT_DIR}/appstore_2.png",
    },
    {
        "title": "Always on your\nlock screen.",
        "subtitle": "Display your signature as\na home or lock screen widget.",
        "screenshot": f"{OUTPUT_DIR}/screenshot_widget.png",
        "bg": BG_TEAL,
        "output": f"{OUTPUT_DIR}/appstore_3.png",
        "full_bleed": True,  # widget screen looks better full-bleed
    },
]


def make_screenshot(title, subtitle, screenshot_path, output_path, bg_color=None, full_bleed=False):
    if bg_color is None:
        bg_color = BG_PURPLE
    canvas = Image.new("RGB", (W, H), bg_color)
    draw = ImageDraw.Draw(canvas)

    # ── Typography ──────────────────────────────────────────────────────────
    # Use a system font — fall back gracefully
    font_paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    font_path = next((p for p in font_paths if os.path.exists(p)), None)

    title_font = ImageFont.truetype(font_path, 100) if font_path else ImageFont.load_default()
    subtitle_font = ImageFont.truetype(font_path, 58) if font_path else ImageFont.load_default()

    PADDING = 90

    # ── Title ───────────────────────────────────────────────────────────────
    title_y = 160
    for line in title.split("\n"):
        bbox = draw.textbbox((0, 0), line, font=title_font)
        draw.text((PADDING, title_y), line, font=title_font, fill=TEXT_COLOR)
        title_y += (bbox[3] - bbox[1]) + 20

    # ── Subtitle ────────────────────────────────────────────────────────────
    subtitle_y = title_y + 40
    for line in subtitle.split("\n"):
        bbox = draw.textbbox((0, 0), line, font=subtitle_font)
        draw.text((PADDING, subtitle_y), line, font=subtitle_font, fill=SUBTITLE_COLOR)
        subtitle_y += (bbox[3] - bbox[1]) + 12

    # ── Phone mockup area ───────────────────────────────────────────────────
    # Place screenshot in lower 65% of the canvas, centered, with rounded frame
    phone_top = subtitle_y + 100
    available_h = H - phone_top - 80
    available_w = W - PADDING * 2

    app_screen = Image.open(screenshot_path).convert("RGBA")
    sw, sh = app_screen.size
    scale = min(available_w / sw, available_h / sh)
    new_sw = int(sw * scale)
    new_sh = int(sh * scale)
    app_screen = app_screen.resize((new_sw, new_sh), Image.LANCZOS)

    # Phone frame padding (bezel)
    bezel = 28
    frame_w = new_sw + bezel * 2
    frame_h = new_sh + bezel * 2
    corner_r = 100

    frame_x = (W - frame_w) // 2
    frame_y = phone_top

    # Draw phone frame (dark background with rounded corners)
    frame_img = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame_img)
    frame_draw.rounded_rectangle(
        [0, 0, frame_w - 1, frame_h - 1],
        radius=corner_r,
        fill=(20, 18, 40),
        outline=(160, 150, 220),
        width=4,
    )
    canvas.paste(Image.new("RGB", (frame_w, frame_h), bg_color), (frame_x, frame_y))
    canvas.paste(frame_img.convert("RGB"), (frame_x, frame_y), frame_img)

    # Mask the screenshot with rounded corners too
    mask = Image.new("L", (new_sw, new_sh), 0)
    mask_draw = ImageDraw.Draw(mask)
    inner_r = corner_r - bezel
    mask_draw.rounded_rectangle([0, 0, new_sw - 1, new_sh - 1], radius=max(inner_r, 10), fill=255)

    screen_x = frame_x + bezel
    screen_y = frame_y + bezel
    canvas.paste(app_screen.convert("RGB"), (screen_x, screen_y), mask)

    # For full-bleed mode (e.g. lock screen), overlay the screenshot behind text
    if full_bleed:
        canvas2 = Image.new("RGB", (W, H), bg_color)
        app_screen = Image.open(screenshot_path).convert("RGBA")
        sw, sh = app_screen.size
        scale = W / sw
        new_sw = W
        new_sh = int(sh * scale)
        app_screen = app_screen.resize((new_sw, new_sh), Image.LANCZOS)
        # Paste at bottom
        paste_y = H - new_sh
        canvas2.paste(app_screen.convert("RGB"), (0, paste_y))
        # Dark gradient overlay at top for text legibility
        grad = Image.new("RGBA", (W, 700), (0, 0, 0, 0))
        grad_draw = ImageDraw.Draw(grad)
        for i in range(700):
            alpha = int(200 * (1 - i / 700))
            grad_draw.line([(0, i), (W, i)], fill=(0, 0, 0, alpha))
        canvas2.paste(grad.convert("RGB"), (0, 0), grad)
        # Re-draw title and subtitle on top
        title_y2 = 160
        for line in title.split("\n"):
            bbox2 = draw.textbbox((0, 0), line, font=title_font)
            ImageDraw.Draw(canvas2).text((PADDING, title_y2), line, font=title_font, fill=TEXT_COLOR)
            title_y2 += (bbox2[3] - bbox2[1]) + 20
        subtitle_y2 = title_y2 + 40
        for line in subtitle.split("\n"):
            bbox2 = draw.textbbox((0, 0), line, font=subtitle_font)
            ImageDraw.Draw(canvas2).text((PADDING, subtitle_y2), line, font=subtitle_font, fill=SUBTITLE_COLOR)
            subtitle_y2 += (bbox2[3] - bbox2[1]) + 12
        canvas2.save(output_path, "PNG")
        print(f"Saved (full-bleed): {output_path} ({W}x{H})")
        return

    canvas.save(output_path, "PNG")
    print(f"Saved: {output_path} ({W}x{H})")


for slide in SLIDES:
    make_screenshot(
        slide["title"],
        slide["subtitle"],
        slide["screenshot"],
        slide["output"],
        bg_color=slide.get("bg", BG_PURPLE),
        full_bleed=slide.get("full_bleed", False),
    )

print("Done.")
