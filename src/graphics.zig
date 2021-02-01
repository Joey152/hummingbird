usingnamespace @import("./c.zig");

const io = @import("./io.zig");
const linmath = @import("./linmath.zig");
const std = @import("std");
const window = @import("./window.zig");

const math = std.math;
const allocator = std.heap.c_allocator;
const Mat4 = linmath.Mat4;
const Vec3 = linmath.Vec3;

var result: VkResult = undefined;
var instance: VkInstance = undefined;
var surface: VkSurfaceKHR = undefined;
var physical_device: VkPhysicalDevice = undefined;
var graphics_queue_family: QueueFamily = undefined;
var graphics_queue: VkQueue = undefined;
var device: VkDevice = undefined;
var surface_format: VkSurfaceFormatKHR = undefined;
var surface_capabilities: VkSurfaceCapabilitiesKHR = undefined;
var extent: VkExtent2D = undefined;
var swapchain: VkSwapchainKHR = undefined;
var swapchain_images: []VkImage = undefined;
var swapchain_image_views: []VkImageView = undefined;
var graphics_command_pool: VkCommandPool = undefined;
var descriptor_pool: VkDescriptorPool = undefined;
var is_image_available: [MAX_FRAMES_IN_FLIGHT]VkSemaphore = undefined;
var is_present_ready: [MAX_FRAMES_IN_FLIGHT]VkSemaphore = undefined;
var is_main_render_done: [MAX_FRAMES_IN_FLIGHT]VkFence = undefined;
var descriptor_set_layout: VkDescriptorSetLayout = undefined;
var pipeline_layout: VkPipelineLayout = undefined;
var render_pass: VkRenderPass = undefined;
var vertex_buffer: VkBuffer = undefined;
var vertex_buffer_memory: VkDeviceMemory = undefined;
var uniform_buffers: []VkBuffer = undefined;
var uniform_buffers_memory: []VkDeviceMemory = undefined;
var descriptor_sets: []VkDescriptorSet = undefined;
var pipeline: VkPipeline = undefined;
var framebuffers: []VkFramebuffer = undefined;
var command_buffers: []VkCommandBuffer = undefined;


const MAX_FRAMES_IN_FLIGHT = 2;
var current_frame: u32 = 0;
const mesh_vertices = [_]Vertex {
    Vertex {
        .pos = .{ 0.0, -0.5 },
        .color = .{ 1.0, 0.0, 0.0 }, 
    },
    Vertex {
        .pos = .{ 0.5, 0.5 },
        .color = .{ 0.0, 1.0, 0.0 }, 
    },
    Vertex {
        .pos = .{ -0.5, 0.5 },
        .color = .{ 0.0, 0.0, 1.0 }, 
    },
    Vertex {
        .pos = .{ 1.0, -0.5 },
        .color = .{ 1.0, 1.0, 0.0 }, 
    },
    Vertex {
        .pos = .{ 1.5, 0.5 },
        .color = .{ 0.0, 1.0, 1.0 }, 
    },
    Vertex {
        .pos = .{ -1.5, 0.5 },
        .color = .{ 1.0, 0.0, 1.0 }, 
    },
};

const QueueFamily = struct {
    index: u32,
    properties: VkQueueFamilyProperties,
};

const Vertex = extern struct {
    pos: [2]f32,
    color: [3]f32,

    pub fn getBindingDescription() VkVertexInputBindingDescription {
        return VkVertexInputBindingDescription {
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = .VK_VERTEX_INPUT_RATE_VERTEX,
        };
    }

    pub fn getAttributeDescriptions() [2]VkVertexInputAttributeDescription {
        return [2]VkVertexInputAttributeDescription {
            VkVertexInputAttributeDescription {
                .binding = 0,
                .location = 0,
                .format = .VK_FORMAT_R32G32_SFLOAT,
                .offset = @byteOffsetOf(Vertex, "pos"),
            },
            VkVertexInputAttributeDescription {
                .binding = 0,
                .location = 1,
                .format = .VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @byteOffsetOf(Vertex, "color"),
            },
        };
    }

    
};

pub const UBO = extern struct {
    view: Mat4,
    proj: Mat4,
};

