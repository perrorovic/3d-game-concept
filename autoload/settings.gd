extends Node

var mouse_sensitivity: float = 0.67
var joystick_deadzone : float = 0
var joystick_v_sensitivity : int = 3
var joystick_h_sensitivity : int = 2

func _ready():
	# Input accumulation can be disabled to get slightly more precise/reactive input at the cost of increased CPU usage
	Input.set_use_accumulated_input(false)
