const builtin = @import("builtin");

pub usingnamespace @cImport({
    if (builtin.os.tag == .linux) {
        @cInclude("alsa/asoundlib.h");
        @cInclude("xcb/xcb.h");
        @cDefine("VK_USE_PLATFORM_XCB_KHR", "");
    }
    @cInclude("vulkan/vulkan.h");
});

