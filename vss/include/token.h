#ifndef VSS_TOKEN_H
#define VSS_TOKEN_H

#include "common.h"
typedef enum { _x00cc, _x00cf, _x00e8, _x00d7, _x00ed, _x0106, _x00fe, _x00e2, _x00dd, _x00be, _x010b, _x00f1, _x00f2, _x00d3, _x00f8, _x0109, _x0108, _x010a, _x00ca, _x00d9, _x00c9, _x00de, _x0103, _x0107, _x00e7, _x00ff, _x010c, _x010e, _x00e9, _x00cb, _x00b7, _x00f0, _x00ea, _x00b5, _x00bf, _x00bb, _x00bc, _x00fd, _x00ec, _x00dc, _x00d2, _x00f6, _x00db, _x00e3, _x0100, _x00d4, _x00ba, _x00f9, _x00f7, _x010d, _x00b6, _x00ce, _x00d0, _x0102, _x00ef, _x00c4, _x00c2, _x00eb, _x00d5, _x00c1, _x00d6, _x00ee, _x00e5, _x00d1, _x00d8, _x00c3, _x00da, _x00f3, _x00c8, _x00cd, _x00f5, _x00e6, _x0105, _x0104, _x00f4, _x00e0, _x00fb, _x00c6, _x00c5, _x00e1, _x00fc, _x0101, _x00c0, _x00e4, _x00b9, _x00bd, _x010f, _x00c7, _x00b8, _x00df, _x00fa } _x0112; typedef struct { _x0112 _x0412; const char *_x03da; size_t _x02d4; int _x02d9; int _x01bf; } _x0111; const char *_x0492(_x0112 _x0412);
#endif
