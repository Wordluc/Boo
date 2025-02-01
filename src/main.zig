const c = @cImport(@cInclude("SDL2/SDL.h"));
const vect=struct {
    x:c_int,
    y:c_int
};
const assert = @import("std").debug.assert;
const std = @import("std");
const rnd = std.rand.init(0);
const apple_t = struct {
    size: c_int,
    x: c_int,
    y: c_int,
    pub fn draw(self: *apple_t) void {
        const rect = &c.SDL_Rect{ .x = self.x, .y = self.y, .w = self.size, .h = self.size };
        _ = c.SDL_FillRect(surface orelse null, rect, c.SDL_MapRGB(surface.*.format, 0, 255, 0));
        _ = c.SDL_UpdateWindowSurface(screen);
    }
};

const head_t = struct {
    x: c_int,
    y: c_int,
    size: c_int,
    tail: ?*head_t,
    pub fn move(self: *head_t, x: c_int, y: c_int) !void {
        if (self.tail) |t| {
            const x_tail = self.x - self.tail.?.x;
            const y_tail = self.y - self.tail.?.y;
            try t.move(x_tail, y_tail);
        } else {
            const rect = &c.SDL_Rect{ .x = self.x, .y = self.y, .w = self.size, .h = self.size };
            _ = c.SDL_FillRect(surface orelse null, rect, c.SDL_MapRGB(surface.*.format, 0, 0, 0));
        }
        self.x += x;
        self.y += y;
        const rect = &c.SDL_Rect{ .x = self.x, .y = self.y, .w = self.size, .h = self.size };
        _ = c.SDL_FillRect(surface orelse null, rect, c.SDL_MapRGB(surface.*.format, 255, 0, 0));
    }

    pub fn add_tail(self: *head_t) void {
        if (self.tail) |t| {
            t.add_tail();
            return;
        }
        self.tail = &(std.heap.page_allocator.alloc(head_t, 1) catch unreachable)[0];
        self.tail.?.x = self.x;
        self.tail.?.y = self.y;
        self.tail.?.size = self.size;
        self.tail.?.tail = null;
    }

    fn is_colliding(self: *head_t) bool {
        var tail = self.tail;
        while (tail) |t| {
            if (self.x == t.x and self.y == t.y) {
                return true;
            }
            tail = t.tail;
        }
        return false;
    }
};

var head: head_t = undefined;

var screen: ?*c.SDL_Window = null;
var surface: [*c]c.SDL_Surface = null;
var apple: ?apple_t = null;
const speed = 10;
pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();
    head = head_t{ .x = 0, .y = 0, .size = 10, .tail = null };
    apple = apple_t{ .x = 200, .y = 200, .size = 10 };
    screen = c.SDL_CreateWindow("My Game Window", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, 400, 400, c.SDL_WINDOW_OPENGL) orelse
    {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);
    surface = c.SDL_GetWindowSurface(screen) orelse {
        c.SDL_Log("Unable to get window surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    var quit = false;
    try head.move(0, 0);
    apple.?.draw();
    var event: c.SDL_Event = undefined;
    var state_keyboard: [*c]const u8 = undefined;
    state_keyboard = c.SDL_GetKeyboardState(null);
    var speed_head =vect{.x=speed,.y=0};
    while (!quit) {
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }
        if (state_keyboard[c.SDL_SCANCODE_UP]==1){
                speed_head.y=-speed;
                speed_head.x=0;
        }else
        if (state_keyboard[c.SDL_SCANCODE_DOWN]==1){
                speed_head.y=speed;
                speed_head.x=0;
        }else
        if (state_keyboard[c.SDL_SCANCODE_LEFT]==1){
                speed_head.x=-speed;
                speed_head.y=0;
        }else
        if (state_keyboard[c.SDL_SCANCODE_RIGHT]==1){
                speed_head.x=speed;
                speed_head.y=0;
        }else
        if (state_keyboard[c.SDL_SCANCODE_Q]==1){
            break;
        }
        try head.move(speed_head.x, speed_head.y);
        if (head.is_colliding()) {
            break;
        }
        if (apple != null) {
            apple.?.draw();
            if (head.x >= apple.?.x and head.x < apple.?.x + apple.?.size and head.y >= apple.?.y and head.y < apple.?.y + apple.?.size) {
                head.add_tail();
                var prng = std.rand.DefaultPrng.init(blk: {
                    var seed: u64 = undefined;
                    try std.posix.getrandom(std.mem.asBytes(&seed));
                    break :blk seed;
                });
                const rand = prng.random();
                apple = apple_t{ .x = rand.intRangeAtMost(i32, 0, 10) * 30, .y = rand.intRangeAtMost(i32, 0, 10) * 30, .size = apple.?.size };
            }
        }

        _ = c.SDL_UpdateWindowSurface(screen);
        c.SDL_Delay(100);
    }
}
