// What the hair is: haircut presets, the fields over the scalp, and the guide
// strands built from them. Pure CPU; hair_engine.js puts it on the GPU.
//
// Scalp UV: u = azimuth / 2π, v = polar / MAX_POLAR, angles taken on the
// fitted cranium ellipsoid (polar from the crown, azimuth π/2 = the face).
// Every field lives in this space:
//   base length  a formula of the preset and its parameters (× hairline)
//   painted      strokes from the tools, in 2D canvases: length and colour
// A design = preset + parameters + strokes, so it rebuilds identically on
// any phone whatever its strand count.
//
// Lengths in designs are in 0.5 cm units (as since design v1); the scene
// uses 1 = 10 cm.

(function () {
  const asset = window.HEAD_ASSET;
  const deg = Math.PI / 180;

  const LENGTH_TO_SCENE = 0.05;
  const MAX_LENGTH = 100; // 50 cm
  const V = 24; // vertices per guide strand
  // Drawn strands are this share of the length field at their root, at
  // random: cut hair doesn't end in one line.
  const STRAND_LENGTH_JITTER = [0.8, 1.1];
  // Shells draw hair up to this length (scene units, 2 cm) — at that length
  // they look better than strands; guides exist only where hair is longer.
  const SHELL_MAX_LENGTH = 0.2;
  const STRAND_MIN_LENGTH = 0.17;
  // How far off the scalp strands lie (as a share of the cranium's size,
  // ≈ 3 mm): above the shells' 1.5 mm root undercoat, which would
  // otherwise hide them.
  const STRAND_LIFT = 0.03;

  // Real clipper guard lengths, in 0.5 cm units: skin, #1 3 mm, #2 6 mm,
  // #3 10 mm, #4 13 mm, #5 16 mm, #6 19 mm, #7 22 mm, #8 25 mm.
  const CLIPPER_GUARD_LENGTHS = [0, 0.6, 1.2, 2, 2.6, 3.2, 3.8, 4.4, 5];

  // --- Hair types ----------------------------------------------------------------
  //
  // The 1A-4C scale. Types differ in the strand's shape, not just how much
  // it curls:
  //   pattern     0 straight, 1 a flat "S" wave (side to side in the hair's
  //               sheet), 2 a spiral (ringlets, coils), 3 a "Z" zig-zag
  //   diameter    of the wave / spiral, cm
  //   wavelength  one turn, cm (the curl's tightness)
  //   definition  how much strands gather into ringlets, 0..1
  //   frizz       stray, fine kinks off the pattern, 0..1
  //   shine       0..1
  //   shrink      how much shorter it looks than its length when pulled
  //               straight (a coiled 10 cm 4C hair looks ~2.5 cm)
  //   curliness   0..1, for what the groom does with it: curlier hair falls
  //               less and stands further off the head
  const HAIR_TYPES = [
    { id: '1A', pattern: 0, diameter: 0, wavelength: 1, definition: 0.35, frizz: 0, shine: 1, shrink: 0, curliness: 0 },
    { id: '1B', pattern: 0, diameter: 0, wavelength: 1, definition: 0.45, frizz: 0.05, shine: 0.8, shrink: 0, curliness: 0.05 },
    { id: '1C', pattern: 1, diameter: 0.3, wavelength: 8, definition: 0.5, frizz: 0.2, shine: 0.6, shrink: 0.02, curliness: 0.1 },
    { id: '2A', pattern: 1, diameter: 1, wavelength: 6, definition: 0.55, frizz: 0.1, shine: 0.7, shrink: 0.05, curliness: 0.25 },
    { id: '2B', pattern: 1, diameter: 1.6, wavelength: 4.5, definition: 0.7, frizz: 0.2, shine: 0.6, shrink: 0.1, curliness: 0.35 },
    { id: '2C', pattern: 1, diameter: 2, wavelength: 3.5, definition: 0.75, frizz: 0.45, shine: 0.45, shrink: 0.15, curliness: 0.45 },
    { id: '3A', pattern: 2, diameter: 3, wavelength: 4, definition: 0.85, frizz: 0.2, shine: 0.6, shrink: 0.2, curliness: 0.6 },
    { id: '3B', pattern: 2, diameter: 2, wavelength: 2.6, definition: 0.9, frizz: 0.3, shine: 0.45, shrink: 0.3, curliness: 0.7 },
    { id: '3C', pattern: 2, diameter: 1, wavelength: 1.5, definition: 0.85, frizz: 0.45, shine: 0.35, shrink: 0.4, curliness: 0.8 },
    { id: '4A', pattern: 2, diameter: 0.6, wavelength: 0.8, definition: 0.6, frizz: 0.6, shine: 0.25, shrink: 0.55, curliness: 0.9 },
    { id: '4B', pattern: 3, diameter: 0.5, wavelength: 0.6, definition: 0.35, frizz: 0.7, shine: 0.15, shrink: 0.7, curliness: 0.95 },
    { id: '4C', pattern: 3, diameter: 0.35, wavelength: 0.4, definition: 0.15, frizz: 0.85, shine: 0.1, shrink: 0.75, curliness: 1 },
  ];
  const HAIR_TYPE_INDEX = Object.fromEntries(HAIR_TYPES.map((type, i) => [type.id, i]));

  function hairTypeOf(id) {
    return HAIR_TYPES[HAIR_TYPE_INDEX[id] ?? HAIR_TYPE_INDEX['1B']];
  }

  // --- The scan's scalp map and collision shapes ------------------------------

  function decodeBase64(text, Type) {
    const binary = atob(text);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return new Type(bytes.buffer);
  }

  const scalpInfo = asset.scalpMap;
  const scalpData = decodeBase64(scalpInfo.data, Float32Array);
  const MAX_POLAR = scalpInfo.maxPolar;
  const collision = asset.collision;
  const CRANIUM = new THREE.Vector3().fromArray(collision.cranium.radii);
  // Scene units per cranium unit, roughly: for heights above the skull.
  const CRANIUM_SCALE = (CRANIUM.x + CRANIUM.y + CRANIUM.z) / 3;

  // How far out the skin is along each scalp direction, as a multiple of
  // the cranium ellipsoid — the head's real shape for collisions.
  const skinRadius = new Float32Array(scalpInfo.width * scalpInfo.height);
  for (let i = 0; i < skinRadius.length; i++) {
    const x = scalpData[i * 6] / CRANIUM.x;
    const y = scalpData[i * 6 + 1] / CRANIUM.y;
    const z = scalpData[i * 6 + 2] / CRANIUM.z;
    skinRadius[i] = Math.hypot(x, y, z);
  }

  function sampleGrid(data, channels, width, height, u, v, channel) {
    const x = ((u % 1) + 1) % 1 * width;
    const y = Math.min(Math.max(v, 0), 1) * (height - 1);
    const x0 = Math.floor(x) % width;
    const x1 = (x0 + 1) % width;
    const y0 = Math.min(Math.floor(y), height - 1);
    const y1 = Math.min(y0 + 1, height - 1);
    const fx = x - Math.floor(x);
    const fy = y - y0;
    const r0 = y0 * width;
    const r1 = y1 * width;
    return (data[(r0 + x0) * channels + channel] * (1 - fx) + data[(r0 + x1) * channels + channel] * fx) * (1 - fy)
      + (data[(r1 + x0) * channels + channel] * (1 - fx) + data[(r1 + x1) * channels + channel] * fx) * fy;
  }

  function scalpPoint(u, v) {
    const s = (channel) => sampleGrid(scalpData, 6, scalpInfo.width, scalpInfo.height, u, v, channel);
    return {
      position: new THREE.Vector3(s(0), s(1), s(2)),
      normal: new THREE.Vector3(s(3), s(4), s(5)).normalize(),
    };
  }

  function unitFromUV(u, v) {
    const azimuth = u * 2 * Math.PI;
    const polar = v * MAX_POLAR;
    return new THREE.Vector3(Math.sin(polar) * Math.cos(azimuth), Math.cos(polar), Math.sin(polar) * Math.sin(azimuth));
  }

  // Scalp UV of the direction of point p (on the cranium ellipsoid), and
  // that direction (`unit`) and p's distance from the centre in cranium
  // units (`radius`). Writes into `out` — the guide builder calls this for
  // every strand vertex, and fresh objects each time make the phone pause
  // to collect garbage.
  function uvOf(p, out = { u: 0, v: 0, radius: 0, unit: new THREE.Vector3() }) {
    const unit = out.unit.set(p.x / CRANIUM.x, p.y / CRANIUM.y, p.z / CRANIUM.z);
    out.radius = unit.length();
    unit.divideScalar(Math.max(out.radius, 1e-9));
    let azimuth = Math.atan2(unit.z, unit.x);
    if (azimuth < 0) azimuth += 2 * Math.PI;
    out.u = azimuth / (2 * Math.PI);
    out.v = Math.acos(Math.min(1, Math.max(-1, unit.y))) / MAX_POLAR;
    return out;
  }

  function skinRadiusAt(u, v) {
    return sampleGrid(skinRadius, 1, scalpInfo.width, scalpInfo.height, u, v, 0);
  }

  const collideScratch = { u: 0, v: 0, radius: 0, unit: new THREE.Vector3() };

  // Pushes p out of the head, face, neck and shoulders by `margin` (scene
  // units). Mirrors collide() in hair_engine.js.
  function collide(p, margin) {
    const { u, v, radius, unit } = uvOf(p, collideScratch);
    if (v <= 1) {
      const minimum = skinRadiusAt(u, v) + margin;
      if (radius < minimum) p.set(unit.x * minimum * CRANIUM.x, unit.y * minimum * CRANIUM.y, unit.z * minimum * CRANIUM.z);
    }
    pushOutOfEllipsoid(p, collision.face.center, collision.face.radii, 1 + margin);
    const neck = collision.neck;
    if (p.y < neck.center[1] + 0.6 && p.y > neck.center[1] - 0.9) {
      const dx = p.x - neck.center[0];
      const dz = p.z - neck.center[2];
      const r = Math.sqrt(dx * dx + dz * dz);
      const minimum = neck.radius + margin;
      if (r < minimum && r > 1e-6) {
        p.x = neck.center[0] + (dx / r) * minimum;
        p.z = neck.center[2] + (dz / r) * minimum;
      }
    }
    pushOutOfEllipsoid(p, collision.shoulders.center, collision.shoulders.radii, 1 + margin);
  }

  function pushOutOfEllipsoid(p, center, radii, minimum) {
    const ex = (p.x - center[0]) / radii[0];
    const ey = (p.y - center[1]) / radii[1];
    const ez = (p.z - center[2]) / radii[2];
    const r = Math.sqrt(ex * ex + ey * ey + ez * ez);
    if (r < minimum && r > 1e-6) {
      const k = minimum / r;
      p.set(center[0] + ex * k * radii[0], center[1] + ey * k * radii[1], center[2] + ez * k * radii[2]);
    }
  }

  function insideEllipsoid(p, center, radii) {
    const ex = (p.x - center[0]) / radii[0];
    const ey = (p.y - center[1]) / radii[1];
    const ez = (p.z - center[2]) / radii[2];
    return ex * ex + ey * ey + ez * ez < 1;
  }

  const pickScratch = { u: 0, v: 0, radius: 0, unit: new THREE.Vector3() };
  const pickPoint = new THREE.Vector3();

  // Where a ray (body space) first meets the scalp, as [u, v] — or null if
  // it misses, or meets the face or neck first. Marches through the scalp
  // map: a fraction of a millisecond, against tens of milliseconds for
  // testing the head mesh's 17,000 triangles on a phone.
  function pickScalp(origin, direction) {
    const reach = 1.6; // a sphere around the head
    const b = origin.dot(direction);
    const discriminant = b * b - (origin.lengthSq() - reach * reach);
    if (discriminant < 0) return null;
    const exit = -b + Math.sqrt(discriminant);
    let outside = Math.max(0, -b - Math.sqrt(discriminant));
    const hits = (t) => {
      pickPoint.copy(origin).addScaledVector(direction, t);
      const { u, v, radius } = uvOf(pickPoint, pickScratch);
      if (v <= 1) return radius < skinRadiusAt(u, v) ? 'scalp' : null;
      return insideEllipsoid(pickPoint, collision.face.center, collision.face.radii) || radius < 0.95 ? 'body' : null;
    };
    for (let t = outside; t <= exit; t += 0.01) {
      const hit = hits(t);
      if (hit === 'body') return null;
      if (hit === 'scalp') {
        let inside = t;
        for (let i = 0; i < 6; i++) {
          const middle = (outside + inside) / 2;
          if (hits(middle)) inside = middle;
          else outside = middle;
        }
        hits(inside);
        return [pickScratch.u, pickScratch.v];
      }
      outside = t;
    }
    return null;
  }

  // --- Hairline ------------------------------------------------------------------

  function smoothstep(a, b, x) {
    const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
    return t * t * (3 - 2 * t);
  }

  function angularDistance(a, b) {
    const d = Math.abs((a - b) % (2 * Math.PI));
    return d > Math.PI ? 2 * Math.PI - d : d;
  }

  // Where hair grows, tuned to the scan: the front hairline arcs over the
  // forehead and dips at the temples; the lower one runs from the
  // sideburns round the ears down to the nape. Polar angles from the crown
  // (bigger = lower on the head).
  const HAIRLINE = {
    faceHalfWidth: 50 * deg,
    center: 63 * deg,
    temple: 80 * deg,
    nape: 124 * deg,
  };
  const SIDEBURNS = { none: 92 * deg, short: 99 * deg, medium: 104 * deg, long: 113 * deg };

  // A design's hairline and edges (params.hairline), as a barber shapes them:
  //   shape      'rounded' | 'straight' (flat across, square corners) |
  //              'widowsPeak' | 'receding' (temples set back, an M)
  //   height     0 (low on the forehead) .. 1 (high)
  //   lineUp     a sharp, razor-edged line, rather than natural, soft edges
  //              with fine baby hairs
  //   sideburns  'none' | 'short' | 'medium' | 'long'
  //   neckline   'natural' | 'tapered' (soft, fading out) | 'rounded' |
  //              'block' (squared off)
  const BABY_HAIR_LENGTH = 0.12; // scene units: 1.2 cm
  const DEFAULT_EDGES = { shape: 'rounded', height: 0.5, lineUp: false, sideburns: 'medium', neckline: 'natural' };

  function edgesOf(params) {
    return { ...DEFAULT_EDGES, ...(params.hairline || {}) };
  }

  // The front hairline's polar angle, by angular distance from the middle
  // of the face.
  function frontLine(edges, delta) {
    const across = smoothstep(0, HAIRLINE.faceHalfWidth, delta);
    let line;
    switch (edges.shape) {
      case 'straight':
        line = HAIRLINE.center + (HAIRLINE.temple - HAIRLINE.center) * 0.6 * smoothstep(0.7 * HAIRLINE.faceHalfWidth, HAIRLINE.faceHalfWidth, delta);
        break;
      case 'widowsPeak':
        line = HAIRLINE.center + (HAIRLINE.temple - HAIRLINE.center) * across + 7 * deg * (1 - smoothstep(0, 9 * deg, delta));
        break;
      case 'receding':
        line = HAIRLINE.center + (HAIRLINE.temple - HAIRLINE.center) * across - 14 * deg * smoothstep(12 * deg, 38 * deg, delta);
        break;
      default:
        line = HAIRLINE.center + (HAIRLINE.temple - HAIRLINE.center) * across;
    }
    return line - (edges.height - 0.5) * 16 * deg;
  }

  // The lower hairline's polar angle, by angular distance from the face:
  // sideburns at the front, round the ears, down to the nape at the back.
  function lowerLine(edges, delta) {
    const sideburn = SIDEBURNS[edges.sideburns] ?? SIDEBURNS.medium;
    const natural = sideburn + (HAIRLINE.nape - sideburn) * smoothstep(80 * deg, 170 * deg, delta);
    switch (edges.neckline) {
      case 'block': // straight across the back, with corners
        return natural + (120 * deg - natural) * smoothstep(126 * deg, 134 * deg, delta);
      case 'rounded': // a U, highest at the corners
        return sideburn + (122 * deg - sideburn) * Math.pow(smoothstep(80 * deg, 180 * deg, delta), 0.6);
      default:
        return natural;
    }
  }

  // 0 where no hair grows, 1 on the scalp. Natural edges are soft, with a
  // thin band of sparse baby hairs just beyond the line; a line-up is
  // razor sharp.
  function hairline(u, v, edges) {
    const polar = v * MAX_POLAR;
    const delta = angularDistance(u * 2 * Math.PI, Math.PI / 2);
    const sharp = edges.lineUp ? 0.012 : 0;
    const front = frontLine(edges, delta);
    const vertical = 1 - smoothstep(front - (sharp || 0.08), front + (sharp || 0.08), polar);
    const horizontal = smoothstep(HAIRLINE.faceHalfWidth - (sharp || 0.18), HAIRLINE.faceHalfWidth + (sharp || 0.06), delta);
    const lowerAt = lowerLine(edges, delta);
    const soft = edges.neckline === 'tapered' ? 0.22 : 0.12;
    const lower = 1 - smoothstep(lowerAt - (sharp || soft), lowerAt + (sharp || 0.04), polar);
    const grows = Math.max(vertical, horizontal) * lower;
    if (edges.lineUp) return grows;
    const baby = 0.22 * (1 - smoothstep(front + 0.08, front + 0.16, polar)) * (1 - horizontal)
      + 0.22 * (1 - smoothstep(lowerAt + 0.04, lowerAt + 0.1, polar));
    return Math.max(grows, Math.min(0.22, baby) * (polar > front ? 1 : 0) * (polar < lowerAt + 0.12 ? 1 : 0));
  }

  // --- Presets -----------------------------------------------------------------
  //
  // defaults: the design parameters the preset starts from (length is the
  //   top's, in 0.5 cm units).
  // ratios: other regions' length relative to the top.
  // fade: 'taper' (designs v1/v2: shortens toward the bottom, never to skin)
  //   or 'skin' (a barber fade: down to skin, its height set by fadeHeight).
  // undercut: polar angle of a hard line below which hair is undercutLength.
  // comb: where the hair is combed (see combDirection).
  // volume: [fringe, top, crown, sides], cm: how high above the scalp hair
  //   rooted there rises (see volumeAt), over the middle `width` of the
  //   head (0..1, default 0.95), over the first `rise` of its
  //   length, and taper: how much of that height it gives up by its tip (a pompadour's
  //   front rises high and slopes down over the top). Hair from upstream
  //   lies over hair rooted under it (layerRank).
  // hold: how much of each strand keeps the comb's shape off the head
  //   (product). clump: how much hair gathers into pointed locks (textured
  //   cuts) rather than lying smooth (sleek, styled ones), 0..1. bend: how
  //   quickly free hair falls.
  // stiffness: [root, tip] shape memory for the physics (local: direction,
  //   global: position).

  const PRESETS = {
    custom: {
      label: 'Custom',
      defaults: { length: 8, fadeHeight: 0.3, partOffset: 0, hairType: '1B', volume: 1 },
      ratios: { fringe: 1, sides: 1, back: 1, nape: 1 },
      fade: 'taper', comb: 'down', volume: [1, 1, 1, 0.5], rise: 0.3, taper: 0.3, hold: 0, clump: 0.7, bend: 2.4,
      stiffness: { local: [0.5, 0.1], global: [0.1, 0] },
    },
    buzz: {
      label: 'Buzz Cut',
      defaults: { length: 1.2, fadeHeight: 0, partOffset: 0, hairType: '1B', volume: 1 },
      ratios: { fringe: 1, sides: 0.85, back: 0.85, nape: 0.7 },
      fade: 'skin', comb: 'down', volume: [0.4, 0.4, 0.4, 0.3], rise: 0.3, taper: 0, hold: 0, clump: 0.5, bend: 0.5,
      stiffness: { local: [0.9, 0.7], global: [0.5, 0.3] },
    },
    crew: {
      label: 'Crew Cut',
      defaults: { length: 4, fadeHeight: 0.35, partOffset: 0, hairType: '1B', volume: 1 },
      ratios: { fringe: 0.8, sides: 0.35, back: 0.4, nape: 0.3 },
      fade: 'skin', comb: 'forward', volume: [1.0, 1.2, 0.8, 0.3], rise: 0.4, taper: 0.2, hold: 0.6, clump: 0.8, bend: 0.6,
      stiffness: { local: [0.9, 0.6], global: [0.45, 0.2] },
    },
    fade: {
      label: 'Fade',
      defaults: { length: 8, fadeHeight: 0.55, partOffset: 0, hairType: '1B', volume: 1.1 },
      ratios: { fringe: 0.85, sides: 0.3, back: 0.3, nape: 0.2 },
      fade: 'skin', comb: 'forward', volume: [1.2, 1.5, 1.0, 0.3], rise: 0.35, taper: 0.3, hold: 0.5, clump: 0.8, bend: 0.9,
      stiffness: { local: [0.85, 0.45], global: [0.35, 0.1] },
    },
    undercut: {
      label: 'Undercut',
      defaults: { length: 16, fadeHeight: 0, partOffset: 0.25, hairType: '1B', volume: 1.1 },
      ratios: { fringe: 1.05, sides: 1, back: 1, nape: 1 },
      undercut: 72 * deg, undercutLength: 1.2,
      fade: 'skin', comb: 'back', volume: [2.5, 1.5, 0.8, 0.3], rise: 0.3, taper: 0.6, hold: 0.85, clump: 0.4, bend: 1.2,
      stiffness: { local: [0.85, 0.35], global: [0.3, 0.05] },
    },
    pompadour: {
      label: 'Pompadour',
      defaults: { length: 18, fadeHeight: 0.45, partOffset: 0, hairType: '1B', volume: 1.2 },
      ratios: { fringe: 1.15, sides: 0.25, back: 0.3, nape: 0.2 },
      fade: 'skin', comb: 'back', volume: [6, 2.5, 1, 0.3], width: 0.65, rise: 0.45, taper: 0.85, hold: 0.95, clump: 0.3, bend: 0.9,
      stiffness: { local: [0.95, 0.55], global: [0.45, 0.12] },
    },
    quiff: {
      label: 'Quiff',
      defaults: { length: 14, fadeHeight: 0.5, partOffset: 0, hairType: '1B', volume: 1.15 },
      ratios: { fringe: 1.2, sides: 0.25, back: 0.3, nape: 0.2 },
      fade: 'skin', comb: 'up', volume: [5, 2.8, 1.0, 0.3], rise: 0.4, taper: 0.6, hold: 0.8, clump: 0.5, bend: 1.0,
      stiffness: { local: [0.95, 0.5], global: [0.4, 0.1] },
    },
    slickBack: {
      label: 'Slick Back',
      defaults: { length: 14, fadeHeight: 0.2, partOffset: 0, hairType: '1B', volume: 1 },
      ratios: { fringe: 1.05, sides: 0.55, back: 0.65, nape: 0.5 },
      fade: 'skin', comb: 'back', volume: [1.2, 0.8, 0.5, 0.3], rise: 0.2, taper: 0.6, hold: 1, clump: 0.25, bend: 1.6,
      stiffness: { local: [0.85, 0.4], global: [0.35, 0.08] },
    },
    texturedCrop: {
      label: 'Textured Crop',
      defaults: { length: 8, fadeHeight: 0.75, partOffset: 0, hairType: '2A', volume: 1.15 },
      ratios: { fringe: 0.85, sides: 0.2, back: 0.25, nape: 0.15 },
      fade: 'skin', comb: 'forward', volume: [1.0, 1.6, 1.2, 0.3], rise: 0.35, taper: 0.3, hold: 0.6, clump: 0.9, bend: 1.0,
      stiffness: { local: [0.85, 0.4], global: [0.35, 0.1] },
    },
    mullet: {
      label: 'Mullet',
      defaults: { length: 9, fadeHeight: 0.25, partOffset: 0, hairType: '2A', volume: 1.1 },
      ratios: { fringe: 0.8, sides: 0.45, back: 2.2, nape: 3.2 },
      fade: 'skin', comb: 'down', volume: [1.2, 1.5, 1.5, 0.6], rise: 0.2, taper: 0.4, hold: 0.3, clump: 0.7, bend: 2.2,
      stiffness: { local: [0.6, 0.1], global: [0.15, 0] },
    },
    afro: {
      label: 'Afro',
      defaults: { length: 48, fadeHeight: 0, partOffset: 0, hairType: '4B', volume: 1.7 },
      ratios: { fringe: 0.85, sides: 0.95, back: 1, nape: 0.8 },
      fade: 'skin', comb: 'out', volume: [7, 7, 7, 6], rise: 0.3, taper: 0, hold: 1, clump: 0.6, bend: 0.3,
      stiffness: { local: [0.95, 0.8], global: [0.55, 0.35] },
    },
    bald: {
      label: 'Bald/Shaved',
      defaults: { length: 0.15, fadeHeight: 0, partOffset: 0, hairType: '1B', volume: 1 },
      ratios: { fringe: 1, sides: 1, back: 1, nape: 1 },
      fade: 'skin', comb: 'down', volume: [0.2, 0.2, 0.2, 0.2], rise: 0.3, taper: 0, hold: 0, clump: 0.5, bend: 0.5,
      stiffness: { local: [0.9, 0.7], global: [0.5, 0.3] },
    },
    longLayers: {
      label: 'Long Layers',
      defaults: { length: 56, fadeHeight: 0, partOffset: 0, hairType: '2A', volume: 1.15 },
      ratios: { fringe: 0.75, sides: 1.0, back: 1.15, nape: 1.15 },
      fade: 'skin', comb: 'center', volume: [1.2, 1.5, 1.2, 0.8], rise: 0.15, taper: 0.5, hold: 0.35, clump: 0.6, bend: 3.0,
      stiffness: { local: [0.6, 0.03], global: [0.12, 0] },
    },
    bob: {
      label: 'Bob',
      defaults: { length: 24, fadeHeight: 0, partOffset: 0.3, hairType: '1B', volume: 1.15 },
      ratios: { fringe: 0.95, sides: 0.9, back: 0.75, nape: 0.6 },
      fade: 'skin', comb: 'side', volume: [1.2, 1.5, 1.0, 0.8], rise: 0.2, taper: 0.5, hold: 0.5, clump: 0.5, bend: 2.6,
      stiffness: { local: [0.65, 0.15], global: [0.15, 0.02] },
    },
    pixie: {
      label: 'Pixie',
      defaults: { length: 11, fadeHeight: 0.2, partOffset: 0.35, hairType: '1B', volume: 1.05 },
      ratios: { fringe: 1.25, sides: 0.4, back: 0.45, nape: 0.3 },
      fade: 'skin', comb: 'side', volume: [1.5, 1.8, 1.0, 0.4], rise: 0.3, taper: 0.4, hold: 0.7, clump: 0.7, bend: 1.4,
      stiffness: { local: [0.8, 0.3], global: [0.3, 0.05] },
    },
    curtains: {
      label: 'Curtains',
      defaults: { length: 26, fadeHeight: 0, partOffset: 0, hairType: '1C', volume: 1.1 },
      ratios: { fringe: 0.85, sides: 0.9, back: 0.85, nape: 0.7 },
      fade: 'skin', comb: 'center', volume: [1.5, 1.6, 1.2, 0.6], rise: 0.2, taper: 0.5, hold: 0.5, clump: 0.6, bend: 2.4,
      stiffness: { local: [0.7, 0.12], global: [0.2, 0.02] },
    },
    curly: {
      label: 'Curly',
      defaults: { length: 30, fadeHeight: 0, partOffset: 0, hairType: '3B', volume: 1.45 },
      ratios: { fringe: 0.85, sides: 0.95, back: 1, nape: 0.85 },
      fade: 'skin', comb: 'center', volume: [3, 3.5, 3.5, 2.5], rise: 0.3, taper: 0.2, hold: 0.6, clump: 0.95, bend: 1.0,
      stiffness: { local: [0.8, 0.35], global: [0.25, 0.05] },
    },
  };

  function presetOf(id) {
    return PRESETS[id] || PRESETS.custom;
  }

  // How high in the hair a strand rooted at `unit` lies, 0..1: the comb
  // carries hair over the hair downstream of it, so strands from upstream
  // (the front, for hair combed back) form the outer layer and the rest lie
  // underneath.
  function layerRank(comb, unit, partX) {
    switch (comb) {
      case 'back':
      case 'up':
        return smoothstep(0.1, 0.9, unit.z);
      case 'forward':
        return smoothstep(-0.7, 0.3, -unit.z);
      case 'side':
      case 'center':
        return 1 - smoothstep(0, 0.7, Math.abs(unit.x - partX));
      case 'out':
        return 1;
      default:
        return 1 - smoothstep(0, 1.4, Math.acos(Math.min(1, Math.max(-1, unit.y))));
    }
  }

  // The hair's outer surface above the scalp (scene units) in scalp
  // direction `unit`: the preset's fringe / top / crown / sides heights,
  // blended across the head.
  function volumeAt(preset, unit) {
    const [fringe, top, crown, sides] = preset.volume;
    const polar = Math.acos(Math.min(1, Math.max(-1, unit.y)));
    const upper = 1 - smoothstep(68 * deg, 92 * deg, polar);
    // The height sits over the middle of the head (`width` of it, 0..1);
    // toward the sides it eases down to the sides' value rather than
    // sticking out in wings.
    const width = preset.width ?? 0.95;
    const middle = 1 - smoothstep(width * 0.35, width, Math.abs(unit.x));
    const front = smoothstep(0.15, 0.75, unit.z);
    const back = smoothstep(0.1, 0.8, -unit.z);
    const height = top + (fringe - top) * front + (crown - top) * back;
    return (sides + (height - sides) * upper * middle) * 0.1;
  }

  // The zones a barber works in, front to back: their lengths (0.5 cm
  // units, like `length`, which is the top's) live in params.zones.
  const ZONES = ['fringe', 'crown', 'sides', 'back', 'nape'];

  // Where on the head the fade's shape lets it work, 0..1, by angular
  // distance from the face (0 the face, pi the back). The ear is ~100°.
  function fadeReach(shape, delta) {
    switch (shape) {
      case 'taper': // only the sideburns and the neckline
        return Math.max(1 - smoothstep(25 * deg, 55 * deg, delta), smoothstep(135 * deg, 165 * deg, delta));
      case 'burst': // a half-circle round the ear; the nape keeps its length
        return 1 - smoothstep(35 * deg, 75 * deg, Math.abs(delta - 100 * deg));
      default:
        return 1;
    }
  }

  // How far above the hairline (polar angle) the fade starts: fadeHeight
  // low ~19°, mid ~29°, high ~40°. A drop fade's line curves down behind
  // the ear toward the nape; a taper stays low.
  function fadeStart(params, delta) {
    const height = params.fadeShape === 'taper' ? 0.15 * params.fadeHeight : params.fadeHeight;
    const drop = params.fadeShape === 'drop' ? 14 * deg * smoothstep(95 * deg, 150 * deg, delta) : 0;
    return (10 + 35 * height) * deg - drop;
  }

  // Length (scene units, before the hairline) at a scalp point.
  function baseLength(presetId, params, u, v) {
    const preset = presetOf(presetId);
    const polar = v * MAX_POLAR;
    const azimuth = u * 2 * Math.PI;
    const unitZ = Math.sin(polar) * Math.sin(azimuth); // front (+) to back (-)
    const top = Math.max(0, params.length) * LENGTH_TO_SCENE;

    if (presetId === 'custom' || !PRESETS[presetId]) {
      // Designs v1/v2: one length, a parting gap and a taper.
      let part = 1;
      if (params.partOffset !== 0) {
        const delta = angularDistance(azimuth, params.partOffset * Math.PI);
        part = 0.25 + 0.75 * Math.max(smoothstep(0.02, 0.09, delta), smoothstep(1.1, 1.4, polar));
      }
      const fade = smoothstep(35 * deg, 112 * deg, polar);
      return top * part * Math.max(0.05, 1 - fade * params.fadeHeight);
    }

    const zones = params.zones || zonesFor(preset, params.length);
    const zone = (name) => Math.max(0, zones[name]) * LENGTH_TO_SCENE;
    const front = smoothstep(0.25, 0.8, unitZ);
    const back = smoothstep(0.05, 0.7, -unitZ);
    const upper = top + (zone('fringe') - top) * front + (zone('crown') - top) * back;
    const sides = zone('sides') + (zone('back') - zone('sides')) * back;
    const lower = sides + (zone('nape') - sides) * back * smoothstep(100 * deg, 120 * deg, polar);
    let length;
    const undercut = params.undercut;
    if (undercut && undercut.on) {
      // A hard line (disconnected), from low (85°) to high (60°).
      const line = (85 - 25 * undercut.height) * deg;
      const below = smoothstep(line - 0.03, line + 0.03, polar);
      length = upper * (1 - below) + (CLIPPER_GUARD_LENGTHS[undercut.guard] ?? 0) * LENGTH_TO_SCENE * below;
    } else {
      const blend = smoothstep(55 * deg, 85 * deg, polar);
      length = upper * (1 - blend) + lower * blend;
    }
    if (params.fadeHeight > 0) {
      // A barber fade: graduated evenly down to its finish (skin, or a
      // guard for a shadow fade) just above the hairline.
      const delta = angularDistance(azimuth, Math.PI / 2);
      const finish = (CLIPPER_GUARD_LENGTHS[params.fadeTo ?? 0] ?? 0) * LENGTH_TO_SCENE;
      const skin = lowerLine(edgesOf(params), delta) - 4 * deg;
      const start = skin - fadeStart(params, delta);
      const t = Math.min(1, Math.max(0, (polar - start) / (skin - start))) * fadeReach(params.fadeShape, delta);
      if (length > finish) length = finish + (length - finish) * (1 - t);
    }
    return length;
  }

  // A preset's zone lengths for a given top length (0.5 cm units).
  function zonesFor(preset, length) {
    const ratios = preset.ratios;
    return Object.fromEntries(ZONES.map((zone) => [zone, length * (ratios[zone] ?? 1)]));
  }

  // A preset's starting parameters, with every barber detail filled in.
  function presetDefaults(id) {
    const preset = presetOf(id);
    const defaults = preset.defaults;
    return {
      ...defaults,
      zones: zonesFor(preset, defaults.length),
      fadeTo: 0,
      fadeShape: 'classic',
      hairline: { ...DEFAULT_EDGES },
      undercut: preset.undercut
        ? { on: true, height: (85 * deg - preset.undercut) / (25 * deg), guard: CLIPPER_GUARD_LENGTHS.indexOf(preset.undercutLength) }
        : { on: false, height: 0.5, guard: 2 },
    };
  }

  // --- Painted fields ------------------------------------------------------------

  const MASK_WIDTH = 1024;
  const MASK_HEIGHT = 512;
  const BASE_WIDTH = 256;
  const BASE_HEIGHT = 128;

  function createFields() {
    const make = () => {
      const canvas = document.createElement('canvas');
      canvas.width = MASK_WIDTH;
      canvas.height = MASK_HEIGHT;
      return { canvas, ctx: canvas.getContext('2d', { willReadFrequently: true }) };
    };
    return {
      length: make(), // grey = painted length / MAX_LENGTH, alpha = painted
      color: make(), // dye colour, alpha = painted
      type: make(), // curl brush: red = hair type index (see typeCode), alpha = painted
      // RG per texel: base length × hairline (scene units), hairline.
      base: new Float32Array(BASE_WIDTH * BASE_HEIGHT * 2),
    };
  }

  let hairlineGrid = null;
  let hairlineGridKey = '';

  function computeBase(fields, presetId, params) {
    const edges = edgesOf(params);
    const key = JSON.stringify(edges);
    if (key !== hairlineGridKey) {
      hairlineGridKey = key;
      hairlineGrid ??= new Float32Array(BASE_WIDTH * BASE_HEIGHT);
      for (let row = 0; row < BASE_HEIGHT; row++) {
        for (let col = 0; col < BASE_WIDTH; col++) {
          hairlineGrid[row * BASE_WIDTH + col] = hairline((col + 0.5) / BASE_WIDTH, (row + 0.5) / BASE_HEIGHT, edges);
        }
      }
    }
    for (let row = 0; row < BASE_HEIGHT; row++) {
      const v = (row + 0.5) / BASE_HEIGHT;
      for (let col = 0; col < BASE_WIDTH; col++) {
        const u = (col + 0.5) / BASE_WIDTH;
        const h = hairlineGrid[row * BASE_WIDTH + col];
        const i = (row * BASE_WIDTH + col) * 2;
        // Baby hairs (the sparse band beyond a natural hairline) stay short
        // and wispy whatever the cut.
        const length = h > 0 ? baseLength(presetId, params, u, v) * h : 0;
        fields.base[i] = h < 0.25 ? Math.min(length, BABY_HAIR_LENGTH) : length;
        fields.base[i + 1] = h;
      }
    }
  }

  function strokeLength(stroke) {
    if (stroke.tool === 'clipper' || stroke.tool === 'razor') return CLIPPER_GUARD_LENGTHS[stroke.guard ?? 0] ?? 0;
    if (stroke.tool === 'scissors') return stroke.length ?? 0;
    return null;
  }

  // Paints points [from, end) of a stroke (and the segment joining them to
  // the point before) into the field(s) its tool affects. Painting is
  // idempotent, so a growing stroke can be painted incrementally. Each pass
  // is drawn at u-1, u, u+1 so strokes wrap round the back of the head.
  function paintStroke(fields, stroke, from = 0) {
    const points = stroke.points;
    if (points.length === 0 || from >= points.length) return;
    const radius = Math.max(1, stroke.radius * MASK_WIDTH);
    const start = Math.max(0, from - 1);

    const pass = (ctx, styleOf) => {
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.lineWidth = radius * 2;
      for (const offset of [-MASK_WIDTH, 0, MASK_WIDTH]) {
        if (stroke.tool === 'cut') {
          // Physics scissors: each point is one strand's new length.
          for (let i = start; i < points.length; i++) {
            ctx.fillStyle = styleOf(points[i]);
            ctx.beginPath();
            ctx.arc(points[i][0] * MASK_WIDTH + offset, points[i][1] * MASK_HEIGHT, radius, 0, Math.PI * 2);
            ctx.fill();
          }
          continue;
        }
        ctx.strokeStyle = ctx.fillStyle = styleOf(null);
        ctx.beginPath();
        for (let i = start; i < points.length; i++) {
          const x = points[i][0] * MASK_WIDTH + offset;
          const y = points[i][1] * MASK_HEIGHT;
          if (i === start) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
        if (points.length - start === 1) {
          ctx.beginPath();
          ctx.arc(points[start][0] * MASK_WIDTH + offset, points[start][1] * MASK_HEIGHT, radius, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    };

    const grey = (length) => {
      const g = Math.round((Math.max(0, Math.min(MAX_LENGTH, length)) / MAX_LENGTH) * 255);
      return `rgba(${g}, ${g}, ${g}, 1)`;
    };
    if (stroke.tool === 'cut') pass(fields.length.ctx, (point) => grey(point[2]));
    else {
      const length = strokeLength(stroke);
      if (length !== null) pass(fields.length.ctx, () => grey(length));
    }
    if (stroke.tool === 'dye') pass(fields.color.ctx, () => stroke.colorHex || '#000000');
    if (stroke.tool === 'curl') pass(fields.type.ctx, () => `rgb(${typeCode(hairTypeOf(stroke.hairType))}, 0, 0)`);
  }

  function repaint(fields, strokes) {
    fields.length.ctx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
    fields.color.ctx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
    fields.type.ctx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
    for (const stroke of strokes) paintStroke(fields, stroke);
  }

  // A hair type painted into the type field as red = 20 i + 10: well apart,
  // so the shader reads the index back exactly (FIELDS_GLSL hairTypeIndex).
  function typeCode(type) {
    return HAIR_TYPES.indexOf(type) * 20 + 10;
  }

  // The hair type at a scalp point: the design's, unless the curl brush
  // painted another.
  function typeSampler(fields, params) {
    const painted = fields.type.ctx.getImageData(0, 0, MASK_WIDTH, MASK_HEIGHT).data;
    const base = hairTypeOf(params.hairType);
    return (u, v) => {
      const x = Math.min(MASK_WIDTH - 1, Math.floor((((u % 1) + 1) % 1) * MASK_WIDTH));
      const y = Math.min(MASK_HEIGHT - 1, Math.floor(Math.min(Math.max(v, 0), 1) * MASK_HEIGHT));
      const i = (y * MASK_WIDTH + x) * 4;
      return painted[i + 3] > 127 ? HAIR_TYPES[Math.floor(painted[i] / 20)] ?? base : base;
    };
  }

  // How long hair looks at a scalp point (scene units): its length, less
  // what its curl takes up (shrinkage).
  function visibleLengthSampler(fields, params) {
    const lengthAt = lengthSampler(fields);
    const typeAt = typeSampler(fields, params);
    return (u, v) => lengthAt(u, v) * (1 - typeAt(u, v).shrink);
  }

  // Final length (scene units) at a scalp point: base, unless painted.
  function lengthSampler(fields) {
    const painted = fields.length.ctx.getImageData(0, 0, MASK_WIDTH, MASK_HEIGHT).data;
    return (u, v) => {
      const base = sampleGrid(fields.base, 2, BASE_WIDTH, BASE_HEIGHT, u - 0.5 / BASE_WIDTH, v - 0.5 / BASE_HEIGHT, 0);
      const h = sampleGrid(fields.base, 2, BASE_WIDTH, BASE_HEIGHT, u - 0.5 / BASE_WIDTH, v - 0.5 / BASE_HEIGHT, 1);
      const x = Math.min(MASK_WIDTH - 1, Math.floor((((u % 1) + 1) % 1) * MASK_WIDTH));
      const y = Math.min(MASK_HEIGHT - 1, Math.floor(Math.min(Math.max(v, 0), 1) * MASK_HEIGHT));
      const i = (y * MASK_WIDTH + x) * 4;
      const alpha = painted[i + 3] / 255;
      const paintedLength = (painted[i] / 255) * MAX_LENGTH * LENGTH_TO_SCENE * h;
      return base * (1 - alpha) + paintedLength * alpha;
    };
  }

  // --- Combing and guide strands -----------------------------------------------

  const combNormal = new THREE.Vector3();
  const combTarget = new THREE.Vector3();

  // Where hair at scalp direction `unit` is combed, flat along the scalp,
  // written into `out`. partX: the parting's x (-1..1 across the head);
  // partSide: which side of it this strand's root is on.
  function combDirection(unit, comb, partX, partSide, out) {
    const cosPolar = Math.min(1, Math.max(-1, unit.y));
    const polar = Math.acos(cosPolar);
    const normal = combNormal.set(unit.x / CRANIUM.x, unit.y / CRANIUM.y, unit.z / CRANIUM.z).normalize();
    if (comb === 'out') return out.copy(normal);
    // Down and away from the crown (the polar direction): (cosP cosA, -sinP,
    // cosP sinA), from the unit vector (sinP cosA, cosP, sinP sinA).
    const sinPolar = Math.sqrt(1 - cosPolar * cosPolar);
    if (sinPolar < 1e-4) out.set(1, 0, 0); // the crown itself: any way out
    else out.set((cosPolar * unit.x) / sinPolar, -sinPolar, (cosPolar * unit.z) / sinPolar);
    const styled = 1 - smoothstep(60 * deg, 98 * deg, polar); // the top and front take the comb
    switch (comb) {
      case 'back':
      case 'up':
        // Swept back over the whole upper head, sides included, not just the
        // top — straight back, or the two halves part along the middle.
        out.lerp(combTarget.set(0, -0.12, -1), 1 - smoothstep(85 * deg, 112 * deg, polar));
        break;
      case 'forward':
        out.lerp(combTarget.set(0, -0.2, 1), styled * 0.85);
        break;
      case 'side':
        out.lerp(combTarget.set(partSide, -0.3, -0.15), styled * 0.9 * smoothstep(-0.6, 0.2, unit.z));
        break;
      case 'center':
        out.lerp(combTarget.set(Math.sign(unit.x - partX) || 1, -0.35, 0.05), styled * 0.9 * smoothstep(-0.5, 0.3, unit.z));
        break;
      default:
        break;
    }
    return out.addScaledVector(normal, -out.dot(normal)).normalize();
  }

  // Deterministic randomness, so a design rebuilds the same everywhere.
  function random(seed) {
    let a = seed >>> 0;
    return () => {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // The share of the scalp cap (by area) where hair grows.
  const hairBearing = new Map();
  function hairBearingShare(edges) {
    const key = JSON.stringify(edges);
    if (!hairBearing.has(key)) {
      let grows = 0;
      let total = 0;
      for (let row = 0; row < 64; row++) {
        const v = (row + 0.5) / 64;
        const area = Math.sin(v * MAX_POLAR);
        for (let col = 0; col < 128; col++) {
          grows += hairline((col + 0.5) / 128, v, edges) * area;
          total += area;
        }
      }
      hairBearing.set(key, grows / total);
    }
    return hairBearing.get(key);
  }

  // How long a guide at (u, v) must be to cover every drawn strand that may
  // take its shape: the longest hair around it (within `neighbourhood`, in
  // u units), plus the strands' random extra.
  function guideLengthAt(lengthAt, neighbourhood, u, v) {
    const neighbourhoodV = (neighbourhood * 2 * Math.PI) / MAX_POLAR;
    let longest = lengthAt(u, v);
    for (let k = 0; k < 6; k++) {
      const a = (k / 6) * 2 * Math.PI;
      longest = Math.max(longest, lengthAt(u + Math.cos(a) * neighbourhood, v + Math.sin(a) * neighbourhoodV));
    }
    return longest * STRAND_LENGTH_JITTER[1];
  }

  const TRACE_STEPS = 4; // per guide segment
  const traceHere = { u: 0, v: 0, radius: 0, unit: new THREE.Vector3() };
  const traceFlow = new THREE.Vector3();
  const traceDirection = new THREE.Vector3();
  const traceNext = new THREE.Vector3();
  const traceNormal = new THREE.Vector3();
  const traceSkin = new THREE.Vector3();

  // A guide strand's rest shape, V points pushed onto `out` (x, y, z, 1).
  //
  // Hair on the head is laid like hair over a mould: it glides along the
  // comb at a height above the scalp that rises smoothly from the root to
  // `peak` (over the preset's `rise`) and eases off by its tip (`taper`). Where
  // it leaves the scalp, or the comb runs steeply down past the product's
  // hold, it falls freely under gravity. Traced in fine steps, then
  // resampled to V evenly spaced points.
  function traceGuide(preset, curliness, root, length, peak, partX, partSide, jitter, out) {
    const ds = length / (V - 1) / TRACE_STEPS;
    const rise = preset.rise * length;
    const holdLength = preset.hold * length;
    const points = [root.x, root.y, root.z];
    const p = root.clone();
    // The skin point the strand is over, tracked apart from its height: the
    // height isn't straight out from the head's centre (see below), so the
    // skin point can't be recovered from the strand's own position.
    const skinPoint = traceSkin.copy(root);
    let height = 0;
    let free = false;
    for (let s = ds; s < length + ds * 0.5; s += ds) {
      if (!free) {
        uvOf(skinPoint, traceHere);
        combDirection(traceHere.unit, preset.comb, partX, partSide, traceFlow);
        free = traceHere.v > 1 || (s > holdLength && traceFlow.y < -0.75);
      }
      if (free) {
        traceDirection.y -= preset.bend * ds * (1 - 0.65 * curliness);
        traceDirection.normalize();
        p.addScaledVector(traceDirection, ds);
        collide(p, STRAND_LIFT + 0.03 * curliness);
      } else {
        // Along the comb (with this strand's own slight deviation), and up
        // or down toward this point's height in the hair.
        traceFlow.add(jitter).addScaledVector(combNormal, -traceFlow.dot(combNormal)).normalize();
        const target = peak * smoothstep(0, rise, s) * (1 - preset.taper * smoothstep(rise, length, s));
        const climb = Math.min(ds * 0.95, Math.max(-ds * 0.7, target - height));
        height += climb;
        skinPoint.addScaledVector(traceFlow, Math.sqrt(ds * ds - climb * climb));
        uvOf(skinPoint, traceHere);
        const { unit } = traceHere;
        const skin = skinRadiusAt(traceHere.u, traceHere.v);
        skinPoint.set(unit.x * skin * CRANIUM.x, unit.y * skin * CRANIUM.y, unit.z * skin * CRANIUM.z);
        // Volume builds upward over the top of the head (that's what product
        // does) and outward at the sides: straight off the forehead is
        // forward, and hair would stand out in front of the face.
        traceNormal.set(unit.x / CRANIUM.x, unit.y / CRANIUM.y, unit.z / CRANIUM.z).normalize();
        traceNormal.y += 1.5 * Math.max(0, unit.y);
        traceNormal.normalize();
        traceNext.copy(skinPoint).addScaledVector(traceNormal, STRAND_LIFT + height);
        traceDirection.subVectors(traceNext, p).normalize();
        p.copy(traceNext);
      }
      points.push(p.x, p.y, p.z);
    }
    resampleEvenly(points, out);
  }

  // A polyline (x, y, z, ...) resampled to V points evenly spaced along it,
  // pushed onto `out` as (x, y, z, 1).
  function resampleEvenly(points, out) {
    const n = points.length / 3;
    const cumulative = new Float64Array(n);
    for (let i = 1; i < n; i++) {
      cumulative[i] = cumulative[i - 1] + Math.hypot(
        points[i * 3] - points[i * 3 - 3], points[i * 3 + 1] - points[i * 3 - 2], points[i * 3 + 2] - points[i * 3 - 1],
      );
    }
    const total = cumulative[n - 1];
    let i = 0;
    for (let j = 0; j < V; j++) {
      const target = (total * j) / (V - 1);
      while (i < n - 2 && cumulative[i + 1] < target) i++;
      const t = Math.min(1, Math.max(0, (target - cumulative[i]) / Math.max(cumulative[i + 1] - cumulative[i], 1e-9)));
      for (let c = 0; c < 3; c++) out.push(points[i * 3 + c] + (points[(i + 1) * 3 + c] - points[i * 3 + c]) * t);
      out.push(1);
    }
  }

  // Golden-angle spiral over the scalp cap, `count` candidate roots,
  // jittered: an even spread with no rows. Calls visit(u, v) for each.
  function* scalpSpiral(count, rng, visit) {
    const cap = 1 - Math.cos(MAX_POLAR);
    const golden = Math.PI * (3 - Math.sqrt(5));
    const offset = rng() * 2 * Math.PI;
    for (let i = 0; i < count; i++) {
      if (i % 64 === 63) yield;
      const polar = Math.acos(1 - ((i + rng()) / count) * cap);
      let azimuth = (offset + i * golden + (rng() - 0.5) * 0.01) % (2 * Math.PI);
      if (azimuth < 0) azimuth += 2 * Math.PI;
      visit(azimuth / (2 * Math.PI), polar / MAX_POLAR);
    }
  }

  // Finds the (up to) three nearest guide roots that `accept` takes: a grid
  // of cells about two guide spacings wide, searched 3x3x3 around a point.
  function guideGrid(positions, cell) {
    const cells = new Map();
    const key = (x, y, z) => `${x},${y},${z}`;
    for (let i = 0; i < positions.length / 3; i++) {
      const k = key(Math.floor(positions[i * 3] / cell), Math.floor(positions[i * 3 + 1] / cell), Math.floor(positions[i * 3 + 2] / cell));
      if (!cells.has(k)) cells.set(k, []);
      cells.get(k).push(i);
    }
    return (x, y, z, accept, out) => {
      const cx = Math.floor(x / cell);
      const cy = Math.floor(y / cell);
      const cz = Math.floor(z / cell);
      out.length = 0;
      for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
          for (let dz = -1; dz <= 1; dz++) {
            for (const i of cells.get(key(cx + dx, cy + dy, cz + dz)) || []) {
              if (!accept(i)) continue;
              const ex = positions[i * 3] - x;
              const ey = positions[i * 3 + 1] - y;
              const ez = positions[i * 3 + 2] - z;
              out.push({ i, d: Math.sqrt(ex * ex + ey * ey + ez * ez) });
            }
          }
        }
      }
      out.sort((a, b) => a.d - b.d);
      if (out.length > 3) out.length = 3;
      return out;
    };
  }

  // The groom: guide strands (simulated) and the strands actually drawn.
  //
  // Guides are a few hundred strands, shaped by the preset and simulated by
  // hair_sim.js. Drawn strands are many thousands, each with its own root;
  // the GPU shapes each one from the three nearest guides (on its side of a
  // parting) and takes its length from the length field at its root, so
  // tools that paint length show on every strand at once. Guides are a
  // little longer than the longest hair near them, so drawn strands never
  // run past their guides' tips.
  //
  // Only where the hair is long enough for strands: shorter hair is the
  // shells'. A generator: it yields every few dozen strands and returns the
  // groom, so the designer can build in slices across frames — all at once
  // takes hundreds of milliseconds on a phone and freezes the view.
  function* buildGuides(fields, presetId, params, guideBudget, strandBudget) {
    const preset = presetOf(presetId);
    const lengthAt = visibleLengthSampler(fields, params);
    const typeAt = typeSampler(fields, params);
    const rng = random(1234567);
    const cap = 1 - Math.cos(MAX_POLAR);
    const spacing = Math.sqrt((2 * Math.PI * cap * 0.48 * CRANIUM.x * CRANIUM.z) / guideBudget);
    const neighbourhood = (spacing * 1.2) / ((CRANIUM.x + CRANIUM.z) * Math.PI); // in u
    const guideLength = (u, v) => guideLengthAt(lengthAt, neighbourhood, u, v);
    const partX = params.partOffset;
    const parted = preset.comb === 'side' || preset.comb === 'center';

    const rest = [];
    const lengths = [];
    const roots = [];
    const sides = [];
    const edges = edgesOf(params);
    yield* scalpSpiral(Math.round(guideBudget / hairBearingShare(edges)), rng, (u, v) => {
      // Hair thins out toward the hairline rather than stopping at an edge.
      const h = hairline(u, v, edges);
      if (rng() > h) return;
      if (lengthAt(u, v) < STRAND_MIN_LENGTH * STRAND_LENGTH_JITTER[0]) return;
      const length = guideLength(u, v);

      const { position: root } = scalpPoint(u, v);
      const unit = unitFromUV(u, v);
      const partSide = Math.sign(unit.x - partX) || 1;
      const layer = 0.25 + 0.75 * layerRank(preset.comb, unit, partX);
      const jitter = new THREE.Vector3(rng() - 0.5, rng() - 0.5, rng() - 0.5).multiplyScalar(0.12);

      const height = Math.min(volumeAt(preset, unit) * params.volume * layer, length * 0.7);
      traceGuide(preset, typeAt(u, v).curliness, root, length, height, partX, partSide, jitter, rest);
      lengths.push(length);
      roots.push(u, v);
      sides.push(partSide);
    });

    const rows = lengths.length;
    const guideRoots = new Float32Array(rows * 3);
    for (let row = 0; row < rows; row++) {
      for (let c = 0; c < 3; c++) guideRoots[row * 3 + c] = rest[row * V * 4 + c];
    }
    const nearest = guideGrid(guideRoots, spacing * 2);

    // Drawn strands. Layout must match hair_engine.js (16 floats each):
    //   aRoot    root position (body space), random
    //   aRootUv  scalp u, v, clumping (0 = a stray hair), length jitter
    //   aGuides  the three guide rows it follows (the first is its clump's)
    //   aWeights their weights
    const strands = [];
    const found = [];
    yield* scalpSpiral(Math.round(strandBudget / hairBearingShare(edges)), rng, (u, v) => {
      if (rows === 0 || rng() > hairline(u, v, edges)) return;
      const jitter = STRAND_LENGTH_JITTER[0] + rng() * (STRAND_LENGTH_JITTER[1] - STRAND_LENGTH_JITTER[0]);
      if (lengthAt(u, v) * jitter < STRAND_MIN_LENGTH) return;
      const { position: root } = scalpPoint(u, v);
      const rootUnit = unitFromUV(u, v);
      const side = Math.sign(rootUnit.x - partX) || 1;
      // A parting runs from the hairline back to the crown, no further:
      // behind it the two sides blend, or a seam runs down the back.
      const atParting = parted && rootUnit.z > -0.2;
      nearest(root.x, root.y, root.z, (i) => !atParting || sides[i] === side, found);
      if (found.length === 0) return;
      let total = 0;
      const weights = found.map(({ d }) => 1 / (d + spacing * 0.25) ** 2);
      for (const w of weights) total += w;
      const stray = rng() < 0.06;
      strands.push(
        root.x, root.y, root.z, rng(),
        u, v, stray ? 0 : preset.clump * (0.5 + rng() * 0.5), jitter,
        found[0].i, (found[1] ?? found[0]).i, (found[2] ?? found[0]).i, 0,
        weights[0] / total, (weights[1] ?? 0) / total, (weights[2] ?? 0) / total, 0,
      );
    });

    // In random order, so drawing fewer of them thins the hair evenly.
    const count = strands.length / 16;
    const shuffled = new Float32Array(strands.length);
    const order = Array.from({ length: count }, (_, i) => i);
    for (let i = count - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]];
    }
    for (let i = 0; i < count; i++) shuffled.set(strands.slice(order[i] * 16, order[i] * 16 + 16), i * 16);

    return {
      rows,
      rest: new Float32Array(rest),
      lengths: new Float32Array(lengths),
      roots: new Float32Array(roots),
      strands: shuffled,
      strandCount: count,
      stiffness: preset.stiffness,
      // A cut guide is recorded as a dot this big (u units) on the length
      // field: about the gap between guides, so the cut rebuilds the same
      // whatever the guide count.
      cutRadius: (spacing * 0.8) / (Math.PI * (CRANIUM.x + CRANIUM.z)),
      // For guideLengthAt, when tools change the length field.
      neighbourhood,
    };
  }

  window.HairGroom = {
    V,
    STRAND_LENGTH_JITTER,
    HAIR_TYPES,
    hairTypeOf,
    MAX_POLAR,
    MAX_LENGTH,
    LENGTH_TO_SCENE,
    SHELL_MAX_LENGTH,
    STRAND_MIN_LENGTH,
    STRAND_LIFT,
    MASK_WIDTH,
    MASK_HEIGHT,
    BASE_WIDTH,
    BASE_HEIGHT,
    CRANIUM,
    HAIRLINE,
    PRESETS,
    collision,
    scalpInfo,
    scalpData,
    skinRadius,
    ZONES,
    presetDefaults,
    zonesFor: (id, length) => zonesFor(presetOf(id), length),
    createFields,
    computeBase,
    paintStroke,
    repaint,
    lengthSampler,
    visibleLengthSampler,
    buildGuides,
    guideLengthAt,
    uvOf,
    pickScalp,
    decodeBase64,
  };
})();
