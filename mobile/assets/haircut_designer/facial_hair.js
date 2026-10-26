// Facial hair: a beard and brows, grown on the bust's skin below and in
// front of the scalp map, where the scalp's fields and guides don't reach.
//
// Strands grow as in Digital Salon (He et al. 2025, arXiv:2507.07387, MIT;
// the idea ported, not its code): from a root on a painted region, along
// the skin's normal with a small random nudge, then each step bent by
// gravity, at most as far as p_Γ allows away from vertical, and curled
// round a helix (p_Ω, p_freq). One change: a beard hair starts leaning
// down along the skin, as it leaves the follicle, not straight out of it
// (straight out, the cheeks' and sideburns' hair stuck out sideways). Beard hairs are short enough not to swing,
// so they are drawn as static strands, not simulated. Under the strands,
// and alone for stubble (hairs far thinner than a pixel), the skin is
// shaded with the hair's colour (the head's aStubble attribute).
//
// Head space: 1 = 10 cm, the face towards +z (see build_head_asset.py).
// Landmarks measured on the mesh: nose tip y -0.45, under the nose -0.58,
// mouth -0.80, chin bottom -1.28, jaw corner (0.55, -0.8), brow ridge
// y 0.10-0.20 from x 0.1 to 0.6.
//
// design.facial: { beard: one of BEARDS' ids, beardLength (mm), beardDensity
// 0.2..1, brows: one of BROWS' ids, browThickness 0.5..1.5 }.

