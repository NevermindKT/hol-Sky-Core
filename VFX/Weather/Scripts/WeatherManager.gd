extends Node

signal weather_changed()

var weather_state: WeatherState


func set_weather(state: WeatherState):
	weather_state = state
	weather_changed.emit()
