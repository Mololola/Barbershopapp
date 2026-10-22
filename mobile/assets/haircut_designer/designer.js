// The 3D haircut designer: a mannequin head, hair with physics
// (hair_engine.js) built from a design (groom.js), gestures, tools, and the
// bridge to Flutter.
//
// A design: { version, preset, length, volume, hairType, colorHex,
// partOffset, fadeHeight, fadeTo, fadeShape, zones, undercut, hairline,
// faceParams: { skinTone }, colour: { ombre, ombreHex, ombreStart (cm
// from the root) }, strokes: [...] }. See groom.js for what the
// parameters mean (hairType: '1A'..'4C'; zones: the fringe, crown, sides,
// back and nape lengths; fadeTo: the guard a fade finishes at; fadeShape:
// 'classic'|'taper'|'drop'|'burst'; undercut: { on, height, guard };
// hairline: { shape, height, lineUp, sideburns, neckline }); strokes
// are tool applications in scalp UV:
//   clipper / razor   { tool, guard, radius, points: [[u, v], ...] }
//   scissors          { tool, length, radius, points }   brush to a length
//                     (the Length brush: longer or shorter)
//   dye               { tool, colorHex, radius, points }
//   curl              { tool, hairType, radius, points }  another hair type
//   volume            { tool, amount: 1 lift | 0 flatten, radius, points }
//   thin              { tool, amount: share removed 0..1, radius, points }
// A stroke with `mirrored: true` is the mirror image of the one before it;
// undo and redo take the pair together.
//   cut               { tool, radius, points: [[u, v, length], ...] } one
//                     point per strand the scissors cut, at its new length
//
// Bridge (called from Flutter via runJavaScript):
//   loadDesign(json)          the whole design (also converts v1-v3)
//   updateParameters(json)    some or all parameters (sliders)
//   setPreset(id)             a preset with its default parameters
// Both loadDesign and setPreset post the design's parameters (without
// strokes) on "ParametersChannel".
//   setToolMode(json)         { tool: 'look'|'move'|'cut'|'clipper'|'razor'|
//                             'dye'|'curl'|'volume'|'thin'|
//                             'scissors', guard?, colorHex?, hairType?,
//                             amount?, length?, radius?, mirror? }
//   setView(name)             'front'|'left'|'right'|'back'|'top'|'reset'
//   setWind(strength)         0..1
//   shake()
//   undoLastStroke() / redoStroke() / clearStrokes()
//   requestDesignState()      posts the design on "DesignStateChannel"
//   captureSnapshot()         posts a PNG data URL on "SnapshotChannel"
//   enableProfiling()         debug/profile builds: logs where frame time
//                             goes to the console (see `perf` below)
// Whenever the strokes change, { strokes, redo } (counts) is posted on
// "EditChannel", so Flutter knows whether switching cut would throw work
// away and whether there's anything to redo.

