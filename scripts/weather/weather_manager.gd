extends Node

signal weather_changed()

var weather_data: WeatherData


func set_weather(data: WeatherData):
	weather_data = data
	weather_changed.emit()