pub fn init() !void {
    {
        const layers = [_][*:0]const u8 {
            "VK_LAYER_KHRONOS_validation"
        };

        const extensions = [_][*:0]const u8 {
            VK_EXT_DEBUG_REPORT_EXTENSION_NAME,
            VK_KHR_XCB_SURFACE_EXTENSION_NAME,
            VK_KHR_SURFACE_EXTENSION_NAME,
        };

        const app_info = VkApplicationInfo {
            .sType = .VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "Flicker",
            .applicationVersion = VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "Flicker",
            .engineVersion = VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = VK_API_VERSION_1_1,
        };

        const create_info = VkInstanceCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = @intCast(u32, layers.len),
            .ppEnabledLayerNames = &layers[0],
            .enabledExtensionCount = @intCast(u32, extensions.len),
            .ppEnabledExtensionNames = &extensions[0],
        };

        result = vkCreateInstance(&create_info, null, &instance);
        std.debug.assert(result == .VK_SUCCESS);        
    }

    surface = window.getVulkanSurface(instance);

    {
        var physical_device_count: u32 = 0;
        result = vkEnumeratePhysicalDevices(instance, &physical_device_count, null);
        std.debug.assert(result == .VK_SUCCESS);
        var physical_devices = try allocator.alloc(VkPhysicalDevice, physical_device_count);
        result = vkEnumeratePhysicalDevices(instance, &physical_device_count, physical_devices.ptr);
        std.debug.assert(result == .VK_SUCCESS);

        var i: usize = 0;
        find_phys: while (i < physical_device_count) : (i += 1) {
            var queue_family_property_count: u32 = 0;
            _ = vkGetPhysicalDeviceQueueFamilyProperties(physical_devices[i], &queue_family_property_count, null);
            var queue_family_properties = try allocator.alloc(VkQueueFamilyProperties, queue_family_property_count);
            _ = vkGetPhysicalDeviceQueueFamilyProperties(physical_devices[i], &queue_family_property_count, queue_family_properties.ptr);
            
            var j: u32 = 0;
            while (j < queue_family_property_count) : (j += 1) {
                if (queue_family_properties[j].queueFlags & @intCast(u32, @enumToInt(VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT)) != 0) {
                    var is_surface_supported: VkBool32 = VK_FALSE;
                    result = vkGetPhysicalDeviceSurfaceSupportKHR(physical_devices[i], j, surface, &is_surface_supported);
                    std.debug.assert(result == .VK_SUCCESS);
                    if (is_surface_supported == VK_TRUE) {
                        physical_device = physical_devices[i].?;
                        graphics_queue_family = QueueFamily {
                            .index = j,
                            .properties = queue_family_properties[j],
                        };
                        break :find_phys;
                    }
                }
            }
        }
        // TODO: how to handle this case
        std.debug.assert(physical_device != null);
    }

    {
        const extension_names = [_][*:0]const u8 {
            VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        };

        const features = VkPhysicalDeviceFeatures {
            .robustBufferAccess = VK_FALSE,
            .fullDrawIndexUint32 = VK_FALSE,
            .imageCubeArray = VK_FALSE,
            .independentBlend = VK_FALSE,
            .geometryShader = VK_FALSE,
            .tessellationShader = VK_FALSE,
            .sampleRateShading = VK_FALSE,
            .dualSrcBlend = VK_FALSE,
            .logicOp = VK_TRUE,
            .multiDrawIndirect = VK_FALSE,
            .drawIndirectFirstInstance = VK_FALSE,
            .depthClamp = VK_FALSE,
            .depthBiasClamp = VK_FALSE,
            .fillModeNonSolid = VK_FALSE,
            .depthBounds = VK_FALSE,
            .wideLines = VK_FALSE,
            .largePoints = VK_FALSE,
            .alphaToOne = VK_FALSE,
            .multiViewport = VK_FALSE,
            .samplerAnisotropy = VK_FALSE,
            .textureCompressionETC2 = VK_FALSE,
            .textureCompressionASTC_LDR = VK_FALSE,
            .textureCompressionBC = VK_FALSE,
            .occlusionQueryPrecise = VK_FALSE,
            .pipelineStatisticsQuery = VK_FALSE,
            .vertexPipelineStoresAndAtomics = VK_FALSE,
            .fragmentStoresAndAtomics = VK_FALSE,
            .shaderTessellationAndGeometryPointSize = VK_FALSE,
            .shaderImageGatherExtended = VK_FALSE,
            .shaderStorageImageExtendedFormats = VK_FALSE,
            .shaderStorageImageMultisample = VK_FALSE,
            .shaderStorageImageReadWithoutFormat = VK_FALSE,
            .shaderStorageImageWriteWithoutFormat = VK_FALSE,
            .shaderUniformBufferArrayDynamicIndexing = VK_FALSE,
            .shaderSampledImageArrayDynamicIndexing = VK_FALSE,
            .shaderStorageBufferArrayDynamicIndexing = VK_FALSE,
            .shaderStorageImageArrayDynamicIndexing = VK_FALSE,
            .shaderClipDistance = VK_FALSE,
            .shaderCullDistance = VK_FALSE,
            .shaderFloat64 = VK_FALSE,
            .shaderInt64 = VK_FALSE,
            .shaderInt16 = VK_FALSE,
            .shaderResourceResidency = VK_FALSE,
            .shaderResourceMinLod = VK_FALSE,
            .sparseBinding = VK_FALSE,
            .sparseResidencyBuffer = VK_FALSE,
            .sparseResidencyImage2D = VK_FALSE,
            .sparseResidencyImage3D = VK_FALSE,
            .sparseResidency2Samples = VK_FALSE,
            .sparseResidency4Samples = VK_FALSE,
            .sparseResidency8Samples = VK_FALSE,
            .sparseResidency16Samples = VK_FALSE,
            .sparseResidencyAliased = VK_FALSE,
            .variableMultisampleRate = VK_FALSE,
            .inheritedQueries = VK_FALSE,
        };

        var queue_priorities = try allocator.alloc(f32, graphics_queue_family.properties.queueCount);
        for (queue_priorities) |*q| {
            q.* = 0.0; 
        }
        
        const device_queue_info = VkDeviceQueueCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = graphics_queue_family.index,
            .queueCount = @intCast(u32, queue_priorities.len),
            .pQueuePriorities = queue_priorities.ptr,
        };
        
        const create_info = VkDeviceCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &device_queue_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = extension_names.len,
            .ppEnabledExtensionNames = &extension_names,
            .pEnabledFeatures = &features,
        };

        result = vkCreateDevice(physical_device, &create_info, null, &device);
        std.debug.assert(result == .VK_SUCCESS);
    }

    {
        vkGetDeviceQueue(device, graphics_queue_family.index, 0, &graphics_queue);
    }

    get_surface_format: {
        var surface_formats_count: u32 = 0;
        result = vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &surface_formats_count, null);
        std.debug.assert(result == .VK_SUCCESS);
        var surface_formats = try allocator.alloc(VkSurfaceFormatKHR, surface_formats_count);
        result = vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &surface_formats_count, surface_formats.ptr);
        std.debug.assert(result == .VK_SUCCESS);

        const preferred_format = VkSurfaceFormatKHR {
            .format = .VK_FORMAT_B8G8R8_UNORM,
            .colorSpace = .VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
        };
        
        if (surface_formats_count == 1 and surface_formats[0].format == .VK_FORMAT_UNDEFINED) {
            surface_format = preferred_format;
            break :get_surface_format;
        }
        
        var i: u32 = 0;
        while (i < surface_formats_count) : (i += 1) {
            if (surface_formats[i].format == preferred_format.format and surface_formats[i].colorSpace == preferred_format.colorSpace) {
                surface_format = preferred_format;                
                break :get_surface_format;
            }
        }

        surface_format = surface_formats[0];
    }

    result = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &surface_capabilities);
    std.debug.assert(result == .VK_SUCCESS);
    
    extent = window.getExtent(surface_capabilities);
    try initSwapchain(extent);

    {
        const create_info= VkCommandPoolCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = @enumToInt(VkCommandPoolCreateFlagBits.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT),
            .queueFamilyIndex = graphics_queue_family.index,
        };
        result = vkCreateCommandPool(device, &create_info, null, &graphics_command_pool);
        std.debug.assert(result == .VK_SUCCESS);
    }

    {
        const descriptor_pool_sizes = [_]VkDescriptorPoolSize {
            VkDescriptorPoolSize {
                .type = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = @intCast(u32, swapchain_images.len),
            },
        };

        const create_info = VkDescriptorPoolCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .maxSets = @intCast(u32, swapchain_images.len),
            .poolSizeCount = descriptor_pool_sizes.len,
            .pPoolSizes = &descriptor_pool_sizes[0],
        };

        result = vkCreateDescriptorPool(device, &create_info, null, &descriptor_pool);
        std.debug.assert(result == .VK_SUCCESS);
    }

    {
        const semaphore_info = VkSemaphoreCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
        };

        const fence_info = VkFenceCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .pNext = null,
            .flags = @enumToInt(VkFenceCreateFlagBits.VK_FENCE_CREATE_SIGNALED_BIT),
        };

        var i: usize = 0;
        while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1) {
            result = vkCreateSemaphore(device, &semaphore_info, null, &is_image_available[i]);
            std.debug.assert(result == .VK_SUCCESS);
            result = vkCreateSemaphore(device, &semaphore_info, null, &is_present_ready[i]);
            std.debug.assert(result == .VK_SUCCESS);
            result = vkCreateFence(device, &fence_info, null, &is_main_render_done[i]);
            std.debug.assert(result == .VK_SUCCESS);
        }
    }

    {
        const ubo_layout_binding = VkDescriptorSetLayoutBinding {
            .binding = 0,
            .descriptorType = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .stageFlags = @enumToInt(VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT),
            .pImmutableSamplers = null,
        };

        const create_info = VkDescriptorSetLayoutCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .bindingCount = 1,
            .pBindings = &ubo_layout_binding,
        };

        result = vkCreateDescriptorSetLayout(device, &create_info, null, &descriptor_set_layout);
        std.debug.assert(result == .VK_SUCCESS);
    }

    {
        const pipeline_layout_create_info = VkPipelineLayoutCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .setLayoutCount = 1,
            .pSetLayouts = &descriptor_set_layout,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
        };

        result = vkCreatePipelineLayout(device, &pipeline_layout_create_info, null, &pipeline_layout);
        std.debug.assert(result == .VK_SUCCESS);
    }

    {
        const color_attachment_descriptions = [_]VkAttachmentDescription {
            VkAttachmentDescription {
                .flags = 0,
                .format = surface_format.format,
                .samples = .VK_SAMPLE_COUNT_1_BIT,
                .loadOp = .VK_ATTACHMENT_LOAD_OP_CLEAR,
                .storeOp = .VK_ATTACHMENT_STORE_OP_STORE,
                .stencilLoadOp = .VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                .stencilStoreOp = .VK_ATTACHMENT_STORE_OP_DONT_CARE,
                .initialLayout = .VK_IMAGE_LAYOUT_UNDEFINED,
                .finalLayout = .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            },
        };

        const color_attachment_refs = [_]VkAttachmentReference {
            VkAttachmentReference {
                .attachment = 0,
                .layout = .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            },
        };

        const subpasses = [_]VkSubpassDescription {
            VkSubpassDescription {
                .flags = 0,
                .pipelineBindPoint = .VK_PIPELINE_BIND_POINT_GRAPHICS,
                .inputAttachmentCount = 0,
                .pInputAttachments = null,
                .colorAttachmentCount = color_attachment_refs.len,
                .pColorAttachments = &color_attachment_refs,
                .pResolveAttachments = null,
                .pDepthStencilAttachment = null,
                .preserveAttachmentCount = 0,
                .pPreserveAttachments = null,
            },
        };

        const dependency = VkSubpassDependency {
            .srcSubpass = VK_SUBPASS_EXTERNAL,
            .dstSubpass = 0,
            .srcStageMask = @enumToInt(VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT),
            .dstStageMask = @enumToInt(VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT),
            .srcAccessMask = 0,
            .dstAccessMask = @enumToInt(VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT),
            .dependencyFlags = 0,
        };
        
        const create_info = VkRenderPassCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .attachmentCount = color_attachment_descriptions.len,
            .pAttachments = &color_attachment_descriptions,
            .subpassCount = subpasses.len,
            .pSubpasses = &subpasses,
            .dependencyCount = 1,
            .pDependencies = &dependency,
        };

        result = vkCreateRenderPass(device, &create_info, null, &render_pass);
        std.debug.assert(result == .VK_SUCCESS);
    }

    {
        const create_info = VkBufferCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = @sizeOf(Vertex) * mesh_vertices.len,
            .usage = @enumToInt(VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT),
            .sharingMode = .VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };
        
        result = vkCreateBuffer(device, &create_info, null, &vertex_buffer);
        std.debug.assert(result == .VK_SUCCESS);

        var memory_requirements: VkMemoryRequirements = undefined;
        _ = vkGetBufferMemoryRequirements(device, vertex_buffer, &memory_requirements);
        const alloc_info = VkMemoryAllocateInfo {
            .sType = .VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = memory_requirements.size,
            .memoryTypeIndex = getMemoryType(
                memory_requirements.memoryTypeBits, 
                VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
            ),
        };

        result = vkAllocateMemory(device, &alloc_info, null, &vertex_buffer_memory);
        std.debug.assert(result == .VK_SUCCESS);

        _ = vkBindBufferMemory(device, vertex_buffer, vertex_buffer_memory, 0);

        // TODO: lifetime/free issues?
        var data = try allocator.alloc(Vertex, mesh_vertices.len);
        _ = vkMapMemory(device, vertex_buffer_memory, 0, @sizeOf(Vertex) * mesh_vertices.len, 0, @ptrCast(*?*c_void, &data));
        std.mem.copy(Vertex, data, mesh_vertices[0..]); 
        _ = vkUnmapMemory(device, vertex_buffer_memory);
    }

    {
        uniform_buffers = try allocator.alloc(VkBuffer, swapchain_images.len);
        uniform_buffers_memory = try allocator.alloc(VkDeviceMemory, swapchain_images.len);
        var i: usize = 0;
        while (i < swapchain_images.len) : (i += 1) {
            {
                const create_info = VkBufferCreateInfo {
                    .sType = .VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
                    .pNext = null,
                    .flags = 0,
                    .size = @sizeOf(UBO),
                    .usage = @enumToInt(VkBufferUsageFlagBits.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT),
                    .sharingMode = .VK_SHARING_MODE_EXCLUSIVE,
                    .queueFamilyIndexCount = 0,
                    .pQueueFamilyIndices = null,
                };
                
                result = vkCreateBuffer(device, &create_info, null, &uniform_buffers[i]);
                std.debug.assert(result == .VK_SUCCESS);
            }

            var memory_requirements: VkMemoryRequirements = undefined;
            _ = vkGetBufferMemoryRequirements(device, uniform_buffers[i], &memory_requirements);
            const buffer_alloc_info = VkMemoryAllocateInfo {
                .sType = .VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                .pNext = null,
                .allocationSize = memory_requirements.size,
                .memoryTypeIndex = getMemoryType(
                    memory_requirements.memoryTypeBits, 
                    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
                ),
            };

            result = vkAllocateMemory(device, &buffer_alloc_info, null, &uniform_buffers_memory[i]);
            std.debug.assert(result == .VK_SUCCESS);

            _ = vkBindBufferMemory(device, uniform_buffers[i], uniform_buffers_memory[i], 0);
        }
    }

    {
        descriptor_sets = try allocator.alloc(VkDescriptorSet, swapchain_images.len);
        var layouts = try allocator.alloc(VkDescriptorSetLayout, swapchain_images.len);
        for (layouts) |*layout| {
            layout.* = descriptor_set_layout;
        }
        const descriptor_alloc_info = VkDescriptorSetAllocateInfo {
            .sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .pNext = null,
            .descriptorPool = descriptor_pool,
            .descriptorSetCount = @intCast(u32, layouts.len),
            .pSetLayouts = layouts.ptr,
        };

        result = vkAllocateDescriptorSets(device, &descriptor_alloc_info, descriptor_sets.ptr);
    }

    {
        var i: usize = 0;
        while (i < swapchain_images.len) : (i += 1) {
            const buffer_info = VkDescriptorBufferInfo {
                .buffer = uniform_buffers[i],
                .offset = 0,
                .range = VK_WHOLE_SIZE,
            };
        
            const descriptor_write = VkWriteDescriptorSet {
                .sType = .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = descriptor_sets[i],
                .dstBinding = 0,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .pImageInfo = null,
                .pBufferInfo = &buffer_info,
                .pTexelBufferView = null,
            };

            vkUpdateDescriptorSets(device, 1, &descriptor_write, 0, null);
        }
    }

    try initWithNewExtent(extent);
}

