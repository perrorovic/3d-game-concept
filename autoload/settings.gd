extends Node

var mouse_sensitivity: float = 0.67

func _ready():
	# Input accumulation can be disabled to get slightly more precise/reactive input at the cost of increased CPU usage
	Input.set_use_accumulated_input(false)
