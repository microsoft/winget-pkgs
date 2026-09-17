#include <ctype.h>
#include <string.h>

#include "lexer.h"

static bool is_at_end(VSS_Lexer *lexer) {
    return *lexer->current == '\0';
}

static char advance_char(VSS_Lexer *lexer) {
    char c = *lexer->current;
    lexer->current++;
    lexer->column++;
    return c;
}

static char peek_char(VSS_Lexer *lexer) {
    return *lexer->current;
}

static char peek_next_char(VSS_Lexer *lexer) {
    if (is_at_end(lexer)) {
        return '\0';
    }
    return lexer->current[1];
}

static VSS_Token make_token(VSS_Lexer *lexer, VSS_TokenType type) {
    VSS_Token token;
    token.type = type;
    token.start = lexer->start;
    token.length = (size_t)(lexer->current - lexer->start);
    token.line = lexer->line;
    token.column = lexer->token_column;
    return token;
}

static VSS_Token error_token(VSS_Lexer *lexer, const char *message) {
    VSS_Token token;
    token.type = VSS_TOKEN_ERROR;
    token.start = message;
    token.length = strlen(message);
    token.line = lexer->line;
    token.column = lexer->token_column;
    return token;
}

static void skip_spaces(VSS_Lexer *lexer) {
    for (;;) {
        char c = peek_char(lexer);
        if (c == ' ' || c == '\t' || c == '\r') {
            advance_char(lexer);
        } else {
            break;
        }
    }
}

static bool is_name_start(char c) {
    return isalpha((unsigned char)c) || c == '_';
}

static bool is_name_part(char c) {
    return isalnum((unsigned char)c) || c == '_';
}

static VSS_TokenType keyword_type(const char *start, size_t length) {
    struct KeywordEntry {
        const char *text;
        VSS_TokenType type;
    };

    static const struct KeywordEntry keywords[] = {
        {"say", VSS_TOKEN_SAY},
        {"make", VSS_TOKEN_MAKE},
        {"keep", VSS_TOKEN_KEEP},
        {"becomes", VSS_TOKEN_BECOMES},
        {"when", VSS_TOKEN_WHEN},
        {"orwhen", VSS_TOKEN_ORWHEN},
        {"otherwise", VSS_TOKEN_OTHERWISE},
        {"finish", VSS_TOKEN_FINISH},
        {"repeat", VSS_TOKEN_REPEAT},
        {"times", VSS_TOKEN_TIMES},
        {"through", VSS_TOKEN_THROUGH},
        {"to", VSS_TOKEN_TO},
        {"each", VSS_TOKEN_EACH},
        {"in", VSS_TOKEN_IN},
        {"during", VSS_TOKEN_DURING},
        {"leave", VSS_TOKEN_LEAVE},
        {"skip", VSS_TOKEN_SKIP},
        {"task", VSS_TOKEN_TASK},
        {"needs", VSS_TOKEN_NEEDS},
        {"send", VSS_TOKEN_SEND},
        {"with", VSS_TOKEN_WITH},
        {"yes", VSS_TOKEN_YES},
        {"no", VSS_TOKEN_NO},
        {"empty", VSS_TOKEN_EMPTY},
        {"and", VSS_TOKEN_AND},
        {"or", VSS_TOKEN_OR},
        {"not", VSS_TOKEN_NOT},
        {"above", VSS_TOKEN_ABOVE},
        {"below", VSS_TOKEN_BELOW},
        {"at_least", VSS_TOKEN_AT_LEAST},
        {"at_most", VSS_TOKEN_AT_MOST},
        {"same_as", VSS_TOKEN_SAME_AS},
        {"not_same_as", VSS_TOKEN_NOT_SAME_AS},
        {"item", VSS_TOKEN_ITEM},
        {"field", VSS_TOKEN_FIELD},
        {"put", VSS_TOKEN_PUT},
        {"into", VSS_TOKEN_INTO},
        {"map", VSS_TOKEN_MAP},
        {"set", VSS_TOKEN_SET},
        {"grab", VSS_TOKEN_GRAB},
        {"attempt", VSS_TOKEN_ATTEMPT},
        {"rescue", VSS_TOKEN_RESCUE},
        {"read", VSS_TOKEN_READ},
        {"write", VSS_TOKEN_WRITE},
        {"add", VSS_TOKEN_ADD},
        {"erase", VSS_TOKEN_ERASE},
        {"exists", VSS_TOKEN_EXISTS},
        {"size", VSS_TOKEN_SIZE},
        {"of", VSS_TOKEN_OF},
        {"choose", VSS_TOKEN_CHOOSE},
        {"case", VSS_TOKEN_CASE},
        {"note", VSS_TOKEN_NOTE},
        {"hi", VSS_TOKEN_HI},
        {"bye", VSS_TOKEN_BYE},
        {"htmvss", VSS_TOKEN_HTMVSS},
        {"object", VSS_TOKEN_OBJECT},
        {"mine", VSS_TOKEN_MINE},
        {"extends", VSS_TOKEN_EXTENDS},
        {"implements", VSS_TOKEN_IMPLEMENTS},
        {"choices", VSS_TOKEN_CHOICES},
        {"interface", VSS_TOKEN_INTERFACE},
        {"parent", VSS_TOKEN_PARENT},
        {"shape", VSS_TOKEN_SHAPE},
        {"blueprint", VSS_TOKEN_BLUEPRINT},
        {"match", VSS_TOKEN_MATCH},
        {"async", VSS_TOKEN_ASYNC},
        {"await", VSS_TOKEN_AWAIT},
        {"yield", VSS_TOKEN_YIELD},
        {"coroutine", VSS_TOKEN_COROUTINE},
        {"const", VSS_TOKEN_CONST},
        {"trait", VSS_TOKEN_TRAIT},
        {"namespace", VSS_TOKEN_NAMESPACE},
        {"thread", VSS_TOKEN_THREAD},
        {"lock", VSS_TOKEN_LOCK},
        {"unlock", VSS_TOKEN_UNLOCK},
        {"ask", VSS_TOKEN_ASK},
        {"start", VSS_TOKEN_START},
        {"parallel", VSS_TOKEN_PARALLEL},
        {"timeout", VSS_TOKEN_TIMEOUT},
        {"select", VSS_TOKEN_SELECT}
    };

    size_t count = sizeof(keywords) / sizeof(keywords[0]);
    for (size_t i = 0; i < count; i++) {
        if (strlen(keywords[i].text) == length && strncmp(keywords[i].text, start, length) == 0) {
            return keywords[i].type;
        }
    }
    return VSS_TOKEN_IDENTIFIER;
}

