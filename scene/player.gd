extends CharacterBody3D

var speed: float = 5.0
var speed_sprint: float = 7.0
const speed_default: float = 5.0
const jump_velocity: float = 5.0 # Default value is 4.5

var player_ableToWallJump: bool
const jump_modifierWallJump:= 2
var player_ableToDoubleJump: bool
const jump_modifierDoubleJump:= -1

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var added_mass: float = 6.2

@onready var camera := $CameraPivot/Camera3D
@onready var pivot := $CameraPivot
@onready var sens: float = Settings.mouse_sensitivity

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# First person camera
func _unhandled_input(event: InputEvent):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(rad_to_deg(-event.relative.x * 0.00005 * sens))
			pivot.rotate_x(rad_to_deg(-event.relative.y * 0.00005 * sens))
			pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-50), deg_to_rad(60))

func _physics_process(delta):
	var input_direction = Input.get_vector("mv_left", "mv_right", "mv_foward", "mv_backward")
	player_gravity(delta)
	player_movement(input_direction)
	player_cameraTilt()
	player_actionSprint(input_direction)
	move_and_slide()
	player_quit()

func player_gravity(delta):
	if not is_on_floor():
		velocity.y -= (gravity + added_mass) * delta

func player_movement(input_direction: Vector2):
	player_jump()
	# WASD Movement
	var direction = (transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func player_jump():
	# Jump priority (if all condition are met): Default -> Wall-jump -> Double-jump
	# Default-jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		# Bunny hopping with holding space with Input.is_action_pressed()
		# The default is Input.is_action_just_pressed()
		print('Default-jump')
		velocity.y = jump_velocity
	# Wall-jump
	elif Input.is_action_just_pressed("ui_accept") and is_on_wall_only() and player_ableToWallJump:
		player_ableToWallJump = false
		print('Wall-jump')
		velocity.y = jump_velocity + jump_modifierWallJump
	# Double-jump
	elif Input.is_action_just_pressed("ui_accept") and not is_on_floor() and player_ableToDoubleJump:
		player_ableToDoubleJump = false
		print('Double-jump')
		velocity.y = jump_velocity + jump_modifierDoubleJump
	# Being on floor reset everything
	if is_on_floor():
		player_ableToDoubleJump = true
		player_ableToWallJump = true

func player_cameraTilt():
	# Camera tilt to right is negative and left is positive
	if Input.is_action_just_released("mv_left") or Input.is_action_just_released("mv_right"):
		camera_tiltTween()
	if Input.is_action_pressed("mv_left") and Input.is_action_pressed("mv_shift"):
		camera_tiltTween(0.025) # Default value is 0.015
	if Input.is_action_pressed("mv_right") and Input.is_action_pressed("mv_shift"):
		camera_tiltTween(-0.025) # Default value is -0.015

func player_actionSprint(input_direction: Vector2):
	if input_direction != Vector2.ZERO and Input.is_action_pressed("mv_shift"):
		speed = speed_sprint
		camera_fovTween(90)
		player_audioSfxStep(input_direction, 0.35, 18)
	else:
		speed = speed_default
		camera_fovTween(75)
		player_audioSfxStep(input_direction, 0.5)

func player_audioSfxStep(input_direction: Vector2, audio_interval: float = 0.5, audio_volume: int = 16):
	if input_direction != Vector2.ZERO and is_on_floor():
		if $Timer/SfxStepCooldown.time_left <= 0:
			var SfxStep = $SfxStep.get_children()
			var SfxStepPicker = SfxStep[randi() % SfxStep.size()]
			SfxStepPicker.volume_db = audio_volume
			SfxStepPicker.pitch_scale = randf_range(0.8, 1.2)
			SfxStepPicker.play()
			$Timer/SfxStepCooldown.start(audio_interval)

func camera_tiltTween(tilt_degree: float = 0):
	var cameraTween = get_tree().create_tween()
	cameraTween.tween_property(camera, "rotation", Vector3(0, 0, tilt_degree), 0.25)

func camera_fovTween(fov: int):
	var cameraTween = get_tree().create_tween()
	cameraTween.tween_property(camera, "fov", fov, 0.25)

func player_quit():
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
