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

var player_freeView: bool = false
var player_targetLocked: bool = false
var player_targetAvailable: bool
var player_targetList: Array = []
var player_targetActive: CharacterBody3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	player_cameraTilt()
	controller_cameraView()
	

func _physics_process(delta):
	var input_direction = Input.get_vector("mv_left", "mv_right", "mv_foward", "mv_backward")
	player_gravity(delta)
	player_movement(input_direction)
	player_actionSprint(input_direction)
	move_and_slide()
	player_quit()
	player_targetLock(delta)

# First person camera for mouse and controller
func _unhandled_input(event: InputEvent):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and player_freeView == false:
		if event is InputEventMouseMotion:
			rotate_y(rad_to_deg(-event.relative.x * 0.00005 * mouse_sens))
			pivot.rotate_x(rad_to_deg(-event.relative.y * 0.00005 * mouse_sens))
			pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-50), deg_to_rad(60))
	
	# Enter free view mode
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("alt"):
		print("player on free View")
		player_freeView = true
		if event is InputEventMouseMotion:
			camera.rotate_y(rad_to_deg(-event.relative.x * 0.00005 * mouse_sens))
			camera.rotation_degrees.y = clamp(camera.rotation_degrees.y, -75,75)
	# Exit free view mode
	if Input.is_action_just_released("alt"):
		camera_tiltTween()
		player_freeView = false
		print("player exited free View")
	
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
	
	# Camera will not tilt on free View -Kepponn 10-04-2024
	if player_freeView == false:
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

func player_targetLock(delta):
	if Input.is_action_just_pressed("target_lock") and !player_targetLocked and player_targetAvailable:
		# Targeting enable when enemy are in target radius
		player_targetLocked = true
		# Disable camera input from both mouse and controller
		set_process_unhandled_input(false)
		# This loops the player_targetList[] and search for the nearest target to the player
		# Maybe make this a standalone function? maybe it will be used for other things in the future...
		var nearestDistance = INF
		for player_target in player_targetList:
			var distanceSquared = position.distance_squared_to(player_target.position)
			if distanceSquared < nearestDistance:
				nearestDistance = distanceSquared
				player_targetActive = player_target
				print("Target locked to ", player_targetActive, " with ", position.distance_squared_to(player_targetActive.position), " distance")
		# This check the distance between the player position and the enemy pos stored in player_targetActive
		# This could be use before everything else to check the nearest enemy and lock into it!
	elif Input.is_action_just_pressed("target_lock") and player_targetLocked:
		# Targeting released manually
		player_targetLocked = false
		# Enable camera input from both mouse and controller
		set_process_unhandled_input(true)
		print("Target unlocked from ", player_targetActive)
		player_targetActive = null
	
	if player_targetLocked:
		# There is 2 key for gamepad that is joypad_tc+ and joypad_tc- because for some reason it can not have both axis+ and axis- in the same input name action, it will read the top most keys
		# TEST mwheel-up/down both use 1 spin sensitivity which make the change really sensitive, need to tune it down
		if (Input.is_action_just_pressed("target_change") or Input.is_action_just_pressed("joypad_tc+") or Input.is_action_just_pressed("joypad_tc-")) and player_targetList.size() > 1:
			# Ref the main target and remove it form the arrays and send it back
			player_targetList.remove_at(player_targetList.find(player_targetActive))
			player_targetList.append(player_targetActive)
			print("Changing target from ", player_targetActive," to ", player_targetList[0])
			player_targetActive = player_targetList[0]
		# Advance version of look_at(player_targetActive) which smoothen the camera view
		var target_direction = (player_targetActive.position - global_transform.origin).normalized()
		var target_rotation = Basis.looking_at(target_direction, Vector3(0, 1, 0))
		var player_cameraLockTarget = global_transform.basis.slerp(target_rotation, delta * 5)
		# BUG debugger about orthonormalized is required or something...
		# This BUG is recreatable if you do 180deg spin to lock-on to enemies
		#E 0:00:11:0362 player.gd:191 @ player_targetLock(): Basis must be normalized in order to be casted to a Quaternion. Use get_rotation_quaternion() or call orthonormalized() if the Basis contains linearly independent vectors.
		#<C++ Error>    Condition "!is_rotation()" is true. Returning: Quaternion()
		#<C++ Source>   core/math/basis.cpp:710 @ get_quaternion()
		#<Stack Trace>  player.gd:191 @ player_targetLock()
		#               player.gd:40 @ _process()
		global_transform.basis = player_cameraLockTarget

func _on_target_area_body_entered(body):
	# This check for all bodies including those which static? 
	# Adding filter changer into param [body: filter] does work but the debugger didn't like it...
	# The filtering is on collision layer and mask
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