static VSS_Token identifier(VSS_Lexer *lexer) {
    while (is_name_part(peek_char(lexer))) {
        advance_char(lexer);
    }

    VSS_TokenType type = keyword_type(lexer->start, (size_t)(lexer->current - lexer->start));
    return make_token(lexer, type);
}

static VSS_Token number(VSS_Lexer *lexer) {
    while (isdigit((unsigned char)peek_char(lexer))) {
        advance_char(lexer);
    }

    if (peek_char(lexer) == '.' && isdigit((unsigned char)peek_next_char(lexer))) {
        advance_char(lexer);
        while (isdigit((unsigned char)peek_char(lexer))) {
            advance_char(lexer);
        }
    }

    return make_token(lexer, VSS_TOKEN_NUMBER);
}

static VSS_Token string(VSS_Lexer *lexer) {
    while (!is_at_end(lexer) && peek_char(lexer) != '"') {
        if (peek_char(lexer) == '\n') {
            lexer->line++;
            lexer->column = 1;
        }
        if (peek_char(lexer) == '\\' && peek_next_char(lexer) != '\0') {
            advance_char(lexer);
        }
        advance_char(lexer);
    }

    if (is_at_end(lexer)) {
        return error_token(lexer, "Unterminated string.");
    }

    advance_char(lexer);
    return make_token(lexer, VSS_TOKEN_STRING);
}

extern VSS_THREAD_LOCAL const char *vss_current_source;
void vss_lexer_init(VSS_Lexer *lexer, const char *source) {
    vss_current_source = source;
    lexer->source = source;
    lexer->start = source;
    lexer->current = source;
    lexer->line = 1;
    lexer->column = 1;
    lexer->token_column = 1;
}

