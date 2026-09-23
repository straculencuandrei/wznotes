import os
import math
from PIL import Image, ImageDraw

def render_wznotes_icon(size=1024, is_round=True, padding_ratio=0.18):
    """
    Renders the exact wznotes icon: AMOLED black background with the perfectly centered white stylus pen.
    """
    # Create high-res canvas with supersampling (2x for ultra smooth antialiasing)
    canvas_size = size * 2
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Background
    # For Windows ICO and Android standard icon:
    # A sleek dark squircle / rounded rectangle or pure AMOLED circle
    corner_radius = int(canvas_size * 0.22)
    # Background: pure black #0D0D0D or #000000 with subtle elegant border
    bg_margin = int(canvas_size * 0.02)
    draw.rounded_rectangle(
        [bg_margin, bg_margin, canvas_size - bg_margin, canvas_size - bg_margin],
        radius=corner_radius,
        fill=(10, 10, 10, 255)
    )

    # Subtle inner border / highlight for premium feel on Windows taskbar
    draw.rounded_rectangle(
        [bg_margin, bg_margin, canvas_size - bg_margin, canvas_size - bg_margin],
        radius=corner_radius,
        outline=(40, 40, 40, 255),
        width=int(canvas_size * 0.008)
    )

    # 2. Draw the centered pen
    # Original coordinates on 108x108 viewport centered at (54, 54):
    # Centered path:
    # Body: (41.35, 67.15) -> (44.35, 70.15) -> (71.05, 43.45) -> cap curve -> (69.85, 36.45) -> cap curve -> (37.35, 63.15) -> (40.35, 66.15)
    # Nib: (35.35, 73.15) -> (39.85, 71.65) -> (36.85, 68.65)
    #
    # Let's map coordinates from [0, 108] to canvas_size
    scale = canvas_size / 108.0

    # Body polygon with rounded cap
    # We can use high-resolution polygon points
    # Cap arc around top right: center of top cap is roughly between (71.05, 37.65) and (64.05, 36.45)
    
    # We can sample the bezier curves for the cap:
    def bezier_point(p0, p1, p2, p3, t):
        x = (1-t)**3 * p0[0] + 3*(1-t)**2 * t * p1[0] + 3*(1-t) * t**2 * p2[0] + t**3 * p3[0]
        y = (1-t)**3 * p0[1] + 3*(1-t)**2 * t * p1[1] + 3*(1-t) * t**2 * p2[1] + t**3 * p3[1]
        return (x, y)

    curve1_pts = [bezier_point((71.05, 43.45), (72.65, 41.85), (72.65, 39.25), (71.05, 37.65), t/10.0) for t in range(11)]
    curve2_pts = [bezier_point((69.85, 36.45), (68.25, 34.85), (65.65, 34.85), (64.05, 36.45), t/10.0) for t in range(11)]

    body_raw = [
        (41.35, 67.15),
        (44.35, 70.15),
        (71.05, 43.45),
    ] + curve1_pts[1:] + [
        (69.85, 36.45)
    ] + curve2_pts[1:] + [
        (37.35, 63.15),
        (40.35, 66.15)
    ]

    body_scaled = [(x * scale, y * scale) for x, y in body_raw]
    draw.polygon(body_scaled, fill=(255, 255, 255, 255))

    # Nib triangle
    nib_raw = [
        (35.35, 73.15),
        (39.85, 71.65),
        (36.85, 68.65)
    ]
    nib_scaled = [(x * scale, y * scale) for x, y in nib_raw]
    draw.polygon(nib_scaled, fill=(255, 255, 255, 255))

    # Downsample to target size with highest quality Lanczos
    return img.resize((size, size), Image.Resampling.LANCZOS)

def generate_all_icons(project_root):
    # 1. Windows app_icon.ico (contains 16, 24, 32, 48, 64, 128, 256)
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    ico_images = [render_wznotes_icon(s) for s in ico_sizes]
    
    win_res_dir = os.path.join(project_root, "windows", "runner", "resources")
    os.makedirs(win_res_dir, exist_ok=True)
    ico_path = os.path.join(win_res_dir, "app_icon.ico")
    
    # Save multi-res ICO
    ico_images[-1].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in ico_sizes],
        append_images=ico_images[:-1]
    )
    print(f"Generated Windows icon: {ico_path} with sizes {ico_sizes}")

    # 2. Android mipmap PNGs
    android_res = os.path.join(project_root, "android", "app", "src", "main", "res")
    mipmap_targets = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, px in mipmap_targets.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Standard icon
        icon_img = render_wznotes_icon(px, is_round=False)
        icon_img.save(os.path.join(folder_path, "ic_launcher.png"), format="PNG")
        
        # Round icon (circle mask for Pixel launcher)
        round_canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        mask = Image.new("L", (px * 2, px * 2), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse([0, 0, px * 2, px * 2], fill=255)
        mask = mask.resize((px, px), Image.Resampling.LANCZOS)
        
        round_img = render_wznotes_icon(px, is_round=True)
        round_canvas.paste(round_img, (0, 0), mask)
        round_canvas.save(os.path.join(folder_path, "ic_launcher_round.png"), format="PNG")
        print(f"Generated Android {folder} ({px}x{px})")

if __name__ == "__main__":
    import sys
    proj_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    generate_all_icons(proj_dir)
