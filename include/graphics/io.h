#pragma once

#include <errno.h>
#include <stdint.h>

int io_read_spirv(char const *relative_path, uint32_t *size, uint32_t **spirv);

