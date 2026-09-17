#ifndef VSS_INTERPRETER_H
#define VSS_INTERPRETER_H

#include "ast.h"
#include "env.h"
#include "value.h"

typedef enum {
    VSS_FLOW_NORMAL,
    VSS_FLOW_SEND,
    VSS_FLOW_LEAVE,
    VSS_FLOW_SKIP,
    VSS_FLOW_ERROR
} VSS_FlowType;

typedef struct {
    VSS_FlowType type;
    VSS_Value value;     // For VSS_FLOW_SEND
    char *error_msg; // For VSS_FLOW_ERROR
    int line;
    int column;
} VSS_FlowResult;

VSS_FlowResult vss_interpret(VSS_Block block, VSS_Env *env);
void vss_register_builtins(VSS_Env *env);

#endif
