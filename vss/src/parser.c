#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "parser.h"

static const char *get_suggestion(VSS_Token *token) {
    if (token->type == VSS_TOKEN_IDENTIFIER) {
        if (strncmp(token->start, "return", token->length) == 0 && token->length == 6) {
            return "use 'send' instead of 'return'";
        }
        if (strncmp(token->start, "while", token->length) == 0 && token->length == 5) {
            return "use 'during' instead of 'while'";
        }
        if (strncmp(token->start, "import", token->length) == 0 && token->length == 6) {
            return "use 'grab' instead of 'import'";
        }
        if (strncmp(token->start, "print", token->length) == 0 && token->length == 5) {
            return "use 'say' instead of 'print'";
        }
        if (strncmp(token->start, "println", token->length) == 0 && token->length == 7) {
            return "use 'say' instead of 'println'";
        }
        if (strncmp(token->start, "true", token->length) == 0 && token->length == 4) {
            return "use 'yes' instead of 'true'";
        }
        if (strncmp(token->start, "false", token->length) == 0 && token->length == 5) {
            return "use 'no' instead of 'false'";
        }
        if (strncmp(token->start, "null", token->length) == 0 && token->length == 4) {
            return "use 'empty' instead of 'null'";
        }
        if (strncmp(token->start, "nil", token->length) == 0 && token->length == 3) {
            return "use 'empty' instead of 'nil'";
        }
        if (strncmp(token->start, "def", token->length) == 0 && token->length == 3) {
            return "use 'task' instead of 'def'";
        }
        if (strncmp(token->start, "func", token->length) == 0 && token->length == 4) {
            return "use 'task' instead of 'func'";
        }
        if (strncmp(token->start, "function", token->length) == 0 && token->length == 8) {
            return "use 'task' instead of 'function'";
        }
        if (strncmp(token->start, "elif", token->length) == 0 && token->length == 4) {
            return "use 'orwhen' instead of 'elif'";
        }
        if (strncmp(token->start, "else", token->length) == 0 && token->length == 4) {
            return "use 'otherwise' instead of 'else'";
        }
    }
    return NULL;
}

static void error_at(VSS_Parser *parser, VSS_Token *token, const char *message) {
    if (parser->panic_mode) return;
    parser->panic_mode = true;
    parser->had_error = true;

    fprintf(stderr, "\033[1;31merror:\033[0m line %d, col %d: ", token->line, token->column);
    if (token->type == VSS_TOKEN_EOF) {
        fprintf(stderr, "at end of file: ");
    } else if (token->type == VSS_TOKEN_ERROR) {
        // Already an error token from lexer
    } else {
        fprintf(stderr, "at '%.*s': ", (int)token->length, token->start);
    }
    fprintf(stderr, "%s\n", message);

    const char *source = (parser->lexer && parser->lexer->source) ? parser->lexer->source : NULL;
    const char *line_start = NULL;
    if (source && token->start && token->start >= source) {
        line_start = token->start;
        while (line_start > source && *(line_start - 1) != '\n' && *(line_start - 1) != '\r') {
            line_start--;
        }
    }

    if (line_start && token->type != VSS_TOKEN_EOF) {
        const char *line_end = line_start;
        while (*line_end != '\0' && *line_end != '\n' && *line_end != '\r') {
            line_end++;
        }
        int line_len = (int)(line_end - line_start);
        fprintf(stderr, " %4d | %.*s\n", token->line, line_len, line_start);

        fprintf(stderr, "      | ");
        for (int i = 1; i < token->column; i++) {
            if (line_start[i - 1] == '\t') {
                fprintf(stderr, "    ");
            } else {
                fprintf(stderr, " ");
            }
        }
        int len = (token->length > 0) ? (int)token->length : 1;
        fprintf(stderr, "\033[1;31m");
        for (int i = 0; i < len; i++) {
            fprintf(stderr, "^");
        }
        fprintf(stderr, "\033[0m\n");
    }
    const char *suggestion = get_suggestion(token);
    if (suggestion) {
        fprintf(stderr, "      \033[1;36mhint:\033[0m %s\n", suggestion);
    }
}

static void advance(VSS_Parser *parser) {
    parser->previous = parser->current;

    for (;;) {
        parser->current = vss_lexer_next(parser->lexer);
        if (parser->current.type != VSS_TOKEN_ERROR) break;
        error_at(parser, &parser->current, parser->current.start);
    }
}

static bool check(VSS_Parser *parser, VSS_TokenType type) {
    return parser->current.type == type;
}

static bool match(VSS_Parser *parser, VSS_TokenType type) {
    if (!check(parser, type)) return false;
    advance(parser);
    return true;
}

static void consume(VSS_Parser *parser, VSS_TokenType type, const char *message) {
    if (parser->current.type == type) {
        advance(parser);
        return;
    }
    error_at(parser, &parser->current, message);
}

static bool is_newline_or_eof(VSS_Parser *parser) {
    return check(parser, VSS_TOKEN_NEWLINE) || check(parser, VSS_TOKEN_EOF);
}

static bool can_start_unary(VSS_TokenType type) {
    switch (type) {
        case VSS_TOKEN_NUMBER:
        case VSS_TOKEN_STRING:
        case VSS_TOKEN_YES:
        case VSS_TOKEN_NO:
        case VSS_TOKEN_EMPTY:
        case VSS_TOKEN_IDENTIFIER:
        case VSS_TOKEN_LEFT_BRACKET:
        case VSS_TOKEN_MAP:
        case VSS_TOKEN_NOT:
        case VSS_TOKEN_MINUS:
        case VSS_TOKEN_SIZE:
        case VSS_TOKEN_EXISTS:
        case VSS_TOKEN_READ:
        case VSS_TOKEN_MINE:
        case VSS_TOKEN_PARENT:
            return true;
        default:
            return false;
    }
}

static bool match_becomes_or_equal(VSS_Parser *parser) {
    return match(parser, VSS_TOKEN_BECOMES) || match(parser, VSS_TOKEN_EQUAL);
}

static void consume_becomes_or_equal(VSS_Parser *parser, const char *message) {
    if (match_becomes_or_equal(parser)) return;
    error_at(parser, &parser->current, message);
}

// Forward declarations of expression parsers
static VSS_Expr *parse_expression(VSS_Parser *parser);
static char *parse_string_value(const char *start, size_t length);

static VSS_Expr *parse_interpolated_string(VSS_Parser *parser, const char *str, int line, int column) {
    const char *p = str;
    const char *start = str;
    VSS_Expr *expr = NULL;

    while (*p) {
        if (*p == '{') {
            size_t len = p - start;
            if (len > 0) {
                char *segment = malloc(len + 1);
                memcpy(segment, start, len);
                segment[len] = '\0';
                VSS_Expr *seg_expr = vss_expr_new_string(segment, line, column);
                free(segment);
                if (!expr) {
                    expr = seg_expr;
                } else {
                    expr = vss_expr_new_binary(VSS_TOKEN_PLUS, expr, seg_expr, line, column);
                }
            }
            
            p++;
            const char *expr_start = p;
            int braces = 1;
            while (*p && braces > 0) {
                if (*p == '{') braces++;
                else if (*p == '}') braces--;
                if (braces > 0) p++;
            }
            if (*p != '}') {
                error_at(parser, &parser->current, "Unterminated interpolation bracket.");
                break;
            }
            
            size_t expr_len = p - expr_start;
            char *expr_str = malloc(expr_len + 1);
            memcpy(expr_str, expr_start, expr_len);
            expr_str[expr_len] = '\0';
            
            VSS_Lexer temp_lexer;
            vss_lexer_init(&temp_lexer, expr_str);
            VSS_Parser temp_parser;
            vss_parser_init(&temp_parser, &temp_lexer);
            VSS_Expr *inner_expr = parse_expression(&temp_parser);
            
            bool is_valid = !temp_parser.had_error && (temp_parser.current.type == VSS_TOKEN_EOF);
            if (!is_valid) {
                if (inner_expr) {
                    vss_expr_free(inner_expr);
                }
                free(expr_str);
                start = expr_start - 1;
                p++;
                continue;
            }
            
            free(expr_str);
            if (!expr) {
                expr = inner_expr;
            } else {
                expr = vss_expr_new_binary(VSS_TOKEN_PLUS, expr, inner_expr, line, column);
            }
            
            p++;
            start = p;
        } else {
            p++;
        }
    }
    
    if (*start) {
        VSS_Expr *seg_expr = vss_expr_new_string(start, line, column);
        if (!expr) {
            expr = seg_expr;
        } else {
            expr = vss_expr_new_binary(VSS_TOKEN_PLUS, expr, seg_expr, line, column);
        }
    }
    
    if (!expr) {
        expr = vss_expr_new_string("", line, column);
    }
    return expr;
}

