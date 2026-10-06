// The hair on the GPU: strands, short-hair shells, and the bridge to the
// physics (hair_sim.js, in a Web Worker).
//
// Guide strands come from groom.js. The simulator steps them and sends back
// their positions each frame, uploaded as a float texture: one row per
// strand, V texels of body-space positions (the shader applies the bust's
// transform). The strands actually drawn are many more: each is shaped on
// the GPU from its three nearest guides, at the length the length field
// gives it (see buildGuides). Hair shorter than SHELL_MAX_LENGTH is drawn
// by shells: stacked copies of the scalp cut into individual hairs (fur
// technique). Scissors and brush tools shorten guides in the simulator.
//
// The whole bust can turn (bodyGroup.matrix); hair is simulated in its frame.

(function () {
  const G = window.HairGroom;
  const V = G.V;
  const SHELL_LAYERS = 14;
  // Points along each drawn strand: more than the guides' V, so a curl has
  // enough of them to turn through (a few per turn).
  const DRAW_POINTS = 40;

  // Length and colour of the hair at a scalp UV, from groom.js's fields.
  const FIELDS_GLSL = `
    uniform sampler2D uBaseField;   // r: base length x hairline (scene units), g: hairline
    uniform sampler2D uLengthMask;  // painted length / MAX_LENGTH, alpha = painted
    uniform sampler2D uColorMask;   // dye, alpha = painted
    uniform sampler2D uTypeField;   // curl brush: red = 20 i + 10 (hair type i), alpha = painted
    uniform vec3 uBaseColor;
    uniform int uBaseType;          // the design's hair type (index into groom.js HAIR_TYPES)
    // Per hair type: (pattern, radius, wavenumber, frizz), (definition,
    // shine, shrink, curliness) — scene units; see groom.js HAIR_TYPES.
    uniform vec4 uTypeShape[${G.HAIR_TYPES.length}];
    uniform vec4 uTypeLook[${G.HAIR_TYPES.length}];
    const float PAINTED_MAX = ${(G.MAX_LENGTH * G.LENGTH_TO_SCENE).toFixed(3)};

    float hairLength(vec2 uv) {
      vec2 base = texture2D(uBaseField, uv).rg;
      vec4 painted = texture2D(uLengthMask, uv);
      // Divide out alpha: at a stroke's edge linear filtering blends with
      // unpainted (0,0,0,0) texels — this recovers the painted value.
      float paintedLength = painted.r / max(painted.a, 0.001) * PAINTED_MAX * base.g;
      return mix(base.r, paintedLength, painted.a);
    }

    // Sine-free hash: fract(sin()) loses precision on cell and pixel
    // coordinates and draws lines across the hair.
    float hash(vec3 p) {
      p = fract(p * 0.1031);
      p += dot(p, p.zyx + 31.32);
      return fract((p.x + p.y) * p.z);
    }

    // Where shells hand over to strands: full shells up to SHELL_MAX_LENGTH,
    // easing to just the undercoat by UNDERCOAT_FROM. The strands start
    // shorter than that, so the two overlap — handing over any sooner
    // leaves a band of sparse short strands over a dark undercoat.
    const float UNDERCOAT_FROM = ${(G.SHELL_MAX_LENGTH * 1.75).toFixed(3)};

    float undercoat(float hairLen) {
      return smoothstep(${G.SHELL_MAX_LENGTH.toFixed(3)}, UNDERCOAT_FROM, hairLen);
    }

    // How tall the shells are: the hair itself where it's short; beneath
    // strands, only a thin undercoat at the roots — a full-height one would
    // swallow the strands lying on the head.
    float shellLength(float hairLen) {
      return mix(min(hairLen, ${G.SHELL_MAX_LENGTH.toFixed(3)}), 0.015, undercoat(hairLen));
    }

    int hairTypeIndex(vec2 uv) {
      vec4 painted = texture2D(uTypeField, uv);
      return painted.a > 0.5 ? int(painted.r * 255.0 / 20.0) : uBaseType;
    }

    vec3 hairColor(vec2 uv) {
      vec4 dye = texture2D(uColorMask, uv);
      return mix(uBaseColor, pow(dye.rgb / max(dye.a, 0.001), vec3(2.2)), dye.a);
    }

    // Kajiya-Kay: a white primary highlight and a coloured secondary one,
    // the two bands real hair shows.
    vec3 shadeHair(vec3 color, vec3 tangent, vec3 view, vec3 key, float occlusion, float shine) {
      float tl = dot(tangent, key);
      float diffuse = mix(0.3, 1.0, sqrt(max(0.0, 1.0 - tl * tl)));
      vec3 halfway = normalize(key + view);
      vec3 t1 = normalize(tangent + view * 0.1);
      vec3 t2 = normalize(tangent - view * 0.15);
      float h1 = dot(t1, halfway);
      float h2 = dot(t2, halfway);
      float primary = pow(sqrt(max(0.0, 1.0 - h1 * h1)), 90.0);
      float secondary = pow(sqrt(max(0.0, 1.0 - h2 * h2)), 22.0);
      return (color * diffuse + ((vec3(0.03) + color * 0.25) * primary + color * 0.55 * secondary) * shine) * occlusion;
    }

    // Short hair seen from a distance has no single strand direction to
    // light: soft wrap-around light, brighter at the outline, as fur reads.
    vec3 shadeShortHair(vec3 color, vec3 normal, vec3 view, vec3 key, float occlusion) {
      float wrap = clamp((dot(normal, key) + 0.5) / 1.5, 0.0, 1.0);
      float rim = pow(1.0 - abs(dot(normal, view)), 3.0);
      return color * (0.3 + 0.8 * wrap + 0.3 * rim) * occlusion;
    }
  `;
  class HairEngine {
    constructor(renderer, scene, bodyGroup, fields) {
      this.renderer = renderer;
      this.scene = scene;
      this.bodyGroup = bodyGroup;
      this.fields = fields;
      this.body = { matrix: bodyGroup.matrix, inverse: new THREE.Matrix4(), rotation: new THREE.Matrix3() };
      this.rows = 0; // guides
      this.strandCount = 0; // drawn strands
      this.lengths = new Float32Array(0);
      this.roots = new Float32Array(0);
      this.layers = 8;
      this.maxLayers = 8;
      this.wind = 0;
      this.puff = 0.03;
      this.pendingGroom = null; // sent to the simulator, not settled yet
      this.groomId = 0;
      this.stepInFlight = false;
      this.lastStep = 0;
      this.spare = null; // a positions buffer to hand back to the simulator
      this.swipeDone = null;
      this.simMs = 0; // the simulator's own time for its last step
      this.settleMs = 0;
      this.onChange = null; // called with each simulator message that changes what to draw

      this.buildFieldTextures();
      this.buildStrandMaterial();
      this.buildShells();
      this.updateBody();
      this.connectSimulator();
    }

    connectSimulator() {
      this.sim = connectHairSimulator((message) => this.onSimMessage(message));
      const c = G.collision;
      this.sim.send({
        type: 'init',
        V,
        config: {
          skin: { data: G.skinRadius, width: G.scalpInfo.width, height: G.scalpInfo.height },
          cranium: G.CRANIUM.toArray(),
          maxPolar: G.MAX_POLAR,
          lift: G.STRAND_LIFT,
          collision: { face: c.face, neck: c.neck, shoulders: c.shoulders },
        },
      });
    }

    onSimMessage(message) {
      switch (message.type) {
        case 'groomReady':
          if (message.id !== this.groomId) return; // superseded by a newer groom
          this.settleMs = message.settleMs;
          this.applyGroom(this.pendingGroom, message.positions);
          this.pendingGroom = null;
          break;
        case 'positions':
          this.stepInFlight = false;
          this.simMs = message.stepMs;
          if (this.pendingGroom || message.positions.length !== this.rows * V * 4) return;
          this.showPositions(message.positions);
          break;
        case 'swipe':
          this.swipeDone?.(message.cuts);
          this.swipeDone = null;
          break;
        default:
          return;
      }
      this.onChange?.(message);
    }

    showPositions(positions) {
      const texture = this.positionsTexture;
      if (texture.image.width === V && texture.image.height === this.rows) {
        this.spare = texture.image.data;
        texture.image.data = positions;
      } else {
        texture.dispose();
        this.positionsTexture = new THREE.DataTexture(positions, V, Math.max(1, this.rows), THREE.RGBAFormat, THREE.FloatType);
        this.strandMaterial.uniforms.uPositions.value = this.positionsTexture;
        this.spare = null;
      }
      this.positionsTexture.needsUpdate = true;
    }

    // --- Fields -------------------------------------------------------------

    buildFieldTextures() {
      const base = new THREE.DataTexture(
        new Uint16Array(G.BASE_WIDTH * G.BASE_HEIGHT * 2), G.BASE_WIDTH, G.BASE_HEIGHT, THREE.RGFormat, THREE.HalfFloatType,
      );
      base.wrapS = THREE.RepeatWrapping;
      base.magFilter = base.minFilter = THREE.LinearFilter;
      this.baseTexture = base;

      const skin = new Uint16Array(G.skinRadius.length);
      for (let i = 0; i < skin.length; i++) skin[i] = THREE.DataUtils.toHalfFloat(G.skinRadius[i]);
      this.skinTexture = new THREE.DataTexture(skin, G.scalpInfo.width, G.scalpInfo.height, THREE.RedFormat, THREE.HalfFloatType);
      this.skinTexture.wrapS = THREE.RepeatWrapping;
      this.skinTexture.magFilter = this.skinTexture.minFilter = THREE.LinearFilter;
      this.skinTexture.needsUpdate = true;

      const mask = (canvas) => {
        const texture = new THREE.CanvasTexture(canvas);
        texture.flipY = false; // texture v = canvas row, matching the UV maths
        texture.wrapS = THREE.RepeatWrapping;
        texture.generateMipmaps = false;
        texture.minFilter = texture.magFilter = THREE.LinearFilter;
        texture.colorSpace = THREE.NoColorSpace; // raw data; hairColor() decodes the dye itself
        return texture;
      };
      this.lengthMaskTexture = mask(this.fields.length.canvas);
      // Hair type indices: nearest, never blended into indices in between.
      this.typeTexture = mask(this.fields.type.canvas);
      this.typeTexture.minFilter = this.typeTexture.magFilter = THREE.NearestFilter;
      this.colorMaskTexture = mask(this.fields.color.canvas);

      this.positionsTexture = new THREE.DataTexture(new Float32Array(4), 1, 1, THREE.RGBAFormat, THREE.FloatType);

      this.fieldUniforms = {
        uBaseField: { value: this.baseTexture },
        uLengthMask: { value: this.lengthMaskTexture },
        uColorMask: { value: this.colorMaskTexture },
        uTypeField: { value: this.typeTexture },
        uBaseType: { value: 0 },
        uTypeShape: { value: G.HAIR_TYPES.map((t) => new THREE.Vector4(t.pattern, t.diameter * 0.05, (2 * Math.PI) / (t.wavelength * 0.1), t.frizz)) },
        uTypeLook: { value: G.HAIR_TYPES.map((t) => new THREE.Vector4(t.definition, t.shine, t.shrink, t.curliness)) },
        uBaseColor: { value: new THREE.Color('#3b2314') },
      };
    }

    // groom.js recomputed the base field: upload it.
    baseFieldChanged() {
      const data = this.baseTexture.image.data;
      for (let i = 0; i < data.length; i++) data[i] = THREE.DataUtils.toHalfFloat(this.fields.base[i]);
      this.baseTexture.needsUpdate = true;
    }

    masksChanged() {
      this.lengthMaskTexture.needsUpdate = true;
      this.colorMaskTexture.needsUpdate = true;
      this.typeTexture.needsUpdate = true;
    }

    // --- Groom -----------------------------------------------------------------

    // Replaces the strands with a new set of guides. They settle in the
    // simulator while the current hair stays on screen, then swap in.
    setGroom(groom) {
      this.groomId++;
      this.pendingGroom = groom;
      this.sim.send({
        type: 'groom',
        id: this.groomId,
        rows: groom.rows,
        rest: groom.rest,
        stiffness: groom.stiffness,
        puff: this.puff,
        body: this.body.matrix.elements,
        inverse: this.body.inverse.elements,
      });
    }

    applyGroom(groom, positions) {
      this.rows = groom.rows;
      this.lengths = groom.lengths;
      this.roots = groom.roots;
      this.strandCount = groom.strandCount;
      this.strandMesh.visible = groom.rows > 0 && groom.strandCount > 0;
      this.showPositions(positions);
      const geometry = this.strandMesh.geometry;
      const strands = new THREE.InstancedInterleavedBuffer(groom.strands, 16, 1);
      geometry.setAttribute('aRoot', new THREE.InterleavedBufferAttribute(strands, 4, 0));
      geometry.setAttribute('aRootUv', new THREE.InterleavedBufferAttribute(strands, 4, 4));
      geometry.setAttribute('aGuides', new THREE.InterleavedBufferAttribute(strands, 4, 8));
      geometry.setAttribute('aWeights', new THREE.InterleavedBufferAttribute(strands, 4, 12));
      this.updateInstanceCount();
    }

    // Whether a groom is still settling in the simulator.
    get settling() {
      return this.pendingGroom !== null;
    }

    setLayers(layers) {
      this.layers = layers;
      this.updateInstanceCount();
    }

    setMaxLayers(maxLayers) {
      this.maxLayers = maxLayers;
      this.updateInstanceCount();
    }

    updateInstanceCount() {
      // Layers: eighths of the drawn strands (volume, and the quality tier).
      this.strandMesh.geometry.instanceCount = Math.round((this.strandCount * Math.max(1, Math.min(this.layers, this.maxLayers))) / 8);
    }

    // --- Body ------------------------------------------------------------------

    // Call after the designer moves the bust (bodyGroup.matrix).
    updateBody() {
      this.body.matrix.copy(this.bodyGroup.matrix);
      this.body.inverse.copy(this.body.matrix).invert();
      this.body.rotation.setFromMatrix4(this.body.matrix);
    }

    // --- Stepping --------------------------------------------------------------

    // Asks the simulator for the next positions. One request at a time: a
    // slow step skips frames rather than queueing up behind them.
    step(now) {
      if (this.stepInFlight || this.rows === 0 || this.pendingGroom) return;
      const elapsed = this.lastStep && now - this.lastStep < 200 ? (now - this.lastStep) / 1000 : 1 / 60;
      this.lastStep = now;
      this.stepInFlight = true;
      const buffer = this.spare;
      this.spare = null;
      this.sim.send({
        type: 'step',
        elapsed,
        wind: this.wind,
        puff: this.puff,
        body: this.body.matrix.elements,
        inverse: this.body.inverse.elements,
        buffer,
      }, buffer ? [buffer.buffer] : []);
    }

    // --- Cutting -----------------------------------------------------------------

    beginSwipe() {
      this.sim.send({ type: 'beginSwipe' });
    }

    // One segment of a scissor swipe (CSS pixels, y down).
    cutAlong(a, b, camera, viewport) {
      if (this.rows === 0) return;
      const modelViewProjection = new THREE.Matrix4()
        .multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse)
        .multiply(this.body.matrix);
      this.sim.send({
        type: 'cut',
        modelViewProjection: modelViewProjection.elements,
        viewport: [viewport.width, viewport.height],
        a: [a.x, viewport.height - a.y],
        b: [b.x, viewport.height - b.y],
        radius: 16,
        cameraDirection: camera.position.clone().applyMatrix4(this.body.inverse).normalize().toArray(),
      });
    }

    // The swipe's cuts, as [{ row, length }] with new lengths (scene units),
    // passed to `done` once the simulator has them.
    endSwipe(done) {
      this.swipeDone = (cuts) => {
        const result = [];
        for (let i = 0; i < cuts.length; i += 2) {
          const row = cuts[i];
          this.lengths[row] *= cuts[i + 1];
          result.push({ row, length: this.lengths[row] });
        }
        done(result);
      };
      this.sim.send({ type: 'endSwipe' });
    }

    // Shortens guides to new lengths (scene units) where those are shorter —
    // brush tools painting a length. Returns whether any guide would have
    // to grow instead (which needs a rebuild).
    shortenTo(newLengths) {
      if (this.rows === 0) return false;
      const fractions = new Float32Array(this.rows).fill(1);
      let shortened = false;
      let grows = false;
      for (let row = 0; row < this.rows; row++) {
        const target = newLengths[row];
        if (target < this.lengths[row] * 0.97) {
          fractions[row] = Math.max(2 / (V - 1), target / this.lengths[row]);
          this.lengths[row] *= fractions[row];
          shortened = true;
        } else if (target > this.lengths[row] * 1.05) {
          grows = true;
        }
      }
      if (shortened) this.sim.send({ type: 'shorten', fractions });
      return grows;
    }

    // --- Rendering -----------------------------------------------------------------

    buildStrandMaterial() {
      const positions = [];
      const indices = [];
      for (let j = 0; j < DRAW_POINTS; j++) {
        positions.push(-1, j, 0, 1, j, 0);
        if (j < DRAW_POINTS - 1) indices.push(j * 2, j * 2 + 1, j * 2 + 2, j * 2 + 1, j * 2 + 3, j * 2 + 2);
      }
      const geometry = new THREE.InstancedBufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
      geometry.setIndex(indices);
      geometry.instanceCount = 0;

      this.strandMaterial = new THREE.ShaderMaterial({
        uniforms: {
          ...this.fieldUniforms,
          uPositions: { value: this.positionsTexture },
          uBody: { value: this.body.matrix },
          uBodyRotation: { value: this.body.rotation },
          uWidth: { value: 1 },
          uKey: { value: new THREE.Vector3(0.4, 0.6, 0.7).normalize() },
          uSkinRadius: { value: this.skinTexture },
          uCranium: { value: G.CRANIUM },
          uMaxPolar: { value: G.MAX_POLAR },
        },
        vertexShader: `
          ${FIELDS_GLSL}
          uniform sampler2D uPositions, uSkinRadius;
          uniform mat3 uBodyRotation;
          uniform mat4 uBody;
          uniform vec3 uCranium;
          uniform float uWidth, uMaxPolar;
          // Layout must match groom.js buildGuides:
          attribute vec4 aRoot;    // root position (body space), random
          attribute vec4 aRootUv;  // scalp u, v, clumping (0 = a stray hair), length jitter
          attribute vec4 aGuides;  // the three guide rows it follows (the first is its clump's)
          attribute vec4 aWeights; // their weights
          varying vec3 vTangent;
          varying vec3 vWorld;
          varying vec3 vColor;
          varying float vAlong;
          varying float vFromRoot;
          varying float vShade;
          varying float vAcross;
          varying float vSeed;
          varying float vShine;

          // A guide's point at arc length s from its root (body space); adds
          // its local direction, weighted, to dir. Guides' w is their length.
          vec3 guideAt(int row, float s, float weight, inout vec3 dir) {
            float guideLength = texelFetch(uPositions, ivec2(0, row), 0).w;
            float k = clamp(s / max(guideLength, 1e-4), 0.0, 1.0) * ${(V - 1).toFixed(1)};
            int j0 = min(int(floor(k)), ${V - 2});
            vec3 a = texelFetch(uPositions, ivec2(j0, row), 0).xyz;
            vec3 b = texelFetch(uPositions, ivec2(j0 + 1, row), 0).xyz;
            dir += (b - a) * weight;
            return mix(a, b, k - float(j0));
          }

          vec3 guideRoot(int row) {
            return texelFetch(uPositions, ivec2(0, row), 0).xyz;
          }

          void main() {
            float along = position.y / ${(DRAW_POINTS - 1).toFixed(1)};
            int type = hairTypeIndex(aRootUv.xy);
            vec4 shape = uTypeShape[type];
            vec4 look = uTypeLook[type];
            // What it looks like, not its length pulled straight: a coil
            // takes up some of it.
            float strandLength = hairLength(aRootUv.xy) * aRootUv.w * (1.0 - look.z);
            // Hair this short (cut, clipped) is the shells': no strand.
            if (strandLength < ${G.STRAND_MIN_LENGTH.toFixed(3)}) {
              gl_Position = vec4(0.0, 0.0, -2.0, 1.0);
              return;
            }
            float s = along * strandLength;

            // The strand's own root, moved the way its three guides move.
            ivec3 rows = ivec3(aGuides.xyz);
            vec3 dir = vec3(0.0, -1e-6, 0.0);
            vec3 g0 = guideAt(rows.x, s, aWeights.x, dir);
            vec3 g1 = guideAt(rows.y, s, aWeights.y, dir);
            vec3 g2 = guideAt(rows.z, s, aWeights.z, dir);
            vec3 r0 = guideRoot(rows.x);
            vec3 d0 = g0 - r0;
            vec3 d1 = g1 - guideRoot(rows.y);
            vec3 d2 = g2 - guideRoot(rows.z);
            // Where neighbouring guides part ways (long hair falling either
            // side of a shoulder), blending them puts strands through the
            // middle: follow the strand's own lock instead.
            vec3 w = aWeights.xyz * vec3(1.0, 1.0 - smoothstep(0.12, 0.35, distance(d1, d0)), 1.0 - smoothstep(0.12, 0.35, distance(d2, d0)));
            w /= w.x + w.y + w.z;
            vec3 p = aRoot.xyz + w.x * d0 + w.y * d1 + w.z * d2;
            // Clumping: toward the first guide's path, more toward the tip,
            // so hair gathers into locks as real hair does.
            float definition = aRootUv.z == 0.0 ? 0.0 : (shape.x >= 2.0 ? look.x : aRootUv.z);
            float clump = definition * smoothstep(0.1, 1.0, along);
            p = mix(p, g0 + (aRoot.xyz - r0) * 0.25, clump);
            // Stray hairs wander off their lock.
            vec3 seed3 = vec3(aRoot.w * 13.1, aRoot.w * 71.7, aRoot.w * 37.3);
            p += (fract(seed3) - 0.5) * (aRootUv.z == 0.0 ? 0.12 : 0.012) * along * along;

            // Blending guides that curve round the head cuts the corner
            // through it: keep the strand out of the skin.
            vec3 e = p / uCranium;
            float r = length(e);
            vec3 d = e / max(r, 1e-6);
            float polar = acos(clamp(d.y, -1.0, 1.0));
            float clear = 1.0;
            if (polar <= uMaxPolar) {
              float azimuth = atan(d.z, d.x);
              if (azimuth < 0.0) azimuth += 6.2831853;
              vec2 size = vec2(${G.scalpInfo.width.toFixed(1)}, ${G.scalpInfo.height.toFixed(1)});
              vec2 uv = vec2(azimuth / 6.2831853 + 0.5 / size.x, (polar / uMaxPolar * (size.y - 1.0) + 0.5) / size.y);
              float skin = texture2D(uSkinRadius, uv).r;
              float minimum = skin + ${(G.STRAND_LIFT * 0.6).toFixed(3)};
              if (r < minimum) p = d * minimum * uCranium;
              // How deep in the hair this point is: under the rest of it,
              // hair gets less light. Measured against how thick the hair is
              // here — short hair lying flat is the top layer, fully lit.
              float thickness = clamp(hairLength(vec2(azimuth / 6.2831853, polar / uMaxPolar)) * 0.4, 0.015, 0.4);
              clear = smoothstep(0.0, thickness, max(r, minimum) - skin);
            }

            p = (uBody * vec4(p, 1.0)).xyz;
            vec3 tangent = normalize(uBodyRotation * dir);

            // The hair type's pattern, round the strand's path. b1 lies across
            // the hair's sheet (perpendicular to the strand and to the way out
            // of the head), so waves swing side to side, as they do; b2 is out.
            vec3 outward = normalize(p - (uBody * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
            vec3 b1 = cross(tangent, outward);
            b1 = length(b1) > 1e-3 ? normalize(b1) : normalize(cross(tangent, vec3(0.0, 0.0, 1.0)));
            vec3 b2 = cross(tangent, b1);
            float pattern = shape.x;
            // Never more than a turn per few drawn points: finer than that
            // can't be drawn, and only aliases.
            float wavenumber = min(shape.z, ${(DRAW_POINTS / 4).toFixed(1)} * 6.2832 / max(strandLength, 1e-3));
            // Curls turn together within a lock (phase from its guide), so
            // they read as ringlets rather than noise.
            float phase = fract(aGuides.x * 0.618034) * 6.2832 + aRoot.w * 0.8 + s * wavenumber;
            // Straight from the root for the first centimetre or so.
            float radius = shape.y * smoothstep(0.0, 0.12, s);
            vec3 offset = vec3(0.0);
            vec3 slope = vec3(0.0);
            if (pattern == 1.0) {
              offset = sin(phase) * b1;
              slope = cos(phase) * b1;
            } else if (pattern == 2.0) {
              offset = cos(phase) * b1 + sin(phase) * b2;
              slope = -sin(phase) * b1 + cos(phase) * b2;
            } else if (pattern == 3.0) {
              // Zig-zag: a triangle wave, sharp at its corners.
              float zig = asin(sin(phase)) * 0.63662;
              offset = zig * b1 + 0.35 * sin(phase * 0.5) * b2;
              slope = sign(cos(phase)) * 0.63662 * 1.5708 * b1;
            }
            p += radius * offset;
            tangent = normalize(tangent + radius * wavenumber * slope);
            // Frizz: fine kinks off the pattern, more toward the tips.
            float frizz = shape.w * 0.012 * smoothstep(0.0, 0.3, along);
            p += frizz * (sin(s * 157.0 + aRoot.w * 41.0) * b1 + sin(s * 113.0 + aRoot.w * 23.0) * b2);

            // A card: a strip a few millimetres wide holding several fine
            // hairs (drawn in the fragment shader), facing the camera.
            vec3 side = normalize(cross(tangent, cameraPosition - p));
            // Curlier hair reads bulkier: its hairs don't lie side by side.
            p += side * position.x * 0.016 * uWidth * (1.0 + 0.6 * look.w) * mix(1.0, 0.45, along);

            vTangent = tangent;
            vWorld = p;
            vColor = hairColor(aRootUv.xy) * (0.9 + 0.2 * aRoot.w);
            vAlong = along;
            vFromRoot = s;
            vShade = mix(0.42, 1.0, clear) * mix(0.8, 1.0, aRoot.w);
            vAcross = position.x;
            vSeed = aRoot.w;
            vShine = look.y;
            gl_Position = projectionMatrix * viewMatrix * vec4(p, 1.0);
          }`,
        fragmentShader: `
          ${FIELDS_GLSL}
          uniform vec3 uKey;
          varying vec3 vTangent;
          varying vec3 vWorld;
          varying vec3 vColor;
          varying float vAlong;
          varying float vFromRoot;
          varying float vShade;
          varying float vAcross;
          varying float vSeed;
          varying float vShine;

          const float HAIRS_PER_CARD = 7.0;

          void main() {
            // Which of the card's hairs this pixel is in, and how far from
            // its centre line.
            float x = (vAcross * 0.5 + 0.5) * HAIRS_PER_CARD;
            float id = floor(x);
            vec3 hairSeed = vec3(id, vSeed * 97.0, 1.0);
            float wobble = 0.12 * sin(vAlong * 31.0 + hash(hairSeed) * 40.0);
            float centre = 0.5 + (hash(hairSeed + 1.0) - 0.5) * 0.5 + wobble;
            float halfWidth = mix(0.16, 0.32, hash(hairSeed + 2.0));
            // Close up the card's hairs separate, with gaps between them.
            // Once they're thinner than a pixel the card reads as a dense
            // lock (nearly opaque — partial coverage doesn't build up across
            // overlapping cards) and the hairs show as shading instead.
            float pixel = fwidth(x);
            float far = smoothstep(0.35, 1.0, pixel);
            float sharp = 1.0 - smoothstep(halfWidth - pixel, halfWidth + pixel, abs(fract(x) - centre));
            // Each hair ends at its own length (on average, from a distance).
            float tip = mix(0.62, 1.0, hash(hairSeed + 3.0));
            float ends = mix(1.0 - smoothstep(tip - 0.1, tip, vAlong), 1.0 - smoothstep(0.7, 1.0, vAlong), far);
            float alpha = mix(sharp, 0.95, far) * ends * (1.0 - smoothstep(0.7, 1.0, abs(vAcross)));
            // Hairs grow out of the skin one by one: no hard edge of card
            // roots along the hairline.
            alpha *= smoothstep(0.0, 0.04, vFromRoot);
            if (alpha < 0.02) discard;

            vec3 view = normalize(cameraPosition - vWorld);
            // Roots are in the shade of the hair around them (the first
            // 1.2 cm, whatever the strand's length).
            float occlusion = mix(0.55, 1.0, smoothstep(0.0, 0.12, vFromRoot)) * vShade;
            float lockShade = 0.82 + 0.3 * hash(vec3(floor(vAlong * 5.0 + vSeed * 3.0), vSeed * 97.0, 7.0));
            vec3 color = vColor * mix(mix(0.78, 1.15, hash(hairSeed + 4.0)), lockShade * (0.85 + 0.25 * sharp), far);
            gl_FragColor = vec4(shadeHair(color, normalize(vTangent), view, uKey, occlusion, vShine), alpha);
            #include <colorspace_fragment>
          }`,
        side: THREE.DoubleSide,
        alphaToCoverage: true,
      });
      this.strandMesh = new THREE.Mesh(geometry, this.strandMaterial);
      this.strandMesh.frustumCulled = false;
      this.scene.add(this.strandMesh);
    }

    // Shells over the scan's scalp map, one instance per layer.
    buildShells() {
      const w = G.scalpInfo.width;
      const h = G.scalpInfo.height;
      const scalpPositions = [];
      const scalpNormals = [];
      const uvs = [];
      const indices = [];
      for (let row = 0; row < h; row++) {
        for (let col = 0; col <= w; col++) {
          const i = (row * w + (col % w)) * 6;
          scalpPositions.push(G.scalpData[i], G.scalpData[i + 1], G.scalpData[i + 2]);
          scalpNormals.push(G.scalpData[i + 3], G.scalpData[i + 4], G.scalpData[i + 5]);
          uvs.push(col / w, row / (h - 1));
          if (row < h - 1 && col < w) {
            const a = row * (w + 1) + col;
            const b = a + w + 1;
            indices.push(a, b, a + 1, a + 1, b, b + 1);
          }
        }
      }
      const geometry = new THREE.InstancedBufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(scalpPositions, 3));
      geometry.setAttribute('aNormal', new THREE.Float32BufferAttribute(scalpNormals, 3));
      geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
      geometry.setIndex(indices);
      geometry.setAttribute('aLayer', new THREE.InstancedBufferAttribute(Float32Array.from({ length: SHELL_LAYERS }, (_, i) => i), 1));
      geometry.instanceCount = SHELL_LAYERS;

      this.shellMaterial = new THREE.ShaderMaterial({
        uniforms: {
          ...this.fieldUniforms,
          uCranium: { value: G.CRANIUM },
          uKey: this.strandMaterial.uniforms.uKey,
        },
        vertexShader: `
          ${FIELDS_GLSL}
          attribute vec3 aNormal;
          attribute float aLayer;
          uniform vec3 uCranium;
          varying vec2 vUv;
          varying float vLayer;
          varying vec3 vNormal;
          varying vec3 vDirection;
          varying vec3 vWorld;
          varying float vUndercoat;
          void main() {
            float hairLen = hairLength(uv);
            vUndercoat = step(UNDERCOAT_FROM, hairLen);
            float height = shellLength(hairLen) * (aLayer + 1.0) / ${SHELL_LAYERS.toFixed(1)};
            vec4 world = modelMatrix * vec4(position + aNormal * (height + 0.002), 1.0);
            vUv = uv;
            vLayer = aLayer;
            vNormal = normalize(mat3(modelMatrix) * aNormal);
            vDirection = normalize(position / uCranium);
            vWorld = world.xyz;
            gl_Position = projectionMatrix * viewMatrix * world;
          }`,
        fragmentShader: `
          ${FIELDS_GLSL}
          uniform vec3 uKey;
          varying vec2 vUv;
          varying float vLayer;
          varying vec3 vNormal;
          varying vec3 vDirection;
          varying vec3 vWorld;
          varying float vUndercoat;

          void main() {
            // Beneath strands only the bottom layer (the roots) is drawn: skip
            // the other 13 before any work, they're most of the fill cost.
            if (vLayer > 0.5 && vUndercoat > 0.99) discard;
            float capped = shellLength(hairLength(vUv));
            if (capped < 0.004) discard;
            float hairlineDensity = texture2D(uBaseField, vUv).g;

            // One hair per cell of a grid projected from a cube onto the
            // scalp: even everywhere, unlike UV (which pinches at the crown).
            vec3 d = normalize(vDirection);
            vec3 m = abs(d);
            vec2 face;
            float faceId;
            if (m.x >= m.y && m.x >= m.z) { face = d.yz / m.x; faceId = sign(d.x); }
            else if (m.y >= m.z) { face = d.xz / m.y; faceId = 2.0 + sign(d.y); }
            else { face = d.xy / m.z; faceId = 4.0 + sign(d.z); }
            vec2 cellSpace = face * 190.0;
            vec3 cell = vec3(floor(cellSpace), faceId);
            // Hairs sit at random spots in their cells: on a lattice the
            // stacked layers line up into rows you can see through.
            vec2 jitter = vec2(hash(cell + 3.0), hash(cell + 5.0)) - 0.5;
            vec2 offset = fract(cellSpace) - 0.5 - jitter * 0.6;
            // Close up each cell draws its own hair; zoomed out (cells below a
            // pixel) the layer is drawn at the coverage those hairs would
            // average to. Blended, never random per pixel — no static.
            float far = smoothstep(0.35, 0.9, length(fwidth(cellSpace)));
            float layerFraction = (vLayer + 1.0) / ${SHELL_LAYERS.toFixed(1)};
            float relative = 0.7 + 0.3 * hash(cell); // this hair's height, relative to the length
            float thickness = mix(0.5, 0.18, clamp(layerFraction / relative, 0.0, 1.0))
              * mix(0.4, 1.0, smoothstep(0.004, 0.05, capped)); // stubble shows skin between hairs
            float edge = fwidth(offset.x) + 0.02;
            float near = (layerFraction <= relative ? 1.0 : 0.0) * (1.0 - smoothstep(thickness - edge, thickness + edge, length(offset)));
            // Averages. How much skin short hair hides grows with its length
            // (~15% at 2 mm, ~60% at 6 mm, nearly all at 12 mm) — that's what
            // makes a fade read as a fade. Each layer takes an equal share of
            // that, and only hairs tall enough reach the upper layers.
            float reaching = clamp((1.0 - layerFraction) / 0.3, 0.0, 1.0);
            float stackOpacity = 0.97 * smoothstep(0.0, 0.12, capped);
            float averaged = reaching * (1.0 - pow(1.0 - stackOpacity, 1.0 / ${SHELL_LAYERS.toFixed(1)}));
            // At a distance, clumps and streaks fixed on the head give short
            // hair its texture (stable as the view moves, unlike per-pixel
            // noise): a coarse cell noise across, and growth-wise streaks.
            vec2 clumpSpace = cellSpace / 7.0;
            float clump = mix(hash(vec3(floor(clumpSpace), faceId + 31.0)), hash(vec3(floor(clumpSpace + 0.5), faceId + 37.0)), 0.5);
            float streak = hash(vec3(floor(cellSpace.x / 2.0), floor(cellSpace.y / 9.0), faceId + 41.0));
            float grain = 0.55 + 0.7 * clump * (0.7 + 0.3 * streak);
            float alpha = mix(near, averaged * (0.6 + 0.6 * grain), far);
            // The bottom layer carries the stack's opacity, so the scalp shows
            // through short hair exactly as much as it should.
            if (vLayer < 0.5) alpha = max(alpha, stackOpacity * 0.6);
            // Fewer hairs toward the hairline: a soft edge, not a helmet line.
            float density = hairlineDensity * hairlineDensity;
            alpha *= mix(hash(cell + 9.0) < density ? 1.0 : 0.0, density, far);

            vec3 view = normalize(cameraPosition - vWorld);
            // Seen edge-on, upper layers thin out so the outline reads as fuzz
            // rather than a stack of slices.
            float facing = abs(dot(normalize(vNormal), view));
            if (vLayer > 0.5) alpha *= smoothstep(0.05, 0.45, facing);
            if (alpha < 0.01) discard;

            // Each hair leans its own way (close up): a shared direction would
            // light the whole cap as one smooth, helmet-like highlight.
            vec3 lean = (vec3(hash(cell + 13.0), hash(cell + 17.0), hash(cell + 19.0)) - 0.5) * (1.0 - far);
            vec3 tangent = normalize(vNormal + vec3(0.0, -0.3, 0.0) + lean * 1.6);
            float occlusion = mix(0.7, 1.0, layerFraction);
            vec3 color = hairColor(vUv) * mix(0.88 + 0.24 * hash(cell + 7.0), 0.62 + 0.55 * grain, far);
            vec3 shaded = mix(
              shadeHair(color, tangent, view, uKey, occlusion, uTypeLook[hairTypeIndex(vUv)].y),
              shadeShortHair(color, normalize(vNormal), view, uKey, mix(0.75, 1.0, layerFraction)),
              far);
            // Beneath strands the shells are only roots in the hair's shade:
            // matte and dark, never a shiny cap of their own — but only once
            // the strands are long enough to cover them, or the hand-over
            // from short hair to strands shows as a dark band.
            float covered = smoothstep(UNDERCOAT_FROM, UNDERCOAT_FROM * 2.0, hairLength(vUv));
            shaded = mix(shaded, color * 0.3, covered);
            gl_FragColor = vec4(shaded, clamp(alpha, 0.0, 1.0));
            #include <colorspace_fragment>
          }`,
        side: THREE.DoubleSide,
        // Blended, layer by layer from the scalp out (instance order), after
        // the opaque strands: no depth writes, so it never hides a strand
        // that's in front of it.
        transparent: true,
        depthWrite: false,
      });
      this.shellMesh = new THREE.Mesh(geometry, this.shellMaterial);
      this.shellMesh.frustumCulled = false;
      this.bodyGroup.add(this.shellMesh);
    }

    setColor(hex) {
      this.fieldUniforms.uBaseColor.value.set(hex);
    }

    setHairType(id) {
      const type = G.hairTypeOf(id);
      this.fieldUniforms.uBaseType.value = G.HAIR_TYPES.indexOf(type);
      // Curly hair stands further off the head (the physics' collision margin).
      this.puff = 0.03 + 0.08 * type.curliness;
    }

    setKeyLight(direction) {
      this.strandMaterial.uniforms.uKey.value.copy(direction);
    }
  }

  HairEngine.FIELDS_GLSL = FIELDS_GLSL;
  window.HairEngine = HairEngine;
})();
