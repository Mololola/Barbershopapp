// Procedural hair designer scene — stylized, not photoreal. No external 3D
// model files are used (avoids sourcing/licensing third-party assets); the
// head, face, and hair are all built entirely from primitive geometry driven
// by the parameters and freehand strokes Flutter sends in.
//
// Bridge (called from Flutter via runJavaScript):
//   updateParameters(jsonString) — base style: { length, volume, curl,
//     colorHex, partOffset, fadeHeight, faceParams: { skinTone } }
//   loadStrokes(jsonString) — replaces the whole freehand stroke list (used
//     once when opening an existing design).
//   setToolMode(jsonString) — { tool: 'rotate'|'clipper'|'scissors'|'razor'|
//     'dye', guard?, length?, colorHex?, radius }. Anything other than
//     'rotate' turns pointer drags into paint strokes instead of orbiting.
//   undoLastStroke() / clearStrokes() — pop/clear freehand strokes.
//   requestDesignState() — posts the full { ...base style, strokes } JSON to
//     the "DesignStateChannel" JavaScriptChannel (mirrors captureSnapshot's
//     SnapshotChannel — runJavaScript can't return values reliably).
//   captureSnapshot() — renders one frame and posts a PNG data URL to the
//     "SnapshotChannel" JavaScriptChannel.

let scene, camera, renderer, headGroup, headMesh, headMaterial, hairMesh;
let eyebrowMaterials = [];

const DEFAULT_PARAMS = {
  length: 8, // 0 (shaved) .. 20 (long), arbitrary scene units
  volume: 1, // 0.2 (sparse) .. 2 (very thick)
  curl: 0, // 0 (straight) .. 1 (tight curl)
  colorHex: '#3b2314',
  partOffset: 0, // -1 (left) .. 1 (right), 0 = no part
  fadeHeight: 0.3, // 0 (no fade, even length) .. 1 (high, tight fade)
  faceParams: { skinTone: '#e0ac69' },
};

let currentParams = { ...DEFAULT_PARAMS };

// Freehand clipper/scissors/razor/dye strokes painted onto the scalp. Each:
// { tool, guard?, length?, colorHex?, radius, points: [[u, v], ...] }.
let strokes = [];
let activeStroke = null;
let pendingRaycastPoints = [];
let hairDirty = false;

// The tool currently selected in Flutter's tool bar. tool: 'rotate' means
// pointer drags orbit the camera (the original/default behavior); anything
// else paints a stroke instead.
let toolConfig = { tool: 'rotate', radius: 0.03 };

// Matches the head mesh's SphereGeometry(1,...).scale(x,y,z) in init() —
// used to place hair roots on the actual head surface, not the underlying
// unit sphere.
const HEAD_SCALE = new THREE.Vector3(0.85, 1, 0.9);
const GRAVITY = new THREE.Vector3(0, -1, 0);

const MAX_POLAR = (100 * Math.PI) / 180; // from the top pole, in radians — the scalp's polar extent

// The default camera sits on +Z looking at the origin (see updateCamera with
// yaw=0), so azimuth = π/2 (see scalpFollicles' x/z formula) is "the front
// of the head" — that's where the face and the hairline exclusion live.
const FACE_CENTER_AZIMUTH = Math.PI / 2;
const FACE_HALF_WIDTH = (60 * Math.PI) / 180;
const FACE_HAIRLINE_CENTER_POLAR = (38 * Math.PI) / 180; // forehead center — hairline sits high
const FACE_HAIRLINE_TEMPLE_POLAR = (75 * Math.PI) / 180; // near the temples — hairline dips lower

// Guard #0 (skin) .. #8, arbitrary scene-unit steps loosely mimicking real
// clipper guard increments. Razor strokes always use guard 0 (skin/liner).
const CLIPPER_GUARD_LENGTHS = [0, 1, 2, 3, 4, 5, 6, 8, 10];

