import json, struct
import numpy as np


def load_glb(path):
    """Positions, normals, uvs and triangle indices of the scan's one mesh."""
    data = open(path, "rb").read()
    json_length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_length])
    bin_start = 20 + json_length + 8

    def accessor(index, dtype, size):
        a = gltf["accessors"][index]
        view = gltf["bufferViews"][a["bufferView"]]
        start = bin_start + view.get("byteOffset", 0)
        return np.frombuffer(data, dtype=dtype, count=a["count"] * size, offset=start).reshape(a["count"], size)

    p = gltf["meshes"][0]["primitives"][0]
    return (
        accessor(p["attributes"]["POSITION"], np.float32, 3).astype(np.float64),
        accessor(p["attributes"]["NORMAL"], np.float32, 3).astype(np.float64),
        accessor(p["attributes"]["TEXCOORD_0"], np.float32, 2).copy(),
        accessor(p["indices"], np.uint16, 1).reshape(-1, 3).copy(),
    )
