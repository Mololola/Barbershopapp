// Procedural hair designer scene — polished stylized, not photoreal. No
// external 3D model files (avoids sourcing/licensing third-party assets);
// the head, face and hair are built from primitive geometry.
//
// How the hair works: everything about it is a *field* over the scalp,
// indexed by scalp UV (u = azimuth / 2π, v = polar / MAX_POLAR) — the base
// style (length, fade, part, face exclusion) is a formula of those, and
// freehand strokes are painted into 2D canvases in the same UV space. The
// GPU reads the fields directly: strands and short-hair shells are shaped
// in the vertex/fragment shaders, so changing a slider or painting a
// stroke only updates a uniform or re-uploads a texture — no geometry is
// ever rebuilt on the CPU. Two layers:
//   - shells: stacked offset copies of the scalp, cut into tiny hairs in
//     the fragment shader (the classic fur technique). They draw everything
//     up to SHELL_MAX_LENGTH, which is what buzz cuts, fades and razor lines
//     need, and act as a dense undercoat beneath longer hair.
//   - strands: camera-facing ribbons for anything longer, bent by gravity,
//     kept outside the head, combed away from the crown and the part, and
//     curled into a helix.
// Frames are only rendered when something changes (render on demand).
//
// Bridge (called from Flutter via runJavaScript):
//   updateParameters(jsonString) — base style: { length, volume, curl,
//     colorHex, partOffset, fadeHeight, faceParams: { skinTone } }
//   loadStrokes(jsonString) — replaces the whole freehand stroke list (used
//     once when opening an existing design).
//   setToolMode(jsonString) — { tool: 'rotate'|'clipper'|'scissors'|'razor'|
//     'dye', guard?, length?, colorHex?, radius }. Anything other than
//     'rotate' turns one-finger drags into paint strokes; two fingers
//     always zoom/pan.
//   setView(name) — 'front' | 'left' | 'right' | 'back' | 'top' | 'reset',
//     animated.
//   undoLastStroke() / clearStrokes() — pop/clear freehand strokes.
//   requestDesignState() — posts the full { ...base style, strokes } JSON to
//     the "DesignStateChannel" JavaScriptChannel (mirrors captureSnapshot's
//     SnapshotChannel — runJavaScript can't return values reliably).
//   captureSnapshot() — renders one frame and posts a PNG data URL to the
//     "SnapshotChannel" JavaScriptChannel.

let scene, camera, renderer, headGroup, headMesh, headMaterial;
let shellMesh, strandMesh, hairUniforms;
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
let activeStrokeRasterized = 0; // points of activeStroke already painted
let pendingRaycastPoints = [];

// The tool currently selected in Flutter's tool bar. tool: 'rotate' means
// one-finger drags orbit the camera; anything else paints a stroke.
let toolConfig = { tool: 'rotate', radius: 0.03 };

// Matches the head mesh's SphereGeometry(1,...).scale(x,y,z) in init() —
// hair roots sit on this ellipsoid, not the underlying unit sphere.
const HEAD_SCALE = new THREE.Vector3(0.85, 1, 0.9);

// The scalp's polar extent, from the top pole — far enough down the back
// for the nape. Design format v1 used 100°; see convertStrokesFromV1.
const MAX_POLAR = (130 * Math.PI) / 180;
const V1_MAX_POLAR = (100 * Math.PI) / 180;
const DESIGN_VERSION = 2;

// Length parameters (0..20) become scene units at this scale.
const LENGTH_TO_SCENE = 0.05;

// Guard #0 (skin) .. #8, arbitrary scene-unit steps loosely mimicking real
// clipper guard increments. Razor strokes always use guard 0 (skin/liner).
const CLIPPER_GUARD_LENGTHS = [0, 1, 2, 3, 4, 5, 6, 8, 10];

// Painted length/color masks in scalp UV space. Alpha 0 = unpainted (use
// the base style); alpha 1 = painted. lengthMask stores length / 20 as
// grey; colorMask stores the dye colour. Strokes are stored as UV
// polylines, not pixels, so this resolution can change freely.
const MASK_WIDTH = 1024;
const MASK_HEIGHT = 512;
let lengthMaskCanvas, lengthMaskCtx, colorMaskCanvas, colorMaskCtx;
let lengthMaskTexture, colorMaskTexture;

const STRAND_SEGMENTS = 16;
const MAX_STRANDS = 20000;
const MIN_STRANDS = 4000;
const SHELL_LAYERS = 14;
// Shells draw hair up to this length (scene units, ≈ guard 3); strands take
// over above it.
const SHELL_MAX_LENGTH = 0.15;

