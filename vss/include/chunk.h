#ifndef VSS_CHUNK_H
#define VSS_CHUNK_H

#include "common.h"
#include "value.h"
typedef enum { _x0061, _x0062, _x0065, _x0089, _x006a, _x007c, _x006e, _x0084, _x006c, _x0063, _x0083, _x0071, _x0086, _x0055, _x0088, _x0078, _x0064, _x0077, _x007a, _x0079, _x0054, _x005a, _x0058, _x0059, _x0080, _x007b, _x0081, _x0074, _x0075, _x0076, _x005e, _x0060, _x007f, _x008b, _x005b, _x005c, _x006d, _x007d, _x006b, _x0082, _x0087, _x0069, _x007e, _x008a, _x0056, _x0068, _x0057, _x0066, _x0072, _x0073, _x005d, _x005f, _x0067, _x006f, _x0085, _x0070 } _x0092; typedef struct { uint8_t *_x01b8; int *_x02dd; int _x01d7; int _x019c; _x012a *_x01d3; int _x01d0; int _x01cf; } _x0035; void _x042f(_x0035 *_x01a9); void _x042e(_x0035 *_x01a9); void _x0430(_x0035 *_x01a9, uint8_t _x018c, int _x02d9); int _x042d(_x0035 *_x01a9, _x012a _x0425); void _x0439(_x0035 *_x01a9, const char *_x0319); int _x043a(_x0035 *_x01a9, int _x0329);
#endif
