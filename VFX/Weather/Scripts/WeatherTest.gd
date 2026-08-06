extends Node

@export var weather_state: WeatherState

func _ready():
	WeatherManager.set_weather(weather_state)
