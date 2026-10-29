#!/usr/bin/env python3
"""
render_assets.py - the Assets phase's pictures: every labelled picture and sprite pose, drawn by the
ROM's own routines headless and rendered with the game's own palettes.

Grounding: nothing is redrawn by hand. The CPU, bus, PPU port and renderers are emu-harness's.
  * Background pictures: draw_rle_text ($C6FB) draws each blob that data_pointers.py labelled, with
    rendering off (ppu_mask_shadow = 0, so ppu_buffer_enqueue writes straight to the PPU), at a fixed
    nametable address. The palette is what each family's caller passes in draw_palette ($14):
      item_picture        draw_item: 0 for pairs 0-2 (offsets 0-4), 2 after; the erase ($0A) $80
      trampoline_picture  draw_trampoline: $14 = bounces left (3 fresh .. 1 worn; broken: 0, entry $14)
      bonus_target_picture draw_bonus_target: 0
      door_picture, floor_trap_picture, text_line: $80 (leave the attributes: drawn on the mansion,
                          whose fill is $55, i.e. sub-palette 1)
  * Sprites: draw_object ($C305) on a record in its usual slot, for every anim handler (tbl_draw_by_anim),
    object type and timer phase (+7); the OAM shadow ($0700) it writes is rendered by render_sprites.
  * Palettes: the background palette a round load writes ($3F00, ppu_run_draw_blocks entry 4, round 1)
    and the sprite palette only the title's block writes ($3F10, entry 2; rounds keep it).

  py -3.14 mappy/render_assets.py OUT_DIR      -> pictures.png, sprites.png, and one PNG per picture
  py -3.14 mappy/render_assets.py --art        -> listing_art.json: {address: comment lines} for asm_gen,
                                                  ASCII art of each picture and of each draw handler's
                                                  first pose, and the decoded string of each text blob
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from code_map import label_names
from data_pointers import TABLES    # the pointer tables and their reader-proven counts
PICTURE_STEMS = {"item_picture", "door_picture", "trampoline_picture", "floor_trap_picture",
                 "bonus_target_picture", "text_line"}
from emu_harness.cpu.m6502.cpu import CPU6502
from emu_harness.machines.nes import ppu
from emu_harness.machines.nes.bus import Bus
from emu_harness.machines.nes.canvas import Canvas
from emu_harness.machines.nes.ppuport import PPUPort

from paths import DATA, PICTURES, ROM as ROM_FILE
ROM = ROM_FILE.read_bytes()
CHR = ROM[16 + 0x4000:16 + 0x6000]
DRAW_RLE_TEXT, DRAW_OBJECT, RUN_DRAW_BLOCKS = 0xC6FB, 0xC305, 0xCC15
AT = (12, 12)                       # the nametable cell a picture is drawn from (room for negative deltas)
SENTINEL = 0xFE                     # pre-filled tile: a cell still holding it was not written
MANSION_SUB = 1                     # attribute fill $55 under the $80 families
SCALE = 3


def call(cpu, entry, y=0):
    cpu.a, cpu.x, cpu.y, cpu.sp = 0, 0, y, 0xFD
    cpu.push_word(0xFFFE)
    cpu.pc = entry
    cpu.run_until({0xFFFF}, max_steps=2_000_000)


def machine():
    port = PPUPort()
    bus = Bus(ROM, ppu=port)
    return port, bus, CPU6502(bus)


def palettes():
    """(background $3F00, sprite $3F10), 16 bytes each, as the game's own draw blocks write them."""
    port, _, cpu = machine()
    call(cpu, RUN_DRAW_BLOCKS, y=2)                    # the title's block: the sprite palette
    spr = list(port.vram[0x3F10:0x3F20])
    call(cpu, RUN_DRAW_BLOCKS, y=4)                    # round 1's block: the background palette
    return list(port.vram[0x3F00:0x3F10]), spr


def picture_palette(stem, off):
    if stem == "item_picture":
        return 0x80 if off == 0x0A else (0 if off < 6 else 2)
    if stem == "bonus_target_picture":
        return 0
    return 0x80


