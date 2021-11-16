#include <inttypes.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#include "game/io.h"
#include "graphics/graphics.h"
#include "graphics/vertex.h"
#include "common/linmath.h"
#include "platform/platform.h"

#ifndef M_PI
#define M_PI (3.14159265358979323846)
#endif

static struct UBO ubo;
static float camera_pos[3] = {0.0f, 9.5f, 0.0f};
static float camera_dir[3] = {0.0f, 0.0f, 1.0f};
static float up_dir[3] = {0.0f, -1.0f, 0.0f};
static float mouse_yaw = 0.0f;
static float mouse_pitch = 0.0f;
static float const init_mouse_pitch = 0.0f;
static float const init_mouse_yaw = 0.0f;
static double xmouse_prev = 0.0f;
static double ymouse_prev = 0.0f;
static struct PlayerControlEvent control_event;

int
main(void)
{
    platform.create_window();

    graphics.init();

    #define MAP1_SIZE 2
    char const *map1[MAP1_SIZE] = {
        "asset/mesh/map1.vertex",
        "asset/mesh/monkey.vertex",
    };
    uint32_t vertex_count[MAP1_SIZE+1];
    vertex_count[0] = 0;
    uint32_t total_vertex_count = 0;
    uint32_t vertex_offset[MAP1_SIZE+1];
    vertex_offset[0] = 0;
    FILE *file[MAP1_SIZE];
    for (int i = 0; i < MAP1_SIZE; i++)
    {
        file[i] = fopen(map1[i], "rb");
        io_get_triangle_count(file[i], &vertex_count[i]);
        total_vertex_count += vertex_count[i];
        vertex_offset[i+1] = vertex_offset[i] + vertex_count[i];
        printf("%u: %u\n", i,  vertex_count[i]);
    }
    struct Vertex *vertices = malloc(total_vertex_count * sizeof *vertices);
    for (int i = 0; i < MAP1_SIZE; i++)
    {
        io_load_mesh(file[i], &vertex_count[i], &vertices[vertex_offset[i]]);
        fclose(file[i]);
    }

    graphics.load_map(total_vertex_count, vertices);

    float cos_yaw = cosf(mouse_yaw);
    float sin_yaw = sinf(mouse_yaw);
    float cos_pitch = cosf(mouse_pitch);
    float sin_pitch = sinf(mouse_pitch);
    mat4_view(ubo.view, camera_pos, cos_yaw, sin_yaw, cos_pitch, sin_pitch);
    mat4_perspective(ubo.proj, 16.0f/9.0f, 90.0f * M_PI / 180.0f, 0.01f, 1000.0f);

    platform.init_timestamp();
    while (platform.is_application_running())
    {
        platform.poll_events();
        platform.get_keyboard_events(&control_event);
        mouse_pitch = control_event.mouse_y / 100.0 + init_mouse_pitch;
        mouse_yaw = control_event.mouse_x / 100.0 + init_mouse_yaw;
        float cos_yaw = cosf(mouse_yaw);
        float sin_yaw = sinf(mouse_yaw);
        float cos_pitch = cosf(mouse_pitch);
        float sin_pitch = sinf(mouse_pitch);
        float forward[3] = { sin_yaw, 0.0f, cos_yaw, };
        float strafe[3];
        vec3_cross(strafe, forward, up_dir);
        vec3_add(camera_pos, forward[0] * control_event.forward_time * 0.0000001f, forward[1], forward[2] * control_event.forward_time * 0.0000001f);
        vec3_add(camera_pos, strafe[0] * control_event.strafe_time * 0.0000001f, strafe[1], strafe[2] * control_event.strafe_time * 0.0000001f);
        mat4_view(ubo.view, camera_pos, cos_yaw, sin_yaw, cos_pitch, sin_pitch);
        graphics.draw_frame(&ubo);
    }

    free(vertices);

    graphics.deinit();

    return EXIT_SUCCESS;
}
