#include <stdlib.h>
#include <string.h>

#include "ast.h"

// Helper to duplicate string safely
static char *safe_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) {
        strcpy(dup, s);
    }
    return dup;
}

VSS_Expr *vss_expr_new_number(double value, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_NUMBER;
        expr->line = line;
        expr->column = column;
        expr->as.number = value;
    }
    return expr;
}

VSS_Expr *vss_expr_new_string(const char *value, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_STRING;
        expr->line = line;
        expr->column = column;
        expr->as.string = safe_strdup(value);
    }
    return expr;
}

VSS_Expr *vss_expr_new_bool(bool value, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_BOOL;
        expr->line = line;
        expr->column = column;
        expr->as.boolean = value;
    }
    return expr;
}

VSS_Expr *vss_expr_new_empty(int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_EMPTY;
        expr->line = line;
        expr->column = column;
    }
    return expr;
}

VSS_Expr *vss_expr_new_name(const char *name, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_NAME;
        expr->line = line;
        expr->column = column;
        expr->as.name = safe_strdup(name);
    }
    return expr;
}

VSS_Expr *vss_expr_new_binary(VSS_TokenType op, VSS_Expr *left, VSS_Expr *right, int line, int column) {
    if (left && right) {
        if (left->kind == VSS_EXPR_NUMBER && right->kind == VSS_EXPR_NUMBER) {
            double lval = left->as.number;
            double rval = right->as.number;
            double res = 0.0;
            bool is_comp = false;
            bool comp_res = false;
            
            switch (op) {
                case VSS_TOKEN_PLUS: res = lval + rval; break;
                case VSS_TOKEN_MINUS: res = lval - rval; break;
                case VSS_TOKEN_STAR: res = lval * rval; break;
                case VSS_TOKEN_SLASH: {
                    if (rval != 0.0) res = lval / rval;
                    break;
                }
                case VSS_TOKEN_PERCENT: {
                    if (rval != 0.0) res = (double)((long)lval % (long)rval);
                    break;
                }
                case VSS_TOKEN_ABOVE: comp_res = lval > rval; is_comp = true; break;
                case VSS_TOKEN_BELOW: comp_res = lval < rval; is_comp = true; break;
                case VSS_TOKEN_AT_LEAST: comp_res = lval >= rval; is_comp = true; break;
                case VSS_TOKEN_AT_MOST: comp_res = lval <= rval; is_comp = true; break;
                case VSS_TOKEN_SAME_AS: comp_res = lval == rval; is_comp = true; break;
                case VSS_TOKEN_NOT_SAME_AS: comp_res = lval != rval; is_comp = true; break;
                default: goto no_fold;
            }
            vss_expr_free(left);
            vss_expr_free(right);
            if (is_comp) {
                return vss_expr_new_bool(comp_res, line, column);
            } else {
                return vss_expr_new_number(res, line, column);
            }
        }
        
        if (left->kind == VSS_EXPR_STRING && right->kind == VSS_EXPR_STRING && op == VSS_TOKEN_PLUS) {
            char *lstr = left->as.string;
            char *rstr = right->as.string;
            char *joined = malloc(strlen(lstr) + strlen(rstr) + 1);
            strcpy(joined, lstr);
            strcat(joined, rstr);
            vss_expr_free(left);
            vss_expr_free(right);
            VSS_Expr *expr = vss_expr_new_string(joined, line, column);
            free(joined);
            return expr;
        }
        
        if (left->kind == VSS_EXPR_BOOL && right->kind == VSS_EXPR_BOOL) {
            bool lval = left->as.boolean;
            bool rval = right->as.boolean;
            bool res = false;
            switch (op) {
                case VSS_TOKEN_AND: res = lval && rval; break;
                case VSS_TOKEN_OR: res = lval || rval; break;
                case VSS_TOKEN_SAME_AS: res = lval == rval; break;
                case VSS_TOKEN_NOT_SAME_AS: res = lval != rval; break;
                default: goto no_fold;
            }
            vss_expr_free(left);
            vss_expr_free(right);
            return vss_expr_new_bool(res, line, column);
        }
    }
    
no_fold:;
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_BINARY;
        expr->line = line;
        expr->column = column;
        expr->as.binary.op = op;
        expr->as.binary.left = left;
        expr->as.binary.right = right;
    }
    return expr;
}

