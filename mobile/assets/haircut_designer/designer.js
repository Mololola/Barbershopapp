// The 3D haircut designer: a realistic head (scan), hair with physics
// (hair_engine.js) built from a design (groom.js), gestures, tools, and the
// bridge to Flutter.
//
// A design: { version, preset, length, volume, curl, colorHex, partOffset,
// fadeHeight, faceParams: { skinTone }, strokes: [...] }. See groom.js for
// what the parameters mean; strokes are tool applications in scalp UV:
//   clipper / razor   { tool, guard, radius, points: [[u, v], ...] }
//   scissors (v1/v2)  { tool, length, radius, points }   brush to a length
//   dye               { tool, colorHex, radius, points }
//   cut               { tool, radius, points: [[u, v, length], ...] } one
//                     point per strand the scissors cut, at its new length
//
// Bridge (called from Flutter via runJavaScript):
//   loadDesign(json)          the whole design (also converts v1/v2)
//   updateParameters(json)    some or all parameters (sliders)
//   setPreset(id)             a preset with its default parameters; posts
//                             the new parameters on "ParametersChannel"
//   setToolMode(json)         { tool: 'look'|'move'|'cut'|'clipper'|'razor'|
//                             'dye', guard?, colorHex?, radius?, mirror? }
//   setView(name)             'front'|'left'|'right'|'back'|'top'|'reset'
//   setWind(strength)         0..1
//   shake()
//   undoLastStroke() / clearStrokes()
//   requestDesignState()      posts the design on "DesignStateChannel"
//   captureSnapshot()         posts a PNG data URL on "SnapshotChannel"
// Whenever the number of strokes changes it is posted on "EditChannel", so
// Flutter knows whether switching cut would throw work away.

