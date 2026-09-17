#ifndef VSS_CHUNK_H
#define VSS_CHUNK_H

#include "common.h"
#include "value.h"

typedef enum {
    VSS_OP_CONSTANT,       // Push constant (1-byte index operand)
    VSS_OP_CONSTANT_LONG,  // Push constant (3-byte index operand)
    VSS_OP_EMPTY,          // Push empty
    VSS_OP_TRUE,           // Push yes (true)
    VSS_OP_FALSE,          // Push no (false)
    VSS_OP_POP,            // Pop top of stack
    
    VSS_OP_GET_LOCAL,      // Read local variable (1-byte stack slot index)
    VSS_OP_SET_LOCAL,      // Write local variable (1-byte stack slot index)
    
    VSS_OP_GET_GLOBAL,     // Read global variable (operand: constant pool string index)
    VSS_OP_DEFINE_GLOBAL,  // Define global variable/constant (operand: constant pool string index, +1 byte is_const flag)
    VSS_OP_SET_GLOBAL,     // Assign to global variable (operand: constant pool string index)
    
    VSS_OP_GET_UPVALUE,    // Read captured closure variable (operand: upvalue index)
    VSS_OP_SET_UPVALUE,    // Write captured closure variable (operand: upvalue index)
    
    VSS_OP_ADD,            // Add numbers or join strings
    VSS_OP_SUB,            // Subtract numbers
    VSS_OP_MUL,            // Multiply numbers
    VSS_OP_DIV,            // Divide numbers
    VSS_OP_MOD,            // Modulo of numbers
    
    VSS_OP_NOT,            // Logical NOT
    VSS_OP_NEGATE,         // Numeric negation
    
    VSS_OP_ABOVE,          // Compare above (>)
    VSS_OP_BELOW,          // Compare below (<)
    VSS_OP_AT_LEAST,       // Compare at least (>=)
    VSS_OP_AT_MOST,        // Compare at most (<=)
    VSS_OP_SAME_AS,        // Compare equality (same_as)
    VSS_OP_NOT_SAME_AS,    // Compare inequality (not_same_as)
    
    VSS_OP_SAY,            // Print top of stack followed by newline
    
    VSS_OP_JUMP,           // Jump forward/backward unconditionally (2-byte offset operand)
    VSS_OP_JUMP_IF_FALSE,  // Jump if stack top is falsy (2-byte offset operand)
    VSS_OP_LOOP,           // Loop jump backward (2-byte offset operand)
    
    VSS_OP_CALL,           // Call a closure or native function (1-byte operand: argument count)
    VSS_OP_CLOSURE,        // Instantiate closure (operand: function index in constants, followed by upvalue layout)
    VSS_OP_RETURN,         // Return from current task
    VSS_OP_YIELD,          // Yield from current coroutine/generator task
    
    VSS_OP_BUILD_LIST,     // Create list from stack elements (1-byte operand: count)
    VSS_OP_BUILD_SET,      // Create set from stack elements (1-byte operand: count)
    VSS_OP_BUILD_MAP,      // Create map from stack elements (1-byte operand: key-value pair count)
    VSS_OP_GET_ITEM,       // Access list item: stack has [list, index] -> pushes item
    VSS_OP_SET_ITEM,       // Assign list item: stack has [list, index, val]
    VSS_OP_PUT_ITEM,       // Put item in list: stack has [val, list] -> appends val
    VSS_OP_GET_FIELD,      // Access map field: stack has [map, field_key] -> pushes field value
    VSS_OP_SET_FIELD,      // Set map field: stack has [map, field_key, val] -> sets field
    
    VSS_OP_SIZE_OF,        // Get size of list/map/string
    VSS_OP_EXISTS,         // File exists check
    VSS_OP_READ_FILE,      // Read file
    VSS_OP_WRITE_FILE,     // Write content into file
    VSS_OP_ADD_FILE,       // Append content to file
    VSS_OP_ERASE_FILE,     // Delete file
    
    VSS_OP_ATTEMPT,        // Enter attempt block (2-byte jump offset to rescue block)
    VSS_OP_END_ATTEMPT,    // Exit attempt block (pop exception handler)
    VSS_OP_GRAB,           // Import/grab module (1-byte operand: constant pool string index)
    
    VSS_OP_HI_HTMVSS,      // Emit HTML document prefix
    VSS_OP_BYE_HTMVSS,     // Emit HTML document suffix
    
    // OOP Opcodes
    VSS_OP_CLASS,
    VSS_OP_ENUM,
    VSS_OP_GET_MEMBER,
    VSS_OP_SET_MEMBER,
    VSS_OP_GET_PARENT,
    VSS_OP_ASK,
    VSS_OP_START_TASK,
    VSS_OP_AWAIT_TASK,
    VSS_OP_PARALLEL_EACH,
    VSS_OP_LOCK_MUTEX,
    VSS_OP_UNLOCK_MUTEX
} VSS_OpCode;

typedef struct {
    uint8_t *code;
    int *lines;
    int count;
    int capacity;
    VSS_Value *constants;
    int const_count;
    int const_capacity;
} VSS_Chunk;

void vss_chunk_init(VSS_Chunk *chunk);
void vss_chunk_free(VSS_Chunk *chunk);
void vss_chunk_write(VSS_Chunk *chunk, uint8_t byte, int line);
int vss_chunk_add_constant(VSS_Chunk *chunk, VSS_Value value);

// Disassembly tools for debugging
void vss_disassemble_chunk(VSS_Chunk *chunk, const char *name);
int vss_disassemble_instruction(VSS_Chunk *chunk, int offset);

#endif
