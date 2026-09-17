#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "interpreter.h"
#include "parser.h"

// Helper to duplicate string safely
static char *safe_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) {
        strcpy(dup, s);
    }
    return dup;
}

static VSS_FlowResult flow_normal(void) {
    VSS_FlowResult res;
    res.type = VSS_FLOW_NORMAL;
    res.value = vss_value_new_empty();
    res.error_msg = NULL;
    res.line = 0;
    res.column = 0;
    return res;
}

static VSS_FlowResult flow_error(int line, int col, const char *format, ...) {
    VSS_FlowResult res;
    res.type = VSS_FLOW_ERROR;
    res.value = vss_value_new_empty();
    res.line = line;
    res.column = col;

    va_list args;
    va_start(args, format);
    // Determine size
    int len = vsnprintf(NULL, 0, format, args);
    va_end(args);

    res.error_msg = malloc(len + 1);
    va_start(args, format);
    vsnprintf(res.error_msg, len + 1, format, args);
    va_end(args);

    return res;
}

// Forward declarations of evaluation helpers
static VSS_FlowResult eval_expr(VSS_Expr *expr, VSS_Env *env, VSS_Value *out_val);

// Built-in Native Functions are registered from builtins.c


// Expression evaluation
static VSS_FlowResult eval_expr(VSS_Expr *expr, VSS_Env *env, VSS_Value *out_val) {
    if (!expr) {
        *out_val = vss_value_new_empty();
        return flow_normal();
    }

    switch (expr->kind) {
        case VSS_EXPR_NUMBER:
            *out_val = vss_value_new_number(expr->as.number);
            return flow_normal();
        case VSS_EXPR_STRING:
            *out_val = vss_value_new_string(expr->as.string);
            return flow_normal();
        case VSS_EXPR_BOOL:
            *out_val = vss_value_new_bool(expr->as.boolean);
            return flow_normal();
        case VSS_EXPR_EMPTY:
            *out_val = vss_value_new_empty();
            return flow_normal();
        case VSS_EXPR_NAME: {
            if (!vss_env_get(env, expr->as.name, out_val)) {
                return flow_error(expr->line, expr->column, "Undefined variable '%s'.", expr->as.name);
            }
            return flow_normal();
        }
        case VSS_EXPR_UNARY: {
            VSS_Value operand;
            VSS_FlowResult res = eval_expr(expr->as.unary.operand, env, &operand);
            if (res.type != VSS_FLOW_NORMAL) return res;

            if (expr->as.unary.op == VSS_TOKEN_MINUS) {
                if (operand.type != VSS_VAL_NUMBER) {
                    vss_value_release(operand);
                    return flow_error(expr->line, expr->column, "Operand to '-' must be a number.");
                }
                *out_val = vss_value_new_number(-operand.as.number);
                vss_value_release(operand);
                return flow_normal();
            } else if (expr->as.unary.op == VSS_TOKEN_NOT) {
                *out_val = vss_value_new_bool(!vss_value_truthy(operand));
                vss_value_release(operand);
                return flow_normal();
            }
            vss_value_release(operand);
            return flow_error(expr->line, expr->column, "Unknown unary operator.");
        }
        case VSS_EXPR_BINARY: {
            // Short-circuit logical operators
            if (expr->as.binary.op == VSS_TOKEN_OR) {
                VSS_Value left;
                VSS_FlowResult res = eval_expr(expr->as.binary.left, env, &left);
                if (res.type != VSS_FLOW_NORMAL) return res;
                if (vss_value_truthy(left)) {
                    *out_val = left;
                    return flow_normal();
                }
                vss_value_release(left);
                return eval_expr(expr->as.binary.right, env, out_val);
            }
            if (expr->as.binary.op == VSS_TOKEN_AND) {
                VSS_Value left;
                VSS_FlowResult res = eval_expr(expr->as.binary.left, env, &left);
                if (res.type != VSS_FLOW_NORMAL) return res;
                if (!vss_value_truthy(left)) {
                    *out_val = left;
                    return flow_normal();
                }
                vss_value_release(left);
                return eval_expr(expr->as.binary.right, env, out_val);
            }

            VSS_Value left, right;
            VSS_FlowResult res = eval_expr(expr->as.binary.left, env, &left);
            if (res.type != VSS_FLOW_NORMAL) return res;
            res = eval_expr(expr->as.binary.right, env, &right);
            if (res.type != VSS_FLOW_NORMAL) {
                vss_value_release(left);
                return res;
            }

            VSS_TokenType op = expr->as.binary.op;
            if (op == VSS_TOKEN_PLUS) {
                if (left.type == VSS_VAL_NUMBER && right.type == VSS_VAL_NUMBER) {
                    *out_val = vss_value_new_number(left.as.number + right.as.number);
                    vss_value_release(left); vss_value_release(right);
                    return flow_normal();
                } else if (left.type == VSS_VAL_STRING && right.type == VSS_VAL_STRING) {
                    char *joined = malloc(strlen(left.as.string->chars) + strlen(right.as.string->chars) + 1);
                    strcpy(joined, left.as.string->chars);
                    strcat(joined, right.as.string->chars);
                    *out_val = vss_value_new_string(joined);
                    free(joined);
                    vss_value_release(left); vss_value_release(right);
                    return flow_normal();
                } else {
                    vss_value_release(left); vss_value_release(right);
                    return flow_error(expr->line, expr->column, "Can only add numbers or join strings.");
                }
            }

            // Other arithmetic operators
            if (op == VSS_TOKEN_MINUS || op == VSS_TOKEN_STAR || op == VSS_TOKEN_SLASH || op == VSS_TOKEN_PERCENT) {
                if (left.type != VSS_VAL_NUMBER || right.type != VSS_VAL_NUMBER) {
                    vss_value_release(left); vss_value_release(right);
                    return flow_error(expr->line, expr->column, "Arithmetic operands must be numbers.");
                }
                double l = left.as.number;
                double r = right.as.number;
                vss_value_release(left); vss_value_release(right);

                if (op == VSS_TOKEN_MINUS) *out_val = vss_value_new_number(l - r);
                else if (op == VSS_TOKEN_STAR) *out_val = vss_value_new_number(l * r);
                else if (op == VSS_TOKEN_SLASH) {
                    if (r == 0.0) return flow_error(expr->line, expr->column, "Division by zero.");
                    *out_val = vss_value_new_number(l / r);
                } else {
                    if (r == 0.0) return flow_error(expr->line, expr->column, "Modulo by zero.");
                    // Standard C Modulo on doubles using fmod? Let's just cast to long long, or use standard double mod.
                    // Casting to long is standard for small % operators.
                    *out_val = vss_value_new_number((long long)l % (long long)r);
                }
                return flow_normal();
            }

            // Numeric comparisons
            if (op == VSS_TOKEN_ABOVE || op == VSS_TOKEN_BELOW || op == VSS_TOKEN_AT_LEAST || op == VSS_TOKEN_AT_MOST) {
                if (left.type != VSS_VAL_NUMBER || right.type != VSS_VAL_NUMBER) {
                    vss_value_release(left); vss_value_release(right);
                    return flow_error(expr->line, expr->column, "Comparison operands must be numbers.");
                }
                double l = left.as.number;
                double r = right.as.number;
                vss_value_release(left); vss_value_release(right);

                if (op == VSS_TOKEN_ABOVE) *out_val = vss_value_new_bool(l > r);
                else if (op == VSS_TOKEN_BELOW) *out_val = vss_value_new_bool(l < r);
                else if (op == VSS_TOKEN_AT_LEAST) *out_val = vss_value_new_bool(l >= r);
                else *out_val = vss_value_new_bool(l <= r);
                return flow_normal();
            }

            // Equality comparisons
            if (op == VSS_TOKEN_SAME_AS || op == VSS_TOKEN_NOT_SAME_AS) {
                bool same = vss_value_same_as(left, right);
                *out_val = vss_value_new_bool(op == VSS_TOKEN_SAME_AS ? same : !same);
                vss_value_release(left); vss_value_release(right);
                return flow_normal();
            }

            vss_value_release(left); vss_value_release(right);
            return flow_error(expr->line, expr->column, "Unknown binary operator.");
        }
        case VSS_EXPR_LIST: {
            VSS_Value list_val = vss_value_new_list();
            for (size_t i = 0; i < expr->as.list.count; i++) {
                VSS_Value elem;
                VSS_FlowResult res = eval_expr(expr->as.list.elements[i], env, &elem);
                if (res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(list_val);
                    return res;
                }
                // Append elem to list_val
                VSS_ValList *l = list_val.as.list;
                if (l->count >= l->capacity) {
                    l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
                    l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
                }
                l->items[l->count++] = elem; // Holds reference
            }
            *out_val = list_val;
            return flow_normal();
        }
        case VSS_EXPR_SET: {
            VSS_Value list_val = vss_value_new_list();
            VSS_ValList *l = list_val.as.list;
            for (size_t i = 0; i < expr->as.list.count; i++) {
                VSS_Value elem;
                VSS_FlowResult res = eval_expr(expr->as.list.elements[i], env, &elem);
                if (res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(list_val);
                    return res;
                }
                bool exists = false;
                for (size_t k = 0; k < l->count; k++) {
                    if (vss_value_same_as(l->items[k], elem)) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    if (l->count >= l->capacity) {
                        l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
                        l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
                    }
                    l->items[l->count++] = elem;
                } else {
                    vss_value_release(elem);
                }
            }
            *out_val = list_val;
            return flow_normal();
        }
        case VSS_EXPR_MAP: {
            VSS_Value map_val = vss_value_new_map();
            for (size_t i = 0; i < expr->as.map.count; i++) {
                VSS_Value entry_val;
                VSS_FlowResult res = eval_expr(expr->as.map.values[i], env, &entry_val);
                if (res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(map_val);
                    return res;
                }
                VSS_ValMap *m = map_val.as.map;
                if (m->count >= m->capacity) {
                    m->capacity = m->capacity == 0 ? 8 : m->capacity * 2;
                    m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * m->capacity);
                }
                m->entries[m->count].key = safe_strdup(expr->as.map.keys[i]);
                m->entries[m->count].value = entry_val;
                m->count++;
            }
            *out_val = map_val;
            return flow_normal();
        }
        case VSS_EXPR_ITEM_ACCESS: {
            VSS_Value col;
            VSS_FlowResult res = eval_expr(expr->as.item_access.list, env, &col);
            if (res.type != VSS_FLOW_NORMAL) return res;
            if (col.type != VSS_VAL_LIST) {
                vss_value_release(col);
                return flow_error(expr->line, expr->column, "Item access expects list.");
            }
            VSS_Value idx;
            res = eval_expr(expr->as.item_access.index, env, &idx);
            if (res.type != VSS_FLOW_NORMAL) {
                vss_value_release(col);
                return res;
            }
            if (idx.type != VSS_VAL_NUMBER) {
                vss_value_release(col); vss_value_release(idx);
                return flow_error(expr->line, expr->column, "List index must be a number.");
            }
            long long index = (long long)idx.as.number;
            vss_value_release(idx);

            VSS_ValList *l = col.as.list;
            if (index < 0 || (size_t)index >= l->count) {
                vss_value_release(col);
                return flow_error(expr->line, expr->column, "List index out of range: got %lld but size is %zu.", index, l->count);
            }
            *out_val = l->items[index];
            vss_value_retain(*out_val);
            vss_value_release(col);
            return flow_normal();
        }
        case VSS_EXPR_FIELD_ACCESS: {
            VSS_Value col;
            VSS_FlowResult res = eval_expr(expr->as.field_access.map, env, &col);
            if (res.type != VSS_FLOW_NORMAL) return res;
            if (col.type != VSS_VAL_MAP) {
                vss_value_release(col);
                return flow_error(expr->line, expr->column, "Field access expects a map.");
            }
            VSS_Value field_val;
            res = eval_expr(expr->as.field_access.field, env, &field_val);
            if (res.type != VSS_FLOW_NORMAL) {
                vss_value_release(col);
                return res;
            }
            if (field_val.type != VSS_VAL_STRING) {
                vss_value_release(col); vss_value_release(field_val);
                return flow_error(expr->line, expr->column, "Map field key must be a string.");
            }
            const char *key = field_val.as.string->chars;

            VSS_ValMap *m = col.as.map;
            bool found = false;
            for (size_t i = 0; i < m->count; i++) {
                if (strcmp(m->entries[i].key, key) == 0) {
                    *out_val = m->entries[i].value;
                    vss_value_retain(*out_val);
                    found = true;
                    break;
                }
            }
            vss_value_release(field_val);
            vss_value_release(col);

            if (!found) {
                return flow_error(expr->line, expr->column, "Map key '%s' not found.", key);
            }
            return flow_normal();
        }
        case VSS_EXPR_CALL: {
            VSS_Value callee;
            VSS_FlowResult res = eval_expr(expr->as.call.callee, env, &callee);
            if (res.type != VSS_FLOW_NORMAL) return res;

            if (callee.type != VSS_VAL_TASK && callee.type != VSS_VAL_NATIVE) {
                vss_value_release(callee);
                return flow_error(expr->line, expr->column, "VSS_Value is not callable.");
            }

            // Evaluate arguments
            VSS_Value *args = malloc(sizeof(VSS_Value) * expr->as.call.count);
            for (size_t i = 0; i < expr->as.call.count; i++) {
                res = eval_expr(expr->as.call.args[i], env, &args[i]);
                if (res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(callee);
                    for (size_t j = 0; j < i; j++) vss_value_release(args[j]);
                    free(args);
                    return res;
                }
            }

            if (callee.type == VSS_VAL_TASK) {
                VSS_ValTask *task = callee.as.task;
                if (expr->as.call.count != task->param_count) {
                    vss_value_release(callee);
                    for (size_t i = 0; i < expr->as.call.count; i++) vss_value_release(args[i]);
                    free(args);
                    return flow_error(expr->line, expr->column, "Expected %zu arguments but got %zu.", task->param_count, expr->as.call.count);
                }

                // Create environment for call using closure environment
                VSS_Env *call_env = vss_env_new(task->closure);
                for (size_t i = 0; i < task->param_count; i++) {
                    vss_env_define(call_env, task->params[i], args[i]);
                }

                VSS_Block body;
                body.statements = task->body;
                body.count = task->body_count;

                VSS_FlowResult call_res = vss_interpret(body, call_env);
                vss_env_release(call_env);

                // Release args (they were retained during eval, and call_env also retained them. But call_env is released now).
                for (size_t i = 0; i < expr->as.call.count; i++) vss_value_release(args[i]);
                free(args);
                vss_value_release(callee);

                if (call_res.type == VSS_FLOW_SEND) {
                    *out_val = call_res.value; // It is already retained in send statement
                    // Convert VSS_FLOW_SEND to VSS_FLOW_NORMAL for expression result
                    call_res.type = VSS_FLOW_NORMAL;
                    call_res.value = vss_value_new_empty(); // Clear so it isn't released twice
                    return call_res;
                }

                if (call_res.type == VSS_FLOW_LEAVE || call_res.type == VSS_FLOW_SKIP) {
                    VSS_FlowResult err = flow_error(call_res.line, call_res.column, "leave or skip outside loop.");
                    return err;
                }

                if (call_res.type == VSS_FLOW_ERROR) {
                    return call_res;
                }

                *out_val = vss_value_new_empty();
                return flow_normal();
            } else {
                // Native task
                bool err = false;
                char *err_msg = NULL;
                VSS_Value ret_val = callee.as.native(expr->as.call.count, args, &err, &err_msg);

                // Release args
                for (size_t i = 0; i < expr->as.call.count; i++) vss_value_release(args[i]);
                free(args);
                vss_value_release(callee);

                if (err) {
                    VSS_FlowResult flow_err = flow_error(expr->line, expr->column, "%s", err_msg);
                    free(err_msg);
                    return flow_err;
                }
                *out_val = ret_val;
                return flow_normal();
            }
        }
        case VSS_EXPR_MINE: {
            VSS_Value val;
            if (!vss_env_get(env, "mine", &val)) {
                return flow_error(expr->line, expr->column, "Undefined variable 'mine'.");
            }
            vss_value_retain(val);
            *out_val = val;
            return flow_normal();
        }
        case VSS_EXPR_PARENT: {
            VSS_Value val;
            if (!vss_env_get(env, "mine", &val)) {
                return flow_error(expr->line, expr->column, "Undefined variable 'parent'.");
            }
            vss_value_retain(val);
            *out_val = val;
            return flow_normal();
        }
        case VSS_EXPR_STRUCT_LITERAL:
        case VSS_EXPR_CLOSURE:
            return flow_error(expr->line, expr->column, "Not implemented in tree-walk interpreter.");
    }

    return flow_error(expr->line, expr->column, "Unknown expression kind.");
}