static VSS_Expr *parse_expression(VSS_Parser *parser);
static VSS_Expr *parse_or(VSS_Parser *parser);
static VSS_Expr *parse_and(VSS_Parser *parser);
static VSS_Expr *parse_equality(VSS_Parser *parser);
static VSS_Expr *parse_comparison(VSS_Parser *parser);
static VSS_Expr *parse_term(VSS_Parser *parser);
static VSS_Expr *parse_factor(VSS_Parser *parser);
static VSS_Expr *parse_unary(VSS_Parser *parser);
static VSS_Expr *parse_postfix(VSS_Parser *parser);
static VSS_Expr *parse_primary(VSS_Parser *parser);

static VSS_Stmt *parse_statement(VSS_Parser *parser);
static VSS_Block parse_block(VSS_Parser *parser);

static char *safe_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) {
        strcpy(dup, s);
    }
    return dup;
}

static VSS_Block parse_block(VSS_Parser *parser) {
    while (match(parser, VSS_TOKEN_NEWLINE));
    
    VSS_Stmt **statements = NULL;
    size_t count = 0;
    
    while (!check(parser, VSS_TOKEN_FINISH) && 
           !check(parser, VSS_TOKEN_ORWHEN) && 
           !check(parser, VSS_TOKEN_OTHERWISE) && 
           !check(parser, VSS_TOKEN_CASE) && 
           !check(parser, VSS_TOKEN_RESCUE) && 
           !check(parser, VSS_TOKEN_EOF)) {
        VSS_Stmt *stmt = parse_statement(parser);
        if (stmt) {
            statements = realloc(statements, sizeof(VSS_Stmt*) * (count + 1));
            statements[count++] = stmt;
        }
        
        if (check(parser, VSS_TOKEN_EOF)) break;
        
        if (!match(parser, VSS_TOKEN_NEWLINE)) {
            error_at(parser, &parser->current, "Expected newline after statement in block.");
            while (!is_newline_or_eof(parser)) {
                advance(parser);
            }
            if (check(parser, VSS_TOKEN_NEWLINE)) advance(parser);
        }
        while (match(parser, VSS_TOKEN_NEWLINE));
        parser->panic_mode = false;
    }
    
    VSS_Block b;
    b.statements = statements;
    b.count = count;
    return b;
}

static VSS_Expr *parse_expression(VSS_Parser *parser) {
    return parse_or(parser);
}

static VSS_Expr *parse_or(VSS_Parser *parser) {
    VSS_Expr *expr = parse_and(parser);
    while (match(parser, VSS_TOKEN_OR)) {
        VSS_Token op = parser->previous;
        VSS_Expr *right = parse_and(parser);
        expr = vss_expr_new_binary(op.type, expr, right, op.line, op.column);
    }
    return expr;
}

static VSS_Expr *parse_and(VSS_Parser *parser) {
    VSS_Expr *expr = parse_equality(parser);
    while (match(parser, VSS_TOKEN_AND)) {
        VSS_Token op = parser->previous;
        VSS_Expr *right = parse_equality(parser);
        expr = vss_expr_new_binary(op.type, expr, right, op.line, op.column);
    }
    return expr;
}

static VSS_Expr *parse_equality(VSS_Parser *parser) {
    VSS_Expr *expr = parse_comparison(parser);
    while (match(parser, VSS_TOKEN_SAME_AS) || match(parser, VSS_TOKEN_NOT_SAME_AS)) {
        VSS_Token op = parser->previous;
        VSS_Expr *right = parse_comparison(parser);
        expr = vss_expr_new_binary(op.type, expr, right, op.line, op.column);
    }
    return expr;
}

static VSS_Expr *parse_comparison(VSS_Parser *parser) {
    VSS_Expr *expr = parse_term(parser);
    while (match(parser, VSS_TOKEN_ABOVE) || match(parser, VSS_TOKEN_BELOW) ||
           match(parser, VSS_TOKEN_AT_LEAST) || match(parser, VSS_TOKEN_AT_MOST)) {
        VSS_Token op = parser->previous;
        VSS_Expr *right = parse_term(parser);
        expr = vss_expr_new_binary(op.type, expr, right, op.line, op.column);
    }
    return expr;
}

static VSS_Expr *parse_term(VSS_Parser *parser) {
    VSS_Expr *expr = parse_factor(parser);
    while (match(parser, VSS_TOKEN_PLUS) || match(parser, VSS_TOKEN_MINUS)) {
        VSS_Token op = parser->previous;
        VSS_Expr *right = parse_factor(parser);
        expr = vss_expr_new_binary(op.type, expr, right, op.line, op.column);
    }
    return expr;
}

static VSS_Expr *parse_factor(VSS_Parser *parser) {
    VSS_Expr *expr = parse_unary(parser);
    while (match(parser, VSS_TOKEN_STAR) || match(parser, VSS_TOKEN_SLASH) || match(parser, VSS_TOKEN_PERCENT)) {
        VSS_Token op = parser->previous;
        VSS_Expr *right = parse_unary(parser);
        expr = vss_expr_new_binary(op.type, expr, right, op.line, op.column);
    }
    return expr;
}

static VSS_Expr *parse_unary(VSS_Parser *parser) {
    if (match(parser, VSS_TOKEN_AWAIT)) {
        VSS_Token op = parser->previous;
        VSS_Expr *task_expr = parse_unary(parser);
        VSS_Expr *timeout_expr = NULL;
        if (match(parser, VSS_TOKEN_TIMEOUT)) {
            timeout_expr = parse_expression(parser);
        }
        return vss_expr_new_await(task_expr, timeout_expr, op.line, op.column);
    }
    if (match(parser, VSS_TOKEN_NOT) || match(parser, VSS_TOKEN_MINUS)) {
        VSS_Token op = parser->previous;
        VSS_Expr *operand = parse_unary(parser);
        return vss_expr_new_unary(op.type, operand, op.line, op.column);
    }
    return parse_postfix(parser);
}