// Pointer-drag-to-rotate + wheel-to-zoom — hand-rolled since the classic
// (non-module) three.min.js build doesn't include the OrbitControls addon.
let orbitYaw = 0;
let orbitPitch = 0.15;
let orbitDistance = 6;
let dragging = false;
let lastPointer = { x: 0, y: 0 };

// Offscreen 2D canvases (not WebGL) holding the painted length/color masks,
// in the same (azimuth, polar) UV space scalpFollicles works in: u = azimuth
// / 2π, v = polar / MAX_POLAR. Alpha=0 means "unpainted, use the base style
// formula"; alpha>0 means a stroke painted here. lengthMask encodes an
// absolute length (0..20) as grayscale; colorMask encodes an actual dye
// color as RGB.
const MASK_WIDTH = 512;
const MASK_HEIGHT = 256;
let lengthMaskCanvas, lengthMaskCtx, colorMaskCanvas, colorMaskCtx;
let lengthMaskData, colorMaskData;

function init() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x1a1a1a);

  camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 100);

  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(window.devicePixelRatio || 1);
  renderer.domElement.setAttribute('id', 'scene-canvas');
  document.body.appendChild(renderer.domElement);

  scene.add(new THREE.AmbientLight(0xffffff, 0.6));
  const keyLight = new THREE.DirectionalLight(0xffffff, 0.9);
  keyLight.position.set(3, 5, 4);
  scene.add(keyLight);
  const fillLight = new THREE.DirectionalLight(0xffffff, 0.3);
  fillLight.position.set(-4, 1, -2);
  scene.add(fillLight);

  headGroup = new THREE.Group();
  scene.add(headGroup);

  const headGeometry = new THREE.SphereGeometry(1, 32, 32);
  headGeometry.scale(HEAD_SCALE.x, HEAD_SCALE.y, HEAD_SCALE.z);
  headMaterial = new THREE.MeshStandardMaterial({ color: currentParams.faceParams.skinTone, roughness: 0.85 });
  headMesh = new THREE.Mesh(headGeometry, headMaterial);
  headGroup.add(headMesh);

  const neckGeometry = new THREE.CylinderGeometry(0.35, 0.4, 0.6, 16);
  const neckMesh = new THREE.Mesh(neckGeometry, headMaterial);
  neckMesh.position.set(0, -1.15, 0);
  headGroup.add(neckMesh);

  buildFace();

  lengthMaskCanvas = document.createElement('canvas');
  lengthMaskCanvas.width = MASK_WIDTH;
  lengthMaskCanvas.height = MASK_HEIGHT;
  lengthMaskCtx = lengthMaskCanvas.getContext('2d');
  colorMaskCanvas = document.createElement('canvas');
  colorMaskCanvas.width = MASK_WIDTH;
  colorMaskCanvas.height = MASK_HEIGHT;
  colorMaskCtx = colorMaskCanvas.getContext('2d');
  refreshMaskData();

  rebuildHair(currentParams);
  setupControls();
  updateCamera();
  animate();
}