// Statement execution
static VSS_FlowResult exec_stmt(VSS_Stmt *stmt, VSS_Env *env) {
    if (!stmt) return flow_normal();

    switch (stmt->kind) {
        case VSS_STMT_MAKE: {
            VSS_Value val;
            VSS_FlowResult res = eval_expr(stmt->as.make.initializer, env, &val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            if (!vss_env_define(env, stmt->as.make.name, val)) {
                vss_value_release(val);
                return flow_error(stmt->line, stmt->column, "Variable '%s' is already defined in this scope.", stmt->as.make.name);
            }
            vss_value_release(val);
            return flow_normal();
        }
        case VSS_STMT_KEEP: {
            VSS_Value val;
            VSS_FlowResult res = eval_expr(stmt->as.keep.initializer, env, &val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            if (!vss_env_define_const(env, stmt->as.keep.name, val)) {
                vss_value_release(val);
                return flow_error(stmt->line, stmt->column, "Constant '%s' is already defined in this scope.", stmt->as.keep.name);
            }
            vss_value_release(val);
            return flow_normal();
        }
        case VSS_STMT_ASSIGN: {
            VSS_Value val;
            VSS_FlowResult res = eval_expr(stmt->as.assign.value, env, &val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            if (!vss_env_assign(env, stmt->as.assign.name, val)) {
                vss_value_release(val);
                return flow_error(stmt->line, stmt->column, "Cannot reassign to '%s' (either constant or undefined variable).", stmt->as.assign.name);
            }
            vss_value_release(val);
            return flow_normal();
        }
        case VSS_STMT_SAY: {
            VSS_Value val;
            VSS_FlowResult res = eval_expr(stmt->as.say.expression, env, &val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            vss_value_say(val);
            vss_value_release(val);
            return flow_normal();
        }
        case VSS_STMT_ASK: {
            VSS_Value prompt_val = vss_value_new_empty();
            if (stmt->as.ask.prompt) {
                VSS_FlowResult res = eval_expr(stmt->as.ask.prompt, env, &prompt_val);
                if (res.type != VSS_FLOW_NORMAL) return res;
            }
            if (prompt_val.type != VSS_VAL_EMPTY) {
                char *prompt_str = vss_value_to_string(prompt_val);
                printf("%s", prompt_str);
                free(prompt_str);
                fflush(stdout);
            }
            char input_buf[1024];
            if (!fgets(input_buf, sizeof(input_buf), stdin)) {
                vss_value_release(prompt_val);
                return flow_error(stmt->line, stmt->column, "Input Error: End of file or stdin failure.");
            }
            size_t len = strlen(input_buf);
            while (len > 0 && (input_buf[len - 1] == '\n' || input_buf[len - 1] == '\r')) {
                input_buf[len - 1] = '\0';
                len--;
            }
            char *start = input_buf;
            while (*start == ' ' || *start == '\t') start++;
            char *end = start + strlen(start);
            while (end > start && (end[-1] == ' ' || end[-1] == '\t')) end--;
            *end = '\0';

            VSS_Expr *target = stmt->as.ask.target;
            VSS_Value curr_val = vss_value_new_empty();
            
            if (target->kind == VSS_EXPR_NAME) {
                if (!vss_env_get(env, target->as.name, &curr_val)) {
                    vss_value_release(prompt_val);
                    return flow_error(stmt->line, stmt->column, "Undefined variable '%s'.", target->as.name);
                }
                vss_value_retain(curr_val);
            } else if (target->kind == VSS_EXPR_FIELD_ACCESS) {
                VSS_FlowResult res = eval_expr(target, env, &curr_val);
                if (res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(prompt_val);
                    return res;
                }
            }

            VSS_Value new_val;
            if (curr_val.type == VSS_VAL_NUMBER) {
                if (*start == '\0') {
                    vss_value_release(curr_val);
                    vss_value_release(prompt_val);
                    return flow_error(stmt->line, stmt->column, "Input Error: Expected a number but received empty input.");
                }
                char *endptr;
                double val = strtod(start, &endptr);
                if (*endptr != '\0') {
                    vss_value_release(curr_val);
                    vss_value_release(prompt_val);
                    return flow_error(stmt->line, stmt->column, "Input Error: Expected a number but received \"%s\".", start);
                }
                new_val = vss_value_new_number(val);
            } else if (curr_val.type == VSS_VAL_BOOL) {
                if (*start == '\0') {
                    vss_value_release(curr_val);
                    vss_value_release(prompt_val);
                    return flow_error(stmt->line, stmt->column, "Input Error: Expected a boolean but received empty input.");
                }
                bool b_val = false;
                bool parsed = false;
                char lower_start[16];
                size_t slen = strlen(start);
                if (slen < 16) {
                    for (size_t i = 0; i < slen; i++) {
                        char c = start[i];
                        if (c >= 'A' && c <= 'Z') c += 32;
                        lower_start[i] = c;
                    }
                    lower_start[slen] = '\0';
                    if (strcmp(lower_start, "yes") == 0 || strcmp(lower_start, "true") == 0 || strcmp(lower_start, "1") == 0) {
                        b_val = true;
                        parsed = true;
                    } else if (strcmp(lower_start, "no") == 0 || strcmp(lower_start, "false") == 0 || strcmp(lower_start, "0") == 0) {
                        b_val = false;
                        parsed = true;
                    }
                }
                if (!parsed) {
                    vss_value_release(curr_val);
                    vss_value_release(prompt_val);
                    return flow_error(stmt->line, stmt->column, "Input Error: Expected a boolean but received \"%s\".", start);
                }
                new_val = vss_value_new_bool(b_val);
            } else {
                new_val = vss_value_new_string(input_buf);
            }

            vss_value_release(curr_val);
            vss_value_release(prompt_val);

            if (target->kind == VSS_EXPR_NAME) {
                if (!vss_env_assign(env, target->as.name, new_val)) {
                    vss_value_release(new_val);
                    return flow_error(stmt->line, stmt->column, "Cannot assign to '%s'.", target->as.name);
                }
                vss_value_release(new_val);
            } else if (target->kind == VSS_EXPR_FIELD_ACCESS) {
                VSS_Value col, field_val;
                VSS_FlowResult res = eval_expr(target->as.field_access.map, env, &col);
                if (res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(new_val);
                    return res;
                }
                res = eval_expr(target->as.field_access.field, env, &field_val);
                if (res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(col);
                    vss_value_release(new_val);
                    return res;
                }
                if (col.type != VSS_VAL_MAP) {
                    vss_value_release(col); vss_value_release(field_val); vss_value_release(new_val);
                    return flow_error(stmt->line, stmt->column, "set statement expects a map.");
                }
                if (field_val.type != VSS_VAL_STRING) {
                    vss_value_release(col); vss_value_release(field_val); vss_value_release(new_val);
                    return flow_error(stmt->line, stmt->column, "map field key must be a string.");
                }
                VSS_ValMap *m = col.as.map;
                const char *key = field_val.as.string->chars;
                bool found = false;
                for (size_t i = 0; i < m->count; i++) {
                    if (strcmp(m->entries[i].key, key) == 0) {
                        vss_value_release(m->entries[i].value);
                        m->entries[i].value = new_val;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    if (m->count >= m->capacity) {
                        m->capacity = m->capacity == 0 ? 8 : m->capacity * 2;
                        m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * m->capacity);
                    }
                    m->entries[m->count].key = safe_strdup(key);
                    m->entries[m->count].value = new_val;
                    m->count++;
                }
                vss_value_release(col); vss_value_release(field_val);
            }
            return flow_normal();
        }
        case VSS_STMT_SEND: {
            VSS_Value val;
            VSS_FlowResult res = eval_expr(stmt->as.send.expression, env, &val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            VSS_FlowResult send_res;
            send_res.type = VSS_FLOW_SEND;
            send_res.value = val; // ownership transferred to send result
            send_res.error_msg = NULL;
            send_res.line = stmt->line;
            send_res.column = stmt->column;
            return send_res;
        }
        case VSS_STMT_LEAVE: {
            VSS_FlowResult leave_res;
            leave_res.type = VSS_FLOW_LEAVE;
            leave_res.value = vss_value_new_empty();
            leave_res.error_msg = NULL;
            leave_res.line = stmt->line;
            leave_res.column = stmt->column;
            return leave_res;
        }
        case VSS_STMT_SKIP: {
            VSS_FlowResult skip_res;
            skip_res.type = VSS_FLOW_SKIP;
            skip_res.value = vss_value_new_empty();
            skip_res.error_msg = NULL;
            skip_res.line = stmt->line;
            skip_res.column = stmt->column;
            return skip_res;
        }
        case VSS_STMT_TASK: {
            // Define task
            VSS_Value task_val = vss_value_new_task(
                stmt->as.task.params, stmt->as.task.param_count,
                stmt->as.task.body.statements, stmt->as.task.body.count,
                env
            );
            if (!vss_env_define(env, stmt->as.task.name, task_val)) {
                vss_value_release(task_val);
                return flow_error(stmt->line, stmt->column, "Task '%s' redefines existing name in this scope.", stmt->as.task.name);
            }
            vss_value_release(task_val);
            return flow_normal();
        }
        case VSS_STMT_WHEN: {
            for (size_t i = 0; i < stmt->as.when.branch_count; i++) {
                VSS_Value cond;
                VSS_FlowResult res = eval_expr(stmt->as.when.branches[i].condition, env, &cond);
                if (res.type != VSS_FLOW_NORMAL) return res;
                bool is_true = vss_value_truthy(cond);
                vss_value_release(cond);

                if (is_true) {
                    VSS_Env *branch_env = vss_env_new(env);
                    VSS_FlowResult branch_res = vss_interpret(stmt->as.when.branches[i].block, branch_env);
                    vss_env_release(branch_env);
                    return branch_res;
                }
            }

            if (stmt->as.when.otherwise_branch.count > 0) {
                VSS_Env *branch_env = vss_env_new(env);
                VSS_FlowResult branch_res = vss_interpret(stmt->as.when.otherwise_branch, branch_env);
                vss_env_release(branch_env);
                return branch_res;
            }

            return flow_normal();
        }
        case VSS_STMT_REPEAT_COUNT: {
            VSS_Value count_val;
            VSS_FlowResult res = eval_expr(stmt->as.repeat_count.count_expr, env, &count_val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            if (count_val.type != VSS_VAL_NUMBER) {
                vss_value_release(count_val);
                return flow_error(stmt->line, stmt->column, "Repeat count must be a number.");
            }
            double c = count_val.as.number;
            vss_value_release(count_val);

            for (double i = 0; i < c; i++) {
                VSS_Env *loop_env = vss_env_new(env);
                VSS_FlowResult loop_res = vss_interpret(stmt->as.repeat_count.body, loop_env);
                vss_env_release(loop_env);

                if (loop_res.type == VSS_FLOW_LEAVE) break;
                if (loop_res.type == VSS_FLOW_SKIP) continue;
                if (loop_res.type != VSS_FLOW_NORMAL) return loop_res;
            }
            return flow_normal();
        }
        case VSS_STMT_REPEAT_RANGE: {
            VSS_Value start_val, end_val;
            VSS_FlowResult res = eval_expr(stmt->as.repeat_range.start, env, &start_val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            res = eval_expr(stmt->as.repeat_range.end, env, &end_val);
            if (res.type != VSS_FLOW_NORMAL) {
                vss_value_release(start_val);
                return res;
            }
            if (start_val.type != VSS_VAL_NUMBER || end_val.type != VSS_VAL_NUMBER) {
                vss_value_release(start_val); vss_value_release(end_val);
                return flow_error(stmt->line, stmt->column, "Range bounds must be numbers.");
            }
            double start = start_val.as.number;
            double end = end_val.as.number;
            vss_value_release(start_val); vss_value_release(end_val);

            if (start <= end) {
                for (double i = start; i <= end; i++) {
                    VSS_Env *loop_env = vss_env_new(env);
                    vss_env_define(loop_env, stmt->as.repeat_range.var_name, vss_value_new_number(i));
                    VSS_FlowResult loop_res = vss_interpret(stmt->as.repeat_range.body, loop_env);
                    vss_env_release(loop_env);

                    if (loop_res.type == VSS_FLOW_LEAVE) break;
                    if (loop_res.type == VSS_FLOW_SKIP) continue;
                    if (loop_res.type != VSS_FLOW_NORMAL) return loop_res;
                }
            } else {
                for (double i = start; i >= end; i--) {
                    VSS_Env *loop_env = vss_env_new(env);
                    vss_env_define(loop_env, stmt->as.repeat_range.var_name, vss_value_new_number(i));
                    VSS_FlowResult loop_res = vss_interpret(stmt->as.repeat_range.body, loop_env);
                    vss_env_release(loop_env);

                    if (loop_res.type == VSS_FLOW_LEAVE) break;
                    if (loop_res.type == VSS_FLOW_SKIP) continue;
                    if (loop_res.type != VSS_FLOW_NORMAL) return loop_res;
                }
            }
            return flow_normal();
        }
        case VSS_STMT_REPEAT_EACH: {
            VSS_Value col;
            VSS_FlowResult res = eval_expr(stmt->as.repeat_each.collection, env, &col);
            if (res.type != VSS_FLOW_NORMAL) return res;
            if (col.type != VSS_VAL_LIST) {
                vss_value_release(col);
                return flow_error(stmt->line, stmt->column, "repeat each expects list.");
            }
            VSS_ValList *l = col.as.list;
            for (size_t i = 0; i < l->count; i++) {
                VSS_Env *loop_env = vss_env_new(env);
                vss_env_define(loop_env, stmt->as.repeat_each.var_name, l->items[i]);
                VSS_FlowResult loop_res = vss_interpret(stmt->as.repeat_each.body, loop_env);
                vss_env_release(loop_env);

                if (loop_res.type == VSS_FLOW_LEAVE) break;
                if (loop_res.type == VSS_FLOW_SKIP) continue;
                if (loop_res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(col);
                    return loop_res;
                }
            }
            vss_value_release(col);
            return flow_normal();
        }
        case VSS_STMT_DURING: {
            for (;;) {
                VSS_Value cond;
                VSS_FlowResult res = eval_expr(stmt->as.during.condition, env, &cond);
                if (res.type != VSS_FLOW_NORMAL) return res;
                bool is_true = vss_value_truthy(cond);
                vss_value_release(cond);

                if (!is_true) break;

                VSS_Env *loop_env = vss_env_new(env);
                VSS_FlowResult loop_res = vss_interpret(stmt->as.during.body, loop_env);
                vss_env_release(loop_env);

                if (loop_res.type == VSS_FLOW_LEAVE) break;
                if (loop_res.type == VSS_FLOW_SKIP) continue;
                if (loop_res.type != VSS_FLOW_NORMAL) return loop_res;
            }
            return flow_normal();
        }
        case VSS_STMT_ATTEMPT: {
            VSS_Env *try_env = vss_env_new(env);
            VSS_FlowResult res = vss_interpret(stmt->as.attempt.try_body, try_env);
            vss_env_release(try_env);

            if (res.type == VSS_FLOW_ERROR) {
                VSS_Value err_str = vss_value_new_string(res.error_msg);
                free(res.error_msg); // Free old error message

                VSS_Env *rescue_env = vss_env_new(env);
                vss_env_define(rescue_env, stmt->as.attempt.problem_var, err_str);
                vss_value_release(err_str);

                VSS_FlowResult rescue_res = vss_interpret(stmt->as.attempt.rescue_body, rescue_env);
                vss_env_release(rescue_env);
                return rescue_res;
            }

            return res;
        }
        case VSS_STMT_CHOOSE: {
            VSS_Value val;
            VSS_FlowResult res = eval_expr(stmt->as.choose.expr, env, &val);
            if (res.type != VSS_FLOW_NORMAL) return res;

            bool matched = false;
            for (size_t i = 0; i < stmt->as.choose.case_count; i++) {
                VSS_Value cval;
                res = eval_expr(stmt->as.choose.cases[i].expr, env, &cval);
                if (res.type != VSS_FLOW_NORMAL) {
                    vss_value_release(val);
                    return res;
                }
                bool is_same = vss_value_same_as(val, cval);
                vss_value_release(cval);

                if (is_same) {
                    matched = true;
                    vss_value_release(val);
                    VSS_Env *case_env = vss_env_new(env);
                    VSS_FlowResult case_res = vss_interpret(stmt->as.choose.cases[i].block, case_env);
                    vss_env_release(case_env);
                    return case_res;
                }
            }

            vss_value_release(val);
            if (!matched && stmt->as.choose.otherwise_branch.count > 0) {
                VSS_Env *case_env = vss_env_new(env);
                VSS_FlowResult case_res = vss_interpret(stmt->as.choose.otherwise_branch, case_env);
                vss_env_release(case_env);
                return case_res;
            }
            return flow_normal();
        }
        case VSS_STMT_PUT: {
            VSS_Value val, col;
            VSS_FlowResult res = eval_expr(stmt->as.put.value, env, &val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            res = eval_expr(stmt->as.put.list, env, &col);
            if (res.type != VSS_FLOW_NORMAL) {
                vss_value_release(val);
                return res;
            }
            if (col.type != VSS_VAL_LIST) {
                vss_value_release(val); vss_value_release(col);
                return flow_error(stmt->line, stmt->column, "put statement expects a list.");
            }
            VSS_ValList *l = col.as.list;
            if (l->count >= l->capacity) {
                l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
                l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
            }
            l->items[l->count++] = val; // Transfers reference (already retained by eval_expr)
            vss_value_release(col);
            return flow_normal();
        }
        case VSS_STMT_SET_FIELD: {
            VSS_Value col, field_val, val;
            VSS_FlowResult res = eval_expr(stmt->as.set_field.map, env, &col);
            if (res.type != VSS_FLOW_NORMAL) return res;
            res = eval_expr(stmt->as.set_field.field, env, &field_val);
            if (res.type != VSS_FLOW_NORMAL) {
                vss_value_release(col);
                return res;
            }
            res = eval_expr(stmt->as.set_field.value, env, &val);
            if (res.type != VSS_FLOW_NORMAL) {
                vss_value_release(col); vss_value_release(field_val);
                return res;
            }
            if (col.type != VSS_VAL_MAP) {
                vss_value_release(col); vss_value_release(field_val); vss_value_release(val);
                return flow_error(stmt->line, stmt->column, "set statement expects a map.");
            }
            if (field_val.type != VSS_VAL_STRING) {
                vss_value_release(col); vss_value_release(field_val); vss_value_release(val);
                return flow_error(stmt->line, stmt->column, "map field key must be a string.");
            }

            VSS_ValMap *m = col.as.map;
            const char *key = field_val.as.string->chars;
            bool found = false;
            for (size_t i = 0; i < m->count; i++) {
                if (strcmp(m->entries[i].key, key) == 0) {
                    vss_value_release(m->entries[i].value);
                    m->entries[i].value = val; // transfers reference (already retained)
                    found = true;
                    break;
                }
            }

            if (!found) {
                if (m->count >= m->capacity) {
                    m->capacity = m->capacity == 0 ? 8 : m->capacity * 2;
                    m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * m->capacity);
                }
                m->entries[m->count].key = safe_strdup(key);
                m->entries[m->count].value = val; // transfers reference
                m->count++;
            }

            vss_value_release(col); vss_value_release(field_val);
            return flow_normal();
        }
        case VSS_STMT_HI_HTMVSS: {
            printf("<!DOCTYPE html>\n<html>\n<head>\n<script src=\"https://cdn.tailwindcss.com\"></script>\n</head>\n<body class=\"bg-slate-900 text-white font-sans flex flex-col items-center justify-center min-h-screen\">\n");
            return flow_normal();
        }
        case VSS_STMT_BYE_HTMVSS: {
            printf("</body>\n</html>\n");
            return flow_normal();
        }
        case VSS_STMT_EXPR: {
            VSS_Value val;
            VSS_FlowResult res = eval_expr(stmt->as.expr_stmt.expression, env, &val);
            if (res.type != VSS_FLOW_NORMAL) return res;
            vss_value_release(val);
            return flow_normal();
        }
        case VSS_STMT_GRAB: {
            // Module Import
            char filepath[256];
            snprintf(filepath, sizeof(filepath), "%s.vss", stmt->as.grab.module_name);
            FILE *f = fopen(filepath, "rb");
            if (!f) {
                snprintf(filepath, sizeof(filepath), "stdlib/%s.vss", stmt->as.grab.module_name);
                f = fopen(filepath, "rb");
            }
            if (!f) {
                snprintf(filepath, sizeof(filepath), "packages/%s.vss", stmt->as.grab.module_name);
                f = fopen(filepath, "rb");
            }
            if (!f) {
                snprintf(filepath, sizeof(filepath), "examples/%s.vss", stmt->as.grab.module_name);
                f = fopen(filepath, "rb");
            }
            if (!f) {
                return flow_error(stmt->line, stmt->column, "Grab module '%s' not found.", stmt->as.grab.module_name);
            }
            fclose(f);

            // Read the file content
            FILE *file = fopen(filepath, "rb");
            fseek(file, 0, SEEK_END);
            long size = ftell(file);
            rewind(file);
            char *source = malloc(size + 1);
            size_t read_bytes = fread(source, 1, size, file);
            fclose(file);
            source[read_bytes] = '\0';

            VSS_Lexer mod_lexer;
            vss_lexer_init(&mod_lexer, source);
            VSS_Parser mod_parser;
            vss_parser_init(&mod_parser, &mod_lexer);
            VSS_Block mod_ast = vss_parse_program(&mod_parser);
            free(source);

            if (mod_parser.had_error) {
                vss_block_free(mod_ast);
                return flow_error(stmt->line, stmt->column, "Syntax error in module '%s'.", stmt->as.grab.module_name);
            }

            VSS_Env *mod_env = vss_env_new(NULL);
            vss_register_builtins(mod_env);
            
            VSS_FlowResult mod_res = vss_interpret(mod_ast, mod_env);
            vss_block_free(mod_ast);

            if (mod_res.type == VSS_FLOW_ERROR) {
                vss_env_release(mod_env);
                return mod_res;
            }

            // Create the exports map
            VSS_Value exports = vss_value_new_map();
            VSS_ValMap *m = exports.as.map;
            for (size_t i = 0; i < mod_env->count; i++) {
                if (strncmp(mod_env->items[i].name, "__", 2) == 0) continue;
                m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * (m->count + 1));
                m->entries[m->count].key = safe_strdup(mod_env->items[i].name);
                m->entries[m->count].value = mod_env->items[i].value;
                vss_value_retain(mod_env->items[i].value);
                m->count++;
            }
            
            // Unwrap if single exported item has the module's name
            if (m->count == 1 && strcmp(m->entries[0].key, stmt->as.grab.module_name) == 0) {
                VSS_Value inner = m->entries[0].value;
                vss_value_retain(inner);
                vss_value_release(exports);
                exports = inner;
            }
            
            // Define module name namespace
            vss_env_define(env, stmt->as.grab.module_name, exports);
            
            // Define individual exports in current env if not name-conflicting
            if (exports.type == VSS_VAL_MAP) {
                VSS_ValMap *em = exports.as.map;
                for (size_t i = 0; i < em->count; i++) {
                    vss_env_define(env, em->entries[i].key, em->entries[i].value);
                    char mangled[256];
                    snprintf(mangled, sizeof(mangled), "%s_%s", stmt->as.grab.module_name, em->entries[i].key);
                    vss_env_define(env, mangled, em->entries[i].value);
                }
            }
            
            vss_value_release(exports);
            vss_env_release(mod_env);
            return flow_normal();
        }
        case VSS_STMT_OBJECT:
        case VSS_STMT_INTERFACE:
        case VSS_STMT_CHOICES:
        case VSS_STMT_SHAPE:
        case VSS_STMT_FIELD:
        case VSS_STMT_YIELD:
        case VSS_STMT_NAMESPACE:
        case VSS_STMT_SET_ITEM:
            return flow_normal();
    }

    return flow_error(stmt->line, stmt->column, "Unknown statement kind.");
}

VSS_FlowResult vss_interpret(VSS_Block block, VSS_Env *env) {
    for (size_t i = 0; i < block.count; i++) {
        VSS_FlowResult res = exec_stmt(block.statements[i], env);
        if (res.type != VSS_FLOW_NORMAL) {
            return res;
        }
    }
    return flow_normal();
}
