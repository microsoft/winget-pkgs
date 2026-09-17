#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "semantic.h"

extern VSS_THREAD_LOCAL const char *vss_current_source;

static void sem_error(int line, int col, const char *format, ...) {
    fprintf(stderr, "\033[1;31merror:\033[0m line %d, col %d: ", line, col);
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fprintf(stderr, "\n");

    if (vss_current_source && line > 0) {
        const char *p = vss_current_source;
        int curr_line = 1;
        while (*p && curr_line < line) {
            if (*p == '\n') curr_line++;
            p++;
        }
        const char *line_start = p;
        while (*p && *p != '\n' && *p != '\r') p++;
        int line_len = (int)(p - line_start);
        
        fprintf(stderr, " %4d | %.*s\n", line, line_len, line_start);
        
        fprintf(stderr, "      | ");
        for (int i = 1; i < col; i++) {
            fprintf(stderr, " ");
        }
        fprintf(stderr, "\033[1;31m^\033[0m\n");
    }
}

static char *safe_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) strcpy(dup, s);
    return dup;
}

typedef struct {
    char *name;
    char **params;
    size_t param_count;
} SemTaskSig;

typedef struct {
    char *name;
    SemTaskSig *tasks;
    size_t task_count;
} SemInterface;

typedef struct {
    char *name;
    char **members;
    size_t member_count;
} SemEnum;

typedef struct {
    char *name;
    char *parent_name;
    char **interfaces;
    size_t interface_count;
    char **fields;
    size_t field_count;
    SemTaskSig *methods;
    size_t method_count;
} SemClass;

typedef struct SemVar {
    char *name;
    char *type_name;
    bool is_const;
    struct SemVar *next;
} SemVar;

typedef struct SemScope {
    SemVar *vars;
    struct SemScope *parent;
} SemScope;

static SemInterface *interfaces = NULL;
static size_t interface_count = 0;

static SemEnum *enums = NULL;
static size_t enum_count = 0;

static SemClass *classes = NULL;
static size_t class_count = 0;

static SemInterface *find_interface(const char *name) {
    for (size_t i = 0; i < interface_count; i++) {
        if (strcmp(interfaces[i].name, name) == 0) return &interfaces[i];
    }
    return NULL;
}

static SemEnum *find_enum(const char *name) {
    for (size_t i = 0; i < enum_count; i++) {
        if (strcmp(enums[i].name, name) == 0) return &enums[i];
    }
    return NULL;
}

static SemClass *find_class(const char *name) {
    for (size_t i = 0; i < class_count; i++) {
        if (strcmp(classes[i].name, name) == 0) return &classes[i];
    }
    return NULL;
}

static SemTaskSig *find_class_method(SemClass *cls, const char *name) {
    for (size_t i = 0; i < cls->method_count; i++) {
        if (strcmp(cls->methods[i].name, name) == 0) return &cls->methods[i];
    }
    if (cls->parent_name) {
        SemClass *parent = find_class(cls->parent_name);
        if (parent) return find_class_method(parent, name);
    }
    return NULL;
}

static bool has_inheritance_loop(SemClass *cls) {
    SemClass *curr = cls;
    size_t depth = 0;
    while (curr && curr->parent_name) {
        if (depth > 256) return true;
        SemClass *parent = find_class(curr->parent_name);
        if (parent == cls) return true;
        curr = parent;
        depth++;
    }
    return false;
}

static void scope_define(SemScope *scope, const char *name, const char *type_name, bool is_const) {
    SemVar *v = malloc(sizeof(SemVar));
    v->name = safe_strdup(name);
    v->type_name = type_name ? safe_strdup(type_name) : NULL;
    v->is_const = is_const;
    v->next = scope->vars;
    scope->vars = v;
}

static SemVar *scope_lookup(SemScope *scope, const char *name) {
    SemScope *curr = scope;
    while (curr) {
        SemVar *v = curr->vars;
        while (v) {
            if (strcmp(v->name, name) == 0) return v;
            v = v->next;
        }
        curr = curr->parent;
    }
    return NULL;
}

