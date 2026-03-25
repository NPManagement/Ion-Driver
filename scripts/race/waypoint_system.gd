## WaypointSystem — Defines the racing line and provides path utilities.
extends Node
class_name WaypointSystem

## Center-line waypoints of the track (world space, at track surface height).
## Set by the TrackGenerator after building the track.
var waypoints: Array[Vector3] = []
var total_length: float = 0.0

func set_waypoints(pts: Array[Vector3]) -> void:
	waypoints    = pts
	total_length = _calc_total_length()

func _calc_total_length() -> float:
	var len := 0.0
	for i in waypoints.size():
		var a := waypoints[i]
		var b := waypoints[(i + 1) % waypoints.size()]
		len += a.distance_to(b)
	return len

## Returns distance along the path for a world position (approximation).
func get_path_distance(world_pos: Vector3) -> float:
	if waypoints.is_empty():
		return 0.0
	var best_dist  := INF
	var best_seg   := 0
	var best_t     := 0.0

	for i in waypoints.size():
		var a := waypoints[i]
		var b := waypoints[(i + 1) % waypoints.size()]
		var t := _project_point_segment(world_pos, a, b)
		var pt := a.lerp(b, t)
		var d  := world_pos.distance_to(pt)
		if d < best_dist:
			best_dist = d
			best_seg  = i
			best_t    = t

	var dist := 0.0
	for i in best_seg:
		dist += waypoints[i].distance_to(waypoints[(i + 1) % waypoints.size()])
	dist += waypoints[best_seg].distance_to(waypoints[(best_seg + 1) % waypoints.size()]) * best_t
	return dist

func _project_point_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return 0.0
	return clampf(ab.dot(p - a) / len_sq, 0.0, 1.0)

## Returns the nearest waypoint index to a world position.
func nearest_waypoint(world_pos: Vector3) -> int:
	var best := 0
	var best_dist := INF
	for i in waypoints.size():
		var d := world_pos.distance_to(waypoints[i])
		if d < best_dist:
			best_dist = d
			best = i
	return best

## Returns the waypoint ahead of an index (for AI look-ahead).
func lookahead(from_idx: int, count: int = 3) -> Vector3:
	return waypoints[(from_idx + count) % waypoints.size()]
