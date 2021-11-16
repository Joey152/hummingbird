#include "game/io.h"

#include <assert.h>
#include <stdio.h>
#include <stdint.h>

#include "graphics/vertex.h"

void
io_get_triangle_count(FILE *file, uint32_t *count)
{
    fread(count, sizeof *count, 1, file);
}

void
io_load_mesh(FILE *file, uint32_t *count, struct Vertex *vertices)
{
    fread(vertices, sizeof *vertices, *count, file);
}
