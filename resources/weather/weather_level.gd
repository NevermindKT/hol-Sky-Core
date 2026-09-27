extends Resource
class_name WeatherLevel

@export_group("Transitions")
@export_range(0.0, 100.0, 0.1, "suffix:%") var chance_intensify := 33.3
@export_range(0.0, 100.0, 0.1, "suffix:%") var chance_weaken := 33.3