// Stylized facial features built from primitive geometry — eyes, brows,
// nose, mouth, ears — all parented to headGroup in the same coordinate
// space scalpFollicles' HEAD_SCALE-projected surface points live in, so
// "front of head" (azimuth = FACE_CENTER_AZIMUTH) lines up with the face.
function buildFace() {
  const eyeWhiteMaterial = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.4 });
  const pupilMaterial = new THREE.MeshStandardMaterial({ color: 0x2a1a12, roughness: 0.3 });
  const mouthMaterial = new THREE.MeshStandardMaterial({ color: 0x7a4a45, roughness: 0.6 });

  const eyeWhiteGeometry = new THREE.SphereGeometry(0.085, 12, 12);
  const pupilGeometry = new THREE.SphereGeometry(0.04, 10, 10);
  const browGeometry = new THREE.BoxGeometry(0.16, 0.03, 0.03);
  const noseGeometry = new THREE.SphereGeometry(0.09, 10, 10);
  const mouthGeometry = new THREE.BoxGeometry(0.2, 0.035, 0.02);
  const earGeometry = new THREE.SphereGeometry(0.13, 10, 10);

  for (const side of [-1, 1]) {
    const eyeWhite = new THREE.Mesh(eyeWhiteGeometry, eyeWhiteMaterial);
    eyeWhite.position.set(side * 0.3, 0.08, 0.78);
    eyeWhite.scale.set(1, 0.85, 0.7);
    headGroup.add(eyeWhite);

    const pupil = new THREE.Mesh(pupilGeometry, pupilMaterial);
    pupil.position.set(side * 0.3, 0.08, 0.84);
    headGroup.add(pupil);

    // Brows track the base hair color (see rebuildHair) rather than a fixed
    // shade, matching how eyebrows usually read the same tone as the hair.
    const browMaterial = new THREE.MeshStandardMaterial({ color: currentParams.colorHex, roughness: 0.7 });
    const brow = new THREE.Mesh(browGeometry, browMaterial);
    brow.position.set(side * 0.3, 0.21, 0.76);
    brow.rotation.z = side * 0.12;
    headGroup.add(brow);
    eyebrowMaterials.push(browMaterial);

    const ear = new THREE.Mesh(earGeometry, headMaterial);
    ear.position.set(side * 0.87, -0.02, 0);
    ear.scale.set(0.35, 0.65, 0.4);
    headGroup.add(ear);
  }

  const nose = new THREE.Mesh(noseGeometry, headMaterial);
  nose.position.set(0, -0.08, 0.86);
  nose.scale.set(0.7, 0.85, 0.9);
  headGroup.add(nose);

  const mouth = new THREE.Mesh(mouthGeometry, mouthMaterial);
  mouth.position.set(0, -0.34, 0.82);
  headGroup.add(mouth);
}

/// Follicle points over the scalp cap (top/sides/back), evenly spread via a
/// Fibonacci-sphere sampling restricted to the polar angle range that
/// covers hair-bearing scalp. Face exclusion (so hair doesn't grow through
/// the eyes/nose/mouth) is applied later, in rebuildHair, via
/// scalpMultiplier — not here — for the same reason partSuppression and
/// fadeMultiplier are also applied there: it's a multiplicative style
/// factor, not a change to which points exist.
function scalpFollicles(count) {
  const points = [];
  const goldenAngle = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0; i < count; i++) {
    const t = i / Math.max(1, count - 1);
    const polar = t * MAX_POLAR;
    const azimuth = i * goldenAngle;
    const x = Math.sin(polar) * Math.cos(azimuth);
    const z = Math.sin(polar) * Math.sin(azimuth);
    const y = Math.cos(polar);
    points.push({ direction: new THREE.Vector3(x, y, z), polar, azimuth });
  }
  return points;
}

// 0 near the front-center of the face (suppress hair), 1 well clear of it
// (normal scalp). The hairline arcs higher at the center-forehead and dips
// lower near the temples, matching a natural hairline shape.
function scalpMultiplier(azimuth, polar) {
  let delta = Math.abs((azimuth % (2 * Math.PI)) - FACE_CENTER_AZIMUTH);
  if (delta > Math.PI) delta = 2 * Math.PI - delta;
  const t = smoothstep(0, FACE_HALF_WIDTH, delta);
  const hairlinePolar = FACE_HAIRLINE_CENTER_POLAR + (FACE_HAIRLINE_TEMPLE_POLAR - FACE_HAIRLINE_CENTER_POLAR) * t;
  // Above the hairline (smaller polar, toward the crown) hair is allowed;
  // below it (larger polar, into the forehead/face) it's suppressed.
  const verticalFactor = 1 - smoothstep(hairlinePolar - 0.14, hairlinePolar + 0.14, polar);
  const horizontalFactor = smoothstep(FACE_HALF_WIDTH - 0.25, FACE_HALF_WIDTH + 0.1, delta);
  return Math.max(verticalFactor, horizontalFactor);
}