(function () {
  const G = window.HairGroom;
  const DESIGN_VERSION = 4;
  const V1_MAX_POLAR = (100 * Math.PI) / 180;
  const DEFAULT_COLOUR = { ombre: false, ombreHex: '#b08350', ombreStart: 6 };

  let renderer, scene, camera, bodyGroup, engine, fields;
  let keyLight;
  const keyDirection = new THREE.Vector3();
  const keyTarget = new THREE.Vector3();
  let design = {
    version: DESIGN_VERSION,
    preset: 'fade',
    ...G.presetDefaults('fade'),
    colorHex: '#3b2314',
    faceParams: { skinTone: '#c68e62' },
    colour: { ...DEFAULT_COLOUR },
    strokes: [],
  };
  let groom = null;
  let toolConfig = { tool: 'look', radius: 0.04 };
  let activeStroke = null;
  let activeMirror = null;
  let activeRasterized = 0;
  let pendingPoints = [];
  let pendingScreenPoints = [];
  let cutTarget = null;
  let lastCutPoint = null;
  let rebuildTimer = null;
  let bodyYaw = 0;
  let bodyPitch = 0;
  let shakeStart = null;
  let lastDisturbance = 0;

  // --- Profiling ----------------------------------------------------------------
  //
  // Off unless Flutter calls enableProfiling() (debug and profile builds),
  // which logs to the console: every frame over 45 ms with where its time
  // went, and a summary every 3 s of drawing. WebGL calls return before the
  // GPU has done the work, so while profiling the render waits for it (a
  // 1-pixel read) to show its real cost, at the price of slightly slower
  // frames. The physics runs in a worker: its time is reported separately.

  const perf = {
    on: false,
    sections: {},
    frameSections: {},
    frameTimes: [],
    lastFrame: 0,
    lastSummary: 0,
    syncBytes: new Uint8Array(4),
    initMs: 0,
    firstFrameMs: 0,
  };

  function timed(name, fn) {
    if (!perf.on) return fn();
    const start = performance.now();
    try {
      return fn();
    } finally {
      const ms = performance.now() - start;
      perf.frameSections[name] = (perf.frameSections[name] || 0) + ms;
    }
  }

  // Waits for the GPU to finish everything queued so far.
  function gpuSync() {
    if (!perf.on) return;
    const gl = renderer.getContext();
    gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, perf.syncBytes);
  }

  function perfEvent(text) {
    if (perf.on) console.log(`[perf] ${text}`);
  }

  function perfFrame(now) {
    if (!perf.on) return;
    const frameMs = perf.lastFrame ? now - perf.lastFrame : 0;
    perf.lastFrame = now;
    const sections = perf.frameSections;
    perf.frameSections = {};
    for (const [name, ms] of Object.entries(sections)) perf.sections[name] = (perf.sections[name] || 0) + ms;
    if (frameMs === 0 || frameMs > 1000) return; // first frame after idle
    perf.frameTimes.push(frameMs);
    const breakdown = () => Object.entries(sections).map(([name, ms]) => `${name} ${ms.toFixed(1)}`).join(', ');
    if (frameMs > 45) perfEvent(`slow frame ${frameMs.toFixed(0)} ms: ${breakdown()}`);
    if (now - perf.lastSummary > 3000 && perf.frameTimes.length > 5) {
      const times = [...perf.frameTimes].sort((a, b) => a - b);
      const at = (q) => times[Math.min(times.length - 1, Math.floor(q * times.length))].toFixed(0);
      const average = Object.entries(perf.sections).map(([name, ms]) => `${name} ${(ms / times.length).toFixed(1)}`).join(', ');
      perfEvent(
        `${times.length} frames, ${(1000 / (times.reduce((a, b) => a + b, 0) / times.length)).toFixed(0)} fps, `
        + `median ${at(0.5)} ms, 95% ${at(0.95)} ms | per frame: ${average} | `
        + `simulator step ${engine.simMs.toFixed(1)} ms | tier ${tier}, strands ${engine.rows}`,
      );
      perf.frameTimes = [];
      perf.sections = {};
      perf.lastSummary = now;
    }
  }

  window.enableProfiling = function () {
    perf.on = true;
    perf.lastSummary = performance.now();
    const gl = renderer.getContext();
    const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
    perfEvent(`profiling on: ${debugInfo ? gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) : 'GPU unknown'}, `
      + `${window.innerWidth}x${window.innerHeight} @${window.devicePixelRatio}, `
      + `physics ${engine.sim.inWorker ? 'in a worker' : 'on the main thread'}; `
      + `startup: scripts ${performance.now().toFixed(0)} ms after page start, init ${perf.initMs.toFixed(0)} ms, `
      + `first frame ${perf.firstFrameMs.toFixed(0)} ms`);
  };

  // --- Quality -----------------------------------------------------------------
  //
  // Starts high and steps down (never up) while frames run below ~38 fps —
  // under that, dragging and painting already feel laggy.
  // guides: simulated strands; strands: drawn ones (maxLayers eighths of
  // them are drawn).
  const TIERS = [
    { pixelRatio: 2, maxLayers: 8, guides: 900, strands: 18000 },
    { pixelRatio: 1.5, maxLayers: 6, guides: 900, strands: 18000 },
    { pixelRatio: 1.25, maxLayers: 5, guides: 700, strands: 14000 },
    { pixelRatio: 1, maxLayers: 4, guides: 500, strands: 10000 },
  ];
  let tier = 0;
  let slowFrames = 0;
  let measuredFrames = 0;
  let lastFrameTime = 0;

  function applyTier(rebuildIfNeeded) {
    const t = TIERS[tier];
    perfEvent(`quality tier ${tier}`);
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
    engine.onChange = (message) => {
      if (message.type === 'groomReady') perfEvent(`groom settled: ${message.settleMs.toFixed(0)} ms in the simulator`);
      requestRender();
    };
    buildHead();
    setupControls();
    fitView();
    orbit.distance = DEFAULT_VIEW.distance;
    updateCamera();
    rebuild();
  }

  // A plain mannequin: the scan's shape in one matte skin tone, with the
  // scalp tinted with the hair colour where hair grows, so gaps between
  // strands read as dense hair. No skin texture: pores, stubble, wrinkles
  // and veins made it read as a particular, real person, which customers
  // found creepy (Oct 2026).
  function buildHead() {
    const mesh = window.HEAD_ASSET.mesh;
    const positions = G.decodeBase64(mesh.positions, Int16Array);
    const normals = G.decodeBase64(mesh.normals, Int8Array);
    const indices = G.decodeBase64(mesh.indices, Uint16Array);
    const position = new Float32Array(mesh.count * 3);
    for (let i = 0; i < mesh.count * 3; i++) {
      position[i] = (positions[i] + 32768) * mesh.positionScale[i % 3] + mesh.positionLow[i % 3];
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(position, 3));
    geometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3, true));
    geometry.setIndex(new THREE.BufferAttribute(indices, 1));

    const material = new THREE.MeshStandardMaterial({ roughness: 0.6, metalness: 0 });
    material.color = skinTone; // the same object, so applyLook's tone change shows
    material.onBeforeCompile = (shader) => {
      Object.assign(shader.uniforms, engine.fieldUniforms, {
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
           uniform vec3 uCranium;
           uniform float uMaxPolar;`,
        )
        .replace(
          '#include <map_fragment>',
          `vec3 direction = normalize(vBodyPosition / uCranium);
           float polar = acos(clamp(direction.y, -1.0, 1.0));
           if (polar < uMaxPolar) {
             float azimuth = atan(direction.z, direction.x);
             if (azimuth < 0.0) azimuth += PI2;
             vec2 scalpUv = vec2(azimuth / PI2, polar / uMaxPolar);
             // Grows with the hair's length, as a fade darkens gradually from
             // the skin up (a tint at any length drew a hard dark band), and
             // with the hairline itself — stopping where the length does
             // would draw a hard, wig-like line round the face.
             float hair = smoothstep(0.0, 0.12, hairLength(scalpUv)) * smoothstep(0.1, 0.9, texture2D(uBaseField, scalpUv).g);
             diffuseColor.rgb = mix(diffuseColor.rgb, hairColor(scalpUv) * 0.75, hair * 0.9);
           }`,
        );
    };
    bodyGroup.add(new THREE.Mesh(geometry, material));
  }

  const skinTone = new THREE.Color('#c68e62');

  // --- Building the hair from the design ------------------------------------------

  // Rebuilds everything from the design: base field, painted fields, guides.
  // Strokes undone, most recent last, for redo. Any new edit clears it.
  let redoStack = [];

  function editsChanged() {
    window.EditChannel?.postMessage(JSON.stringify({ strokes: design.strokes.length, redo: redoStack.length }));
  }

  function addStrokes(...strokes) {
    design.strokes.push(...strokes);
    redoStack = [];
  }

  // Rebuilds everything from the design. The fields update at once; the
  // guides are built in slices across frames (see buildGuides) while the
  // current hair stays on screen, then swapped in.
  let guideBuild = null;
  const BUILD_SLICE_MS = 8;

  function rebuild() {
    clearTimeout(rebuildTimer);
    rebuildTimer = null;
    perfEvent(`rebuild: ${design.preset}, ${design.strokes.length} strokes`);
    timed('computeBase', () => G.computeBase(fields, design.preset, design));
    timed('uploadBase', () => engine.baseFieldChanged());
    timed('repaint', () => G.repaint(fields, design.strokes));
    engine.masksChanged();
    guideBuild = G.buildGuides(fields, design.preset, design, TIERS[tier].guides, TIERS[tier].strands);
    applyLook();
    measuredFrames = 0;
    wake();
  }

  function continueBuild() {
    if (!guideBuild) return;
    const start = performance.now();
    let step;
    timed('buildGuides', () => {
      do step = guideBuild.next();
      while (!step.done && performance.now() - start < BUILD_SLICE_MS);
    });
    if (!step.done) return;
    guideBuild = null;
    groom = step.value;
    timed('setGroom', () => engine.setGroom(groom));
    perfEvent(`groom built: ${groom.rows} strands`);
    applyLook();
  }

  // Sliders move often: the shells follow as the slider moves (at most every
  // 90 ms — recomputing the field on every event lags the slider), the
  // strands rebuild when it rests.
  let lastBaseUpdate = 0;
  let baseTimer = null;
  function scheduleRebuild() {
    clearTimeout(rebuildTimer);
    rebuildTimer = setTimeout(rebuild, 180);
    if (baseTimer) return;
    const wait = Math.max(0, 90 - (performance.now() - lastBaseUpdate));
    baseTimer = setTimeout(() => {
      baseTimer = null;
      lastBaseUpdate = performance.now();
      timed('computeBase', () => G.computeBase(fields, design.preset, design));
      timed('uploadBase', () => engine.baseFieldChanged());
      requestRender();
    }, wait);
  }

  function applyLook() {
    engine.setColor(design.colorHex, design.colour);
    engine.setHairType(design.hairType);
    engine.setLayers(Math.round(Math.min(8, Math.max(1, design.volume * 5))));
    skinTone.set(design.faceParams.skinTone);
    requestRender();
  }

  // --- Painting tools -----------------------------------------------------------

  const raycaster = new THREE.Raycaster();
  const pointerNDC = new THREE.Vector2();
  const bodyInverse = new THREE.Matrix4();

  // Scalp UV under a screen point, or null off the scalp.
  function raycastToUV(clientX, clientY) {
    pointerNDC.x = (clientX / window.innerWidth) * 2 - 1;
    pointerNDC.y = -(clientY / window.innerHeight) * 2 + 1;
    raycaster.setFromCamera(pointerNDC, camera);
    bodyInverse.copy(bodyGroup.matrix).invert();
    const ray = raycaster.ray.applyMatrix4(bodyInverse);
    return G.pickScalp(ray.origin, ray.direction.normalize());
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
    if (toolConfig.tool === 'curl') stroke.hairType = toolConfig.hairType || design.hairType;
    if (toolConfig.tool === 'volume' || toolConfig.tool === 'thin') stroke.amount = toolConfig.amount ?? 1;
    if (toolConfig.tool === 'scissors') stroke.length = toolConfig.length ?? design.length;
    activeStroke = stroke;
    activeMirror = toolConfig.mirror ? { ...stroke, points: [], mirrored: true } : null;
    activeRasterized = 0;
    pendingPoints = [uv];
    pendingScreenPoints = [];
  }

  // Points gathered since the last frame go onto the stroke once per frame
  // (pointer events can arrive far faster than frames).
  function flushBrush() {
    if (!activeStroke) return;
    // Finger positions since the last frame: resolve at most four, evenly
    // spread, always including the latest.
    const screen = pendingScreenPoints;
    pendingScreenPoints = [];
    const count = Math.min(4, screen.length);
    for (let i = 1; i <= count; i++) {
      const point = screen[Math.round((i / count) * (screen.length - 1))];
      const uv = raycastToUV(point.x, point.y);
      if (uv) pendingPoints.push(uv);
    }
    if (pendingPoints.length === 0) return;
    activeStroke.points.push(...pendingPoints);
    G.paintStroke(fields, activeStroke, activeRasterized);
    if (activeMirror) {
      activeMirror.points.push(...pendingPoints.map(mirrored));
      G.paintStroke(fields, activeMirror, activeRasterized);
    }
    activeRasterized = activeStroke.points.length;
    pendingPoints = [];
    engine.masksChanged();
    // Volume shows while the finger is still down.
    if (RESTYLES.includes(activeStroke.tool) && performance.now() - lastRestyle > RESTYLE_EVERY_MS) restyleStrokes();
  }

  const RESTYLES = ['volume'];
  const RESTYLE_EVERY_MS = 150;
  let lastRestyle = 0;

  // Reshapes the guides the active stroke (and its mirror) pass over.
  function restyleStrokes() {
    lastRestyle = performance.now();
    // A build in progress read the fields before this stroke: start again.
    if (guideBuild || !groom || groom.rows === 0) {
      rebuild();
      return;
    }
    timed('restyle', () => {
      for (const stroke of [activeStroke, activeMirror]) {
        if (!stroke || stroke.points.length === 0) continue;
        const { rows, rest } = G.restyleGuides(fields, design.preset, design, groom, strokeRegion(stroke));
        engine.restyle(rows, rest);
      }
    });
    wake();
  }

  // A stroke's extent in scalp UV, padded by its radius (u0 > u1 when it
  // crosses the seam at the back of the head).
  function strokeRegion(stroke) {
    const us = stroke.points.map(([u]) => u);
    const vs = stroke.points.map(([, v]) => v);
    const r = stroke.radius;
    const region = { v0: Math.min(...vs) - 2 * r, v1: Math.max(...vs) + 2 * r };
    if (Math.max(...us) - Math.min(...us) <= 0.5) {
      return { ...region, u0: Math.max(0, Math.min(...us) - r), u1: Math.min(1, Math.max(...us) + r) };
    }
    return { ...region, u0: Math.min(...us.filter((u) => u > 0.5)) - r, u1: Math.max(...us.filter((u) => u <= 0.5)) + r };
  }

  function endBrush() {
    timed('endStroke', endBrushNow);
  }

  function endBrushNow() {
    flushBrush();
    if (activeStroke && activeStroke.points.length > 0) {
      addStrokes(activeStroke, ...(activeMirror ? [activeMirror] : []));
      // A hair type changes how the hair is laid out: the groom rebuilds.
      // Volume reshapes just the guides it touches; thinning
      // and dye are drawn straight from their fields. Length brushes
      // shorten in place if they can.
      if (activeStroke.tool === 'curl') rebuild();
      else if (RESTYLES.includes(activeStroke.tool)) restyleStrokes();
      else if (!['dye', 'thin'].includes(activeStroke.tool)) applyLengthsToStrands();
      editsChanged();
    }
    activeStroke = activeMirror = null;
  }

  // After a clipper/razor stroke: strands under it take the painted length.
  // Shortening happens in place; anything that would need to grow rebuilds.
  function applyLengthsToStrands() {
    // A build in progress read the fields before this stroke: start again.
    if (guideBuild || !groom || groom.rows === 0) {
      rebuild(); // a longer guard over bare/short hair can create strands
      return;
    }
    const lengthAt = G.visibleLengthSampler(fields, design);
    const targets = new Float32Array(groom.rows);
    for (let row = 0; row < groom.rows; row++) {
      targets[row] = G.guideLengthAt(lengthAt, groom.neighbourhood, groom.roots[row * 2], groom.roots[row * 2 + 1]);
    }
    if (engine.shortenTo(targets)) rebuild();
    wake();
  }

  // Scissors: cut strands along the swipe; each cut strand is recorded as a
  // point on a 'cut' stroke so the design rebuilds the cut later.
  function startCut(point) {
    activeStroke = { tool: 'cut', radius: groom ? groom.cutRadius : 0.004, points: [] };
    lastCutPoint = point;
    cutTarget = null;
    engine.beginSwipe();
  }

  // The swipe since the last frame, as one segment.
  function flushCut() {
    if (!activeStroke || activeStroke.tool !== 'cut' || !cutTarget) return;
    engine.cutAlong(lastCutPoint, cutTarget, camera, { width: window.innerWidth, height: window.innerHeight });
    lastCutPoint = cutTarget;
    cutTarget = null;
  }

  function endCut() {
    flushCut();
    const stroke = activeStroke;
    const cutGroom = groom;
    activeStroke = null;
    lastCutPoint = null;
    engine.endSwipe((cuts) => {
      if (groom !== cutGroom) return; // the hair was rebuilt meanwhile
      for (const { row, length } of cuts) {
        stroke.points.push([groom.roots[row * 2], groom.roots[row * 2 + 1], length / G.LENGTH_TO_SCENE]);
      }
      if (stroke.points.length === 0) return;
      addStrokes(stroke);
      G.paintStroke(fields, stroke);
      engine.masksChanged();
      editsChanged();
      if (guideBuild) rebuild(); // it read the fields before this cut
      requestRender();
    });
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
    return ['clipper', 'razor', 'dye', 'curl', 'volume', 'thin', 'scissors'].includes(tool);
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
        pinch = pinchState();
        return;
      }
      if (pointers.size > 2) return;
      if (isBrush(toolConfig.tool)) startBrush(event.clientX, event.clientY);
      if (toolConfig.tool === 'cut') startCut({ x: event.clientX, y: event.clientY });
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
        pendingScreenPoints.push({ x: event.clientX, y: event.clientY });
        return;
      }
      if (activeStroke && activeStroke.tool === 'cut') {
        cutTarget = { x: event.clientX, y: event.clientY };
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

    timed('brush', flushBrush);
    timed('cut', flushCut);
    continueBuild();
    engine.wind = wind;
    timed('physics', () => engine.step(now));
    const settling = engine.settling;
    // Toward the light, from where it points (its target). Not the light's
    // getWorldDirection(): that's its own +z, which pointed the hair
    // shaders' light into the scene and left surfaces facing the camera dark.
    keyDirection.setFromMatrixPosition(keyLight.matrixWorld)
      .sub(keyTarget.setFromMatrixPosition(keyLight.target.matrixWorld))
      .normalize();
    engine.setKeyLight(keyDirection);
    timed('render', () => {
      renderer.render(scene, camera);
      gpuSync();
    });
    perfFrame(now);

    if (!settling) adaptQuality(now);
    else lastFrameTime = 0;

    const physicsActive = engine.rows > 0 && (wind > 0 || shakeStart !== null || settling || now - lastDisturbance < 3000);
    if (animating || physicsActive || pointers.size > 0 || guideBuild) {
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
    slowFrames = frameTime > 26 ? slowFrames + 1 : Math.max(0, slowFrames - 1);
    if (slowFrames > 18 && tier < TIERS.length - 1) {
      const guidesBefore = TIERS[tier].guides;
      tier++;
      slowFrames = 0;
      applyTier(TIERS[tier].guides !== guidesBefore);
    }
  }

  // --- Flutter bridge ---------------------------------------------------------------

  function parse(json) {
    return typeof json === 'string' ? JSON.parse(json) : json;
  }

  // Designs before v4 had one 'curl' slider, 0..1, instead of a hair type.
  // Must match HairParameters.hairTypeFromCurl in Dart.
  function hairTypeFromCurl(curl) {
    if (curl < 0.15) return '1B';
    if (curl < 0.45) return '2B';
    if (curl < 0.8) return '3B';
    return '4A';
  }

  // v1 mapped polar 0..100° onto v; v2 and later use 0..130°. v1 and v2
  // designs had no presets: their parameters are the 'custom' preset. v1-v3
  // had a curl amount, v4 a hair type.
  function upgrade(loaded) {
    const version = loaded.version ?? 1;
    const strokes = Array.isArray(loaded.strokes) ? loaded.strokes : [];
    const { curl, ...rest } = loaded;
    const preset = version < 3 ? 'custom' : loaded.preset ?? 'custom';
    // Barber details a design doesn't have yet come from its own cut, never
    // from whatever was on screen before.
    const defaults = G.presetDefaults(preset);
    return {
      ...design,
      ...rest,
      hairType: version < 4 ? hairTypeFromCurl(curl ?? 0) : loaded.hairType ?? design.hairType,
      zones: loaded.zones ?? G.zonesFor(preset, loaded.length ?? defaults.length),
      fadeTo: loaded.fadeTo ?? defaults.fadeTo,
      fadeShape: loaded.fadeShape ?? defaults.fadeShape,
      undercut: loaded.undercut ?? defaults.undercut,
      hairline: loaded.hairline ?? defaults.hairline,
      version: DESIGN_VERSION,
      preset,
      faceParams: { ...design.faceParams, ...(loaded.faceParams || {}) },
      // Never the colour on screen before: a design without one has none.
      colour: { ...DEFAULT_COLOUR, ...(loaded.colour || {}) },
      strokes: version < 2
        ? strokes.map((s) => ({ ...s, points: s.points.map(([u, v]) => [u, (v * V1_MAX_POLAR) / G.MAX_POLAR]) }))
        : strokes,
    };
  }

  window.loadDesign = function (json) {
    try {
      design = upgrade(parse(json));
      redoStack = [];
      rebuild();
      editsChanged();
      postParameters(); // with the details upgrade() filled in
    } catch (error) {
      console.error('loadDesign failed', error);
    }
  };

  window.updateParameters = function (json) {
    try {
      const update = parse(json);
      const { strokes, preset, version, ...parameters } = update;
      const lookOnly = Object.keys(parameters).every((k) => ['colorHex', 'faceParams', 'colour', 'volume'].includes(k));
      design = {
        ...design,
        ...parameters,
        faceParams: { ...design.faceParams, ...(parameters.faceParams || {}) },
        colour: { ...design.colour, ...(parameters.colour || {}) },
      };
      applyLook();
      if (!lookOnly) scheduleRebuild();
    } catch (error) {
      console.error('updateParameters failed', error);
    }
  };

  window.setPreset = function (id) {
    if (!G.PRESETS[id]) return;
    perfEvent(`preset ${id}`);
    design = { ...design, preset: id, ...G.presetDefaults(id), strokes: [] };
    redoStack = [];
    rebuild();
    editsChanged();
    postParameters();
  };

  function postParameters() {
    const { strokes, ...parameters } = design;
    window.ParametersChannel?.postMessage(JSON.stringify(parameters));
  }

  window.setToolMode = function (json) {
    try {
      toolConfig = parse(json);
      perfEvent(`tool ${toolConfig.tool}`);
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

  // The last edit: one stroke, or a stroke and its mirror image.
  function takeLastEdit(from) {
    const last = from.pop();
    return last.mirrored && from.length > 0 ? [from.pop(), last] : [last];
  }

  window.undoLastStroke = function () {
    if (design.strokes.length === 0) return;
    redoStack.push(...takeLastEdit(design.strokes));
    rebuild();
    editsChanged();
  };

  window.redoStroke = function () {
    if (redoStack.length === 0) return;
    design.strokes.push(...takeLastEdit(redoStack));
    rebuild();
    editsChanged();
  };

  window.clearStrokes = function () {
    design.strokes = [];
    redoStack = [];
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

  const initStart = performance.now();
  init();
  perf.initMs = performance.now() - initStart;
  requestAnimationFrame(() => {
    const start = performance.now();
    requestAnimationFrame(() => (perf.firstFrameMs = performance.now() - start));
  });
})();
