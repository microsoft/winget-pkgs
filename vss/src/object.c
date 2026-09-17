#include <stdlib.h>
#include <string.h>
#include "object.h"

static char *safe_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) {
        strcpy(dup, s);
    }
    return dup;
}

VSS_ObjFunction *vss_function_new(const char *name, size_t param_count) {
    VSS_ObjFunction *func = malloc(sizeof(VSS_ObjFunction));
    vss_atomic_set(&func->ref_count, 1);
    func->name = safe_strdup(name);
    func->param_count = param_count;
    func->params = NULL;
    func->upvalue_count = 0;
    vss_chunk_init(&func->chunk);
    return func;
}

void vss_function_retain(VSS_ObjFunction *func) {
    if (!func) return;
    vss_atomic_inc(&func->ref_count);
}

void vss_function_release(VSS_ObjFunction *func) {
    if (!func) return;
    if (vss_atomic_dec(&func->ref_count) == 0) {
        free(func->name);
        if (func->params) {
            for (size_t i = 0; i < func->param_count; i++) {
                free(func->params[i]);
            }
            free(func->params);
        }
        vss_chunk_free(&func->chunk);
        free(func);
    }
}

VSS_Upvalue *vss_upvalue_new(VSS_Value *slot) {
    VSS_Upvalue *uv = malloc(sizeof(VSS_Upvalue));
    vss_atomic_set(&uv->ref_count, 1);
    uv->location = slot;
    uv->closed_value = vss_value_new_empty();
    uv->next = NULL;
    return uv;
}

void vss_upvalue_retain(VSS_Upvalue *uv) {
    if (!uv) return;
    vss_atomic_inc(&uv->ref_count);
}

void vss_upvalue_release(VSS_Upvalue *uv) {
    if (!uv) return;
    if (vss_atomic_dec(&uv->ref_count) == 0) {
        vss_value_release(uv->closed_value);
        free(uv);
    }
}

VSS_ObjClosure *vss_closure_new(VSS_ObjFunction *func) {
    VSS_ObjClosure *closure = malloc(sizeof(VSS_ObjClosure));
    vss_atomic_set(&closure->ref_count, 1);
    closure->function = func;
    vss_function_retain(func);
    closure->receiver = vss_value_new_empty();
    
    closure->upvalue_count = func->upvalue_count;
    if (closure->upvalue_count > 0) {
        closure->upvalues = malloc(sizeof(VSS_Upvalue*) * closure->upvalue_count);
        for (int i = 0; i < closure->upvalue_count; i++) {
            closure->upvalues[i] = NULL;
        }
    } else {
        closure->upvalues = NULL;
    }
    return closure;
}

void vss_closure_retain(VSS_ObjClosure *closure) {
    if (!closure) return;
    vss_atomic_inc(&closure->ref_count);
    vss_value_retain(closure->receiver);
}

void vss_closure_release(VSS_ObjClosure *closure) {
    if (!closure) return;
    if (vss_atomic_dec(&closure->ref_count) == 0) {
        vss_function_release(closure->function);
        vss_value_release(closure->receiver);
        if (closure->upvalue_count > 0) {
            for (int i = 0; i < closure->upvalue_count; i++) {
                if (closure->upvalues[i]) {
                    vss_upvalue_release(closure->upvalues[i]);
                }
            }
            free(closure->upvalues);
        }
        free(closure);
    }
}
