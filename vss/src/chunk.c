#include <stdio.h>
#include <stdlib.h>
#include "chunk.h"
#include "object.h"

void vss_chunk_init(VSS_Chunk *chunk) {
    chunk->code = NULL;
    chunk->lines = NULL;
    chunk->count = 0;
    chunk->capacity = 0;
    chunk->constants = NULL;
    chunk->const_count = 0;
    chunk->const_capacity = 0;
}

void vss_chunk_free(VSS_Chunk *chunk) {
    free(chunk->code);
    free(chunk->lines);
    for (int i = 0; i < chunk->const_count; i++) {
        vss_value_release(chunk->constants[i]);
    }
    free(chunk->constants);
    vss_chunk_init(chunk);
}

void vss_chunk_write(VSS_Chunk *chunk, uint8_t byte, int line) {
    if (chunk->count >= chunk->capacity) {
        chunk->capacity = chunk->capacity < 8 ? 8 : chunk->capacity * 2;
        chunk->code = realloc(chunk->code, chunk->capacity);
        chunk->lines = realloc(chunk->lines, chunk->capacity * sizeof(int));
    }
    chunk->code[chunk->count] = byte;
    chunk->lines[chunk->count] = line;
    chunk->count++;
}

int vss_chunk_add_constant(VSS_Chunk *chunk, VSS_Value value) {
    // Retain the constant value
    vss_value_retain(value);
    
    if (chunk->const_count >= chunk->const_capacity) {
        chunk->const_capacity = chunk->const_capacity < 8 ? 8 : chunk->const_capacity * 2;
        chunk->constants = realloc(chunk->constants, chunk->const_capacity * sizeof(VSS_Value));
    }
    chunk->constants[chunk->const_count] = value;
    return chunk->const_count++;
}

void vss_disassemble_chunk(VSS_Chunk *chunk, const char *name) {
    printf("== %s ==\n", name);
    for (int offset = 0; offset < chunk->count;) {
        offset = vss_disassemble_instruction(chunk, offset);
    }
}

static int simple_instruction(const char *name, int offset) {
    printf("%s\n", name);
    return offset + 1;
}

static int constant_instruction(const char *name, VSS_Chunk *chunk, int offset) {
    uint8_t constant = chunk->code[offset + 1];
    printf("%-16s %4d '", name, constant);
    vss_value_say(chunk->constants[constant]);
    printf("'\n");
    return offset + 2;
}

static int byte_instruction(const char *name, VSS_Chunk *chunk, int offset) {
    uint8_t slot = chunk->code[offset + 1];
    printf("%-16s %4d\n", name, slot);
    return offset + 2;
}

static int jump_instruction(const char *name, int sign, VSS_Chunk *chunk, int offset) {
    uint16_t jump = (uint16_t)(chunk->code[offset + 1] << 8);
    jump |= chunk->code[offset + 2];
    printf("%-16s %4d -> %d\n", name, offset, offset + 3 + sign * jump);
    return offset + 3;
}

static int global_define_instruction(const char *name, VSS_Chunk *chunk, int offset) {
    uint8_t constant = chunk->code[offset + 1];
    uint8_t is_const = chunk->code[offset + 2];
    printf("%-16s %4d '", name, constant);
    vss_value_say(chunk->constants[constant]);
    printf("' (const: %s)\n", is_const ? "yes" : "no");
    return offset + 3;
}

