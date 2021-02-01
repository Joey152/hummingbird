const std = @import("std");

const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;

pub const Vec3 = struct {
    data: [3]f32,
    
    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return Vec3 {
            .data = [3]f32 { x, y, z }
        };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return Vec3 {
            .data = [3]f32 {
                a.data[0] + b.data[0],
                a.data[1] + b.data[1],
                a.data[2] + b.data[2],
            }
        };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return Vec3 {
            .data = [3]f32 {
                a.data[0] - b.data[0],
                a.data[1] - b.data[1],
                a.data[2] - b.data[2],
            }
        };
    }

    pub fn mul(a: Vec3, b: Vec3) Vec3 {
        return Vec3 {
            .data = [3]f32 {
                a.data[0] * b.data[0],
                a.data[1] * b.data[1],
                a.data[2] * b.data[2],
            }
        };
    }

    pub fn div(a: Vec3, b: Vec3) Vec3 {
        return Vec3 {
            .data = [3]f32 {
                a.data[0] / b.data[0],
                a.data[1] / b.data[1],
                a.data[2] / b.data[2],
            }
        };
    }

    pub fn scale(a: Vec3, x: f32) Vec3 {
        return Vec3 {
            .data = [3]f32 {
                a.data[0] * x,
                a.data[1] * x,
                a.data[2] * x,
            }
        };
    }

    pub fn length(a: Vec3) f32 {
        return math.sqrt(
            math.pow(f32, a.data[0], 2) +
            math.pow(f32, a.data[1], 2) +
            math.pow(f32, a.data[2], 2)
        );
    }

    pub fn normalize(a: Vec3) Vec3 {
        const l = Vec3.length(a);
        return Vec3 {
            .data = [3]f32 {
                a.data[0] / l,
                a.data[1] / l,
                a.data[2] / l,
            }
        };
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return Vec3.init(
            a.data[1] * b.data[2] - a.data[2] * b.data[1],
            a.data[2] * b.data[0] - a.data[0] * b.data[2],
            a.data[0] * b.data[1] - a.data[1] * b.data[0],
        );
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.data[0] * b.data[0] + a.data[1] * b.data[1] + a.data[2] * b.data[2];
    }
};

test "Vec3 add" {
    const a = Vec3.init(1,2,3);
    const b = Vec3.init(4,5,6);
    const c = Vec3.init(5,7,9);
    const d = Vec3.add(a, b);
    assert(mem.eql(f32, &c.data, &d.data));
}

test "Vec3 subtract" {
    const a = Vec3.init(1,2,3);
    const b = Vec3.init(4,5,6);
    const c = Vec3.init(-3, -3, -3);
    const d = Vec3.init(3,3,3);
    const e = Vec3.sub(a,b);
    const f = Vec3.sub(b,a);

    assert(mem.eql(f32, &c.data, &e.data));
    assert(mem.eql(f32, &d.data, &f.data));
}

test "Vec3 normalize" {
    const a = Vec3.init(1, 1, 1);
    const b = Vec3.init(22, 22, 22);
    const c = Vec3.init(0.57735026919, 0.57735026919, 0.57735026919);
    const d = Vec3.normalize(a);
    const e = Vec3.normalize(b);

    assert(math.absFloat(d.data[0] - c.data[0]) < 0.0001);
    assert(math.absFloat(d.data[1] - c.data[1]) < 0.0001);
    assert(math.absFloat(d.data[2] - c.data[2]) < 0.0001);
    assert(math.absFloat(e.data[0] - c.data[0]) < 0.0001);
    assert(math.absFloat(e.data[1] - c.data[1]) < 0.0001);
    assert(math.absFloat(e.data[2] - c.data[2]) < 0.0001);
}

test "Vec3 cross" {

}

test "Vec3 dot" {
    const a = Vec3.init(1, 2, 3);
    const b = Vec3.init(4, 5, 6);
    const c = 32.0;
    const d = Vec3.dot(a, b);

    assert(c == d);
}

