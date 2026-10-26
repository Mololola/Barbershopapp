"""Builds mobile/assets/haircut_designer/head_asset.js from the head scan.

The designer's WebView loads from file:// and can't fetch() local files, so
everything ships embedded in one script: the mesh (quantised), the collision
shapes fitted to it, and a precomputed scalp map. The scan's skin textures
aren't shipped: the designer draws the head as a plain mannequin.

Units: 1 = 10 cm. The scan is scaled so crown to chin is 23 cm, and moved
so the fitted cranium ellipsoid is centred on the origin; it faces +z.

Scalp map: for a grid over scalp UV (u = azimuth / 2pi, v = polar / 130deg,
angles taken on the cranium ellipsoid, azimuth pi/2 = the face), the point
where a ray from the cranium centre meets the skin, and the skin normal
there. Hair roots and the short-hair shells sit on it.

Body field: the signed distance (negative inside) to the bust's skin
below the head, on a 1 cm grid, so long hair can be kept out of the neck,
shoulders and back without the fitted shapes' gaps, and pushed out along
its gradient, which changes smoothly (pushes along a fixed axis switched
direction between neighbouring points, and resting hair shook).

Run with the system Python (needs numpy, scipy):  python build_head_asset.py
"""
import base64
import json
import math
import pathlib

import numpy as np
from scipy.spatial import cKDTree

from glb import load_glb

HERE = pathlib.Path(__file__).parent
SOURCE = HERE / "source"
OUTPUT = HERE.parent.parent / "mobile" / "assets" / "haircut_designer" / "head_asset.js"

CROWN_TO_CHIN = 2.3  # 23 cm
SCAN_CROWN_Y = 3.97
SCAN_CHIN_Y = -0.70  # where the face profile (front-most z at each height) drops into the neck
MAX_POLAR = math.radians(130)
SCALP_MAP_WIDTH = 128
SCALP_MAP_HEIGHT = 64


def fit_ellipsoid(points, center, radii, iterations=30):
    """Axis-aligned ellipsoid best fitting the points (Gauss-Newton on each
    point's normalised radius minus 1), from a starting guess. The algebraic
    least-squares fit is unstable on a partial cap like the cranium."""
    params = np.concatenate([center, radii]).astype(np.float64)

    def residuals(p):
        return np.linalg.norm((points - p[:3]) / p[3:], axis=1) - 1

    for _ in range(iterations):
        r = residuals(params)
        jacobian = np.empty((len(points), 6))
        for k in range(6):
            step = np.zeros(6)
            step[k] = 1e-5
            jacobian[:, k] = (residuals(params + step) - r) / 1e-5
        params -= np.linalg.lstsq(jacobian, r, rcond=None)[0]
    return params[:3], np.abs(params[3:])



def ray_mesh(origin, direction, v0, e1, e2):
    """Nearest hit (t, triangle index, u, v) of one ray against all triangles
    (Moller-Trumbore, vectorised over triangles); None if it misses."""
    p = np.cross(direction, e2)
    det = np.einsum("ij,ij->i", e1, p)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
    s = origin - v0
    u = np.einsum("ij,ij->i", s, p) * inv
    q = np.cross(s, e1)
    v = (q @ direction) * inv
    t = np.einsum("ij,ij->i", e2, q) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-6)
    if not hit.any():
        return None
    index = np.where(hit)[0][np.argmin(t[hit])]
    return t[index], index, u[index], v[index]


BODY_FIELD = {"x0": -2.3, "y0": -3.0, "z0": -1.5, "cell": 0.1, "nx": 47, "ny": 22, "nz": 31, "step": 0.002}