// Camera: orbit around `target`, with inertia after a flick and animated
// preset views. Zoom is the orbit distance.
const MIN_DISTANCE = 1.6;
const MAX_DISTANCE = 9;
const DEFAULT_VIEW = { yaw: 0, pitch: 0.15, distance: 5.2, target: new THREE.Vector3(0, 0.1, 0) };
const PRESET_VIEWS = {
  front: { yaw: 0, pitch: 0.1 },
  left: { yaw: -Math.PI / 2, pitch: 0.1 },
  right: { yaw: Math.PI / 2, pitch: 0.1 },
  back: { yaw: Math.PI, pitch: 0.1 },
  top: { yaw: 0, pitch: 1.35 },
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

// --- Shaders ---------------------------------------------------------------

// Shared by the strand and shell shaders: the hair fields. Mirrors the
// pre-GPU JS formulas so existing saved designs keep their look.
const HAIR_FIELDS_GLSL = /* glsl */ `
  #define PI 3.141592653589793
  #define TAU 6.283185307179586
  uniform sampler2D uLengthMask;
  uniform sampler2D uColorMask;
  uniform float uBaseLength;
  uniform float uFade;
  uniform float uPart;
  uniform float uMaxPolar;
  uniform vec3 uHeadScale;
  uniform vec3 uBaseColor;

  const float FACE_AZIMUTH = PI * 0.5;
  const float FACE_HALF_WIDTH = 60.0 * PI / 180.0;
  const float HAIRLINE_CENTER = 38.0 * PI / 180.0;
  const float HAIRLINE_TEMPLE = 75.0 * PI / 180.0;
  const float SIDEBURN_BOTTOM = 100.0 * PI / 180.0;
  const float NAPE_BOTTOM = 124.0 * PI / 180.0;
  const float PAINTED_LENGTH_MAX = ${(20 * LENGTH_TO_SCENE).toFixed(3)};

  vec3 scalpDirection(vec2 uv) {
    float azimuth = uv.x * TAU;
    float polar = uv.y * uMaxPolar;
    return vec3(sin(polar) * cos(azimuth), cos(polar), sin(polar) * sin(azimuth));
  }

  float angularDistance(float a, float b) {
    return abs(mod(a - b + PI, TAU) - PI);
  }

  // 0 where no hair grows, 1 on the scalp. The front hairline arcs high at
  // the centre of the forehead and dips toward the temples; the lower one
  // runs from the sideburns, round the ears, down to the nape.
  float scalpMultiplier(vec2 uv) {
    float polar = uv.y * uMaxPolar;
    float delta = angularDistance(uv.x * TAU, FACE_AZIMUTH);
    float t = smoothstep(0.0, FACE_HALF_WIDTH, delta);
    float hairline = mix(HAIRLINE_CENTER, HAIRLINE_TEMPLE, t);
    float vertical = 1.0 - smoothstep(hairline - 0.14, hairline + 0.14, polar);
    float horizontal = smoothstep(FACE_HALF_WIDTH - 0.25, FACE_HALF_WIDTH + 0.1, delta);
    float lowerHairline = mix(SIDEBURN_BOTTOM, NAPE_BOTTOM, smoothstep(80.0 * PI / 180.0, 170.0 * PI / 180.0, delta));
    float lower = 1.0 - smoothstep(lowerHairline - 0.08, lowerHairline + 0.04, polar);
    return max(vertical, horizontal) * lower;
  }

  float baseLength(vec2 uv) {
    float polar = uv.y * uMaxPolar;
    float part = 1.0;
    if (uPart != 0.0) {
      float delta = angularDistance(uv.x * TAU, uPart * PI);
      // A narrow parting line down from the crown, fading out by the ears.
      part = mix(0.25, 1.0, max(smoothstep(0.02, 0.09, delta), smoothstep(1.1, 1.4, polar)));
    }
    float fade = smoothstep(35.0 * PI / 180.0, 112.0 * PI / 180.0, polar);
    return uBaseLength * part * max(0.05, 1.0 - fade * uFade);
  }

  float hairLength(vec2 uv) {
    vec4 painted = texture2D(uLengthMask, uv);
    // Divide out alpha: linear filtering at a stroke's edge blends with
    // unpainted (0,0,0,0) texels — this recovers the painted value and lets
    // alpha act as a soft edge.
    float paintedLength = painted.r / max(painted.a, 0.001) * PAINTED_LENGTH_MAX;
    return mix(baseLength(uv), paintedLength, painted.a) * scalpMultiplier(uv);
  }

  vec3 hairColor(vec2 uv) {
    vec4 dye = texture2D(uColorMask, uv);
    // The canvas holds sRGB; lighting works in linear.
    vec3 dyeLinear = pow(dye.rgb / max(dye.a, 0.001), vec3(2.2));
    return mix(uBaseColor, dyeLinear, dye.a);
  }

  // Kajiya-Kay style lighting for hair: brightness depends on the angle
  // between the hair's direction and the light, which gives the familiar
  // band-shaped shine.
  vec3 shadeHair(vec3 color, vec3 tangent, vec3 view, vec3 keyDir, vec3 fillDir, float occlusion) {
    float tl = dot(tangent, keyDir);
    float diffuse = sqrt(max(0.0, 1.0 - tl * tl));
    float tf = dot(tangent, fillDir);
    float fill = sqrt(max(0.0, 1.0 - tf * tf));
    vec3 halfway = normalize(keyDir + view);
    float th = dot(tangent, halfway);
    float shine = pow(sqrt(max(0.0, 1.0 - th * th)), 70.0);
    vec3 lit = color * (0.22 + 0.6 * diffuse + 0.18 * fill) * occlusion;
    return lit + shine * 0.28 * (0.25 + color) * occlusion;
  }
`;

const STRAND_VERTEX = /* glsl */ `
  ${HAIR_FIELDS_GLSL}
  // Per strand: scalp UV of the root, and two randoms (x: shape/curl
  // phase, y: density rank — strands above uDensity are hidden).
  attribute vec2 aRoot;
  attribute vec2 aRandom;
  // position.x is the ribbon side (-1 or 1), position.y the vertex index
  // along the strand (0 .. SEGMENTS).
  uniform float uDensity;
  uniform float uCurl;
  uniform float uVolume;
  uniform float uMinStrandLength;
  varying vec3 vTangent;
  varying vec3 vColor;
  varying vec3 vWorldPosition;
  varying float vAlong;

  const int SEGMENTS = ${STRAND_SEGMENTS};

  vec3 hash3(float n) {
    return fract(sin(vec3(n, n + 1.7, n + 3.1)) * 43758.5453);
  }

  void main() {
    // Curls take up length: a curly strand reaches less far than straight.
    float extent = hairLength(aRoot) * (1.0 - 0.45 * uCurl);
    if (aRandom.y > uDensity || extent < uMinStrandLength) {
      gl_Position = vec4(2.0, 2.0, 2.0, 1.0); // outside the clip volume: drawn as nothing
      return;
    }

    float azimuth = aRoot.x * TAU;
    float polar = aRoot.y * uMaxPolar;
    vec3 unit = scalpDirection(aRoot);
    vec3 root = unit * uHeadScale;
    vec3 normal = normalize(unit / uHeadScale);
    // Away from the crown, down the head — the natural fall of hair. At the
    // crown this points radially outward, which forms a whorl.
    vec3 down = vec3(cos(polar) * cos(azimuth), -sin(polar), cos(polar) * sin(azimuth));
    vec3 around = vec3(-sin(azimuth), 0.0, cos(azimuth));

    // Combed away from the parting line.
    float partSweep = 0.0;
    if (uPart != 0.0) {
      float delta = mod(azimuth - uPart * PI + PI, TAU) - PI;
      partSweep = sign(delta) * (1.0 - smoothstep(0.0, 1.4, abs(delta))) * (1.0 - smoothstep(1.0, 1.6, polar));
    }

    // Short hair stands up; longer hair lies down along the head.
    float lift = mix(0.7, 0.12, smoothstep(0.03, 0.35, extent));
    vec3 jitter = (hash3(aRandom.x * 97.0) - 0.5) * 0.35;
    vec3 direction = normalize(normal * lift + down * (1.0 - lift) + around * partSweep * 0.9 + jitter);

    float segmentLength = extent / float(SEGMENTS);
    float gravity = 2.6 * (1.0 - 0.6 * uCurl); // curly hair holds its shape
    float puff = 0.015 + 0.02 * uVolume + 0.1 * uVolume * uCurl;
    vec3 position3 = root;
    for (int i = 0; i < SEGMENTS; i++) {
      if (float(i) >= position.y) break;
      position3 += direction * segmentLength;
      direction = normalize(direction + vec3(0.0, -gravity * segmentLength, 0.0));
      // Keep the strand outside the head, sliding along it instead.
      vec3 local = position3 / uHeadScale;
      float radius = length(local);
      float minRadius = 1.012 + puff * (float(i) + 1.0) / float(SEGMENTS);
      if (radius < minRadius) {
        vec3 outward = normalize(local / uHeadScale);
        position3 = local / radius * minRadius * uHeadScale;
        float into = dot(direction, outward);
        if (into < 0.0) direction = normalize(direction - into * outward);
      }
    }

    float along = position.y / float(SEGMENTS);

    // Curl: a helix around the strand's path, growing from the root.
    vec3 tangent = direction;
    if (uCurl > 0.0) {
      vec3 helper = abs(direction.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
      vec3 b1 = normalize(cross(direction, helper));
      vec3 b2 = cross(direction, b1);
      // Radians per scene unit, capped so each turn keeps >= 5 vertices.
      float frequency = min(mix(12.0, 60.0, uCurl), float(SEGMENTS) / max(extent, 0.001) * TAU / 5.0);
      float radius = 0.05 * uCurl * smoothstep(0.0, 0.25, along);
      float phase = aRandom.x * TAU + along * extent * frequency;
      position3 += radius * (cos(phase) * b1 + sin(phase) * b2);
      tangent = normalize(direction + radius * frequency * (-sin(phase) * b1 + cos(phase) * b2));
    }

    // Ribbon facing the camera, tapering to the tip.
    vec3 worldPosition = (modelMatrix * vec4(position3, 1.0)).xyz;
    vec3 view = normalize(cameraPosition - worldPosition);
    vec3 side = normalize(cross(tangent, view));
    float width = 0.011 * (1.0 + 0.7 * uCurl) * mix(1.0, 0.3, along);
    worldPosition += side * position.x * width * 0.5;

    vTangent = tangent;
    vColor = hairColor(aRoot);
    vWorldPosition = worldPosition;
    vAlong = along;
    gl_Position = projectionMatrix * viewMatrix * vec4(worldPosition, 1.0);
  }
`;

const STRAND_FRAGMENT = /* glsl */ `
  ${HAIR_FIELDS_GLSL}
  uniform vec3 uKeyDirection;
  uniform vec3 uFillDirection;
  varying vec3 vTangent;
  varying vec3 vColor;
  varying vec3 vWorldPosition;
  varying float vAlong;

  void main() {
    vec3 view = normalize(cameraPosition - vWorldPosition);
    float occlusion = mix(0.45, 1.0, smoothstep(0.0, 0.6, vAlong));
    gl_FragColor = vec4(shadeHair(vColor, normalize(vTangent), view, uKeyDirection, uFillDirection, occlusion), 1.0);
    #include <colorspace_fragment>
  }
`;

const SHELL_VERTEX = /* glsl */ `
  ${HAIR_FIELDS_GLSL}
  attribute float aLayer;
  uniform float uLayers;
  uniform float uShellMax;
  varying vec2 vUv;
  varying float vLayer;
  varying vec3 vNormal;
  varying vec3 vWorldPosition;

  void main() {
    vec3 unit = scalpDirection(uv);
    vec3 normal = normalize(unit / uHeadScale);
    float height = min(hairLength(uv), uShellMax) * (aLayer + 1.0) / uLayers;
    vec3 worldPosition = (modelMatrix * vec4(unit * uHeadScale + normal * (height + 0.002), 1.0)).xyz;
    vUv = uv;
    vLayer = aLayer;
    vNormal = normal;
    vWorldPosition = worldPosition;
    gl_Position = projectionMatrix * viewMatrix * vec4(worldPosition, 1.0);
  }
`;

const SHELL_FRAGMENT = /* glsl */ `
  ${HAIR_FIELDS_GLSL}
  uniform float uLayers;
  uniform float uShellMax;
  uniform vec3 uKeyDirection;
  uniform vec3 uFillDirection;
  varying vec2 vUv;
  varying float vLayer;
  varying vec3 vNormal;
  varying vec3 vWorldPosition;

  // Sine-free hash (Dave Hoskins' "hash without sine"): the usual
  // fract(sin(...)) one loses precision on pixel/cell coordinates and draws
  // visible lines across the hair.
  float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
  }

  void main() {
    float capped = min(hairLength(vUv), uShellMax);
    if (capped < 0.004) discard;

    // One hair per cell of a grid projected from a cube onto the scalp —
    // evenly spaced everywhere, unlike UV (which pinches at the crown) or a
    // 3D grid (whose planes show as lines where they graze the head).
    vec3 normal = normalize(vNormal);
    vec3 direction = scalpDirection(vUv);
    vec3 magnitude = abs(direction);
    vec2 faceCoords;
    float faceId;
    if (magnitude.x >= magnitude.y && magnitude.x >= magnitude.z) {
      faceCoords = direction.yz / magnitude.x;
      faceId = sign(direction.x);
    } else if (magnitude.y >= magnitude.z) {
      faceCoords = direction.xz / magnitude.y;
      faceId = 2.0 + sign(direction.y);
    } else {
      faceCoords = direction.xy / magnitude.z;
      faceId = 4.0 + sign(direction.z);
    }
    vec2 cellSpace = faceCoords * 180.0;
    vec3 cell = vec3(floor(cellSpace), faceId);
    // Each hair sits at a random spot in its cell: on a regular lattice the
    // stacked layers line up into rows you can see straight through.
    vec2 jitter = vec2(hash(cell + 3.0), hash(cell + 5.0)) - 0.5;
    vec2 offset = fract(cellSpace) - 0.5 - jitter * 0.6;
    float hairHeight = capped * (0.7 + 0.3 * hash(cell));
    float layerHeight = capped * (vLayer + 1.0) / uLayers;
    if (layerHeight > hairHeight) discard;
    // Hairs thin toward the tip, and stubble is sparse enough to show skin.
    float thickness = mix(0.5, 0.18, layerHeight / hairHeight) * mix(0.4, 1.0, smoothstep(0.004, 0.05, capped));
    // Close up, each cell draws its hair as a dot. Zoomed out, cells shrink
    // below a pixel and dots would shimmer or vanish, so instead each pixel
    // keeps the share of the cell a hair covers — skin shows through short
    // hair, and a fade lightens as it shortens, at any zoom.
    // Blended per pixel through the in-between zoom so there's no visible
    // boundary where one approach hands over to the other.
    float cellsPerPixel = length(fwidth(cellSpace));
    float coverage = clamp(PI * thickness * thickness, 0.0, 1.0);
    float pixelNoise = hash(vec3(gl_FragCoord.xy, vLayer));
    bool useCoverage = hash(vec3(gl_FragCoord.yx, vLayer + 11.0)) < smoothstep(0.45, 0.9, cellsPerPixel);
    bool covered = useCoverage ? pixelNoise < coverage : length(offset) < thickness;
    // Once hair is past stubble, the bottom layer hides the scalp the way
    // dense real hair does when seen straight on.
    if (vLayer < 0.5) covered = covered || pixelNoise < smoothstep(0.02, 0.08, capped);
    if (!covered) discard;

    vec3 view = normalize(cameraPosition - vWorldPosition);
    // Short hair points outward; light it as if combed slightly back.
    vec3 tangent = normalize(normal + vec3(0.0, -0.3, 0.0));
    float occlusion = mix(0.35, 1.0, layerHeight / hairHeight);
    vec3 base = hairColor(vUv) * (0.88 + 0.24 * hash(cell + 7.0)); // hair-to-hair variation
    vec3 color = shadeHair(base, tangent, view, uKeyDirection, uFillDirection, occlusion);
    gl_FragColor = vec4(color, 1.0);
    #include <colorspace_fragment>
  }
`;

// --- Scene -------------------------------------------------------------------

function init() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x1a1a1a);

  camera = new THREE.PerspectiveCamera(40, window.innerWidth / window.innerHeight, 0.05, 100);
  scene.add(camera);

  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(window.innerWidth, window.innerHeight);
  // Capped: above 2x the extra pixels cost far more than they show.
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.domElement.setAttribute('id', 'scene-canvas');
  document.body.appendChild(renderer.domElement);

  // Lights ride with the camera, so whichever side is being looked at is
  // well lit (the hair shaders get the same directions as uniforms).
  scene.add(new THREE.AmbientLight(0xffffff, 0.55));
  const keyLight = new THREE.DirectionalLight(0xffffff, 1.6);
  keyLight.position.set(2, 3, 4);
  camera.add(keyLight);
  keyLight.target.position.set(0, 0, -1);
  camera.add(keyLight.target);
  const fillLight = new THREE.DirectionalLight(0xffffff, 0.45);
  fillLight.position.set(-4, 0, 1);
  camera.add(fillLight);
  fillLight.target.position.set(0, 0, -1);
  camera.add(fillLight.target);

  headGroup = new THREE.Group();
  scene.add(headGroup);

  const headGeometry = new THREE.SphereGeometry(1, 64, 48);
  headGeometry.scale(HEAD_SCALE.x, HEAD_SCALE.y, HEAD_SCALE.z);
  headMaterial = new THREE.MeshStandardMaterial({ color: currentParams.faceParams.skinTone, roughness: 0.75 });
  headMesh = new THREE.Mesh(headGeometry, headMaterial);
  headGroup.add(headMesh);

  const neckGeometry = new THREE.CylinderGeometry(0.35, 0.4, 0.6, 32);
  const neckMesh = new THREE.Mesh(neckGeometry, headMaterial);
  neckMesh.position.set(0, -1.15, 0);
  headGroup.add(neckMesh);

  buildFace();
  buildMasks();
  buildHair();
  applyParameters();
  setupControls();
  updateCamera();
  requestRender();
}

