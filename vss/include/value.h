#ifndef VSS_VALUE_H
#define VSS_VALUE_H

#include "common.h"
#include "platform.h"

typedef enum {
    VSS_VAL_NUMBER,
    VSS_VAL_STRING,
    VSS_VAL_BOOL,
    VSS_VAL_EMPTY,
    VSS_VAL_LIST,
    VSS_VAL_MAP,
    VSS_VAL_TASK,
    VSS_VAL_NATIVE,
    VSS_VAL_CLOSURE,
    VSS_VAL_FUNCTION,
    VSS_VAL_CLASS,
    VSS_VAL_INSTANCE,
    VSS_VAL_ENUM,
    VSS_VAL_ENUM_VAL,
    VSS_VAL_TASK_HANDLE,
    VSS_VAL_CHANNEL,
    VSS_VAL_MUTEX,
    VSS_VAL_ATOMIC
} VSS_ValueType;

typedef struct VSS_ValString VSS_ValString;
typedef struct VSS_ValList VSS_ValList;
typedef struct VSS_ValMap VSS_ValMap;
typedef struct VSS_ValTask VSS_ValTask;
typedef struct VSS_ObjClosure VSS_ObjClosure;
typedef struct VSS_ObjFunction VSS_ObjFunction;
typedef struct VSS_ObjClass VSS_ObjClass;
typedef struct VSS_ObjInstance VSS_ObjInstance;
typedef struct VSS_ObjEnum VSS_ObjEnum;
typedef struct VSS_ObjEnumVal VSS_ObjEnumVal;
typedef struct VSS_TaskHandle VSS_TaskHandle;
typedef struct VSS_Channel VSS_Channel;
typedef struct VSS_MutexVal VSS_MutexVal;
typedef struct VSS_AtomicVal VSS_AtomicVal;
struct VSS_Stmt;
struct VSS_Env;

typedef struct VSS_Value (*VSS_NativeFnPtr)(size_t arg_count, struct VSS_Value *args, bool *out_error, char **out_error_msg);

typedef struct VSS_Value {
    VSS_ValueType type;
    union {
        double number;
        bool boolean;
        VSS_ValString *string;
        VSS_ValList *list;
        VSS_ValMap *map;
        VSS_ValTask *task;
        VSS_NativeFnPtr native;
        VSS_ObjClosure *closure;
        VSS_ObjFunction *function;
        VSS_ObjClass *klass;
        VSS_ObjInstance *instance;
        VSS_ObjEnum *enm;
        VSS_ObjEnumVal *enm_val;
        VSS_TaskHandle *task_handle;
        VSS_Channel *channel;
        VSS_MutexVal *mutex;
        VSS_AtomicVal *atomic;
    } as;
} VSS_Value;

struct VSS_ValString {
    VSS_AtomicInt ref_count;
    char *chars;
};

struct VSS_ValList {
    VSS_AtomicInt ref_count;
    VSS_Value *items;
    size_t count;
    size_t capacity;
};

typedef struct {
    char *key;
    VSS_Value value;
} VSS_ValMapEntry;

struct VSS_ValMap {
    VSS_AtomicInt ref_count;
    VSS_ValMapEntry *entries;
    size_t count;
    size_t capacity;
};

struct VSS_ValTask {
    VSS_AtomicInt ref_count;
    char **params;
    size_t param_count;
    struct VSS_Stmt **body;
    size_t body_count;
    struct VSS_Env *closure;
};

struct VSS_ObjClass {
    VSS_AtomicInt ref_count;
    char *name;
    struct VSS_ObjClass *parent;
    VSS_ValMap *methods;
};

struct VSS_ObjInstance {
    VSS_AtomicInt ref_count;
    VSS_ObjClass *klass;
    VSS_ValMap *fields;
};

struct VSS_ObjEnum {
    VSS_AtomicInt ref_count;
    char *name;
    VSS_ValMap *members;
};

struct VSS_ObjEnumVal {
    VSS_AtomicInt ref_count;
    char *enum_name;
    char *member_name;
    int value;
};

// Constructors
VSS_Value vss_value_new_number(double n);
VSS_Value vss_value_new_string(const char *s);
VSS_Value vss_value_new_bool(bool b);
VSS_Value vss_value_new_empty(void);
VSS_Value vss_value_new_list(void);
VSS_Value vss_value_new_map(void);
VSS_Value vss_value_new_task(char **params, size_t param_count, struct VSS_Stmt **body, size_t body_count, struct VSS_Env *closure);
VSS_Value vss_value_new_native(VSS_NativeFnPtr func);
VSS_Value vss_value_new_closure(VSS_ObjClosure *closure);
VSS_Value vss_value_new_function(VSS_ObjFunction *func);
VSS_Value vss_value_new_class(const char *name, VSS_ObjClass *parent);
VSS_Value vss_value_new_instance(VSS_ObjClass *klass);
VSS_Value vss_value_new_enum(const char *name);
VSS_Value vss_value_new_enum_val(const char *enum_name, const char *member_name, int value);
VSS_Value vss_value_new_task_handle(VSS_TaskHandle *handle);
VSS_Value vss_value_new_channel(VSS_Channel *channel);
VSS_Value vss_value_new_mutex(VSS_MutexVal *mutex);
VSS_Value vss_value_new_atomic(VSS_AtomicVal *atomic);

// Reference counting
void vss_value_retain(VSS_Value v);
void vss_value_release(VSS_Value v);

// Utility functions
bool vss_value_same_as(VSS_Value a, VSS_Value b);
bool vss_value_truthy(VSS_Value v);
void vss_value_say(VSS_Value v);
char *vss_value_to_string(VSS_Value v);

#endif