def body_field(positions, triangles):
    """Signed distance to the skin at the grid's nodes, in BODY_FIELD steps
    (int8: +-25 cm). Distance: to dense samples of the triangles near the
    body (about 1.5 mm apart); sign: crossings of the skin along +z."""
    f = BODY_FIELD
    near = (positions[triangles][:, :, 1] < f["y0"] + f["cell"] * f["ny"] + 0.3).any(axis=1)
    tris = positions[triangles[near]]
    n = 10
    weights = np.array([(i / n, j / n, 1 - (i + j) / n) for i in range(n + 1) for j in range(n + 1 - i)])
    samples = np.einsum("wk,tkc->twc", weights, tris).reshape(-1, 3)
    xs = f["x0"] + np.arange(f["nx"]) * f["cell"]
    ys = f["y0"] + np.arange(f["ny"]) * f["cell"]
    zs = f["z0"] + np.arange(f["nz"]) * f["cell"]
    grid = np.stack(np.meshgrid(xs, ys, zs, indexing="ij"), axis=-1)  # x, y, z
    distance, _ = cKDTree(samples).query(grid.reshape(-1, 3))
    distance = distance.reshape(grid.shape[:3])
    # Inside: an odd number of skin crossings along +z before the node.
    a, b, c = tris[:, 0], tris[:, 1], tris[:, 2]
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            # Barycentric coordinates of (x, y) in each triangle's xy shadow.
            d = (b[:, 1] - c[:, 1]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 1] - c[:, 1])
            ok = np.abs(d) > 1e-12
            d = np.where(ok, d, 1)
            l1 = ((b[:, 1] - c[:, 1]) * (x - c[:, 0]) + (c[:, 0] - b[:, 0]) * (y - c[:, 1])) / d
            l2 = ((c[:, 1] - a[:, 1]) * (x - c[:, 0]) + (a[:, 0] - c[:, 0]) * (y - c[:, 1])) / d
            l3 = 1 - l1 - l2
            hit = ok & (l1 >= 0) & (l2 >= 0) & (l3 >= 0)
            crossings = np.sort(l1[hit] * a[hit, 2] + l2[hit] * b[hit, 2] + l3[hit] * c[hit, 2])
            inside = np.searchsorted(crossings, zs) % 2 == 1
            distance[i, j, inside] *= -1
    quantised = np.clip(np.round(distance / f["step"]), -127, 127).astype(np.int8)
    # Stored z fastest, then x, then y: data[(y * nx + x) * nz + z].
    return {**f, "data": b64(quantised.transpose(1, 0, 2))}


def b64(array):
    return base64.b64encode(np.ascontiguousarray(array).tobytes()).decode("ascii")