function sampleMask(data, width, height, u, v) {
  const x = Math.min(width - 1, Math.max(0, Math.floor(u * width)));
  const y = Math.min(height - 1, Math.max(0, Math.floor(v * height)));
  const idx = (y * width + x) * 4;
  return { r: data[idx], g: data[idx + 1], b: data[idx + 2], a: data[idx + 3] };
}

function refreshMaskData() {
  lengthMaskData = lengthMaskCtx.getImageData(0, 0, MASK_WIDTH, MASK_HEIGHT).data;
  colorMaskData = colorMaskCtx.getImageData(0, 0, MASK_WIDTH, MASK_HEIGHT).data;
}

function strokeLength(stroke) {
  if (stroke.tool === 'clipper' || stroke.tool === 'razor') {
    return CLIPPER_GUARD_LENGTHS[stroke.guard ?? 0];
  }
  if (stroke.tool === 'scissors') {
    return stroke.length ?? 0;
  }
  return null; // dye doesn't touch length
}

// Draws (or re-draws) one stroke's full polyline into whichever mask(s) its
// tool affects. Safe to call repeatedly on a growing stroke — opaque paint
// over already-painted pixels is a no-op, so re-rasterizing the whole path
// each time a point is added is simpler than trying to append incrementally.
// Each pass draws three copies offset by -width/0/+width so strokes that
// cross the azimuth 0/2π seam wrap around correctly.
function rasterizeStroke(stroke) {
  if (stroke.points.length === 0) return;
  const pixelRadius = Math.max(1, stroke.radius * MASK_WIDTH);

  const drawPass = (ctx, style) => {
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.lineWidth = pixelRadius * 2;
    ctx.strokeStyle = style;
    ctx.fillStyle = style;
    for (const offsetX of [-MASK_WIDTH, 0, MASK_WIDTH]) {
      ctx.beginPath();
      stroke.points.forEach(([u, v], i) => {
        const x = u * MASK_WIDTH + offsetX;
        const y = v * MASK_HEIGHT;
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      });
      ctx.stroke();
      // Round caps at every vertex so a single tap (one point, no line) and
      // sharp turns still show up as a filled circle, not just line joins.
      stroke.points.forEach(([u, v]) => {
        ctx.beginPath();
        ctx.arc(u * MASK_WIDTH + offsetX, v * MASK_HEIGHT, pixelRadius, 0, Math.PI * 2);
        ctx.fill();
      });
    }
  };

  const lengthValue = strokeLength(stroke);
  if (lengthValue !== null) {
    const gray = Math.round((Math.max(0, Math.min(20, lengthValue)) / 20) * 255);
    drawPass(lengthMaskCtx, `rgba(${gray}, ${gray}, ${gray}, 1)`);
  }
  if (stroke.tool === 'dye') {
    drawPass(colorMaskCtx, stroke.colorHex || '#000000');
  }
}

function rebuildMasksFromStrokes() {
  lengthMaskCtx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
  colorMaskCtx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
  for (const stroke of strokes) rasterizeStroke(stroke);
  refreshMaskData();
}