pub fn deinit() void {

}

pub fn drawFrame(ubo: *UBO) !void {
    result = vkWaitForFences(device, 1, &is_main_render_done[current_frame], VK_TRUE, math.maxInt(u64));
    std.debug.assert(result == .VK_SUCCESS);

    result = vkResetFences(device, 1, &is_main_render_done[current_frame]);
    std.debug.assert(result == .VK_SUCCESS);

    var image_index: u32 = undefined;
    result = vkAcquireNextImageKHR(device, swapchain, math.maxInt(u64), is_image_available[current_frame], null, &image_index);
    if (result == .VK_ERROR_OUT_OF_DATE_KHR or result == .VK_SUBOPTIMAL_KHR) {
        result = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &surface_capabilities);
        std.debug.assert(result == .VK_SUCCESS);
        extent = window.getExtent(surface_capabilities);
        deinitWithNewExtent();
        try initSwapchain(extent);
        try initWithNewExtent(extent);
    }

    var data: *UBO = undefined;
    _ = vkMapMemory(device, uniform_buffers_memory[image_index], 0, @sizeOf(UBO), 0, @ptrCast(*?*c_void, &data));
    data.* = ubo.*;
    vkUnmapMemory(device, uniform_buffers_memory[image_index]);

    const wait_semaphore_count = 1;
    const wait_stages = [wait_semaphore_count]VkPipelineStageFlags {
        @enumToInt(VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT),
    };
    
    const submit_info = VkSubmitInfo {
        .sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &[_]VkSemaphore {is_image_available[current_frame]},
        .pWaitDstStageMask = &wait_stages,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffers[image_index],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &[_]VkSemaphore {is_present_ready[current_frame]},
    };

    result = vkQueueSubmit(graphics_queue, 1, &submit_info, is_main_render_done[current_frame]);
    std.debug.assert(result == .VK_SUCCESS);

    const present_info = VkPresentInfoKHR {
        .sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pNext = null,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &is_present_ready[current_frame],
        .swapchainCount = 1,
        .pSwapchains = &swapchain,
        .pImageIndices = &image_index,
        .pResults = null,
    };

    result = vkQueuePresentKHR(graphics_queue, &present_info);
    if (result == .VK_ERROR_OUT_OF_DATE_KHR or result == .VK_SUBOPTIMAL_KHR) {
        result = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &surface_capabilities);
        std.debug.assert(result == .VK_SUCCESS);
        extent = window.getExtent(surface_capabilities);
        deinitWithNewExtent();
        try initSwapchain(extent);
        try initWithNewExtent(extent);
    }

    current_frame = (current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
}

