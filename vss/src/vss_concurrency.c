#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "vss_concurrency.h"
#include "vm.h"
#include "env.h"
#include "interpreter.h"

static VSS_AtomicInt global_task_id_counter = 0;

// Global Task Queue and Worker Pool
typedef struct TaskNode {
    VSS_TaskHandle *handle;
    struct TaskNode *next;
} TaskNode;

static TaskNode *task_queue_head = NULL;
static TaskNode *task_queue_tail = NULL;
static VSS_Mutex task_queue_mutex;
static VSS_Cond task_queue_cond;
static VSS_Thread *worker_threads = NULL;
static int worker_thread_count = 0;
static bool worker_pool_shutdown = false;

static void *worker_thread_loop(void *arg) {
    (void)arg;
    while (1) {
        vss_mutex_lock(&task_queue_mutex);
        while (!task_queue_head && !worker_pool_shutdown) {
            vss_cond_wait(&task_queue_cond, &task_queue_mutex);
        }
        if (worker_pool_shutdown && !task_queue_head) {
            vss_mutex_unlock(&task_queue_mutex);
            break;
        }

        TaskNode *node = task_queue_head;
        task_queue_head = node->next;
        if (!task_queue_head) {
            task_queue_tail = NULL;
        }
        vss_mutex_unlock(&task_queue_mutex);

        VSS_TaskHandle *handle = node->handle;
        free(node);

        // Execute task
        vss_mutex_lock(&handle->mutex);
        if (handle->is_cancelled) {
            handle->status = VSS_TASK_CANCELLED;
            vss_cond_broadcast(&handle->cond);
            vss_mutex_unlock(&handle->mutex);
            vss_task_handle_release(handle);
            continue;
        }
        handle->status = VSS_TASK_RUNNING;
        vss_mutex_unlock(&handle->mutex);

        // Setup VM execution context (parent environment already contains all builtins and stdlib)
        VSS_Env *exec_env = vss_env_new(handle->closure_env);

        VSS_Value task_res = vss_value_new_empty();
        bool success = vss_vm_run_task(handle->function, handle->args, handle->arg_count, exec_env, &task_res);

        vss_mutex_lock(&handle->mutex);
        if (success) {
            handle->status = VSS_TASK_COMPLETED;
            vss_value_release(handle->result);
            handle->result = task_res;
        } else {
            handle->status = VSS_TASK_FAILED;
            fprintf(stderr, "Worker Task #%d Error Output\n", handle->id);
            handle->error_msg = strdup("Task execution failed with runtime error.");
        }
        vss_cond_broadcast(&handle->cond);
        vss_mutex_unlock(&handle->mutex);

        vss_env_release(exec_env);
        vss_task_handle_release(handle);
    }
    return NULL;
}

void vss_concurrency_init(void) {
    vss_mutex_init(&task_queue_mutex);
    vss_cond_init(&task_queue_cond);
    worker_pool_shutdown = false;

    int nprocs = vss_get_hardware_concurrency();
    worker_thread_count = nprocs > 0 ? nprocs : 4;
    if (worker_thread_count < 2) worker_thread_count = 2;

    worker_threads = malloc(sizeof(VSS_Thread) * worker_thread_count);
    for (int i = 0; i < worker_thread_count; i++) {
        vss_thread_create(&worker_threads[i], worker_thread_loop, NULL);
    }
}

void vss_concurrency_cleanup(void) {
    vss_mutex_lock(&task_queue_mutex);
    worker_pool_shutdown = true;
    vss_cond_broadcast(&task_queue_cond);
    vss_mutex_unlock(&task_queue_mutex);

    for (int i = 0; i < worker_thread_count; i++) {
        vss_thread_join(worker_threads[i], NULL);
    }
    free(worker_threads);
    worker_threads = NULL;
    worker_thread_count = 0;

    vss_mutex_destroy(&task_queue_mutex);
    vss_cond_destroy(&task_queue_cond);
}