static VSS_Expr *parse_postfix(VSS_Parser *parser) {
    VSS_Expr *expr = parse_primary(parser);
    for (;;) {
        if (match(parser, VSS_TOKEN_ITEM)) {
            VSS_Token op = parser->previous;
            VSS_Expr *index = parse_unary(parser);
            expr = vss_expr_new_item_access(expr, index, op.line, op.column);
        } else if (match(parser, VSS_TOKEN_LEFT_BRACKET)) {
            VSS_Token op = parser->previous;
            VSS_Expr *index = parse_expression(parser);
            consume(parser, VSS_TOKEN_RIGHT_BRACKET, "Expected ']' after index.");
            expr = vss_expr_new_item_access(expr, index, op.line, op.column);
        } else if (match(parser, VSS_TOKEN_FIELD)) {
            VSS_Token op = parser->previous;
            VSS_Expr *field = parse_unary(parser);
            expr = vss_expr_new_field_access(expr, field, op.line, op.column);
        } else if (match(parser, VSS_TOKEN_DOT)) {
            VSS_Token op = parser->previous;
            VSS_TokenType type = parser->current.type;
            bool is_id = (type == VSS_TOKEN_IDENTIFIER) || 
                         (type >= VSS_TOKEN_SAY && type <= VSS_TOKEN_HTMVSS) ||
                         (type >= VSS_TOKEN_OBJECT && type <= VSS_TOKEN_PARENT);
            if (!is_id) {
                error_at(parser, &parser->current, "Expected field or method name after '.'.");
                return expr;
            }
            advance(parser);
            char *field_name = parse_string_value(parser->previous.start, parser->previous.length);
            VSS_Expr *field = vss_expr_new_string(field_name, parser->previous.line, parser->previous.column);
            free(field_name);
            expr = vss_expr_new_field_access(expr, field, op.line, op.column);
        } else if (match(parser, VSS_TOKEN_LEFT_PAREN)) {
            VSS_Token op = parser->previous;
            VSS_Expr **args = NULL;
            size_t count = 0;
            if (!check(parser, VSS_TOKEN_RIGHT_PAREN)) {
                do {
                    VSS_Expr *arg = parse_expression(parser);
                    args = realloc(args, sizeof(VSS_Expr*) * (count + 1));
                    args[count++] = arg;
                } while (match(parser, VSS_TOKEN_COMMA));
            }
            consume(parser, VSS_TOKEN_RIGHT_PAREN, "Expected ')' after arguments.");
            expr = vss_expr_new_call(expr, args, count, op.line, op.column);
        } else if (match(parser, VSS_TOKEN_WITH)) {
            VSS_Token op = parser->previous;
            VSS_Expr **args = NULL;
            size_t count = 0;
            // Parse arguments as space-separated unary expressions
            while (can_start_unary(parser->current.type) && !is_newline_or_eof(parser)) {
                VSS_Expr *arg = parse_unary(parser);
                args = realloc(args, sizeof(VSS_Expr*) * (count + 1));
                args[count++] = arg;
            }
            expr = vss_expr_new_call(expr, args, count, op.line, op.column);
        } else if (can_start_unary(parser->current.type) && parser->current.type != VSS_TOKEN_MINUS && !is_newline_or_eof(parser) &&
                   (expr->kind == VSS_EXPR_NAME || expr->kind == VSS_EXPR_FIELD_ACCESS || expr->kind == VSS_EXPR_CLOSURE)) {
            VSS_Expr **args = NULL;
            size_t count = 0;
            int line = parser->current.line;
            int col = parser->current.column;
            while (can_start_unary(parser->current.type) && !is_newline_or_eof(parser)) {
                VSS_Expr *arg = parse_unary(parser);
                args = realloc(args, sizeof(VSS_Expr*) * (count + 1));
                args[count++] = arg;
            }
            expr = vss_expr_new_call(expr, args, count, line, col);
        } else {
            break;
        }
    }
    return expr;
}

// Parse string characters, handling escape sequences
static char *parse_string_value(const char *start, size_t length) {
    // Strip double quotes
    if (length >= 2 && start[0] == '"' && start[length - 1] == '"') {
        start++;
        length -= 2;
    }
    char *result = malloc(length + 1);
    size_t r = 0;
    for (size_t i = 0; i < length; i++) {
        if (start[i] == '\r') {
            continue;
        }
        if (start[i] == '\\' && i + 1 < length) {
            i++;
            switch (start[i]) {
                case 'n': result[r++] = '\n'; break;
                case 't': result[r++] = '\t'; break;
                case '"': result[r++] = '"'; break;
                case '\\': result[r++] = '\\'; break;
                default: result[r++] = start[i]; break;
            }
        } else {
            result[r++] = start[i];
        }
    }
    result[r] = '\0';
    return result;
}

static bool is_identifier_like(VSS_TokenType type) {
    return (type == VSS_TOKEN_IDENTIFIER) || 
           (type >= VSS_TOKEN_SAY && type <= VSS_TOKEN_SELECT);
}

static bool has_arrow_before_brace(VSS_Parser *parser) {
    VSS_Lexer temp = *parser->lexer;
    int brace_depth = 1;
    for (;;) {
        VSS_Token tok = vss_lexer_next(&temp);
        if (tok.type == VSS_TOKEN_EOF) break;
        if (tok.type == VSS_TOKEN_LEFT_BRACE) brace_depth++;
        if (tok.type == VSS_TOKEN_RIGHT_BRACE) {
            brace_depth--;
            if (brace_depth == 0) break;
        }
        if (tok.type == VSS_TOKEN_ARROW && brace_depth == 1) {
            return true;
        }
    }
    return false;
}

static VSS_Block parse_closure_block(VSS_Parser *parser) {
    while (match(parser, VSS_TOKEN_NEWLINE));
    
    VSS_Stmt **statements = NULL;
    size_t count = 0;
    
    VSS_Block block;
    block.statements = NULL;
    block.count = 0;
    
    while (!check(parser, VSS_TOKEN_RIGHT_BRACE) && !check(parser, VSS_TOKEN_EOF)) {
        VSS_Stmt *stmt = parse_statement(parser);
        if (stmt) {
            statements = realloc(statements, sizeof(VSS_Stmt*) * (count + 1));
            statements[count++] = stmt;
        }
        
        if (check(parser, VSS_TOKEN_EOF)) break;
        
        if (!match(parser, VSS_TOKEN_NEWLINE) && !check(parser, VSS_TOKEN_RIGHT_BRACE)) {
            error_at(parser, &parser->current, "Expected newline after statement in closure block.");
            while (!is_newline_or_eof(parser)) {
                advance(parser);
            }
            if (check(parser, VSS_TOKEN_NEWLINE)) advance(parser);
        }
        while (match(parser, VSS_TOKEN_NEWLINE));
    }
    
    block.statements = statements;
    block.count = count;
    return block;
}


static bool is_set_literal(VSS_Parser *parser) {
    VSS_Lexer temp = *parser->lexer;
    int brace_depth = 1;
    int paren_depth = 0;
    int bracket_depth = 0;
    for (;;) {
        VSS_Token tok = vss_lexer_next(&temp);
        if (tok.type == VSS_TOKEN_EOF) break;
        if (tok.type == VSS_TOKEN_LEFT_BRACE) brace_depth++;
        else if (tok.type == VSS_TOKEN_RIGHT_BRACE) {
            brace_depth--;
            if (brace_depth == 0) break;
        }
        else if (tok.type == VSS_TOKEN_LEFT_PAREN) paren_depth++;
        else if (tok.type == VSS_TOKEN_RIGHT_PAREN) { if (paren_depth > 0) paren_depth--; }
        else if (tok.type == VSS_TOKEN_LEFT_BRACKET) bracket_depth++;
        else if (tok.type == VSS_TOKEN_RIGHT_BRACKET) { if (bracket_depth > 0) bracket_depth--; }

        if (brace_depth == 1 && paren_depth == 0 && bracket_depth == 0) {
            if (tok.type == VSS_TOKEN_ARROW || tok.type == VSS_TOKEN_MAKE ||
                tok.type == VSS_TOKEN_KEEP || tok.type == VSS_TOKEN_SAY ||
                tok.type == VSS_TOKEN_WHEN || tok.type == VSS_TOKEN_REPEAT ||
                tok.type == VSS_TOKEN_DURING || tok.type == VSS_TOKEN_TASK ||
                tok.type == VSS_TOKEN_START || tok.type == VSS_TOKEN_PARALLEL ||
                tok.type == VSS_TOKEN_LOCK || tok.type == VSS_TOKEN_SELECT ||
                tok.type == VSS_TOKEN_NEWLINE) {
                return false;
            }
            if (tok.type == VSS_TOKEN_COMMA) {
                return true;
            }
        }
    }
    return false;
}

