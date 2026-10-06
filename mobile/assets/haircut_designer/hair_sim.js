// Hair physics on the CPU, in a Web Worker so it never costs a frame: the
// main thread renders while the worker steps the strands, and a new groom
// settles in the worker while the old hair stays on screen.
//
// Measured on a Galaxy A33 (Mali-G68), the same physics as fragment passes
// cost 10-50 ms of GPU per frame and froze the view for over a second on
// every new groom: a fragment can only write one vertex, so each one walked
// its strand from the root (V² work per strand). Here each strand is walked
// once.
//
// The simulation (Müller et al. 2012, "Fast Simulation of Inextensible
// Hair and Fur"): per step, a Verlet prediction (gravity, gusty wind,
// damping, global shape memory), then follow-the-leader from the pinned
// root, with local shape memory, collisions (the scan's real skin from the
// scalp map, then face, neck and shoulders), friction, and the paper's
// velocity correction, without which strands whip.
//
// Everything is in body space (the bust's own frame), so collision shapes
// and rest shapes need no transforming per vertex. When the bust turns,
// the strands are moved by the inverse turn — they stay where they were in
// the world, and lag behind the head as real hair does — and gravity and
// wind are turned into body space.
//
// Messages in:  init, groom, step, beginSwipe, cut, endSwipe, shorten.
// Messages out: groomReady { id, positions, settleMs }, positions
//               { positions, stepMs }, swipe { cuts: [row, fraction, ...] }.
// Positions are body space RGBA float rows (V texels per strand, w = the
// strand's length), ready to upload; the strand shader applies the bust's
// transform.

