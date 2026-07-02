"""
Re-download ALL game art for The Tiffin Route into the project.
  python download_portraits.py            # download any missing assets
  python download_portraits.py --force    # re-download everything

These are the regenerated, game-ready assets (2026-07 art pass): clean top-down
pixel-art sprite sheets (transparent), clean bust portraits (day + spirit),
seamless tiles, transparent props, tiffin-tin UI skin, and title key art.

Post-download notes:
  * Tiles in assets/tiles/ are downscaled to 128x128 for repeat-tiling. Re-run:
      ffmpeg -y -i <src.png> -vf "scale=128:128:flags=lanczos" assets/tiles/<name>.png
  * Music ships as .ogg (Godot 4 cannot import .m4a). If you re-download the .m4a
    source, convert with:  ffmpeg -i music_day.m4a -c:a libvorbis music_day.ogg
"""
import urllib.request
import os
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
FORCE = "--force" in sys.argv
CDN = "https://d8j0ntlcm91z4.cloudfront.net/user_3F63nkWT7V1yAkun8oivzNQun6a/"

# (cdn_filename, local_relative_path, label)
ASSETS = [
    # ── WORLD CHARACTER SPRITE SHEETS (clean 2x2 directional, transparent) ──
    ("hf_20260701_151126_d8b8c969-ad9f-43b3-97f6-ac7c6f614ddc.png", "assets/sprites/npcs/player_world.png",    "Protagonist world sheet"),
    ("hf_20260701_151429_5c820dc0-731e-44af-8368-42fe48a2fb36.png", "assets/sprites/npcs/mrs_mehta_world.png",  "Mrs. Mehta world sheet"),
    ("hf_20260701_151438_cf3a9fc9-0477-4f83-8e62-ce2667e9d87b.png", "assets/sprites/npcs/raju_world.png",       "Raju world sheet"),
    ("hf_20260701_151413_e5673841-6af7-4f87-9b20-a8478065740f.png", "assets/sprites/npcs/desai_world.png",      "Desai world sheet"),
    ("hf_20260701_151418_2ce1c0ad-6f57-4543-9b77-a0e48b17ce87.png", "assets/sprites/npcs/arjun_world.png",      "Arjun world sheet"),
    ("hf_20260701_151418_3a21a9b3-97d0-4fe6-9ea0-678c0e553cc1.png", "assets/sprites/npcs/champa_world.png",     "Champa world sheet"),
    # ── DAY PORTRAITS (clean bust, transparent) ──
    ("hf_20260701_151644_62164d86-b827-40cc-bd7d-ab45f06574f5.png", "assets/sprites/npcs/player_portrait.png",    "Protagonist (day)"),
    ("hf_20260701_151646_f9138ce4-5130-4a0e-99bc-62b86c1c72a5.png", "assets/sprites/npcs/mrs_mehta_portrait.png", "Mrs. Mehta (day)"),
    ("hf_20260701_151655_89769fca-8bbc-412e-86e6-67f5d39c9717.png", "assets/sprites/npcs/raju_portrait.png",      "Raju (day)"),
    ("hf_20260701_151659_7d461859-c679-4897-848e-9d04317b0dc8.png", "assets/sprites/npcs/desai_portrait.png",     "Desai Sahib (day)"),
    ("hf_20260701_151701_0222d8bb-eb71-4929-89c1-048a91682f38.png", "assets/sprites/npcs/arjun_portrait.png",     "Arjun (day)"),
    ("hf_20260701_151711_7d08e534-53bc-48de-912b-bfdb4dff4624.png", "assets/sprites/npcs/champa_portrait.png",    "Champa Tai (day)"),
    # ── SPIRIT / NIGHT PORTRAITS (indigo glow, transparent) ──
    ("hf_20260701_151715_ea72c45d-97d2-434d-a6f8-2e924d3a0611.png", "assets/sprites/npcs/player_spirit_portrait.png",    "Protagonist (spirit)"),
    ("hf_20260701_151717_99d28edb-58f1-40f8-b242-e7e37490b0d4.png", "assets/sprites/npcs/mrs_mehta_spirit_portrait.png", "Mrs. Mehta (spirit)"),
    ("hf_20260701_151727_19ee0fd9-fb89-4ba5-9558-db04f705b2e4.png", "assets/sprites/npcs/raju_spirit_portrait.png",      "Raju (spirit)"),
    ("hf_20260701_151730_9def23f8-6ccc-4442-a41a-40993ce0b94b.png", "assets/sprites/npcs/desai_spirit_portrait.png",     "Desai Sahib (spirit)"),
    ("hf_20260701_151733_fde0f29e-d19c-46b3-bead-3336e0361509.png", "assets/sprites/npcs/arjun_spirit_portrait.png",     "Arjun (spirit)"),
    ("hf_20260701_151748_1c6bd791-011f-4cdd-a295-275bfd5cc1d6.png", "assets/sprites/npcs/champa_spirit_portrait.png",    "Champa Tai (spirit)"),
    # ── ENVIRONMENT TILES (seamless; downscale to 128 after download) ──
    ("hf_20260701_151751_f1f61f85-f0e5-4673-8fd0-b2af7c729d29.png", "assets/tiles/cobblestone_day.png",   "Cobblestone (day)"),
    ("hf_20260701_151754_78935355-3f0d-4612-b692-dae0fd46a3e4.png", "assets/tiles/cobblestone_night.png", "Cobblestone (night)"),
    ("hf_20260701_151804_762edabc-60ae-4c9f-98c4-18c9d90dfe16.png", "assets/tiles/tenement_facade.png",   "Tenement facade"),
    ("hf_20260701_151812_4cbae830-7d73-4a2a-8c15-ba21bd65abe7.png", "assets/tiles/temple_stone.png",      "Temple stone"),
    ("hf_20260701_151813_896ed451-69d6-40d3-923d-08689d2c1473.png", "assets/tiles/interior_floor.png",    "Interior floor"),
    # 2026-07-02 environment variety pass (downscale to 128x128 like the tiles above)
    ("hf_20260702_145240_611a79e5-0a3b-400d-9778-d61872f9b4fd.png", "assets/tiles/bazaar_shopfront.png",  "Bazaar shopfront (day)"),
    ("hf_20260702_145245_3a91430f-16d8-4ea2-be93-0933b126a83b.png", "assets/tiles/temple_wall.png",       "Temple wall (day)"),
    ("hf_20260702_145256_a432409a-d614-44c2-a873-0cf80b018b79.png", "assets/tiles/tenement_night.png",    "Tenement w/ lit windows (night)"),
    # ── PROP SPRITES (transparent) ──
    ("hf_20260701_151824_c9d67617-8de6-4826-8244-2f206b31256b.png", "assets/sprites/props/chai_stall.png",       "Chai tea stall"),
    ("hf_20260701_151829_a1bc5dc1-f0a1-44fa-a6b5-766abcfece43.png", "assets/sprites/props/municipal_office.png", "Municipal office"),
    ("hf_20260701_151830_4e1869d8-997e-4981-aae0-a0faeecf2b8c.png", "assets/sprites/props/market_props.png",     "Market vegetable cart"),
    ("hf_20260701_151849_08cca248-93fc-4134-91dd-bc2d8dc4ba79.png", "assets/sprites/props/street_props.png",     "Street lamp"),
    # ── UI SKIN ──
    ("hf_20260701_151853_21ea6291-d13d-49ab-8d6c-ccf081afa090.png", "assets/ui/dialogue_frame.png", "Dialogue box frame (tiffin tin)"),
    ("hf_20260701_151857_d3fbda23-6a46-4213-aa36-83be75dce37a.png", "assets/ui/journal_cover.png",  "Route journal cover"),
    ("hf_20260701_151908_8468e822-5cb4-466d-a3d6-30a56a99a975.png", "assets/ui/title_key_art.png",  "Title screen key art"),
    ("hf_20260702_145300_77ab5a67-13e3-4c78-be52-ee8d3ae1c4e7.png", "assets/ui/ending_key_art.png", "Ending screen dawn key art"),
    # NOTE: Audio (assets/audio/sfx_*.mp3, music_day.ogg, music_night.ogg) is not
    # re-fetched here; the .mp3 SFX ship in-repo and the music was converted from the
    # original .m4a sources to .ogg via ffmpeg (see header note). Only the 2026-07
    # visual art pass is reproducible from this manifest.
]

ok = skipped = failed = 0
for cdn_file, rel, label in ASSETS:
    dest = os.path.join(BASE, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(dest) and os.path.getsize(dest) > 1000 and not FORCE:
        print(f"  skip  {label:34s} (already present)")
        skipped += 1
        continue
    print(f"  dl    {label:34s} ...", end=" ", flush=True)
    try:
        urllib.request.urlretrieve(CDN + cdn_file, dest)
        print(f"{os.path.getsize(dest) / 1024:.0f} KB OK")
        ok += 1
    except Exception as e:
        print(f"FAILED - {e}")
        failed += 1

print(f"\nDone: {ok} downloaded, {skipped} skipped, {failed} failed.")
if ok > 0:
    print("Reimport in Godot: FileSystem panel -> right-click assets/ -> Reimport.")