static VSS_Expr *parse_primary(VSS_Parser *parser) {
    if (check(parser, VSS_TOKEN_LEFT_BRACE) && is_set_literal(parser)) {
        advance(parser); // Consume '{'
        VSS_Token op = parser->previous;
        VSS_Expr **elements = NULL;
        size_t count = 0;
        if (!check(parser, VSS_TOKEN_RIGHT_BRACE)) {
            do {
                while (match(parser, VSS_TOKEN_NEWLINE));
                VSS_Expr *expr = parse_expression(parser);
                elements = realloc(elements, sizeof(VSS_Expr*) * (count + 1));
                elements[count++] = expr;
                while (match(parser, VSS_TOKEN_NEWLINE));
            } while (match(parser, VSS_TOKEN_COMMA));
        }
        consume(parser, VSS_TOKEN_RIGHT_BRACE, "Expected '}' after set elements.");
        return vss_expr_new_set(elements, count, op.line, op.column);
    }

    if (match(parser, VSS_TOKEN_LEFT_BRACE)) {
        VSS_Token op = parser->previous;
        char **params = NULL;
        size_t param_count = 0;
        
        if (has_arrow_before_brace(parser)) {
            if (!check(parser, VSS_TOKEN_ARROW)) {
                do {
                    consume(parser, VSS_TOKEN_IDENTIFIER, "Expected parameter name.");
                    char *param = parse_string_value(parser->previous.start, parser->previous.length);
                    params = realloc(params, sizeof(char*) * (param_count + 1));
                    params[param_count++] = param;
                } while (match(parser, VSS_TOKEN_COMMA));
            }
            consume(parser, VSS_TOKEN_ARROW, "Expected '->' after parameters.");
        }
        
        VSS_Block body;
        // Check if there is a newline or statement keyword
        bool has_nl = false;
        while (match(parser, VSS_TOKEN_NEWLINE)) {
            has_nl = true;
        }
        
        if (check(parser, VSS_TOKEN_RIGHT_BRACE)) {
            body.statements = NULL;
            body.count = 0;
        } else {
            VSS_Token first = parser->current;
            bool is_stmt_kw = (first.type == VSS_TOKEN_SAY || first.type == VSS_TOKEN_MAKE || 
                               first.type == VSS_TOKEN_KEEP || first.type == VSS_TOKEN_DURING || 
                               first.type == VSS_TOKEN_REPEAT || first.type == VSS_TOKEN_WHEN || 
                               first.type == VSS_TOKEN_SEND);
            if (has_nl || is_stmt_kw) {
                body = parse_closure_block(parser);
            } else {
                VSS_Expr *expr = parse_expression(parser);
                VSS_Stmt *send_stmt = vss_stmt_new_send(expr, expr->line, expr->column);
                VSS_Stmt **stmts = malloc(sizeof(VSS_Stmt*));
                stmts[0] = send_stmt;
                body.statements = stmts;
                body.count = 1;
            }
        }
        consume(parser, VSS_TOKEN_RIGHT_BRACE, "Expected '}' to close closure.");
        return vss_expr_new_closure(params, param_count, body, op.line, op.column);
    }

    if (match(parser, VSS_TOKEN_START)) {
        VSS_Token op = parser->previous;
        VSS_TokenType next_type = parser->current.type;
        bool is_start_task = (next_type == VSS_TOKEN_IDENTIFIER || 
                              next_type == VSS_TOKEN_TASK || 
                              next_type == VSS_TOKEN_LEFT_BRACE);
        if (is_start_task) {
            VSS_Expr *callee = parse_postfix(parser);
            VSS_Expr **args = NULL;
            size_t count = 0;
            if (match(parser, VSS_TOKEN_LEFT_PAREN)) {
                if (!check(parser, VSS_TOKEN_RIGHT_PAREN)) {
                    do {
                        VSS_Expr *arg = parse_expression(parser);
                        args = realloc(args, sizeof(VSS_Expr*) * (count + 1));
                        args[count++] = arg;
                    } while (match(parser, VSS_TOKEN_COMMA));
                }
                consume(parser, VSS_TOKEN_RIGHT_PAREN, "Expected ')' after task start arguments.");
            } else if (callee && callee->kind == VSS_EXPR_CALL) {
                args = callee->as.call.args;
                count = callee->as.call.count;
                VSS_Expr *real_callee = callee->as.call.callee;
                free(callee);
                callee = real_callee;
            }
            return vss_expr_new_start_task(callee, args, count, op.line, op.column);
        } else {
            return vss_expr_new_name("start", op.line, op.column);
        }
    }
    if (match(parser, VSS_TOKEN_TIMEOUT)) {
        return vss_expr_new_name("timeout", parser->previous.line, parser->previous.column);
    }
    if (match(parser, VSS_TOKEN_PARALLEL)) {
        return vss_expr_new_name("parallel", parser->previous.line, parser->previous.column);
    }
    if (match(parser, VSS_TOKEN_SELECT)) {
        return vss_expr_new_name("select", parser->previous.line, parser->previous.column);
    }

    if (check(parser, VSS_TOKEN_IDENTIFIER)) {
        VSS_Lexer temp = *parser->lexer;
        VSS_Token next = vss_lexer_next(&temp);
        if (next.type == VSS_TOKEN_LEFT_BRACE) {
            VSS_Token name_tok = parser->current;
            advance(parser); // Consume identifier
            advance(parser); // Consume '{'
            
            char *struct_name = parse_string_value(name_tok.start, name_tok.length);
            char **keys = NULL;
            VSS_Expr **values = NULL;
            size_t count = 0;
            
            while (!check(parser, VSS_TOKEN_RIGHT_BRACE) && !check(parser, VSS_TOKEN_EOF)) {
                consume(parser, VSS_TOKEN_IDENTIFIER, "Expected field name.");
                char *key = parse_string_value(parser->previous.start, parser->previous.length);
                consume(parser, VSS_TOKEN_COLON, "Expected ':' after field name.");
                VSS_Expr *val = parse_expression(parser);
                
                keys = realloc(keys, sizeof(char*) * (count + 1));
                values = realloc(values, sizeof(VSS_Expr*) * (count + 1));
                keys[count] = key;
                values[count] = val;
                count++;
                
                if (!match(parser, VSS_TOKEN_COMMA)) break;
            }
            consume(parser, VSS_TOKEN_RIGHT_BRACE, "Expected '}' to close shape literal.");
            return vss_expr_new_struct_literal(struct_name, keys, values, count, name_tok.line, name_tok.column);
        }
    }

    if (match(parser, VSS_TOKEN_LEFT_PAREN)) {
        VSS_Expr *expr = parse_expression(parser);
        consume(parser, VSS_TOKEN_RIGHT_PAREN, "Expected ')' after expression.");
        return expr;
    }
    if (match(parser, VSS_TOKEN_NUMBER)) {
        double val = strtod(parser->previous.start, NULL);
        return vss_expr_new_number(val, parser->previous.line, parser->previous.column);
    }
    if (match(parser, VSS_TOKEN_STRING)) {
        char *str = parse_string_value(parser->previous.start, parser->previous.length);
        VSS_Expr *expr = NULL;
        if (strchr(str, '{')) {
            expr = parse_interpolated_string(parser, str, parser->previous.line, parser->previous.column);
        } else {
            expr = vss_expr_new_string(str, parser->previous.line, parser->previous.column);
        }
        free(str);
        return expr;
    }
    if (match(parser, VSS_TOKEN_MINE)) {
        return vss_expr_new_mine(parser->previous.line, parser->previous.column);
    }
    if (match(parser, VSS_TOKEN_PARENT)) {
        return vss_expr_new_parent(parser->previous.line, parser->previous.column);
    }
    if (match(parser, VSS_TOKEN_YES)) {
        return vss_expr_new_bool(true, parser->previous.line, parser->previous.column);
    }
    if (match(parser, VSS_TOKEN_NO)) {
        return vss_expr_new_bool(false, parser->previous.line, parser->previous.column);
    }
    if (match(parser, VSS_TOKEN_EMPTY)) {
        return vss_expr_new_empty(parser->previous.line, parser->previous.column);
    }
    if (match(parser, VSS_TOKEN_IDENTIFIER)) {
        char *name = malloc(parser->previous.length + 1);
        memcpy(name, parser->previous.start, parser->previous.length);
        name[parser->previous.length] = '\0';
        VSS_Expr *expr = vss_expr_new_name(name, parser->previous.line, parser->previous.column);
        free(name);
        return expr;
    }
    
    // Built-ins desugared directly
    if (match(parser, VSS_TOKEN_SIZE)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_OF, "Expected 'of' after 'size'.");
        VSS_Expr *collection = parse_unary(parser);
        VSS_Expr **args = malloc(sizeof(VSS_Expr*));
        args[0] = collection;
        return vss_expr_new_call(vss_expr_new_name("__size", op.line, op.column), args, 1, op.line, op.column);
    }
    if (match(parser, VSS_TOKEN_EXISTS)) {
        VSS_Token op = parser->previous;
        VSS_Expr *path = parse_unary(parser);
        VSS_Expr **args = malloc(sizeof(VSS_Expr*));
        args[0] = path;
        return vss_expr_new_call(vss_expr_new_name("__exists", op.line, op.column), args, 1, op.line, op.column);
    }
    if (match(parser, VSS_TOKEN_READ)) {
        VSS_Token op = parser->previous;
        VSS_Expr *path = parse_unary(parser);
        VSS_Expr **args = malloc(sizeof(VSS_Expr*));
        args[0] = path;
        return vss_expr_new_call(vss_expr_new_name("__read", op.line, op.column), args, 1, op.line, op.column);
    }
    
    // List Literal
    if (match(parser, VSS_TOKEN_LEFT_BRACKET)) {
        VSS_Token op = parser->previous;
        VSS_Expr **elements = NULL;
        size_t count = 0;
        
        while (match(parser, VSS_TOKEN_NEWLINE)); // Skip newlines inside bracket
        
        if (!check(parser, VSS_TOKEN_RIGHT_BRACKET)) {
            do {
                while (match(parser, VSS_TOKEN_NEWLINE));
                VSS_Expr *elem = parse_expression(parser);
                elements = realloc(elements, sizeof(VSS_Expr*) * (count + 1));
                elements[count++] = elem;
                while (match(parser, VSS_TOKEN_NEWLINE));
            } while (match(parser, VSS_TOKEN_COMMA));
        }
        
        while (match(parser, VSS_TOKEN_NEWLINE));
        consume(parser, VSS_TOKEN_RIGHT_BRACKET, "Expected ']' at the end of list literal.");
        return vss_expr_new_list(elements, count, op.line, op.column);
    }
    
    // Map Literal
    if (match(parser, VSS_TOKEN_MAP)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_LEFT_BRACKET, "Expected '[' after 'map'.");
        
        char **keys = NULL;
        VSS_Expr **values = NULL;
        size_t count = 0;
        
        while (match(parser, VSS_TOKEN_NEWLINE));
        
        while (!check(parser, VSS_TOKEN_RIGHT_BRACKET) && !check(parser, VSS_TOKEN_EOF)) {
            consume(parser, VSS_TOKEN_STRING, "Expected string key in map literal.");
            char *key = parse_string_value(parser->previous.start, parser->previous.length);
            
            consume(parser, VSS_TOKEN_COLON, "Expected ':' after key in map entry.");
            VSS_Expr *val = parse_expression(parser);
            
            keys = realloc(keys, sizeof(char*) * (count + 1));
            values = realloc(values, sizeof(VSS_Expr*) * (count + 1));
            keys[count] = key;
            values[count] = val;
            count++;
            
            match(parser, VSS_TOKEN_COMMA);
            while (match(parser, VSS_TOKEN_NEWLINE));
        }
        
        consume(parser, VSS_TOKEN_RIGHT_BRACKET, "Expected ']' at the end of map literal.");
        return vss_expr_new_map(keys, values, count, op.line, op.column);
    }
    
    error_at(parser, &parser->current, "Expected expression.");
    return NULL;
}