int vss_disassemble_instruction(VSS_Chunk *chunk, int offset) {
    printf("%04d ", offset);
    if (offset > 0 && chunk->lines[offset] == chunk->lines[offset - 1]) {
        printf("   | ");
    } else {
        printf("%4d ", chunk->lines[offset]);
    }

    uint8_t instruction = chunk->code[offset];
    switch (instruction) {
        case VSS_OP_CONSTANT:
            return constant_instruction("VSS_OP_CONSTANT", chunk, offset);
        case VSS_OP_CONSTANT_LONG: {
            uint32_t constant = chunk->code[offset + 1] |
                                (chunk->code[offset + 2] << 8) |
                                (chunk->code[offset + 3] << 16);
            printf("%-16s %4d '", "VSS_OP_CONSTANT_LONG", constant);
            vss_value_say(chunk->constants[constant]);
            printf("'\n");
            return offset + 4;
        }
        case VSS_OP_EMPTY:
            return simple_instruction("VSS_OP_EMPTY", offset);
        case VSS_OP_TRUE:
            return simple_instruction("VSS_OP_TRUE", offset);
        case VSS_OP_FALSE:
            return simple_instruction("VSS_OP_FALSE", offset);
        case VSS_OP_POP:
            return simple_instruction("VSS_OP_POP", offset);
        case VSS_OP_GET_LOCAL:
            return byte_instruction("VSS_OP_GET_LOCAL", chunk, offset);
        case VSS_OP_SET_LOCAL:
            return byte_instruction("VSS_OP_SET_LOCAL", chunk, offset);
        case VSS_OP_GET_GLOBAL:
            return constant_instruction("VSS_OP_GET_GLOBAL", chunk, offset);
        case VSS_OP_DEFINE_GLOBAL:
            return global_define_instruction("VSS_OP_DEFINE_GLOBAL", chunk, offset);
        case VSS_OP_SET_GLOBAL:
            return constant_instruction("VSS_OP_SET_GLOBAL", chunk, offset);
        case VSS_OP_GET_UPVALUE:
            return byte_instruction("VSS_OP_GET_UPVALUE", chunk, offset);
        case VSS_OP_SET_UPVALUE:
            return byte_instruction("VSS_OP_SET_UPVALUE", chunk, offset);
        case VSS_OP_ADD:
            return simple_instruction("VSS_OP_ADD", offset);
        case VSS_OP_SUB:
            return simple_instruction("VSS_OP_SUB", offset);
        case VSS_OP_MUL:
            return simple_instruction("VSS_OP_MUL", offset);
        case VSS_OP_DIV:
            return simple_instruction("VSS_OP_DIV", offset);
        case VSS_OP_MOD:
            return simple_instruction("VSS_OP_MOD", offset);
        case VSS_OP_NOT:
            return simple_instruction("VSS_OP_NOT", offset);
        case VSS_OP_NEGATE:
            return simple_instruction("VSS_OP_NEGATE", offset);
        case VSS_OP_ABOVE:
            return simple_instruction("VSS_OP_ABOVE", offset);
        case VSS_OP_BELOW:
            return simple_instruction("VSS_OP_BELOW", offset);
        case VSS_OP_AT_LEAST:
            return simple_instruction("VSS_OP_AT_LEAST", offset);
        case VSS_OP_AT_MOST:
            return simple_instruction("VSS_OP_AT_MOST", offset);
        case VSS_OP_SAME_AS:
            return simple_instruction("VSS_OP_SAME_AS", offset);
        case VSS_OP_NOT_SAME_AS:
            return simple_instruction("VSS_OP_NOT_SAME_AS", offset);
        case VSS_OP_SAY:
            return simple_instruction("VSS_OP_SAY", offset);
        case VSS_OP_JUMP:
            return jump_instruction("VSS_OP_JUMP", 1, chunk, offset);
        case VSS_OP_JUMP_IF_FALSE:
            return jump_instruction("VSS_OP_JUMP_IF_FALSE", 1, chunk, offset);
        case VSS_OP_LOOP:
            return jump_instruction("VSS_OP_LOOP", -1, chunk, offset);
        case VSS_OP_CALL:
            return byte_instruction("VSS_OP_CALL", chunk, offset);
        case VSS_OP_CLOSURE: {
            offset++;
            uint8_t constant = chunk->code[offset++];
            printf("%-16s %4d ", "VSS_OP_CLOSURE", constant);
            vss_value_say(chunk->constants[constant]);
            printf("\n");
            
            VSS_ObjFunction *func = chunk->constants[constant].as.function;
            for (int j = 0; j < func->upvalue_count; j++) {
                int is_local = chunk->code[offset++];
                int index = chunk->code[offset++];
                printf("%04d      |                     %s %d\n",
                       offset - 2, is_local ? "local" : "upvalue", index);
            }
            return offset;
        }
        case VSS_OP_RETURN:
            return simple_instruction("VSS_OP_RETURN", offset);
        case VSS_OP_YIELD:
            return simple_instruction("VSS_OP_YIELD", offset);
        case VSS_OP_BUILD_LIST:
            return byte_instruction("VSS_OP_BUILD_LIST", chunk, offset);
        case VSS_OP_BUILD_MAP:
            return byte_instruction("VSS_OP_BUILD_MAP", chunk, offset);
        case VSS_OP_GET_ITEM:
            return simple_instruction("VSS_OP_GET_ITEM", offset);
        case VSS_OP_SET_ITEM:
            return simple_instruction("VSS_OP_SET_ITEM", offset);
        case VSS_OP_PUT_ITEM:
            return simple_instruction("VSS_OP_PUT_ITEM", offset);
        case VSS_OP_GET_FIELD:
            return simple_instruction("VSS_OP_GET_FIELD", offset);
        case VSS_OP_SET_FIELD:
            return simple_instruction("VSS_OP_SET_FIELD", offset);
        case VSS_OP_SIZE_OF:
            return simple_instruction("VSS_OP_SIZE_OF", offset);
        case VSS_OP_EXISTS:
            return simple_instruction("VSS_OP_EXISTS", offset);
        case VSS_OP_READ_FILE:
            return simple_instruction("VSS_OP_READ_FILE", offset);
        case VSS_OP_WRITE_FILE:
            return simple_instruction("VSS_OP_WRITE_FILE", offset);
        case VSS_OP_ADD_FILE:
            return simple_instruction("VSS_OP_ADD_FILE", offset);
        case VSS_OP_ERASE_FILE:
            return simple_instruction("VSS_OP_ERASE_FILE", offset);
        case VSS_OP_ATTEMPT:
            return jump_instruction("VSS_OP_ATTEMPT", 1, chunk, offset);
        case VSS_OP_END_ATTEMPT:
            return simple_instruction("VSS_OP_END_ATTEMPT", offset);
        case VSS_OP_GRAB:
            return constant_instruction("VSS_OP_GRAB", chunk, offset);
        case VSS_OP_HI_HTMVSS:
            return simple_instruction("VSS_OP_HI_HTMVSS", offset);
        case VSS_OP_BYE_HTMVSS:
            return simple_instruction("VSS_OP_BYE_HTMVSS", offset);
        case VSS_OP_CLASS:
            return constant_instruction("VSS_OP_CLASS", chunk, offset);
        case VSS_OP_ENUM:
            return constant_instruction("VSS_OP_ENUM", chunk, offset);
        case VSS_OP_GET_MEMBER:
            return constant_instruction("VSS_OP_GET_MEMBER", chunk, offset);
        case VSS_OP_SET_MEMBER:
            return constant_instruction("VSS_OP_SET_MEMBER", chunk, offset);
        case VSS_OP_GET_PARENT:
            return constant_instruction("VSS_OP_GET_PARENT", chunk, offset);
        case VSS_OP_ASK:
            return simple_instruction("VSS_OP_ASK", offset);
        case VSS_OP_START_TASK:
            return byte_instruction("VSS_OP_START_TASK", chunk, offset);
        case VSS_OP_AWAIT_TASK:
            return byte_instruction("VSS_OP_AWAIT_TASK", chunk, offset);
        case VSS_OP_PARALLEL_EACH:
            return simple_instruction("VSS_OP_PARALLEL_EACH", offset);
        case VSS_OP_LOCK_MUTEX:
            return simple_instruction("VSS_OP_LOCK_MUTEX", offset);
        case VSS_OP_UNLOCK_MUTEX:
            return simple_instruction("VSS_OP_UNLOCK_MUTEX", offset);
        default:
            printf("Unknown opcode %d\n", instruction);
            return offset + 1;
    }
}