// Stylized facial features built from primitive geometry — eyes, brows,
// nose, mouth, ears — parented to headGroup in the same coordinate space
// as the scalp, so "front of head" (azimuth π/2) lines up with the face.
function buildFace() {
  const eyeWhiteMaterial = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.4 });
  const pupilMaterial = new THREE.MeshStandardMaterial({ color: 0x2a1a12, roughness: 0.3 });
  const mouthMaterial = new THREE.MeshStandardMaterial({ color: 0x7a4a45, roughness: 0.6 });

  const eyeWhiteGeometry = new THREE.SphereGeometry(0.085, 16, 16);
  const pupilGeometry = new THREE.SphereGeometry(0.04, 12, 12);
  const browGeometry = new THREE.BoxGeometry(0.16, 0.03, 0.03);
  const noseGeometry = new THREE.SphereGeometry(0.09, 16, 16);
  const mouthGeometry = new THREE.BoxGeometry(0.2, 0.035, 0.02);
  const earGeometry = new THREE.SphereGeometry(0.13, 16, 16);

  for (const side of [-1, 1]) {
    const eyeWhite = new THREE.Mesh(eyeWhiteGeometry, eyeWhiteMaterial);
    eyeWhite.position.set(side * 0.3, 0.08, 0.78);
    eyeWhite.scale.set(1, 0.85, 0.7);
    headGroup.add(eyeWhite);

    const pupil = new THREE.Mesh(pupilGeometry, pupilMaterial);
    pupil.position.set(side * 0.3, 0.08, 0.84);
    headGroup.add(pupil);

    // Brows follow the base hair colour (see applyParameters).
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

function buildMasks() {
  lengthMaskCanvas = document.createElement('canvas');
  lengthMaskCanvas.width = MASK_WIDTH;
  lengthMaskCanvas.height = MASK_HEIGHT;
  lengthMaskCtx = lengthMaskCanvas.getContext('2d');
  colorMaskCanvas = document.createElement('canvas');
  colorMaskCanvas.width = MASK_WIDTH;
  colorMaskCanvas.height = MASK_HEIGHT;
  colorMaskCtx = colorMaskCanvas.getContext('2d');

  const maskTexture = (canvas) => {
    const texture = new THREE.CanvasTexture(canvas);
    texture.flipY = false; // texture v = canvas row, matching the UV maths
    texture.wrapS = THREE.RepeatWrapping; // u wraps around the head
    texture.wrapT = THREE.ClampToEdgeWrapping;
    texture.generateMipmaps = false;
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    texture.colorSpace = THREE.NoColorSpace; // raw data; hairColor() decodes the dye itself
    return texture;
  };
  lengthMaskTexture = maskTexture(lengthMaskCanvas);
  colorMaskTexture = maskTexture(colorMaskCanvas);
}

function buildHair() {
  hairUniforms = {
    uLengthMask: { value: lengthMaskTexture },
    uColorMask: { value: colorMaskTexture },
    uBaseLength: { value: 0 },
    uFade: { value: 0 },
    uPart: { value: 0 },
    uMaxPolar: { value: MAX_POLAR },
    uHeadScale: { value: HEAD_SCALE },
    uBaseColor: { value: new THREE.Color() },
    uDensity: { value: 0.5 },
    uCurl: { value: 0 },
    uVolume: { value: 1 },
    uMinStrandLength: { value: SHELL_MAX_LENGTH * 0.6 },
    uLayers: { value: SHELL_LAYERS },
    uShellMax: { value: SHELL_MAX_LENGTH },
    uKeyDirection: { value: new THREE.Vector3() },
    uFillDirection: { value: new THREE.Vector3() },
  };

  // Shells: a UV grid over the scalp, one instance per layer.
  const grid = new THREE.PlaneGeometry(1, 1, 160, 64);
  const shellGeometry = new THREE.InstancedBufferGeometry();
  shellGeometry.index = grid.index;
  shellGeometry.setAttribute('position', grid.attributes.position);
  // PlaneGeometry's uv has v=1 at the top; the scalp wants v=0 at the crown.
  const uv = grid.attributes.uv.clone();
  for (let i = 0; i < uv.count; i++) uv.setY(i, 1 - uv.getY(i));
  shellGeometry.setAttribute('uv', uv);
  shellGeometry.setAttribute(
    'aLayer',
    new THREE.InstancedBufferAttribute(Float32Array.from({ length: SHELL_LAYERS }, (_, i) => i), 1),
  );
  shellGeometry.instanceCount = SHELL_LAYERS;
  shellMesh = new THREE.Mesh(
    shellGeometry,
    new THREE.ShaderMaterial({
      uniforms: hairUniforms,
      vertexShader: SHELL_VERTEX,
      fragmentShader: SHELL_FRAGMENT,
      side: THREE.DoubleSide,
    }),
  );
  shellMesh.frustumCulled = false; // vertices are placed in the shader
  headGroup.add(shellMesh);

  // Strands: one ribbon (2 vertices per step) per instance.
  const vertices = [];
  const indices = [];
  for (let step = 0; step <= STRAND_SEGMENTS; step++) {
    vertices.push(-1, step, 0, 1, step, 0);
    if (step < STRAND_SEGMENTS) {
      const a = step * 2;
      indices.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
    }
  }
  const strandGeometry = new THREE.InstancedBufferGeometry();
  strandGeometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  strandGeometry.setIndex(indices);

  // Roots spread evenly by area over the scalp cap (Fibonacci spiral with
  // cos-spaced polar angles), jittered so no pattern shows.
  const roots = new Float32Array(MAX_STRANDS * 2);
  const randoms = new Float32Array(MAX_STRANDS * 2);
  const goldenAngle = Math.PI * (3 - Math.sqrt(5));
  const capHeight = 1 - Math.cos(MAX_POLAR);
  for (let i = 0; i < MAX_STRANDS; i++) {
    const polar = Math.acos(1 - ((i + Math.random()) / MAX_STRANDS) * capHeight);
    let azimuth = (i * goldenAngle + (Math.random() - 0.5) * 0.02) % (2 * Math.PI);
    if (azimuth < 0) azimuth += 2 * Math.PI;
    roots[i * 2] = azimuth / (2 * Math.PI);
    roots[i * 2 + 1] = Math.min(1, polar / MAX_POLAR);
    randoms[i * 2] = Math.random();
    randoms[i * 2 + 1] = Math.random();
  }
  strandGeometry.setAttribute('aRoot', new THREE.InstancedBufferAttribute(roots, 2));
  strandGeometry.setAttribute('aRandom', new THREE.InstancedBufferAttribute(randoms, 2));
  strandGeometry.instanceCount = 14000;
  strandMesh = new THREE.Mesh(
    strandGeometry,
    new THREE.ShaderMaterial({
      uniforms: hairUniforms,
      vertexShader: STRAND_VERTEX,
      fragmentShader: STRAND_FRAGMENT,
      side: THREE.DoubleSide,
    }),
  );
  strandMesh.frustumCulled = false;
  headGroup.add(strandMesh);
}

function applyParameters() {
  hairUniforms.uBaseLength.value = Math.max(0, currentParams.length) * LENGTH_TO_SCENE;
  hairUniforms.uFade.value = currentParams.fadeHeight;
  hairUniforms.uPart.value = currentParams.partOffset;
  hairUniforms.uCurl.value = currentParams.curl;
  hairUniforms.uVolume.value = currentParams.volume;
  // volume 0.2..2 shows 10%..100% of the strands.
  hairUniforms.uDensity.value = Math.min(1, Math.max(0.1, currentParams.volume / 2));
  hairUniforms.uBaseColor.value.set(currentParams.colorHex);
  headMaterial.color.set(currentParams.faceParams.skinTone);
  for (const material of eyebrowMaterials) material.color.set(currentParams.colorHex);
  requestRender();
}

// --- Painting ---------------------------------------------------------------

function strokeLength(stroke) {
  if (stroke.tool === 'clipper' || stroke.tool === 'razor') {
    return CLIPPER_GUARD_LENGTHS[stroke.guard ?? 0];
  }
  if (stroke.tool === 'scissors') {
    return stroke.length ?? 0;
  }
  return null; // dye doesn't touch length
}

// Paints points [from, end) of a stroke (plus the segment joining them to
// the previous point) into the mask(s) its tool affects. Opaque paint is
// idempotent, so painting a growing stroke incrementally gives the same
// result as painting it whole. Each pass is drawn at -width/0/+width so
// strokes crossing the u = 0/1 seam wrap around.
function rasterizeStroke(stroke, from = 0) {
  const points = stroke.points;
  if (points.length === 0 || from >= points.length) return;
  const pixelRadius = Math.max(1, stroke.radius * MASK_WIDTH);
  const start = Math.max(0, from - 1);

  const drawPass = (ctx, style) => {
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.lineWidth = pixelRadius * 2;
    ctx.strokeStyle = style;
    ctx.fillStyle = style;
    for (const offsetX of [-MASK_WIDTH, 0, MASK_WIDTH]) {
      ctx.beginPath();
      for (let i = start; i < points.length; i++) {
        const x = points[i][0] * MASK_WIDTH + offsetX;
        const y = points[i][1] * MASK_HEIGHT;
        if (i === start) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
      // A single tap (one point) still paints a dot.
      if (points.length - start === 1) {
        ctx.beginPath();
        ctx.arc(points[start][0] * MASK_WIDTH + offsetX, points[start][1] * MASK_HEIGHT, pixelRadius, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  };

  const lengthValue = strokeLength(stroke);
  if (lengthValue !== null) {
    const gray = Math.round((Math.max(0, Math.min(20, lengthValue)) / 20) * 255);
    drawPass(lengthMaskCtx, `rgba(${gray}, ${gray}, ${gray}, 1)`);
    lengthMaskTexture.needsUpdate = true;
  }
  if (stroke.tool === 'dye') {
    drawPass(colorMaskCtx, stroke.colorHex || '#000000');
    colorMaskTexture.needsUpdate = true;
  }
}

function rebuildMasksFromStrokes() {
  lengthMaskCtx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
  colorMaskCtx.clearRect(0, 0, MASK_WIDTH, MASK_HEIGHT);
  lengthMaskTexture.needsUpdate = true;
  colorMaskTexture.needsUpdate = true;
  for (const stroke of strokes) rasterizeStroke(stroke);
  requestRender();
}

// Applies points collected since the last frame to the active stroke. Done
// once per frame, not per pointer event — event rates can far exceed 60/s.
function flushPendingStrokePoints() {
  if (!activeStroke || pendingRaycastPoints.length === 0) return;
  activeStroke.points.push(...pendingRaycastPoints);
  pendingRaycastPoints = [];
  rasterizeStroke(activeStroke, activeStrokeRasterized);
  activeStrokeRasterized = activeStroke.points.length;
}

// Casts the given screen point onto the head and returns its scalp UV, or
// null if the ray misses the head.
const raycaster = new THREE.Raycaster();
const pointerNDC = new THREE.Vector2();
function raycastToUV(clientX, clientY) {
  const rect = renderer.domElement.getBoundingClientRect();
  pointerNDC.x = ((clientX - rect.left) / rect.width) * 2 - 1;
  pointerNDC.y = -((clientY - rect.top) / rect.height) * 2 + 1;
  raycaster.setFromCamera(pointerNDC, camera);
  const hits = raycaster.intersectObject(headMesh, false);
  if (hits.length === 0) return null;
  // headGroup sits at the origin unrotated: hit point local == world.
  const direction = hits[0].point.clone().divide(HEAD_SCALE).normalize();
  const polar = Math.acos(Math.min(1, Math.max(-1, direction.y)));
  let azimuth = Math.atan2(direction.z, direction.x);
  if (azimuth < 0) azimuth += 2 * Math.PI;
  return { u: azimuth / (2 * Math.PI), v: Math.min(1, polar / MAX_POLAR) };
}

// --- Gestures -----------------------------------------------------------------
//
// One finger: orbit (rotate tool) or paint (any other tool). Two fingers:
// pinch to zoom and drag to pan, whatever the tool — a second finger landing
// mid-stroke discards that stroke, since it was the start of a pinch. Double
// tap resets the view. Mouse wheel zooms, for desktop debugging.

const pointers = new Map();
let pinch = null; // { distance, midX, midY } at the previous move
let lastTap = { time: 0, x: 0, y: 0 };
let lastMoveTime = 0;

function setupControls() {
  const el = renderer.domElement;

  el.addEventListener('pointerdown', (event) => {
    el.setPointerCapture(event.pointerId);
    pointers.set(event.pointerId, { x: event.clientX, y: event.clientY, downX: event.clientX, downY: event.clientY });
    cameraTween = null;
    orbit.yawVelocity = 0;
    orbit.pitchVelocity = 0;

    if (pointers.size === 2) {
      activeStroke = null; // the first finger was the start of a pinch, not a stroke
      pendingRaycastPoints = [];
      rebuildMasksFromStrokes();
      pinch = pinchState();
      return;
    }
    if (pointers.size > 2) return;

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
      activeStrokeRasterized = 0;
      pendingRaycastPoints = [[uv.u, uv.v]];
      requestRender();
    }
  });

  el.addEventListener('pointermove', (event) => {
    const pointer = pointers.get(event.pointerId);
    if (!pointer) return;
    const dx = event.clientX - pointer.x;
    const dy = event.clientY - pointer.y;
    pointer.x = event.clientX;
    pointer.y = event.clientY;

    if (pointers.size === 2 && pinch) {
      const next = pinchState();
      orbit.distance = clamp(orbit.distance * (pinch.distance / next.distance), MIN_DISTANCE, MAX_DISTANCE);
      pan(next.midX - pinch.midX, next.midY - pinch.midY);
      pinch = next;
      updateCamera();
      requestRender();
      return;
    }
    if (pointers.size !== 1) return;

    if (activeStroke) {
      const uv = raycastToUV(event.clientX, event.clientY);
      if (uv) pendingRaycastPoints.push([uv.u, uv.v]);
      requestRender();
      return;
    }
    if (toolConfig.tool && toolConfig.tool !== 'rotate') return; // painting started off the head

    const now = performance.now();
    const elapsed = Math.max(1, now - lastMoveTime);
    lastMoveTime = now;
    const yawStep = -dx * 0.008;
    const pitchStep = dy * 0.008;
    orbit.yaw += yawStep;
    orbit.pitch = clamp(orbit.pitch + pitchStep, -1.4, 1.45);
    // Velocity in radians per 16ms frame, for the fling after release.
    orbit.yawVelocity = (yawStep / elapsed) * 16;
    orbit.pitchVelocity = (pitchStep / elapsed) * 16;
    updateCamera();
    requestRender();
  });

  const release = (event) => {
    const pointer = pointers.get(event.pointerId);
    if (!pointer) return;
    pointers.delete(event.pointerId);
    if (pointers.size < 2) pinch = null;

    if (activeStroke) {
      flushPendingStrokePoints();
      if (activeStroke.points.length > 0) strokes.push(activeStroke);
      activeStroke = null;
      requestRender();
      return;
    }
    // A fling keeps spinning only if the finger was still moving at release.
    if (performance.now() - lastMoveTime > 80) {
      orbit.yawVelocity = 0;
      orbit.pitchVelocity = 0;
    }
    requestRender();

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

  el.addEventListener(
    'wheel',
    (event) => {
      event.preventDefault();
      orbit.distance = clamp(orbit.distance * Math.exp(event.deltaY * 0.001), MIN_DISTANCE, MAX_DISTANCE);
      updateCamera();
      requestRender();
    },
    { passive: false },
  );
  window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
    requestRender();
  });
}

function pinchState() {
  const [a, b] = [...pointers.values()];
  return {
    distance: Math.max(1, Math.hypot(a.x - b.x, a.y - b.y)),
    midX: (a.x + b.x) / 2,
    midY: (a.y + b.y) / 2,
  };
}

// Moves the orbit target with the fingers, at the scale of the view.
function pan(dx, dy) {
  const worldPerPixel = (2 * orbit.distance * Math.tan((camera.fov * Math.PI) / 360)) / window.innerHeight;
  const right = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0);
  const up = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 1);
  orbit.target.addScaledVector(right, -dx * worldPerPixel).addScaledVector(up, dy * worldPerPixel);
  orbit.target.clampLength(0, 1.5); // the head can't be panned out of view
}

function updateCamera() {
  const x = orbit.distance * Math.cos(orbit.pitch) * Math.sin(orbit.yaw);
  const y = orbit.distance * Math.sin(orbit.pitch);
  const z = orbit.distance * Math.cos(orbit.pitch) * Math.cos(orbit.yaw);
  camera.position.set(x, y, z).add(orbit.target);
  camera.lookAt(orbit.target);
  camera.updateMatrixWorld();
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

// --- Render loop ------------------------------------------------------------
//
// Frames are only drawn when something changed: an idle designer costs no
// GPU or battery. Fling inertia and view animations keep it going until
// they settle.

let renderRequested = false;
let lastFrameTime = 0;
let slowFrames = 0;

function requestRender() {
  if (renderRequested) return;
  renderRequested = true;
  requestAnimationFrame(frame);
}

function frame(now) {
  renderRequested = false;
  let animating = false;

  if (cameraTween) {
    const t = Math.min(1, (now - cameraTween.start) / cameraTween.duration);
    const eased = 1 - Math.pow(1 - t, 3);
    orbit.yaw = lerp(cameraTween.from.yaw, cameraTween.to.yaw, eased);
    orbit.pitch = lerp(cameraTween.from.pitch, cameraTween.to.pitch, eased);
    orbit.distance = lerp(cameraTween.from.distance, cameraTween.to.distance, eased);
    orbit.target.lerpVectors(cameraTween.from.target, cameraTween.to.target, eased);
    if (t >= 1) cameraTween = null;
    animating = true;
    updateCamera();
  } else if (pointers.size === 0 && (Math.abs(orbit.yawVelocity) > 0.0005 || Math.abs(orbit.pitchVelocity) > 0.0005)) {
    orbit.yaw += orbit.yawVelocity;
    orbit.pitch = clamp(orbit.pitch + orbit.pitchVelocity, -1.4, 1.45);
    orbit.yawVelocity *= 0.92;
    orbit.pitchVelocity *= 0.92;
    animating = true;
    updateCamera();
  }

  flushPendingStrokePoints();
  hairUniforms.uKeyDirection.value.set(2, 3, 4).normalize().transformDirection(camera.matrixWorld);
  hairUniforms.uFillDirection.value.set(-4, 0, 1).normalize().transformDirection(camera.matrixWorld);
  renderer.render(scene, camera);

  adaptQuality(now);
  if (animating) requestRender();
}

// Adaptive quality: if back-to-back frames run slower than ~40fps for a
// while, draw fewer strands. Only ever steps down, so it can't oscillate.
function adaptQuality(now) {
  const frameTime = now - lastFrameTime;
  lastFrameTime = now;
  if (frameTime > 100) return; // not consecutive frames — the scene was idle
  slowFrames = frameTime > 25 ? slowFrames + 1 : Math.max(0, slowFrames - 1);
  const geometry = strandMesh.geometry;
  if (slowFrames > 20 && geometry.instanceCount > MIN_STRANDS) {
    geometry.instanceCount = Math.max(MIN_STRANDS, Math.round(geometry.instanceCount * 0.75));
    slowFrames = 0;
  }
}

function lerp(a, b, t) {
  return a + (b - a) * t;
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
    applyParameters();
  } catch (error) {
    console.error('updateParameters failed', error);
  }
};

// v1 designs mapped polar 0..100° onto v = 0..1; v2 maps 0..130°.
function convertStrokesFromV1(v1Strokes) {
  const scale = V1_MAX_POLAR / MAX_POLAR;
  return v1Strokes.map((stroke) => ({
    ...stroke,
    points: stroke.points.map(([u, v]) => [u, v * scale]),
  }));
}

// Call after updateParameters, which carries the design's version.
window.loadStrokes = function (jsonString) {
  try {
    const parsed = JSON.parse(jsonString);
    strokes = Array.isArray(parsed) ? parsed : [];
    if ((currentParams.version ?? 1) < 2) strokes = convertStrokesFromV1(strokes);
    rebuildMasksFromStrokes();
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

window.setView = function (name) {
  const preset = name === 'reset' ? DEFAULT_VIEW : PRESET_VIEWS[name];
  if (!preset) return;
  // Turn the short way round to the target yaw.
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
  orbit.yawVelocity = 0;
  orbit.pitchVelocity = 0;
  requestRender();
};

window.undoLastStroke = function () {
  strokes.pop();
  rebuildMasksFromStrokes();
};

window.clearStrokes = function () {
  strokes = [];
  rebuildMasksFromStrokes();
};

window.requestDesignState = function () {
  const state = { ...currentParams, version: DESIGN_VERSION, strokes };
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
