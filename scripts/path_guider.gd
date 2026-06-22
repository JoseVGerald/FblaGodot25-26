class_name PathGuider
extends Node2D

var curve: Curve2D
var width: float = 3.0
var base_color: Color = Color(0.96, 0.93, 0.58, 0.5) # Simple semi-transparent light yellow
var arrow_color: Color = Color(0.96, 0.93, 0.58, 1.0) # Solid simple light yellow

var arrow_spacing: float = 100.0 # spacing between static arrows
var pixel_size: float = 3.0      # size of each pixel in the chevron

# Relative pixel coordinates for a 2-pixel-thick retro pixel-art chevron
# Pointing right (positive X)
const PIXELS = [
	Vector2(-2, -3), Vector2(-1, -3),
	Vector2(-1, -2), Vector2(0, -2),
	Vector2(0, -1), Vector2(1, -1),
	Vector2(1, 0), Vector2(2, 0),
	Vector2(0, 1), Vector2(1, 1),
	Vector2(-1, 2), Vector2(0, 2),
	Vector2(-2, 3), Vector2(-1, 3)
]

# Take a Path2D node, extract waypoints, and build a smooth Curve2D
func setup_path(path2d: Path2D, p_width: float = 3.0, p_color: Color = Color(0.96, 0.93, 0.58, 0.5)) -> void:
	width = p_width
	base_color = p_color
	arrow_color = Color(p_color.r, p_color.g, p_color.b, 1.0) # Solid matching color
	
	if not path2d or not path2d.curve:
		return
		
	# Extract raw editor waypoints
	var raw_points = PackedVector2Array()
	for i in range(path2d.curve.point_count):
		raw_points.append(path2d.curve.get_point_position(i))
		
	curve = Curve2D.new()
	curve.bake_interval = 5.0 # Smooth interpolation
	
	if raw_points.size() < 2:
		return
		
	if raw_points.size() == 2:
		# Simple line for 2 points
		curve.add_point(raw_points[0])
		curve.add_point(raw_points[1])
	else:
		# Smooth spline calculation
		var p0 = raw_points[0]
		var p1 = raw_points[1]
		var dir_start = (p1 - p0).normalized()
		var dist_start = p0.distance_to(p1)
		curve.add_point(p0, Vector2.ZERO, dir_start * (dist_start * 0.25))
		
		for i in range(1, raw_points.size() - 1):
			var prev = raw_points[i-1]
			var curr = raw_points[i]
			var next = raw_points[i+1]
			
			var d_prev = curr.distance_to(prev)
			var d_next = curr.distance_to(next)
			var factor = min(d_prev, d_next) * 0.25
			
			var tangent = (next - prev).normalized()
			var control_in = -tangent * factor
			var control_out = tangent * factor
			curve.add_point(curr, control_in, control_out)
			
		var pn = raw_points[raw_points.size() - 1]
		var pn_prev = raw_points[raw_points.size() - 2]
		var dir_end = (pn_prev - pn).normalized()
		var dist_end = pn.distance_to(pn_prev)
		curve.add_point(pn, dir_end * (dist_end * 0.25), Vector2.ZERO)

func _draw() -> void:
	if not curve or curve.get_baked_points().size() < 2:
		return
		
	var points = curve.get_baked_points()
	
	# Draw simple thin guidance line (no borders, no glows)
	draw_polyline(points, base_color, width, true)
	
	# Draw static pixelated arrows along the path
	var length = curve.get_baked_length()
	if length < 10.0:
		return
		
	if length < arrow_spacing:
		_draw_arrow(length / 2.0)
	else:
		var offset = arrow_spacing / 2.0
		while offset < length:
			if offset < length - 6.0:
				_draw_arrow(offset)
			offset += arrow_spacing

func _draw_arrow(offset: float) -> void:
	var trans = curve.sample_baked_with_rotation(offset)
	
	# Draw the pixelated chevron using relative pixel offsets
	for pixel in PIXELS:
		var local_pos = pixel * pixel_size
		var v0 = trans * local_pos
		var v1 = trans * (local_pos + Vector2(pixel_size, 0))
		var v2 = trans * (local_pos + Vector2(pixel_size, pixel_size))
		var v3 = trans * (local_pos + Vector2(0, pixel_size))
		
		draw_colored_polygon(PackedVector2Array([v0, v1, v2, v3]), arrow_color)
