#ifndef VSS_ENV_H
#define VSS_ENV_H

#include "common.h"
#include "platform.h"
#include "value.h"

typedef struct {
    char *name;
    VSS_Value value;
    bool is_constant;
} VSS_Binding;

typedef struct VSS_Env {
    VSS_AtomicInt ref_count;
    VSS_Binding *items;
    size_t count;
    size_t capacity;
    struct VSS_Env *parent;
    VSS_Mutex mutex;
} VSS_Env;

VSS_Env *vss_env_new(VSS_Env *parent);
void vss_env_retain(VSS_Env *env);
void vss_env_release(VSS_Env *env);

bool vss_env_define(VSS_Env *env, const char *name, VSS_Value value);
bool vss_env_define_const(VSS_Env *env, const char *name, VSS_Value value);
bool vss_env_assign(VSS_Env *env, const char *name, VSS_Value value);
bool vss_env_get(VSS_Env *env, const char *name, VSS_Value *out_value);
bool vss_env_exists_local(VSS_Env *env, const char *name);

#endif
