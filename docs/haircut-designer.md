# 3D haircut designer

Customers design a cut in 3D to show their barber exactly what they want. Product decisions (Oct 2026): a polished **stylized** look that's accurate in barber terms (guard numbers, fade height) rather than photoreal; presets for **all styles** (barbershop and long/women's cuts); later extras: beards, razor line designs, braids/cornrows/locs, head/face shape and hairline.

## Architecture

three.js (r160, classic build) runs in a WebView: `mobile/assets/haircut_designer/designer.js`, hosted by `design_editor_screen.dart` and `design_detail_screen.dart` through a small JS bridge (documented at the top of `designer.js`).

**Everything about the hair is a field over the scalp**, indexed by scalp UV: `u = azimuth / 2π`, `v = polar / 130°` (polar measured from the crown; 130° reaches the nape). The base style (length, fade, part, hairlines) is a formula over UV, and the tools paint into 2D canvases in the same UV space (`lengthMask`, `colorMask`). The GPU reads the fields directly, so a slider change or a brush stroke only updates a uniform or re-uploads a texture. No geometry is rebuilt on the CPU.

There are two hair layers, both shaped entirely in shaders:
- **Shells** (fur technique): 14 offset copies of the scalp, cut into individual hairs in the fragment shader, on a cube-projected jittered grid. They draw all hair up to `SHELL_MAX_LENGTH` (≈ guard 3): buzz cuts, fades, razor lines, stubble. They also serve as the undercoat beneath longer hair. When zoomed out, each pixel keeps the share of the cell a hair covers, so fades lighten correctly at any zoom.
- **Strands**: camera-facing ribbons (16 segments) for longer hair. Each one is bent by gravity, kept outside the head ellipsoid, combed away from the crown and the part, and curled into a helix. Lighting is Kajiya-Kay (band-shaped hair shine).

**Performance:** frames are drawn only when something changes (render on demand), so an idle designer costs nothing. Up to 20k strands are built once; if consecutive frames run below ~40 fps the visible count steps down (never back up), with a floor of 4k. The pixel ratio is capped at 2.

**Gestures:** one finger rotates (with fling inertia), or paints when a tool is selected. Two fingers pinch to zoom and pan; a second finger landing mid-stroke cancels that stroke. Double-tap resets the view, and `setView()` animates to front/left/right/back/top.

## Saved format

`haircut_designs.parameters` JSONB is `HairParameters` (Dart) and `currentParams + strokes` (JS). Strokes are UV polylines, not pixels, so mask resolution can change freely. `version` records the scalp mapping: v1 (no key) mapped polar 0–100°, and v2 maps 0–130°. `loadStrokes` converts v1 strokes on load, and the next save writes v2. Any future change to what stored values mean must bump the version and add a conversion there.

## Roadmap

Each stage ships on its own and is checked on a real phone before the next one starts.

1. **Engine:** GPU field renderer, gestures, view presets, v1→v2 conversion. *(done)*
2. **Presets:** pick a cut from the review haircut list (plus long and women's styles) and the fields are seeded with that cut. This needs a comb-direction field so slick backs, quiffs and side parts can be expressed.
3. **Tools:** comb (sets direction), thinning/density, grow, mirror (symmetric) painting, soft brushes, redo, an exact colour picker (wheel + hex), dye gradients and highlights, and a brush cursor on the head.
4. **Hair types:** per-region curl pattern along the straight → wavy → curly → coily scale, fine vs thick strands, and coily/afro volume.
5. **Extras:** beard and facial-hair area, razor line designs, braids/cornrows/locs (structured geometry, not strands), and head/face shape plus hairline.
