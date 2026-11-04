"""Raw Layer sheets (assets/source/sheets) -> runtime sprites (assets/sprites) + backgrounds (assets/backgrounds).

Sheet layouts are positional (see the prompts in assets/source/layer_jobs.json):
  hero_sheet     3x3 grid    workers_sheet 4x4 grid    items_sheet 4x4 grid
  windows_sheet  5 + 5 + 2 windows (connected components, reading order)
  ceo_sheet      2 halves    rooftop / logo / street   single sprite
Run:  python3 tools/asset_pipeline/build_assets.py
"""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from chroma import key_magenta, components, reading_order, clean_small, trim, fit  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "source", "sheets")
OUT = os.path.join(ROOT, "assets", "sprites")
BG_OUT = os.path.join(ROOT, "assets", "backgrounds")

HERO = ["hang", "climb_a", "climb_b", "side", "hit", "fall", "victory", "mgr_hang", "mgr_climb"]
WORKERS = ["hr_idle", "hr_ready", "hr_throw", "acc_idle", "acc_ready", "acc_throw", "mgmt_idle", "mgmt_ready",
           "mgmt_throw", "it_idle", "it_ready", "it_throw", "mkt_idle", "mkt_ready", "mkt_throw", "intern"]
ITEMS = ["letter", "paper_stack", "calculator", "binder", "bs", "ppt", "crt", "keyboard",
         "keycap", "mug", "tshirt", "confetti_box", "badge", "ac_unit", "ficus", "pigeon"]
WINDOWS = ["win_hr", "win_acc", "win_mgmt", "win_it", "win_mkt",
           "open_hr", "open_acc", "open_mgmt", "open_it", "open_mkt", "win_boarded", "win_gold"]


def save(img, name, max_w, max_h, folder=OUT):
    os.makedirs(folder, exist_ok=True)
    img = fit(trim(img), max_w, max_h)
    img.save(os.path.join(folder, name + ".png"), optimize=True)
    print(f"  {name}.png {img.width}x{img.height}")


def grid(sheet, cols, rows, names, max_w, max_h, prefix=""):
    path = os.path.join(SRC, sheet)
    if not os.path.exists(path):
        print("skip (missing)", sheet); return
    print(sheet)
    im = Image.open(path).convert("RGB")
    cw, ch = im.width / cols, im.height / rows
    for i, n in enumerate(names):
        c, r = i % cols, i // cols
        cell = im.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch)))
        save(clean_small(key_magenta(cell)), prefix + n, max_w, max_h)


def comps(sheet, names, max_w, max_h, row_tol=150):
    path = os.path.join(SRC, sheet)
    if not os.path.exists(path):
        print("skip (missing)", sheet); return
    print(sheet)
    found = reading_order(components(key_magenta(Image.open(path)), dilate=6, min_area=4000), row_tol)
    if len(found) != len(names):
        raise SystemExit(f"{sheet}: expected {len(names)} components, found {len(found)}")
    for (bb, img), n in zip(found, names):
        save(img, n, max_w, max_h)


def single(sheet, name, max_w, max_h):
    path = os.path.join(SRC, sheet)
    if not os.path.exists(path):
        print("skip (missing)", sheet); return
    print(sheet)
    save(clean_small(key_magenta(Image.open(path)), 0.01), name, max_w, max_h)


def background(sheet, name, w=1080, h=1920):
    path = os.path.join(SRC, sheet)
    if not os.path.exists(path):
        print("skip (missing)", sheet); return
    os.makedirs(BG_OUT, exist_ok=True)
    im = Image.open(path).convert("RGB")
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    l, t = (im.width - w) // 2, (im.height - h) // 2
    im.crop((l, t, l + w, t + h)).save(os.path.join(BG_OUT, name + ".jpg"), quality=86, optimize=True)
    print(f"{sheet} -> {name}.jpg")


def derived():
    """HUD life icon (hero head from the victory pose) + the app icon."""
    v = Image.open(os.path.join(OUT, "victory.png"))
    head = v.crop((0, 0, v.width, int(v.height * 0.5)))
    head = head.crop(head.getbbox())
    head.thumbnail((128, 128))
    head.save(os.path.join(OUT, "life.png"))
    icon = Image.new("RGBA", (256, 256), (79, 157, 255, 255))
    h = Image.open(os.path.join(OUT, "hang.png"))
    h.thumbnail((230, 230))
    icon.alpha_composite(h, ((256 - h.width) // 2, (256 - h.height) // 2 + 10))
    icon.save(os.path.join(ROOT, "icon.png"))
    print("life.png, icon.png")


if __name__ == "__main__":
    grid("hero_sheet.png", 3, 3, HERO, 300, 300)
    grid("workers_sheet.png", 4, 4, WORKERS, 280, 280)
    grid("items_sheet.png", 4, 4, ITEMS, 200, 200)
    comps("windows_sheet.png", WINDOWS, 220, 300)
    grid("ceo_sheet.png", 2, 1, ["ceo_sit", "ceo_cheer"], 620, 520)
    single("rooftop.png", "rooftop", 1100, 760)
    single("logo.png", "logo", 1000, 700)
    background("skyline.png", "bg_sky")
    background("penthouse.png", "bg_penthouse")
    derived()