def draw_picture(addr, pal, nt=None):
    """-> Canvas of exactly the cells draw_rle_text wrote, sub-palette from `pal` (or the mansion's).
    `nt`: the nametable address to draw at (default the cell AT)."""
    port, bus, cpu = machine()
    port.vram[0x2000:0x23C0] = bytes([SENTINEL]) * 0x3C0
    col, row = AT
    bus.ram[0x2D] = 0                                   # ppu_mask_shadow: rendering off, write direct
    nt = nt if nt is not None else 0x2000 + row * 32 + col
    bus.ram[0x10], bus.ram[0x11] = nt & 0xFF, nt >> 8
    bus.ram[0x12], bus.ram[0x13] = addr & 0xFF, addr >> 8
    bus.ram[0x14] = pal
    call(cpu, DRAW_RLE_TEXT)
    cells = [i for i in range(960) if port.vram[0x2000 + i] != SENTINEL]
    if not cells:
        return None
    c0, c1 = min(i % 32 for i in cells), max(i % 32 for i in cells)
    r0, r1 = min(i // 32 for i in cells), max(i // 32 for i in cells)
    sub = MANSION_SUB if pal & 0x80 else pal & 3
    tiles = [port.vram[0x2000 + r * 32 + c] for r in range(r0, r1 + 1) for c in range(c0, c1 + 1)]
    tiles = [0 if t == SENTINEL else t for t in tiles]
    return Canvas(c1 - c0 + 1, r1 - r0 + 1, tiles, [sub] * len(tiles))


def picture_jobs():
    """[(label, address, palette, nametable)] for every picture blob, plus the trampoline's wear colours.
    Text lines are drawn at their own record's address (tbl_text_lines: [address][text pointer])."""
    jobs, names = [], label_names()
    word = lambda a: ROM[16 + a - 0xC000] | ROM[16 + a - 0xC000 + 1] << 8
    for _, base, n, stride, woff, stem, _ in TABLES:     # by address: the pointer tables data_pointers walks
        if stem not in PICTURE_STEMS:
            continue
        seen = set()
        for k in range(n):
            off, addr = stride * k, word(base + stride * k + woff)
            if addr in seen:
                continue
            seen.add(addr)
            name = names.get(addr, f"{stem}_{off:02x}")
            if stem == "trampoline_picture":
                for left in ((0,) if off == 0x14 else (3, 2, 1)):
                    jobs.append((f"{name} (bounces left {left})" if off != 0x14 else f"{name} (broken)", addr, left, None))
            else:
                nt = word(base + stride * k) if stem == "text_line" else None   # [address][text pointer]
                jobs.append((name, addr, picture_palette(stem, off), nt))
    return jobs


def draw_sprite(anim, slot, typ, t7, facing):
    """-> OAM bytes draw_object writes for one record (x, y = 6 tiles in), or b'' if it draws nothing."""
    _, bus, cpu = machine()
    rec = 0x400 + 16 * slot
    bus.ram[rec + 1], bus.ram[rec + 3] = 6, 6           # tile x, row (fractions 0)
    bus.ram[rec + 4], bus.ram[rec + 5], bus.ram[rec + 6], bus.ram[rec + 7] = anim, typ, facing, t7
    bus.ram[0x1E], bus.ram[0x1F] = rec & 0xFF, rec >> 8
    bus.ram[0x28] = bus.ram[0x29] = 0                   # camera at the left edge
    bus.ram[0x2C] = 0                                   # oam_cursor
    call(cpu, DRAW_OBJECT)
    return bytes(bus.ram[0x700:0x700 + bus.ram[0x2C]])


def sprite_jobs():
    """[(title, oam)]: each anim handler with the slots / types that use it and its timer phases,
    duplicates (same OAM) dropped."""
    who = {0x02: [(0, 0), (3, 3), (2, 2), (1, 1)], 0x04: [(0, 0), (3, 3)], 0x06: [(0, 0), (3, 3)],
           0x08: None, 0x0A: [(1, 1)], 0x0C: [(3, 3), (2, 2)], 0x0E: [(3, 3)], 0x10: None,
           0x12: [(2, 2)], 0x13: [(2, 2)], 0x14: [(2, 2)], 0x15: [(2, 2)], 0x16: [(0, 0)],
           0x18: [(1, 0)], 0x1C: [(0, 0)], 0x1E: [(0, 0)], 0x20: [(3, 3), (2, 2), (1, 1)],
           0x22: [(3, 3), (2, 2)], 0x24: [(3, 3)]}
    names = {0x02: "walk", 0x04: "hop", 0x06: "fall / bounce", 0x0A: "anim 0A", 0x0C: "stunned",
             0x0E: "stunned, blinking", 0x12: "slot 2 still", 0x13: "slot 2 on item", 0x14: "slot 2 scored",
             0x15: "slot 2 scored (variant)", 0x16: "player death", 0x18: "bonus goal", 0x1C: "title object",
             0x1E: "player caught", 0x20: "knocked out", 0x22: "drop-stun points", 0x24: "drop recover"}
    out, seen = [], set()
    for anim, users in who.items():
        if users is None:                                # the door wave's 8-byte records: not $0400 slots
            continue
        for slot, typ in users:
            for t7 in (0, 4, 8, 12, 0x40, 0x48):
                oam = draw_sprite(anim, slot, typ, t7, 1)
                if oam and oam not in seen:
                    seen.add(oam)
                    out.append((f"anim {anim:02X} {names.get(anim, '')}: slot {slot} type {typ} +7={t7:02X}", oam))
    return out


RAMP = " .:-=+*#%@"                  # dark -> bright: the backdrop is black, so bright reads as ink
FONT = {0x00: " "} | {0x01 + i: str(i) for i in range(10)} | {0x0B + i: chr(65 + i) for i in range(26)} \
       | {0x25: ".", 0x26: "(c)"}                                   # rom_data.FONT, the background font
FONT |= {0x8A: "=", 0x8B: "x"} | {t: "o" for t in range(0x28, 0x2C)}  # the results screen's = and x (by count
                                                                   # against its render), the balloon icon
SPRITE_FONT = dict(zip([0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xCA],
                       "PLAYER12GMOVD"))                             # read from mappy.chr, 2026-10-26


def ascii_art(img, bg_rgb):
    """A PIL image -> lines: cropped to its ink, brightness mapped onto RAMP. Narrow art doubles each
    pixel across (characters are about twice as tall as wide); tall art halves its rows."""
    px = img.convert("RGB").load()
    ink = [(x, y) for y in range(img.height) for x in range(img.width) if px[x, y] != bg_rgb]
    if not ink:
        return []
    x0, x1 = min(x for x, _ in ink), max(x for x, _ in ink)
    y0, y1 = min(y for _, y in ink), max(y for _, y in ink)
    wide = 2 if x1 - x0 < 32 else 1
    step = 2 if y1 - y0 >= 24 else 1
    lines = []
    for y in range(y0, y1 + 1, step):
        row = ""
        for x in range(x0, x1 + 1):
            vals = [px[x, yy] for yy in range(y, min(y + step, y1 + 1))]
            lum = max(0.0 if v == bg_rgb else (0.3 * v[0] + 0.59 * v[1] + 0.11 * v[2]) / 255 for v in vals)
            c = " " if lum == 0 else RAMP[1 + min(len(RAMP) - 2, int(lum * (len(RAMP) - 1)))]
            row += c * wide
        lines.append(row.rstrip())
    return lines


def text_of(cv, font):
    """A canvas of glyph tiles -> its rows as strings (an unknown glyph is shown as '?')."""
    rows = [cv.tiles[r * cv.cols:(r + 1) * cv.cols] for r in range(cv.rows)]
    return [''.join(font.get(t, "?") for t in row).rstrip() for row in rows]


def listing_art():
    """{'$ADDR': [comment lines]}: pictures as art, text blobs as strings, draw handlers as their first pose."""
    bg, spr = palettes()
    black = tuple(ppu.NES_MASTER_FCEUX[bg[0] & 0x3F])
    art = {}
    for title, addr, pal, nt in picture_jobs():
        if "bounces left" in title and "(bounces left 3)" not in title:
            continue                                    # one colour per trampoline frame is enough
        cv = draw_picture(addr, pal, nt)
        if cv is None:
            continue
        key = f"{addr:04X}"
        if title.startswith("text_line"):
            art[key] = [f'"{s}"' for s in text_of(cv, FONT) if s]
        else:
            art[key] = ascii_art(cv.render(CHR, bg, scale=1, master=ppu.NES_MASTER_FCEUX), black)
    for name, addr in ((n, a) for a, n in label_names().items() if n.startswith("spr_text_")):
        n = ROM[16 + addr - 0xC000 + 3]                 # [x lo][x hi][y][count][glyphs]
        glyphs = ROM[16 + addr - 0xC000 + 4:16 + addr - 0xC000 + 4 + n]
        art[f"{addr:04X}"] = ['"' + ''.join(SPRITE_FONT.get(g, " " if g == 0 else "?") for g in glyphs) + '"']
    # the draw-block lists (ppu_run_draw_blocks entries: title screen, HUD, round templates): run each
    # and decode the text rows it writes into the nametables; rows that are not text are left out
    for k in range(0, 10, 2):
        target = ROM[16 + 0xCC41 + k - 0xC000] | ROM[16 + 0xCC41 + k + 1 - 0xC000] << 8
        port, _, cpu = machine()
        port.vram[0x2000:0x2800] = bytes([SENTINEL]) * 0x800
        call(cpu, RUN_DRAW_BLOCKS, y=k)
        lines = []
        for page in (0x2000, 0x2400):
            for r in range(30):
                row = port.vram[page + 32 * r:page + 32 * r + 32]
                cells = [(c, t) for c, t in enumerate(row) if t != SENTINEL]
                if cells and all(t in FONT for _, t in cells) and any(t for _, t in cells):
                    c0 = cells[0][0]
                    text = "".join(FONT[t] for _, t in cells).strip()
                    if text:
                        lines.append(f'${page + 32 * r + c0:04X}: "{text}"')
        if lines:
            art[f"{target:04X}"] = lines
    # the ASCII copyright at $C000 (read by choose_cat_target_floor as random bits)
    end = next(a for a in range(0xC000, 0xC031) if not 0x20 <= ROM[16 + a - 0xC000] < 0x7F) \
        if any(not 0x20 <= ROM[16 + a - 0xC000] < 0x7F for a in range(0xC000, 0xC031)) else 0xC031   # $C031 is code (SEI)
    art["C000"] = ['"' + ROM[16:16 + end - 0xC000].decode("ascii") + '"']
    handlers = {}                                       # tbl_draw_by_anim: anim -> handler address
    for k in range(19):
        a = 0xC356 + 2 * k
        handlers[2 * k] = ROM[16 + a - 0xC000] | ROM[16 + a - 0xC000 + 1] << 8
    done = set()
    for title, oam in sprite_jobs():
        anim = int(title.split()[1], 16)
        h = handlers.get(anim & 0xFE)
        if h is None or h in done:
            continue
        done.add(h)
        im = ppu.render_sprites(CHR, oam, spr, Image.new("RGB", (96, 96), black), chr_base=0x1000,
                                master=ppu.NES_MASTER_FCEUX)
        art[f"{h:04X}"] = [f"(first pose: {title.split(':', 1)[1].strip()})"] + ascii_art(im, black)
    return art


def sheet(items, cell_w, cell_h, cols=6, label_h=12):
    rows = (len(items) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell_w, rows * (cell_h + label_h)), (40, 40, 40))
    d = ImageDraw.Draw(img)
    for i, (title, im) in enumerate(items):
        x, y = (i % cols) * cell_w, (i // cols) * (cell_h + label_h)
        img.paste(im, (x + (cell_w - im.width) // 2, y + label_h + (cell_h - im.height) // 2))
        d.text((x + 2, y), title[:cell_w // 6], fill=(220, 220, 220))
    return img


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    bg, spr = palettes()
    pics = []
    for title, addr, pal, nt in picture_jobs():
        cv = draw_picture(addr, pal, nt)
        if cv is None:
            print("  (draws nothing)", title)
            continue
        im = cv.render(CHR, bg, scale=SCALE, master=ppu.NES_MASTER_FCEUX)
        im.save(out / f"{title.split(' ')[0]}{'_' + str(pal) if 'bounces' in title else ''}.png")
        pics.append((title, im))
    sheet(pics, 64 * SCALE // 2 + 60, max(i.height for _, i in pics), cols=6).save(out / "pictures.png")
    sprites = []
    for title, oam in sprite_jobs():
        base = Image.new("RGB", (96, 96), tuple(ppu.NES_MASTER_FCEUX[bg[0] & 0x3F]))
        im = ppu.render_sprites(CHR, oam, spr, base, chr_base=0x1000, scale=2, master=ppu.NES_MASTER_FCEUX)
        sprites.append((title, im))
    sheet(sprites, 200, 192, cols=6).save(out / "sprites.png")
    print(f"{len(pics)} pictures, {len(sprites)} distinct sprite poses -> {out}")


if __name__ == "__main__":
    if "--art" in sys.argv:
        art = listing_art()
        (DATA / "listing_art.json").write_text(json.dumps(art, indent=1), encoding="utf-8")
        print(f"wrote listing_art.json: {len(art)} entries, {sum(len(v) for v in art.values())} lines")
    else:
        main(Path(sys.argv[1]) if len(sys.argv) > 1 else PICTURES)