function rebuildHair(params) {
  for (const mat of eyebrowMaterials) mat.color.set(params.colorHex);

  if (hairMesh) {
    headGroup.remove(hairMesh);
    hairMesh.geometry.dispose();
    hairMesh.material.dispose();
    hairMesh = null;
  }

  const lengthUnits = Math.max(0, params.length) * 0.05; // scene-unit scale
  const baseColor = new THREE.Color(params.colorHex);

  const baseCount = 900;
  const follicleCount = Math.round(baseCount * Math.max(0.1, params.volume));
  const follicles = scalpFollicles(follicleCount);

  // Segment resolution scales with the longest hair anywhere on the head —
  // not just the base style — so a bald base style with a deliberately
  // long painted region still gets enough segments to bend/drape properly.
  const maxPaintedLength =
    strokes.reduce((max, s) => {
      const len = strokeLength(s);
      return len !== null ? Math.max(max, len) : max;
    }, 0) * 0.05;
  const segmentCount = Math.max(2, Math.min(8, Math.round(Math.max(lengthUnits, maxPaintedLength) / 0.12)));
  const segmentGeometry = new THREE.CylinderGeometry(0.012, 0.016, 1, 5);
  segmentGeometry.translate(0, 0.5, 0); // pivot at the base, extends toward +Y locally

  const instances = follicles.length * segmentCount;
  // Base material color stays white — per-strand color comes entirely from
  // instanceColor (painted dye or the base colorHex), set per-follicle below.
  hairMesh = new THREE.InstancedMesh(
    segmentGeometry,
    new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.6 }),
    instances,
  );

  const matrix = new THREE.Matrix4();
  const quaternion = new THREE.Quaternion();
  const scale = new THREE.Vector3();
  const up = new THREE.Vector3(0, 1, 0);
  let instanceIndex = 0;

  for (const follicle of follicles) {
    let azNorm = follicle.azimuth % (2 * Math.PI);
    if (azNorm < 0) azNorm += 2 * Math.PI;
    const u = azNorm / (2 * Math.PI);
    const v = Math.min(1, follicle.polar / MAX_POLAR);

    const scalpFactor = scalpMultiplier(follicle.azimuth, follicle.polar);
    const lengthPixel = sampleMask(lengthMaskData, MASK_WIDTH, MASK_HEIGHT, u, v);
    const colorPixel = sampleMask(colorMaskData, MASK_WIDTH, MASK_HEIGHT, u, v);

    let strandLength;
    if (lengthPixel.a > 0) {
      // A painted stroke is a deliberate design choice — it overrides the
      // ambient part/fade curve entirely (but still respects the face
      // exclusion, so a stray stroke can't grow hair through the eyes).
      const paintedLength = (lengthPixel.r / 255) * 20;
      strandLength = paintedLength * 0.05 * scalpFactor;
    } else {
      // Part line: a narrow angular band around the chosen meridian pushes
      // strands nearly flat instead of growing them, creating a visible gap.
      const partMeridian = params.partOffset * Math.PI;
      let angularDelta = Math.abs(follicle.azimuth - partMeridian) % (2 * Math.PI);
      if (angularDelta > Math.PI) angularDelta = 2 * Math.PI - angularDelta;
      const partSuppression = params.partOffset === 0 ? 1 : smoothstep(0.12, 0.35, angularDelta);

      // Fade: hair near the sides/back (higher polar angle) shortens as
      // fadeHeight increases, mimicking a tapered/fade haircut.
      const fadeStart = (35 * Math.PI) / 180;
      const fadeAmount = smoothstep(fadeStart, (100 * Math.PI) / 180, follicle.polar);
      const fadeMultiplier = 1 - fadeAmount * params.fadeHeight;

      strandLength = lengthUnits * partSuppression * Math.max(0.05, fadeMultiplier) * scalpFactor;
    }

    if (strandLength <= 0.02) {
      instanceIndex += segmentCount;
      continue;
    }

    const effectiveColor =
      colorPixel.a > 0 ? new THREE.Color(colorPixel.r / 255, colorPixel.g / 255, colorPixel.b / 255) : baseColor;

    // Roots sit on the actual (non-uniformly scaled) head surface, not the
    // underlying unit sphere — otherwise strands on the sides float
    // slightly outside the visible head.
    const segmentLength = strandLength / segmentCount;
    let origin = follicle.direction.clone().multiply(HEAD_SCALE);
    let direction = follicle.direction.clone().normalize();
    const strandSeed = follicle.azimuth * 12.9898 + follicle.polar * 78.233;

    for (let s = 0; s < segmentCount; s++) {
      quaternion.setFromUnitVectors(up, direction);
      scale.set(1, segmentLength, 1);
      matrix.compose(origin, quaternion, scale);
      hairMesh.setMatrixAt(instanceIndex, matrix);
      hairMesh.setColorAt(instanceIndex, effectiveColor);
      instanceIndex++;

      const nextOrigin = origin.clone().add(direction.clone().multiplyScalar(segmentLength));
      const curlAngle = params.curl * 0.6 * Math.sin(s * 1.7 + strandSeed);
      direction.applyAxisAngle(new THREE.Vector3(1, 0, 0), curlAngle);
      direction.applyAxisAngle(new THREE.Vector3(0, 0, 1), curlAngle * 0.7);
      // Gravity: without this, strands just keep growing straight out from
      // the scalp normal and the whole head reads as a pom-pom/sea-urchin
      // instead of hair. Blending toward "down" each segment makes longer
      // hair arc over and hang, like it's actually draping under its own
      // weight, while short hair (few segments) barely bends at all.
      direction.lerp(GRAVITY, 0.2).normalize();
      origin = nextOrigin;
    }
  }

  // Unused instances (suppressed by the part line, face, or a painted
  // shave) still need a definite (zero-scale) transform, otherwise they
  // render as garbage matrices.
  const zeroMatrix = new THREE.Matrix4().makeScale(0, 0, 0);
  for (let i = instanceIndex; i < instances; i++) {
    hairMesh.setMatrixAt(i, zeroMatrix);
  }

  hairMesh.instanceMatrix.needsUpdate = true;
  if (hairMesh.instanceColor) hairMesh.instanceColor.needsUpdate = true;
  headGroup.add(hairMesh);
}

