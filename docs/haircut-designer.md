# 3D haircut designer

Customers design a cut in 3D, with real hair physics, to show their barber exactly what they want. The reference is [Digital Salon](https://digital-salon.github.io/) (SIGGRAPH Asia 2024): strand physics, cutting, and simulated motion, scaled down to run on a phone.

Product decisions (Oct 2026):
- Physics and editing run **on the phone**. Photoreal pictures of the result will come from a cloud AI image service, on a generic model and never on the customer's own face.
- **Starting cuts are our own** procedural presets. Digital Salon's code is MIT-licensed, but its hairstyle data (USC-HairSalon, CT2Hair) is non-commercial only, so we don't use it.
- Full quality targets ~2021+ mid-range phones. Others step down automatically.
- **Measured on a Galaxy with a Mali-G68** (the proof of concept, 2022 mid-range): 37 fps with 1,500 simulated / 12,000 drawn strands, and 25 fps with 3,000 / 24,000.

## Files (`mobile/assets/haircut_designer/`)

The WebView loads these over `file://`, which can't `fetch()`, so everything ships as classic scripts loaded in order:

| File | What |
|---|---|
| `three.min.js` | three.js r160 (classic build) |
| `head_asset.js` | **Generated** by `tools/head-asset/build_head_asset.py`. Contains the scan (quantised mesh, textures as data URIs), the collision shapes fitted to it, and the scalp map. |
| `groom.js` | What the hair is: presets, the fields over the scalp, and guide strands (CPU). |
| `hair_engine.js` | The hair on the GPU: physics, strands, short-hair shells, and the scissors. |
| `designer.js` | Scene, head, gestures, tools, quality tiers, and the Flutter bridge (documented at its top). |

**The head** is "Infinite, 3D Head Scan" by Lee Perry-Smith (ir-ltd.net), **CC BY 3.0**. The credit appears in the editor's ⓘ dialog. Source files and the licence are in `tools/head-asset/source/`. The scan is scaled to 23 cm from crown to chin; 1 scene unit = 10 cm.

## How the hair works

**Scalp UV:** `u = azimuth / 2π` and `v = polar / 130°`, with angles taken on the cranium ellipsoid fitted to the scan. The polar angle is measured from the crown, and azimuth π/2 is the face. Everything about the hair is a field in this space:
- **The base length** is a formula of the preset and its parameters, times the hairline.
- **Painted fields** are 2D canvases holding the length and the dye that the tools paint.

The **scalp map** (in `head_asset.js`) gives the skin position and normal for each UV point. Roots and shells sit on it, and it also gives the head's real shape for collisions.

**Hair has two layers:**
- **Shells** (the fur technique) draw everything up to 2 cm: buzz cuts, fades, razor lines and stubble. They also act as the undercoat beneath longer hair.
  - The hair cells are jittered on a cube-projected grid.
  - When zoomed out, each pixel shows the share of the cell a hair covers.
  - Each hair gets its own lighting direction.
  - Hairs thin toward the hairline, and the upper layers thin when seen edge-on.
- **Guide strands** cover anything longer: up to ~3,000 guides of 24 points, each drawn as up to 8 child strands. The children are ordered layer by layer, so drawing fewer instances thins the hair evenly.

**Physics** runs entirely in fragment passes, with state textures that are 2V wide (position and previous position):
- `integrate`: a Verlet step with gravity, gusty wind, damping and global shape memory.
- `constrain`: follow-the-leader (Müller et al. 2012). It handles local shape memory, collisions (the scan's real skin, then the face, neck and shoulders), friction, and the paper's velocity correction, without which strands whip.
- Two substeps run per frame at 1/120 s. A new groom settles quickly first, and the settled shape then becomes its rest shape.

**Scissors** run on the GPU:
1. A pass finds where the swipe crosses each strand.
2. The CPU reads back one value per strand.
3. Another pass resamples the cut strands, so the kept part keeps its shape.

A strand is cut at most once per swipe. Each cut strand is recorded as a point `[u, v, length]` on a `cut` stroke, so the cut rebuilds the same on any phone whatever its strand count. Clipper and razor strokes shorten strands in place; anything that would need to grow triggers a rebuild.

**Rendering is on demand:** frames are drawn only while something moves, and for 3 s after while the hair settles.

**Quality tiers** step down (never up) while back-to-back frames run under ~27 fps. Each tier lowers the pixel ratio (2, 1.5, 1.25, 1), then the child layers (8, 6, 5, 4), then the guide budget (3,000, 2,200, 1,500).

## Saved format

`haircut_designs.parameters` JSONB is `HairParameters` in Dart and `design` in `designer.js`:
- `version`, `preset`, `length` (the top's length, in 0.5 cm units), `volume`, `curl`, `colorHex`, `partOffset`, `fadeHeight`, `faceParams.skinTone`;
- `strokes`: `clipper`/`razor` (guard), `dye` (colorHex) and `cut` (per-strand lengths). `scissors` (a brush to a length) only appears in pre-v3 designs.

**Versions:**
- v1 mapped polar 0–100° onto `v`; v2 onward map 0–130°.
- Designs before v3 had no presets, so they load as the `custom` preset (one length, a parting gap, a taper).
- Any future change to what stored values mean must bump the version and add a conversion in `designer.js`'s `upgrade()`.

**Clipper guards are real sizes:** skin, then #1 3 mm, #2 6 mm, #3 10 mm, #4 13 mm, #5 16 mm, #6 19 mm, #7 22 mm and #8 25 mm.

## Presets

All presets are defined in `groom.js` `PRESETS`; the Dart list is `haircutPresets`.
- **Barbershop:** buzz, crew, fade, undercut, pompadour, quiff, slick back, textured crop, mullet, afro, bald.
- **Longer cuts:** long layers, bob, pixie, curtains, curly.

Each preset is parameters only, with no stored geometry:
- the region length ratios;
- the fade (`skin`, or `taper` for `custom`) and an optional undercut line;
- the comb (`down`, `back`, `up`, `forward`, `side`, `center`, `out`);
- root lift, product hold and bend;
- physics stiffness.

## Roadmap

1. *(done)* Physics engine, realistic head, presets, scissors / clipper / razor / dye with mirror, wind and shake, quality tiers, and the editor UI.
2. **Hair-hair interaction:** volume preservation and collective motion, via a coarse velocity/density grid.
3. **More tools:** comb (direction), grow, thinning, a brush cursor on the head, and redo.
4. **Hair types:** per-region curl patterns along the straight → coily scale, and coily/afro volume.
5. **AI photoreal image:** render a control image, then a cloud image model on a generic model. This needs a provider account.
6. **"Describe your cut":** an AI maps text to a preset and parameters.
7. **Extras:** beards, razor line designs, braids/cornrows/locs (structured geometry, not strands), and head/face shapes.
