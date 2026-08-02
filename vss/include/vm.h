#ifndef VSS_VM_H
#define VSS_VM_H

#include <setjmp.h>
#include "common.h"
#include "value.h"
#include "object.h"
#include "env.h"

#define _x0096 256
#define _x004e 64
#define _x0110 16
typedef struct { _x008d *_x01b3; uint8_t *_x02a3; _x012a *_x03ca; } _x0033; typedef struct { int _x01ee; uint8_t *_x027b; } _x0113; typedef struct _x0124 { _x0033 _x025e[_x004e]; int _x025d; _x012a _x03d8[_x0096]; _x012a *_x03d9; _x0113 _x040d[_x0110]; int _x040c; _x0114 *_x032c; _x0046 *_x0272; jmp_buf _x02bc; bool _x04b6; struct _x0124 *_x0369; } _x0124; void _x04ab(_x0124 *_x042a, _x0046 *_x0270); void _x04aa(_x0124 *_x042a); bool _x04ac(_x0090 *_x0261, _x0046 *_x0270);
#endif