VSS_TaskHandle *vss_task_handle_new(VSS_ObjFunction *func, VSS_Value *args, size_t arg_count, struct VSS_Env *closure_env) {
    VSS_TaskHandle *handle = malloc(sizeof(VSS_TaskHandle));
    vss_atomic_set(&handle->ref_count, 1);
    handle->id = vss_atomic_inc(&global_task_id_counter);
    handle->status = VSS_TASK_CREATED;
    handle->result = vss_value_new_empty();
    handle->error_msg = NULL;
    handle->is_cancelled = false;
    vss_mutex_init(&handle->mutex);
    vss_cond_init(&handle->cond);

    handle->function = func;
    if (func) vss_function_retain(func);

    handle->arg_count = arg_count;
    if (arg_count > 0 && args) {
        handle->args = malloc(sizeof(VSS_Value) * arg_count);
        for (size_t i = 0; i < arg_count; i++) {
            handle->args[i] = args[i];
            vss_value_retain(args[i]);
        }
    } else {
        handle->args = NULL;
    }
    handle->closure_env = closure_env;
    if (closure_env) vss_env_retain(closure_env);

    return handle;
}

void vss_task_handle_retain(VSS_TaskHandle *handle) {
    if (!handle) return;
    vss_atomic_inc(&handle->ref_count);
}

void vss_task_handle_release(VSS_TaskHandle *handle) {
    if (!handle) return;
    if (vss_atomic_dec(&handle->ref_count) == 0) {
        vss_value_release(handle->result);
        if (handle->error_msg) free(handle->error_msg);
        if (handle->function) vss_function_release(handle->function);
        if (handle->args) {
            for (size_t i = 0; i < handle->arg_count; i++) {
                vss_value_release(handle->args[i]);
            }
            free(handle->args);
        }
        if (handle->closure_env) vss_env_release(handle->closure_env);
        vss_mutex_destroy(&handle->mutex);
        vss_cond_destroy(&handle->cond);
        free(handle);
    }
}

VSS_TaskHandle *vss_task_spawn(VSS_ObjFunction *func, VSS_Value *args, size_t arg_count, struct VSS_Env *closure_env) {
    VSS_TaskHandle *handle = vss_task_handle_new(func, args, arg_count, closure_env);
    
    TaskNode *node = malloc(sizeof(TaskNode));
    node->handle = handle;
    vss_task_handle_retain(handle);
    node->next = NULL;

    vss_mutex_lock(&task_queue_mutex);
    if (!task_queue_head) {
        task_queue_head = node;
        task_queue_tail = node;
    } else {
        task_queue_tail->next = node;
        task_queue_tail = node;
    }
    vss_cond_signal(&task_queue_cond);
    vss_mutex_unlock(&task_queue_mutex);

    return handle;
}

bool vss_task_await(VSS_TaskHandle *handle, int timeout_ms, VSS_Value *out_val, char **out_err) {
    if (!handle) return false;
    vss_mutex_lock(&handle->mutex);

    if (timeout_ms <= 0) {
        while (handle->status != VSS_TASK_COMPLETED &&
               handle->status != VSS_TASK_FAILED &&
               handle->status != VSS_TASK_CANCELLED) {
            vss_cond_wait(&handle->cond, &handle->mutex);
        }
    } else {
        if (handle->status != VSS_TASK_COMPLETED &&
            handle->status != VSS_TASK_FAILED &&
            handle->status != VSS_TASK_CANCELLED) {
            vss_cond_timedwait(&handle->cond, &handle->mutex, timeout_ms);
        }
    }

    if (handle->status == VSS_TASK_COMPLETED) {
        if (out_val) {
            *out_val = handle->result;
            vss_value_retain(handle->result);
        }
        vss_mutex_unlock(&handle->mutex);
        return true;
    } else if (handle->status == VSS_TASK_FAILED) {
        if (out_err && handle->error_msg) *out_err = strdup(handle->error_msg);
        vss_mutex_unlock(&handle->mutex);
        return false;
    } else if (handle->status == VSS_TASK_CANCELLED) {
        if (out_err) *out_err = strdup("Task was cancelled.");
        vss_mutex_unlock(&handle->mutex);
        return false;
    }

    vss_mutex_unlock(&handle->mutex);
    if (out_err) *out_err = strdup("Task timed out.");
    return false;
}

void vss_task_cancel(VSS_TaskHandle *handle) {
    if (!handle) return;
    vss_mutex_lock(&handle->mutex);
    handle->is_cancelled = true;
    if (handle->status == VSS_TASK_CREATED) {
        handle->status = VSS_TASK_CANCELLED;
        vss_cond_broadcast(&handle->cond);
    }
    vss_mutex_unlock(&handle->mutex);
}