(function () {
  const P_GAMMA = 0.2; // p_Γ: how far gravity may bend a hair from vertical
  const P_OMEGA = 0.3; // p_Ω: how strongly the curl bends it
  const P_FREQ = 1.0; // p_freq: the curl's turns per step
  const GRAVITY = 0.12; // p_γ per step (the paper gives no default)
  const BEARD_STEPS = 5;
  const BROW_STEPS = 3;
  const BEARD_HAIRS_PER_AREA = 5000; // per square scene unit (100 cm²): ~50 per cm²
  const BROW_HAIRS_PER_AREA = 12000;
  const HAIR_WIDTH = 0.008; // about a pixel at the phone's usual zoom
  // Under this length (scene units: 4 mm) stubble is shading on the skin only.
  const STRAND_MIN = 0.04;

  const BEARDS = {
    none: { region: null },
    stubble: { region: 'full', length: 2 },
    shortBoxed: { region: 'boxed', length: 10 },
    full: { region: 'full', length: 35 },
    goatee: { region: 'goatee', length: 15 },
    moustache: { region: 'moustache', length: 12 },
  };
  const BROWS = { none: 0, thin: 0.6, natural: 1, thick: 1.45 };

  const smoothstep = (a, b, x) => {
    const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
    return t * t * (3 - 2 * t);
  };
  // 1 between lo and hi, soft by `soft` either side.
  const band = (lo, hi, soft, v) => smoothstep(lo - soft, lo, v) * (1 - smoothstep(hi, hi + soft, v));

  // How much beard grows at a skin point, 0..1.
  function beardRegion(region, x, y, z) {
    if (!region) return 0;
    const side = Math.abs(x);
    // The lips stay bare.
    const lips = band(-0.9, -0.73, 0.02, y) * (1 - smoothstep(0.22, 0.28, side));
    if (region === 'moustache') {
      return band(-0.74, -0.6, 0.02, y) * (1 - smoothstep(0.26, 0.32, side)) * (1 - lips);
    }
    // From under the nose (the moustache) and along the cheek line, from the
    // mouth's corner up to the sideburn in front of the ear.
    const cheek = -0.7 + ((side - 0.28) / 0.44) * 0.5;
    const top = -0.6 + (cheek + 0.6) * smoothstep(0.2, 0.32, side);
    // Under the chin down to about the Adam's apple, rising along the jaw.
    const neck = -1.5 + 0.75 * smoothstep(0.15, 0.68, side) + (region === 'boxed' ? 0.1 : 0);
    let grows = band(neck, top, 0.05, y) * smoothstep(0.05, 0.25, z) * (1 - lips);
    if (region === 'goatee') grows *= (1 - smoothstep(0.26, 0.32, side)) * smoothstep(-1.4, -1.34, y);
    return grows;
  }

  // How much brow grows at a skin point, 0..1: an arch over each eye, its
  // tail thinner and lower.
  function browRegion(thickness, x, y, z) {
    if (!thickness) return 0;
    const side = Math.abs(x);
    const t = (side - 0.3) / 0.3;
    const middle = 0.115 + 0.055 * (1 - t * t);
    const half = thickness * (0.035 - 0.015 * smoothstep(0.3, 0.6, side));
    return (1 - smoothstep(half * 0.6, half, Math.abs(y - middle)))
      * smoothstep(0.06, 0.11, side) * (1 - smoothstep(0.55, 0.63, side)) * smoothstep(0.5, 0.6, z);
  }

  function random(seed) {
    let a = seed >>> 0;
    return () => {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  class FacialHair {
    // headGeometry: the bust (body space); its aStubble attribute is
    // written here. fieldUniforms: the hair engine's (the hair colour);
    // key: its key light uniform.
    constructor(bodyGroup, headGeometry, fieldUniforms, key) {
      this.headGeometry = headGeometry;
      this.stubble = new THREE.BufferAttribute(new Float32Array(headGeometry.attributes.position.count), 1);
      headGeometry.setAttribute('aStubble', this.stubble);
      this.material = new THREE.ShaderMaterial({
        uniforms: { ...fieldUniforms, uKey: key },
        vertexShader: `
          attribute vec3 aTangent;
          attribute float aSide;
          attribute float aAlong;
          attribute float aSeed;
          varying vec3 vTangent;
          varying vec3 vWorld;
          varying float vAlong;
          varying float vSeed;
          void main() {
            vec4 world = modelMatrix * vec4(position, 1.0);
            vec3 tangent = normalize(mat3(modelMatrix) * aTangent);
            vec3 side = normalize(cross(tangent, cameraPosition - world.xyz));
            world.xyz += side * aSide * ${HAIR_WIDTH.toFixed(4)} * (1.0 - 0.6 * aAlong);
            vTangent = tangent;
            vWorld = world.xyz;
            vAlong = aAlong;
            vSeed = aSeed;
            gl_Position = projectionMatrix * viewMatrix * world;
          }`,
        fragmentShader: `
          ${HairEngine.FIELDS_GLSL}
          uniform vec3 uKey;
          varying vec3 vTangent;
          varying vec3 vWorld;
          varying float vAlong;
          varying float vSeed;
          void main() {
            vec3 view = normalize(cameraPosition - vWorld);
            vec3 color = uBaseColor * (0.8 + 0.35 * vSeed);
            // Roots sit in the shade of the hairs around them.
            float occlusion = mix(0.6, 1.0, vAlong);
            gl_FragColor = vec4(shadeHair(color, normalize(vTangent), view, uKey, occlusion, 0.5, (vSeed - 0.5) * 0.4, 1.0), 1.0);
            #include <colorspace_fragment>
          }`,
        side: THREE.DoubleSide,
      });
      this.mesh = new THREE.Mesh(new THREE.BufferGeometry(), this.material);
      this.mesh.frustumCulled = false;
      bodyGroup.add(this.mesh);
      this.key = '';
    }

    // Regrows the facial hair for design.facial, if it changed. curliness:
    // the hair type's, 0..1 (a curly head of hair grows a curly beard).
    update(facial, curliness) {
      const key = JSON.stringify([facial, curliness]);
      if (key === this.key) return;
      this.key = key;
      const beard = BEARDS[facial.beard] || BEARDS.none;
      const length = facial.beardLength * 0.01; // mm to scene units
      const density = facial.beardDensity;
      const brows = (BROWS[facial.brows] ?? BROWS.natural) * facial.browThickness;

      const position = this.headGeometry.attributes.position;
      const normal = this.headGeometry.attributes.normal;
      const index = this.headGeometry.index;

      // The skin: stubble, or the roots' shade under longer hair.
      const cover = beard.region ? density * (0.35 + 0.45 * smoothstep(0, 0.02, length)) : 0;
      for (let i = 0; i < position.count; i++) {
        const x = position.getX(i);
        const y = position.getY(i);
        const z = position.getZ(i);
        this.stubble.array[i] = Math.max(cover * beardRegion(beard.region, x, y, z), 0.5 * browRegion(brows, x, y, z));
      }
      this.stubble.needsUpdate = true;

      const rng = random(97531);
      const points = [];
      const a = new THREE.Vector3();
      const b = new THREE.Vector3();
      const c = new THREE.Vector3();
      const na = new THREE.Vector3();
      const nb = new THREE.Vector3();
      const nc = new THREE.Vector3();
      const root = new THREE.Vector3();
      const n = new THREE.Vector3();
      for (let t = 0; t < index.count; t += 3) {
        a.fromBufferAttribute(position, index.getX(t));
        b.fromBufferAttribute(position, index.getX(t + 1));
        c.fromBufferAttribute(position, index.getX(t + 2));
        const cx = (a.x + b.x + c.x) / 3;
        const cy = (a.y + b.y + c.y) / 3;
        const cz = (a.z + b.z + c.z) / 3;
        if (cy > 0.35 || cz < -0.1) continue; // nowhere near the face
        const beardHere = length >= STRAND_MIN ? beardRegion(beard.region, cx, cy, cz) * density : 0;
        const browHere = browRegion(brows, cx, cy, cz);
        if (beardHere <= 0 && browHere <= 0) continue;
        const ux = b.x - a.x;
        const uy = b.y - a.y;
        const uz = b.z - a.z;
        const vx = c.x - a.x;
        const vy = c.y - a.y;
        const vz = c.z - a.z;
        const area = Math.hypot(uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx) / 2;
        const expected = area * (beardHere > 0 ? BEARD_HAIRS_PER_AREA * beardHere : BROW_HAIRS_PER_AREA * browHere);
        const count = Math.floor(expected) + (rng() < expected % 1 ? 1 : 0);
        na.fromBufferAttribute(normal, index.getX(t));
        nb.fromBufferAttribute(normal, index.getX(t + 1));
        nc.fromBufferAttribute(normal, index.getX(t + 2));
        for (let h = 0; h < count; h++) {
          let u = rng();
          let v = rng();
          if (u + v > 1) {
            u = 1 - u;
            v = 1 - v;
          }
          root.copy(a).multiplyScalar(1 - u - v).addScaledVector(b, u).addScaledVector(c, v);
          n.copy(na).multiplyScalar(1 - u - v).addScaledVector(nb, u).addScaledVector(nc, v).normalize();
          points.push(beardHere > 0
            ? growBeardHair(root, n, length * (0.75 + 0.5 * rng()), curliness, rng)
            : growBrowHair(root, n, 0.08 * (0.7 + 0.6 * rng()), rng));
        }
      }
      this.setStrands(points);
    }

    // Strands (arrays of points) as camera-facing ribbons.
    setStrands(strands) {
      let vertices = 0;
      let quads = 0;
      for (const s of strands) {
        vertices += s.length * 2;
        quads += s.length - 1;
      }
      const positions = new Float32Array(vertices * 3);
      const tangents = new Float32Array(vertices * 3);
      const sides = new Float32Array(vertices);
      const alongs = new Float32Array(vertices);
      const seeds = new Float32Array(vertices);
      const indices = new Uint32Array(quads * 6);
      let v = 0;
      let q = 0;
      for (let k = 0; k < strands.length; k++) {
        const s = strands[k];
        const seed = (k * 0.6180339887) % 1;
        for (let i = 0; i < s.length; i++) {
          const from = s[Math.max(0, i - 1)];
          const to = s[Math.min(s.length - 1, i + 1)];
          for (let side = -1; side <= 1; side += 2) {
            positions[v * 3] = s[i].x;
            positions[v * 3 + 1] = s[i].y;
            positions[v * 3 + 2] = s[i].z;
            tangents[v * 3] = to.x - from.x;
            tangents[v * 3 + 1] = to.y - from.y;
            tangents[v * 3 + 2] = to.z - from.z;
            sides[v] = side;
            alongs[v] = i / (s.length - 1);
            seeds[v] = seed;
            v++;
          }
          if (i > 0) {
            const base = v - 4;
            indices[q] = base;
            indices[q + 1] = base + 1;
            indices[q + 2] = base + 2;
            indices[q + 3] = base + 1;
            indices[q + 4] = base + 3;
            indices[q + 5] = base + 2;
            q += 6;
          }
        }
      }
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
      geometry.setAttribute('aTangent', new THREE.BufferAttribute(tangents, 3));
      geometry.setAttribute('aSide', new THREE.BufferAttribute(sides, 1));
      geometry.setAttribute('aAlong', new THREE.BufferAttribute(alongs, 1));
      geometry.setAttribute('aSeed', new THREE.BufferAttribute(seeds, 1));
      geometry.setIndex(new THREE.BufferAttribute(indices, 1));
      this.mesh.geometry.dispose();
      this.mesh.geometry = geometry;
      this.mesh.visible = strands.length > 0;
    }
  }

  // One beard hair (Digital Salon's growth): out along the skin's normal,
  // nudged at random, then each step bent toward vertical by gravity (at
  // least p_Γ of it, more the less vertical the hair already is) and
  // curled round a helix, never back into the skin.
  function growBeardHair(root, normal, length, curliness, rng) {
    const step = length / BEARD_STEPS;
    const helix = 0.2 + 1.6 * curliness; // p_h: the curl's radius
    const phase = rng() * Math.PI * 2;
    // Down along the skin: straight down with the normal's part taken out.
    const down = new THREE.Vector3(0, -1, 0).addScaledVector(normal, normal.y);
    const dir = normal.clone().multiplyScalar(0.6).addScaledVector(down, 0.8)
      .add(new THREE.Vector3(rng() - 0.5, rng() - 0.5, rng() - 0.5).multiplyScalar(0.6)).normalize();
    const points = [root.clone()];
    const p = root.clone();
    for (let i = 1; i <= BEARD_STEPS; i++) {
      const pull = Math.max(P_GAMMA, 1 - Math.abs(dir.y));
      dir.y -= (i - 1) * GRAVITY * pull;
      const hx = helix * Math.cos(i * P_FREQ + phase);
      const hz = helix * Math.sin(i * P_FREQ + phase);
      dir.set(dir.x + P_OMEGA * (dir.x - hx), dir.y + P_OMEGA * (dir.y - 1), dir.z + P_OMEGA * (dir.z - hz)).normalize();
      p.addScaledVector(dir, step);
      // Never back under the skin it grew from.
      const under = p.clone().sub(root).dot(normal) - 0.3 * step * i;
      if (under < 0) p.addScaledVector(normal, -under);
      points.push(p.clone());
    }
    return points;
  }

  // One brow hair: lying along the skin, toward the temple, rising near
  // the brow's inner end.
  function growBrowHair(root, normal, length, rng) {
    const side = Math.sign(root.x) || 1;
    const rise = 0.25 + 0.6 * (1 - smoothstep(0.1, 0.25, Math.abs(root.x)));
    const dir = new THREE.Vector3(side, rise + (rng() - 0.5) * 0.3, 0);
    dir.addScaledVector(normal, -dir.dot(normal)).normalize().addScaledVector(normal, 0.25).normalize();
    const step = length / BROW_STEPS;
    const points = [root.clone()];
    const p = root.clone();
    for (let i = 1; i <= BROW_STEPS; i++) {
      // Curving back down onto the skin.
      dir.addScaledVector(normal, -0.15).normalize();
      p.addScaledVector(dir, step);
      points.push(p.clone());
    }
    return points;
  }

  FacialHair.BEARDS = BEARDS;
  FacialHair.BROWS = BROWS;
  window.FacialHair = FacialHair;
})();
