#ifndef VSS_OBJECT_H
#define VSS_OBJECT_H

#include "common.h"
#include "platform.h"
#include "value.h"
#include "chunk.h"

typedef struct VSS_ObjFunction {
    VSS_AtomicInt ref_count;
    char *name;
    size_t param_count;
    char **params;
    VSS_Chunk chunk;
    int upvalue_count;
} VSS_ObjFunction;

typedef struct VSS_Upvalue VSS_Upvalue;
struct VSS_Upvalue {
    VSS_AtomicInt ref_count;
    VSS_Value *location;  // Points to slot on stack (if open) or closed_value (if closed)
    VSS_Value closed_value;
    VSS_Upvalue *next;    // Linked list of open upvalues
};

typedef struct VSS_ObjClosure {
    VSS_AtomicInt ref_count;
    VSS_ObjFunction *function;
    VSS_Upvalue **upvalues;
    int upvalue_count;
    VSS_Value receiver;
} VSS_ObjClosure;

VSS_ObjFunction *vss_function_new(const char *name, size_t param_count);
void vss_function_retain(VSS_ObjFunction *func);
void vss_function_release(VSS_ObjFunction *func);

VSS_Upvalue *vss_upvalue_new(VSS_Value *slot);
void vss_upvalue_retain(VSS_Upvalue *uv);
void vss_upvalue_release(VSS_Upvalue *uv);

VSS_ObjClosure *vss_closure_new(VSS_ObjFunction *func);
void vss_closure_retain(VSS_ObjClosure *closure);
void vss_closure_release(VSS_ObjClosure *closure);

#endif