function hairSimulator(post) {
  const TAU = Math.PI * 2;
  const DT = 1 / 120;
  // Steps per message at most: a slow step mustn't make the next one longer
  // still, trying to catch up.
  const MAX_STEPS = 2;
  // A new groom settles under gravity in big, heavily damped steps: it only
  // needs the resting shape, not the motion.
  const SETTLE_STEPS = 36;
  const SETTLE_DT = 1 / 30;
  const GRAVITY = -98; // scene units (10 cm) per s²
  const WIND = [0.6, 0.15, -1].map((c) => (c / Math.hypot(0.6, 0.15, -1)) * 140); // from front-left

  let V = 0;
  let rows = 0;
  let rest = null; // rows * V * 3
  let segment = null; // rest segment lengths, rows * V
  let rowLength = null; // each strand's length
  let pos = null;
  let prev = null;
  let pred = null;
  let swipe = null; // per row: fraction cut this swipe (1 = not cut)
  let globalStiffness = [0, 0];
  let localStiffness = [0, 0];
  let time = 0;
  let leftover = 0;
  const body = new Float64Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

  // Collision output (allocation-free: this runs for every vertex, every step).
  let ox = 0;
  let oy = 0;
  let oz = 0;

  // Collision shapes as plain numbers.
  let craniumX = 1;
  let craniumY = 1;
  let craniumZ = 1;
  let face = null;
  let neck = null;
  let shoulders = null;
  let lift = 0;

  // The skin's radius (in cranium units) by direction, as a cube map: a
  // lookup by the direction's largest axis needs only divisions, where the
  // scalp map's polar/azimuth needs acos and atan2 for every vertex. 0 where
  // the scalp map doesn't reach (below its last polar angle).
  const CUBE = 64;
  let cube = null;

  function scalpMapRadius(skin, maxPolar, azimuth, polar) {
    const { data, width, height } = skin;
    const x = (azimuth / TAU) * width;
    const y = Math.min(Math.max(polar / maxPolar, 0), 1) * (height - 1);
    const x0f = Math.floor(x);
    const fx = x - x0f;
    const x0 = ((x0f % width) + width) % width;
    const x1 = (x0 + 1) % width;
    const y0 = Math.min(Math.floor(y), height - 1);
    const y1 = Math.min(y0 + 1, height - 1);
    const fy = y - y0;
    return (data[y0 * width + x0] * (1 - fx) + data[y0 * width + x1] * fx) * (1 - fy)
      + (data[y1 * width + x0] * (1 - fx) + data[y1 * width + x1] * fx) * fy;
  }

  function buildCube(skin, maxPolar) {
    cube = new Float32Array(6 * CUBE * CUBE);
    for (let f = 0; f < 6; f++) {
      for (let i = 0; i < CUBE; i++) {
        for (let j = 0; j < CUBE; j++) {
          const a = ((j + 0.5) / CUBE) * 2 - 1;
          const b = ((i + 0.5) / CUBE) * 2 - 1;
          const sign = f % 2 === 0 ? 1 : -1;
          let x;
          let y;
          let z;
          if (f < 2) [x, y, z] = [sign, a, b];
          else if (f < 4) [x, y, z] = [a, sign, b];
          else [x, y, z] = [a, b, sign];
          const length = Math.sqrt(x * x + y * y + z * z);
          const polar = Math.acos(y / length);
          let azimuth = Math.atan2(z, x);
          if (azimuth < 0) azimuth += TAU;
          cube[(f * CUBE + i) * CUBE + j] = polar <= maxPolar ? scalpMapRadius(skin, maxPolar, azimuth, polar) : 0;
        }
      }
    }
  }

  // Skin radius in direction (x, y, z) (any length), or 0 off the scalp.
  function skinRadius(x, y, z) {
    const ax = Math.abs(x);
    const ay = Math.abs(y);
    const az = Math.abs(z);
    let f;
    let a;
    let b;
    if (ax >= ay && ax >= az) {
      f = x > 0 ? 0 : 1;
      a = y / ax;
      b = z / ax;
    } else if (ay >= az) {
      f = y > 0 ? 2 : 3;
      a = x / ay;
      b = z / ay;
    } else {
      f = z > 0 ? 4 : 5;
      a = x / az;
      b = y / az;
    }
    const u = Math.min(CUBE - 1, Math.max(0, (a * 0.5 + 0.5) * CUBE - 0.5));
    const v = Math.min(CUBE - 1, Math.max(0, (b * 0.5 + 0.5) * CUBE - 0.5));
    const j0 = Math.floor(u);
    const i0 = Math.floor(v);
    const j1 = Math.min(j0 + 1, CUBE - 1);
    const i1 = Math.min(i0 + 1, CUBE - 1);
    const row0 = (f * CUBE + i0) * CUBE;
    const row1 = (f * CUBE + i1) * CUBE;
    const r00 = cube[row0 + j0];
    const r01 = cube[row0 + j1];
    const r10 = cube[row1 + j0];
    const r11 = cube[row1 + j1];
    const fu = u - j0;
    const fv = v - i0;
    // At the scalp map's edge, don't blend with "no scalp": take the nearest.
    if (r00 === 0 || r01 === 0 || r10 === 0 || r11 === 0) {
      return fv < 0.5 ? (fu < 0.5 ? r00 : r01) : (fu < 0.5 ? r10 : r11);
    }
    return (r00 * (1 - fu) + r01 * fu) * (1 - fv) + (r10 * (1 - fu) + r11 * fu) * fv;
  }

  function pushOutOfEllipsoid(shape, minimum) {
    const ex = (ox - shape.cx) / shape.rx;
    const ey = (oy - shape.cy) / shape.ry;
    const ez = (oz - shape.cz) / shape.rz;
    const r2 = ex * ex + ey * ey + ez * ez;
    if (r2 < minimum * minimum && r2 > 1e-12) {
      const k = minimum / Math.sqrt(r2);
      ox = shape.cx + ex * k * shape.rx;
      oy = shape.cy + ey * k * shape.ry;
      oz = shape.cz + ez * k * shape.rz;
    }
  }

  function ellipsoid({ center, radii }) {
    return { cx: center[0], cy: center[1], cz: center[2], rx: radii[0], ry: radii[1], rz: radii[2] };
  }

  function configure(message) {
    V = message.V;
    const c = message.config;
    [craniumX, craniumY, craniumZ] = c.cranium;
    face = ellipsoid(c.collision.face);
    shoulders = ellipsoid(c.collision.shoulders);
    neck = { cx: c.collision.neck.center[0], cy: c.collision.neck.center[1], cz: c.collision.neck.center[2], r: c.collision.neck.radius };
    lift = c.lift;
    buildCube(c.skin, c.maxPolar);
  }

  // Point (x, y, z) pushed out of the body by margin, into (ox, oy, oz).
  function collide(x, y, z, margin) {
    ox = x;
    oy = y;
    oz = z;
    const ex = x / craniumX;
    const ey = y / craniumY;
    const ez = z / craniumZ;
    const r2 = ex * ex + ey * ey + ez * ez;
    if (r2 < 1.35 * 1.35 && r2 > 1e-12) { // far from the skull: skip the scalp
      const skin = skinRadius(ex, ey, ez);
      const minimum = skin + margin;
      if (skin > 0 && r2 < minimum * minimum) {
        const k = minimum / Math.sqrt(r2);
        ox *= k;
        oy *= k;
        oz *= k;
      }
    }
    pushOutOfEllipsoid(face, 1 + margin);
    if (oy < neck.cy + 0.6 && oy > neck.cy - 0.9) {
      const nx = ox - neck.cx;
      const nz = oz - neck.cz;
      const d2 = nx * nx + nz * nz;
      const minimum = neck.r + margin;
      if (d2 < minimum * minimum && d2 > 1e-12) {
        const k = minimum / Math.sqrt(d2);
        ox = neck.cx + nx * k;
        oz = neck.cz + nz * k;
      }
    }
    pushOutOfEllipsoid(shoulders, 1 + margin);
  }

  // gx..wz: gravity and wind, in body space.
  function simulate(dt, damping, gx, gy, gz, wx, wy, wz, puff) {
    // Locals, not the closure's variables, in the hot loop.
    const P = pos;
    const Q = prev;
    const R = pred;
    const S = rest;
    const L = segment;
    const [globalRoot, globalTip] = [globalStiffness[0], globalStiffness[1]];
    const [localRoot, localTip] = [localStiffness[0], localStiffness[1]];
    const windy = wx !== 0 || wy !== 0 || wz !== 0;
    const dt2 = dt * dt;
    const keep = 1 - damping;
    const lastIndex = V - 1;
    time += dt;
    for (let row = 0; row < rows; row++) {
      const base = row * V;
      // Integrate: Verlet, pulled toward the rest shape (global stiffness).
      const rowGust = windy ? Math.sin(time * 0.7 + row * 0.017) : 0;
      for (let j = 0; j < V; j++) {
        const k = (base + j) * 3;
        if (j < 2) {
          R[k] = S[k];
          R[k + 1] = S[k + 1];
          R[k + 2] = S[k + 2];
          continue;
        }
        const x = P[k];
        const y = P[k + 1];
        const z = P[k + 2];
        const along = j / lastIndex;
        const gust = windy ? (0.6 + 0.4 * Math.sin(time * 1.9 + y * 2.1 + x * 1.3) * rowGust) * Math.sqrt(along) : 0;
        let px = x + (x - Q[k]) * keep + (gx + wx * gust) * dt2;
        let py = y + (y - Q[k + 1]) * keep + (gy + wy * gust) * dt2;
        let pz = z + (z - Q[k + 2]) * keep + (gz + wz * gust) * dt2;
        const rootward = (1 - along) * (1 - along);
        const pull = globalTip + (globalRoot - globalTip) * rootward;
        px += (S[k] - px) * pull;
        py += (S[k + 1] - py) * pull;
        pz += (S[k + 2] - pz) * pull;
        R[k] = px;
        R[k + 1] = py;
        R[k + 2] = pz;
      }
      // Constrain: follow the leader out from the pinned root.
      for (let j = 0; j < 2; j++) {
        const k = (base + j) * 3;
        Q[k] = P[k] = R[k];
        Q[k + 1] = P[k + 1] = R[k + 1];
        Q[k + 2] = P[k + 2] = R[k + 2];
      }
      let qx = R[(base + 1) * 3];
      let qy = R[(base + 1) * 3 + 1];
      let qz = R[(base + 1) * 3 + 2];
      let previous = -1;
      for (let j = 2; j < V; j++) {
        const k = (base + j) * 3;
        const r0 = k - 3;
        const length = L[base + j];
        const inverseLength = 1 / Math.max(length, 1e-6);
        const rx = (S[k] - S[r0]) * inverseLength;
        const ry = (S[k + 1] - S[r0 + 1]) * inverseLength;
        const rz = (S[k + 2] - S[r0 + 2]) * inverseLength;
        let dx = R[k] - qx;
        let dy = R[k + 1] - qy;
        let dz = R[k + 2] - qz;
        let d = Math.sqrt(dx * dx + dy * dy + dz * dz);
        if (d > 1e-6) {
          dx /= d;
          dy /= d;
          dz /= d;
        } else {
          dx = rx;
          dy = ry;
          dz = rz;
        }
        const along = j / lastIndex;
        const rootward = (1 - along) * (1 - along);
        const memory = localTip + (localRoot - localTip) * rootward;
        dx += (rx - dx) * memory;
        dy += (ry - dy) * memory;
        dz += (rz - dz) * memory;
        d = length / (Math.sqrt(dx * dx + dy * dy + dz * dz) || 1);
        const fx = qx + dx * d;
        const fy = qy + dy * d;
        const fz = qz + dz * d;
        const margin = lift + puff * along;
        collide(fx, fy, fz, margin);
        // Friction: hair touching the body mostly stays put.
        if (Math.abs(ox - fx) + Math.abs(oy - fy) + Math.abs(oz - fz) > 1e-5) {
          collide(ox + (P[k] - ox) * 0.5, oy + (P[k + 1] - oy) * 0.5, oz + (P[k + 2] - oz) * 0.5, margin);
        }
        // Velocity correction for the previous vertex (Müller et al.): its
        // next velocity loses a share of this vertex's correction. Verlet
        // keeps velocity as (position - previous), so previous = old + 0.9 d.
        if (previous >= 0) {
          Q[previous] = R[previous] + 0.9 * (ox - R[k]);
          Q[previous + 1] = R[previous + 1] + 0.9 * (oy - R[k + 1]);
          Q[previous + 2] = R[previous + 2] + 0.9 * (oz - R[k + 2]);
        }
        // Park the old position in pred until the next vertex's correction.
        R[k] = P[k];
        R[k + 1] = P[k + 1];
        R[k + 2] = P[k + 2];
        P[k] = qx = ox;
        P[k + 1] = qy = oy;
        P[k + 2] = qz = oz;
        previous = k;
      }
      // The tip has no next vertex: its velocity is uncorrected.
      if (previous >= 0) {
        Q[previous] = R[previous];
        Q[previous + 1] = R[previous + 1];
        Q[previous + 2] = R[previous + 2];
      }
    }
  }

  function output(buffer) {
    const size = rows * V * 4;
    const out = buffer && buffer.length === size ? buffer : new Float32Array(size);
    const P = pos;
    for (let i = 0, n = rows * V; i < n; i++) {
      out[i * 4] = P[i * 3];
      out[i * 4 + 1] = P[i * 3 + 1];
      out[i * 4 + 2] = P[i * 3 + 2];
      out[i * 4 + 3] = rowLength[(i / V) | 0];
    }
    return out;
  }

  // The bust moved from `body` to `next` (column-major): every point keeps
  // its place in the world, so in body space it moves by inverse(next) * body.
  // Roots are pinned to the rest shape anyway.
  function followBody(next, nextInverse) {
    let moved = false;
    for (let i = 0; i < 16; i++) if (Math.abs(next[i] - body[i]) > 1e-7) moved = true;
    if (!moved) return;
    const m = new Float64Array(16);
    for (let c = 0; c < 4; c++) {
      for (let r = 0; r < 4; r++) {
        let sum = 0;
        for (let k = 0; k < 4; k++) sum += nextInverse[k * 4 + r] * body[c * 4 + k];
        m[c * 4 + r] = sum;
      }
    }
    for (const array of [pos, prev]) {
      for (let i = 0, n = rows * V; i < n; i++) {
        const x = array[i * 3];
        const y = array[i * 3 + 1];
        const z = array[i * 3 + 2];
        array[i * 3] = m[0] * x + m[4] * y + m[8] * z + m[12];
        array[i * 3 + 1] = m[1] * x + m[5] * y + m[9] * z + m[13];
        array[i * 3 + 2] = m[2] * x + m[6] * y + m[10] * z + m[14];
      }
    }
    body.set(next);
  }

  function computeSegments() {
    segment = new Float32Array(rows * V);
    rowLength = new Float32Array(rows);
    for (let row = 0; row < rows; row++) {
      for (let j = 1; j < V; j++) {
        const k = (row * V + j) * 3;
        segment[row * V + j] = Math.hypot(rest[k] - rest[k - 3], rest[k + 1] - rest[k - 2], rest[k + 2] - rest[k - 1]);
        rowLength[row] += segment[row * V + j];
      }
    }
  }

  function groom(message) {
    const start = performance.now();
    body.set(message.body);
    rows = message.rows;
    rest = new Float32Array(rows * V * 3);
    for (let i = 0; i < rows * V; i++) {
      rest[i * 3] = message.rest[i * 4];
      rest[i * 3 + 1] = message.rest[i * 4 + 1];
      rest[i * 3 + 2] = message.rest[i * 4 + 2];
    }
    globalStiffness = message.stiffness.global;
    localStiffness = message.stiffness.local;
    computeSegments();
    pos = new Float32Array(rest);
    prev = new Float32Array(rest);
    pred = new Float32Array(rest.length);
    swipe = new Float32Array(rows).fill(1);
    // Settle under gravity (the head upright: the style's own shape), with
    // heavy damping; the settled shape becomes the style's rest shape.
    for (let i = 0; i < SETTLE_STEPS; i++) simulate(SETTLE_DT, 0.35, 0, GRAVITY, 0, 0, 0, 0, message.puff);
    rest.set(pos);
    prev.set(pos);
    computeSegments();
    leftover = 0;
    const positions = output(null);
    post({ type: 'groomReady', id: message.id, positions, settleMs: performance.now() - start }, [positions.buffer]);
  }

  function step(message) {
    const start = performance.now();
    if (rows > 0) {
      followBody(message.body, message.inverse);
      // Gravity and wind are world directions: turn them into body space
      // (the inverse's rotation columns).
      const n = message.inverse;
      const w = message.wind;
      const gx = n[4] * GRAVITY;
      const gy = n[5] * GRAVITY;
      const gz = n[6] * GRAVITY;
      const wx = (n[0] * WIND[0] + n[4] * WIND[1] + n[8] * WIND[2]) * w;
      const wy = (n[1] * WIND[0] + n[5] * WIND[1] + n[9] * WIND[2]) * w;
      const wz = (n[2] * WIND[0] + n[6] * WIND[1] + n[10] * WIND[2]) * w;
      leftover += Math.min(message.elapsed, MAX_STEPS * DT);
      const steps = Math.max(1, Math.min(MAX_STEPS, Math.floor(leftover / DT)));
      leftover = Math.max(0, leftover - steps * DT);
      for (let i = 0; i < steps; i++) simulate(DT, 0.05, gx, gy, gz, wx, wy, wz, message.puff);
    }
    const positions = output(message.buffer);
    post({ type: 'positions', positions, stepMs: performance.now() - start }, [positions.buffer]);
  }

  // Shortens strands to a fraction of their length (1 = untouched): the
  // kept part keeps its shape, resampled over all V vertices.
  function resample(array, row, fraction) {
    const base = row * V * 3;
    const copy = array.slice(base, base + V * 3);
    for (let j = 0; j < V; j++) {
      const s = j * fraction;
      const j0 = Math.floor(s);
      const j1 = Math.min(j0 + 1, V - 1);
      const t = s - j0;
      for (let c = 0; c < 3; c++) array[base + j * 3 + c] = copy[j0 * 3 + c] + (copy[j1 * 3 + c] - copy[j0 * 3 + c]) * t;
    }
  }

  function shorten(row, fraction) {
    resample(pos, row, fraction);
    resample(prev, row, fraction);
    resample(rest, row, fraction);
    for (let j = 1; j < V; j++) segment[row * V + j] *= fraction;
    rowLength[row] *= fraction;
  }

  // Scissors, one segment of a swipe (pixels, y up): where it crosses each
  // strand on the camera's side, as a fraction of the strand. A strand is
  // cut once per swipe: its new tip sits under the finger and would
  // otherwise lose a sliver on every move. `modelViewProjection` takes body
  // space to clip space; `cameraDirection` is in body space.
  function cut(message) {
    const m = message.modelViewProjection;
    const [width, height] = message.viewport;
    const [ax, ay] = message.a;
    const [bx, by] = message.b;
    const abx = bx - ax;
    const aby = by - ay;
    const abLength2 = Math.max(abx * abx + aby * aby, 1e-6);
    const [vx, vy, vz] = message.cameraDirection;
    for (let row = 0; row < rows; row++) {
      if (swipe[row] < 0.999) continue;
      for (let j = 3; j < V - 1; j++) { // never the very tip: a cut takes a real piece off
        const k = (row * V + j) * 3;
        const x = pos[k];
        const y = pos[k + 1];
        const z = pos[k + 2];
        if (x * vx + y * vy + z * vz < -0.35) continue; // the far side of the head
        const w = m[3] * x + m[7] * y + m[11] * z + m[15];
        if (w <= 0) continue;
        const sx = ((m[0] * x + m[4] * y + m[8] * z + m[12]) / w * 0.5 + 0.5) * width;
        const sy = ((m[1] * x + m[5] * y + m[9] * z + m[13]) / w * 0.5 + 0.5) * height;
        const t = Math.min(1, Math.max(0, ((sx - ax) * abx + (sy - ay) * aby) / abLength2));
        const ex = sx - ax - abx * t;
        const ey = sy - ay - aby * t;
        if (ex * ex + ey * ey < message.radius * message.radius) {
          swipe[row] = (j - 0.5) / (V - 1);
          shorten(row, swipe[row]);
          break;
        }
      }
    }
  }

  return function handle(message) {
    switch (message.type) {
      case 'init':
        configure(message);
        break;
      case 'groom':
        groom(message);
        break;
      case 'step':
        step(message);
        break;
      case 'beginSwipe':
        if (swipe) swipe.fill(1);
        break;
      case 'cut':
        if (rows > 0) cut(message);
        break;
      case 'endSwipe': {
        const cuts = [];
        for (let row = 0; row < rows; row++) if (swipe[row] < 0.999) cuts.push(row, swipe[row]);
        post({ type: 'swipe', cuts });
        break;
      }
      case 'shorten':
        for (let row = 0; row < rows; row++) {
          if (message.fractions[row] < 0.999) shorten(row, message.fractions[row]);
        }
        break;
      default:
        break;
    }
  };
}

// A connection to the simulator: a Web Worker built from this file's own
// source (the page is loaded over file://, which can't load a worker
// script by URL), or, where that fails, the same code on the main thread.
function connectHairSimulator(onMessage) {
  try {
    const source = `const handle = (${hairSimulator.toString()})((m, t) => postMessage(m, t || []));\n`
      + 'onmessage = (event) => handle(event.data);';
    const worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
    worker.onmessage = (event) => onMessage(event.data);
    return { inWorker: true, send: (message, transfer) => worker.postMessage(message, transfer || []) };
  } catch (error) {
    console.warn('Hair physics worker unavailable, running on the main thread', error);
    const handle = hairSimulator((message) => setTimeout(() => onMessage(message), 0));
    return { inWorker: false, send: (message) => handle(message) };
  }
}
