extends Node

@export var weather_data: WeatherData

func _ready():
	WeatherManager.set_weather(weather_data)
