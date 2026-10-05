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
| `hair_sim.js` | The physics, on the CPU in a Web Worker: stepping, settling a new groom, scissors and shortening. |
| `hair_engine.js` | The hair on the GPU: strands, short-hair shells, and the bridge to the simulator. |
| `designer.js` | Scene, head, gestures, tools, quality tiers, and the Flutter bridge (documented at its top). |

**The head** is "Infinite, 3D Head Scan" by Lee Perry-Smith (ir-ltd.net), **CC BY 3.0**. The credit appears in the editor's ⓘ dialog. Source files and the licence are in `tools/head-asset/source/`. The scan is scaled to 23 cm from crown to chin; 1 scene unit = 10 cm.

## How the hair works

**Scalp UV:** `u = azimuth / 2π` and `v = polar / 130°`, with angles taken on the cranium ellipsoid fitted to the scan. The polar angle is measured from the crown, and azimuth π/2 is the face. Everything about the hair is a field in this space:
- **The base length** is a formula of the preset and its parameters, times the hairline.
- **Painted fields** are 2D canvases holding the length and the dye that the tools paint.

The **scalp map** (in `head_asset.js`) gives the skin position and normal for each UV point. Roots and shells sit on it, and it also gives the head's real shape for collisions.

**Hair has two layers:**
- **Shells** (the fur technique) draw everything up to 2 cm: buzz cuts, fades, razor lines and stubble. They're blended layer by layer from the scalp out, drawn after the strands and with no depth writes.
  - **Up close**, each cell of a jittered cube-projected grid draws its own antialiased hair.
  - **At a distance**, each layer is drawn at the coverage those hairs average to, textured by clumps and streaks fixed on the head. It is never random per pixel, which shows as static.
  - **Opacity follows length**: about 15% at 2 mm and nearly full at 12 mm. That's what makes a fade read as a fade.
  - **Beneath strands**, the shells are only a 1.5 mm undercoat of matte, dark roots. At full height they would swallow the strands lying on the head.
- **Guide strands** cover anything longer: exactly the tier's budget of guides (~3,000), 24 points each.
  - Each guide is drawn as up to 8 children, ordered layer by layer, so drawing fewer instances thins the hair evenly.
  - Strands rest `STRAND_LIFT` (≈3 mm) off the scalp, above the undercoat.
- **Each child is a hair card**: a camera-facing strip ~3 mm wide, inside which the fragment shader draws 7 fine hairs, each with its own width, wobble, tip and shade.
  - Up close, the hairs separate with antialiased edges.
  - At a distance, the card reads as a nearly opaque lock, with the hairs shown as shading. This matters because alpha-to-coverage doesn't accumulate across overlapping layers that share an alpha, so thin, semi-transparent cards let the head show through.
  - Hair lying close to the scalp is darker (`clearOfScalp`).
- **Child data layout** (in `groom.js` and `hair_engine.js` together) is `aChildA = (row, random, tipTrim, rootU)`, `aChildB = (offset xyz, rootV)`. A mismatch here once shifted the strands into the head.

**The head** is a softened scan: a blurred (low-mip) read of the skin texture, its colour moved to the chosen skin tone and mostly evened out, and a softer normal map. It reads as a neutral model, not a particular person.

**Fades** follow the lower hairline all the way round. They graduate evenly from `fadeHeight`'s start line (low ~19°, mid ~29°, high ~40° above the hairline) down to skin just above it.

**Physics** runs on the CPU in a Web Worker (`hair_sim.js`), built from the file's own source as a blob, because a `file://` page can't load a worker by URL. If that fails, the same code runs on the main thread.
- Each step is a Verlet prediction (gravity, gusty wind, damping, global shape memory), then follow-the-leader (Müller et al. 2012) out from the pinned root. That pass handles local shape memory, collisions (the scan's real skin, then the face, neck and shoulders), friction, and the paper's velocity correction, without which strands whip.
- It runs at 1/120 s steps, at most two per frame, so a slow step doesn't snowball.
- **Everything is in body space**, so collision and rest shapes need no per-vertex transforms. When the bust turns, the strands move by the inverse turn (they keep their place in the world and lag behind the head), and gravity and wind are turned into body space. The strand shader applies the bust's transform.
- The skin collision reads a 64² **cube map** of the skin radius by direction. That's divisions only, where the scalp map's polar/azimuth needed `acos` and `atan2` for every vertex.
- A **new groom settles in the worker** (36 big, heavily damped steps) while the old hair stays on screen, and the settled shape becomes its rest shape.
- The main thread asks for one step per frame, never two at once. Positions come back as a transferred `Float32Array` (RGBA rows, V texels per strand), are uploaded as a float texture, and the buffer goes back to the worker with the next request.
- Why not the GPU: it was the original design, with fragment passes. A fragment writes one vertex, so each one walked its strand from the root (V² work). On the Galaxy A33 that cost 10–50 ms of GPU per frame, competed with drawing, and froze the view for over a second on every new groom.

**Scissors** run in the simulator. Each swipe segment projects the strands on the camera's side to the screen and cuts each one where the swipe crosses it, resampling the kept part so it keeps its shape. When the finger lifts, the simulator sends the swipe's cuts back.

A strand is cut at most once per swipe. Each cut strand is recorded as a point `[u, v, length]` on a `cut` stroke, so the cut rebuilds the same on any phone whatever its strand count. Clipper and razor strokes shorten strands in place; anything that would need to grow triggers a rebuild.

**Keeping it responsive on a phone.** Each of these caused visible lag before it was fixed:
- **Rebuilding the hair:** `buildGuides` is a generator. The designer runs it in slices of about 8 ms per frame while the old hair stays on screen. The new groom then settles in the worker and swaps in when it's done.
- **Profiling:** in debug and profile builds, Flutter calls `enableProfiling()`, and the designer's console (including frame-time breakdowns and the simulator's step time) appears in `flutter run`'s output. Run `flutter run --profile` with the phone on USB to measure.
- **Garbage collection:** the guide builder's helpers (`uvOf`, `collide`, `combDirection`) write into scratch objects, because hundreds of thousands of throwaway vectors make the phone pause to collect garbage.
- **Touch input:** pointer events only record positions; the work happens once per frame.
  - Brush strokes resolve at most 4 points per frame through `pickScalp`, a ray march through the scalp map that takes ~0.06 ms, instead of raycasting the mesh's 17k triangles.
- **Sliders:** they recompute the base field (with the hairline cached) at most every 90 ms. The strands rebuild 180 ms after the slider rests.
- **Shells:** beneath strands, only the bottom shell layer is drawn; the rest are discarded before any work.
- **Collision:** strand points far from the skull skip the scalp-map lookup.

**Rendering is on demand:** frames are drawn only while something moves, and for 3 s after while the hair settles.

**Quality tiers** step down (never up) while back-to-back frames run under ~38 fps, since below that, touch already feels laggy. Each tier lowers the pixel ratio (2, 1.5, 1.25, 1), then the child layers (8, 6, 5, 4), then the guide budget (3,000, 2,200, 1,500).

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
