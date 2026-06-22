class_name PathGuider
extends Node2D

var curve: Curve2D
var width: float = 6.0
var base_color: Color = Color(1.0, 0.9, 0.1)
var arrow_color: Color = Color(1.0, 0.9, 0.0)

var arrow_phase: float = 0.0
var arrow_speed: float = 140.0 # pixels per second for flow animation
var arrow_spacing: float = 75.0 # distance between chevrons
var arrow_scale: float = 1.35   # size factor of chevrons

# Chevron arrow points (facing positive X / right in local space)
# Sleek modern chevron design:
# Tip at (12, 0)
# Top-back at (-8, -8)
# Inner indent at (-4, 0) for chevron effect
# Bottom-back at (-8, 8)
var arrow_poly = PackedVector2Array([
	Vector2(12, 0),
	Vector2(-8, -8),
	Vector2(-4, 0),
	Vector2(-8, 8)
])

# Process to update the arrow animation offset
func _process(delta: float) -> void:
	arrow_phase += delta * arrow_speed
	if arrow_phase >= arrow_spacing:
		arrow_phase = fmod(arrow_phase, arrow_spacing)
	queue_redraw()

# Take a Path2D node, extract waypoints, and build a smooth Curve2D
func setup_path(path2d: Path2D, p_width: float = 6.0, p_color: Color = Color(1.0, 0.9, 0.1)) -> void:
	width = p_width
	base_color = p_color
	arrow_color = Color(1.0, 0.9, 0.0, 1.0) # Vibrant solid yellow for arrows
	
	if not path2d or not path2d.curve:
		return
		
	# Extract the raw editor waypoints
	var raw_points = PackedVector2Array()
	for i in range(path2d.curve.point_count):
		raw_points.append(path2d.curve.get_point_position(i))
		
	curve = Curve2D.new()
	curve.bake_interval = 5.0 # Smooth interpolation
	
	if raw_points.size() < 2:
		return
		
	if raw_points.size() == 2:
		# Simple line for just 2 points
		curve.add_point(raw_points[0])
		curve.add_point(raw_points[1])
	else:
		# Generate a smooth spline using cubic Bézier tangent calculation
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
			# Control length is proportional to segment length to avoid overshoot loops
			var factor = min(d_prev, d_next) * 0.25
			
			# Tangent parallel to the line from previous to next waypoint
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
	
	# --- DRAW GLOWING GUIDANCE PATH ---
	# Outer soft halo (glow effect)
	draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, 0.12), width * 2.5, true)
	# Medium core glow
	draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, 0.28), width * 1.5, true)
	# Sharp main guidance line
	draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, 0.7), width * 0.7, true)
	# Hot bright inner core
	draw_polyline(points, Color(1.0, 1.0, 0.75, 0.95), width * 0.25, true)
	
	# --- DRAW ANIMATED FLOWING ARROWS ---
	var length = curve.get_baked_length()
	if length < 10.0:
		return
		
	if length < arrow_spacing:
		# Short path: place a single centered arrow
		_draw_arrow(length / 2.0)
	else:
		var offset = arrow_phase
		while offset < length:
			# Prevent drawing an arrow too close to the end point to avoid clipping
			if offset < length - 6.0:
				_draw_arrow(offset)
			offset += arrow_spacing

func _draw_arrow(offset: float) -> void:
	# Get rotation and position at offset
	var trans = curve.sample_baked_with_rotation(offset)
	
	# 1. Dark background polygon (outline effect to pop out on any background)
	var border_poly = PackedVector2Array()
	for p in arrow_poly:
		border_poly.append(trans * (p * arrow_scale * 1.3))
	# Translucent dark outline
	draw_colored_polygon(border_poly, Color(0.05, 0.05, 0.05, 0.8))
	
	# 2. Main bright yellow chevron fill
	var fill_poly = PackedVector2Array()
	for p in arrow_poly:
		fill_poly.append(trans * (p * arrow_scale))
	draw_colored_polygon(fill_poly, arrow_color)