VSS_Token vss_lexer_next(VSS_Lexer *lexer) {
    skip_spaces(lexer);
    lexer->start = lexer->current;
    lexer->token_column = lexer->column;

    if (is_at_end(lexer)) {
        return make_token(lexer, VSS_TOKEN_EOF);
    }

    char c = advance_char(lexer);

    if (c == '\n') {
        VSS_Token token = make_token(lexer, VSS_TOKEN_NEWLINE);
        lexer->line++;
        lexer->column = 1;
        return token;
    }

    if (is_name_start(c)) {
        VSS_Token t = identifier(lexer);
        if (t.type == VSS_TOKEN_NOTE) {
            while (!is_at_end(lexer) && peek_char(lexer) != '\n') {
                advance_char(lexer);
            }
            return vss_lexer_next(lexer);
        }
        return t;
    }

    if (isdigit((unsigned char)c)) {
        return number(lexer);
    }

    switch (c) {
        case '"': return string(lexer);
        case '+': return make_token(lexer, VSS_TOKEN_PLUS);
        case '-':
            if (peek_char(lexer) == '>') {
                advance_char(lexer);
                return make_token(lexer, VSS_TOKEN_ARROW);
            }
            return make_token(lexer, VSS_TOKEN_MINUS);
        case '*': return make_token(lexer, VSS_TOKEN_STAR);
        case '/': return make_token(lexer, VSS_TOKEN_SLASH);
        case '%': return make_token(lexer, VSS_TOKEN_PERCENT);
        case '[': return make_token(lexer, VSS_TOKEN_LEFT_BRACKET);
        case ']': return make_token(lexer, VSS_TOKEN_RIGHT_BRACKET);
        case '{': return make_token(lexer, VSS_TOKEN_LEFT_BRACE);
        case '}': return make_token(lexer, VSS_TOKEN_RIGHT_BRACE);
        case ',': return make_token(lexer, VSS_TOKEN_COMMA);
        case ':': return make_token(lexer, VSS_TOKEN_COLON);
        case '.': return make_token(lexer, VSS_TOKEN_DOT);
        case '(': return make_token(lexer, VSS_TOKEN_LEFT_PAREN);
        case ')': return make_token(lexer, VSS_TOKEN_RIGHT_PAREN);
        case '<':
            if (peek_char(lexer) == '=') {
                advance_char(lexer);
                return error_token(lexer, "Unexpected '<='. In VSS, use 'at_most'.");
            }
            return error_token(lexer, "Unexpected '<'. In VSS, use 'below'.");
        case '>':
            if (peek_char(lexer) == '=') {
                advance_char(lexer);
                return error_token(lexer, "Unexpected '>='. In VSS, use 'at_least'.");
            }
            return error_token(lexer, "Unexpected '>'. In VSS, use 'above'.");
        case '!':
            if (peek_char(lexer) == '=') {
                advance_char(lexer);
                return error_token(lexer, "Unexpected '!='. In VSS, use 'not_same_as'.");
            }
            return error_token(lexer, "Unexpected '!'. In VSS, use 'not'.");
        case '=':
            if (peek_char(lexer) == '=') {
                advance_char(lexer);
                return error_token(lexer, "Unexpected '=='. In VSS, use 'same_as'.");
            }
            return make_token(lexer, VSS_TOKEN_EQUAL);
        case '#': {
            if (peek_char(lexer) == '#' && peek_next_char(lexer) == '#') {
                // Consume the other two '#'
                advance_char(lexer);
                advance_char(lexer);
                // Scan until closing "###"
                while (!is_at_end(lexer)) {
                    if (peek_char(lexer) == '#' && peek_next_char(lexer) == '#') {
                        if (lexer->current[2] == '#') {
                            // Found closing "###"
                            advance_char(lexer);
                            advance_char(lexer);
                            advance_char(lexer);
                            break;
                        }
                    }
                    if (peek_char(lexer) == '\n') {
                        lexer->line++;
                        lexer->column = 1;
                    }
                    advance_char(lexer);
                }
                return vss_lexer_next(lexer);
            }
            return error_token(lexer, "Unexpected character '#'.");
        }
        default: return error_token(lexer, "Unexpected character.");
    }
}
