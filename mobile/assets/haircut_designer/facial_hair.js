// Facial hair: a beard and brows, grown on the bust's skin below and in
// front of the scalp map, where the scalp's fields and guides don't reach.
//
// Strands grow as in Digital Salon (He et al. 2025, arXiv:2507.07387, MIT;
// the idea ported, not its code): from a root on a painted region, nudged
// at random, then each step bent by gravity, at most as far as p_Γ allows
// away from vertical, and curled round a helix (p_Ω, p_freq). Two changes:
// a hair starts along the way a beard grows there (down the cheeks toward
// the chin, back under the jaw, out from the middle of a moustache), lying
// as close to the skin as its texture lets it (straight hair flat, curly
// hair standing out and coiling), not straight out of the skin, which drew
// a block standing off the face. Beard hairs are short enough not to
// swing, so they are drawn as static strands, not simulated. Under them,
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
  const BROW_HAIRS_PER_AREA = 14000;
  const HAIR_WIDTH = 0.006; // about a pixel at the phone's usual zoom
  // Under this length (scene units: 4 mm) stubble is shading on the skin only.
  const STRAND_MIN = 0.04;

  const smoothstep = (a, b, x) => {
    const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
    return t * t * (3 - 2 * t);
  };
  // 1 between lo and hi, soft by `soft` either side.
  const band = (lo, hi, soft, v) => smoothstep(lo - soft, lo, v) * (1 - smoothstep(hi, hi + soft, v));

  // --- Where each part of a beard grows (side = |x|) --------------------------

  const lips = (side, y) => band(-0.9, -0.73, 0.02, y) * (1 - smoothstep(0.22, 0.28, side));
  // Over the upper lip, from under the nose to the mouth.
  const moustache = (side, y, width = 0.3) => band(-0.74, -0.6, 0.02, y) * (1 - smoothstep(width - 0.04, width + 0.02, side));
  // The chin under the lower lip, rounded at the bottom.
  const chin = (side, y, width = 0.3) => (1 - smoothstep(width - 0.04, width + 0.02, side)) * band(-1.38, -0.88, 0.04, y);
  // Where the moustache would join the cheeks: left bare by styles whose
  // moustache stands apart.
  const corners = (side, y) => band(0.25, 0.36, 0.02, side) * band(-0.95, -0.66, 0.03, y);
  // Everything a full beard covers: from under the nose and along the cheek
  // line (the mouth's corner up to the sideburn in front of the ear) down
  // to about the Adam's apple, rising along the jaw.
  function cheeksAndChin(side, y, z, neckRaise = 0) {
    const cheekLine = -0.7 + ((side - 0.28) / 0.44) * 0.5;
    const top = -0.6 + (cheekLine + 0.6) * smoothstep(0.2, 0.32, side);
    const neck = -1.5 + 0.75 * smoothstep(0.15, 0.68, side) + neckRaise;
    return band(neck, top, 0.05, y) * smoothstep(0.05, 0.25, z) * (1 - lips(side, y));
  }

  // Each style: where it grows (0..1 at a skin point), how long it is there
  // relative to its length (its shape), and its usual length (mm).
  const BEARDS = {
    none: null,
    stubble: { length: 2, region: cheeksAndChin },
    full: { length: 30, region: cheeksAndChin },
    shortBoxed: { length: 10, region: (side, y, z) => cheeksAndChin(side, y, z, 0.1) },
    // Wide, full and rounded, broad at the bottom.
    garibaldi: {
      length: 50,
      region: cheeksAndChin,
      shape: (side, y) => 0.55 + 0.35 * smoothstep(-0.65, -1.05, y) + 0.45 * smoothstep(-0.95, -1.3, y) * (1 - smoothstep(0.25, 0.6, side)),
    },
    // Short and rounded, with a longer moustache standing apart from the cheeks.
    verdi: {
      length: 25,
      region: (side, y, z) => cheeksAndChin(side, y, z) * (1 - corners(side, y)),
      shape: (side, y) => (moustache(side, y) > 0.5 ? 1.5 : 0.7 + 0.3 * smoothstep(-0.7, -1.1, y)),
    },
    // Circle beard: a moustache and a round chin patch joined round the mouth.
    goatee: {
      length: 15,
      region: (side, y) => Math.max(moustache(side, y), chin(side, y), band(-0.9, -0.6, 0.02, y) * band(0.22, 0.3, 0.02, side)) * (1 - lips(side, y)),
    },
    // A pointed chin beard and a moustache standing apart from it.
    vanDyke: {
      length: 20,
      region: (side, y) => Math.max(moustache(side, y, 0.28), chin(side, y, 0.2 + 0.08 * smoothstep(-1.3, -0.95, y))) * (1 - lips(side, y)) * (1 - corners(side, y)),
      shape: (side, y) => 1 + 1.1 * smoothstep(-1.0, -1.32, y) * (1 - smoothstep(0, 0.2, side)),
    },
    // Sideburns down the cheeks into the moustache, the chin shaven.
    muttonChops: {
      length: 15,
      region: (side, y, z) => cheeksAndChin(side, y, z) * (1 - (1 - smoothstep(0.3, 0.38, side)) * smoothstep(-0.86, -0.92, y)),
    },
    moustache: { length: 12, region: (side, y) => moustache(side, y) },
  };
  const BROWS = { none: 0, thin: 0.65, natural: 1, thick: 1.35 };

  // How much brow grows at a skin point, 0..1: an arch over each eye,
  // rounded at its inner end, its tail thinner and lower.
  function browRegion(thickness, x, y, z) {
    if (!thickness) return 0;
    const side = Math.abs(x);
    const t = (side - 0.3) / 0.3;
    const middle = 0.115 + 0.05 * (1 - t * t) - 0.02 * smoothstep(0.45, 0.6, side);
    const half = thickness * (0.034 - 0.016 * smoothstep(0.28, 0.58, side));
    return (1 - smoothstep(half * 0.5, half, Math.abs(y - middle)))
      * smoothstep(0.07, 0.12, side) * (1 - smoothstep(0.52, 0.6, side)) * smoothstep(0.5, 0.6, z);
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
            world.xyz += side * aSide * ${HAIR_WIDTH.toFixed(4)} * (1.0 - 0.65 * aAlong);
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
            vec3 color = uBaseColor * (0.75 + 0.45 * vSeed);
            // Roots sit in the shade of the hairs around them.
            float occlusion = mix(0.55, 1.0, vAlong);
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
      const beard = BEARDS[facial.beard] || null;
      const length = facial.beardLength * 0.01; // mm to scene units
      const density = facial.beardDensity;
      const brows = (BROWS[facial.brows] ?? BROWS.natural) * facial.browThickness;
      const beardAt = (x, y, z) => (beard ? beard.region(Math.abs(x), y, z) : 0);

      const position = this.headGeometry.attributes.position;
      const normal = this.headGeometry.attributes.normal;
      const index = this.headGeometry.index;

      // The skin: stubble, or the roots' shade under longer hair.
      const cover = density * (0.35 + 0.45 * smoothstep(0, 0.02, length));
      for (let i = 0; i < position.count; i++) {
        const x = position.getX(i);
        const y = position.getY(i);
        const z = position.getZ(i);
        this.stubble.array[i] = Math.max(cover * beardAt(x, y, z), 0.45 * browRegion(brows, x, y, z));
      }
      this.stubble.needsUpdate = true;

      const rng = random(97531);
      const strands = [];
      const a = new THREE.Vector3();
      const b = new THREE.Vector3();
      const c = new THREE.Vector3();
      const na = new THREE.Vector3();
      const nb = new THREE.Vector3();
      const nc = new THREE.Vector3();
      const root = new THREE.Vector3();
      const n = new THREE.Vector3();
      const growBeard = beard && length >= STRAND_MIN;
      for (let t = 0; t < index.count; t += 3) {
        a.fromBufferAttribute(position, index.getX(t));
        b.fromBufferAttribute(position, index.getX(t + 1));
        c.fromBufferAttribute(position, index.getX(t + 2));
        if ((a.y + b.y + c.y) / 3 > 0.35 || (a.z + b.z + c.z) / 3 < -0.1) continue; // nowhere near the face
        // The most this triangle grows anywhere on it; each hair then keeps
        // to the region where it falls, so edges follow the region, not the
        // mesh's triangles.
        const most = (f) => Math.max(f(a.x, a.y, a.z), f(b.x, b.y, b.z), f(c.x, c.y, c.z), f((a.x + b.x + c.x) / 3, (a.y + b.y + c.y) / 3, (a.z + b.z + c.z) / 3));
        const beardMost = growBeard ? most(beardAt) * density : 0;
        const browMost = most((x, y, z) => browRegion(brows, x, y, z));
        if (beardMost <= 0 && browMost <= 0) continue;
        const ux = b.x - a.x;
        const uy = b.y - a.y;
        const uz = b.z - a.z;
        const vx = c.x - a.x;
        const vy = c.y - a.y;
        const vz = c.z - a.z;
        const area = Math.hypot(uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx) / 2;
        const expected = area * Math.max(BEARD_HAIRS_PER_AREA * beardMost, BROW_HAIRS_PER_AREA * browMost);
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
          const keep = rng();
          const beardHere = growBeard ? beardAt(root.x, root.y, root.z) * density : 0;
          if (beardHere > 0 && keep * beardMost < beardHere) {
            const side = Math.abs(root.x);
            const shape = beard.shape ? beard.shape(side, root.y) : 1;
            strands.push(growBeardHair(root, n, length * shape * (0.8 + 0.35 * rng()), curliness, rng));
          } else if (beardHere <= 0 && keep * browMost < browRegion(brows, root.x, root.y, root.z)) {
            strands.push(growBrowHair(root, n, 0.06 * (0.7 + 0.6 * rng()), rng));
          }
        }
      }
      this.setStrands(strands);
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

  // The way a beard grows at a root, along the skin (normal: the skin's):
  // down the cheeks and slightly toward the chin, back toward the neck
  // under the jaw, down and out from the middle of the moustache.
  function beardDirection(root, normal) {
    const side = Math.abs(root.x);
    const sign = Math.sign(root.x) || 1;
    const under = smoothstep(0.3, 0.7, -normal.y);
    const inMoustache = moustache(side, root.y);
    const d = new THREE.Vector3(
      -sign * 0.25 * smoothstep(0.2, 0.6, side) * (1 - inMoustache) + sign * 0.6 * inMoustache,
      -1,
      0.15 - 0.6 * under,
    );
    return d.addScaledVector(normal, -d.dot(normal)).normalize();
  }

  // One beard hair (Digital Salon's growth, from the way the beard grows
  // there): each step bent toward vertical by gravity (at least p_Γ of it,
  // more the less vertical the hair already is) and curled round a helix,
  // never back into the skin. Straight hair lies flat and barely curls;
  // curly hair stands out, droops less and coils.
  function growBeardHair(root, normal, length, curliness, rng) {
    const step = length / BEARD_STEPS;
    const helix = 0.1 + 1.8 * curliness; // p_h: the curl's radius
    const gravity = GRAVITY * (1 - 0.6 * curliness);
    const phase = rng() * Math.PI * 2;
    const dir = beardDirection(root, normal)
      .addScaledVector(normal, 0.2 + 0.7 * curliness)
      .add(new THREE.Vector3(rng() - 0.5, rng() - 0.5, rng() - 0.5).multiplyScalar(0.35))
      .normalize();
    const points = [root.clone()];
    const p = root.clone();
    for (let i = 1; i <= BEARD_STEPS; i++) {
      const pull = Math.max(P_GAMMA, 1 - Math.abs(dir.y));
      dir.y -= (i - 1) * gravity * pull;
      const hx = helix * Math.cos(i * P_FREQ + phase);
      const hz = helix * Math.sin(i * P_FREQ + phase);
      dir.set(dir.x + P_OMEGA * (dir.x - hx), dir.y + P_OMEGA * (dir.y - 1), dir.z + P_OMEGA * (dir.z - hz)).normalize();
      p.addScaledVector(dir, step);
      // Never back under the skin it grew from (only just off it).
      const under = p.clone().sub(root).dot(normal) - 0.05 * step * i;
      if (under < 0) p.addScaledVector(normal, -under);
      points.push(p.clone());
    }
    return points;
  }

  // One brow hair: lying flat along the skin toward the temple, rising
  // near the brow's inner end.
  function growBrowHair(root, normal, length, rng) {
    const side = Math.sign(root.x) || 1;
    const rise = 0.2 + 0.7 * (1 - smoothstep(0.1, 0.22, Math.abs(root.x)));
    const dir = new THREE.Vector3(side, rise + (rng() - 0.5) * 0.3, 0);
    dir.addScaledVector(normal, -dir.dot(normal)).normalize().addScaledVector(normal, 0.12).normalize();
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

  window.FacialHair = FacialHair;
})();