def main():
    positions, normals, _, triangles = load_glb(SOURCE / "LeePerrySmith.glb")
    scale = CROWN_TO_CHIN / (SCAN_CROWN_Y - SCAN_CHIN_Y)
    positions = positions * scale
    sx, sy, sz = positions.T / scale  # back in scan units, for region selection

    # Cranium: above the brows, plus the back of the skull down to the ears,
    # leaving out the face and the ears themselves.
    # Starting guess from the measured profile: brow-level length 4.2 and
    # temple width 3.15 scan units, crown at 3.97.
    cranium_points = (sy > 1.9) | ((sy > 0.4) & (sz < 0.3) & (np.abs(sx) < 1.55))
    cranium_center, cranium_radii = fit_ellipsoid(
        positions[cranium_points], np.array([0, 1.87, 0.1]) * scale, np.array([1.58, 2.1, 2.1]) * scale
    )
    positions -= cranium_center

    # Everything below is in the final frame (cranium centre at the origin).
    x, y, z = positions.T
    # The face is too flat for a fit to converge: an ellipsoid spanning its
    # extents, reaching forward to the nose, keeps long hair off the cheeks.
    face_points = (sz > 1.0) & (sy > -0.85) & (sy < 1.9) & (np.abs(sx) < 1.3)
    face_low, face_high = positions[face_points].min(axis=0), positions[face_points].max(axis=0)
    face_radii = (face_high - face_low) / 2 * np.array([1.0, 1.0, 1.6])
    face_center = np.array([(face_low[0] + face_high[0]) / 2, (face_low[1] + face_high[1]) / 2, face_high[2] - face_radii[2]])
    neck_points = (sy < -0.9) & (sy > -1.45) & (sz < 0.9)
    neck_center = positions[neck_points].mean(axis=0)
    neck_radius = float(np.median(np.hypot(x[neck_points] - neck_center[0], z[neck_points] - neck_center[2])))
    shoulder_points = sy < -1.9
    shoulders_center, shoulders_radii = fit_ellipsoid(positions[shoulder_points], positions[shoulder_points].mean(axis=0), np.ptp(positions[shoulder_points], axis=0) / 2)

    # Scalp map: rays from the cranium centre out through the ellipsoid.
    v0 = positions[triangles[:, 0]]
    e1 = positions[triangles[:, 1]] - v0
    e2 = positions[triangles[:, 2]] - v0
    scalp = np.zeros((SCALP_MAP_HEIGHT, SCALP_MAP_WIDTH, 6), dtype=np.float32)
    misses = 0
    for row in range(SCALP_MAP_HEIGHT):
        polar = row / (SCALP_MAP_HEIGHT - 1) * MAX_POLAR
        for col in range(SCALP_MAP_WIDTH):
            azimuth = col / SCALP_MAP_WIDTH * 2 * math.pi
            unit = np.array([math.sin(polar) * math.cos(azimuth), math.cos(polar), math.sin(polar) * math.sin(azimuth)])
            direction = unit * cranium_radii
            direction /= np.linalg.norm(direction)
            hit = ray_mesh(np.zeros(3), direction, v0, e1, e2)
            if hit is None:
                misses += 1
                point, normal = unit * cranium_radii, unit / cranium_radii
            else:
                t, index, bu, bv = hit
                point = direction * t
                a, b, c = triangles[index]
                normal = normals[a] * (1 - bu - bv) + normals[b] * bu + normals[c] * bv
            scalp[row, col, :3] = point
            scalp[row, col, 3:] = normal / np.linalg.norm(normal)

    # Quantise: positions to int16 over the bounding box, normals to int8.
    low, high = positions.min(axis=0), positions.max(axis=0)
    position_scale = (high - low) / 65535
    quantised_positions = np.round((positions - low) / position_scale - 32768).astype(np.int16)
    quantised_normals = np.round(normals / np.linalg.norm(normals, axis=1, keepdims=True) * 127).astype(np.int8)

    asset = {
        "credit": "Infinite, 3D Head Scan by Lee Perry-Smith (www.ir-ltd.net), CC BY 3.0, based on a work at www.triplegangers.com",
        "mesh": {
            "count": int(len(positions)),
            "positions": b64(quantised_positions),
            "positionLow": low.round(6).tolist(),
            "positionScale": position_scale.round(9).tolist(),
            "normals": b64(quantised_normals),
            "indices": b64(triangles.astype(np.uint16)),
        },
        "scalpMap": {"width": SCALP_MAP_WIDTH, "height": SCALP_MAP_HEIGHT, "maxPolar": MAX_POLAR, "data": b64(scalp)},
        "collision": {
            "cranium": {"center": [0, 0, 0], "radii": cranium_radii.round(4).tolist()},
            "face": {"center": face_center.round(4).tolist(), "radii": face_radii.round(4).tolist()},
            "neck": {"center": neck_center.round(4).tolist(), "radius": round(neck_radius, 4)},
            "shoulders": {"center": shoulders_center.round(4).tolist(), "radii": shoulders_radii.round(4).tolist()},
            "body": body_field(positions, triangles),
        },
    }
    OUTPUT.write_text(
        "// Generated by tools/head-asset/build_head_asset.py — do not edit.\n"
        "// " + asset["credit"] + "\n"
        "window.HEAD_ASSET = " + json.dumps(asset, separators=(",", ":")) + ";\n",
        encoding="utf-8",
    )
    print(json.dumps({k: v for k, v in asset["collision"].items() if k != "body"}, indent=1))
    print("scalp map misses:", misses, "| output:", OUTPUT, f"{OUTPUT.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