VSS_Expr *vss_expr_new_unary(VSS_TokenType op, VSS_Expr *operand, int line, int column) {
    if (operand) {
        if (op == VSS_TOKEN_MINUS && operand->kind == VSS_EXPR_NUMBER) {
            double val = -operand->as.number;
            vss_expr_free(operand);
            return vss_expr_new_number(val, line, column);
        }
        if (op == VSS_TOKEN_NOT && operand->kind == VSS_EXPR_BOOL) {
            bool val = !operand->as.boolean;
            vss_expr_free(operand);
            return vss_expr_new_bool(val, line, column);
        }
    }
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_UNARY;
        expr->line = line;
        expr->column = column;
        expr->as.unary.op = op;
        expr->as.unary.operand = operand;
    }
    return expr;
}

VSS_Expr *vss_expr_new_list(VSS_Expr **elements, size_t count, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_LIST;
        expr->line = line;
        expr->column = column;
        expr->as.list.elements = elements;
        expr->as.list.count = count;
    }
    return expr;
}

VSS_Expr *vss_expr_new_map(char **keys, VSS_Expr **values, size_t count, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_MAP;
        expr->line = line;
        expr->column = column;
        expr->as.map.keys = keys;
        expr->as.map.values = values;
        expr->as.map.count = count;
    }
    return expr;
}

VSS_Expr *vss_expr_new_item_access(VSS_Expr *list, VSS_Expr *index, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_ITEM_ACCESS;
        expr->line = line;
        expr->column = column;
        expr->as.item_access.list = list;
        expr->as.item_access.index = index;
    }
    return expr;
}

VSS_Expr *vss_expr_new_field_access(VSS_Expr *map, VSS_Expr *field, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_FIELD_ACCESS;
        expr->line = line;
        expr->column = column;
        expr->as.field_access.map = map;
        expr->as.field_access.field = field;
    }
    return expr;
}

VSS_Expr *vss_expr_new_call(VSS_Expr *callee, VSS_Expr **args, size_t count, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_CALL;
        expr->line = line;
        expr->column = column;
        expr->as.call.callee = callee;
        expr->as.call.args = args;
        expr->as.call.count = count;
    }
    return expr;
}

VSS_Expr *vss_expr_new_mine(int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_MINE;
        expr->line = line;
        expr->column = column;
    }
    return expr;
}

VSS_Expr *vss_expr_new_parent(int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_PARENT;
        expr->line = line;
        expr->column = column;
    }
    return expr;
}

VSS_Expr *vss_expr_new_struct_literal(const char *name, char **keys, VSS_Expr **values, size_t count, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_STRUCT_LITERAL;
        expr->line = line;
        expr->column = column;
        expr->as.struct_literal.name = safe_strdup(name);
        expr->as.struct_literal.keys = keys;
        expr->as.struct_literal.values = values;
        expr->as.struct_literal.count = count;
    }
    return expr;
}

VSS_Expr *vss_expr_new_closure(char **params, size_t param_count, VSS_Block body, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_CLOSURE;
        expr->line = line;
        expr->column = column;
        expr->as.closure.params = params;
        expr->as.closure.param_count = param_count;
        expr->as.closure.body = body;
    }
    return expr;
}