static void scope_free(SemScope *scope) {
    SemVar *v = scope->vars;
    while (v) {
        SemVar *next = v->next;
        free(v->name);
        if (v->type_name) free(v->type_name);
        free(v);
        v = next;
    }
    scope->vars = NULL;
}

static const char *infer_type(VSS_Expr *expr, SemScope *scope) {
    if (!expr) return "any";
    switch (expr->kind) {
        case VSS_EXPR_NUMBER: return "number";
        case VSS_EXPR_STRING: return "text";
        case VSS_EXPR_BOOL: return "boolean";
        case VSS_EXPR_EMPTY: return "any";
        case VSS_EXPR_LIST: return "list";
        case VSS_EXPR_SET: return "set";
        case VSS_EXPR_MAP: return "map";
        case VSS_EXPR_MINE: return "any";
        case VSS_EXPR_PARENT: return "any";
        case VSS_EXPR_NAME: {
            SemVar *v = scope_lookup(scope, expr->as.name);
            if (v && v->type_name) return v->type_name;
            if (find_class(expr->as.name)) return expr->as.name;
            if (find_enum(expr->as.name)) return expr->as.name;
            return "any";
        }
        case VSS_EXPR_BINARY: {
            VSS_TokenType op = expr->as.binary.op;
            if (op == VSS_TOKEN_PLUS || op == VSS_TOKEN_MINUS || op == VSS_TOKEN_STAR || op == VSS_TOKEN_SLASH || op == VSS_TOKEN_PERCENT) {
                const char *lt = infer_type(expr->as.binary.left, scope);
                const char *rt = infer_type(expr->as.binary.right, scope);
                if (strcmp(lt, "decimal") == 0 || strcmp(rt, "decimal") == 0) return "decimal";
                return "number";
            }
            if (op == VSS_TOKEN_ABOVE || op == VSS_TOKEN_BELOW || op == VSS_TOKEN_AT_LEAST || op == VSS_TOKEN_AT_MOST || op == VSS_TOKEN_SAME_AS || op == VSS_TOKEN_NOT_SAME_AS || op == VSS_TOKEN_AND || op == VSS_TOKEN_OR) {
                return "boolean";
            }
            return "any";
        }
        case VSS_EXPR_UNARY: {
            VSS_TokenType op = expr->as.unary.op;
            if (op == VSS_TOKEN_MINUS || op == VSS_TOKEN_AWAIT) {
                return infer_type(expr->as.unary.operand, scope);
            }
            if (op == VSS_TOKEN_NOT) {
                return "boolean";
            }
            return "any";
        }
        case VSS_EXPR_CALL: {
            if (expr->as.call.callee->kind == VSS_EXPR_NAME) {
                SemClass *cls = find_class(expr->as.call.callee->as.name);
                if (cls) return cls->name;
            }
            return "any";
        }
        case VSS_EXPR_FIELD_ACCESS: {
            if (expr->as.field_access.map->kind == VSS_EXPR_NAME) {
                SemEnum *enm = find_enum(expr->as.field_access.map->as.name);
                if (enm) return enm->name;
            }
            return "any";
        }
        case VSS_EXPR_STRUCT_LITERAL: {
            return expr->as.struct_literal.name;
        }
        case VSS_EXPR_CLOSURE: {
            return "any";
        }
        default: return "any";
    }
}

static bool types_compatible(const char *declared, const char *inferred) {
    if (!declared || !inferred) return true;
    if (strcmp(declared, "any") == 0 || strcmp(inferred, "any") == 0) return true;
    if (strcmp(declared, inferred) == 0) return true;
    if ((strcmp(declared, "number") == 0 || strcmp(declared, "decimal") == 0) &&
        (strcmp(inferred, "number") == 0 || strcmp(inferred, "decimal") == 0)) {
        return true;
    }
    return false;
}

