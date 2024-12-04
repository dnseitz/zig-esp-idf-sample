const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");

export fn app_main() callconv(.C) void {
    // This allocator is safe to use as the backing allocator w/ arena allocator
    // std.heap.raw_c_allocator

    // custom allocators (based on raw_c_allocator)
    // idf.heap.HeapCapsAllocator
    // idf.heap.MultiHeapAllocator
    // idf.heap.vPortAllocator

    var heap = idf.heap.vPortAllocator.init();
    var arena = std.heap.ArenaAllocator.init(heap.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    log.info("Hello, world from Zig!", .{});

    log.info(
        \\
        \\[Zig Info]
        \\* Version: {s}
        \\* Stage: {s}
        \\
    , .{
        builtin.zig_version_string,
        @tagName(builtin.zig_backend),
    });

    idf.ESP_LOG(allocator, tag,
        \\
        \\[ESP-IDF Info]
        \\* Version: {s}
        \\
    , .{idf.Version.get().toString(allocator)});

    idf.ESP_LOG(
        allocator,
        tag,
        \\
        \\[Memory Info]
        \\* Free: {d}
        \\* Minimum: {d}
        \\
    ,
        .{
            heap.freeSize(),
            heap.minimumFreeSize(),
        },
    );

    idf.ESP_LOG(
        allocator,
        tag,
        "\nLet's have a look at your shiny {s} - {s} system! :)\n\n",
        .{
            @tagName(builtin.cpu.arch),
            builtin.cpu.model.name,
        },
    );

    if (builtin.mode == .Debug)
        heap.dump();

    // FreeRTOS Tasks
    if (idf.xTaskCreate(blinkclock, "blink", 1024 * 2, null, 5, null) == 0) {
        @panic("Error: Task blinkclock not created!\n");
    }
}
var led_strip: ?*idf.led_strip_t = null;
var s_led_state = false;

/// comptime function
fn blinkLED(delay_ms: u32) !void {
    if (s_led_state) {
        idf.vTaskDelay(delay_ms / idf.portTICK_PERIOD_MS);
        log.info("LOG ON", .{});
        // Set the LED pixel using RGB from 0 (0%) to 255 (100%) for each color
        idf.espCheckError(idf.led_strip_set_pixel(led_strip, 0, 16, 16, 16)) catch |err|
            @panic(@errorName(err));
        // Refresh the strip to send data
        idf.espCheckError(idf.led_strip_refresh(led_strip)) catch |err|
            @panic(@errorName(err));
    } else {
        idf.vTaskDelay(delay_ms / idf.portTICK_PERIOD_MS);
        // Set all LED off to clear all pixels
        idf.espCheckError(idf.led_strip_clear(led_strip)) catch |err|
            @panic(@errorName(err));
        log.info("LOG OFF", .{});
    }
}

fn config_led() void {
    const strip_config: idf.led_strip_config_t = .{
        .strip_gpio_num = 8,
        .max_leds = 1, // at least one LED on board
    };
    const rmt_config: idf.led_strip_rmt_config_t = .{
        .resolution_hz = 10 * 1000 * 1000, // 10MHz
        .flags = .{
            .with_dma = false,
        },
    };
    idf.espCheckError(idf.led_strip_new_rmt_device(&strip_config, &rmt_config, &led_strip)) catch |err|
        @panic(@errorName(err));
    // const spi_config: idf.led_strip_spi_config_t = .{
    //     .spi_bus = .SPI2_HOST,
    //     .flags = .{
    //         .with_dma = true,
    //     },
    // };
    // idf.espCheckError(idf.led_strip_new_spi_device(&strip_config, &spi_config, &led_strip)) catch |err|
    //     @panic(@errorName(err));
    // Set all LED off to clear all pixels
    idf.espCheckError(idf.led_strip_clear(led_strip)) catch |err|
        @panic(@errorName(err));
}

/// Task functions (must be exported to C ABI) - runtime functions
export fn blinkclock(_: ?*anyopaque) void {
    config_led();

    while (true) {
        blinkLED(1000) catch |err|
            @panic(@errorName(err));
        // Toggle the LED state
        s_led_state = !s_led_state;
    }
}

/// override the std panic function with idf.panic
pub const panic = idf.panic;

const log = std.log.scoped(.@"esp-idf");
pub const std_options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
    // Define logFn to override the std implementation
    .logFn = idf.espLogFn,
};

const tag = "zig-blinkSPI";

// const std = @import("std");
// const builtin = @import("builtin");
// const idf = @import("esp_idf");

