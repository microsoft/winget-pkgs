#ifndef VSS_VM_H
#define VSS_VM_H

#include <setjmp.h>
#include "common.h"
#include "value.h"
#include "object.h"
#include "env.h"

#define VSS_STACK_MAX 256
#define VSS_FRAMES_MAX 64
#define VSS_TRAPS_MAX 16

typedef struct {
    VSS_ObjClosure *closure;
    uint8_t *ip;
    VSS_Value *slots;
} VSS_CallFrame;

typedef struct {
    int depth;
    uint8_t *handler_ip;
} VSS_TrapFrame;

typedef struct VSS_VM {
    VSS_CallFrame frames[VSS_FRAMES_MAX];
    int frame_count;
    
    VSS_Value stack[VSS_STACK_MAX];
    VSS_Value *stack_top;
    
    VSS_TrapFrame traps[VSS_TRAPS_MAX];
    int trap_count;
    
    VSS_Upvalue *open_upvalues;
    VSS_Env *globals;
    jmp_buf jump_buffer;
    bool yielded;
    struct VSS_VM *prev_vm_instance;
} VSS_VM;

void vss_vm_init(VSS_VM *vm, VSS_Env *global_env);
void vss_vm_free(VSS_VM *vm);
bool vss_vm_run(VSS_ObjFunction *func, VSS_Env *global_env);
bool vss_vm_run_task(VSS_ObjFunction *func, VSS_Value *args, size_t arg_count, VSS_Env *global_env, VSS_Value *out_result);

#endif