static bool check_stmt(VSS_Stmt *stmt, SemScope *scope) {
    if (!stmt) return true;
    switch (stmt->kind) {
        case VSS_STMT_MAKE: {
            const char *inf = infer_type(stmt->as.make.initializer, scope);
            if (stmt->as.make.type_name) {
                if (!types_compatible(stmt->as.make.type_name, inf)) {
                    sem_error(stmt->line, stmt->column, "Type mismatch in variable declaration '%s'. Declared type is '%s', got '%s'.",
                              stmt->as.make.name, stmt->as.make.type_name, inf);
                    return false;
                }
            }
            scope_define(scope, stmt->as.make.name, stmt->as.make.type_name, false);
            break;
        }
        case VSS_STMT_KEEP: {
            const char *inf = infer_type(stmt->as.keep.initializer, scope);
            if (stmt->as.keep.type_name) {
                if (!types_compatible(stmt->as.keep.type_name, inf)) {
                    sem_error(stmt->line, stmt->column, "Type mismatch in constant declaration '%s'. Declared type is '%s', got '%s'.",
                              stmt->as.keep.name, stmt->as.keep.type_name, inf);
                    return false;
                }
            }
            scope_define(scope, stmt->as.keep.name, stmt->as.keep.type_name, true);
            break;
        }
        case VSS_STMT_ASSIGN: {
            SemVar *v = scope_lookup(scope, stmt->as.assign.name);
            if (v) {
                if (v->is_const) {
                    sem_error(stmt->line, stmt->column, "Cannot reassign to constant '%s'.",
                              stmt->as.assign.name);
                    return false;
                }
                const char *inf = infer_type(stmt->as.assign.value, scope);
                if (v->type_name) {
                    if (!types_compatible(v->type_name, inf)) {
                        sem_error(stmt->line, stmt->column, "Type mismatch in assignment to '%s'. Declared type is '%s', got '%s'.",
                                  stmt->as.assign.name, v->type_name, inf);
                        return false;
                    }
                }
            } else {
                scope_define(scope, stmt->as.assign.name, "any", false);
            }
            break;
        }
        case VSS_STMT_WHEN: {
            for (size_t i = 0; i < stmt->as.when.branch_count; i++) {
                SemScope sub;
                sub.vars = NULL;
                sub.parent = scope;
                for (size_t j = 0; j < stmt->as.when.branches[i].block.count; j++) {
                    if (!check_stmt(stmt->as.when.branches[i].block.statements[j], &sub)) {
                        scope_free(&sub);
                        return false;
                    }
                }
                scope_free(&sub);
            }
            if (stmt->as.when.otherwise_branch.count > 0) {
                SemScope sub;
                sub.vars = NULL;
                sub.parent = scope;
                for (size_t j = 0; j < stmt->as.when.otherwise_branch.count; j++) {
                    if (!check_stmt(stmt->as.when.otherwise_branch.statements[j], &sub)) {
                        scope_free(&sub);
                        return false;
                    }
                }
                scope_free(&sub);
            }
            break;
        }
        case VSS_STMT_REPEAT_COUNT: {
            SemScope sub;
            sub.vars = NULL;
            sub.parent = scope;
            for (size_t j = 0; j < stmt->as.repeat_count.body.count; j++) {
                if (!check_stmt(stmt->as.repeat_count.body.statements[j], &sub)) {
                    scope_free(&sub);
                    return false;
                }
            }
            scope_free(&sub);
            break;
        }
        case VSS_STMT_REPEAT_RANGE: {
            SemScope sub;
            sub.vars = NULL;
            sub.parent = scope;
            scope_define(&sub, stmt->as.repeat_range.var_name, "number", false);
            for (size_t j = 0; j < stmt->as.repeat_range.body.count; j++) {
                if (!check_stmt(stmt->as.repeat_range.body.statements[j], &sub)) {
                    scope_free(&sub);
                    return false;
                }
            }
            scope_free(&sub);
            break;
        }
        case VSS_STMT_REPEAT_EACH: {
            SemScope sub;
            sub.vars = NULL;
            sub.parent = scope;
            scope_define(&sub, stmt->as.repeat_each.var_name, "any", false);
            for (size_t j = 0; j < stmt->as.repeat_each.body.count; j++) {
                if (!check_stmt(stmt->as.repeat_each.body.statements[j], &sub)) {
                    scope_free(&sub);
                    return false;
                }
            }
            scope_free(&sub);
            break;
        }
        case VSS_STMT_DURING: {
            SemScope sub;
            sub.vars = NULL;
            sub.parent = scope;
            for (size_t j = 0; j < stmt->as.during.body.count; j++) {
                if (!check_stmt(stmt->as.during.body.statements[j], &sub)) {
                    scope_free(&sub);
                    return false;
                }
            }
            scope_free(&sub);
            break;
        }
        case VSS_STMT_TASK: {
            SemScope sub;
            sub.vars = NULL;
            sub.parent = scope;
            for (size_t i = 0; i < stmt->as.task.param_count; i++) {
                scope_define(&sub, stmt->as.task.params[i], "any", false);
            }
            for (size_t j = 0; j < stmt->as.task.body.count; j++) {
                if (!check_stmt(stmt->as.task.body.statements[j], &sub)) {
                    scope_free(&sub);
                    return false;
                }
            }
            scope_free(&sub);
            break;
        }
        case VSS_STMT_CHOOSE: {
            for (size_t i = 0; i < stmt->as.choose.case_count; i++) {
                SemScope sub;
                sub.vars = NULL;
                sub.parent = scope;
                for (size_t j = 0; j < stmt->as.choose.cases[i].block.count; j++) {
                    if (!check_stmt(stmt->as.choose.cases[i].block.statements[j], &sub)) {
                        scope_free(&sub);
                        return false;
                    }
                }
                scope_free(&sub);
            }
            if (stmt->as.choose.otherwise_branch.count > 0) {
                SemScope sub;
                sub.vars = NULL;
                sub.parent = scope;
                for (size_t j = 0; j < stmt->as.choose.otherwise_branch.count; j++) {
                    if (!check_stmt(stmt->as.choose.otherwise_branch.statements[j], &sub)) {
                        scope_free(&sub);
                        return false;
                    }
                }
                scope_free(&sub);
            }
            break;
        }
        case VSS_STMT_ATTEMPT: {
            SemScope sub_try;
            sub_try.vars = NULL;
            sub_try.parent = scope;
            for (size_t j = 0; j < stmt->as.attempt.try_body.count; j++) {
                if (!check_stmt(stmt->as.attempt.try_body.statements[j], &sub_try)) {
                    scope_free(&sub_try);
                    return false;
                }
            }
            scope_free(&sub_try);
            
            SemScope sub_rescue;
            sub_rescue.vars = NULL;
            sub_rescue.parent = scope;
            scope_define(&sub_rescue, stmt->as.attempt.problem_var, "text", true);
            for (size_t j = 0; j < stmt->as.attempt.rescue_body.count; j++) {
                if (!check_stmt(stmt->as.attempt.rescue_body.statements[j], &sub_rescue)) {
                    scope_free(&sub_rescue);
                    return false;
                }
            }
            scope_free(&sub_rescue);
            break;
        }
        case VSS_STMT_NAMESPACE: {
            for (size_t i = 0; i < stmt->as.namespace_decl.body.count; i++) {
                if (!check_stmt(stmt->as.namespace_decl.body.statements[i], scope)) {
                    return false;
                }
            }
            break;
        }
        case VSS_STMT_PARALLEL_EACH: {
            SemScope sub;
            sub.vars = NULL;
            sub.parent = scope;
            scope_define(&sub, stmt->as.parallel_each.var_name, "any", false);
            for (size_t j = 0; j < stmt->as.parallel_each.body.count; j++) {
                if (!check_stmt(stmt->as.parallel_each.body.statements[j], &sub)) {
                    scope_free(&sub);
                    return false;
                }
            }
            scope_free(&sub);
            break;
        }
        case VSS_STMT_LOCK: {
            SemScope sub;
            sub.vars = NULL;
            sub.parent = scope;
            for (size_t j = 0; j < stmt->as.lock_stmt.body.count; j++) {
                if (!check_stmt(stmt->as.lock_stmt.body.statements[j], &sub)) {
                    scope_free(&sub);
                    return false;
                }
            }
            scope_free(&sub);
            break;
        }
        case VSS_STMT_SELECT: {
            for (size_t i = 0; i < stmt->as.select_stmt.case_count; i++) {
                SemScope sub;
                sub.vars = NULL;
                sub.parent = scope;
                for (size_t j = 0; j < stmt->as.select_stmt.cases[i].block.count; j++) {
                    if (!check_stmt(stmt->as.select_stmt.cases[i].block.statements[j], &sub)) {
                        scope_free(&sub);
                        return false;
                    }
                }
                scope_free(&sub);
            }
            if (stmt->as.select_stmt.otherwise_branch.count > 0) {
                SemScope sub;
                sub.vars = NULL;
                sub.parent = scope;
                for (size_t j = 0; j < stmt->as.select_stmt.otherwise_branch.count; j++) {
                    if (!check_stmt(stmt->as.select_stmt.otherwise_branch.statements[j], &sub)) {
                        scope_free(&sub);
                        return false;
                    }
                }
                scope_free(&sub);
            }
            break;
        }
        case VSS_STMT_SET_ITEM: {
            VSS_Stmt *t1 = vss_stmt_new_expr(stmt->as.set_item.list, stmt->line, stmt->column);
            VSS_Stmt *t2 = vss_stmt_new_expr(stmt->as.set_item.index, stmt->line, stmt->column);
            VSS_Stmt *t3 = vss_stmt_new_expr(stmt->as.set_item.value, stmt->line, stmt->column);
            bool ok = check_stmt(t1, scope) && check_stmt(t2, scope) && check_stmt(t3, scope);
            free(t1); free(t2); free(t3);
            if (!ok) return false;
            break;
        }
        case VSS_STMT_SHAPE: {
            SemScope sub;
            sub.vars = NULL;
            sub.parent = scope;
            for (size_t j = 0; j < stmt->as.shape_decl.member_count; j++) {
                if (!check_stmt(stmt->as.shape_decl.members[j], &sub)) {
                    scope_free(&sub);
                    return false;
                }
            }
            scope_free(&sub);
            break;
        }
        case VSS_STMT_FIELD: {
            if (stmt->as.field_decl.default_value) {
                VSS_Stmt *temp = vss_stmt_new_expr(stmt->as.field_decl.default_value, stmt->line, stmt->column);
                bool ok = check_stmt(temp, scope);
                free(temp);
                if (!ok) return false;
            }
            break;
        }
        case VSS_STMT_YIELD: {
            if (stmt->as.yield_stmt.expression) {
                VSS_Stmt *temp = vss_stmt_new_expr(stmt->as.yield_stmt.expression, stmt->line, stmt->column);
                bool ok = check_stmt(temp, scope);
                free(temp);
                if (!ok) return false;
            }
            break;
        }
        case VSS_STMT_ASK: {
            if (stmt->as.ask.prompt) {
                VSS_Stmt *temp = vss_stmt_new_expr(stmt->as.ask.prompt, stmt->line, stmt->column);
                bool ok = check_stmt(temp, scope);
                free(temp);
                if (!ok) return false;
            }
            VSS_Expr *target = stmt->as.ask.target;
            if (target->kind == VSS_EXPR_NAME) {
                SemVar *v = scope_lookup(scope, target->as.name);
                if (!v) {
                    sem_error(stmt->line, stmt->column, "Variable '%s' is not defined.", target->as.name);
                    return false;
                }
                if (v->is_const) {
                    sem_error(stmt->line, stmt->column, "Cannot assign input to constant '%s'.", target->as.name);
                    return false;
                }
            } else if (target->kind == VSS_EXPR_FIELD_ACCESS) {
                VSS_Expr *base = target->as.field_access.map;
                if (base->kind == VSS_EXPR_NAME) {
                    SemVar *v = scope_lookup(scope, base->as.name);
                    if (!v) {
                        sem_error(stmt->line, stmt->column, "Variable '%s' is not defined.", base->as.name);
                        return false;
                    }
                }
            } else {
                sem_error(stmt->line, stmt->column, "Invalid target for 'ask' statement. Expected variable name or field.");
                return false;
            }
            break;
        }
        default:
            break;
    }
    return true;
}