void vss_expr_free(VSS_Expr *expr) {
    if (!expr) return;
    switch (expr->kind) {
        case VSS_EXPR_NUMBER:
        case VSS_EXPR_BOOL:
        case VSS_EXPR_EMPTY:
            break;
        case VSS_EXPR_STRING:
            free(expr->as.string);
            break;
        case VSS_EXPR_NAME:
            free(expr->as.name);
            break;
        case VSS_EXPR_BINARY:
            vss_expr_free(expr->as.binary.left);
            vss_expr_free(expr->as.binary.right);
            break;
        case VSS_EXPR_UNARY:
            vss_expr_free(expr->as.unary.operand);
            break;
        case VSS_EXPR_LIST:
        case VSS_EXPR_SET:
            for (size_t i = 0; i < expr->as.list.count; i++) {
                vss_expr_free(expr->as.list.elements[i]);
            }
            free(expr->as.list.elements);
            break;
        case VSS_EXPR_MAP:
            for (size_t i = 0; i < expr->as.map.count; i++) {
                free(expr->as.map.keys[i]);
                vss_expr_free(expr->as.map.values[i]);
            }
            free(expr->as.map.keys);
            free(expr->as.map.values);
            break;
        case VSS_EXPR_ITEM_ACCESS:
            vss_expr_free(expr->as.item_access.list);
            vss_expr_free(expr->as.item_access.index);
            break;
        case VSS_EXPR_FIELD_ACCESS:
            vss_expr_free(expr->as.field_access.map);
            vss_expr_free(expr->as.field_access.field);
            break;
        case VSS_EXPR_CALL:
            vss_expr_free(expr->as.call.callee);
            for (size_t i = 0; i < expr->as.call.count; i++) {
                vss_expr_free(expr->as.call.args[i]);
            }
            free(expr->as.call.args);
            break;
        case VSS_EXPR_MINE:
        case VSS_EXPR_PARENT:
            break;
        case VSS_EXPR_STRUCT_LITERAL:
            free(expr->as.struct_literal.name);
            for (size_t i = 0; i < expr->as.struct_literal.count; i++) {
                free(expr->as.struct_literal.keys[i]);
                vss_expr_free(expr->as.struct_literal.values[i]);
            }
            free(expr->as.struct_literal.keys);
            free(expr->as.struct_literal.values);
            break;
        case VSS_EXPR_CLOSURE:
            for (size_t i = 0; i < expr->as.closure.param_count; i++) {
                free(expr->as.closure.params[i]);
            }
            free(expr->as.closure.params);
            vss_block_free(expr->as.closure.body);
            break;
        case VSS_EXPR_AWAIT:
            vss_expr_free(expr->as.await_expr.task_expr);
            if (expr->as.await_expr.timeout_expr) vss_expr_free(expr->as.await_expr.timeout_expr);
            break;
        case VSS_EXPR_START_TASK:
            vss_expr_free(expr->as.start_task.callee);
            for (size_t i = 0; i < expr->as.start_task.count; i++) {
                vss_expr_free(expr->as.start_task.args[i]);
            }
            free(expr->as.start_task.args);
            break;
    }
    free(expr);
}