static VSS_Stmt *parse_statement(VSS_Parser *parser) {
    if (match(parser, VSS_TOKEN_PARALLEL)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_EACH, "Expected 'each' after 'parallel'.");
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected variable name after 'each'.");
        char *var_name = parse_string_value(parser->previous.start, parser->previous.length);
        consume(parser, VSS_TOKEN_IN, "Expected 'in' after variable name in 'parallel each' loop.");
        VSS_Expr *collection = parse_expression(parser);
        VSS_Block body = parse_block(parser);
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end 'parallel each' loop.");
        VSS_Stmt *stmt = vss_stmt_new_parallel_each(var_name, collection, body, op.line, op.column);
        free(var_name);
        return stmt;
    }

    if (match(parser, VSS_TOKEN_LOCK)) {
        VSS_Token op = parser->previous;
        VSS_Expr *mutex_expr = parse_expression(parser);
        VSS_Block body = parse_block(parser);
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end 'lock' block.");
        return vss_stmt_new_lock(mutex_expr, body, op.line, op.column);
    }

    if (match(parser, VSS_TOKEN_SELECT)) {
        VSS_Token op = parser->previous;
        while (match(parser, VSS_TOKEN_NEWLINE));
        VSS_ChooseCase *cases = NULL;
        size_t count = 0;
        while (match(parser, VSS_TOKEN_CASE)) {
            VSS_Expr *case_expr = parse_expression(parser);
            VSS_Block case_block = parse_block(parser);
            cases = realloc(cases, sizeof(VSS_ChooseCase) * (count + 1));
            cases[count].expr = case_expr;
            cases[count].block = case_block;
            count++;
            while (match(parser, VSS_TOKEN_NEWLINE));
        }
        VSS_Block otherwise_branch = {NULL, 0};
        if (match(parser, VSS_TOKEN_OTHERWISE)) {
            otherwise_branch = parse_block(parser);
        }
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end 'select' block.");
        return vss_stmt_new_select(cases, count, otherwise_branch, op.line, op.column);
    }

    if (match(parser, VSS_TOKEN_NAMESPACE)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected namespace name.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        while (match(parser, VSS_TOKEN_NEWLINE));
        VSS_Block body = parse_block(parser);
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end namespace.");
        return vss_stmt_new_namespace(name, body, op.line, op.column);
    }

    // Variable definition: make
    if (match(parser, VSS_TOKEN_MAKE)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected variable name after 'make'.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        char *type_name = NULL;
        if (match(parser, VSS_TOKEN_COLON)) {
            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected type name after ':'.");
            type_name = parse_string_value(parser->previous.start, parser->previous.length);
        }
        consume_becomes_or_equal(parser, "Expected 'becomes' or '=' after variable name.");
        VSS_Expr *init = parse_expression(parser);
        VSS_Stmt *stmt = vss_stmt_new_make(name, type_name, init, op.line, op.column);
        free(name);
        if (type_name) free(type_name);
        return stmt;
    }
    
    // Constant definition: keep
    if (match(parser, VSS_TOKEN_KEEP) || match(parser, VSS_TOKEN_CONST)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected constant name after 'keep'.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        char *type_name = NULL;
        if (match(parser, VSS_TOKEN_COLON)) {
            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected type name after ':'.");
            type_name = parse_string_value(parser->previous.start, parser->previous.length);
        }
        consume_becomes_or_equal(parser, "Expected 'becomes' or '=' after constant name.");
        VSS_Expr *init = parse_expression(parser);
        VSS_Stmt *stmt = vss_stmt_new_keep(name, type_name, init, op.line, op.column);
        free(name);
        if (type_name) free(type_name);
        return stmt;
    }
    
    // Output: say
    if (match(parser, VSS_TOKEN_SAY)) {
        VSS_Token op = parser->previous;
        VSS_Expr *expr = parse_expression(parser);
        return vss_stmt_new_say(expr, op.line, op.column);
    }
    
    // Return: send
    if (match(parser, VSS_TOKEN_SEND)) {
        VSS_Token op = parser->previous;
        VSS_Expr *expr = parse_expression(parser);
        return vss_stmt_new_send(expr, op.line, op.column);
    }
    
    // Loop control: leave
    if (match(parser, VSS_TOKEN_LEAVE)) {
        return vss_stmt_new_leave(parser->previous.line, parser->previous.column);
    }
    
    // Loop control: skip
    if (match(parser, VSS_TOKEN_SKIP)) {
        return vss_stmt_new_skip(parser->previous.line, parser->previous.column);
    }
    
    // Import: grab
    if (match(parser, VSS_TOKEN_GRAB)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected module name after 'grab'.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        VSS_Stmt *stmt = vss_stmt_new_grab(name, op.line, op.column);
        free(name);
        return stmt;
    }
    
    // File built-ins desugared into call statements
    if (match(parser, VSS_TOKEN_WRITE)) {
        VSS_Token op = parser->previous;
        VSS_Expr *content = parse_expression(parser);
        consume(parser, VSS_TOKEN_INTO, "Expected 'into' after content in 'write' statement.");
        VSS_Expr *path = parse_expression(parser);
        VSS_Expr **args = malloc(sizeof(VSS_Expr*) * 2);
        args[0] = content;
        args[1] = path;
        return vss_stmt_new_expr(vss_expr_new_call(vss_expr_new_name("__write", op.line, op.column), args, 2, op.line, op.column), op.line, op.column);
    }
    if (match(parser, VSS_TOKEN_ADD)) {
        VSS_Token op = parser->previous;
        VSS_Expr *content = parse_expression(parser);
        consume(parser, VSS_TOKEN_INTO, "Expected 'into' after content in 'add' statement.");
        VSS_Expr *path = parse_expression(parser);
        VSS_Expr **args = malloc(sizeof(VSS_Expr*) * 2);
        args[0] = content;
        args[1] = path;
        return vss_stmt_new_expr(vss_expr_new_call(vss_expr_new_name("__add", op.line, op.column), args, 2, op.line, op.column), op.line, op.column);
    }
    if (match(parser, VSS_TOKEN_ERASE)) {
        VSS_Token op = parser->previous;
        VSS_Expr *path = parse_expression(parser);
        VSS_Expr **args = malloc(sizeof(VSS_Expr*));
        args[0] = path;
        return vss_stmt_new_expr(vss_expr_new_call(vss_expr_new_name("__erase", op.line, op.column), args, 1, op.line, op.column), op.line, op.column);
    }
    
    if (match(parser, VSS_TOKEN_ASK)) {
        VSS_Token op = parser->previous;
        VSS_Expr *first = parse_expression(parser);
        VSS_Expr *prompt = NULL;
        VSS_Expr *target = NULL;
        if (match(parser, VSS_TOKEN_INTO)) {
            prompt = first;
            target = parse_expression(parser);
        } else {
            target = first;
        }
        return vss_stmt_new_ask(prompt, target, op.line, op.column);
    }

    // List collection update: put
    if (match(parser, VSS_TOKEN_PUT)) {
        VSS_Token op = parser->previous;
        VSS_Expr *val = parse_expression(parser);
        consume(parser, VSS_TOKEN_INTO, "Expected 'into' after value in 'put' statement.");
        VSS_Expr *list = parse_expression(parser);
        return vss_stmt_new_put(val, list, op.line, op.column);
    }
    
    // Map collection update: set
    if (match(parser, VSS_TOKEN_SET)) {
        VSS_Token op = parser->previous;
        VSS_Expr *target = parse_expression(parser);
        VSS_Expr *map = NULL;
        VSS_Expr *field = NULL;
        if (target->kind == VSS_EXPR_FIELD_ACCESS) {
            map = target->as.field_access.map;
            field = target->as.field_access.field;
        } else if (target->kind == VSS_EXPR_ITEM_ACCESS) {
            map = target->as.item_access.list;
            field = target->as.item_access.index;
        } else {
            error_at(parser, &parser->previous, "Expected map field or item access after 'set'.");
        }
        consume_becomes_or_equal(parser, "Expected 'becomes' or '=' after map target in 'set' statement.");
        VSS_Expr *val = parse_expression(parser);
        free(target);
        return vss_stmt_new_set_field(map, field, val, op.line, op.column);
    }
    
    if (match(parser, VSS_TOKEN_HI)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_HTMVSS, "Expected 'htmvss' after 'hi'.");
        return vss_stmt_new_hi_htmvss(op.line, op.column);
    }
    
    if (match(parser, VSS_TOKEN_BYE)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_HTMVSS, "Expected 'htmvss' after 'bye'.");
        return vss_stmt_new_bye_htmvss(op.line, op.column);
    }
    
    // Conditional: when
    if (match(parser, VSS_TOKEN_WHEN)) {
        VSS_Token op = parser->previous;
        VSS_WhenBranch *branches = NULL;
        size_t count = 0;
        
        VSS_Expr *cond = parse_expression(parser);
        VSS_Block block = parse_block(parser);
        
        branches = realloc(branches, sizeof(VSS_WhenBranch) * (count + 1));
        branches[count].condition = cond;
        branches[count].block = block;
        count++;
        
        while (match(parser, VSS_TOKEN_ORWHEN)) {
            VSS_Expr *ocond = parse_expression(parser);
            VSS_Block oblock = parse_block(parser);
            branches = realloc(branches, sizeof(VSS_WhenBranch) * (count + 1));
            branches[count].condition = ocond;
            branches[count].block = oblock;
            count++;
        }
        
        VSS_Block otherwise_branch = {NULL, 0};
        if (match(parser, VSS_TOKEN_OTHERWISE)) {
            otherwise_branch = parse_block(parser);
        }
        
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end 'when' block.");
        return vss_stmt_new_when(branches, count, otherwise_branch, op.line, op.column);
    }
    
    // Loops: repeat
    if (match(parser, VSS_TOKEN_REPEAT)) {
        VSS_Token op = parser->previous;
        
        if (match(parser, VSS_TOKEN_EACH)) {
            // each loop
            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected variable name after 'each'.");
            char *var_name = parse_string_value(parser->previous.start, parser->previous.length);
            consume(parser, VSS_TOKEN_IN, "Expected 'in' after variable name in 'each' loop.");
            VSS_Expr *collection = parse_expression(parser);
            VSS_Block body = parse_block(parser);
            consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end 'repeat each' loop.");
            VSS_Stmt *stmt = vss_stmt_new_repeat_each(var_name, collection, body, op.line, op.column);
            free(var_name);
            return stmt;
        } else {
            // Check if range loop or count loop
            // Since we need to look ahead without consuming (unless it's an identifier),
            // if current is IDENTIFIER and token after it is THROUGH:
            // But we don't have standard lookahead for two tokens. Wait!
            // We can just parse the next expression. If that expression is a name (VSS_EXPR_NAME) and the current token is VSS_TOKEN_THROUGH:
            // This is super clever! We parse the expression. If it is VSS_EXPR_NAME, and we match VSS_TOKEN_THROUGH, we know it's a range loop!
            // If it's anything else, it's a count loop!
            // Wait, does that work?
            // E.g., `repeat i through 1 to 5` -> first we parse `i` as expression. It returns `VSS_EXPR_NAME` for `i`.
            // Then we see `through`! We match `through`. This is perfect!
            // What if it is `repeat 5 times`? First we parse `5` as expression. It returns `VSS_EXPR_NUMBER` for `5`.
            // The next token is `times`. We do NOT match `through`. So we fall back to count loop!
            // This is absolutely brilliant and doesn't require looking ahead in the token stream at all!
            VSS_Expr *first_expr = parse_expression(parser);
            if (first_expr->kind == VSS_EXPR_NAME && match(parser, VSS_TOKEN_THROUGH)) {
                char *var_name = safe_strdup(first_expr->as.name);
                vss_expr_free(first_expr);
                
                VSS_Expr *start = parse_expression(parser);
                consume(parser, VSS_TOKEN_TO, "Expected 'to' in range loop.");
                VSS_Expr *end = parse_expression(parser);
                VSS_Block body = parse_block(parser);
                consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end range loop.");
                VSS_Stmt *stmt = vss_stmt_new_repeat_range(var_name, start, end, body, op.line, op.column);
                free(var_name);
                return stmt;
            } else {
                consume(parser, VSS_TOKEN_TIMES, "Expected 'times' after count expression in repeat loop.");
                VSS_Block body = parse_block(parser);
                consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end repeat loop.");
                return vss_stmt_new_repeat_count(first_expr, body, op.line, op.column);
            }
        }
    }
    
    // Loops: during
    if (match(parser, VSS_TOKEN_DURING)) {
        VSS_Token op = parser->previous;
        VSS_Expr *cond = parse_expression(parser);
        VSS_Block body = parse_block(parser);
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end 'during' loop.");
        return vss_stmt_new_during(cond, body, op.line, op.column);
    }
    
    // Task Definition: task, async task, coroutine task
    bool is_coroutine = false;
    bool is_async = false;
    VSS_Token op;
    bool matched_task = false;
    
    if (match(parser, VSS_TOKEN_COROUTINE)) {
        op = parser->previous;
        consume(parser, VSS_TOKEN_TASK, "Expected 'task' after 'coroutine'.");
        is_coroutine = true;
        matched_task = true;
    } else if (match(parser, VSS_TOKEN_ASYNC)) {
        op = parser->previous;
        consume(parser, VSS_TOKEN_TASK, "Expected 'task' after 'async'.");
        is_async = true;
        matched_task = true;
    } else if (match(parser, VSS_TOKEN_TASK)) {
        op = parser->previous;
        matched_task = true;
    }
    
    if (matched_task) {
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected task name.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        
        char **params = NULL;
        size_t count = 0;
        if (match(parser, VSS_TOKEN_NEEDS)) {
            while (is_identifier_like(parser->current.type)) {
                advance(parser);
                char *p = parse_string_value(parser->previous.start, parser->previous.length);
                params = realloc(params, sizeof(char*) * (count + 1));
                params[count++] = p;
                
                if (match(parser, VSS_TOKEN_COLON)) {
                    if (is_identifier_like(parser->current.type)) advance(parser);
                }
                match(parser, VSS_TOKEN_COMMA);
            }
        }
        
        if (match(parser, VSS_TOKEN_ARROW)) {
            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected return type name after '->'.");
        }
        
        VSS_Block body = parse_block(parser);
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end task definition.");
        VSS_Stmt *stmt = vss_stmt_new_task(name, params, count, body, op.line, op.column);
        stmt->as.task.is_coroutine = is_coroutine;
        stmt->as.task.is_async = is_async;
        free(name);
        return stmt;
    }
    
    // Error Handling: attempt
    if (match(parser, VSS_TOKEN_ATTEMPT)) {
        VSS_Token op = parser->previous;
        VSS_Block try_body = parse_block(parser);
        consume(parser, VSS_TOKEN_RESCUE, "Expected 'rescue' after 'attempt' block.");
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected problem variable name after 'rescue'.");
        char *prob_var = parse_string_value(parser->previous.start, parser->previous.length);
        VSS_Block rescue_body = parse_block(parser);
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end 'attempt' block.");
        VSS_Stmt *stmt = vss_stmt_new_attempt(try_body, prob_var, rescue_body, op.line, op.column);
        free(prob_var);
        return stmt;
    }
    
    // Choose/Match: choose / match
    if (match(parser, VSS_TOKEN_CHOOSE) || match(parser, VSS_TOKEN_MATCH)) {
        VSS_Token op = parser->previous;
        VSS_Expr *expr = parse_expression(parser);
        
        while (match(parser, VSS_TOKEN_NEWLINE));
        
        VSS_ChooseCase *cases = NULL;
        size_t count = 0;
        
        while (match(parser, VSS_TOKEN_CASE)) {
            VSS_Expr *case_expr = parse_expression(parser);
            VSS_Block case_block;
            
            if (match(parser, VSS_TOKEN_ARROW)) {
                if (check(parser, VSS_TOKEN_NEWLINE)) {
                    case_block = parse_block(parser);
                } else {
                    VSS_Stmt *stmt = parse_statement(parser);
                    VSS_Stmt **stmts = malloc(sizeof(VSS_Stmt*));
                    stmts[0] = stmt;
                    case_block.statements = stmts;
                    case_block.count = 1;
                }
            } else {
                case_block = parse_block(parser);
            }
            
            cases = realloc(cases, sizeof(VSS_ChooseCase) * (count + 1));
            cases[count].expr = case_expr;
            cases[count].block = case_block;
            count++;
            while (match(parser, VSS_TOKEN_NEWLINE));
        }
        
        VSS_Block otherwise_branch = {NULL, 0};
        if (match(parser, VSS_TOKEN_OTHERWISE) || match(parser, VSS_TOKEN_ARROW)) {
            // Note: in case they write otherwise -> ...
            otherwise_branch = parse_block(parser);
        }
        
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end block.");
        return vss_stmt_new_choose(expr, cases, count, otherwise_branch, op.line, op.column);
    }
    
    // Yield: yield
    if (match(parser, VSS_TOKEN_YIELD)) {
        VSS_Token op = parser->previous;
        VSS_Expr *expr = NULL;
        if (!check(parser, VSS_TOKEN_NEWLINE) && !check(parser, VSS_TOKEN_FINISH) && !check(parser, VSS_TOKEN_EOF)) {
            expr = parse_expression(parser);
        }
        return vss_stmt_new_yield(expr, op.line, op.column);
    }
    
    // Field: field
    if (match(parser, VSS_TOKEN_FIELD)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected field name after 'field'.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        char *type_name = NULL;
        if (match(parser, VSS_TOKEN_COLON)) {
            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected type name after ':'.");
            type_name = parse_string_value(parser->previous.start, parser->previous.length);
        }
        VSS_Expr *default_val = NULL;
        if (match(parser, VSS_TOKEN_BECOMES) || match(parser, VSS_TOKEN_EQUAL)) {
            default_val = parse_expression(parser);
        }
        VSS_Stmt *stmt = vss_stmt_new_field(name, type_name, default_val, op.line, op.column);
        free(name);
        if (type_name) free(type_name);
        return stmt;
    }
    
    // Shape: shape
    if (match(parser, VSS_TOKEN_SHAPE)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected shape name after 'shape'.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        while (match(parser, VSS_TOKEN_NEWLINE));
        
        VSS_Stmt **members = NULL;
        size_t member_count = 0;
        
        while (!check(parser, VSS_TOKEN_FINISH) && !check(parser, VSS_TOKEN_EOF)) {
            VSS_Stmt *m = parse_statement(parser);
            if (m) {
                members = realloc(members, sizeof(VSS_Stmt*) * (member_count + 1));
                members[member_count++] = m;
            }
            while (match(parser, VSS_TOKEN_NEWLINE));
        }
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end shape declaration.");
        return vss_stmt_new_shape(name, members, member_count, op.line, op.column);
    }
    
    // Choices: choices
    if (match(parser, VSS_TOKEN_CHOICES)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected enum name after 'choices'.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        
        while (match(parser, VSS_TOKEN_NEWLINE));
        
        char **members = NULL;
        size_t count = 0;
        
        while (!check(parser, VSS_TOKEN_FINISH) && !check(parser, VSS_TOKEN_EOF)) {
            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected enum member name.");
            char *member = parse_string_value(parser->previous.start, parser->previous.length);
            members = realloc(members, sizeof(char*) * (count + 1));
            members[count++] = member;
            
            while (match(parser, VSS_TOKEN_NEWLINE));
        }
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end enum declaration.");
        return vss_stmt_new_choices(name, members, count, op.line, op.column);
    }

    // Interface/Blueprint: interface / blueprint
    if (match(parser, VSS_TOKEN_INTERFACE) || match(parser, VSS_TOKEN_BLUEPRINT) || match(parser, VSS_TOKEN_TRAIT)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected interface/blueprint name.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        while (match(parser, VSS_TOKEN_NEWLINE));
        VSS_Stmt **task_decls = NULL;
        size_t count = 0;
        while (match(parser, VSS_TOKEN_TASK)) {
            VSS_Token task_op = parser->previous;
            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected task name in interface.");
            char *task_name = parse_string_value(parser->previous.start, parser->previous.length);
            char **params = NULL;
            size_t param_count = 0;
            if (match(parser, VSS_TOKEN_NEEDS)) {
                while (check(parser, VSS_TOKEN_IDENTIFIER)) {
                    consume(parser, VSS_TOKEN_IDENTIFIER, "Expected parameter name.");
                    char *p = parse_string_value(parser->previous.start, parser->previous.length);
                    params = realloc(params, sizeof(char*) * (param_count + 1));
                    params[param_count++] = p;
                    
                    if (match(parser, VSS_TOKEN_COLON)) {
                        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected type name after ':'.");
                    }
                    match(parser, VSS_TOKEN_COMMA);
                }
            }
            // Also parse optional arrow / return type: e.g. '-> number'
            if (match(parser, VSS_TOKEN_ARROW)) {
                consume(parser, VSS_TOKEN_IDENTIFIER, "Expected return type name after '->'.");
            }
            VSS_Block empty_body = {NULL, 0};
            VSS_Stmt *task_decl = vss_stmt_new_task(task_name, params, param_count, empty_body, task_op.line, task_op.column);
            free(task_name);
            task_decls = realloc(task_decls, sizeof(VSS_Stmt*) * (count + 1));
            task_decls[count++] = task_decl;
            while (match(parser, VSS_TOKEN_NEWLINE));
        }
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end interface declaration.");
        return vss_stmt_new_interface(name, task_decls, count, op.line, op.column);
    }

    if (check(parser, VSS_TOKEN_IDENTIFIER)) {
        VSS_Lexer temp = *parser->lexer;
        VSS_Token next = vss_lexer_next(&temp);
        while (next.type == VSS_TOKEN_NEWLINE) {
            next = vss_lexer_next(&temp);
        }
        if (next.type == VSS_TOKEN_TASK) {
            advance(parser);
            char *name = parse_string_value(parser->previous.start, parser->previous.length);
            while (match(parser, VSS_TOKEN_NEWLINE));
            VSS_Stmt **task_decls = NULL;
            size_t count = 0;
            while (match(parser, VSS_TOKEN_TASK)) {
                VSS_Token task_op = parser->previous;
                consume(parser, VSS_TOKEN_IDENTIFIER, "Expected task name in interface.");
                char *task_name = parse_string_value(parser->previous.start, parser->previous.length);
                char **params = NULL;
                size_t param_count = 0;
                if (match(parser, VSS_TOKEN_NEEDS)) {
                    while (check(parser, VSS_TOKEN_IDENTIFIER)) {
                        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected parameter name.");
                        char *p = parse_string_value(parser->previous.start, parser->previous.length);
                        params = realloc(params, sizeof(char*) * (param_count + 1));
                        params[param_count++] = p;
                        
                        if (match(parser, VSS_TOKEN_COLON)) {
                            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected type name after ':'.");
                        }
                        match(parser, VSS_TOKEN_COMMA);
                    }
                }
                if (match(parser, VSS_TOKEN_ARROW)) {
                    consume(parser, VSS_TOKEN_IDENTIFIER, "Expected return type name after '->'.");
                }
                VSS_Block empty_body = {NULL, 0};
                VSS_Stmt *task_decl = vss_stmt_new_task(task_name, params, param_count, empty_body, task_op.line, task_op.column);
                free(task_name);
                task_decls = realloc(task_decls, sizeof(VSS_Stmt*) * (count + 1));
                task_decls[count++] = task_decl;
                while (match(parser, VSS_TOKEN_NEWLINE));
            }
            consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end interface declaration.");
            return vss_stmt_new_interface(name, task_decls, count, parser->previous.line, parser->previous.column);
        }
    }

    // Object: object
    if (match(parser, VSS_TOKEN_OBJECT)) {
        VSS_Token op = parser->previous;
        consume(parser, VSS_TOKEN_IDENTIFIER, "Expected object name.");
        char *name = parse_string_value(parser->previous.start, parser->previous.length);
        
        char *parent_name = NULL;
        if (match(parser, VSS_TOKEN_EXTENDS)) {
            consume(parser, VSS_TOKEN_IDENTIFIER, "Expected parent object name after 'extends'.");
            parent_name = parse_string_value(parser->previous.start, parser->previous.length);
        }
        
        char **interfaces = NULL;
        size_t interface_count = 0;
        if (match(parser, VSS_TOKEN_IMPLEMENTS)) {
            do {
                consume(parser, VSS_TOKEN_IDENTIFIER, "Expected interface name after 'implements'.");
                char *iface = parse_string_value(parser->previous.start, parser->previous.length);
                interfaces = realloc(interfaces, sizeof(char*) * (interface_count + 1));
                interfaces[interface_count++] = iface;
            } while (match(parser, VSS_TOKEN_COMMA));
        }
        
        while (match(parser, VSS_TOKEN_NEWLINE));
        
        VSS_Stmt **members = NULL;
        size_t member_count = 0;
        
        while (!check(parser, VSS_TOKEN_FINISH) && !check(parser, VSS_TOKEN_EOF)) {
            VSS_Stmt *m = parse_statement(parser);
            if (m) {
                members = realloc(members, sizeof(VSS_Stmt*) * (member_count + 1));
                members[member_count++] = m;
            }
            while (match(parser, VSS_TOKEN_NEWLINE));
        }
        consume(parser, VSS_TOKEN_FINISH, "Expected 'finish' to end object declaration.");
        return vss_stmt_new_object(name, parent_name, interfaces, interface_count, members, member_count, op.line, op.column);
    }

    // Assignment or Expression Statement
    VSS_Expr *expr = parse_expression(parser);
    if (match_becomes_or_equal(parser)) {
        VSS_Expr *val = parse_expression(parser);
        if (expr->kind == VSS_EXPR_NAME) {
            char *name = safe_strdup(expr->as.name);
            int line = expr->line;
            int col = expr->column;
            vss_expr_free(expr);
            return vss_stmt_new_assign(name, val, line, col);
        } else if (expr->kind == VSS_EXPR_FIELD_ACCESS) {
            VSS_Expr *map = expr->as.field_access.map;
            VSS_Expr *field = expr->as.field_access.field;
            int line = expr->line;
            int col = expr->column;
            expr->as.field_access.map = NULL;
            expr->as.field_access.field = NULL;
            vss_expr_free(expr);
            return vss_stmt_new_set_field(map, field, val, line, col);
        } else if (expr->kind == VSS_EXPR_ITEM_ACCESS) {
            VSS_Expr *list = expr->as.item_access.list;
            VSS_Expr *index = expr->as.item_access.index;
            int line = expr->line;
            int col = expr->column;
            expr->as.item_access.list = NULL;
            expr->as.item_access.index = NULL;
            vss_expr_free(expr);
            return vss_stmt_new_set_item(list, index, val, line, col);
        } else {
            error_at(parser, &parser->previous, "Invalid assignment target.");
            vss_expr_free(expr);
            vss_expr_free(val);
            return NULL;
        }
    }
    
    return vss_stmt_new_expr(expr, expr->line, expr->column);
}