static VSS_Stmt *find_stmt_for_class_in_block(VSS_Block block, const char *name) {
    for (size_t i = 0; i < block.count; i++) {
        VSS_Stmt *s = block.statements[i];
        if (s->kind == VSS_STMT_OBJECT && strcmp(s->as.object_decl.name, name) == 0) {
            return s;
        }
        if (s->kind == VSS_STMT_SHAPE && strcmp(s->as.shape_decl.name, name) == 0) {
            return s;
        }
        if (s->kind == VSS_STMT_NAMESPACE) {
            VSS_Stmt *res = find_stmt_for_class_in_block(s->as.namespace_decl.body, name);
            if (res) return res;
        }
    }
    return NULL;
}

static VSS_Stmt *find_stmt_for_class(VSS_Block program, const char *name) {
    return find_stmt_for_class_in_block(program, name);
}

static bool register_declarations(VSS_Block block) {
    for (size_t i = 0; i < block.count; i++) {
        VSS_Stmt *stmt = block.statements[i];
        if (stmt->kind == VSS_STMT_CHOICES) {
            SemEnum *e = find_enum(stmt->as.choices_decl.name);
            if (e) {
                sem_error(stmt->line, stmt->column, "Duplicate enum declaration '%s'.", stmt->as.choices_decl.name);
                return false;
            }
            enums = realloc(enums, sizeof(SemEnum) * (enum_count + 1));
            SemEnum *curr = &enums[enum_count++];
            curr->name = safe_strdup(stmt->as.choices_decl.name);
            curr->members = malloc(sizeof(char*) * stmt->as.choices_decl.member_count);
            curr->member_count = stmt->as.choices_decl.member_count;
            for (size_t j = 0; j < stmt->as.choices_decl.member_count; j++) {
                curr->members[j] = safe_strdup(stmt->as.choices_decl.members[j]);
            }
        } else if (stmt->kind == VSS_STMT_INTERFACE) {
            SemInterface *iface = find_interface(stmt->as.interface_decl.name);
            if (iface) {
                sem_error(stmt->line, stmt->column, "Duplicate interface declaration '%s'.", stmt->as.interface_decl.name);
                return false;
            }
            interfaces = realloc(interfaces, sizeof(SemInterface) * (interface_count + 1));
            SemInterface *curr = &interfaces[interface_count++];
            curr->name = safe_strdup(stmt->as.interface_decl.name);
            curr->tasks = malloc(sizeof(SemTaskSig) * stmt->as.interface_decl.task_count);
            curr->task_count = stmt->as.interface_decl.task_count;
            for (size_t j = 0; j < stmt->as.interface_decl.task_count; j++) {
                VSS_Stmt *t = stmt->as.interface_decl.task_decls[j];
                curr->tasks[j].name = safe_strdup(t->as.task.name);
                curr->tasks[j].params = malloc(sizeof(char*) * t->as.task.param_count);
                curr->tasks[j].param_count = t->as.task.param_count;
                for (size_t k = 0; k < t->as.task.param_count; k++) {
                    curr->tasks[j].params[k] = safe_strdup(t->as.task.params[k]);
                }
            }
        } else if (stmt->kind == VSS_STMT_OBJECT) {
            SemClass *cls = find_class(stmt->as.object_decl.name);
            if (cls) {
                sem_error(stmt->line, stmt->column, "Duplicate class declaration '%s'.", stmt->as.object_decl.name);
                return false;
            }
            classes = realloc(classes, sizeof(SemClass) * (class_count + 1));
            SemClass *curr = &classes[class_count++];
            curr->name = safe_strdup(stmt->as.object_decl.name);
            curr->parent_name = stmt->as.object_decl.parent_name ? safe_strdup(stmt->as.object_decl.parent_name) : NULL;
            curr->interfaces = malloc(sizeof(char*) * stmt->as.object_decl.interface_count);
            curr->interface_count = stmt->as.object_decl.interface_count;
            for (size_t j = 0; j < stmt->as.object_decl.interface_count; j++) {
                curr->interfaces[j] = safe_strdup(stmt->as.object_decl.interfaces[j]);
            }
            curr->fields = NULL;
            curr->field_count = 0;
            curr->methods = NULL;
            curr->method_count = 0;
            for (size_t j = 0; j < stmt->as.object_decl.member_count; j++) {
                VSS_Stmt *m = stmt->as.object_decl.members[j];
                if (m->kind == VSS_STMT_MAKE || m->kind == VSS_STMT_KEEP) {
                    const char *fname = (m->kind == VSS_STMT_MAKE) ? m->as.make.name : m->as.keep.name;
                    curr->fields = realloc(curr->fields, sizeof(char*) * (curr->field_count + 1));
                    curr->fields[curr->field_count++] = safe_strdup(fname);
                } else if (m->kind == VSS_STMT_TASK) {
                    curr->methods = realloc(curr->methods, sizeof(SemTaskSig) * (curr->method_count + 1));
                    SemTaskSig *sig = &curr->methods[curr->method_count++];
                    sig->name = safe_strdup(m->as.task.name);
                    sig->param_count = m->as.task.param_count;
                    sig->params = malloc(sizeof(char*) * m->as.task.param_count);
                    for (size_t k = 0; k < m->as.task.param_count; k++) {
                        sig->params[k] = safe_strdup(m->as.task.params[k]);
                    }
                }
            }
        } else if (stmt->kind == VSS_STMT_SHAPE) {
            SemClass *cls = find_class(stmt->as.shape_decl.name);
            if (cls) {
                sem_error(stmt->line, stmt->column, "Duplicate shape/class declaration '%s'.", stmt->as.shape_decl.name);
                return false;
            }
            classes = realloc(classes, sizeof(SemClass) * (class_count + 1));
            SemClass *curr = &classes[class_count++];
            curr->name = safe_strdup(stmt->as.shape_decl.name);
            curr->parent_name = NULL;
            curr->interfaces = NULL;
            curr->interface_count = 0;
            curr->fields = NULL;
            curr->field_count = 0;
            curr->methods = NULL;
            curr->method_count = 0;
            for (size_t j = 0; j < stmt->as.shape_decl.member_count; j++) {
                VSS_Stmt *m = stmt->as.shape_decl.members[j];
                if (m->kind == VSS_STMT_FIELD) {
                    curr->fields = realloc(curr->fields, sizeof(char*) * (curr->field_count + 1));
                    curr->fields[curr->field_count++] = safe_strdup(m->as.field_decl.name);
                }
            }
        } else if (stmt->kind == VSS_STMT_NAMESPACE) {
            if (!register_declarations(stmt->as.namespace_decl.body)) {
                return false;
            }
        }
    }
    return true;
}

