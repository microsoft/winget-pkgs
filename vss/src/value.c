#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "value.h"
#include "env.h"
#include "ast.h"
#include "object.h"
#include "vss_concurrency.h"

// Helper to duplicate string safely
static char *safe_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) {
        strcpy(dup, s);
    }
    return dup;
}

VSS_Value vss_value_new_number(double n) {
    VSS_Value v;
    v.type = VSS_VAL_NUMBER;
    v.as.number = n;
    return v;
}

VSS_Value vss_value_new_string(const char *s) {
    VSS_Value v;
    v.type = VSS_VAL_STRING;
    v.as.string = malloc(sizeof(VSS_ValString));
    vss_atomic_set(&v.as.string->ref_count, 1);
    v.as.string->chars = safe_strdup(s);
    return v;
}

VSS_Value vss_value_new_bool(bool b) {
    VSS_Value v;
    v.type = VSS_VAL_BOOL;
    v.as.boolean = b;
    return v;
}

VSS_Value vss_value_new_empty(void) {
    VSS_Value v;
    v.type = VSS_VAL_EMPTY;
    return v;
}

VSS_Value vss_value_new_list(void) {
    VSS_Value v;
    v.type = VSS_VAL_LIST;
    v.as.list = malloc(sizeof(VSS_ValList));
    vss_atomic_set(&v.as.list->ref_count, 1);
    v.as.list->items = NULL;
    v.as.list->count = 0;
    v.as.list->capacity = 0;
    return v;
}

VSS_Value vss_value_new_map(void) {
    VSS_Value v;
    v.type = VSS_VAL_MAP;
    v.as.map = malloc(sizeof(VSS_ValMap));
    vss_atomic_set(&v.as.map->ref_count, 1);
    v.as.map->entries = NULL;
    v.as.map->count = 0;
    v.as.map->capacity = 0;
    return v;
}

VSS_Value vss_value_new_task(char **params, size_t param_count, struct VSS_Stmt **body, size_t body_count, struct VSS_Env *closure) {
    VSS_Value v;
    v.type = VSS_VAL_TASK;
    v.as.task = malloc(sizeof(VSS_ValTask));
    vss_atomic_set(&v.as.task->ref_count, 1);
    
    v.as.task->param_count = param_count;
    v.as.task->params = malloc(sizeof(char*) * param_count);
    for (size_t i = 0; i < param_count; i++) {
        v.as.task->params[i] = safe_strdup(params[i]);
    }
    
    v.as.task->body_count = body_count;
    v.as.task->body = malloc(sizeof(struct VSS_Stmt*) * body_count);
    for (size_t i = 0; i < body_count; i++) {
        v.as.task->body[i] = body[i]; // Statements are owned by AST
    }
    
    v.as.task->closure = closure;
    if (closure) {
        vss_env_retain(closure);
    }
    
    return v;
}

VSS_Value vss_value_new_native(VSS_NativeFnPtr func) {
    VSS_Value v;
    v.type = VSS_VAL_NATIVE;
    v.as.native = func;
    return v;
}

VSS_Value vss_value_new_closure(VSS_ObjClosure *closure) {
    VSS_Value val;
    val.type = VSS_VAL_CLOSURE;
    val.as.closure = closure;
    vss_closure_retain(closure);
    return val;
}

VSS_Value vss_value_new_function(VSS_ObjFunction *func) {
    VSS_Value val;
    val.type = VSS_VAL_FUNCTION;
    val.as.function = func;
    vss_function_retain(func);
    return val;
}

VSS_Value vss_value_new_class(const char *name, VSS_ObjClass *parent) {
    VSS_ObjClass *klass = malloc(sizeof(VSS_ObjClass));
    vss_atomic_set(&klass->ref_count, 1);
    klass->name = safe_strdup(name);
    klass->parent = parent;
    if (parent) {
        VSS_Value pval;
        pval.type = VSS_VAL_CLASS;
        pval.as.klass = parent;
        vss_value_retain(pval);
    }
    VSS_Value m = vss_value_new_map();
    klass->methods = m.as.map;
    vss_atomic_inc(&klass->methods->ref_count);
    vss_value_release(m);
    
    VSS_Value val;
    val.type = VSS_VAL_CLASS;
    val.as.klass = klass;
    return val;
}

