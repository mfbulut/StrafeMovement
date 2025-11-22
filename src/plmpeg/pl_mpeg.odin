package plmpeg

import "core:c"


when ODIN_OS == .Windows {
	foreign import plmpeg "pl_mpeg.lib"
} else when ODIN_OS == .Linux {
	foreign import plmpeg "pl_mpeg.a"
}


ctx :: struct {}

frame_ctx :: struct {
	time:   f64,
	width:  c.uint,
	height: c.uint,
	y:      plane_ctx,
	cr:     plane_ctx,
	cb:     plane_ctx,
}

plane_ctx :: struct {
	width:  c.uint,
	height: c.uint,
	data:   [^]u8,
}

// Callback types
video_decode_callback :: #type proc "c" (self: ^ctx, frame: ^frame_ctx, user: rawptr)
audio_decode_callback :: #type proc "c" (self: ^ctx, samples: rawptr, user: rawptr)

@(default_calling_convention = "c", link_prefix = "plm_")
foreign plmpeg {
	create_with_filename :: proc(filename: cstring) -> ^ctx ---
	create_with_memory :: proc(bytes: rawptr, length: c.size_t, free_when_done: c.int) -> ^ctx ---
	destroy :: proc(self: ^ctx) ---
	has_headers :: proc(self: ^ctx) -> c.int ---
	get_width :: proc(self: ^ctx) -> c.int ---
	get_height :: proc(self: ^ctx) -> c.int ---
	get_framerate :: proc(self: ^ctx) -> f64 ---
	set_audio_enabled :: proc(self: ^ctx, enabled: c.int) ---
	set_video_enabled :: proc(self: ^ctx, enabled: c.int) ---
	decode :: proc(self: ^ctx, seconds: f64) -> c.int ---
	decode_video :: proc(self: ^ctx) -> ^frame_ctx ---
	rewind :: proc(self: ^ctx) ---
	has_ended :: proc(self: ^ctx) -> c.int ---
	get_loop :: proc(self: ^ctx) -> c.int ---
	set_loop :: proc(self: ^ctx, loop: c.int) ---
	set_video_decode_callback :: proc(self: ^ctx, fp: video_decode_callback, user: rawptr) ---
	set_audio_decode_callback :: proc(self: ^ctx, fp: audio_decode_callback, user: rawptr) ---
	seek :: proc(self: ^ctx, time: c.double, seek_exact: c.int) ---
}
