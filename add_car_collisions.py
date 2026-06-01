import base64
import struct
import re

print("Starting injection of invisible car collisions...")

# 1. Parse Cars_29.tscn to get tile_map_data
cars_file = "scenes/maps/map (3) (1)/Cars_29.tscn"
try:
    with open(cars_file, "r") as f:
        cars_content = f.read()
except FileNotFoundError:
    print(f"Error: Could not find {cars_file}")
    exit(1)

match = re.search(r'tile_map_data = PackedByteArray\("([^"]+)"\)', cars_content)
if not match:
    print("Could not find tile_map_data in Cars_29.tscn")
    exit(1)

data_b64 = match.group(1)
binary_data = base64.b64decode(data_b64)

# 2. Extract grid positions (gx, gy) of all car tiles
cells = []
for i in range(0, len(binary_data), 12):
    cell = binary_data[i:i+12]
    if len(cell) < 12:
        break
    gx, gy, gz, source_id, atlas_x, atlas_y = struct.unpack('<hhhhhh', cell)
    cells.append((gx, gy))

# 3. Group by gy, and merge consecutive gx segments
from collections import defaultdict
by_row = defaultdict(list)
for gx, gy in cells:
    by_row[gy].append(gx)

segments = []
for gy, gxs in by_row.items():
    gxs.sort()
    start_gx = gxs[0]
    prev_gx = gxs[0]
    for gx in gxs[1:]:
        if gx == prev_gx + 1:
            prev_gx = gx
        else:
            segments.append((gy, start_gx, prev_gx))
            start_gx = gx
            prev_gx = gx
    segments.append((gy, start_gx, prev_gx))

print(f"Detected {len(cells)} car tiles. Merged into {len(segments)} optimized collision rectangles.")

# 4. Generate TSCN blocks
sub_resources = []
collision_nodes = []

for idx, (gy, gx_start, gx_end) in enumerate(segments):
    width = (gx_end - gx_start + 1) * 16
    height = 16
    cx = (gx_start + (gx_end - gx_start) / 2.0) * 16 + 8
    cy = gy * 16 + 8
    
    sub_res_id = f"RectangleShape2D_car_col_{idx}"
    sub_resources.append(f'[sub_resource type="RectangleShape2D" id="{sub_res_id}"]\nsize = Vector2({width}, {height})\n')
    collision_nodes.append(
        f'[node name="Collision_{idx}" type="CollisionShape2D" parent="Referance/Cars_Colliders" unique_id=987600{idx}]\n'
        f'position = Vector2({cx}, {cy})\n'
        f'shape = SubResource("{sub_res_id}")\n'
    )

# 5. Inject into Map.tscn
map_file = "scenes/maps/map (3) (1)/Map.tscn"
with open(map_file, "r") as f:
    map_content = f.read()

# Check if already injected
if "Cars_Colliders" in map_content:
    print("Car collisions are already injected!")
    exit(0)

# Insert sub-resources at the top (before the first [node)
first_node_idx = map_content.find("\n[node")
if first_node_idx == -1:
    print("Error: Could not find first node in Map.tscn")
    exit(1)

new_sub_resources_str = "\n" + "\n".join(sub_resources) + "\n"
map_content = map_content[:first_node_idx] + new_sub_resources_str + map_content[first_node_idx:]

# Insert StaticBody2D and CollisionShape2D nodes at the end of the Referance node
referance_insert_idx = map_content.find('[node name="Houses_28a"')
if referance_insert_idx == -1:
    print("Error: Could not find Houses_28a in Map.tscn")
    exit(1)

static_body_str = (
    '\n[node name="Cars_Colliders" type="StaticBody2D" parent="Referance" unique_id=987654321]\n\n'
    + "\n".join(collision_nodes)
    + "\n"
)

map_content = map_content[:referance_insert_idx] + static_body_str + map_content[referance_insert_idx:]

with open(map_file, "w") as f:
    f.write(map_content)

print("Successfully injected StaticBody2D and CollisionShape2D nodes into Map.tscn!")
