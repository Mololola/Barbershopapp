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
  const CHILDREN = 8; // drawn strands per guide
  // Shells draw hair up to this length (scene units, 2 cm) — at that length
  // they look better than strands; guides exist only where hair is longer.
  const SHELL_MAX_LENGTH = 0.2;
  const STRAND_MIN_LENGTH = 0.17;

  // Real clipper guard lengths, in 0.5 cm units: skin, #1 3 mm, #2 6 mm,
  // #3 10 mm, #4 13 mm, #5 16 mm, #6 19 mm, #7 22 mm, #8 25 mm.
  const CLIPPER_GUARD_LENGTHS = [0, 0.6, 1.2, 2, 2.6, 3.2, 3.8, 4.4, 5];

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
    const at = (col, row) => data[(row * width + col) * channels + channel];
    return (at(x0, y0) * (1 - fx) + at(x1, y0) * fx) * (1 - fy) + (at(x0, y1) * (1 - fx) + at(x1, y1) * fx) * fy;
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

  // Scalp UV of the direction of point p (on the cranium ellipsoid).
  function uvOf(p) {
    const e = p.clone().divide(CRANIUM).normalize();
    let azimuth = Math.atan2(e.z, e.x);
    if (azimuth < 0) azimuth += 2 * Math.PI;
    return { u: azimuth / (2 * Math.PI), v: Math.acos(Math.min(1, Math.max(-1, e.y))) / MAX_POLAR, unit: e };
  }

  // Pushes p out of the head, face, neck and shoulders by `margin` (scene
  // units). Mirrors collide() in hair_engine.js.
  function collide(p, margin) {
    const { u, v, unit } = uvOf(p);
    if (v <= 1) {
      const e = p.clone().divide(CRANIUM);
      const minimum = sampleGrid(skinRadius, 1, scalpInfo.width, scalpInfo.height, u, v, 0) + margin;
      if (e.length() < minimum) p.copy(unit.multiplyScalar(minimum).multiply(CRANIUM));
    }
    pushOutOfEllipsoid(p, collision.face.center, collision.face.radii, 1 + margin);
    const neck = collision.neck;
    if (p.y < neck.center[1] + 0.6 && p.y > neck.center[1] - 0.9) {
      const dx = p.x - neck.center[0];
      const dz = p.z - neck.center[2];
      const r = Math.hypot(dx, dz);
      const minimum = neck.radius + margin;
      if (r < minimum && r > 1e-6) {
        p.x = neck.center[0] + (dx / r) * minimum;
        p.z = neck.center[2] + (dz / r) * minimum;
      }
    }
    pushOutOfEllipsoid(p, collision.shoulders.center, collision.shoulders.radii, 1 + margin);
  }

  function pushOutOfEllipsoid(p, center, radii, minimum) {
    const e = new THREE.Vector3(
      (p.x - center[0]) / radii[0],
      (p.y - center[1]) / radii[1],
      (p.z - center[2]) / radii[2],
    );
    const r = e.length();
    if (r < minimum && r > 1e-6) {
      e.multiplyScalar(minimum / r);
      p.set(center[0] + e.x * radii[0], center[1] + e.y * radii[1], center[2] + e.z * radii[2]);
    }
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

  // 0 where no hair grows, 1 on the scalp: the front hairline arcs high over
  // the forehead and dips at the temples; the lower one runs from the
  // sideburns round the ears down to the nape. Tuned to the scan.
  const HAIRLINE = {
    faceHalfWidth: 50 * deg,
    center: 63 * deg,
    temple: 80 * deg,
    sideburn: 104 * deg,
    nape: 124 * deg,
  };

  function hairline(u, v) {
    const polar = v * MAX_POLAR;
    const delta = angularDistance(u * 2 * Math.PI, Math.PI / 2);
    const t = smoothstep(0, HAIRLINE.faceHalfWidth, delta);
    const front = HAIRLINE.center + (HAIRLINE.temple - HAIRLINE.center) * t;
    const vertical = 1 - smoothstep(front - 0.08, front + 0.08, polar);
    const horizontal = smoothstep(HAIRLINE.faceHalfWidth - 0.18, HAIRLINE.faceHalfWidth + 0.06, delta);
    const lowerLine = HAIRLINE.sideburn + (HAIRLINE.nape - HAIRLINE.sideburn) * smoothstep(80 * deg, 170 * deg, delta);
    const lower = 1 - smoothstep(lowerLine - 0.07, lowerLine + 0.03, polar);
    return Math.max(vertical, horizontal) * lower;
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
  // lift: how far roots stand up (0 flat, 1 straight out); frontLift adds at
  //   the front. hold: how much of each strand keeps the comb's shape off
  //   the head (product). bend: how quickly free hair falls.
  // stiffness: [root, tip] shape memory for the physics (local: direction,
  //   global: position).

  const PRESETS = {
    custom: {
      label: 'Custom',
      defaults: { length: 8, fadeHeight: 0.3, partOffset: 0, curl: 0, volume: 1 },
      ratios: { fringe: 1, sides: 1, back: 1, nape: 1 },
      fade: 'taper', comb: 'down', lift: 0.3, frontLift: 0, hold: 0, bend: 2.4,
      stiffness: { local: [0.5, 0.1], global: [0.1, 0] },
    },
    buzz: {
      label: 'Buzz Cut',
      defaults: { length: 1.2, fadeHeight: 0, partOffset: 0, curl: 0, volume: 1 },
      ratios: { fringe: 1, sides: 0.85, back: 0.85, nape: 0.7 },
      fade: 'skin', comb: 'down', lift: 0.6, frontLift: 0, hold: 0, bend: 0.5,
      stiffness: { local: [0.9, 0.7], global: [0.5, 0.3] },
    },
    crew: {
      label: 'Crew Cut',
      defaults: { length: 4, fadeHeight: 0.35, partOffset: 0, curl: 0, volume: 1 },
      ratios: { fringe: 0.8, sides: 0.35, back: 0.4, nape: 0.3 },
      fade: 'skin', comb: 'forward', lift: 0.55, frontLift: 0.15, hold: 0.6, bend: 0.6,
      stiffness: { local: [0.9, 0.6], global: [0.45, 0.2] },
    },
    fade: {
      label: 'Fade',
      defaults: { length: 8, fadeHeight: 0.55, partOffset: 0, curl: 0, volume: 1.1 },
      ratios: { fringe: 0.85, sides: 0.3, back: 0.3, nape: 0.2 },
      fade: 'skin', comb: 'forward', lift: 0.45, frontLift: 0.1, hold: 0.5, bend: 0.9,
      stiffness: { local: [0.85, 0.45], global: [0.35, 0.1] },
    },
    undercut: {
      label: 'Undercut',
      defaults: { length: 16, fadeHeight: 0, partOffset: 0.25, curl: 0, volume: 1.1 },
      ratios: { fringe: 1.05, sides: 1, back: 1, nape: 1 },
      undercut: 72 * deg, undercutLength: 1.2,
      fade: 'skin', comb: 'back', lift: 0.3, frontLift: 0.35, hold: 0.85, bend: 1.2,
      stiffness: { local: [0.85, 0.35], global: [0.3, 0.05] },
    },
    pompadour: {
      label: 'Pompadour',
      defaults: { length: 18, fadeHeight: 0.45, partOffset: 0, curl: 0, volume: 1.2 },
      ratios: { fringe: 1.15, sides: 0.25, back: 0.3, nape: 0.2 },
      fade: 'skin', comb: 'back', lift: 0.35, frontLift: 0.55, hold: 0.95, bend: 0.9,
      stiffness: { local: [0.95, 0.55], global: [0.45, 0.12] },
    },
    quiff: {
      label: 'Quiff',
      defaults: { length: 14, fadeHeight: 0.5, partOffset: 0, curl: 0, volume: 1.15 },
      ratios: { fringe: 1.2, sides: 0.25, back: 0.3, nape: 0.2 },
      fade: 'skin', comb: 'up', lift: 0.45, frontLift: 0.5, hold: 0.8, bend: 1.0,
      stiffness: { local: [0.95, 0.5], global: [0.4, 0.1] },
    },
    slickBack: {
      label: 'Slick Back',
      defaults: { length: 14, fadeHeight: 0.2, partOffset: 0, curl: 0, volume: 1 },
      ratios: { fringe: 1.05, sides: 0.55, back: 0.65, nape: 0.5 },
      fade: 'skin', comb: 'back', lift: 0.05, frontLift: 0.1, hold: 1, bend: 1.6,
      stiffness: { local: [0.85, 0.4], global: [0.35, 0.08] },
    },
    texturedCrop: {
      label: 'Textured Crop',
      defaults: { length: 8, fadeHeight: 0.75, partOffset: 0, curl: 0.15, volume: 1.15 },
      ratios: { fringe: 0.85, sides: 0.2, back: 0.25, nape: 0.15 },
      fade: 'skin', comb: 'forward', lift: 0.4, frontLift: 0, hold: 0.6, bend: 1.0,
      stiffness: { local: [0.85, 0.4], global: [0.35, 0.1] },
    },
    mullet: {
      label: 'Mullet',
      defaults: { length: 9, fadeHeight: 0.25, partOffset: 0, curl: 0.1, volume: 1.1 },
      ratios: { fringe: 0.8, sides: 0.45, back: 2.2, nape: 3.2 },
      fade: 'skin', comb: 'down', lift: 0.25, frontLift: 0.1, hold: 0.3, bend: 2.2,
      stiffness: { local: [0.6, 0.1], global: [0.15, 0] },
    },
    afro: {
      label: 'Afro',
      defaults: { length: 16, fadeHeight: 0, partOffset: 0, curl: 1, volume: 1.7 },
      ratios: { fringe: 0.85, sides: 0.95, back: 1, nape: 0.8 },
      fade: 'skin', comb: 'out', lift: 0.85, frontLift: 0, hold: 1, bend: 0.3,
      stiffness: { local: [0.95, 0.8], global: [0.55, 0.35] },
    },
    bald: {
      label: 'Bald/Shaved',
      defaults: { length: 0.15, fadeHeight: 0, partOffset: 0, curl: 0, volume: 1 },
      ratios: { fringe: 1, sides: 1, back: 1, nape: 1 },
      fade: 'skin', comb: 'down', lift: 0.6, frontLift: 0, hold: 0, bend: 0.5,
      stiffness: { local: [0.9, 0.7], global: [0.5, 0.3] },
    },
    longLayers: {
      label: 'Long Layers',
      defaults: { length: 56, fadeHeight: 0, partOffset: 0, curl: 0.1, volume: 1.15 },
      ratios: { fringe: 0.75, sides: 1.0, back: 1.15, nape: 1.15 },
      fade: 'skin', comb: 'center', lift: 0.1, frontLift: 0, hold: 0.35, bend: 3.0,
      stiffness: { local: [0.6, 0.03], global: [0.12, 0] },
    },
    bob: {
      label: 'Bob',
      defaults: { length: 24, fadeHeight: 0, partOffset: 0.3, curl: 0, volume: 1.15 },
      ratios: { fringe: 0.95, sides: 0.9, back: 0.75, nape: 0.6 },
      fade: 'skin', comb: 'side', lift: 0.12, frontLift: 0.05, hold: 0.5, bend: 2.6,
      stiffness: { local: [0.65, 0.15], global: [0.15, 0.02] },
    },
    pixie: {
      label: 'Pixie',
      defaults: { length: 11, fadeHeight: 0.2, partOffset: 0.35, curl: 0, volume: 1.05 },
      ratios: { fringe: 1.25, sides: 0.4, back: 0.45, nape: 0.3 },
      fade: 'skin', comb: 'side', lift: 0.25, frontLift: 0.1, hold: 0.7, bend: 1.4,
      stiffness: { local: [0.8, 0.3], global: [0.3, 0.05] },
    },
    curtains: {
      label: 'Curtains',
      defaults: { length: 26, fadeHeight: 0, partOffset: 0, curl: 0.05, volume: 1.1 },
      ratios: { fringe: 0.85, sides: 0.9, back: 0.85, nape: 0.7 },
      fade: 'skin', comb: 'center', lift: 0.18, frontLift: 0.1, hold: 0.5, bend: 2.4,
      stiffness: { local: [0.7, 0.12], global: [0.2, 0.02] },
    },
    curly: {
      label: 'Curly',
      defaults: { length: 22, fadeHeight: 0, partOffset: 0, curl: 0.7, volume: 1.45 },
      ratios: { fringe: 0.85, sides: 0.95, back: 1, nape: 0.85 },
      fade: 'skin', comb: 'center', lift: 0.4, frontLift: 0.05, hold: 0.6, bend: 1.0,
      stiffness: { local: [0.8, 0.35], global: [0.25, 0.05] },
    },
  };

  function presetOf(id) {
    return PRESETS[id] || PRESETS.custom;
  }

  // Length (scene units, before the hairline) at a scalp point.
  function baseLength(presetId, params, u, v) {
    const preset = presetOf(presetId);
    const polar = v * MAX_POLAR;
    const azimuth = u * 2 * Math.PI;
    const unit = unitFromUV(u, v);
    const top = Math.max(0, params.length) * LENGTH_TO_SCENE;
    const ratios = preset.ratios;

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

    const front = smoothstep(0.25, 0.8, unit.z);
    const back = smoothstep(0.05, 0.7, -unit.z);
    const topRatio = 1 + (ratios.fringe - 1) * front;
    const lowerRatio = ratios.sides + (ratios.back - ratios.sides) * back;
    const napeRatio = lowerRatio + (ratios.nape - lowerRatio) * back * smoothstep(100 * deg, 120 * deg, polar);
    let length;
    if (preset.undercut) {
      const below = smoothstep(preset.undercut - 0.03, preset.undercut + 0.03, polar);
      length = top * topRatio * (1 - below) + preset.undercutLength * LENGTH_TO_SCENE * below;
    } else {
      const lower = smoothstep(55 * deg, 85 * deg, polar);
      length = top * (topRatio * (1 - lower) + napeRatio * lower);
    }
    if (params.fadeHeight > 0) {
      // A barber fade: down to skin over a band whose height is fadeHeight.
      const start = (112 - 50 * params.fadeHeight) * deg;
      const end = Math.min(start + 22 * deg, 124 * deg);
      length *= 1 - smoothstep(start, end, polar);
    }
    return length;
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
      // RG per texel: base length × hairline (scene units), hairline.
      base: new Float32Array(BASE_WIDTH * BASE_HEIGHT * 2),
    };
  }

  function computeBase(fields, presetId, params) {
    for (let row = 0; row < BASE_HEIGHT; row++) {
      const v = (row + 0.5) / BASE_HEIGHT;
      for (let col = 0; col < BASE_WIDTH; col++) {
        const u = (col + 0.5) / BASE_WIDTH;
        const h = hairline(u, v);
        const i = (row * BASE_WIDTH + col) * 2;
        fields.base[i] = h > 0 ? baseLength(presetId, params, u, v) * h : 0;
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
  }

  function repaint(fields, strokes) {
    fields.length.ctx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
    fields.color.ctx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
    for (const stroke of strokes) paintStroke(fields, stroke);
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

  // Where hair at scalp direction `unit` is combed, flat along the scalp.
  // partX: the parting's x (-1..1 across the head); partSide: which side of
  // it this strand's root is on.
  function combDirection(unit, comb, partX, partSide) {
    const polar = Math.acos(Math.min(1, Math.max(-1, unit.y)));
    const azimuth = Math.atan2(unit.z, unit.x);
    const normal = unit.clone().divide(CRANIUM).normalize();
    const down = new THREE.Vector3(Math.cos(polar) * Math.cos(azimuth), -Math.sin(polar), Math.cos(polar) * Math.sin(azimuth));
    if (comb === 'out') return normal;
    const styled = 1 - smoothstep(60 * deg, 98 * deg, polar); // the top and front take the comb
    const result = down.clone();
    switch (comb) {
      case 'back':
      case 'up': {
        // Swept back over the whole upper head, sides included, not just the top.
        const sweptBack = 1 - smoothstep(85 * deg, 112 * deg, polar);
        result.lerp(new THREE.Vector3(0, -0.12, -1), sweptBack * 0.95);
        break;
      }
      case 'forward':
        result.lerp(new THREE.Vector3(0, -0.2, 1), styled * 0.85);
        break;
      case 'side':
        result.lerp(new THREE.Vector3(partSide, -0.3, -0.15), styled * 0.9 * smoothstep(-0.6, 0.2, unit.z));
        break;
      case 'center':
        result.lerp(new THREE.Vector3(Math.sign(unit.x - partX) || 1, -0.35, 0.05), styled * 0.9 * smoothstep(-0.5, 0.3, unit.z));
        break;
      default:
        break;
    }
    return result.addScaledVector(normal, -result.dot(normal)).normalize();
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

  // Guide strands where the hair is long enough for strands (shorter hair is
  // drawn by the shells). `budget` is how many root positions to try — the
  // quality tier; bald areas and short hair take none of it.
  function buildGuides(fields, presetId, params, budget) {
    const preset = presetOf(presetId);
    const lengthAt = lengthSampler(fields);
    const rng = random(1234567);
    const cap = 1 - Math.cos(MAX_POLAR);
    const golden = Math.PI * (3 - Math.sqrt(5));
    const candidates = Math.round(budget * 2.1); // ~half the cap grows hair
    const spacing = Math.sqrt((2 * Math.PI * cap * 0.48 * CRANIUM.x * CRANIUM.z) / budget);
    const curl = params.curl;
    const partX = params.partOffset;

    const rest = [];
    const lengths = [];
    const roots = [];
    for (let i = 0; i < candidates; i++) {
      const jitter = rng();
      const polar = Math.acos(1 - ((i + jitter) / candidates) * cap);
      let azimuth = (i * golden + (rng() - 0.5) * 0.01) % (2 * Math.PI);
      if (azimuth < 0) azimuth += 2 * Math.PI;
      const u = azimuth / (2 * Math.PI);
      const v = polar / MAX_POLAR;
      // Hair thins out toward the hairline rather than stopping at an edge.
      const h = hairline(u, v);
      if (rng() > h) continue;
      const length = lengthAt(u, v) * (0.85 + rng() * 0.3); // uneven ends, as cut hair has
      if (length < STRAND_MIN_LENGTH) continue;

      const { position: root, normal } = scalpPoint(u, v);
      const unit = unitFromUV(u, v);
      const partSide = Math.sign(unit.x - partX) || 1;
      const frontness = smoothstep(0.3, 0.85, unit.z) * (1 - smoothstep(55 * deg, 80 * deg, polar));
      const lift = Math.min(1, preset.lift + preset.frontLift * frontness);
      const segment = length / (V - 1);
      const holdUntil = preset.hold * (V - 1);

      const direction = normal.clone().multiplyScalar(lift)
        .addScaledVector(combDirection(unit, preset.comb, partX, partSide), 1 - lift)
        .add(new THREE.Vector3(rng() - 0.5, rng() - 0.5, rng() - 0.5).multiplyScalar(0.14))
        .normalize();
      const p = root.clone();
      const previous = root.clone();
      for (let j = 0; j < V; j++) {
        if (j > 0) {
          if (j > 1) {
            // On the head (or held by product) hair follows the comb; free
            // hair falls. Curly hair holds itself up more.
            const here = uvOf(p);
            const gap = here.v <= 1 ? p.clone().divide(CRANIUM).length() - sampleGrid(skinRadius, 1, scalpInfo.width, scalpInfo.height, here.u, here.v, 0) : 1;
            const comb = combDirection(here.unit, preset.comb, partX, partSide);
            if (j <= holdUntil || (gap < 0.06 && comb.y > -0.75)) direction.lerp(comb, 0.3);
            else direction.y -= preset.bend * segment * (1 - 0.65 * curl);
            direction.normalize();
          }
          previous.copy(p);
          p.addScaledVector(direction, segment);
          collide(p, 0.012 + 0.04 * (j / (V - 1)) * (0.4 + params.volume * 0.6 + curl * 0.8));
          if (j > 1) {
            direction.subVectors(p, previous).normalize();
            p.copy(previous).addScaledVector(direction, segment);
          }
        }
        rest.push(p.x, p.y, p.z, 1);
      }
      lengths.push(length);
      roots.push(u, v);
    }

    const rows = lengths.length;
    // Children ordered layer by layer (every guide's child 0, then child 1,
    // ...) so drawing fewer instances thins the hair evenly.
    const children = new Float32Array(rows * CHILDREN * 8);
    let k = 0;
    const tangent = new THREE.Vector3();
    const bitangent = new THREE.Vector3();
    for (let c = 0; c < CHILDREN; c++) {
      for (let row = 0; row < rows; row++) {
        const { normal } = scalpPoint(roots[row * 2], roots[row * 2 + 1]);
        tangent.crossVectors(normal, new THREE.Vector3(0, 1, 0.001)).normalize();
        bitangent.crossVectors(normal, tangent);
        const angle = rng() * Math.PI * 2;
        const radius = c === 0 ? 0 : spacing * Math.sqrt(rng());
        children[k++] = row;
        children[k++] = rng();
        children[k++] = 0.75 + rng() * 0.25; // tips end at different lengths
        children[k++] = (Math.cos(angle) * tangent.x + Math.sin(angle) * bitangent.x) * radius;
        children[k++] = (Math.cos(angle) * tangent.y + Math.sin(angle) * bitangent.y) * radius;
        children[k++] = (Math.cos(angle) * tangent.z + Math.sin(angle) * bitangent.z) * radius;
        children[k++] = roots[row * 2];
        children[k++] = roots[row * 2 + 1];
      }
    }
    return {
      rows,
      rest: new Float32Array(rest),
      lengths: new Float32Array(lengths),
      roots: new Float32Array(roots),
      children,
      stiffness: preset.stiffness,
      // A cut strand is recorded as a dot this big (u units) on the length
      // field: about the gap between guides, so the cut rebuilds the same
      // whatever the strand count.
      cutRadius: (spacing * 0.8) / (Math.PI * (CRANIUM.x + CRANIUM.z)),
    };
  }

  window.HairGroom = {
    V,
    CHILDREN,
    MAX_POLAR,
    MAX_LENGTH,
    LENGTH_TO_SCENE,
    SHELL_MAX_LENGTH,
    STRAND_MIN_LENGTH,
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
    presetDefaults: (id) => ({ ...presetOf(id).defaults }),
    createFields,
    computeBase,
    paintStroke,
    repaint,
    lengthSampler,
    buildGuides,
    uvOf,
    decodeBase64,
  };
})();
