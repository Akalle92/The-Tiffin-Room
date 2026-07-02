"""Download Higgsfield remove_background outputs over the local portraits,
then render a review grid over magenta."""
import os
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NPC_DIR = os.path.join(ROOT, "assets", "sprites", "npcs")
CDN = "https://d8j0ntlcm91z4.cloudfront.net/user_3F63nkWT7V1yAkun8oivzNQun6a/"

FILES = {
    "mrs_mehta_portrait.png":        "hf_20260702_144034_171b214c-3bc8-4377-aa45-6cf0efcd6da3.png",
    "mrs_mehta_spirit_portrait.png": "hf_20260702_144033_e4082802-6df9-4066-ac92-553a4d6f1149.png",
    "raju_portrait.png":             "hf_20260702_144035_f17e78a0-2077-4e30-8993-4535e7eb6f1d.png",
    "raju_spirit_portrait.png":      "hf_20260702_144036_2a5b074b-d898-49b1-b3cb-84588e25b131.png",
    "desai_portrait.png":            "hf_20260702_144045_c62876f8-9992-4fae-81ec-4c6ff5774028.png",
    "desai_spirit_portrait.png":     "hf_20260702_144047_571e5baa-87da-4fbf-a646-dbeec880ec04.png",
    "arjun_portrait.png":            "hf_20260702_144049_2db3d067-258e-4386-9391-e2e7a9eb8bd0.png",
    "arjun_spirit_portrait.png":     "hf_20260702_144050_7760ae70-325c-40bc-8a9e-85ce63597a52.png",
    "champa_portrait.png":           "hf_20260702_144100_d624dec8-053f-4656-850c-555c236e3aef.png",
    "champa_spirit_portrait.png":    "hf_20260702_144101_befbe568-efe1-44d6-b862-8e54efdbb3cb.png",
    "player_portrait.png":           "hf_20260702_144103_d43f1028-eda2-4df2-8de4-1f028092efa8.png",
    "player_spirit_portrait.png":    "hf_20260702_144104_90d3cb30-83bb-4697-9b04-fe1eb332753a.png",
}

thumbs = []
for local, remote in FILES.items():
    path = os.path.join(NPC_DIR, local)
    urllib.request.urlretrieve(CDN + remote, path)
    im = Image.open(path).convert("RGBA")
    alpha = im.getchannel("A")
    lo, hi = alpha.getextrema()
    transparent = sum(1 for a in alpha.getdata() if a < 10) / (im.width * im.height)
    print(f"{local:36s} {im.size}  transparent={transparent * 100:5.1f}%  alpha_range=({lo},{hi})")
    thumbs.append(im.resize((256, 256), Image.LANCZOS))

grid = Image.new("RGBA", (4 * 256, 3 * 256), (255, 0, 255, 255))
for i, t in enumerate(thumbs):
    grid.paste(t, ((i % 4) * 256, (i // 4) * 256), t)
grid.convert("RGB").save(os.path.join(ROOT, "tools", "portrait_check.png"))
print("review grid updated")