// TODO: move
fn getMemoryType(
    type_filter: u32,
    properties: VkMemoryPropertyFlags,
) u32 {
    var memory_properties: VkPhysicalDeviceMemoryProperties = undefined;
    _ = vkGetPhysicalDeviceMemoryProperties(physical_device, &memory_properties); 

    var i: u5 = 0;
    while (i < memory_properties.memoryTypeCount) : (i += 1) {
        if (type_filter & (@intCast(u32, 1) << i) != 0 and memory_properties.memoryTypes[i].propertyFlags & properties == properties) {
            return i;
        }
    }

    unreachable;
}

fn createShaderModule(
    code: []align(@alignOf(u32)) u8
) VkShaderModule {
    const create_info = VkShaderModuleCreateInfo {
        .sType = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = code.len,
        .pCode = std.mem.bytesAsSlice(u32, code).ptr,
    };
    
    var shader_module: VkShaderModule = undefined;
    result = vkCreateShaderModule(device, &create_info, null, &shader_module);
    std.debug.assert(result == .VK_SUCCESS);

    return shader_module;
}

fn initSwapchain(new_extent: VkExtent2D) !void {
     {
        var present_modes_count = @as(u32, 0);
        result = vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_modes_count, null);
        std.debug.assert(result == .VK_SUCCESS);
        const present_modes = try allocator.alloc(VkPresentModeKHR, present_modes_count);
        defer allocator.free(present_modes);
        result = vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_modes_count, present_modes.ptr);
        std.debug.assert(result == .VK_SUCCESS);

        var swapchain_present_mode = VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
        var i: usize = 0;
        while (i < present_modes_count) : (i += 1) {
            if (present_modes[i] == .VK_PRESENT_MODE_MAILBOX_KHR or present_modes[i] == .VK_PRESENT_MODE_IMMEDIATE_KHR) {
                swapchain_present_mode = present_modes[i];
                break;
            }
        }

        // TODO: supported composite alpha
        const composite_alpha = VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

        var create_info = VkSwapchainCreateInfoKHR {
            .sType = .VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .pNext = null,
            .flags = 0,
            .surface = surface,
            .minImageCount = surface_capabilities.minImageCount,
            .imageFormat = surface_format.format,
            .imageColorSpace = surface_format.colorSpace,
            .imageExtent = new_extent,
            .imageArrayLayers = 1,
            .imageUsage = @enumToInt(VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT),
            .imageSharingMode = .VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .preTransform = surface_capabilities.currentTransform,
            .compositeAlpha = composite_alpha,
            .presentMode = swapchain_present_mode,
            .clipped = VK_TRUE,
            .oldSwapchain = null, 
        };

        result = vkCreateSwapchainKHR(device, &create_info, null, &swapchain);
        std.debug.assert(result == .VK_SUCCESS);
    }

    {
        var swapchain_image_count: u32 = undefined;
        result = vkGetSwapchainImagesKHR(device, swapchain, &swapchain_image_count, null);
        std.debug.assert(result == .VK_SUCCESS);
        swapchain_images = try allocator.alloc(VkImage, swapchain_image_count);
        result = vkGetSwapchainImagesKHR(device, swapchain, &swapchain_image_count, swapchain_images.ptr);
        std.debug.assert(result == .VK_SUCCESS);
    }   
}

