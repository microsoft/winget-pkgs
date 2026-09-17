#ifndef VSS_PARSER_H
#define VSS_PARSER_H

#include "lexer.h"
#include "ast.h"

typedef struct {
    VSS_Lexer *lexer;
    VSS_Token current;
    VSS_Token previous;
    bool had_error;
    bool panic_mode;
} VSS_Parser;

void vss_parser_init(VSS_Parser *parser, VSS_Lexer *lexer);
VSS_Block vss_parse_program(VSS_Parser *parser);

#endif
