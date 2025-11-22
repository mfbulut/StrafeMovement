package main

import plm "plmpeg"

import "base:runtime"
import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

width :: 1280
height :: 720

Vector3 :: rl.Vector3

Triangle :: struct {
	p1:     Vector3,
	p2:     Vector3,
	p3:     Vector3,
	normal: Vector3,
}

collider: [dynamic]Triangle

video_pixels: [width * height]rl.Color
video_texture: rl.Texture2D
VIDEO_MPG :: #load("assets/knife2.mpg")

video_callback :: proc "c" (plmpeg_ctx: ^plm.ctx, frame: ^plm.frame_ctx, user: rawptr) {
	context = runtime.default_context()

	if frame != nil {
		for py in 0 ..< height {
			for px in 0 ..< width {
				y_idx := py * width + px
				c_idx := (py / 2) * width / 2 + (px / 2)

				y := frame.y.data[y_idx]
				cb := frame.cb.data[c_idx]
				cr := frame.cr.data[c_idx]

				video_pixels[py * width + px] = rl.Color{y, cb, cr, 255}
			}
		}

		rl.UpdateTexture(video_texture, &video_pixels[0])
	}
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(width, height, "First Person")
	rl.DisableCursor()

	video_shader := rl.LoadShaderFromMemory(video_vs_code, video_fs_code)
	model_shader := rl.LoadShaderFromMemory(vs_code, fs_code)
	viewPosLoc := rl.GetShaderLocation(model_shader, "viewPos")

	model := rl.LoadModel("assets/surf_ski.glb")
	add_collider(model)

	for &material in model.materials[:model.materialCount] {
		material.shader = model_shader
	}

	model2 := rl.LoadModel("assets/de_dust2.glb")

	add_collider(model2)

	for &material in model2.materials[:model2.materialCount] {
		material.shader = model_shader
	}

	player := Player {
		pos    = {-7, 15, -28},
		radius = 0.2,
	}

	ctx := plm.create_with_memory(raw_data(VIDEO_MPG), len(VIDEO_MPG), 0)
	plm.set_audio_enabled(ctx, 0)
	plm.set_loop(ctx, 0) // Disable looping
	plm.set_video_decode_callback(ctx, video_callback, nil)

	img := rl.GenImageColor(width, height, rl.BLANK)
	video_texture = rl.LoadTextureFromImage(img)
	plm.seek(ctx, 0, 1)
	video_timer: f32 = 0.0

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		if player.pos.y < -15 {
			move_speed = 4.0
			air_acceleration = 1.0
			ground_acceleration = 10.0

			friction = 0.94
			jump_force = 2.5
			gravity = 6.0
		}

		if rl.IsKeyPressed(.R) {
			player.pos = {-7, 15, -28}
			move_speed = 8.0
			air_acceleration = 2.0
			ground_acceleration = 3.0

			friction = 0.95
			jump_force = 2.0
			gravity = 4.0
		}

		if rl.IsKeyPressed(.F) {
			plm.seek(ctx, 0.1, 1)
			video_timer = 6
		}

		if video_timer > 0 {
			video_timer -= dt
			plm.decode(ctx, f64(dt))

			if video_timer <= 0 {
				plm.seek(ctx, 0, 1)
			}
		}

		player_input(&player, dt)
		player_physics(&player, dt, collider)

		camera := player_get_camera(&player)
		rl.BeginDrawing()
		rl.ClearBackground(rl.SKYBLUE)
		rl.BeginMode3D(camera)

		rl.SetShaderValue(model_shader, viewPosLoc, &camera.position, .VEC3)
		rl.DrawModel(model, {0, 0, 0}, 1, rl.WHITE)
		rl.DrawModel(model2, {0, 0, 0}, 1, rl.WHITE)

		rl.EndMode3D()

		rl.BeginShaderMode(video_shader)
		rl.DrawTexture(video_texture, 0, 0, rl.WHITE)
		rl.EndShaderMode()

		rl.DrawText(fmt.ctprintf("Speed: %.2f", linalg.length(player.vel)), 10, 10, 20, rl.BLACK)

		rl.EndDrawing()
	}
}

vs_code :: `
#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform mat4 matModel;

out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;
out vec3 fragPosition;

void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    fragNormal = mat3(matModel) * vertexNormal;
    fragPosition = vec3(matModel * vec4(vertexPosition, 1.0));
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
`

fs_code :: `
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;
in vec3 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec3 viewPos;

out vec4 finalColor;

void main()
{
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.2));
    vec3 lightColor = vec3(1.0, 1.0, 1.0);

    vec3 ambientColor = vec3(0.3, 0.3, 0.3);
    float specularStrength = 0.5;
    float shininess = 64.0;

    vec4 texelColor = texture(texture0, fragTexCoord);
    vec3 normal = normalize(fragNormal);
    vec3 viewDir = normalize(viewPos - fragPosition);

    vec3 ambient = ambientColor * lightColor;

    float diffuse = max(dot(normal, lightDir), 0.0);
    vec3 diffuseColor = diffuse * lightColor;

    vec3 halfwayDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfwayDir), 0.0), shininess);
    vec3 specular = specularStrength * spec * lightColor;

    vec3 lighting = ambient + diffuseColor + specular;

    finalColor = texelColor * colDiffuse * fragColor * vec4(lighting, 1.0);
}
`

video_vs_code :: `
#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;

uniform mat4 mvp;

out vec2 fragTexCoord;

void main()
{
    fragTexCoord = vertexTexCoord;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
`

video_fs_code :: `
#version 330

in vec2 fragTexCoord;
uniform sampler2D texture0;
uniform vec4 colDiffuse;

out vec4 finalColor;

void main()
{
    vec4 ycbcr = texture(texture0, fragTexCoord);

    float y  = ycbcr.r;
    float cb = ycbcr.g - 0.5;
    float cr = ycbcr.b - 0.5;

    float r = y + 1.402 * cr;
    float g = y - 0.344136 * cb - 0.714136 * cr;
    float b = y + 1.772 * cb;

    vec3 rgb = vec3(r, g, b);

    float greenThreshold = 0.07;
    float greenTolerance = 0.2;

    float greenStrength = rgb.g - max(rgb.r, rgb.b);

    float alpha = 1.0 - smoothstep(greenThreshold, greenThreshold + greenTolerance, greenStrength);

    finalColor = vec4(rgb, alpha) * colDiffuse;
}
`

set_model_shader :: proc(model: ^rl.Model) {
	shader := rl.LoadShaderFromMemory(vs_code, fs_code)

	for i in 0 ..< model.materialCount {
		model.materials[i].shader = shader
	}
}

add_collider :: proc(model: rl.Model) {
	for mesh in model.meshes[:model.meshCount] {
		triangles := transmute([^][3]f32)mesh.vertices
		indicies := transmute([^][3]u16)mesh.indices

		for triangle in indicies[:mesh.triangleCount] {
			p1 := triangles[triangle[0]]
			p2 := triangles[triangle[1]]
			p3 := triangles[triangle[2]]
			normal := linalg.normalize(linalg.cross(p2 - p1, p3 - p1))
			append(&collider, Triangle{p1, p2, p3, normal})
		}
	}
}
