#ifndef VSS_CONCURRENCY_H
#define VSS_CONCURRENCY_H

#include "common.h"
#include "platform.h"
#include "value.h"

typedef enum {
    VSS_TASK_CREATED,
    VSS_TASK_RUNNING,
    VSS_TASK_COMPLETED,
    VSS_TASK_FAILED,
    VSS_TASK_CANCELLED
} VSS_TaskStatus;

typedef struct VSS_TaskHandle {
    VSS_AtomicInt ref_count;
    int id;
    VSS_TaskStatus status;
    VSS_Value result;
    char *error_msg;
    bool is_cancelled;
    VSS_Mutex mutex;
    VSS_Cond cond;
    VSS_ObjFunction *function;
    VSS_Value *args;
    size_t arg_count;
    struct VSS_Env *closure_env;
} VSS_TaskHandle;

typedef struct VSS_Channel {
    VSS_AtomicInt ref_count;
    size_t capacity;
    VSS_Value *items;
    size_t head;
    size_t tail;
    size_t count;
    bool closed;
    VSS_Mutex mutex;
    VSS_Cond cond_send;
    VSS_Cond cond_recv;
} VSS_Channel;

typedef struct VSS_MutexVal {
    VSS_AtomicInt ref_count;
    VSS_Mutex lock;
} VSS_MutexVal;

typedef struct VSS_AtomicVal {
    VSS_AtomicInt ref_count;
    VSS_AtomicInt val;
} VSS_AtomicVal;

// Lifecycle
void vss_concurrency_init(void);
void vss_concurrency_cleanup(void);

// Task Handle management
VSS_TaskHandle *vss_task_handle_new(VSS_ObjFunction *func, VSS_Value *args, size_t arg_count, struct VSS_Env *closure_env);
void vss_task_handle_retain(VSS_TaskHandle *handle);
void vss_task_handle_release(VSS_TaskHandle *handle);
VSS_TaskHandle *vss_task_spawn(VSS_ObjFunction *func, VSS_Value *args, size_t arg_count, struct VSS_Env *closure_env);
bool vss_task_await(VSS_TaskHandle *handle, int timeout_ms, VSS_Value *out_val, char **out_err);
void vss_task_cancel(VSS_TaskHandle *handle);

// Channel management
VSS_Channel *vss_channel_new(size_t capacity);
void vss_channel_retain(VSS_Channel *ch);
void vss_channel_release(VSS_Channel *ch);
bool vss_channel_send(VSS_Channel *ch, VSS_Value val);
bool vss_channel_receive(VSS_Channel *ch, int timeout_ms, VSS_Value *out_val, bool *out_closed);
void vss_channel_close(VSS_Channel *ch);

// Mutex value management
VSS_MutexVal *vss_mutex_val_new(void);
void vss_mutex_val_retain(VSS_MutexVal *m);
void vss_mutex_val_release(VSS_MutexVal *m);

// Atomic value management
VSS_AtomicVal *vss_atomic_val_new(int initial_value);
void vss_atomic_val_retain(VSS_AtomicVal *a);
void vss_atomic_val_release(VSS_AtomicVal *a);

#endif