void vss_parser_init(VSS_Parser *parser, VSS_Lexer *lexer) {
    parser->lexer = lexer;
    parser->had_error = false;
    parser->panic_mode = false;
    advance(parser); // Populate current token
}

static void synchronize(VSS_Parser *parser) {
    parser->panic_mode = false;
    while (parser->current.type != VSS_TOKEN_EOF) {
        if (parser->previous.type == VSS_TOKEN_NEWLINE) return;
        switch (parser->current.type) {
            case VSS_TOKEN_SAY:
            case VSS_TOKEN_MAKE:
            case VSS_TOKEN_KEEP:
            case VSS_TOKEN_WHEN:
            case VSS_TOKEN_REPEAT:
            case VSS_TOKEN_DURING:
            case VSS_TOKEN_TASK:
            case VSS_TOKEN_CHOOSE:
            case VSS_TOKEN_ATTEMPT:
            case VSS_TOKEN_GRAB:
            case VSS_TOKEN_OBJECT:
            case VSS_TOKEN_CHOICES:
            case VSS_TOKEN_INTERFACE:
                return;
            default:
                break;
        }
        advance(parser);
    }
}

VSS_Block vss_parse_program(VSS_Parser *parser) {
    VSS_Stmt **statements = NULL;
    size_t count = 0;
    
    while (match(parser, VSS_TOKEN_NEWLINE));
    
    while (!check(parser, VSS_TOKEN_EOF)) {
        VSS_Stmt *stmt = parse_statement(parser);
        if (stmt) {
            statements = realloc(statements, sizeof(VSS_Stmt*) * (count + 1));
            statements[count++] = stmt;
        } else {
            synchronize(parser);
        }
        
        if (check(parser, VSS_TOKEN_EOF)) break;
        
        // Statements must end with newlines
        if (!match(parser, VSS_TOKEN_NEWLINE)) {
            error_at(parser, &parser->current, "Expected newline after statement.");
            // Simple recovery: consume until newline or EOF
            while (!is_newline_or_eof(parser)) {
                advance(parser);
            }
            if (check(parser, VSS_TOKEN_NEWLINE)) advance(parser);
        }
        
        while (match(parser, VSS_TOKEN_NEWLINE));
        parser->panic_mode = false; // Reset panic mode at statement boundary
    }
    
    VSS_Block b;
    b.statements = statements;
    b.count = count;
    return b;
}
