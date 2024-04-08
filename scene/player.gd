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
@onready var JOY_CAMERA_X: float
@onready var JOY_CAMERA_Y: float

@onready var mouse_sens: float = Settings.mouse_sensitivity
@onready var joy_deadzone: float = Settings.joystick_deadzone
@onready var joy_h_sens: float = Settings.joystick_h_sensitivity
@onready var joy_v_sens: float = Settings.joystick_v_sensitivity

var player_targetLocked: bool = false
var player_targetAvailable: bool
# var player_targetList: CharacterBody3D 
# Make this as array with body ref which can be targeted? and remove those if cannot be targeted?
var player_targetList: Array = []
var player_targetActive: CharacterBody3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _process(_delta):
	player_cameraTilt()
	controller_cameraView()
	player_targetLock()
	
func _physics_process(delta):
	var input_direction = Input.get_vector("mv_left", "mv_right", "mv_foward", "mv_backward")
	player_gravity(delta)
	player_movement(input_direction)
	player_actionSprint(input_direction)
	move_and_slide()
	player_quit()

# First person camera for mouse and controller
func _unhandled_input(event: InputEvent):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(rad_to_deg(-event.relative.x * 0.00005 * mouse_sens))
			pivot.rotate_x(rad_to_deg(-event.relative.y * 0.00005 * mouse_sens))
			pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-50), deg_to_rad(60))
	if event is InputEventJoypadMotion:
		if event.get_axis() == JOY_AXIS_RIGHT_Y:
			if abs(event.get_axis_value()) > joy_deadzone:
				JOY_CAMERA_X = -(event.get_axis_value() * 0.0005 * joy_h_sens)
			else:
				JOY_CAMERA_X = 0
		elif event.get_axis() == JOY_AXIS_RIGHT_X:
			if abs(event.get_axis_value()) > joy_deadzone:
				JOY_CAMERA_Y = -(event.get_axis_value() * 0.0005 * joy_v_sens)
			else:
				JOY_CAMERA_Y = 0

# Process for controller camera view
func controller_cameraView():
	rotate_y(rad_to_deg(JOY_CAMERA_Y))
	pivot.rotation.x += rad_to_deg(JOY_CAMERA_X)
	pivot.rotation.x = clamp(pivot.rotation.x,deg_to_rad(-50),deg_to_rad(60))

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
		#print('Default-jump')
		velocity.y = jump_velocity
	# Wall-jump
	elif Input.is_action_just_pressed("ui_accept") and is_on_wall_only() and player_ableToWallJump:
		player_ableToWallJump = false
		#print('Wall-jump')
		velocity.y = jump_velocity + jump_modifierWallJump
	# Double-jump
	elif Input.is_action_just_pressed("ui_accept") and not is_on_floor() and player_ableToDoubleJump:
		player_ableToDoubleJump = false
		#print('Double-jump')
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
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func player_targetLock():
	if Input.is_action_just_pressed("target_lock") and !player_targetLocked and player_targetAvailable:
		# Targeting enable when enemy are in target radius
		player_targetLocked = true
		# Disable camera input from both mouse and controller
		set_process_unhandled_input(false)
		player_targetActive = player_targetList[0]
		print("Target locked from ", player_targetActive)
	elif Input.is_action_just_pressed("target_lock") and player_targetLocked:
		# Targeting released manually
		player_targetLocked = false
		# Enable camera input from both mouse and controller
		set_process_unhandled_input(true)
		print("Target unlocked from ", player_targetActive)
		player_targetActive = null
	
	# BUG Need to check for the distance of the enemies for example:
	# There is two enemy in list. [1] is closer to the player than [0]
	# Therefore it SHOULD target [1] the closer one, but for now it target [0] which entered the area first.
	
	if player_targetLocked:
		if Input.is_action_just_pressed("target_change") and player_targetList.size() > 1:
			print("Target is more than 1 and now changing target!")
			# I dont know how to do this part, how to make a loopback arrays?
			# player_targetActive = player_targetList[(player_targetList.find(player_targetActive)+1)]
			# I mean this does work... but it does looks stupid
			player_targetList.pop_front()
			player_targetList.append(player_targetActive)
			player_targetActive = player_targetList[0]
			# TEST The fact that D-pad left and right didnt see the enemy position whatsoever
			# And also mwheel-up/down both use 1 spin sensitivity which make the change really sensitive...
		# This is currently static, should be property of [body] from target area radius
		# look_at(player_targetList.position)
		look_at(player_targetActive.position)

func _on_target_area_body_entered(body):
	# This check for all bodies including those which static? 
	# Adding filter changer into param [body: filter] does work but the debugger didn't like it...
	# Def need filter but idc for now
	if body.name == 'Enemy' or body.name == 'Enemy2' or body.name == 'Enemy3':
		player_targetAvailable = true
		# Add target into the list if there is any
		player_targetList.append(body)
		print(player_targetList.size(), " Enemy target in vicinity")

func _on_target_area_body_exited(body):
	if body.name == 'Enemy' or body.name == 'Enemy2' or body.name == 'Enemy3':
		player_targetList.erase(body)
		print(player_targetList.size(), " Enemy target in vicinity")
		# What if there is mutiple target side by side?
		# Check which target is leaving? is it the one player currently targeting?
		# If yes then break the targeting because enemy are out of area radius
		if player_targetActive == body:
			player_targetLocked = false
			player_targetAvailable = false
			set_process_unhandled_input(true)
