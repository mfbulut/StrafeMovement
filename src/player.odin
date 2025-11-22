package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

mouse_sensitivity    : f32 = 0.005
eye_height           : f32 = 0.6

move_speed           : f32 = 8.0
air_acceleration     : f32 = 2.0
ground_acceleration  : f32 = 3.0

friction             : f32 = 0.95
jump_force           : f32 = 2.0
gravity              : f32 = 4.0

Player :: struct {
	pos: Vector3,
	vel: Vector3,
	radius: f32,

	forward: Vector3,
	right: Vector3,

	camera_yaw: f32,
	camera_pitch: f32,

	grounded: bool,
}

player_input :: proc(player: ^Player, dt: f32) {
	mouse_delta := rl.GetMouseDelta()

	player.camera_yaw -= mouse_delta.x * mouse_sensitivity
	player.camera_pitch -= mouse_delta.y * mouse_sensitivity
	player.camera_pitch = clamp(player.camera_pitch, -1.5, 1.5)

	player.forward = linalg.normalize(Vector3{
		linalg.cos(player.camera_pitch) * linalg.sin(player.camera_yaw),
		linalg.sin(player.camera_pitch),
		linalg.cos(player.camera_pitch) * linalg.cos(player.camera_yaw),
	})

	player.right = linalg.normalize(linalg.cross(Vector3{0, 1, 0}, player.forward))

	wish_velocity := Vector3{0, 0, 0}

	if rl.IsKeyDown(.W) {
		wish_velocity += player.forward
	}

	if rl.IsKeyDown(.S) {
		wish_velocity -= player.forward
	}

	if rl.IsKeyDown(.A) {
		wish_velocity += player.right
	}

	if rl.IsKeyDown(.D) {
		wish_velocity -= player.right
	}

	wish_velocity.y = 0
	horizontal_length := linalg.length(Vector3{wish_velocity.x, 0, wish_velocity.z})
	if horizontal_length > 0.01 {
		wish_velocity.x /= horizontal_length
		wish_velocity.z /= horizontal_length
	}

	current_speed := linalg.dot(player.vel, wish_velocity)
	add_speed := move_speed - current_speed

	if add_speed > 0 {
		accel_speed := move_speed * dt
		if player.grounded {
			accel_speed *= ground_acceleration
		} else {
			accel_speed *= air_acceleration
		}

		if accel_speed > add_speed {
		    accel_speed = add_speed
		}

		player.vel += accel_speed * wish_velocity
	}

	player.vel.y -= gravity * dt

	if player.grounded {
		player.vel.x *= friction
		player.vel.z *= friction

		if rl.IsKeyDown(.SPACE) {
			player.vel.y = jump_force
			player.grounded = false
		}
	}

	// DEBUG
	if rl.IsKeyDown(.LEFT_SHIFT) {
		player.vel.y = jump_force * 2
		player.grounded = false
	}
}

player_get_camera :: proc(player: ^Player) -> rl.Camera {
	eye_pos := player.pos + {0, eye_height, 0}

	return rl.Camera{
		position = eye_pos,
		target = eye_pos + player.forward,
		up = {0.0, 1.0, 0.0},
		fovy = 70.0,
		projection = .PERSPECTIVE,
	}
}

player_physics :: proc(player: ^Player, dt: f32, collider: [dynamic]Triangle) {
	movement := player.vel * dt
	player.grounded = false

	for i in 0..<4 {
		if linalg.length(movement) < 0.0005 {
			return
		}

		for tri in collider {
			p1 := tri.p1
			p2 := tri.p2
			p3 := tri.p3
			normal := tri.normal

			distance := linalg.dot(player.pos, normal) - linalg.dot(normal, p1)
			movement_dot_normal := linalg.dot(movement, normal)

			if movement_dot_normal >= 0 do continue

			t0 := (-player.radius - distance) / movement_dot_normal
			t1 := (player.radius - distance) / movement_dot_normal

			if t0 > t1 { t0, t1 = t1, t0 }
			if t0 > 1.0 || t1 < 0.0 do continue
			t0 = max(t0, 0)

			intersection_point := player.pos + t0 * movement - normal * player.radius

			if point_in_triangle(intersection_point, p1, p2, p3) {
				if normal.y > 0.7 && player.vel.y <= 0 {
					player.grounded = true
				}

				move_dist := t0 * linalg.length(movement)
				player.pos += linalg.normalize(movement) * move_dist

				remaining_movement := movement * (1.0 - t0)
				movement = remaining_movement - normal * linalg.dot(remaining_movement, normal)

				vel_dot := linalg.dot(player.vel, normal)
				player.vel = player.vel - normal * vel_dot
			}
		}
	}

	player.pos += movement
}

point_in_triangle :: proc(point, pa, pb, pc: Vector3) -> bool {
	e10 := pb - pa
	e20 := pc - pa

	a := linalg.dot(e10, e10)
	b := linalg.dot(e10, e20)
	c := linalg.dot(e20, e20)

	ac_bb := (a * c) - (b * b)

	vp := point - pa

	d := linalg.dot(vp, e10)
	e := linalg.dot(vp, e20)

	x := (d * c) - (e * b)
	y := (e * a) - (d * b)
	z := x + y - ac_bb

	x_bits := transmute(u32)x
	y_bits := transmute(u32)y
	z_bits := transmute(u32)z

	return ((z_bits & ~(x_bits | y_bits)) & 0x80000000) != 0
}