usingnamespace @import("./c.zig");

const std = @import("std");

const math = std.math;

var xcb_connection: ?*xcb_connection_t = undefined;
var xcb_setup: *const struct_xcb_setup_t = undefined;
var xcb_screen: *xcb_screen_t = undefined;
var xcb_window_id: u32 = 0;

pub fn init() !void {
    xcb_connection = xcb_connect(null, null);
    if (xcb_connection_has_error(xcb_connection) != 0) {
        return error.XCB_CONNECTION_ERROR;
    }

    xcb_setup = xcb_get_setup(xcb_connection);
    xcb_screen = xcb_setup_roots_iterator(xcb_setup).data;
    xcb_window_id = xcb_generate_id(xcb_connection);

    _ = xcb_create_window(
        xcb_connection,
        xcb_screen.*.root_depth,
        xcb_window_id,
        xcb_screen.*.root,
        0,
        0,
        100,
        100,
        1,
        XCB_WINDOW_CLASS_INPUT_OUTPUT,
        xcb_screen.*.root_visual,
        0,
        null,
    );

    _ = xcb_map_window(xcb_connection, xcb_window_id);
    _ = xcb_flush(xcb_connection);}

pub fn deinit() void {
    xcb_disconnect(xcb_connection);
}

pub fn getVulkanSurface(instance: VkInstance) VkSurfaceKHR {
    const create_info = VkXcbSurfaceCreateInfoKHR {
        .sType = .VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR,
        .pNext = null,
        .flags = 0,
        .connection = xcb_connection,
        .window = xcb_window_id,
    };

    var surface: VkSurfaceKHR = undefined;
    const result = vkCreateXcbSurfaceKHR(instance, &create_info, null, &surface);
    std.debug.assert(result == .VK_SUCCESS);

    return surface;
}

pub fn getExtent(
    capabilities: VkSurfaceCapabilitiesKHR,
) VkExtent2D { 
    const xcb_geometry_cookie = xcb_get_geometry(xcb_connection, xcb_window_id);
    const xcb_geometry = xcb_get_geometry_reply(xcb_connection, xcb_geometry_cookie, null);

    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    } else {
        return VkExtent2D {
            .width = math.clamp(xcb_geometry.*.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
            .height = math.clamp(xcb_geometry.*.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height),
        };
    }
}