// export fn app_main() callconv(.C) void {
//     // This allocator is safe to use as the backing allocator w/ arena allocator
//     // std.heap.raw_c_allocator

//     // custom allocators (based on raw_c_allocator)
//     // idf.heap.HeapCapsAllocator
//     // idf.heap.MultiHeapAllocator
//     // idf.heap.vPortAllocator

//     var heap = idf.heap.HeapCapsAllocator.init(.MALLOC_CAP_8BIT);
//     var arena = std.heap.ArenaAllocator.init(heap.allocator());
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     idf.espLogFn;
//     log.info("Hello, world from Zig!", .{});

//     log.info(
//         \\[Zig Info]
//         \\* Version: {s}
//         \\* Compiler Backend: {s}
//         \\
//     , .{
//         @as([]const u8, builtin.zig_version_string), // fix esp32p4(.xesppie) fmt-slice bug
//         @tagName(builtin.zig_backend),
//     });

//     idf.ESP_LOG(allocator, tag,
//         \\[ESP-IDF Info]
//         \\* Version: {s}
//         \\
//     , .{idf.Version.get().toString(allocator)});

//     idf.ESP_LOG(
//         allocator,
//         tag,
//         \\[Memory Info]
//         \\* Total: {d}
//         \\* Free: {d}
//         \\* Minimum: {d}
//         \\
//     ,
//         .{
//             heap.totalSize(),
//             heap.freeSize(),
//             heap.minimumFreeSize(),
//         },
//     );

//     idf.ESP_LOG(
//         allocator,
//         tag,
//         "Let's have a look at your shiny {s} - {s} system! :)\n\n",
//         .{
//             @tagName(builtin.cpu.arch),
//             builtin.cpu.model.name,
//         },
//     );

//     arraylist(allocator) catch unreachable;

//     if (builtin.mode == .Debug)
//         heap.dump();

//     // FreeRTOS Tasks
//     if (idf.xTaskCreate(foo, "foo", 1024 * 3, null, 1, null) == 0) {
//         @panic("Error: Task foo not created!\n");
//     }
//     if (idf.xTaskCreate(bar, "bar", 1024 * 3, null, 2, null) == 0) {
//         @panic("Error: Task bar not created!\n");
//     }
//     if (idf.xTaskCreate(blinkclock, "blink", 1024 * 2, null, 5, null) == 0) {
//         @panic("Error: Task blinkclock not created!\n");
//     }
// }

// // comptime function
// fn blinkLED(delay_ms: u32) !void {
//     try idf.gpio.Direction.set(
//         .GPIO_NUM_8,
//         .GPIO_MODE_OUTPUT,
//     );
//     while (true) {
//         log.info("LED: ON", .{});
//         try idf.gpio.Level.set(.GPIO_NUM_8, 1);

//         idf.vTaskDelay(delay_ms / idf.portTICK_PERIOD_MS);

//         log.info("LED: OFF", .{});
//         try idf.gpio.Level.set(.GPIO_NUM_8, 0);
//     }
// }

// fn arraylist(allocator: std.mem.Allocator) !void {
//     var arr = std.ArrayList(u32).init(allocator);
//     defer arr.deinit();

//     try arr.append(10);
//     try arr.append(20);
//     try arr.append(30);

//     for (arr.items) |index| {
//         idf.ESP_LOG(
//             allocator,
//             tag,
//             "Arr value: {}\n",
//             .{index},
//         );
//     }
// }
// // Task functions (must be exported to C ABI) - runtime functions
// export fn blinkclock(_: ?*anyopaque) void {
//     blinkLED(1000) catch |err|
//         @panic(@errorName(err));
// }

// export fn foo(_: ?*anyopaque) callconv(.C) void {
//     while (true) {
//         log.info("Demo_Task foo printing..", .{});
//         idf.vTaskDelay(2000 / idf.portTICK_PERIOD_MS);
//     }
// }
// export fn bar(_: ?*anyopaque) callconv(.C) void {
//     while (true) {
//         log.info("Demo_Task bar printing..", .{});
//         idf.vTaskDelay(1000 / idf.portTICK_PERIOD_MS);
//     }
// }

// // override the std panic function with idf.panic
// pub const panic = idf.panic;
// const log = std.log.scoped(.@"esp-idf");
// pub const std_options = .{
//     .log_level = switch (builtin.mode) {
//         .Debug => .debug,
//         else => .info,
//     },
//     // Define logFn to override the std implementation
//     .logFn = idf.espLogFn,
// };

// const tag = "zig-example";
