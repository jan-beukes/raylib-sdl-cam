const SDL = @import("SDL3.zig");
const rl = @import("raylib");
const std = @import("std");

// glob
var camera: ?*SDL.Camera = undefined;

pub fn init(window_height: *i32, window_width: i32) !void {
    if (!SDL.Init(SDL.INIT_CAMERA)) {
        SDL.Log("WHATTATT %s", SDL.GetError());
        return error.InitFailed;
    }
    var devcount: i32 = 0;
    const devices = SDL.GetCameras(&devcount);
    if (devices == null) {
        SDL.Log("Couldnt enumerate devices: %s", SDL.GetError());
        return error.CamerasBro;
    } else if (devcount == 0) {
        SDL.Log("Couldnt find any devices! Please connect Camera brother");
        return error.What;
    }

    var format_count: c_int = 0;
    const formats = SDL.GetCameraSupportedFormats(devices[0], &format_count);
    defer SDL.free(@ptrCast(formats));

    var max_fps: c_int = 0;
    var best_format: [*c]SDL.CameraSpec = null;
    for (0..@intCast(format_count)) |i| {
        if (formats[i].*.framerate_numerator > max_fps) {
            max_fps = formats[i].*.framerate_numerator;
            best_format = formats[i];
        }
    }

    camera = SDL.OpenCamera(devices[0], best_format); //use first device

    SDL.free(devices);
    if (camera == null) {
        SDL.Log("Couldn't open camera: %s", SDL.GetError());
        return error.NoCameraBro;
    }

    // get spec
    var spec: SDL.CameraSpec = undefined;
    if (SDL.GetCameraFormat(camera, &spec)) {
        const fwindow_width: f32 = @floatFromInt(window_width);
        const fwidth: f32 = @floatFromInt(spec.width);
        const fheight: f32 = @floatFromInt(spec.height);
        window_height.* = @intFromFloat((fheight / fwidth) * fwindow_width);
    }
}

pub fn denit() void {
    SDL.CloseCamera(camera);
    SDL.Quit();
}

pub fn handleEvents() void {
    var e: SDL.Event = undefined;
    while (SDL.PollEvent(&e)) {
        if (e.type == SDL.EVENT_CAMERA_DEVICE_APPROVED) {
            SDL.Log("Camera use approved!");
        } else if (e.type == SDL.EVENT_CAMERA_DEVICE_DENIED) {
            SDL.Log("Camera use denied!");
        }
    }
}

pub fn updateFrameTexture(texture: *rl.Texture) !void {
    var timestamp_ns: u64 = 0;
    const frame = SDL.AcquireCameraFrame(camera, &timestamp_ns);
    if (frame == null) return;

    const converted_frame = SDL.ConvertSurface(frame, SDL.PIXELFORMAT_ABGR8888);
    if (converted_frame == null) return error.ConversionError;
    defer SDL.DestroySurface(converted_frame);

    const f = converted_frame.*;
    const pixels = f.pixels orelse return error.NoPixels;
    if (texture.id == 0) {
        const img: rl.Image = .{
            .width = f.w,
            .height = f.h,
            .format = .pixelformat_uncompressed_r8g8b8a8,
            .data = pixels,
            .mipmaps = 1,
        };
        texture.* = rl.loadTextureFromImage(img);
    } else {
        rl.updateTexture(texture.*, pixels);
    }

    SDL.ReleaseCameraFrame(camera, frame);
}
