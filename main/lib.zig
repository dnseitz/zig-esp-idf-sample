const std = @import("std");
const builtin = @import("builtin");
const esp_idf = @import("esp_idf");
const tag = "zig-example";

fn blinkLED(delay_ms: u32) void {
    _ = esp_idf.gpio_set_direction(.GPIO_NUM_18, .GPIO_MODE_OUTPUT);
    while (true) {
        log.info("LED: ON", .{});
        _ = esp_idf.gpio_set_level(.GPIO_NUM_18, 1);
        esp_idf.vTaskDelay(delay_ms / esp_idf.portTICK_PERIOD_MS);
        log.info("LED: OFF", .{});
        _ = esp_idf.gpio_set_level(.GPIO_NUM_18, 0);
    }
}

export fn app_main() callconv(.C) void {
    // This allocator is safe to use as the backing allocator w/ arena allocator
    // std.heap.raw_c_allocator

    // custom allocators (based on raw_c_allocator)
    // esp_idf.raw_heap_caps_allocator
    // esp_idf.raw_multi_heap_allocator

    var arena = std.heap.ArenaAllocator.init(esp_idf.raw_heap_caps_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    log.info("Hello, world from Zig!\n", .{});
    log.info(
        \\
        \\[Zig Info]
        \\* Version: {s}
        \\* Stage: {s}
        \\
    , .{ builtin.zig_version_string, @tagName(builtin.zig_backend) });
    esp_idf.ESP_LOGI(allocator, tag,
        \\
        \\[ESP-IDF Info]
        \\* Version: {s}
        \\
    , .{esp_idf.esp_get_idf_version()});
    esp_idf.ESP_LOGI(
        allocator,
        tag,
        \\
        \\[Memory Info]
        \\* Total: {d}
        \\* Free: {d}
        \\* Minimum: {d}
        \\
    ,
        .{
            esp_idf.heap_caps_get_total_size(@intFromEnum(esp_idf.Caps.MALLOC_CAP_DEFAULT) | @intFromEnum(esp_idf.Caps.MALLOC_CAP_INTERNAL)),
            esp_idf.heap_caps_get_free_size(@intFromEnum(esp_idf.Caps.MALLOC_CAP_DEFAULT) | @intFromEnum(esp_idf.Caps.MALLOC_CAP_INTERNAL)),
            esp_idf.heap_caps_get_minimum_free_size(@intFromEnum(esp_idf.Caps.MALLOC_CAP_DEFAULT) | @intFromEnum(esp_idf.Caps.MALLOC_CAP_INTERNAL)),
        },
    );
    esp_idf.ESP_LOGI(
        allocator,
        tag,
        "\nLet's have a look at your shiny {s} - {s} system! :)\n\n",
        .{
            @tagName(builtin.cpu.arch),
            builtin.cpu.model.name,
        },
    );

    var arr = std.ArrayList(c_int).init(allocator);
    defer arr.deinit();

    arr.append(10) catch |err|
        @panic(@errorName(err));
    arr.append(20) catch |err|
        @panic(@errorName(err));
    arr.append(30) catch |err|
        @panic(@errorName(err));

    for (arr.items) |index| {
        esp_idf.ESP_LOGI(allocator, tag, "Arr value: {}\n", .{index});
    }
    if (builtin.mode == .Debug)
        esp_idf.heap_caps_dump_all();

    // FreeRTOS Tasks
    if (esp_idf.xTaskCreate(foo, "foo", 1024 * 3, null, 1, null) == 0) {
        @panic("Error: Task foo not created!\n");
    }
    if (esp_idf.xTaskCreate(bar, "bar", 1024 * 3, null, 2, null) == 0) {
        @panic("Error: Task bar not created!\n");
    }
    if (esp_idf.xTaskCreate(blinkclock, "blink", 1024 * 2, null, 5, null) == 0) {
        @panic("Error: Task blinkclock not created!\n");
    }
}
export fn blinkclock(_: ?*anyopaque) void {
    blinkLED(1000);
}
export fn foo(_: ?*anyopaque) callconv(.C) void {
    while (true) {
        log.info("Demo_Task foo printing..", .{});
        esp_idf.vTaskDelay(2000 / esp_idf.portTICK_PERIOD_MS);
    }
}
export fn bar(_: ?*anyopaque) callconv(.C) void {
    while (true) {
        log.info("Demo_Task bar printing..", .{});
        esp_idf.vTaskDelay(1000 / esp_idf.portTICK_PERIOD_MS);
    }
}

// zig panic handler override by esp_idf.panic
pub usingnamespace if (!@hasDecl(@This(), "panic"))
    struct {
        pub const panic = esp_idf.panic;
    }
else
    struct {};

const log = std.log.scoped(.esp_idf);
pub const std_options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
    // Define logFn to override the std implementation
    .logFn = esp_idf.espLogFn,
};
