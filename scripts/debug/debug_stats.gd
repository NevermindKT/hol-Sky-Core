extends Node
class_name debug_stats# Autoload, например "Debug_stats" или любой уже существующий у вас автолоад


#func _process(_delta: float) -> void:
	#if Engine.get_frames_per_second() < 100:
		#print("Frame drop")
	##print("query: min %.0f µs, max %.0f µs" % [Road_spine._q_min_usec, Road_spine._q_max_usec])
	#print("mark_dirty max: %d µs | apply_job max: %d µs | rebuild_cluster max: %d µs" % [
	#Ground_generator._mark_dirty_max_usec,
	#Ground_generator._apply_job_max_usec,
	#Ground_generator._rebuild_cluster_max_usec
	#])
	#Ground_generator._mark_dirty_max_usec = 0
	#Ground_generator._apply_job_max_usec = 0
	#Ground_generator._rebuild_cluster_max_usec = 0
#
	#Road_spine._q_min_usec = 999999999
	#Road_spine._q_max_usec = 0