(function () {
  const G = window.HairGroom;
  const DESIGN_VERSION = 3;
  const V1_MAX_POLAR = (100 * Math.PI) / 180;

  let renderer, scene, camera, bodyGroup, headMesh, engine, fields;
  let keyLight;
  let design = {
    version: DESIGN_VERSION,
    preset: 'fade',
    ...G.presetDefaults('fade'),
    colorHex: '#3b2314',
    faceParams: { skinTone: '#c68e62' },
    strokes: [],
  };
  let groom = null;
  let toolConfig = { tool: 'look', radius: 0.04 };
  let activeStroke = null;
  let activeMirror = null;
  let activeRasterized = 0;
  let pendingPoints = [];
  let lastCutPoint = null;
  let cutThisSwipe = new Set();
  let rebuildTimer = null;
  let bodyYaw = 0;
  let bodyPitch = 0;
  let shakeStart = null;
  let lastDisturbance = 0;

  // --- Quality -----------------------------------------------------------------
  //
  // Starts high and steps down (never up) while frames run below ~27 fps.
  const TIERS = [
    { pixelRatio: 2, maxLayers: 8, budget: 3000 },
    { pixelRatio: 1.5, maxLayers: 6, budget: 3000 },
    { pixelRatio: 1.25, maxLayers: 5, budget: 2200 },
    { pixelRatio: 1, maxLayers: 4, budget: 1500 },
  ];
  let tier = 0;
  let slowFrames = 0;
  let measuredFrames = 0;
  let lastFrameTime = 0;

  function applyTier(rebuildIfNeeded) {
    const t = TIERS[tier];
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, t.pixelRatio));
    renderer.setSize(window.innerWidth, window.innerHeight);
    engine.setMaxLayers(t.maxLayers);
    if (rebuildIfNeeded) rebuild();
  }

  // --- Scene --------------------------------------------------------------------

  function init() {
    renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
    if (!renderer.capabilities.isWebGL2) {
      document.body.textContent = 'This phone does not support WebGL2, which the designer needs.';
      return;
    }
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, TIERS[0].pixelRatio));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.domElement.id = 'scene-canvas';
    document.body.appendChild(renderer.domElement);

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x1b1714);
    camera = new THREE.PerspectiveCamera(32, window.innerWidth / window.innerHeight, 0.05, 100);
    scene.add(camera);
    scene.add(new THREE.HemisphereLight(0xf4eee6, 0x2a221c, 1.0));
    // Lights ride with the camera so the side being looked at is lit.
    keyLight = new THREE.DirectionalLight(0xffffff, 2.0);
    keyLight.position.set(2.5, 3, 4);
    camera.add(keyLight);
    keyLight.target.position.set(0, 0, -1);
    camera.add(keyLight.target);
    const rim = new THREE.DirectionalLight(0xffe2c0, 1.2);
    rim.position.set(-3, 2, -4);
    camera.add(rim);
    rim.target.position.set(0, 0, -1);
    camera.add(rim.target);

    bodyGroup = new THREE.Group();
    bodyGroup.matrixAutoUpdate = false;
    scene.add(bodyGroup);

    fields = G.createFields();
    engine = new HairEngine(renderer, scene, bodyGroup, fields);
    buildHead();
    setupControls();
    fitView();
    orbit.distance = DEFAULT_VIEW.distance;
    updateCamera();
    rebuild();
  }

  // The scan, with its skin tinted toward the design's skin tone and the
  // scalp tinted with the hair colour where hair grows, so gaps between
  // strands read as dense hair.
  function buildHead() {
    const mesh = window.HEAD_ASSET.mesh;
    const positions = G.decodeBase64(mesh.positions, Int16Array);
    const normals = G.decodeBase64(mesh.normals, Int8Array);
    const uvs = G.decodeBase64(mesh.uvs, Uint16Array);
    const indices = G.decodeBase64(mesh.indices, Uint16Array);
    const position = new Float32Array(mesh.count * 3);
    for (let i = 0; i < mesh.count * 3; i++) {
      position[i] = (positions[i] + 32768) * mesh.positionScale[i % 3] + mesh.positionLow[i % 3];
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(position, 3));
    geometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3, true));
    geometry.setAttribute('uv', new THREE.BufferAttribute(uvs, 2, true));
    geometry.setIndex(new THREE.BufferAttribute(indices, 1));

    const loader = new THREE.TextureLoader();
    const map = loader.load(window.HEAD_ASSET.colorMap, (texture) => {
      scanAverage.value.copy(averageColor(texture.image));
      requestRender();
    });
    map.flipY = false;
    map.colorSpace = THREE.SRGBColorSpace;
    const normalMap = loader.load(window.HEAD_ASSET.normalMap, requestRender);
    normalMap.flipY = false;

    // A softened scan: the skin's fine detail (pores, blemishes, the red
    // of the lips) is blurred away and its colour evened out, so the head
    // reads as a neutral model, not a particular person.
    const material = new THREE.MeshStandardMaterial({ map, normalMap, roughness: 0.72, metalness: 0 });
    material.normalScale.set(0.45, 0.45);
    material.onBeforeCompile = (shader) => {
      Object.assign(shader.uniforms, engine.fieldUniforms, {
        uSkinTone: skinToneUniform,
        uScanAverage: scanAverage,
        uCranium: { value: G.CRANIUM },
        uMaxPolar: { value: G.MAX_POLAR },
      });
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', '#include <common>\nvarying vec3 vBodyPosition;')
        .replace('#include <begin_vertex>', '#include <begin_vertex>\nvBodyPosition = position;');
      shader.fragmentShader = shader.fragmentShader
        .replace(
          '#include <common>',
          `#include <common>
           ${HairEngine.FIELDS_GLSL}
           varying vec3 vBodyPosition;
           uniform vec3 uSkinTone, uScanAverage, uCranium;
           uniform float uMaxPolar;`,
        )
        .replace(
          '#include <map_fragment>',
          `// A blurred read of the scan (a low mip level): its shading and
           // broad tone, without fine detail.
           diffuseColor *= texture2D(map, vMapUv, 3.5);
           // Skin tone: the scan's variation moved to the chosen tone, then
           // mostly evened out to that tone's hue.
           vec3 toned = clamp(diffuseColor.rgb * uSkinTone / uScanAverage, 0.0, 1.0);
           float shade = dot(toned, vec3(0.2126, 0.7152, 0.0722)) / max(dot(uSkinTone, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
           diffuseColor.rgb = mix(toned, uSkinTone * shade, 0.75);
           vec3 direction = normalize(vBodyPosition / uCranium);
           float polar = acos(clamp(direction.y, -1.0, 1.0));
           if (polar < uMaxPolar) {
             float azimuth = atan(direction.z, direction.x);
             if (azimuth < 0.0) azimuth += PI2;
             vec2 scalpUv = vec2(azimuth / PI2, polar / uMaxPolar);
             // Fades in with the hairline itself — stopping where the length
             // does would draw a hard, wig-like line round the face.
             float hair = smoothstep(0.0, 0.03, hairLength(scalpUv)) * smoothstep(0.1, 0.9, texture2D(uBaseField, scalpUv).g);
             diffuseColor.rgb = mix(diffuseColor.rgb, hairColor(scalpUv) * 0.5, hair * 0.9);
           }`,
        );
    };
    headMesh = new THREE.Mesh(geometry, material);
    bodyGroup.add(headMesh);
  }

  const skinToneUniform = { value: new THREE.Color('#c68e62') };
  const scanAverage = { value: new THREE.Color(0.5, 0.35, 0.28) };

  // The scan texture's average colour (linear), so a chosen skin tone can
  // replace it while keeping the skin's detail.
  function averageColor(image) {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 32;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(image, 0, 0, 32, 32);
    const data = ctx.getImageData(0, 0, 32, 32).data;
    const sum = [0, 0, 0];
    for (let i = 0; i < data.length; i += 4) for (let c = 0; c < 3; c++) sum[c] += data[i + c];
    const n = data.length / 4;
    return new THREE.Color().setRGB(sum[0] / n / 255, sum[1] / n / 255, sum[2] / n / 255, THREE.SRGBColorSpace);
  }

  // --- Building the hair from the design ------------------------------------------

  // Rebuilds everything from the design: base field, painted fields, guides.
  function editsChanged() {
    window.EditChannel?.postMessage(String(design.strokes.length));
  }

  function rebuild() {
    clearTimeout(rebuildTimer);
    rebuildTimer = null;
    G.computeBase(fields, design.preset, design);
    engine.baseFieldChanged();
    G.repaint(fields, design.strokes);
    engine.masksChanged();
    groom = G.buildGuides(fields, design.preset, design, TIERS[tier].budget);
    engine.setGroom(groom);
    applyLook();
    measuredFrames = 0;
    wake();
  }

  // Sliders move often: the shells follow at once, the strands rebuild when
  // the slider rests.
  function scheduleRebuild() {
    G.computeBase(fields, design.preset, design);
    engine.baseFieldChanged();
    clearTimeout(rebuildTimer);
    rebuildTimer = setTimeout(rebuild, 180);
    requestRender();
  }

  function applyLook() {
    engine.setColor(design.colorHex);
    engine.setCurl(design.curl);
    engine.setLayers(Math.round(Math.min(8, Math.max(1, design.volume * 5))));
    skinToneUniform.value.set(design.faceParams.skinTone);
    requestRender();
  }

  // --- Painting tools -----------------------------------------------------------

  const raycaster = new THREE.Raycaster();
  const pointerNDC = new THREE.Vector2();

  // Scalp UV under a screen point, or null off the head.
  function raycastToUV(clientX, clientY) {
    pointerNDC.x = (clientX / window.innerWidth) * 2 - 1;
    pointerNDC.y = -(clientY / window.innerHeight) * 2 + 1;
    raycaster.setFromCamera(pointerNDC, camera);
    const hits = raycaster.intersectObject(headMesh, false);
    if (hits.length === 0) return null;
    const local = bodyGroup.worldToLocal(hits[0].point.clone());
    const { u, v } = G.uvOf(local);
    return v <= 1 ? [u, v] : null;
  }

  // The same point on the other side of the head (x mirrored).
  function mirrored([u, v]) {
    return [(1.5 - u) % 1, v];
  }

  function startBrush(clientX, clientY) {
    const uv = raycastToUV(clientX, clientY);
    if (!uv) return;
    const stroke = { tool: toolConfig.tool, radius: toolConfig.radius ?? 0.03, points: [] };
    if (toolConfig.tool === 'clipper') stroke.guard = toolConfig.guard ?? 2;
    if (toolConfig.tool === 'razor') stroke.guard = 0;
    if (toolConfig.tool === 'dye') stroke.colorHex = toolConfig.colorHex || '#000000';
    activeStroke = stroke;
    activeMirror = toolConfig.mirror ? { ...stroke, points: [] } : null;
    activeRasterized = 0;
    pendingPoints = [uv];
  }

  // Points gathered since the last frame go onto the stroke once per frame
  // (pointer events can arrive far faster than frames).
  function flushBrush() {
    if (!activeStroke || pendingPoints.length === 0) return;
    activeStroke.points.push(...pendingPoints);
    G.paintStroke(fields, activeStroke, activeRasterized);
    if (activeMirror) {
      activeMirror.points.push(...pendingPoints.map(mirrored));
      G.paintStroke(fields, activeMirror, activeRasterized);
    }
    activeRasterized = activeStroke.points.length;
    pendingPoints = [];
    engine.masksChanged();
  }

  function endBrush() {
    flushBrush();
    if (activeStroke && activeStroke.points.length > 0) {
      design.strokes.push(activeStroke);
      if (activeMirror) design.strokes.push(activeMirror);
      if (activeStroke.tool !== 'dye') applyLengthsToStrands();
      editsChanged();
    }
    activeStroke = activeMirror = null;
  }

  // After a clipper/razor stroke: strands under it take the painted length.
  // Shortening happens in place; anything that would need to grow rebuilds.
  function applyLengthsToStrands() {
    if (!groom || groom.rows === 0) {
      rebuild(); // a longer guard over bare/short hair can create strands
      return;
    }
    const lengthAt = G.lengthSampler(fields);
    const targets = new Float32Array(groom.rows);
    for (let row = 0; row < groom.rows; row++) targets[row] = lengthAt(groom.roots[row * 2], groom.roots[row * 2 + 1]);
    if (engine.shortenTo(targets)) rebuild();
    wake();
  }

  // Scissors: cut strands along the swipe; each cut strand is recorded as a
  // point on a 'cut' stroke so the design rebuilds the cut later.
  function cutTo(point) {
    if (!activeStroke) {
      activeStroke = { tool: 'cut', radius: groom.cutRadius, points: [] };
      cutThisSwipe = new Set();
    }
    const viewport = { width: window.innerWidth, height: window.innerHeight };
    const cuts = engine.cutAlong(lastCutPoint, point, camera, viewport, cutThisSwipe);
    lastCutPoint = point;
    if (cuts.length === 0) return;
    const from = activeStroke.points.length;
    for (const { row, length } of cuts) {
      activeStroke.points.push([groom.roots[row * 2], groom.roots[row * 2 + 1], length / G.LENGTH_TO_SCENE]);
    }
    G.paintStroke(fields, activeStroke, from);
    engine.masksChanged();
  }

  function endCut() {
    if (activeStroke && activeStroke.points.length > 0) {
      design.strokes.push(activeStroke);
      editsChanged();
    }
    activeStroke = null;
    lastCutPoint = null;
  }

  // --- Gestures -----------------------------------------------------------------
  //
  // One finger: orbit (look), turn the bust (move), or use the tool. Two
  // fingers: pinch to zoom and drag to pan, whatever the tool — a second
  // finger mid-stroke drops that stroke. Double tap resets the view.

  const MIN_DISTANCE = 1.8;
  let maxDistance = 12;
  const DEFAULT_VIEW = { yaw: 0.35, pitch: 0.12, distance: 7.2, target: new THREE.Vector3(0, -0.5, 0) };

  // Distance at which head and shoulders fill the view, whatever the
  // screen's shape (a tall phone needs more distance than a wide one).
  function fitDistance() {
    const halfTan = Math.tan((camera.fov * Math.PI) / 360);
    return Math.max(1.7 / halfTan, 1.45 / (halfTan * camera.aspect)) * 1.04;
  }

  function fitView() {
    DEFAULT_VIEW.distance = fitDistance();
    maxDistance = DEFAULT_VIEW.distance * 1.6;
  }
  const PRESET_VIEWS = {
    front: { yaw: 0, pitch: 0.08 },
    left: { yaw: -Math.PI / 2, pitch: 0.08 },
    right: { yaw: Math.PI / 2, pitch: 0.08 },
    back: { yaw: Math.PI, pitch: 0.08 },
    top: { yaw: 0, pitch: 1.3 },
  };
  const orbit = {
    yaw: DEFAULT_VIEW.yaw,
    pitch: DEFAULT_VIEW.pitch,
    distance: DEFAULT_VIEW.distance,
    target: DEFAULT_VIEW.target.clone(),
    yawVelocity: 0,
    pitchVelocity: 0,
  };
  let cameraTween = null;
  const pointers = new Map();
  let pinch = null;
  let lastTap = { time: 0, x: 0, y: 0 };
  let lastMoveTime = 0;

  function isBrush(tool) {
    return tool === 'clipper' || tool === 'razor' || tool === 'dye';
  }

  function setupControls() {
    const el = renderer.domElement;
    el.addEventListener('pointerdown', (event) => {
      try {
        el.setPointerCapture(event.pointerId);
      } catch (_) {
        // Synthetic events (tests) have no capturable pointer.
      }
      pointers.set(event.pointerId, { x: event.clientX, y: event.clientY, downX: event.clientX, downY: event.clientY });
      cameraTween = null;
      orbit.yawVelocity = orbit.pitchVelocity = 0;
      wake();

      if (pointers.size === 2) {
        // The first finger was the start of a pinch, not a stroke.
        if (activeStroke && isBrush(activeStroke.tool)) {
          activeStroke = activeMirror = null;
          G.repaint(fields, design.strokes);
          engine.masksChanged();
        } else if (activeStroke) {
          endCut();
        }
        lastCutPoint = null;
        pinch = pinchState();
        return;
      }
      if (pointers.size > 2) return;
      if (isBrush(toolConfig.tool)) startBrush(event.clientX, event.clientY);
      if (toolConfig.tool === 'cut') lastCutPoint = { x: event.clientX, y: event.clientY };
    });

    el.addEventListener('pointermove', (event) => {
      const pointer = pointers.get(event.pointerId);
      if (!pointer) return;
      const dx = event.clientX - pointer.x;
      const dy = event.clientY - pointer.y;
      pointer.x = event.clientX;
      pointer.y = event.clientY;
      wake();

      if (pointers.size === 2 && pinch) {
        const next = pinchState();
        orbit.distance = clamp(orbit.distance * (pinch.distance / next.distance), MIN_DISTANCE, maxDistance);
        pan(next.midX - pinch.midX, next.midY - pinch.midY);
        pinch = next;
        updateCamera();
        return;
      }
      if (pointers.size !== 1) return;

      if (activeStroke && isBrush(activeStroke.tool)) {
        const uv = raycastToUV(event.clientX, event.clientY);
        if (uv) pendingPoints.push(uv);
        return;
      }
      if (toolConfig.tool === 'cut' && lastCutPoint) {
        cutTo({ x: event.clientX, y: event.clientY });
        return;
      }
      if (isBrush(toolConfig.tool)) return; // the stroke started off the head
      if (toolConfig.tool === 'move') {
        bodyYaw = clamp(bodyYaw + dx * 0.006, -1.2, 1.2);
        bodyPitch = clamp(bodyPitch + dy * 0.004, -0.35, 0.35);
        updateBody();
        return;
      }
      const now = performance.now();
      const elapsed = Math.max(1, now - lastMoveTime);
      lastMoveTime = now;
      const yawStep = -dx * 0.008;
      const pitchStep = dy * 0.008;
      orbit.yaw += yawStep;
      orbit.pitch = clamp(orbit.pitch + pitchStep, -0.9, 1.4);
      orbit.yawVelocity = (yawStep / elapsed) * 16; // radians per 16 ms frame, for the fling
      orbit.pitchVelocity = (pitchStep / elapsed) * 16;
      updateCamera();
    });

    const release = (event) => {
      const pointer = pointers.get(event.pointerId);
      if (!pointer) return;
      pointers.delete(event.pointerId);
      if (pointers.size < 2) pinch = null;
      wake();
      if (activeStroke && isBrush(activeStroke.tool)) {
        endBrush();
        return;
      }
      if (activeStroke && activeStroke.tool === 'cut') {
        endCut();
        return;
      }
      lastCutPoint = null;
      // A fling keeps spinning only if the finger was still moving at release.
      if (performance.now() - lastMoveTime > 80) orbit.yawVelocity = orbit.pitchVelocity = 0;
      const moved = Math.hypot(event.clientX - pointer.downX, event.clientY - pointer.downY);
      if (moved < 10 && pointers.size === 0) {
        const now = performance.now();
        if (now - lastTap.time < 300 && Math.hypot(event.clientX - lastTap.x, event.clientY - lastTap.y) < 30) {
          window.setView('reset');
          lastTap.time = 0;
        } else {
          lastTap = { time: now, x: event.clientX, y: event.clientY };
        }
      }
    };
    el.addEventListener('pointerup', release);
    el.addEventListener('pointercancel', release);

    el.addEventListener('wheel', (event) => {
      event.preventDefault();
      orbit.distance = clamp(orbit.distance * Math.exp(event.deltaY * 0.001), MIN_DISTANCE, maxDistance);
      updateCamera();
      wake();
    }, { passive: false });
    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
      fitView();
      orbit.distance = Math.min(orbit.distance, maxDistance);
      updateCamera();
      requestRender();
    });
  }

  function pinchState() {
    const [a, b] = [...pointers.values()];
    return { distance: Math.max(1, Math.hypot(a.x - b.x, a.y - b.y)), midX: (a.x + b.x) / 2, midY: (a.y + b.y) / 2 };
  }

  // Moves the orbit target with the fingers, at the scale of the view.
  function pan(dx, dy) {
    const worldPerPixel = (2 * orbit.distance * Math.tan((camera.fov * Math.PI) / 360)) / window.innerHeight;
    const right = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0);
    const up = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 1);
    orbit.target.addScaledVector(right, -dx * worldPerPixel).addScaledVector(up, dy * worldPerPixel);
    orbit.target.clamp(new THREE.Vector3(-1.5, -2.5, -1.5), new THREE.Vector3(1.5, 1.5, 1.5));
  }

  function updateCamera() {
    camera.position.set(
      orbit.distance * Math.cos(orbit.pitch) * Math.sin(orbit.yaw),
      orbit.distance * Math.sin(orbit.pitch),
      orbit.distance * Math.cos(orbit.pitch) * Math.cos(orbit.yaw),
    ).add(orbit.target);
    camera.lookAt(orbit.target);
    camera.updateMatrixWorld();
  }

  // Turns the whole bust about the neck (it's one scanned mesh).
  function updateBody() {
    const pivot = new THREE.Vector3().fromArray(G.collision.neck.center);
    bodyGroup.matrix.makeTranslation(pivot.x, pivot.y, pivot.z)
      .multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(bodyPitch, bodyYaw, 0, 'YXZ')))
      .multiply(new THREE.Matrix4().makeTranslation(-pivot.x, -pivot.y, -pivot.z));
    bodyGroup.matrixWorldNeedsUpdate = true;
    engine.updateBody();
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  // --- Frame loop -------------------------------------------------------------------
  //
  // Draws only while something moves: touch, wind, a shake, a camera
  // animation, hair still settling — and for a few seconds after, while the
  // hair swings back. An idle designer costs no battery.

  let running = false;
  let wind = 0;

  function wake() {
    lastDisturbance = performance.now();
    requestRender();
  }

  function requestRender() {
    if (running || !renderer) return;
    running = true;
    requestAnimationFrame(frame);
  }

  function frame(now) {
    let animating = false;
    if (cameraTween) {
      const t = Math.min(1, (now - cameraTween.start) / cameraTween.duration);
      const eased = 1 - Math.pow(1 - t, 3);
      orbit.yaw = lerp(cameraTween.from.yaw, cameraTween.to.yaw, eased);
      orbit.pitch = lerp(cameraTween.from.pitch, cameraTween.to.pitch, eased);
      orbit.distance = lerp(cameraTween.from.distance, cameraTween.to.distance, eased);
      orbit.target.lerpVectors(cameraTween.from.target, cameraTween.to.target, eased);
      if (t >= 1) cameraTween = null;
      updateCamera();
      animating = true;
    } else if (pointers.size === 0 && (Math.abs(orbit.yawVelocity) > 0.0005 || Math.abs(orbit.pitchVelocity) > 0.0005)) {
      orbit.yaw += orbit.yawVelocity;
      orbit.pitch = clamp(orbit.pitch + orbit.pitchVelocity, -0.9, 1.4);
      orbit.yawVelocity *= 0.92;
      orbit.pitchVelocity *= 0.92;
      updateCamera();
      animating = true;
    }
    if (shakeStart !== null) {
      const t = (now - shakeStart) / 1000;
      bodyYaw = 0.4 * Math.sin(t * Math.PI * 2 * 1.6) * Math.exp(-t * 1.4);
      if (t > 2.2) {
        shakeStart = null;
        bodyYaw = 0;
      }
      updateBody();
      lastDisturbance = now;
    }

    flushBrush();
    engine.wind = wind;
    const settling = engine.step();
    const key = keyLight.getWorldDirection(new THREE.Vector3()).negate();
    engine.setKeyLight(key);
    renderer.render(scene, camera);

    if (!settling) adaptQuality(now);
    else lastFrameTime = 0;

    const physicsActive = engine.rows > 0 && (wind > 0 || shakeStart !== null || settling || now - lastDisturbance < 3000);
    if (animating || physicsActive || pointers.size > 0) {
      requestAnimationFrame(frame);
    } else {
      running = false;
      lastFrameTime = 0;
    }
  }

  function adaptQuality(now) {
    const frameTime = lastFrameTime ? now - lastFrameTime : 0;
    lastFrameTime = now;
    if (frameTime === 0 || frameTime > 200) return; // not back-to-back frames
    measuredFrames++;
    slowFrames = frameTime > 37 ? slowFrames + 1 : Math.max(0, slowFrames - 1);
    if (slowFrames > 25 && tier < TIERS.length - 1) {
      const budgetBefore = TIERS[tier].budget;
      tier++;
      slowFrames = 0;
      applyTier(TIERS[tier].budget !== budgetBefore);
    }
  }

  // --- Flutter bridge ---------------------------------------------------------------

  function parse(json) {
    return typeof json === 'string' ? JSON.parse(json) : json;
  }

  // v1 mapped polar 0..100° onto v; v2 and later use 0..130°. v1 and v2
  // designs had no presets: their parameters are the 'custom' preset.
  function upgrade(loaded) {
    const version = loaded.version ?? 1;
    const strokes = Array.isArray(loaded.strokes) ? loaded.strokes : [];
    return {
      ...design,
      ...loaded,
      version: DESIGN_VERSION,
      preset: version < 3 ? 'custom' : loaded.preset ?? 'custom',
      faceParams: { ...design.faceParams, ...(loaded.faceParams || {}) },
      strokes: version < 2
        ? strokes.map((s) => ({ ...s, points: s.points.map(([u, v]) => [u, (v * V1_MAX_POLAR) / G.MAX_POLAR]) }))
        : strokes,
    };
  }

  window.loadDesign = function (json) {
    try {
      design = upgrade(parse(json));
      rebuild();
      editsChanged();
    } catch (error) {
      console.error('loadDesign failed', error);
    }
  };

  window.updateParameters = function (json) {
    try {
      const update = parse(json);
      const { strokes, preset, version, ...parameters } = update;
      const lookOnly = Object.keys(parameters).every((k) => ['colorHex', 'faceParams', 'volume', 'curl'].includes(k));
      design = { ...design, ...parameters, faceParams: { ...design.faceParams, ...(parameters.faceParams || {}) } };
      applyLook();
      if (!lookOnly || 'curl' in parameters) scheduleRebuild();
    } catch (error) {
      console.error('updateParameters failed', error);
    }
  };

  window.setPreset = function (id) {
    if (!G.PRESETS[id]) return;
    design = { ...design, preset: id, ...G.presetDefaults(id), strokes: [] };
    rebuild();
    editsChanged();
    const { strokes, ...parameters } = design;
    window.ParametersChannel?.postMessage(JSON.stringify(parameters));
  };

  window.setToolMode = function (json) {
    try {
      toolConfig = parse(json);
    } catch (error) {
      console.error('setToolMode failed', error);
    }
  };

  window.setView = function (name) {
    const preset = name === 'reset' ? DEFAULT_VIEW : PRESET_VIEWS[name];
    if (!preset) return;
    const turn = Math.atan2(Math.sin(preset.yaw - orbit.yaw), Math.cos(preset.yaw - orbit.yaw));
    cameraTween = {
      start: performance.now(),
      duration: 450,
      from: { yaw: orbit.yaw, pitch: orbit.pitch, distance: orbit.distance, target: orbit.target.clone() },
      to: {
        yaw: orbit.yaw + turn,
        pitch: preset.pitch,
        distance: preset.distance ?? orbit.distance,
        target: preset.target ? preset.target.clone() : orbit.target.clone(),
      },
    };
    orbit.yawVelocity = orbit.pitchVelocity = 0;
    requestRender();
  };

  window.setWind = function (strength) {
    wind = Math.max(0, Math.min(1, Number(strength) || 0));
    wake();
  };

  window.shake = function () {
    shakeStart = performance.now();
    wake();
  };

  window.undoLastStroke = function () {
    if (design.strokes.length === 0) return;
    design.strokes.pop();
    rebuild();
    editsChanged();
  };

  window.clearStrokes = function () {
    design.strokes = [];
    rebuild();
    editsChanged();
  };

  window.requestDesignState = function () {
    window.DesignStateChannel?.postMessage(JSON.stringify(design));
  };

  window.captureSnapshot = function () {
    renderer.render(scene, camera);
    const dataUrl = renderer.domElement.toDataURL('image/png');
    window.SnapshotChannel?.postMessage(dataUrl);
    return dataUrl;
  };

  init();
})();