VSS_Value vss_value_new_instance(VSS_ObjClass *klass) {
    VSS_ObjInstance *inst = malloc(sizeof(VSS_ObjInstance));
    vss_atomic_set(&inst->ref_count, 1);
    inst->klass = klass;
    if (klass) {
        VSS_Value kval;
        kval.type = VSS_VAL_CLASS;
        kval.as.klass = klass;
        vss_value_retain(kval);
    }
    VSS_Value f = vss_value_new_map();
    inst->fields = f.as.map;
    vss_atomic_inc(&inst->fields->ref_count);
    vss_value_release(f);
    
    VSS_Value val;
    val.type = VSS_VAL_INSTANCE;
    val.as.instance = inst;
    return val;
}

VSS_Value vss_value_new_enum(const char *name) {
    VSS_ObjEnum *enm = malloc(sizeof(VSS_ObjEnum));
    vss_atomic_set(&enm->ref_count, 1);
    enm->name = safe_strdup(name);
    VSS_Value m = vss_value_new_map();
    enm->members = m.as.map;
    vss_atomic_inc(&enm->members->ref_count);
    vss_value_release(m);
    
    VSS_Value val;
    val.type = VSS_VAL_ENUM;
    val.as.enm = enm;
    return val;
}

VSS_Value vss_value_new_enum_val(const char *enum_name, const char *member_name, int value) {
    VSS_ObjEnumVal *enm_val = malloc(sizeof(VSS_ObjEnumVal));
    vss_atomic_set(&enm_val->ref_count, 1);
    enm_val->enum_name = safe_strdup(enum_name);
    enm_val->member_name = safe_strdup(member_name);
    enm_val->value = value;
    
    VSS_Value val;
    val.type = VSS_VAL_ENUM_VAL;
    val.as.enm_val = enm_val;
    return val;
}

VSS_Value vss_value_new_task_handle(VSS_TaskHandle *handle) {
    VSS_Value val;
    val.type = VSS_VAL_TASK_HANDLE;
    val.as.task_handle = handle;
    vss_task_handle_retain(handle);
    return val;
}

VSS_Value vss_value_new_channel(VSS_Channel *channel) {
    VSS_Value val;
    val.type = VSS_VAL_CHANNEL;
    val.as.channel = channel;
    vss_channel_retain(channel);
    return val;
}

VSS_Value vss_value_new_mutex(VSS_MutexVal *mutex) {
    VSS_Value val;
    val.type = VSS_VAL_MUTEX;
    val.as.mutex = mutex;
    vss_mutex_val_retain(mutex);
    return val;
}

VSS_Value vss_value_new_atomic(VSS_AtomicVal *atomic) {
    VSS_Value val;
    val.type = VSS_VAL_ATOMIC;
    val.as.atomic = atomic;
    vss_atomic_val_retain(atomic);
    return val;
}