fn initWithNewExtent(new_extent: VkExtent2D) !void {
    {
        var create_info = VkImageViewCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .image = undefined,
            .viewType = .VK_IMAGE_VIEW_TYPE_2D,
            .format = surface_format.format,
            .components = VkComponentMapping {
                .r = .VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = .VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = .VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = .VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = VkImageSubresourceRange {
                .aspectMask = @enumToInt(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT),
                .baseMipLevel =  0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        // TODO: where to free
        swapchain_image_views = try allocator.alloc(VkImageView, swapchain_images.len);
        var i: usize = 0;
        while (i < swapchain_image_views.len) : (i += 1) {
            create_info.image = swapchain_images[i];
            
            var swapchain_image_view: VkImageView = undefined;
            result = vkCreateImageView(device, &create_info, null, &swapchain_image_view);
            std.debug.assert(result == .VK_SUCCESS);

            swapchain_image_views[i] = swapchain_image_view;
        }
    }

    {
        // TODO change cwd() to install path
        const vert_shader_code = io.readSPIRV(std.fs.cwd(), "asset/shader/main/vert.spv", allocator) catch unreachable;
        defer allocator.free(vert_shader_code);
        const frag_shader_code = io.readSPIRV(std.fs.cwd(), "asset/shader/main/frag.spv", allocator) catch unreachable;
        defer allocator.free(frag_shader_code);

        const vert_shader_module = createShaderModule(vert_shader_code);
        defer vkDestroyShaderModule(device, vert_shader_module, null);
        const frag_shader_module = createShaderModule(frag_shader_code);
        defer vkDestroyShaderModule(device, frag_shader_module, null);

        const vert_shader_stage_info = VkPipelineShaderStageCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = .VK_SHADER_STAGE_VERTEX_BIT,
            .module = vert_shader_module,
            .pName = "main",
            .pSpecializationInfo = null,
        };

        const frag_shader_stage_info = VkPipelineShaderStageCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = .VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = frag_shader_module,
            .pName = "main",
            .pSpecializationInfo = null,
        };

        const shader_stages = [_]VkPipelineShaderStageCreateInfo{ vert_shader_stage_info, frag_shader_stage_info };

        const binding_description = Vertex.getBindingDescription();
        const attribute_descriptions = Vertex.getAttributeDescriptions();

        const vertex_input = VkPipelineVertexInputStateCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = &binding_description,
            .vertexAttributeDescriptionCount = attribute_descriptions.len,
            .pVertexAttributeDescriptions = &attribute_descriptions,
        };

        const input_assembly = VkPipelineInputAssemblyStateCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = @boolToInt(false),
        };

        const viewports = [_]VkViewport {
            VkViewport {
                .x = 0.0,
                .y = 0.0,
                .width = @intToFloat(f32, extent.width),
                .height = @intToFloat(f32, extent.height),
                .minDepth = 0.0,
                .maxDepth = 1.0,
            },
        };
        
        const scissors = [_]VkRect2D {
            VkRect2D {
                .offset = VkOffset2D { .x = 0.0, .y = 0.0 },
                .extent = extent,
            },
        };

        const viewport = VkPipelineViewportStateCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .viewportCount = viewports.len,
            .pViewports = &viewports,
            .scissorCount = scissors.len,
            .pScissors = &scissors,
        };

        const rasterization = VkPipelineRasterizationStateCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .depthClampEnable = VK_FALSE,
            .rasterizerDiscardEnable = VK_FALSE,
            .polygonMode = .VK_POLYGON_MODE_FILL,
            .cullMode = @enumToInt(VkCullModeFlagBits.VK_CULL_MODE_NONE),
            .frontFace = .VK_FRONT_FACE_CLOCKWISE,
            .depthBiasEnable = VK_FALSE,
            .depthBiasConstantFactor = 0.0,
            .depthBiasClamp = 0.0,
            .depthBiasSlopeFactor = 0.0,
            .lineWidth = 1.0,
        };

        const multisample = VkPipelineMultisampleStateCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .rasterizationSamples = .VK_SAMPLE_COUNT_1_BIT,
            .sampleShadingEnable = VK_FALSE,
            .minSampleShading = 0.0,
            .pSampleMask = null,
            .alphaToCoverageEnable = VK_FALSE,
            .alphaToOneEnable = VK_FALSE,
        };
        
        // TODO: depth
        
        const color_blend_attachments = [_]VkPipelineColorBlendAttachmentState {
            VkPipelineColorBlendAttachmentState {
                .colorWriteMask = @enumToInt(VkColorComponentFlagBits.VK_COLOR_COMPONENT_R_BIT) |
                                  @enumToInt(VkColorComponentFlagBits.VK_COLOR_COMPONENT_G_BIT) |
                                  @enumToInt(VkColorComponentFlagBits.VK_COLOR_COMPONENT_B_BIT) |
                                  @enumToInt(VkColorComponentFlagBits.VK_COLOR_COMPONENT_A_BIT),
                .blendEnable = VK_FALSE,
                .srcColorBlendFactor = .VK_BLEND_FACTOR_ONE,
                .dstColorBlendFactor = .VK_BLEND_FACTOR_ZERO,
                .colorBlendOp = .VK_BLEND_OP_ADD,
                .srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE,
                .dstAlphaBlendFactor = .VK_BLEND_FACTOR_ZERO,
                .alphaBlendOp = .VK_BLEND_OP_ADD,
            },
        };

        const color_blend = VkPipelineColorBlendStateCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .logicOpEnable = VK_FALSE,
            .logicOp = .VK_LOGIC_OP_COPY,
            .attachmentCount = color_blend_attachments.len,
            .pAttachments = &color_blend_attachments,
            .blendConstants = [_]f32 { 0.0, 0.0, 0.0, 0.0 },
        };

        // TODO: dynamic state

        const graphics_pipeline_create_info = VkGraphicsPipelineCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stageCount = shader_stages.len,
            .pStages = &shader_stages,
            .pVertexInputState = &vertex_input,
            .pInputAssemblyState = &input_assembly,
            .pTessellationState = null,
            .pViewportState = &viewport,
            .pRasterizationState = &rasterization,
            .pMultisampleState = &multisample,
            .pDepthStencilState = null,
            .pColorBlendState = &color_blend,
            .pDynamicState = null,
            .layout = pipeline_layout,
            .renderPass = render_pass,
            .subpass = 0,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };
        
        result = vkCreateGraphicsPipelines(device, null, 1, &graphics_pipeline_create_info, null, &pipeline);
        std.debug.assert(result == .VK_SUCCESS);
    }

    {
        framebuffers = try allocator.alloc(VkFramebuffer, swapchain_images.len);

        var create_info = VkFramebufferCreateInfo {
            .sType = .VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .renderPass = render_pass,
            .attachmentCount = undefined,
            .pAttachments = undefined,
            .width = extent.width,
            .height = extent.height,
            .layers = 1,
        };
        
        var i: usize = 0;
        while (i < framebuffers.len) : (i += 1) {
            const attachments = [_]VkImageView {
                swapchain_image_views[i],
            };

            create_info.attachmentCount = attachments.len;
            create_info.pAttachments = &attachments;

            result = vkCreateFramebuffer(device, &create_info, null, &framebuffers[i]);
            std.debug.assert(result == .VK_SUCCESS);
        }
    }

    {
        command_buffers = try allocator.alloc(VkCommandBuffer, swapchain_images.len);
        const command_buffer_info = VkCommandBufferAllocateInfo {
            .sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .commandPool = graphics_command_pool,
            .level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = @intCast(u32, command_buffers.len),
        };
        result = vkAllocateCommandBuffers(device, &command_buffer_info, command_buffers.ptr);
        std.debug.assert(result == .VK_SUCCESS);

        const begin_info = VkCommandBufferBeginInfo {
            .sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = null,
            .flags = 0,
            .pInheritanceInfo = null,
        };
        
        const clear_colors = [_]VkClearValue {
            VkClearValue {
                .color = VkClearColorValue {
                    .float32 = [_]f32 { 0.0, 0.0, 0.0, 1.0 },
                },
            },
        };

        var i: usize = 0;
        while (i < command_buffers.len) : (i += 1) {
            result = vkBeginCommandBuffer(command_buffers[i], &begin_info);
            std.debug.assert(result == .VK_SUCCESS);

            const render_pass_begin_info = VkRenderPassBeginInfo {
                .sType = .VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
                .pNext = null,
                .renderPass = render_pass,
                .framebuffer = framebuffers[i],
                .renderArea = VkRect2D {
                    .offset = VkOffset2D { .x = 0.0, .y = 0.0 },
                    .extent = extent,
                },
                .clearValueCount = clear_colors.len,
                .pClearValues = &clear_colors,
            };
            
            vkCmdBeginRenderPass(command_buffers[i], &render_pass_begin_info, .VK_SUBPASS_CONTENTS_INLINE);
            vkCmdBindPipeline(command_buffers[i], .VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
            vkCmdBindVertexBuffers(command_buffers[i], 0, 1, &vertex_buffer, &[_]VkDeviceSize {0.0});
            vkCmdBindDescriptorSets(command_buffers[i], .VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout, 0, 1, &descriptor_sets[i], 0, null);    
            vkCmdDraw(command_buffers[i], mesh_vertices.len, 1, 0, 0);
            vkCmdEndRenderPass(command_buffers[i]);

            result = vkEndCommandBuffer(command_buffers[i]);
            std.debug.assert(result == .VK_SUCCESS);
        }
    }
}

fn deinitWithNewExtent() void {
    _ = vkDeviceWaitIdle(device);

    vkFreeCommandBuffers(device, graphics_command_pool, @intCast(u32, command_buffers.len), command_buffers.ptr);
    for (framebuffers) |framebuffer| {
        vkDestroyFramebuffer(device, framebuffer, null);
    }
    allocator.free(framebuffers);
    vkDestroyPipeline(device, pipeline, null);
    for (swapchain_image_views) |view| {
        vkDestroyImageView(device, view, null);
    }
    allocator.free(swapchain_image_views);
    allocator.free(swapchain_images);
    vkDestroySwapchainKHR(device, swapchain, null);
}

