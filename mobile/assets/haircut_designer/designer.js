// Procedural hair designer scene — stylized, not photoreal. No external 3D
// model files are used (avoids sourcing/licensing third-party assets); the
// head and hair are built entirely from primitive geometry driven by the
// parameters Flutter sends in via updateParameters().
//
// Bridge (called from Flutter via runJavaScript):
//   updateParameters(jsonString) — { length, volume, curl, colorHex, partOffset, fadeHeight }
//   captureSnapshot() — renders one frame and posts a PNG data URL to the
//     "SnapshotChannel" JavaScriptChannel Flutter registers.

let scene, camera, renderer, headGroup, hairMesh;

const DEFAULT_PARAMS = {
  length: 8, // 0 (shaved) .. 20 (long), arbitrary scene units
  volume: 1, // 0.2 (sparse) .. 2 (very thick)
  curl: 0, // 0 (straight) .. 1 (tight curl)
  colorHex: '#3b2314',
  partOffset: 0, // -1 (left) .. 1 (right), 0 = no part
  fadeHeight: 0.3, // 0 (no fade, even length) .. 1 (high, tight fade)
};

let currentParams = { ...DEFAULT_PARAMS };

// Matches the head mesh's SphereGeometry(1,...).scale(x,y,z) in init() —
// used to place hair roots on the actual head surface, not the underlying
// unit sphere.
const HEAD_SCALE = new THREE.Vector3(0.85, 1, 0.9);
const GRAVITY = new THREE.Vector3(0, -1, 0);

// Pointer-drag-to-rotate + wheel-to-zoom — hand-rolled since the classic
// (non-module) three.min.js build doesn't include the OrbitControls addon.
let orbitYaw = 0;
let orbitPitch = 0.15;
let orbitDistance = 6;
let dragging = false;
let lastPointer = { x: 0, y: 0 };

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
  headGeometry.scale(0.85, 1, 0.9);
  const headMaterial = new THREE.MeshStandardMaterial({ color: 0xe0ac69, roughness: 0.85 });
  headGroup.add(new THREE.Mesh(headGeometry, headMaterial));

  const neckGeometry = new THREE.CylinderGeometry(0.35, 0.4, 0.6, 16);
  const neckMesh = new THREE.Mesh(neckGeometry, headMaterial);
  neckMesh.position.set(0, -1.15, 0);
  headGroup.add(neckMesh);

  rebuildHair(currentParams);
  setupControls();
  updateCamera();
  animate();
}

/// Follicle points over the scalp cap (top/sides/back, not the face),
/// evenly spread via a Fibonacci-sphere sampling restricted to the polar
/// angle range that covers hair-bearing scalp.
function scalpFollicles(count) {
  const points = [];
  const goldenAngle = Math.PI * (3 - Math.sqrt(5));
  const maxPolar = (100 * Math.PI) / 180; // from the top pole, in radians
  for (let i = 0; i < count; i++) {
    const t = i / Math.max(1, count - 1);
    const polar = t * maxPolar;
    const azimuth = i * goldenAngle;
    const x = Math.sin(polar) * Math.cos(azimuth);
    const z = Math.sin(polar) * Math.sin(azimuth);
    const y = Math.cos(polar);
    points.push({ direction: new THREE.Vector3(x, y, z), polar, azimuth });
  }
  return points;
}

function rebuildHair(params) {
  if (hairMesh) {
    headGroup.remove(hairMesh);
    hairMesh.geometry.dispose();
    hairMesh.material.dispose();
    hairMesh = null;
  }

  const lengthUnits = Math.max(0, params.length) * 0.05; // scene-unit scale
  if (lengthUnits <= 0.01) return; // shaved — nothing to draw

  const baseCount = 900;
  const follicleCount = Math.round(baseCount * Math.max(0.1, params.volume));
  const follicles = scalpFollicles(follicleCount);

  const segmentCount = Math.max(2, Math.min(8, Math.round(lengthUnits / 0.12)));
  const segmentGeometry = new THREE.CylinderGeometry(0.012, 0.016, 1, 5);
  segmentGeometry.translate(0, 0.5, 0); // pivot at the base, extends toward +Y locally

  const instances = follicles.length * segmentCount;
  hairMesh = new THREE.InstancedMesh(
    segmentGeometry,
    new THREE.MeshStandardMaterial({ color: params.colorHex, roughness: 0.6 }),
    instances,
  );

  const matrix = new THREE.Matrix4();
  const quaternion = new THREE.Quaternion();
  const scale = new THREE.Vector3();
  const up = new THREE.Vector3(0, 1, 0);
  let instanceIndex = 0;

  for (const follicle of follicles) {
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

    const strandLength = lengthUnits * partSuppression * Math.max(0.05, fadeMultiplier);
    if (strandLength <= 0.02) {
      instanceIndex += segmentCount;
      continue;
    }

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

  // Unused instances (suppressed by the part line) still need a definite
  // (zero-scale) transform, otherwise they render as garbage matrices.
  const zeroMatrix = new THREE.Matrix4().makeScale(0, 0, 0);
  for (let i = instanceIndex; i < instances; i++) {
    hairMesh.setMatrixAt(i, zeroMatrix);
  }

  hairMesh.instanceMatrix.needsUpdate = true;
  headGroup.add(hairMesh);
}

function smoothstep(edge0, edge1, x) {
  const t = Math.min(1, Math.max(0, (x - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

function setupControls() {
  const el = renderer.domElement;
  el.addEventListener('pointerdown', (event) => {
    dragging = true;
    lastPointer = { x: event.clientX, y: event.clientY };
  });
  window.addEventListener('pointerup', () => {
    dragging = false;
  });
  window.addEventListener('pointermove', (event) => {
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

function updateCamera() {
  const x = orbitDistance * Math.cos(orbitPitch) * Math.sin(orbitYaw);
  const y = orbitDistance * Math.sin(orbitPitch);
  const z = orbitDistance * Math.cos(orbitPitch) * Math.cos(orbitYaw);
  camera.position.set(x, y, z);
  camera.lookAt(0, 0, 0);
}

function animate() {
  requestAnimationFrame(animate);
  renderer.render(scene, camera);
}

// --- Flutter bridge -------------------------------------------------------

window.updateParameters = function (jsonString) {
  try {
    const parsed = JSON.parse(jsonString);
    currentParams = { ...DEFAULT_PARAMS, ...parsed };
    rebuildHair(currentParams);
  } catch (error) {
    console.error('updateParameters failed', error);
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