function smoothstep(edge0, edge1, x) {
  const t = Math.min(1, Math.max(0, (x - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

// Casts the given screen point into the head mesh and returns the hit in
// the same (u, v) UV space the masks and scalpFollicles use, or null if the
// ray misses the head entirely.
const raycaster = new THREE.Raycaster();
const pointerNDC = new THREE.Vector2();
function raycastToUV(clientX, clientY) {
  const rect = renderer.domElement.getBoundingClientRect();
  pointerNDC.x = ((clientX - rect.left) / rect.width) * 2 - 1;
  pointerNDC.y = -((clientY - rect.top) / rect.height) * 2 + 1;
  raycaster.setFromCamera(pointerNDC, camera);
  const hits = raycaster.intersectObject(headMesh, false);
  if (hits.length === 0) return null;
  // headGroup sits at the origin with no rotation, so the hit point's local
  // and world coordinates are the same.
  const direction = hits[0].point.clone().divide(HEAD_SCALE).normalize();
  const polar = Math.acos(Math.min(1, Math.max(-1, direction.y)));
  let azimuth = Math.atan2(direction.z, direction.x);
  if (azimuth < 0) azimuth += 2 * Math.PI;
  return { u: azimuth / (2 * Math.PI), v: Math.min(1, polar / MAX_POLAR) };
}

function setupControls() {
  const el = renderer.domElement;
  el.addEventListener('pointerdown', (event) => {
    if (toolConfig.tool && toolConfig.tool !== 'rotate') {
      const uv = raycastToUV(event.clientX, event.clientY);
      if (!uv) return;
      activeStroke = {
        tool: toolConfig.tool,
        guard: toolConfig.guard,
        length: toolConfig.length,
        colorHex: toolConfig.colorHex,
        radius: toolConfig.radius ?? 0.03,
        points: [],
      };
      pendingRaycastPoints = [[uv.u, uv.v]];
      return;
    }
    dragging = true;
    lastPointer = { x: event.clientX, y: event.clientY };
  });
  window.addEventListener('pointerup', () => {
    dragging = false;
    if (activeStroke) {
      flushPendingStrokePoints();
      if (activeStroke.points.length > 0) strokes.push(activeStroke);
      activeStroke = null;
    }
  });
  window.addEventListener('pointermove', (event) => {
    if (activeStroke) {
      const uv = raycastToUV(event.clientX, event.clientY);
      if (uv) pendingRaycastPoints.push([uv.u, uv.v]);
      return;
    }
    if (!dragging) return;
    const dx = event.clientX - lastPointer.x;
    const dy = event.clientY - lastPointer.y;
    lastPointer = { x: event.clientX, y: event.clientY };
    orbitYaw -= dx * 0.008;
    orbitPitch = Math.min(1.3, Math.max(-1.3, orbitPitch - dy * 0.008));
    updateCamera();
  });
  el.addEventListener(
    'wheel',
    (event) => {
      event.preventDefault();
      orbitDistance = Math.min(12, Math.max(2.5, orbitDistance + event.deltaY * 0.003));
      updateCamera();
    },
    { passive: false },
  );
  window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  });
}

// Applies any points collected since the last animation frame to the active
// stroke and re-rasterizes it. Batched to at most once per frame (called
// from animate() and on pointerup) rather than once per pointermove event,
// since raw pointer event rates can far exceed 60/s and each rasterize does
// a full mask getImageData.
function flushPendingStrokePoints() {
  if (!activeStroke || pendingRaycastPoints.length === 0) return;
  activeStroke.points.push(...pendingRaycastPoints);
  pendingRaycastPoints = [];
  rasterizeStroke(activeStroke);
  refreshMaskData();
  hairDirty = true;
}

function updateCamera() {
  const x = orbitDistance * Math.cos(orbitPitch) * Math.sin(orbitYaw);
  const y = orbitDistance * Math.sin(orbitPitch);
  const z = orbitDistance * Math.cos(orbitPitch) * Math.cos(orbitYaw);
  camera.position.set(x, y, z);
  camera.lookAt(0, 0, 0);
}

function animate() {
  requestAnimationFrame(animate);
  flushPendingStrokePoints();
  if (hairDirty) {
    rebuildHair(currentParams);
    hairDirty = false;
  }
  renderer.render(scene, camera);
}

// --- Flutter bridge -------------------------------------------------------

window.updateParameters = function (jsonString) {
  try {
    const parsed = JSON.parse(jsonString);
    currentParams = {
      ...DEFAULT_PARAMS,
      ...parsed,
      faceParams: { ...DEFAULT_PARAMS.faceParams, ...(parsed.faceParams || {}) },
    };
    headMaterial.color.set(currentParams.faceParams.skinTone);
    rebuildHair(currentParams);
  } catch (error) {
    console.error('updateParameters failed', error);
  }
};

window.loadStrokes = function (jsonString) {
  try {
    const parsed = JSON.parse(jsonString);
    strokes = Array.isArray(parsed) ? parsed : [];
    rebuildMasksFromStrokes();
    rebuildHair(currentParams);
  } catch (error) {
    console.error('loadStrokes failed', error);
  }
};

window.setToolMode = function (jsonString) {
  try {
    toolConfig = JSON.parse(jsonString);
  } catch (error) {
    console.error('setToolMode failed', error);
  }
};

window.undoLastStroke = function () {
  strokes.pop();
  rebuildMasksFromStrokes();
  rebuildHair(currentParams);
};

window.clearStrokes = function () {
  strokes = [];
  rebuildMasksFromStrokes();
  rebuildHair(currentParams);
};

window.requestDesignState = function () {
  const state = { ...currentParams, strokes };
  if (window.DesignStateChannel) {
    window.DesignStateChannel.postMessage(JSON.stringify(state));
  }
};

window.captureSnapshot = function () {
  renderer.render(scene, camera);
  const dataUrl = renderer.domElement.toDataURL('image/png');
  if (window.SnapshotChannel) {
    window.SnapshotChannel.postMessage(dataUrl);
  }
  return dataUrl;
};

init();