bool vss_semantic_analyze(VSS_Block program) {
    // 1. Clean up any state from previous analyzer runs
    for (size_t i = 0; i < interface_count; i++) {
        free(interfaces[i].name);
        for (size_t j = 0; j < interfaces[i].task_count; j++) {
            free(interfaces[i].tasks[j].name);
            for (size_t k = 0; k < interfaces[i].tasks[j].param_count; k++) {
                free(interfaces[i].tasks[j].params[k]);
            }
            free(interfaces[i].tasks[j].params);
        }
        free(interfaces[i].tasks);
    }
    free(interfaces);
    interfaces = NULL;
    interface_count = 0;
    
    for (size_t i = 0; i < enum_count; i++) {
        free(enums[i].name);
        for (size_t j = 0; j < enums[i].member_count; j++) {
            free(enums[i].members[j]);
        }
        free(enums[i].members);
    }
    free(enums);
    enums = NULL;
    enum_count = 0;
    
    for (size_t i = 0; i < class_count; i++) {
        free(classes[i].name);
        if (classes[i].parent_name) free(classes[i].parent_name);
        for (size_t j = 0; j < classes[i].interface_count; j++) {
            free(classes[i].interfaces[j]);
        }
        free(classes[i].interfaces);
        for (size_t j = 0; j < classes[i].field_count; j++) {
            free(classes[i].fields[j]);
        }
        free(classes[i].fields);
        for (size_t j = 0; j < classes[i].method_count; j++) {
            free(classes[i].methods[j].name);
            for (size_t k = 0; k < classes[i].methods[j].param_count; k++) {
                free(classes[i].methods[j].params[k]);
            }
            free(classes[i].methods[j].params);
        }
        free(classes[i].methods);
    }
    free(classes);
    classes = NULL;
    class_count = 0;

    // 2. Scan and register enums, interfaces, and classes recursively
    if (!register_declarations(program)) return false;
    
    // 3. Verify class hierarchy and interface requirements
    for (size_t i = 0; i < class_count; i++) {
        SemClass *cls = &classes[i];
        VSS_Stmt *cls_stmt = find_stmt_for_class(program, cls->name);
        int line = cls_stmt ? cls_stmt->line : 0;
        int col = cls_stmt ? cls_stmt->column : 0;
        if (cls->parent_name) {
            SemClass *parent = find_class(cls->parent_name);
            if (!parent) {
                sem_error(line, col, "Parent class '%s' of class '%s' not found.", cls->parent_name, cls->name);
                return false;
            }
            if (has_inheritance_loop(cls)) {
                sem_error(line, col, "Circular inheritance loop detected involving class '%s'.", cls->name);
                return false;
            }
        }
        
        for (size_t j = 0; j < cls->interface_count; j++) {
            SemInterface *iface = find_interface(cls->interfaces[j]);
            if (!iface) {
                sem_error(line, col, "Interface '%s' implemented by class '%s' not found.", cls->interfaces[j], cls->name);
                return false;
            }
            for (size_t k = 0; k < iface->task_count; k++) {
                SemTaskSig *req = &iface->tasks[k];
                SemTaskSig *impl = find_class_method(cls, req->name);
                if (!impl) {
                    sem_error(line, col, "Class '%s' does not implement required interface task '%s' from '%s'.", cls->name, req->name, iface->name);
                    return false;
                }
                if (impl->param_count != req->param_count) {
                    sem_error(line, col, "Class '%s' implements '%s' with wrong parameter count (expected %zu, got %zu).",
                              cls->name, req->name, req->param_count, impl->param_count);
                    return false;
                }
            }
        }
    }
    
    // 4. Type check statements
    SemScope global_scope;
    global_scope.vars = NULL;
    global_scope.parent = NULL;
    for (size_t i = 0; i < program.count; i++) {
        if (!check_stmt(program.statements[i], &global_scope)) {
            scope_free(&global_scope);
            return false;
        }
    }
    scope_free(&global_scope);
    return true;
}
