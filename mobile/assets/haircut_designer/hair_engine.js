// The hair on the GPU: physics, strands, short-hair shells, and scissors.
//
// Guide strands (from groom.js) live in float textures, one row per strand.
// The state texture is 2V wide: columns 0..V-1 hold each vertex's position,
// V..2V-1 its previous position. Each simulation step is two fragment
// passes:
//   integrate   Verlet: gravity, wind, damping, global shape memory
//   constrain   follow-the-leader (Müller et al. 2012): every segment keeps
//               its rest length, walked out from the pinned root, with local
//               shape memory, collisions (the scan's real skin from the
//               scalp map, then face, neck and shoulders) and friction; it
//               also writes previous positions with the paper's velocity
//               correction, without which strands whip.
// Each guide is drawn as CHILDREN strands around it, straight from the
// state texture. Hair shorter than SHELL_MAX_LENGTH is drawn by shells:
// stacked copies of the scalp cut into individual hairs (fur technique).
// Scissors: a pass finds where a swipe crosses each strand, another
// resamples cut strands to their new length.
//
// Positions are in world space; the whole bust can turn (bodyMatrix), and
// rest shapes are in body space.

(function () {
  const G = window.HairGroom;
  const V = G.V;
  const SUBSTEPS = 2;
  const DT = 1 / 120;
  const SHELL_LAYERS = 14;

  const FULLSCREEN_VERTEX = 'void main() { gl_Position = vec4(position.xy, 0.0, 1.0); }';

  const COLLIDE_GLSL = `
    #define TAU 6.283185307179586
    uniform mat4 uBody;
    uniform mat4 uBodyInverse;
    uniform sampler2D uSkinRadius;
    uniform vec3 uCranium;
    uniform float uMaxPolar;
    uniform vec3 uFaceCenter, uFaceRadii, uNeckCenter, uShouldersCenter, uShouldersRadii;
    uniform float uNeckRadius;

    vec3 pushOutOfEllipsoid(vec3 p, vec3 center, vec3 radii, float minimum) {
      vec3 e = (p - center) / radii;
      float r = length(e);
      return r < minimum && r > 1e-6 ? center + e / r * minimum * radii : p;
    }

    // World position pushed out of the body by margin.
    vec3 collide(vec3 world, float margin) {
      vec3 p = (uBodyInverse * vec4(world, 1.0)).xyz;
      vec3 e = p / uCranium;
      float r = length(e);
      vec3 direction = e / max(r, 1e-6);
      float polar = acos(clamp(direction.y, -1.0, 1.0));
      if (polar <= uMaxPolar) {
        float azimuth = atan(direction.z, direction.x);
        if (azimuth < 0.0) azimuth += TAU;
        // The scalp map's rows sit at polar row/(H-1), columns at azimuth col/W.
        vec2 size = vec2(${G.scalpInfo.width.toFixed(1)}, ${G.scalpInfo.height.toFixed(1)});
        vec2 uv = vec2(azimuth / TAU + 0.5 / size.x, (polar / uMaxPolar * (size.y - 1.0) + 0.5) / size.y);
        float minimum = texture2D(uSkinRadius, uv).r + margin;
        if (r < minimum) p = direction * minimum * uCranium;
      }
      p = pushOutOfEllipsoid(p, uFaceCenter, uFaceRadii, 1.0 + margin);
      vec2 neck = p.xz - uNeckCenter.xz;
      float neckDistance = length(neck);
      if (p.y < uNeckCenter.y + 0.6 && p.y > uNeckCenter.y - 0.9 && neckDistance < uNeckRadius + margin && neckDistance > 1e-6) {
        p.xz = uNeckCenter.xz + neck / neckDistance * (uNeckRadius + margin);
      }
      p = pushOutOfEllipsoid(p, uShouldersCenter, uShouldersRadii, 1.0 + margin);
      return (uBody * vec4(p, 1.0)).xyz;
    }
  `;

  // Length and colour of the hair at a scalp UV, from groom.js's fields.
  const FIELDS_GLSL = `
    uniform sampler2D uBaseField;   // r: base length x hairline (scene units), g: hairline
    uniform sampler2D uLengthMask;  // painted length / MAX_LENGTH, alpha = painted
    uniform sampler2D uColorMask;   // dye, alpha = painted
    uniform vec3 uBaseColor;
    const float PAINTED_MAX = ${(G.MAX_LENGTH * G.LENGTH_TO_SCENE).toFixed(3)};

    float hairLength(vec2 uv) {
      vec2 base = texture2D(uBaseField, uv).rg;
      vec4 painted = texture2D(uLengthMask, uv);
      // Divide out alpha: at a stroke's edge linear filtering blends with
      // unpainted (0,0,0,0) texels — this recovers the painted value.
      float paintedLength = painted.r / max(painted.a, 0.001) * PAINTED_MAX * base.g;
      return mix(base.r, paintedLength, painted.a);
    }

    vec3 hairColor(vec2 uv) {
      vec4 dye = texture2D(uColorMask, uv);
      return mix(uBaseColor, pow(dye.rgb / max(dye.a, 0.001), vec3(2.2)), dye.a);
    }

    // Kajiya-Kay: a white primary highlight and a coloured secondary one,
    // the two bands real hair shows.
    vec3 shadeHair(vec3 color, vec3 tangent, vec3 view, vec3 key, float occlusion) {
      float tl = dot(tangent, key);
      float diffuse = mix(0.3, 1.0, sqrt(max(0.0, 1.0 - tl * tl)));
      vec3 halfway = normalize(key + view);
      vec3 t1 = normalize(tangent + view * 0.1);
      vec3 t2 = normalize(tangent - view * 0.15);
      float h1 = dot(t1, halfway);
      float h2 = dot(t2, halfway);
      float primary = pow(sqrt(max(0.0, 1.0 - h1 * h1)), 90.0);
      float secondary = pow(sqrt(max(0.0, 1.0 - h2 * h2)), 22.0);
      return (color * diffuse + vec3(0.1) * primary + color * 0.7 * secondary) * occlusion;
    }
  `;

  function makePass(fragmentShader, uniforms) {
    return new THREE.ShaderMaterial({ vertexShader: FULLSCREEN_VERTEX, fragmentShader, uniforms, depthTest: false, depthWrite: false });
  }

  class HairEngine {
    constructor(renderer, scene, bodyGroup, fields) {
      this.renderer = renderer;
      this.scene = scene;
      this.bodyGroup = bodyGroup;
      this.fields = fields;
      this.floatTargets = renderer.extensions.has('EXT_color_buffer_float');
      this.body = { matrix: bodyGroup.matrix, inverse: new THREE.Matrix4(), rotation: new THREE.Matrix3() };
      this.targets = null;
      this.rows = 0;
      this.layers = 8;
      this.maxLayers = 8;
      this.wind = 0;
      this.time = 0;
      this.settling = 0;

      this.quadScene = new THREE.Scene();
      this.quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
      this.quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2));
      this.quad.frustumCulled = false;
      this.quadScene.add(this.quad);

      this.buildFieldTextures();
      this.buildPasses();
      this.buildStrandMaterial();
      this.buildShells();
      this.updateBody();
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
      this.colorMaskTexture = mask(this.fields.color.canvas);

      this.fieldUniforms = {
        uBaseField: { value: this.baseTexture },
        uLengthMask: { value: this.lengthMaskTexture },
        uColorMask: { value: this.colorMaskTexture },
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
    }

    // --- Simulation passes ---------------------------------------------------

    collisionUniforms() {
      const c = G.collision;
      return {
        uBody: { value: this.body.matrix },
        uBodyInverse: { value: this.body.inverse },
        uSkinRadius: { value: this.skinTexture },
        uCranium: { value: G.CRANIUM },
        uMaxPolar: { value: G.MAX_POLAR },
        uFaceCenter: { value: new THREE.Vector3().fromArray(c.face.center) },
        uFaceRadii: { value: new THREE.Vector3().fromArray(c.face.radii) },
        uNeckCenter: { value: new THREE.Vector3().fromArray(c.neck.center) },
        uNeckRadius: { value: c.neck.radius },
        uShouldersCenter: { value: new THREE.Vector3().fromArray(c.shoulders.center) },
        uShouldersRadii: { value: new THREE.Vector3().fromArray(c.shoulders.radii) },
      };
    }

    buildPasses() {
      this.passes = {};
      this.passes.copy = makePass(
        `uniform sampler2D uSource;
         void main() { gl_FragColor = texelFetch(uSource, ivec2(gl_FragCoord.xy), 0); }`,
        { uSource: { value: null } },
      );
      // Rest positions (V wide, body space) into a state (2V wide, world): still.
      this.passes.fillState = makePass(
        `uniform sampler2D uSource;
         uniform mat4 uBody;
         void main() {
           ivec2 c = ivec2(gl_FragCoord.xy);
           gl_FragColor = vec4((uBody * vec4(texelFetch(uSource, ivec2(c.x % ${V}, c.y), 0).xyz, 1.0)).xyz, 1.0);
         }`,
        { uSource: { value: null }, uBody: { value: this.body.matrix } },
      );
      // The state's positions (world) back into body space, as a rest shape.
      this.passes.toRest = makePass(
        `uniform sampler2D uSource;
         uniform mat4 uBodyInverse;
         void main() {
           gl_FragColor = vec4((uBodyInverse * vec4(texelFetch(uSource, ivec2(gl_FragCoord.xy), 0).xyz, 1.0)).xyz, 1.0);
         }`,
        { uSource: { value: null }, uBodyInverse: { value: this.body.inverse } },
      );

      this.passes.integrate = makePass(
        `uniform sampler2D uState, uRest;
         uniform mat4 uBody;
         uniform float uDt, uDamping, uTime, uWind;
         uniform vec2 uGlobal;
         void main() {
           ivec2 c = ivec2(gl_FragCoord.xy);
           vec3 target = (uBody * vec4(texelFetch(uRest, c, 0).xyz, 1.0)).xyz;
           if (c.x < 2) { gl_FragColor = vec4(target, 1.0); return; }
           vec3 x = texelFetch(uState, c, 0).xyz;
           vec3 xp = texelFetch(uState, ivec2(c.x + ${V}, c.y), 0).xyz;
           float along = float(c.x) / ${(V - 1).toFixed(1)};
           // Gusty wind from front-left, varying across the head and over time.
           float gust = 0.6 + 0.4 * sin(uTime * 1.9 + x.y * 2.1 + x.x * 1.3) * sin(uTime * 0.7 + float(c.y) * 0.017);
           vec3 wind = normalize(vec3(0.6, 0.15, -1.0)) * uWind * 140.0 * gust * sqrt(along);
           vec3 predicted = x + (x - xp) * (1.0 - uDamping) + (vec3(0.0, -98.0, 0.0) + wind) * uDt * uDt;
           float rootward = (1.0 - along) * (1.0 - along);
           gl_FragColor = vec4(mix(predicted, target, mix(uGlobal.y, uGlobal.x, rootward)), 1.0);
         }`,
        {
          uState: { value: null }, uRest: { value: null }, uBody: { value: this.body.matrix },
          uDt: { value: DT }, uDamping: { value: 0.05 }, uTime: { value: 0 }, uWind: { value: 0 },
          uGlobal: { value: new THREE.Vector2() },
        },
      );

      this.passes.constrain = makePass(
        `uniform sampler2D uPredicted, uRest, uState;
         uniform mat3 uBodyRotation;
         uniform vec2 uLocal;
         uniform float uFriction, uVelocityCorrection, uPuff;
         ${COLLIDE_GLSL}
         void main() {
           ivec2 c = ivec2(gl_FragCoord.xy);
           bool writesPrevious = c.x >= ${V};
           int i = c.x % ${V};
           vec3 restPrevious = texelFetch(uRest, ivec2(1, c.y), 0).xyz;
           if (i < 2) { gl_FragColor = vec4((uBody * vec4(texelFetch(uRest, ivec2(i, c.y), 0).xyz, 1.0)).xyz, 1.0); return; }
           // Walk out to vertex i — one further for the previous-position half,
           // which needs the correction the next vertex received.
           int last = writesPrevious ? min(i + 1, ${V - 1}) : i;
           vec3 q = (uBody * vec4(restPrevious, 1.0)).xyz;
           vec3 qi = q;
           vec3 nextCorrection = vec3(0.0);
           for (int j = 2; j < ${V}; j++) {
             if (j > last) break;
             vec3 restJ = texelFetch(uRest, ivec2(j, c.y), 0).xyz;
             vec3 restSegment = restJ - restPrevious;
             float segmentLength = length(restSegment);
             vec3 restDirection = uBodyRotation * (restSegment / max(segmentLength, 1e-6));
             vec3 predicted = texelFetch(uPredicted, ivec2(j, c.y), 0).xyz;
             vec3 toPredicted = predicted - q;
             vec3 direction = length(toPredicted) > 1e-6 ? normalize(toPredicted) : restDirection;
             float along = float(j) / ${(V - 1).toFixed(1)};
             float rootward = (1.0 - along) * (1.0 - along);
             direction = normalize(mix(direction, restDirection, mix(uLocal.y, uLocal.x, rootward)));
             vec3 free = q + direction * segmentLength;
             float margin = 0.012 + uPuff * along;
             vec3 collided = collide(free, margin);
             // Friction: hair touching the body mostly stays put.
             if (distance(collided, free) > 1e-5) {
               vec3 before = texelFetch(uState, ivec2(j, c.y), 0).xyz;
               collided = collide(mix(collided, before, uFriction), margin);
             }
             if (j == i + 1) nextCorrection = collided - predicted;
             q = collided;
             if (j == i) qi = q;
             restPrevious = restJ;
           }
           if (!writesPrevious) { gl_FragColor = vec4(qi, 1.0); return; }
           // Velocity correction (Muller et al. 2012): next step's velocity is
           // this vertex's move minus a share of the next vertex's correction.
           vec3 x = texelFetch(uState, ivec2(i, c.y), 0).xyz;
           gl_FragColor = vec4(x + uVelocityCorrection * nextCorrection, 1.0);
         }`,
        {
          ...this.collisionUniforms(),
          uPredicted: { value: null }, uRest: { value: null }, uState: { value: null },
          uBodyRotation: { value: this.body.rotation }, uLocal: { value: new THREE.Vector2() },
          uFriction: { value: 0.5 }, uVelocityCorrection: { value: 0.9 }, uPuff: { value: 0.03 },
        },
      );

      // One fragment per strand: where (as a fraction of its length) the
      // swipe A→B crosses it, or 1. Only hair on the camera's side is cut.
      this.passes.findCut = makePass(
        `uniform sampler2D uState;
         uniform mat4 uViewProjection;
         uniform vec2 uViewport, uA, uB;
         uniform float uRadius;
         uniform vec3 uCameraDirection, uCenter;
         float distanceToSegment(vec2 p, vec2 a, vec2 b) {
           vec2 ab = b - a;
           float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
           return length(p - a - ab * t);
         }
         void main() {
           int row = int(gl_FragCoord.y);
           float cut = 1.0;
           for (int j = 3; j < ${V - 1}; j++) { // never the very tip: a cut takes a real piece off
             vec3 p = texelFetch(uState, ivec2(j, row), 0).xyz;
             if (dot(p - uCenter, uCameraDirection) < -0.35) continue;
             vec4 clip = uViewProjection * vec4(p, 1.0);
             if (clip.w <= 0.0) continue;
             vec2 screen = (clip.xy / clip.w * 0.5 + 0.5) * uViewport;
             if (distanceToSegment(screen, uA, uB) < uRadius) {
               cut = (float(j) - 0.5) / ${(V - 1).toFixed(1)};
               break;
             }
           }
           gl_FragColor = vec4(cut, 0.0, 0.0, 1.0);
         }`,
        {
          uState: { value: null }, uViewProjection: { value: new THREE.Matrix4() }, uViewport: { value: new THREE.Vector2() },
          uA: { value: new THREE.Vector2() }, uB: { value: new THREE.Vector2() }, uRadius: { value: 16 },
          uCameraDirection: { value: new THREE.Vector3() }, uCenter: { value: new THREE.Vector3() },
        },
      );

      // Shortens strands by their cut fraction (1 = untouched); the kept part
      // keeps its shape, resampled over all V vertices. Rest is V wide,
      // state 2V wide (resampled per half).
      this.passes.resample = makePass(
        `uniform sampler2D uSource, uCut;
         void main() {
           ivec2 c = ivec2(gl_FragCoord.xy);
           float cut = texelFetch(uCut, ivec2(0, c.y), 0).x;
           if (cut > 0.999) { gl_FragColor = texelFetch(uSource, c, 0); return; }
           int base = (c.x / ${V}) * ${V};
           float s = float(c.x - base) * cut;
           int j0 = int(floor(s));
           int j1 = min(j0 + 1, ${V - 1});
           gl_FragColor = mix(texelFetch(uSource, ivec2(base + j0, c.y), 0), texelFetch(uSource, ivec2(base + j1, c.y), 0), s - float(j0));
         }`,
        { uSource: { value: null }, uCut: { value: null } },
      );
    }

    makeTarget(width, height) {
      return new THREE.WebGLRenderTarget(width, height, {
        type: this.floatTargets ? THREE.FloatType : THREE.HalfFloatType,
        format: THREE.RGBAFormat,
        minFilter: THREE.NearestFilter,
        magFilter: THREE.NearestFilter,
        depthBuffer: false,
        stencilBuffer: false,
        generateMipmaps: false,
      });
    }

    run(material, target) {
      this.quad.material = material;
      const previous = this.renderer.getRenderTarget();
      this.renderer.setRenderTarget(target);
      this.renderer.render(this.quadScene, this.quadCamera);
      this.renderer.setRenderTarget(previous);
    }

    runWith(material, uniforms, target) {
      for (const [name, value] of Object.entries(uniforms)) material.uniforms[name].value = value;
      this.run(material, target);
    }

    // --- Groom -----------------------------------------------------------------

    // Replaces the strands with a new set of guides and lets them settle.
    setGroom(groom) {
      if (this.targets) for (const target of Object.values(this.targets)) target.dispose();
      this.restTexture?.dispose();
      this.rows = groom.rows;
      this.lengths = groom.lengths;
      this.roots = groom.roots;
      this.strandMesh.visible = groom.rows > 0;
      if (groom.rows === 0) {
        this.targets = null;
        return;
      }
      const rows = groom.rows;
      this.targets = {
        state: this.makeTarget(2 * V, rows),
        nextState: this.makeTarget(2 * V, rows),
        stateScratch: this.makeTarget(2 * V, rows),
        predicted: this.makeTarget(V, rows),
        rest: this.makeTarget(V, rows),
        restScratch: this.makeTarget(V, rows),
        cut: this.makeTarget(1, rows),
      };
      this.restTexture = new THREE.DataTexture(groom.rest, V, rows, THREE.RGBAFormat, THREE.FloatType);
      this.restTexture.needsUpdate = true;
      this.runWith(this.passes.copy, { uSource: this.restTexture }, this.targets.rest);
      this.runWith(this.passes.fillState, { uSource: this.restTexture }, this.targets.state);

      this.passes.integrate.uniforms.uGlobal.value.fromArray(groom.stiffness.global);
      this.passes.constrain.uniforms.uLocal.value.fromArray(groom.stiffness.local);

      const geometry = this.strandMesh.geometry;
      const children = new THREE.InstancedInterleavedBuffer(groom.children, 8, 1);
      geometry.setAttribute('aChildA', new THREE.InterleavedBufferAttribute(children, 4, 0));
      geometry.setAttribute('aChildB', new THREE.InterleavedBufferAttribute(children, 4, 4));
      this.updateInstanceCount();
      this.settling = 4; // frames of fast settling, then the settled shape becomes the rest shape
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
      this.strandMesh.geometry.instanceCount = this.rows * Math.max(1, Math.min(this.layers, this.maxLayers));
    }

    // --- Body ------------------------------------------------------------------

    // Call after the designer moves the bust (bodyGroup.matrix).
    updateBody() {
      this.body.matrix.copy(this.bodyGroup.matrix);
      this.body.inverse.copy(this.body.matrix).invert();
      this.body.rotation.setFromMatrix4(this.body.matrix);
    }

    // --- Stepping --------------------------------------------------------------

    step() {
      if (!this.targets) return false;
      if (this.settling > 0) {
        const damping = this.passes.integrate.uniforms.uDamping;
        damping.value = 0.25;
        this.simulate(40);
        damping.value = 0.05;
        this.settling--;
        if (this.settling === 0) {
          // The settled shape becomes the style's rest shape.
          this.runWith(this.passes.toRest, { uSource: this.targets.state.texture }, this.targets.rest);
          this.runWith(this.passes.fillState, { uSource: this.targets.rest.texture }, this.targets.state);
        }
      } else {
        this.simulate(SUBSTEPS);
      }
      this.strandMaterial.uniforms.uPositions.value = this.targets.state.texture;
      return this.settling > 0;
    }

    simulate(steps) {
      const integrate = this.passes.integrate.uniforms;
      const constrain = this.passes.constrain.uniforms;
      integrate.uWind.value = this.wind;
      for (let i = 0; i < steps; i++) {
        this.time += DT;
        integrate.uTime.value = this.time;
        integrate.uState.value = this.targets.state.texture;
        integrate.uRest.value = this.targets.rest.texture;
        this.run(this.passes.integrate, this.targets.predicted);
        constrain.uPredicted.value = this.targets.predicted.texture;
        constrain.uRest.value = this.targets.rest.texture;
        constrain.uState.value = this.targets.state.texture;
        this.run(this.passes.constrain, this.targets.nextState);
        [this.targets.state, this.targets.nextState] = [this.targets.nextState, this.targets.state];
      }
    }

    // --- Cutting -----------------------------------------------------------------

    // Scissors along a swipe segment (CSS pixels, y down). Returns the
    // strands it cut as [{ row, length }] with their new lengths (scene
    // units). A strand is cut once per swipe (`cutThisSwipe`): its new tip
    // sits under the finger, and would otherwise lose a sliver on every move.
    cutAlong(a, b, camera, viewport, cutThisSwipe) {
      if (!this.targets) return [];
      const find = this.passes.findCut.uniforms;
      find.uState.value = this.targets.state.texture;
      find.uViewProjection.value.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
      find.uViewport.value.set(viewport.width, viewport.height);
      find.uA.value.set(a.x, viewport.height - a.y);
      find.uB.value.set(b.x, viewport.height - b.y);
      const center = new THREE.Vector3().setFromMatrixPosition(this.body.matrix);
      find.uCenter.value.copy(center);
      find.uCameraDirection.value.copy(camera.position).sub(center).normalize();
      this.run(this.passes.findCut, this.targets.cut);

      const fractions = new Float32Array(this.rows * 4);
      if (this.floatTargets) {
        this.renderer.readRenderTargetPixels(this.targets.cut, 0, 0, 1, this.rows, fractions);
      } else {
        const halves = new Uint16Array(this.rows * 4);
        this.renderer.readRenderTargetPixels(this.targets.cut, 0, 0, 1, this.rows, halves);
        for (let i = 0; i < halves.length; i++) fractions[i] = THREE.DataUtils.fromHalfFloat(halves[i]);
      }
      const cuts = [];
      for (let row = 0; row < this.rows; row++) {
        const i = row * 4;
        if (fractions[i] < 0.999 && !cutThisSwipe.has(row)) {
          cutThisSwipe.add(row);
          this.lengths[row] *= fractions[i];
          cuts.push({ row, length: this.lengths[row] });
        } else {
          fractions[i] = 1;
        }
      }
      if (cuts.length > 0) this.applyFractions(fractions);
      return cuts;
    }

    applyFractions(fractions) {
      const texture = new THREE.DataTexture(fractions, 1, this.rows, THREE.RGBAFormat, THREE.FloatType);
      texture.needsUpdate = true;
      this.resample(texture);
      texture.dispose();
    }

    // Shortens guides to new lengths (scene units) where those are shorter —
    // brush tools painting a length. Returns whether any guide would have
    // to grow instead (which needs a rebuild).
    shortenTo(newLengths) {
      if (!this.targets) return false;
      const fractions = new Float32Array(this.rows * 4).fill(1);
      let shortened = false;
      let grows = false;
      for (let row = 0; row < this.rows; row++) {
        const target = newLengths[row];
        if (target < this.lengths[row] * 0.97) {
          fractions[row * 4] = Math.max(2 / (V - 1), target / this.lengths[row]);
          this.lengths[row] *= fractions[row * 4];
          shortened = true;
        } else if (target > this.lengths[row] * 1.05) {
          grows = true;
        }
      }
      if (shortened) this.applyFractions(fractions);
      return grows;
    }

    resample(cutTexture) {
      for (const [name, scratch] of [['state', 'stateScratch'], ['rest', 'restScratch']]) {
        this.runWith(this.passes.resample, { uSource: this.targets[name].texture, uCut: cutTexture }, this.targets[scratch]);
        [this.targets[name], this.targets[scratch]] = [this.targets[scratch], this.targets[name]];
      }
    }

    // --- Rendering -----------------------------------------------------------------

    buildStrandMaterial() {
      const positions = [];
      const indices = [];
      for (let j = 0; j < V; j++) {
        positions.push(-1, j, 0, 1, j, 0);
        if (j < V - 1) indices.push(j * 2, j * 2 + 1, j * 2 + 2, j * 2 + 1, j * 2 + 3, j * 2 + 2);
      }
      const geometry = new THREE.InstancedBufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
      geometry.setIndex(indices);
      geometry.instanceCount = 0;

      this.strandMaterial = new THREE.ShaderMaterial({
        uniforms: {
          ...this.fieldUniforms,
          uPositions: { value: null },
          uBodyRotation: { value: this.body.rotation },
          uCurl: { value: 0 },
          uWidth: { value: 1 },
          uKey: { value: new THREE.Vector3(0.4, 0.6, 0.7).normalize() },
        },
        vertexShader: `
          ${FIELDS_GLSL}
          uniform sampler2D uPositions;
          uniform mat3 uBodyRotation;
          uniform float uCurl, uWidth;
          attribute vec4 aChildA; // guide row, random, tip trim, root u
          attribute vec4 aChildB; // root offset from the guide (body space), root v
          varying vec3 vTangent;
          varying vec3 vWorld;
          varying vec3 vColor;
          varying float vAlong;
          varying float vShade;

          void main() {
            int row = int(aChildA.x);
            float along = position.y / ${(V - 1).toFixed(1)};
            float k = along * aChildA.z * ${(V - 1).toFixed(1)};
            int j0 = min(int(floor(k)), ${V - 2});
            vec3 p0 = texelFetch(uPositions, ivec2(j0, row), 0).xyz;
            vec3 p1 = texelFetch(uPositions, ivec2(j0 + 1, row), 0).xyz;
            vec3 p = mix(p0, p1, k - float(j0));
            vec3 tangent = normalize(p1 - p0 + vec3(0.0, -1e-6, 0.0));

            // Children clump toward their guide along the strand.
            p += uBodyRotation * aChildB.xyz * mix(1.0, 0.35, smoothstep(0.2, 1.0, along));

            if (uCurl > 0.0) {
              vec3 helper = abs(tangent.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
              vec3 b1 = normalize(cross(tangent, helper));
              vec3 b2 = cross(tangent, b1);
              float frequency = mix(22.0, 44.0, uCurl);
              float phase = aChildA.y * 6.2832 + along * frequency;
              float radius = 0.075 * uCurl * smoothstep(0.0, 0.18, along);
              p += radius * (cos(phase) * b1 + sin(phase) * b2);
              tangent = normalize(tangent + radius * frequency * (-sin(phase) * b1 + cos(phase) * b2));
            }

            vec3 side = normalize(cross(tangent, cameraPosition - p));
            p += side * position.x * 0.0085 * uWidth * mix(1.0, 0.25, along);

            vTangent = tangent;
            vWorld = p;
            vColor = hairColor(vec2(aChildA.w, aChildB.w)) * (0.88 + 0.24 * aChildA.y);
            vAlong = along;
            vShade = mix(0.75, 1.0, aChildA.y);
            gl_Position = projectionMatrix * viewMatrix * vec4(p, 1.0);
          }`,
        fragmentShader: `
          ${FIELDS_GLSL}
          uniform vec3 uKey;
          varying vec3 vTangent;
          varying vec3 vWorld;
          varying vec3 vColor;
          varying float vAlong;
          varying float vShade;
          void main() {
            vec3 view = normalize(cameraPosition - vWorld);
            float occlusion = mix(0.35, 1.0, smoothstep(0.0, 0.55, vAlong)) * vShade;
            gl_FragColor = vec4(shadeHair(vColor, normalize(vTangent), view, uKey, occlusion), 1.0 - smoothstep(0.8, 1.0, vAlong));
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
          void main() {
            float height = min(hairLength(uv), ${G.SHELL_MAX_LENGTH.toFixed(3)}) * (aLayer + 1.0) / ${SHELL_LAYERS.toFixed(1)};
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

          // Sine-free hash: fract(sin()) loses precision on cell and pixel
          // coordinates and draws lines across the hair.
          float hash(vec3 p) {
            p = fract(p * 0.1031);
            p += dot(p, p.zyx + 31.32);
            return fract((p.x + p.y) * p.z);
          }

          void main() {
            float capped = min(hairLength(vUv), ${G.SHELL_MAX_LENGTH.toFixed(3)});
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
            // Fewer hairs toward the hairline: a soft edge, not a helmet line.
            if (hash(cell + 9.0) > hairlineDensity * hairlineDensity) discard;
            float hairHeight = capped * (0.7 + 0.3 * hash(cell));
            float layerHeight = capped * (vLayer + 1.0) / ${SHELL_LAYERS.toFixed(1)};
            if (layerHeight > hairHeight) discard;
            // Hairs thin toward the tip; stubble shows skin between hairs.
            float thickness = mix(0.5, 0.18, layerHeight / hairHeight) * mix(0.4, 1.0, smoothstep(0.004, 0.05, capped));
            // Zoomed out, cells shrink below a pixel: keep the share of the
            // cell a hair covers instead of drawing (shimmering) dots.
            float cellsPerPixel = length(fwidth(cellSpace));
            float coverage = clamp(3.14159 * thickness * thickness, 0.0, 1.0);
            float noise = hash(vec3(gl_FragCoord.xy, vLayer));
            bool useCoverage = hash(vec3(gl_FragCoord.yx, vLayer + 11.0)) < smoothstep(0.45, 0.9, cellsPerPixel);
            bool covered = useCoverage ? noise < coverage : length(offset) < thickness;
            // Past stubble, the bottom layer hides the scalp as dense hair does.
            if (vLayer < 0.5) covered = covered || noise < smoothstep(0.02, 0.08, capped);
            if (!covered) discard;

            vec3 view = normalize(cameraPosition - vWorld);
            // Seen edge-on, upper layers thin out so the outline reads as fuzz
            // rather than a stack of slices.
            float facing = abs(dot(normalize(vNormal), view));
            if (vLayer > 0.5 && hash(vec3(gl_FragCoord.xy, vLayer + 23.0)) > smoothstep(0.05, 0.45, facing)) discard;
            // Each hair leans its own way: a shared direction would light the
            // whole cap as one smooth, helmet-like highlight.
            vec3 lean = vec3(hash(cell + 13.0), hash(cell + 17.0), hash(cell + 19.0)) - 0.5;
            vec3 tangent = normalize(vNormal + vec3(0.0, -0.3, 0.0) + lean * 1.6);
            float occlusion = mix(0.35, 1.0, layerHeight / hairHeight);
            vec3 color = hairColor(vUv) * (0.88 + 0.24 * hash(cell + 7.0));
            gl_FragColor = vec4(shadeHair(color, tangent, view, uKey, occlusion), 1.0);
            #include <colorspace_fragment>
          }`,
        side: THREE.DoubleSide,
      });
      this.shellMesh = new THREE.Mesh(geometry, this.shellMaterial);
      this.shellMesh.frustumCulled = false;
      this.bodyGroup.add(this.shellMesh);
    }

    setColor(hex) {
      this.fieldUniforms.uBaseColor.value.set(hex);
    }

    setCurl(curl) {
      this.strandMaterial.uniforms.uCurl.value = curl;
      this.passes.constrain.uniforms.uPuff.value = 0.03 + 0.08 * curl;
    }

    setKeyLight(direction) {
      this.strandMaterial.uniforms.uKey.value.copy(direction);
    }
  }

  HairEngine.FIELDS_GLSL = FIELDS_GLSL;
  window.HairEngine = HairEngine;
})();