// Channel implementations
VSS_Channel *vss_channel_new(size_t capacity) {
    VSS_Channel *ch = malloc(sizeof(VSS_Channel));
    vss_atomic_set(&ch->ref_count, 1);
    ch->capacity = capacity > 0 ? capacity : 1024;
    ch->items = malloc(sizeof(VSS_Value) * ch->capacity);
    ch->head = 0;
    ch->tail = 0;
    ch->count = 0;
    ch->closed = false;
    vss_mutex_init(&ch->mutex);
    vss_cond_init(&ch->cond_send);
    vss_cond_init(&ch->cond_recv);
    return ch;
}

void vss_channel_retain(VSS_Channel *ch) {
    if (!ch) return;
    vss_atomic_inc(&ch->ref_count);
}

void vss_channel_release(VSS_Channel *ch) {
    if (!ch) return;
    if (vss_atomic_dec(&ch->ref_count) == 0) {
        for (size_t i = 0; i < ch->count; i++) {
            size_t idx = (ch->head + i) % ch->capacity;
            vss_value_release(ch->items[idx]);
        }
        free(ch->items);
        vss_mutex_destroy(&ch->mutex);
        vss_cond_destroy(&ch->cond_send);
        vss_cond_destroy(&ch->cond_recv);
        free(ch);
    }
}

bool vss_channel_send(VSS_Channel *ch, VSS_Value val) {
    if (!ch) return false;
    vss_mutex_lock(&ch->mutex);
    while (ch->count >= ch->capacity && !ch->closed) {
        vss_cond_wait(&ch->cond_send, &ch->mutex);
    }
    if (ch->closed) {
        vss_mutex_unlock(&ch->mutex);
        return false;
    }
    ch->items[ch->tail] = val;
    vss_value_retain(val);
    ch->tail = (ch->tail + 1) % ch->capacity;
    ch->count++;
    vss_cond_signal(&ch->cond_recv);
    vss_mutex_unlock(&ch->mutex);
    return true;
}

bool vss_channel_receive(VSS_Channel *ch, int timeout_ms, VSS_Value *out_val, bool *out_closed) {
    if (!ch) return false;
    vss_mutex_lock(&ch->mutex);
    if (timeout_ms <= 0) {
        while (ch->count == 0 && !ch->closed) {
            vss_cond_wait(&ch->cond_recv, &ch->mutex);
        }
    } else {
        if (ch->count == 0 && !ch->closed) {
            vss_cond_timedwait(&ch->cond_recv, &ch->mutex, timeout_ms);
        }
    }

    if (ch->count > 0) {
        *out_val = ch->items[ch->head];
        ch->head = (ch->head + 1) % ch->capacity;
        ch->count--;
        if (out_closed) *out_closed = false;
        vss_cond_signal(&ch->cond_send);
        vss_mutex_unlock(&ch->mutex);
        return true;
    }

    if (out_closed) *out_closed = ch->closed;
    vss_mutex_unlock(&ch->mutex);
    return false;
}

void vss_channel_close(VSS_Channel *ch) {
    if (!ch) return;
    vss_mutex_lock(&ch->mutex);
    ch->closed = true;
    vss_cond_broadcast(&ch->cond_send);
    vss_cond_broadcast(&ch->cond_recv);
    vss_mutex_unlock(&ch->mutex);
}

// Mutex value management
VSS_MutexVal *vss_mutex_val_new(void) {
    VSS_MutexVal *m = malloc(sizeof(VSS_MutexVal));
    vss_atomic_set(&m->ref_count, 1);
    vss_mutex_init(&m->lock);
    return m;
}

void vss_mutex_val_retain(VSS_MutexVal *m) {
    if (!m) return;
    vss_atomic_inc(&m->ref_count);
}

void vss_mutex_val_release(VSS_MutexVal *m) {
    if (!m) return;
    if (vss_atomic_dec(&m->ref_count) == 0) {
        vss_mutex_destroy(&m->lock);
        free(m);
    }
}

// Atomic value management
VSS_AtomicVal *vss_atomic_val_new(int initial_value) {
    VSS_AtomicVal *a = malloc(sizeof(VSS_AtomicVal));
    vss_atomic_set(&a->ref_count, 1);
    vss_atomic_set(&a->val, initial_value);
    return a;
}

void vss_atomic_val_retain(VSS_AtomicVal *a) {
    if (!a) return;
    vss_atomic_inc(&a->ref_count);
}

void vss_atomic_val_release(VSS_AtomicVal *a) {
    if (!a) return;
    if (vss_atomic_dec(&a->ref_count) == 0) {
        free(a);
    }
}
