#include <stdlib.h>
#include <string.h>

#include "env.h"

static char *safe_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) {
        strcpy(dup, s);
    }
    return dup;
}

VSS_Env *vss_env_new(VSS_Env *parent) {
    VSS_Env *env = malloc(sizeof(VSS_Env));
    if (env) {
        vss_atomic_set(&env->ref_count, 1);
        env->items = NULL;
        env->count = 0;
        env->capacity = 0;
        env->parent = parent;
        vss_mutex_init(&env->mutex);
        if (parent) {
            vss_env_retain(parent);
        }
    }
    return env;
}

void vss_env_retain(VSS_Env *env) {
    if (env) {
        vss_atomic_inc(&env->ref_count);
    }
}

void vss_env_release(VSS_Env *env) {
    if (!env) return;
    if (vss_atomic_dec(&env->ref_count) == 0) {
        vss_mutex_lock(&env->mutex);
        for (size_t i = 0; i < env->count; i++) {
            free(env->items[i].name);
            vss_value_release(env->items[i].value);
        }
        free(env->items);
        VSS_Env *parent = env->parent;
        vss_mutex_unlock(&env->mutex);
        vss_mutex_destroy(&env->mutex);
        free(env);
        if (parent) {
            vss_env_release(parent);
        }
    }
}

bool vss_env_define(VSS_Env *env, const char *name, VSS_Value value) {
    if (!env) return false;
    vss_mutex_lock(&env->mutex);
    if (vss_env_exists_local(env, name)) {
        vss_mutex_unlock(&env->mutex);
        return false;
    }
    
    if (env->count >= env->capacity) {
        env->capacity = env->capacity == 0 ? 8 : env->capacity * 2;
        env->items = realloc(env->items, sizeof(VSS_Binding) * env->capacity);
    }
    
    VSS_Binding *b = &env->items[env->count++];
    b->name = safe_strdup(name);
    b->value = value;
    b->is_constant = false;
    vss_value_retain(value);
    vss_mutex_unlock(&env->mutex);
    return true;
}

bool vss_env_define_const(VSS_Env *env, const char *name, VSS_Value value) {
    if (!env) return false;
    vss_mutex_lock(&env->mutex);
    if (vss_env_exists_local(env, name)) {
        vss_mutex_unlock(&env->mutex);
        return false;
    }
    
    if (env->count >= env->capacity) {
        env->capacity = env->capacity == 0 ? 8 : env->capacity * 2;
        env->items = realloc(env->items, sizeof(VSS_Binding) * env->capacity);
    }
    
    VSS_Binding *b = &env->items[env->count++];
    b->name = safe_strdup(name);
    b->value = value;
    b->is_constant = true;
    vss_value_retain(value);
    vss_mutex_unlock(&env->mutex);
    return true;
}

bool vss_env_assign(VSS_Env *env, const char *name, VSS_Value value) {
    VSS_Env *current = env;
    while (current) {
        vss_mutex_lock(&current->mutex);
        for (size_t i = 0; i < current->count; i++) {
            if (strcmp(current->items[i].name, name) == 0) {
                if (current->items[i].is_constant) {
                    vss_mutex_unlock(&current->mutex);
                    return false;
                }
                vss_value_release(current->items[i].value);
                current->items[i].value = value;
                vss_value_retain(value);
                vss_mutex_unlock(&current->mutex);
                return true;
            }
        }
        VSS_Env *next = current->parent;
        vss_mutex_unlock(&current->mutex);
        current = next;
    }
    return false;
}

bool vss_env_get(VSS_Env *env, const char *name, VSS_Value *out_value) {
    VSS_Env *current = env;
    while (current) {
        vss_mutex_lock(&current->mutex);
        for (size_t i = 0; i < current->count; i++) {
            if (strcmp(current->items[i].name, name) == 0) {
                *out_value = current->items[i].value;
                vss_value_retain(*out_value);
                vss_mutex_unlock(&current->mutex);
                return true;
            }
        }
        VSS_Env *next = current->parent;
        vss_mutex_unlock(&current->mutex);
        current = next;
    }
    return false;
}

bool vss_env_exists_local(VSS_Env *env, const char *name) {
    if (!env) return false;
    for (size_t i = 0; i < env->count; i++) {
        if (strcmp(env->items[i].name, name) == 0) {
            return true;
        }
    }
    return false;
}