void vss_value_retain(VSS_Value v) {
    switch (v.type) {
        case VSS_VAL_STRING:
            vss_atomic_inc(&v.as.string->ref_count);
            break;
        case VSS_VAL_LIST:
            vss_atomic_inc(&v.as.list->ref_count);
            break;
        case VSS_VAL_MAP:
            vss_atomic_inc(&v.as.map->ref_count);
            break;
        case VSS_VAL_TASK:
            vss_atomic_inc(&v.as.task->ref_count);
            break;
        case VSS_VAL_CLOSURE:
            vss_closure_retain(v.as.closure);
            break;
        case VSS_VAL_FUNCTION:
            vss_function_retain(v.as.function);
            break;
        case VSS_VAL_CLASS:
            vss_atomic_inc(&v.as.klass->ref_count);
            break;
        case VSS_VAL_INSTANCE:
            vss_atomic_inc(&v.as.instance->ref_count);
            break;
        case VSS_VAL_ENUM:
            vss_atomic_inc(&v.as.enm->ref_count);
            break;
        case VSS_VAL_ENUM_VAL:
            vss_atomic_inc(&v.as.enm_val->ref_count);
            break;
        case VSS_VAL_TASK_HANDLE:
            vss_task_handle_retain(v.as.task_handle);
            break;
        case VSS_VAL_CHANNEL:
            vss_channel_retain(v.as.channel);
            break;
        case VSS_VAL_MUTEX:
            vss_mutex_val_retain(v.as.mutex);
            break;
        case VSS_VAL_ATOMIC:
            vss_atomic_val_retain(v.as.atomic);
            break;
        default:
            break;
    }
}

void vss_value_release(VSS_Value v) {
    switch (v.type) {
        case VSS_VAL_STRING:
            if (vss_atomic_dec(&v.as.string->ref_count) == 0) {
                free(v.as.string->chars);
                free(v.as.string);
            }
            break;
        case VSS_VAL_LIST:
            if (vss_atomic_dec(&v.as.list->ref_count) == 0) {
                for (size_t i = 0; i < v.as.list->count; i++) {
                    vss_value_release(v.as.list->items[i]);
                }
                free(v.as.list->items);
                free(v.as.list);
            }
            break;
        case VSS_VAL_MAP:
            if (vss_atomic_dec(&v.as.map->ref_count) == 0) {
                for (size_t i = 0; i < v.as.map->count; i++) {
                    free(v.as.map->entries[i].key);
                    vss_value_release(v.as.map->entries[i].value);
                }
                free(v.as.map->entries);
                free(v.as.map);
            }
            break;
        case VSS_VAL_TASK:
            if (vss_atomic_dec(&v.as.task->ref_count) == 0) {
                for (size_t i = 0; i < v.as.task->param_count; i++) {
                    free(v.as.task->params[i]);
                }
                free(v.as.task->params);
                free(v.as.task->body);
                if (v.as.task->closure) {
                    vss_env_release(v.as.task->closure);
                }
                free(v.as.task);
            }
            break;
        case VSS_VAL_CLOSURE:
            vss_closure_release(v.as.closure);
            break;
        case VSS_VAL_FUNCTION:
            vss_function_release(v.as.function);
            break;
        case VSS_VAL_CLASS:
            if (vss_atomic_dec(&v.as.klass->ref_count) == 0) {
                free(v.as.klass->name);
                if (v.as.klass->parent) {
                    VSS_Value pval;
                    pval.type = VSS_VAL_CLASS;
                    pval.as.klass = v.as.klass->parent;
                    vss_value_release(pval);
                }
                if (v.as.klass->methods) {
                    VSS_Value mval;
                    mval.type = VSS_VAL_MAP;
                    mval.as.map = v.as.klass->methods;
                    vss_value_release(mval);
                }
                free(v.as.klass);
            }
            break;
        case VSS_VAL_INSTANCE:
            if (vss_atomic_dec(&v.as.instance->ref_count) == 0) {
                if (v.as.instance->klass) {
                    VSS_Value kval;
                    kval.type = VSS_VAL_CLASS;
                    kval.as.klass = v.as.instance->klass;
                    vss_value_release(kval);
                }
                if (v.as.instance->fields) {
                    VSS_Value fval;
                    fval.type = VSS_VAL_MAP;
                    fval.as.map = v.as.instance->fields;
                    vss_value_release(fval);
                }
                free(v.as.instance);
            }
            break;
        case VSS_VAL_ENUM:
            if (vss_atomic_dec(&v.as.enm->ref_count) == 0) {
                free(v.as.enm->name);
                if (v.as.enm->members) {
                    VSS_Value mval;
                    mval.type = VSS_VAL_MAP;
                    mval.as.map = v.as.enm->members;
                    vss_value_release(mval);
                }
                free(v.as.enm);
            }
            break;
        case VSS_VAL_ENUM_VAL:
            if (vss_atomic_dec(&v.as.enm_val->ref_count) == 0) {
                free(v.as.enm_val->enum_name);
                free(v.as.enm_val->member_name);
                free(v.as.enm_val);
            }
            break;
        case VSS_VAL_TASK_HANDLE:
            vss_task_handle_release(v.as.task_handle);
            break;
        case VSS_VAL_CHANNEL:
            vss_channel_release(v.as.channel);
            break;
        case VSS_VAL_MUTEX:
            vss_mutex_val_release(v.as.mutex);
            break;
        case VSS_VAL_ATOMIC:
            vss_atomic_val_release(v.as.atomic);
            break;
        default:
            break;
    }
}

