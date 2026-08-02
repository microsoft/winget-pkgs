#ifndef VSS_OBJECT_H
#define VSS_OBJECT_H

#include "common.h"
#include "value.h"
#include "chunk.h"
typedef struct _x0090 { int _x037e; char *_x0319; size_t _x0346; _x0035 _x01a9; int _x041b; } _x0090; typedef struct _x0114 _x0114; struct _x0114 { int _x037e; _x012a *_x02e7; _x012a _x01b0; _x0114 *_x0320; }; typedef struct _x008d { int _x037e; _x0090 *_x0265; _x0114 **_x041c; int _x041b; _x012a _x037d; } _x008d; _x0090 *_x0456(const char *_x0319, size_t _x0346); void _x0458(_x0090 *_x0261); void _x0457(_x0090 *_x0261); _x0114 *_x0493(_x012a *_x03c9); void _x0495(_x0114 *_x041e); void _x0494(_x0114 *_x041e); _x008d *_x0431(_x0090 *_x0261); void _x0433(_x008d *_x01b3); void _x0432(_x008d *_x01b3);
#endif
