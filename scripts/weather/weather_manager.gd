extends Node

var weather_data: WeatherData

func set_weather(data: WeatherData):
	weather_data = data
	Events.weather_changed.emit()