bool vss_value_same_as(VSS_Value a, VSS_Value b) {
    if (a.type != b.type) return false;
    switch (a.type) {
        case VSS_VAL_NUMBER:
            return a.as.number == b.as.number;
        case VSS_VAL_STRING:
            return strcmp(a.as.string->chars, b.as.string->chars) == 0;
        case VSS_VAL_BOOL:
            return a.as.boolean == b.as.boolean;
        case VSS_VAL_EMPTY:
            return true;
        case VSS_VAL_LIST:
            if (a.as.list == b.as.list) return true;
            if (a.as.list->count != b.as.list->count) return false;
            for (size_t i = 0; i < a.as.list->count; i++) {
                if (!vss_value_same_as(a.as.list->items[i], b.as.list->items[i])) return false;
            }
            return true;
        case VSS_VAL_MAP:
            if (a.as.map == b.as.map) return true;
            if (a.as.map->count != b.as.map->count) return false;
            for (size_t i = 0; i < a.as.map->count; i++) {
                // Find matching key in b
                bool found = false;
                for (size_t j = 0; j < b.as.map->count; j++) {
                    if (strcmp(a.as.map->entries[i].key, b.as.map->entries[j].key) == 0) {
                        if (!vss_value_same_as(a.as.map->entries[i].value, b.as.map->entries[j].value)) {
                            return false;
                        }
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
            }
            return true;
        case VSS_VAL_TASK:
            return a.as.task == b.as.task;
        case VSS_VAL_NATIVE:
            return a.as.native == b.as.native;
        case VSS_VAL_CLOSURE:
            return a.as.closure == b.as.closure;
        case VSS_VAL_FUNCTION:
            return a.as.function == b.as.function;
        case VSS_VAL_CLASS:
            return a.as.klass == b.as.klass;
        case VSS_VAL_INSTANCE:
            return a.as.instance == b.as.instance;
        case VSS_VAL_ENUM:
            return a.as.enm == b.as.enm;
        case VSS_VAL_ENUM_VAL:
            return (strcmp(a.as.enm_val->enum_name, b.as.enm_val->enum_name) == 0 &&
                    strcmp(a.as.enm_val->member_name, b.as.enm_val->member_name) == 0);
    }
    return false;
}

bool vss_value_truthy(VSS_Value v) {
    switch (v.type) {
        case VSS_VAL_BOOL:
            return v.as.boolean;
        case VSS_VAL_EMPTY:
            return false;
        case VSS_VAL_NUMBER:
            return v.as.number != 0.0;
        case VSS_VAL_STRING:
            return strlen(v.as.string->chars) > 0;
        case VSS_VAL_LIST:
            return v.as.list->count > 0;
        default:
            return true;
    }
}

char *vss_value_to_string(VSS_Value v) {
    char buffer[256];
    switch (v.type) {
        case VSS_VAL_NUMBER:
            // Format number cleanly
            snprintf(buffer, sizeof(buffer), "%g", v.as.number);
            return safe_strdup(buffer);
        case VSS_VAL_STRING:
            return safe_strdup(v.as.string->chars);
        case VSS_VAL_BOOL:
            return safe_strdup(v.as.boolean ? "yes" : "no");
        case VSS_VAL_EMPTY:
            return safe_strdup("empty");
        case VSS_VAL_LIST: {
            // Estimate size and build string
            size_t total_len = 3; // "[" + "]" + null
            for (size_t i = 0; i < v.as.list->count; i++) {
                char *s = vss_value_to_string(v.as.list->items[i]);
                total_len += strlen(s) + 2; // string + ", "
                free(s);
            }
            char *result = malloc(total_len);
            strcpy(result, "[");
            for (size_t i = 0; i < v.as.list->count; i++) {
                char *s = vss_value_to_string(v.as.list->items[i]);
                strcat(result, s);
                free(s);
                if (i < v.as.list->count - 1) {
                    strcat(result, ", ");
                }
            }
            strcat(result, "]");
            return result;
        }
        case VSS_VAL_MAP: {
            size_t total_len = 8; // "map [ " + "]" + null
            for (size_t i = 0; i < v.as.map->count; i++) {
                char *val_str = vss_value_to_string(v.as.map->entries[i].value);
                total_len += strlen(v.as.map->entries[i].key) + strlen(val_str) + 6; // '"' + key + '": ' + val_str + ' '
                free(val_str);
            }
            char *result = malloc(total_len);
            strcpy(result, "map [ ");
            for (size_t i = 0; i < v.as.map->count; i++) {
                strcat(result, "\"");
                strcat(result, v.as.map->entries[i].key);
                strcat(result, "\": ");
                char *val_str = vss_value_to_string(v.as.map->entries[i].value);
                strcat(result, val_str);
                free(val_str);
                strcat(result, " ");
            }
            strcat(result, "]");
            return result;
        }
        case VSS_VAL_TASK:
            return safe_strdup("<task>");
        case VSS_VAL_NATIVE:
            return safe_strdup("<native task>");
        case VSS_VAL_CLOSURE:
            return safe_strdup("<task>");
        case VSS_VAL_FUNCTION:
            return safe_strdup("<task>");
        case VSS_VAL_CLASS: {
            char buf[128];
            snprintf(buf, sizeof(buf), "<class %s>", v.as.klass->name);
            return safe_strdup(buf);
        }
        case VSS_VAL_INSTANCE: {
            char buf[128];
            snprintf(buf, sizeof(buf), "<instance %s>", v.as.instance->klass->name);
            return safe_strdup(buf);
        }
        case VSS_VAL_ENUM: {
            char buf[128];
            snprintf(buf, sizeof(buf), "<enum %s>", v.as.enm->name);
            return safe_strdup(buf);
        }
        case VSS_VAL_ENUM_VAL: {
            char buf[128];
            snprintf(buf, sizeof(buf), "%s.%s", v.as.enm_val->enum_name, v.as.enm_val->member_name);
            return safe_strdup(buf);
        }
        case VSS_VAL_TASK_HANDLE: {
            char buf[128];
            snprintf(buf, sizeof(buf), "<task handle #%d>", v.as.task_handle->id);
            return safe_strdup(buf);
        }
        case VSS_VAL_CHANNEL:
            return safe_strdup("<channel>");
        case VSS_VAL_MUTEX:
            return safe_strdup("<mutex>");
        case VSS_VAL_ATOMIC: {
            char buf[128];
            snprintf(buf, sizeof(buf), "<atomic %d>", vss_atomic_get(&v.as.atomic->val));
            return safe_strdup(buf);
        }
    }
    return safe_strdup("<unknown>");
}

void vss_value_say(VSS_Value v) {
    if (v.type == VSS_VAL_STRING) {
        const char *p = v.as.string->chars;
        while (*p) {
            if (*p != '\r') {
                putchar(*p);
            }
            p++;
        }
        putchar('\n');
    } else {
        char *s = vss_value_to_string(v);
        const char *p = s;
        while (*p) {
            if (*p != '\r') {
                putchar(*p);
            }
            p++;
        }
        putchar('\n');
        free(s);
    }
}