VSS_Stmt *vss_stmt_new_make(const char *name, const char *type_name, VSS_Expr *initializer, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_MAKE;
        stmt->line = line;
        stmt->column = column;
        stmt->as.make.name = safe_strdup(name);
        stmt->as.make.type_name = safe_strdup(type_name);
        stmt->as.make.initializer = initializer;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_keep(const char *name, const char *type_name, VSS_Expr *initializer, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_KEEP;
        stmt->line = line;
        stmt->column = column;
        stmt->as.keep.name = safe_strdup(name);
        stmt->as.keep.type_name = safe_strdup(type_name);
        stmt->as.keep.initializer = initializer;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_assign(const char *name, VSS_Expr *value, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_ASSIGN;
        stmt->line = line;
        stmt->column = column;
        stmt->as.assign.name = safe_strdup(name);
        stmt->as.assign.value = value;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_say(VSS_Expr *expression, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_SAY;
        stmt->line = line;
        stmt->column = column;
        stmt->as.say.expression = expression;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_when(VSS_WhenBranch *branches, size_t branch_count, VSS_Block otherwise_branch, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_WHEN;
        stmt->line = line;
        stmt->column = column;
        stmt->as.when.branches = branches;
        stmt->as.when.branch_count = branch_count;
        stmt->as.when.otherwise_branch = otherwise_branch;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_repeat_count(VSS_Expr *count_expr, VSS_Block body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_REPEAT_COUNT;
        stmt->line = line;
        stmt->column = column;
        stmt->as.repeat_count.count_expr = count_expr;
        stmt->as.repeat_count.body = body;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_repeat_range(const char *var_name, VSS_Expr *start, VSS_Expr *end, VSS_Block body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_REPEAT_RANGE;
        stmt->line = line;
        stmt->column = column;
        stmt->as.repeat_range.var_name = safe_strdup(var_name);
        stmt->as.repeat_range.start = start;
        stmt->as.repeat_range.end = end;
        stmt->as.repeat_range.body = body;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_repeat_each(const char *var_name, VSS_Expr *collection, VSS_Block body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_REPEAT_EACH;
        stmt->line = line;
        stmt->column = column;
        stmt->as.repeat_each.var_name = safe_strdup(var_name);
        stmt->as.repeat_each.collection = collection;
        stmt->as.repeat_each.body = body;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_during(VSS_Expr *condition, VSS_Block body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_DURING;
        stmt->line = line;
        stmt->column = column;
        stmt->as.during.condition = condition;
        stmt->as.during.body = body;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_leave(int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_LEAVE;
        stmt->line = line;
        stmt->column = column;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_skip(int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_SKIP;
        stmt->line = line;
        stmt->column = column;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_task(const char *name, char **params, size_t param_count, VSS_Block body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_TASK;
        stmt->line = line;
        stmt->column = column;
        stmt->as.task.name = safe_strdup(name);
        stmt->as.task.params = params;
        stmt->as.task.param_count = param_count;
        stmt->as.task.body = body;
        stmt->as.task.is_coroutine = false;
        stmt->as.task.is_async = false;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_send(VSS_Expr *expression, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_SEND;
        stmt->line = line;
        stmt->column = column;
        stmt->as.send.expression = expression;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_grab(const char *module_name, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_GRAB;
        stmt->line = line;
        stmt->column = column;
        stmt->as.grab.module_name = safe_strdup(module_name);
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_attempt(VSS_Block try_body, const char *problem_var, VSS_Block rescue_body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_ATTEMPT;
        stmt->line = line;
        stmt->column = column;
        stmt->as.attempt.try_body = try_body;
        stmt->as.attempt.problem_var = safe_strdup(problem_var);
        stmt->as.attempt.rescue_body = rescue_body;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_choose(VSS_Expr *expr, VSS_ChooseCase *cases, size_t case_count, VSS_Block otherwise_branch, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_CHOOSE;
        stmt->line = line;
        stmt->column = column;
        stmt->as.choose.expr = expr;
        stmt->as.choose.cases = cases;
        stmt->as.choose.case_count = case_count;
        stmt->as.choose.otherwise_branch = otherwise_branch;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_put(VSS_Expr *value, VSS_Expr *list, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_PUT;
        stmt->line = line;
        stmt->column = column;
        stmt->as.put.value = value;
        stmt->as.put.list = list;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_set_field(VSS_Expr *map, VSS_Expr *field, VSS_Expr *value, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_SET_FIELD;
        stmt->line = line;
        stmt->column = column;
        stmt->as.set_field.map = map;
        stmt->as.set_field.field = field;
        stmt->as.set_field.value = value;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_hi_htmvss(int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_HI_HTMVSS;
        stmt->line = line;
        stmt->column = column;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_bye_htmvss(int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_BYE_HTMVSS;
        stmt->line = line;
        stmt->column = column;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_set_item(VSS_Expr *list, VSS_Expr *index, VSS_Expr *value, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_SET_ITEM;
        stmt->line = line;
        stmt->column = column;
        stmt->as.set_item.list = list;
        stmt->as.set_item.index = index;
        stmt->as.set_item.value = value;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_expr(VSS_Expr *expression, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_EXPR;
        stmt->line = line;
        stmt->column = column;
        stmt->as.expr_stmt.expression = expression;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_ask(VSS_Expr *prompt, VSS_Expr *target, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_ASK;
        stmt->line = line;
        stmt->column = column;
        stmt->as.ask.prompt = prompt;
        stmt->as.ask.target = target;
    }
    return stmt;
}

void vss_block_free(VSS_Block block) {
    if (block.statements) {
        for (size_t i = 0; i < block.count; i++) {
            vss_stmt_free(block.statements[i]);
        }
        free(block.statements);
    }
}

void vss_stmt_free(VSS_Stmt *stmt) {
    if (!stmt) return;
    switch (stmt->kind) {
        case VSS_STMT_MAKE:
            free(stmt->as.make.name);
            if (stmt->as.make.type_name) free(stmt->as.make.type_name);
            vss_expr_free(stmt->as.make.initializer);
            break;
        case VSS_STMT_KEEP:
            free(stmt->as.keep.name);
            if (stmt->as.keep.type_name) free(stmt->as.keep.type_name);
            vss_expr_free(stmt->as.keep.initializer);
            break;
        case VSS_STMT_ASSIGN:
            free(stmt->as.assign.name);
            vss_expr_free(stmt->as.assign.value);
            break;
        case VSS_STMT_SAY:
            vss_expr_free(stmt->as.say.expression);
            break;
        case VSS_STMT_WHEN:
            for (size_t i = 0; i < stmt->as.when.branch_count; i++) {
                vss_expr_free(stmt->as.when.branches[i].condition);
                vss_block_free(stmt->as.when.branches[i].block);
            }
            free(stmt->as.when.branches);
            vss_block_free(stmt->as.when.otherwise_branch);
            break;
        case VSS_STMT_REPEAT_COUNT:
            vss_expr_free(stmt->as.repeat_count.count_expr);
            vss_block_free(stmt->as.repeat_count.body);
            break;
        case VSS_STMT_REPEAT_RANGE:
            free(stmt->as.repeat_range.var_name);
            vss_expr_free(stmt->as.repeat_range.start);
            vss_expr_free(stmt->as.repeat_range.end);
            vss_block_free(stmt->as.repeat_range.body);
            break;
        case VSS_STMT_REPEAT_EACH:
            free(stmt->as.repeat_each.var_name);
            vss_expr_free(stmt->as.repeat_each.collection);
            vss_block_free(stmt->as.repeat_each.body);
            break;
        case VSS_STMT_DURING:
            vss_expr_free(stmt->as.during.condition);
            vss_block_free(stmt->as.during.body);
            break;
        case VSS_STMT_LEAVE:
        case VSS_STMT_SKIP:
            break;
        case VSS_STMT_TASK:
            free(stmt->as.task.name);
            for (size_t i = 0; i < stmt->as.task.param_count; i++) {
                free(stmt->as.task.params[i]);
            }
            free(stmt->as.task.params);
            vss_block_free(stmt->as.task.body);
            break;
        case VSS_STMT_SEND:
            vss_expr_free(stmt->as.send.expression);
            break;
        case VSS_STMT_GRAB:
            free(stmt->as.grab.module_name);
            break;
        case VSS_STMT_ATTEMPT:
            vss_block_free(stmt->as.attempt.try_body);
            free(stmt->as.attempt.problem_var);
            vss_block_free(stmt->as.attempt.rescue_body);
            break;
        case VSS_STMT_CHOOSE:
            vss_expr_free(stmt->as.choose.expr);
            for (size_t i = 0; i < stmt->as.choose.case_count; i++) {
                vss_expr_free(stmt->as.choose.cases[i].expr);
                vss_block_free(stmt->as.choose.cases[i].block);
            }
            free(stmt->as.choose.cases);
            vss_block_free(stmt->as.choose.otherwise_branch);
            break;
        case VSS_STMT_PUT:
            vss_expr_free(stmt->as.put.value);
            vss_expr_free(stmt->as.put.list);
            break;
        case VSS_STMT_SET_FIELD:
            vss_expr_free(stmt->as.set_field.map);
            vss_expr_free(stmt->as.set_field.field);
            vss_expr_free(stmt->as.set_field.value);
            break;
        case VSS_STMT_SET_ITEM:
            vss_expr_free(stmt->as.set_item.list);
            vss_expr_free(stmt->as.set_item.index);
            vss_expr_free(stmt->as.set_item.value);
            break;
        case VSS_STMT_HI_HTMVSS:
        case VSS_STMT_BYE_HTMVSS:
            break;
        case VSS_STMT_EXPR:
            vss_expr_free(stmt->as.expr_stmt.expression);
            break;
        case VSS_STMT_OBJECT:
            free(stmt->as.object_decl.name);
            if (stmt->as.object_decl.parent_name) free(stmt->as.object_decl.parent_name);
            if (stmt->as.object_decl.interfaces) {
                for (size_t i = 0; i < stmt->as.object_decl.interface_count; i++) {
                    free(stmt->as.object_decl.interfaces[i]);
                }
                free(stmt->as.object_decl.interfaces);
            }
            if (stmt->as.object_decl.members) {
                for (size_t i = 0; i < stmt->as.object_decl.member_count; i++) {
                    vss_stmt_free(stmt->as.object_decl.members[i]);
                }
                free(stmt->as.object_decl.members);
            }
            break;
        case VSS_STMT_INTERFACE:
            free(stmt->as.interface_decl.name);
            if (stmt->as.interface_decl.task_decls) {
                for (size_t i = 0; i < stmt->as.interface_decl.task_count; i++) {
                    vss_stmt_free(stmt->as.interface_decl.task_decls[i]);
                }
                free(stmt->as.interface_decl.task_decls);
            }
            break;
        case VSS_STMT_CHOICES:
            free(stmt->as.choices_decl.name);
            if (stmt->as.choices_decl.members) {
                for (size_t i = 0; i < stmt->as.choices_decl.member_count; i++) {
                    free(stmt->as.choices_decl.members[i]);
                }
                free(stmt->as.choices_decl.members);
            }
            break;
        case VSS_STMT_SHAPE:
            free(stmt->as.shape_decl.name);
            if (stmt->as.shape_decl.members) {
                for (size_t i = 0; i < stmt->as.shape_decl.member_count; i++) {
                    vss_stmt_free(stmt->as.shape_decl.members[i]);
                }
                free(stmt->as.shape_decl.members);
            }
            break;
        case VSS_STMT_FIELD:
            free(stmt->as.field_decl.name);
            if (stmt->as.field_decl.type_name) free(stmt->as.field_decl.type_name);
            if (stmt->as.field_decl.default_value) vss_expr_free(stmt->as.field_decl.default_value);
            break;
        case VSS_STMT_YIELD:
            if (stmt->as.yield_stmt.expression) vss_expr_free(stmt->as.yield_stmt.expression);
            break;
        case VSS_STMT_NAMESPACE:
            free(stmt->as.namespace_decl.name);
            vss_block_free(stmt->as.namespace_decl.body);
            break;
        case VSS_STMT_ASK:
            if (stmt->as.ask.prompt) vss_expr_free(stmt->as.ask.prompt);
            vss_expr_free(stmt->as.ask.target);
            break;
        case VSS_STMT_PARALLEL_EACH:
            free(stmt->as.parallel_each.var_name);
            vss_expr_free(stmt->as.parallel_each.collection);
            vss_block_free(stmt->as.parallel_each.body);
            break;
        case VSS_STMT_LOCK:
            vss_expr_free(stmt->as.lock_stmt.mutex_expr);
            vss_block_free(stmt->as.lock_stmt.body);
            break;
        case VSS_STMT_SELECT:
            for (size_t i = 0; i < stmt->as.select_stmt.case_count; i++) {
                vss_expr_free(stmt->as.select_stmt.cases[i].expr);
                vss_block_free(stmt->as.select_stmt.cases[i].block);
            }
            free(stmt->as.select_stmt.cases);
            vss_block_free(stmt->as.select_stmt.otherwise_branch);
            break;
    }
    free(stmt);
}

VSS_Stmt *vss_stmt_new_object(const char *name, const char *parent_name, char **interfaces, size_t interface_count, VSS_Stmt **members, size_t member_count, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_OBJECT;
        stmt->line = line;
        stmt->column = column;
        stmt->as.object_decl.name = safe_strdup(name);
        stmt->as.object_decl.parent_name = safe_strdup(parent_name);
        stmt->as.object_decl.interfaces = interfaces;
        stmt->as.object_decl.interface_count = interface_count;
        stmt->as.object_decl.members = members;
        stmt->as.object_decl.member_count = member_count;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_interface(const char *name, VSS_Stmt **task_decls, size_t task_count, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_INTERFACE;
        stmt->line = line;
        stmt->column = column;
        stmt->as.interface_decl.name = safe_strdup(name);
        stmt->as.interface_decl.task_decls = task_decls;
        stmt->as.interface_decl.task_count = task_count;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_choices(const char *name, char **members, size_t member_count, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_CHOICES;
        stmt->line = line;
        stmt->column = column;
        stmt->as.choices_decl.name = safe_strdup(name);
        stmt->as.choices_decl.members = members;
        stmt->as.choices_decl.member_count = member_count;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_shape(const char *name, VSS_Stmt **members, size_t member_count, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_SHAPE;
        stmt->line = line;
        stmt->column = column;
        stmt->as.shape_decl.name = safe_strdup(name);
        stmt->as.shape_decl.members = members;
        stmt->as.shape_decl.member_count = member_count;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_field(const char *name, const char *type_name, VSS_Expr *default_value, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_FIELD;
        stmt->line = line;
        stmt->column = column;
        stmt->as.field_decl.name = safe_strdup(name);
        stmt->as.field_decl.type_name = safe_strdup(type_name);
        stmt->as.field_decl.default_value = default_value;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_yield(VSS_Expr *expression, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_YIELD;
        stmt->line = line;
        stmt->column = column;
        stmt->as.yield_stmt.expression = expression;
    }
    return stmt;
}

VSS_Expr *vss_expr_new_set(VSS_Expr **elements, size_t count, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_SET;
        expr->line = line;
        expr->column = column;
        expr->as.list.elements = elements;
        expr->as.list.count = count;
    }
    return expr;
}

VSS_Stmt *vss_stmt_new_namespace(const char *name, VSS_Block body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_NAMESPACE;
        stmt->line = line;
        stmt->column = column;
        stmt->as.namespace_decl.name = safe_strdup(name);
        stmt->as.namespace_decl.body = body;
    }
    return stmt;
}

VSS_Expr *vss_expr_new_await(VSS_Expr *task_expr, VSS_Expr *timeout_expr, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_AWAIT;
        expr->line = line;
        expr->column = column;
        expr->as.await_expr.task_expr = task_expr;
        expr->as.await_expr.timeout_expr = timeout_expr;
    }
    return expr;
}

VSS_Expr *vss_expr_new_start_task(VSS_Expr *callee, VSS_Expr **args, size_t count, int line, int column) {
    VSS_Expr *expr = malloc(sizeof(VSS_Expr));
    if (expr) {
        expr->kind = VSS_EXPR_START_TASK;
        expr->line = line;
        expr->column = column;
        expr->as.start_task.callee = callee;
        expr->as.start_task.args = args;
        expr->as.start_task.count = count;
    }
    return expr;
}

VSS_Stmt *vss_stmt_new_parallel_each(const char *var_name, VSS_Expr *collection, VSS_Block body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_PARALLEL_EACH;
        stmt->line = line;
        stmt->column = column;
        stmt->as.parallel_each.var_name = safe_strdup(var_name);
        stmt->as.parallel_each.collection = collection;
        stmt->as.parallel_each.body = body;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_lock(VSS_Expr *mutex_expr, VSS_Block body, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_LOCK;
        stmt->line = line;
        stmt->column = column;
        stmt->as.lock_stmt.mutex_expr = mutex_expr;
        stmt->as.lock_stmt.body = body;
    }
    return stmt;
}

VSS_Stmt *vss_stmt_new_select(VSS_ChooseCase *cases, size_t case_count, VSS_Block otherwise_branch, int line, int column) {
    VSS_Stmt *stmt = malloc(sizeof(VSS_Stmt));
    if (stmt) {
        stmt->kind = VSS_STMT_SELECT;
        stmt->line = line;
        stmt->column = column;
        stmt->as.select_stmt.cases = cases;
        stmt->as.select_stmt.case_count = case_count;
        stmt->as.select_stmt.otherwise_branch = otherwise_branch;
    }
    return stmt;
}
