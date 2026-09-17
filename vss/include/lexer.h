#ifndef VSS_LEXER_H
#define VSS_LEXER_H

#include "token.h"

typedef struct {
    const char *source;
    const char *start;
    const char *current;
    int line;
    int column;
    int token_column;
} VSS_Lexer;

void vss_lexer_init(VSS_Lexer *lexer, const char *source);
VSS_Token vss_lexer_next(VSS_Lexer *lexer);

#endif