pub const Mat4 = extern struct {
    data: [4][4]f32 align(4),

    pub fn init(a: [4][4]f32) Mat4 {
        return Mat4 {
            .data = a
        };
    }

    pub fn identity() Mat4 {
        return Mat4 {
            .data = [4][4]f32 {
                [4]f32 { 1.0, 0.0, 0.0, 0.0 },
                [4]f32 { 0.0, 1.0, 0.0, 0.0 },
                [4]f32 { 0.0, 0.0, 1.0, 0.0 },
                [4]f32 { 0.0, 0.0, 0.0, 1.0 },
            }
        };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var m = Mat4.init([4][4]f32 {
            [4]f32{0.0, 0.0, 0.0, 0.0},
            [4]f32{0.0, 0.0, 0.0, 0.0},
            [4]f32{0.0, 0.0, 0.0, 0.0},
            [4]f32{0.0, 0.0, 0.0, 0.0},
        });

        comptime var col = 0;
        inline while (col < 4) : (col += 1) {
            comptime var row = 0;
            inline while (row < 4) : (row += 1) {
                comptime var offset = 0;
                inline while (offset < 4) : (offset += 1) {
                    m.data[col][row] += a.data[offset][row] * b.data[col][offset];
                }
            }
        }

        return m;
    }

    pub fn add(a: Mat4, b: Mat4) Mat4 {
        var m = Mat4.init([_]f32{0.0} ** 4 ** 4);
        return m;
    }

    pub fn view(pos: Vec3, dir: Vec3) Mat4 {
        // TODO(performance): assert dir is a normalized vector
        const up = Vec3.init(0.0, 1.0, 0.0);
        const zaxis = Vec3.normalize(dir);
        const xaxis = Vec3.normalize(Vec3.cross(up, zaxis));
        const yaxis = Vec3.cross(zaxis, xaxis);
        const posx = -Vec3.dot(xaxis, pos);
        const posy = -Vec3.dot(yaxis, pos);
        const posz = -Vec3.dot(zaxis, pos);

        return Mat4.init([4][4]f32 {
//            [4]f32 { xaxis.data[0], xaxis.data[1], xaxis.data[2], 0.0 },
//            [4]f32 { yaxis.data[0], yaxis.data[1], yaxis.data[2], 0.0 },
//            [4]f32 { zaxis.data[0], zaxis.data[1], zaxis.data[2], 0.0 },
            [4]f32 { xaxis.data[0], yaxis.data[0], zaxis.data[0], 0.0  },
            [4]f32 { xaxis.data[1], yaxis.data[1], zaxis.data[1], 0.0 },
            [4]f32 { xaxis.data[2], yaxis.data[2], zaxis.data[2], 0.0 },
            [4]f32 { posx, posy, posz, 1.0 },
            //[4]f32 { -pos.data[0], -pos.data[1], -pos.data[2], 1.0 },
        });
//        return Mat4.init([4][4]f32 {
//            [4]f32 { xaxis.data[0], yaxis.data[0], zaxis.data[0], posx  },
//            [4]f32 { xaxis.data[1], yaxis.data[1], zaxis.data[1], posy },
//            [4]f32 { xaxis.data[2], yaxis.data[2], zaxis.data[2], posz },
//            [4]f32 { 0.0, 0.0, 0.0, 1.0 },
//        });
    }

    pub fn perspective(aspect: f32, fovy: f32, n: f32, f: f32) Mat4 {
        const x = 1.0 / (aspect * std.math.tan(fovy/2.0));
        const y = 1.0 / std.math.tan(fovy/2.0);
        const a = (f + n) / (n - f);
        const b = (2.0 * f * n) / (n - f);

        const p = Mat4.init([4][4]f32 {
            [4]f32 { x,   0.0, 0.0, 0.0 },
            [4]f32 { 0.0, y,   0.0, 0.0 },
            [4]f32 { 0.0, 0.0, -a,   1.0 },
            [4]f32 { 0.0, 0.0, b,   0.0 },
        });

        const c = Mat4.init([4][4]f32 {
            [4]f32 { 1.0, 0.0, 0.0, 0.0 },
            [4]f32 { 0.0, 1.0, 0.0, 0.0 },
            [4]f32 { 0.0, 0.0, 0.5, 0.0 },
            [4]f32 { 0.0, 0.0, 0.5, 1.0 },
        });

        return Mat4.mul(c, p);
        //return p;
    }
};

test "Mat4 multiplication" {
    const a = Mat4.init([4][4]f32 {
        [4]f32 { 5.0, 0.0, 3.0, 1.0 },
        [4]f32 { 2.0, 6.0, 8.0, 8.0 },
        [4]f32 { 6.0, 2.0, 1.0, 5.0 },
        [4]f32 { 1.0, 0.0, 4.0, 6.0 },
    });
    const b = Mat4.init([4][4]f32 {
        [4]f32 { 7.0, 1.0, 9.0, 5.0 },
        [4]f32 { 5.0, 8.0, 4.0, 3.0 },
        [4]f32 { 8.0, 2.0, 3.0, 7.0 },
        [4]f32 { 0.0, 6.0, 8.0, 9.0 },
    });
    const c = Mat4.init([4][4]f32 {
        [4]f32 { 96.0, 24.0, 58.0, 90.0 },
        [4]f32 { 68.0, 56.0, 95.0, 107.0 },
        [4]f32 { 69.0, 18.0, 71.0, 81.0 },
        [4]f32 { 69.0, 52.0, 92.0, 142.0 },
    });
    const d = Mat4.mul(a, b);

    assert(mem.eql(f32, &c.data[0], &d.data[0]));
    assert(mem.eql(f32, &c.data[1], &d.data[1]));
    assert(mem.eql(f32, &c.data[2], &d.data[2]));
    assert(mem.eql(f32, &c.data[3], &d.data[3]));
}

