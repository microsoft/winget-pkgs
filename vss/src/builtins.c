/* Feature-test macros MUST come before every #include */
#ifndef _WIN32
#  ifndef _POSIX_C_SOURCE
#    define _POSIX_C_SOURCE 200809L
#  endif
#  ifndef _DEFAULT_SOURCE
#    define _DEFAULT_SOURCE 1
#  endif
#  ifndef _XOPEN_SOURCE
#    define _XOPEN_SOURCE 700
#  endif
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <time.h>
#include "value.h"
#include "env.h"
#include "platform.h"
#include "json.h"
#include "lexer.h"
#include "parser.h"
#include "compiler.h"
#include "vm.h"
#include "vss_concurrency.h"

#ifdef _WIN32
#  include <windows.h>
#  include <winsock2.h>
#  include <ws2tcpip.h>
#  define strdup  _strdup
#  define popen   _popen
#  define pclose  _pclose
#else
#  include <unistd.h>
#  include <dlfcn.h>
#  include <sys/socket.h>
#  include <netdb.h>
#  include <arpa/inet.h>
#  include <netinet/in.h>
#endif

// MD5 and SHA256 self-contained implementations
#define LEFTROTATE(x, c) (((x) << (c)) | ((x) >> (32 - (c))))

static void md5(const uint8_t *initial_msg, size_t initial_len, uint8_t *digest) {
    uint32_t h0 = 0x67452301;
    uint32_t h1 = 0xefcdab89;
    uint32_t h2 = 0x98badcfe;
    uint32_t h3 = 0x10325476;

    static const uint32_t r[] = {
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
    };

    static const uint32_t k[] = {
        0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
        0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
        0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
        0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
        0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
        0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
        0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
        0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
        0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
        0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
        0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
        0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
        0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
        0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
        0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
        0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
    };

    size_t new_len = ((((initial_len + 8) / 64) + 1) * 64);
    uint8_t *msg = calloc(new_len, 1);
    memcpy(msg, initial_msg, initial_len);
    msg[initial_len] = 128;

    uint32_t bits_len = (uint32_t)(initial_len * 8);
    memcpy(msg + new_len - 8, &bits_len, 4);

    for (size_t offset = 0; offset < new_len; offset += 64) {
        uint32_t *w = (uint32_t *)(msg + offset);
        uint32_t a = h0;
        uint32_t b = h1;
        uint32_t c = h2;
        uint32_t d = h3;

        for (uint32_t i = 0; i < 64; i++) {
            uint32_t f, g;
            if (i < 16) {
                f = (b & c) | ((~b) & d);
                g = i;
            } else if (i < 32) {
                f = (d & b) | ((~d) & c);
                g = (5 * i + 1) % 16;
            } else if (i < 48) {
                f = b ^ c ^ d;
                g = (3 * i + 5) % 16;
            } else {
                f = c ^ (b | (~d));
                g = (7 * i) % 16;
            }
            uint32_t temp = d;
            d = c;
            c = b;
            b = b + LEFTROTATE((a + f + k[i] + w[g]), r[i]);
            a = temp;
        }
        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
    }
    free(msg);

    memcpy(digest, &h0, 4);
    memcpy(digest + 4, &h1, 4);
    memcpy(digest + 8, &h2, 4);
    memcpy(digest + 12, &h3, 4);
}

// SHA-256 implementation
static const uint32_t sha256_k[] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static void sha256(const uint8_t *data, size_t len, uint8_t *digest) {
    uint32_t h[8] = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };
    
    size_t new_len = (len + 8 + 64) & ~63;
    uint8_t *msg = calloc(new_len, 1);
    memcpy(msg, data, len);
    msg[len] = 0x80;
    
    uint64_t bits = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++) {
        msg[new_len - 1 - i] = (uint8_t)(bits >> (i * 8));
    }
    
    for (size_t offset = 0; offset < new_len; offset += 64) {
        uint32_t w[64];
        for (int i = 0; i < 16; i++) {
            uint8_t *p = msg + offset + i * 4;
            w[i] = ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
        }
        for (int i = 16; i < 64; i++) {
            uint32_t s0 = ((w[i-15] >> 7) | (w[i-15] << 25)) ^ ((w[i-15] >> 18) | (w[i-15] << 14)) ^ (w[i-15] >> 3);
            uint32_t s1 = ((w[i-2] >> 17) | (w[i-2] << 15)) ^ ((w[i-2] >> 19) | (w[i-2] << 13)) ^ (w[i-2] >> 10);
            w[i] = w[i-16] + s0 + w[i-7] + s1;
        }
        
        uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], k = h[7];
        
        for (int i = 0; i < 64; i++) {
            uint32_t S1 = ((e >> 6) | (e << 26)) ^ ((e >> 11) | (e << 21)) ^ ((e >> 25) | (e << 7));
            uint32_t ch = (e & f) ^ (~e & g);
            uint32_t temp1 = k + S1 + ch + sha256_k[i] + w[i];
            uint32_t S0 = ((a >> 2) | (a << 30)) ^ ((a >> 13) | (a << 19)) ^ ((a >> 22) | (a << 10));
            uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
            uint32_t temp2 = S0 + maj;
            
            k = g;
            g = f;
            f = e;
            e = d + temp1;
            d = c;
            c = b;
            b = a;
            a = temp1 + temp2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d;
        h[4] += e; h[5] += f; h[6] += g; h[7] += k;
    }
    free(msg);
    
    for (int i = 0; i < 8; i++) {
        digest[i*4]   = (uint8_t)(h[i] >> 24);
        digest[i*4+1] = (uint8_t)(h[i] >> 16);
        digest[i*4+2] = (uint8_t)(h[i] >> 8);
        digest[i*4+3] = (uint8_t)h[i];
    }
}

// Helper to duplicate string safely
static char *safe_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) {
        strcpy(dup, s);
    }
    return dup;
}

// ─────────────────────────────────────────────────────────────────────────────
// SQLITE DYNAMIC LINKER & MOCK ENGINE
// ─────────────────────────────────────────────────────────────────────────────
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;

typedef int (*fn_sqlite3_open)(const char *filename, sqlite3 **ppDb);
typedef int (*fn_sqlite3_close)(sqlite3*);
typedef int (*fn_sqlite3_exec)(sqlite3*, const char *sql, int (*callback)(void*,int,char**,char**), void*, char **errmsg);
typedef int (*fn_sqlite3_prepare_v2)(sqlite3 *db, const char *zSql, int nByte, sqlite3_stmt **ppStmt, const char **pzTail);
typedef int (*fn_sqlite3_step)(sqlite3_stmt*);
typedef int (*fn_sqlite3_finalize)(sqlite3_stmt*);
typedef int (*fn_sqlite3_column_count)(sqlite3_stmt *pStmt);
typedef const char *(*fn_sqlite3_column_name)(sqlite3_stmt*, int N);
typedef const unsigned char *(*fn_sqlite3_column_text)(sqlite3_stmt*, int iCol);

static fn_sqlite3_open p_sqlite3_open = NULL;
static fn_sqlite3_close p_sqlite3_close = NULL;
static fn_sqlite3_exec p_sqlite3_exec = NULL;
static fn_sqlite3_prepare_v2 p_sqlite3_prepare_v2 = NULL;
static fn_sqlite3_step p_sqlite3_step = NULL;
static fn_sqlite3_finalize p_sqlite3_finalize = NULL;
static fn_sqlite3_column_count p_sqlite3_column_count = NULL;
static fn_sqlite3_column_name p_sqlite3_column_name = NULL;
static fn_sqlite3_column_text p_sqlite3_column_text = NULL;

static bool sqlite_loaded = false;
static void *sqlite_lib = NULL;

static void load_sqlite(void) {
    if (sqlite_loaded) return;
#ifdef _WIN32
    sqlite_lib = LoadLibraryA("sqlite3.dll");
    if (sqlite_lib) {
        p_sqlite3_open = (fn_sqlite3_open)GetProcAddress(sqlite_lib, "sqlite3_open");
        p_sqlite3_close = (fn_sqlite3_close)GetProcAddress(sqlite_lib, "sqlite3_close");
        p_sqlite3_exec = (fn_sqlite3_exec)GetProcAddress(sqlite_lib, "sqlite3_exec");
        p_sqlite3_prepare_v2 = (fn_sqlite3_prepare_v2)GetProcAddress(sqlite_lib, "sqlite3_prepare_v2");
        p_sqlite3_step = (fn_sqlite3_step)GetProcAddress(sqlite_lib, "sqlite3_step");
        p_sqlite3_finalize = (fn_sqlite3_finalize)GetProcAddress(sqlite_lib, "sqlite3_finalize");
        p_sqlite3_column_count = (fn_sqlite3_column_count)GetProcAddress(sqlite_lib, "sqlite3_column_count");
        p_sqlite3_column_name = (fn_sqlite3_column_name)GetProcAddress(sqlite_lib, "sqlite3_column_name");
        p_sqlite3_column_text = (fn_sqlite3_column_text)GetProcAddress(sqlite_lib, "sqlite3_column_text");
    }
#else
    const char *libs[] = {"libsqlite3.dylib", "libsqlite3.so", "libsqlite3.so.0", "libsqlite3.so.3", NULL};
    for (int i = 0; libs[i]; i++) {
        sqlite_lib = dlopen(libs[i], RTLD_LAZY);
        if (sqlite_lib) {
            p_sqlite3_open = (fn_sqlite3_open)dlsym(sqlite_lib, "sqlite3_open");
            p_sqlite3_close = (fn_sqlite3_close)dlsym(sqlite_lib, "sqlite3_close");
            p_sqlite3_exec = (fn_sqlite3_exec)dlsym(sqlite_lib, "sqlite3_exec");
            p_sqlite3_prepare_v2 = (fn_sqlite3_prepare_v2)dlsym(sqlite_lib, "sqlite3_prepare_v2");
            p_sqlite3_step = (fn_sqlite3_step)dlsym(sqlite_lib, "sqlite3_step");
            p_sqlite3_finalize = (fn_sqlite3_finalize)dlsym(sqlite_lib, "sqlite3_finalize");
            p_sqlite3_column_count = (fn_sqlite3_column_count)dlsym(sqlite_lib, "sqlite3_column_count");
            p_sqlite3_column_name = (fn_sqlite3_column_name)dlsym(sqlite_lib, "sqlite3_column_name");
            p_sqlite3_column_text = (fn_sqlite3_column_text)dlsym(sqlite_lib, "sqlite3_column_text");
            break;
        }
    }
#endif
    if (p_sqlite3_open && p_sqlite3_close && p_sqlite3_prepare_v2 && p_sqlite3_step && p_sqlite3_finalize) {
        sqlite_loaded = true;
    }
}

typedef struct {
    bool is_mock;
    char *filepath;
    sqlite3 *real_db;
} VssDatabase;

static VSS_Value mock_db_execute(VssDatabase *db, const char *sql, char **out_error_msg) {
    // A simple mock for SQLite that supports CREATE TABLE and INSERT INTO using JSON storage
    // Format in db file: { "tables": { "tablename": [ { "col": "val" } ] } }
    FILE *f = fopen(db->filepath, "rb");
    VSS_Value db_state;
    if (f) {
        fseek(f, 0, SEEK_END);
        long sz = ftell(f);
        rewind(f);
        char *buf = malloc(sz + 1);
        size_t rb = fread(buf, 1, sz, f);
        buf[rb] = '\0';
        fclose(f);
        bool parse_err = false;
        char *parse_err_msg = NULL;
        db_state = vss_json_parse(buf, &parse_err, &parse_err_msg);
        free(buf);
        if (parse_err) {
            vss_value_release(db_state);
            db_state = vss_value_new_map();
            VSS_Value tables = vss_value_new_map();
            vss_env_define_const((VSS_Env*)db_state.as.map, "tables", tables);
            vss_value_release(tables);
        }
    } else {
        db_state = vss_value_new_map();
        VSS_Value tables = vss_value_new_map();
        // Since VSS_Env defines properties, we can just define keys directly inside map
        VSS_ValMap *m = db_state.as.map;
        m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * 1);
        m->entries[0].key = safe_strdup("tables");
        m->entries[0].value = tables;
        vss_value_retain(tables);
        m->count = 1;
        vss_value_release(tables);
    }

    // Helper search
    VSS_ValMap *state_map = db_state.as.map;
    VSS_ValMap *tables_map = NULL;
    for (size_t i = 0; i < state_map->count; i++) {
        if (strcmp(state_map->entries[i].key, "tables") == 0) {
            tables_map = state_map->entries[i].value.as.map;
            break;
        }
    }

    char sql_lower[512];
    strncpy(sql_lower, sql, sizeof(sql_lower)-1);
    sql_lower[sizeof(sql_lower)-1] = '\0';
    for (int i = 0; sql_lower[i]; i++) sql_lower[i] = tolower((unsigned char)sql_lower[i]);

    if (strstr(sql_lower, "create table")) {
        // extract table name
        char tablename[128] = {0};
        sscanf(sql, "%*s %*s %127s", tablename);
        // remove parentheses if any
        char *paren = strchr(tablename, '(');
        if (paren) *paren = '\0';
        
        // Add empty list for table
        VSS_Value empty_list = vss_value_new_list();
        tables_map->entries = realloc(tables_map->entries, sizeof(VSS_ValMapEntry) * (tables_map->count + 1));
        tables_map->entries[tables_map->count].key = safe_strdup(tablename);
        tables_map->entries[tables_map->count].value = empty_list;
        vss_value_retain(empty_list);
        tables_map->count++;
        vss_value_release(empty_list);

    } else if (strstr(sql_lower, "insert into")) {
        char tablename[128] = {0};
        sscanf(sql, "%*s %*s %127s", tablename);
        char *values_ptr = strstr(sql_lower, "values");
        if (values_ptr) {
            // Find corresponding array in tables
            VSS_ValList *table_rows = NULL;
            for (size_t i = 0; i < tables_map->count; i++) {
                if (strcmp(tables_map->entries[i].key, tablename) == 0) {
                    table_rows = tables_map->entries[i].value.as.list;
                    break;
                }
            }
            if (table_rows) {
                // simple parser for values (e.g. values ('Asha', 22))
                VSS_Value row = vss_value_new_map();
                VSS_ValMap *row_map = row.as.map;
                
                // We'll just parse strings and numbers in parenthesis
                const char *val_str = sql + (values_ptr - sql_lower) + 6;
                while (*val_str && *val_str != '(') val_str++;
                if (*val_str == '(') val_str++;
                
                int col_idx = 0;
                while (*val_str && *val_str != ')') {
                    while (*val_str && (isspace((unsigned char)*val_str) || *val_str == ',')) val_str++;
                    if (*val_str == '\'') {
                        val_str++;
                        char val_buf[256] = {0};
                        int v_len = 0;
                        while (*val_str && *val_str != '\'') {
                            val_buf[v_len++] = *val_str++;
                        }
                        if (*val_str == '\'') val_str++;
                        
                        char key_name[32];
                        sprintf(key_name, "col%d", col_idx++);
                        VSS_Value v_val = vss_value_new_string(val_buf);
                        row_map->entries = realloc(row_map->entries, sizeof(VSS_ValMapEntry) * (row_map->count + 1));
                        row_map->entries[row_map->count].key = safe_strdup(key_name);
                        row_map->entries[row_map->count].value = v_val;
                        vss_value_retain(v_val);
                        row_map->count++;
                        vss_value_release(v_val);
                    } else if (isdigit((unsigned char)*val_str) || *val_str == '-') {
                        char num_buf[32] = {0};
                        int n_len = 0;
                        while (*val_str && (isdigit((unsigned char)*val_str) || *val_str == '.' || *val_str == '-')) {
                            num_buf[n_len++] = *val_str++;
                        }
                        double d = atof(num_buf);
                        char key_name[32];
                        sprintf(key_name, "col%d", col_idx++);
                        VSS_Value v_val = vss_value_new_number(d);
                        row_map->entries = realloc(row_map->entries, sizeof(VSS_ValMapEntry) * (row_map->count + 1));
                        row_map->entries[row_map->count].key = safe_strdup(key_name);
                        row_map->entries[row_map->count].value = v_val;
                        vss_value_retain(v_val);
                        row_map->count++;
                        vss_value_release(v_val);
                    } else {
                        val_str++;
                    }
                }
                
                // Add row to table
                if (table_rows->count >= table_rows->capacity) {
                    table_rows->capacity = table_rows->capacity == 0 ? 8 : table_rows->capacity * 2;
                    table_rows->items = realloc(table_rows->items, sizeof(VSS_Value) * table_rows->capacity);
                }
                table_rows->items[table_rows->count++] = row;
                vss_value_retain(row);
                vss_value_release(row);
            }
        }
    }

    // Write back
    char *serialized = vss_json_serialize(db_state);
    f = fopen(db->filepath, "wb");
    if (f) {
        fwrite(serialized, 1, strlen(serialized), f);
        fclose(f);
    }
    free(serialized);
    vss_value_release(db_state);
    return vss_value_new_bool(true);
}

static VSS_Value mock_db_query(VssDatabase *db, const char *sql, char **out_error_msg) {
    // Simple mock select: select * from <table> returns the table array
    char sql_lower[512];
    strncpy(sql_lower, sql, sizeof(sql_lower)-1);
    sql_lower[sizeof(sql_lower)-1] = '\0';
    for (int i = 0; sql_lower[i]; i++) sql_lower[i] = tolower((unsigned char)sql_lower[i]);

    char tablename[128] = {0};
    char *from_ptr = strstr(sql_lower, "from");
    if (from_ptr) {
        sscanf(sql + (from_ptr - sql_lower) + 4, "%127s", tablename);
    }
    
    FILE *f = fopen(db->filepath, "rb");
    if (!f) return vss_value_new_list();

    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    rewind(f);
    char *buf = malloc(sz + 1);
    size_t rb = fread(buf, 1, sz, f);
    buf[rb] = '\0';
    fclose(f);

    bool parse_err = false;
    char *parse_err_msg = NULL;
    VSS_Value db_state = vss_json_parse(buf, &parse_err, &parse_err_msg);
    free(buf);
    if (parse_err) {
        vss_value_release(db_state);
        return vss_value_new_list();
    }

    VSS_ValMap *state_map = db_state.as.map;
    VSS_ValMap *tables_map = NULL;
    for (size_t i = 0; i < state_map->count; i++) {
        if (strcmp(state_map->entries[i].key, "tables") == 0) {
            tables_map = state_map->entries[i].value.as.map;
            break;
        }
    }

    VSS_Value result_list = vss_value_new_list();
    if (tables_map) {
        for (size_t i = 0; i < tables_map->count; i++) {
            if (strcmp(tables_map->entries[i].key, tablename) == 0) {
                // Copy list
                VSS_ValList *src = tables_map->entries[i].value.as.list;
                VSS_ValList *dest = result_list.as.list;
                dest->items = malloc(sizeof(VSS_Value) * src->count);
                dest->count = src->count;
                dest->capacity = src->count;
                for (size_t j = 0; j < src->count; j++) {
                    dest->items[j] = src->items[j];
                    vss_value_retain(src->items[j]);
                }
                break;
            }
        }
    }
    vss_value_release(db_state);
    return result_list;
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILT-IN IMPLEMENTATIONS
// ─────────────────────────────────────────────────────────────────────────────

// Standard library file operations
static VSS_Value builtin_exists(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("__exists expects a string path");
        return vss_value_new_empty();
    }
    return vss_value_new_bool(vss_file_exists(args[0].as.string->chars));
}

static VSS_Value builtin_read(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("__read expects a string path");
        return vss_value_new_empty();
    }
    const char *path = args[0].as.string->chars;
    FILE *f = fopen(path, "rb");
    if (!f) {
        *out_error = true;
        *out_error_msg = malloc(strlen(path) + 32);
        sprintf(*out_error_msg, "Could not open file: %s", path);
        return vss_value_new_empty();
    }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    rewind(f);
    char *buf = malloc(size + 1);
    size_t rb = fread(buf, 1, size, f);
    fclose(f);
    buf[rb] = '\0';
    VSS_Value res = vss_value_new_string(buf);
    free(buf);
    return res;
}

static VSS_Value builtin_write(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("__write expects content and path");
        return vss_value_new_empty();
    }
    const char *content = args[0].as.string->chars;
    const char *path = args[1].as.string->chars;
    FILE *f = fopen(path, "wb");
    if (!f) {
        *out_error = true;
        *out_error_msg = safe_strdup("Could not open file for writing");
        return vss_value_new_empty();
    }
    fwrite(content, 1, strlen(content), f);
    fclose(f);
    return vss_value_new_empty();
}

static VSS_Value builtin_add(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("__add expects content and path");
        return vss_value_new_empty();
    }
    const char *content = args[0].as.string->chars;
    const char *path = args[1].as.string->chars;
    FILE *f = fopen(path, "ab");
    if (!f) {
        *out_error = true;
        *out_error_msg = safe_strdup("Could not open file for appending");
        return vss_value_new_empty();
    }
    fwrite(content, 1, strlen(content), f);
    fclose(f);
    return vss_value_new_empty();
}

static VSS_Value builtin_erase(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("__erase expects a string path");
        return vss_value_new_empty();
    }
    remove(args[0].as.string->chars);
    return vss_value_new_empty();
}

static VSS_Value builtin_make_dir(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("__make_dir expects a string path");
        return vss_value_new_empty();
    }
    bool success = vss_make_dir(args[0].as.string->chars);
    return vss_value_new_bool(success);
}

static VSS_Value builtin_file_list(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("__file_list expects a directory path string");
        return vss_value_new_empty();
    }
    char **filenames = NULL;
    int count = vss_list_dir(args[0].as.string->chars, &filenames);
    VSS_Value list_val = vss_value_new_list();
    VSS_ValList *l = list_val.as.list;
    l->items = malloc(sizeof(VSS_Value) * count);
    l->count = count;
    l->capacity = count;
    for (int i = 0; i < count; i++) {
        l->items[i] = vss_value_new_string(filenames[i]);
        free(filenames[i]);
    }
    free(filenames);
    return list_val;
}

// Math Builtins
static VSS_Value builtin_math_sin(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("sin expects a number"); return vss_value_new_empty();
    }
    return vss_value_new_number(sin(args[0].as.number));
}
static VSS_Value builtin_math_cos(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("cos expects a number"); return vss_value_new_empty();
    }
    return vss_value_new_number(cos(args[0].as.number));
}
static VSS_Value builtin_math_tan(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("tan expects a number"); return vss_value_new_empty();
    }
    return vss_value_new_number(tan(args[0].as.number));
}
static VSS_Value builtin_math_sqrt(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("sqrt expects a number"); return vss_value_new_empty();
    }
    return vss_value_new_number(sqrt(args[0].as.number));
}
static VSS_Value builtin_math_log(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("log expects a number"); return vss_value_new_empty();
    }
    return vss_value_new_number(log(args[0].as.number));
}
static VSS_Value builtin_math_ceil(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("ceil expects a number"); return vss_value_new_empty();
    }
    return vss_value_new_number(ceil(args[0].as.number));
}
static VSS_Value builtin_math_floor(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("floor expects a number"); return vss_value_new_empty();
    }
    return vss_value_new_number(floor(args[0].as.number));
}
static VSS_Value builtin_math_pow(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_NUMBER || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("pow expects base and exponent numbers"); return vss_value_new_empty();
    }
    return vss_value_new_number(pow(args[0].as.number, args[1].as.number));
}

// String Builtins
static VSS_Value builtin_string_length(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("length expects string"); return vss_value_new_empty();
    }
    return vss_value_new_number(strlen(args[0].as.string->chars));
}

static VSS_Value builtin_string_lower(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("lower expects string"); return vss_value_new_empty();
    }
    char *copy = safe_strdup(args[0].as.string->chars);
    for (int i = 0; copy[i]; i++) copy[i] = tolower((unsigned char)copy[i]);
    VSS_Value res = vss_value_new_string(copy);
    free(copy);
    return res;
}

static VSS_Value builtin_string_upper(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("upper expects string"); return vss_value_new_empty();
    }
    char *copy = safe_strdup(args[0].as.string->chars);
    for (int i = 0; copy[i]; i++) copy[i] = toupper((unsigned char)copy[i]);
    VSS_Value res = vss_value_new_string(copy);
    free(copy);
    return res;
}

static VSS_Value builtin_string_trim(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("trim expects string"); return vss_value_new_empty();
    }
    const char *start = args[0].as.string->chars;
    while (*start && isspace((unsigned char)*start)) start++;
    const char *end = start + strlen(start);
    while (end > start && isspace((unsigned char)*(end - 1))) end--;
    
    size_t len = end - start;
    char *trimmed = malloc(len + 1);
    memcpy(trimmed, start, len);
    trimmed[len] = '\0';
    VSS_Value res = vss_value_new_string(trimmed);
    free(trimmed);
    return res;
}

static VSS_Value builtin_string_substring(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 3 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_NUMBER || args[2].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("substring expects string, start, and end index"); return vss_value_new_empty();
    }
    const char *s = args[0].as.string->chars;
    int len = (int)strlen(s);
    int start = (int)args[1].as.number;
    int end = (int)args[2].as.number;
    if (start < 0) start = 0;
    if (end > len) end = len;
    if (start > end) start = end;
    
    int sublen = end - start;
    char *sub = malloc(sublen + 1);
    memcpy(sub, s + start, sublen);
    sub[sublen] = '\0';
    VSS_Value res = vss_value_new_string(sub);
    free(sub);
    return res;
}

static VSS_Value builtin_string_find(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("find expects string and search-sub"); return vss_value_new_empty();
    }
    const char *s = args[0].as.string->chars;
    const char *sub = args[1].as.string->chars;
    const char *found = strstr(s, sub);
    if (!found) return vss_value_new_number(-1);
    return vss_value_new_number(found - s);
}

static VSS_Value builtin_string_replace(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 3 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING || args[2].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("replace expects string, old, and new substring"); return vss_value_new_empty();
    }
    const char *orig = args[0].as.string->chars;
    const char *rep = args[1].as.string->chars;
    const char *with = args[2].as.string->chars;
    
    size_t rep_len = strlen(rep);
    size_t with_len = strlen(with);
    if (rep_len == 0) return vss_value_new_string(orig);

    size_t count = 0;
    const char *tmp = orig;
    while ((tmp = strstr(tmp, rep))) {
        count++;
        tmp += rep_len;
    }
    
    size_t new_len = strlen(orig) + (with_len - rep_len) * count;
    char *result = malloc(new_len + 1);
    char *dst = result;
    const char *src = orig;
    while ((tmp = strstr(src, rep))) {
        size_t skip = tmp - src;
        memcpy(dst, src, skip);
        dst += skip;
        memcpy(dst, with, with_len);
        dst += with_len;
        src = tmp + rep_len;
    }
    strcpy(dst, src);
    VSS_Value res = vss_value_new_string(result);
    free(result);
    return res;
}

static VSS_Value builtin_string_split(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("split expects string and delimiter"); return vss_value_new_empty();
    }
    const char *orig = args[0].as.string->chars;
    const char *sep = args[1].as.string->chars;
    VSS_Value list = vss_value_new_list();
    VSS_ValList *l = list.as.list;
    
    size_t sep_len = strlen(sep);
    if (sep_len == 0) {
        // split into chars
        for (int i = 0; orig[i]; i++) {
            char ch[2] = {orig[i], '\0'};
            VSS_Value str_val = vss_value_new_string(ch);
            if (l->count >= l->capacity) {
                l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
                l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
            }
            l->items[l->count++] = str_val;
            vss_value_retain(str_val);
            vss_value_release(str_val);
        }
        return list;
    }

    const char *src = orig;
    const char *tmp;
    while ((tmp = strstr(src, sep))) {
        size_t part_len = tmp - src;
        char *part = malloc(part_len + 1);
        memcpy(part, src, part_len);
        part[part_len] = '\0';
        
        VSS_Value str_val = vss_value_new_string(part);
        free(part);
        if (l->count >= l->capacity) {
            l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
            l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
        }
        l->items[l->count++] = str_val;
        vss_value_retain(str_val);
        vss_value_release(str_val);
        src = tmp + sep_len;
    }
    VSS_Value str_val = vss_value_new_string(src);
    if (l->count >= l->capacity) {
        l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
        l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
    }
    l->items[l->count++] = str_val;
    vss_value_retain(str_val);
    vss_value_release(str_val);
    
    return list;
}

static void append_str(char **buf, size_t *len, size_t *cap, const char *s) {
    size_t slen = strlen(s);
    while (*len + slen >= *cap) {
        *cap = *cap == 0 ? 64 : *cap * 2;
        *buf = realloc(*buf, *cap);
    }
    strcpy(*buf + *len, s);
    *len += slen;
}

static VSS_Value builtin_string_join(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_LIST || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("join expects list and separator string"); return vss_value_new_empty();
    }
    VSS_ValList *l = args[0].as.list;
    const char *sep = args[1].as.string->chars;
    
    char *buf = NULL;
    size_t len = 0;
    size_t cap = 0;
    for (size_t i = 0; i < l->count; i++) {
        if (i > 0) append_str(&buf, &len, &cap, sep);
        char *item_str = vss_value_to_string(l->items[i]);
        append_str(&buf, &len, &cap, item_str);
        free(item_str);
    }
    VSS_Value res = vss_value_new_string(buf ? buf : "");
    if (buf) free(buf);
    return res;
}

// ─────────────────────────────────────────────────────────────────────────────
// PYTHON PARITY BUILT-INS (Sequence, Math, String & Map Utilities)
// ─────────────────────────────────────────────────────────────────────────────
static VSS_Value builtin_math_abs(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("abs expects a number"); return vss_value_new_empty();
    }
    return vss_value_new_number(fabs(args[0].as.number));
}

static VSS_Value builtin_math_min(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count == 1 && args[0].type == VSS_VAL_LIST) {
        VSS_ValList *l = args[0].as.list;
        if (l->count == 0) return vss_value_new_empty();
        double m = l->items[0].type == VSS_VAL_NUMBER ? l->items[0].as.number : 0;
        for (size_t i = 1; i < l->count; i++) {
            if (l->items[i].type == VSS_VAL_NUMBER && l->items[i].as.number < m) {
                m = l->items[i].as.number;
            }
        }
        return vss_value_new_number(m);
    }
    if (arg_count != 2 || args[0].type != VSS_VAL_NUMBER || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("min expects 2 numbers or a list"); return vss_value_new_empty();
    }
    return vss_value_new_number(args[0].as.number < args[1].as.number ? args[0].as.number : args[1].as.number);
}

static VSS_Value builtin_math_max(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count == 1 && args[0].type == VSS_VAL_LIST) {
        VSS_ValList *l = args[0].as.list;
        if (l->count == 0) return vss_value_new_empty();
        double m = l->items[0].type == VSS_VAL_NUMBER ? l->items[0].as.number : 0;
        for (size_t i = 1; i < l->count; i++) {
            if (l->items[i].type == VSS_VAL_NUMBER && l->items[i].as.number > m) {
                m = l->items[i].as.number;
            }
        }
        return vss_value_new_number(m);
    }
    if (arg_count != 2 || args[0].type != VSS_VAL_NUMBER || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("max expects 2 numbers or a list"); return vss_value_new_empty();
    }
    return vss_value_new_number(args[0].as.number > args[1].as.number ? args[0].as.number : args[1].as.number);
}

static VSS_Value builtin_math_sum(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_LIST) {
        *out_error = true; *out_error_msg = safe_strdup("sum expects a list of numbers"); return vss_value_new_empty();
    }
    VSS_ValList *l = args[0].as.list;
    double total = 0;
    for (size_t i = 0; i < l->count; i++) {
        if (l->items[i].type == VSS_VAL_NUMBER) total += l->items[i].as.number;
    }
    return vss_value_new_number(total);
}

static VSS_Value builtin_math_round(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("round expects a number"); return vss_value_new_empty();
    }
    double val = args[0].as.number;
    if (arg_count == 2 && args[1].type == VSS_VAL_NUMBER) {
        double decimals = args[1].as.number;
        double factor = pow(10.0, decimals);
        return vss_value_new_number(round(val * factor) / factor);
    }
    return vss_value_new_number(round(val));
}

static VSS_Value builtin_string_startswith(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("startswith expects target and prefix string"); return vss_value_new_empty();
    }
    const char *s = args[0].as.string->chars;
    const char *prefix = args[1].as.string->chars;
    return vss_value_new_bool(strncmp(s, prefix, strlen(prefix)) == 0);
}

static VSS_Value builtin_string_endswith(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("endswith expects target and suffix string"); return vss_value_new_empty();
    }
    const char *s = args[0].as.string->chars;
    const char *suffix = args[1].as.string->chars;
    size_t slen = strlen(s);
    size_t suflen = strlen(suffix);
    if (suflen > slen) return vss_value_new_bool(false);
    return vss_value_new_bool(strcmp(s + slen - suflen, suffix) == 0);
}

static VSS_Value builtin_string_isalpha(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("isalpha expects a string"); return vss_value_new_empty();
    }
    const char *s = args[0].as.string->chars;
    if (!*s) return vss_value_new_bool(false);
    while (*s) {
        if (!isalpha((unsigned char)*s)) return vss_value_new_bool(false);
        s++;
    }
    return vss_value_new_bool(true);
}

static VSS_Value builtin_string_isdigit(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("isdigit expects a string"); return vss_value_new_empty();
    }
    const char *s = args[0].as.string->chars;
    if (!*s) return vss_value_new_bool(false);
    while (*s) {
        if (!isdigit((unsigned char)*s)) return vss_value_new_bool(false);
        s++;
    }
    return vss_value_new_bool(true);
}

static VSS_Value builtin_string_count(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("count expects string and substring"); return vss_value_new_empty();
    }
    const char *s = args[0].as.string->chars;
    const char *sub = args[1].as.string->chars;
    size_t sub_len = strlen(sub);
    if (sub_len == 0) return vss_value_new_number(0);
    size_t cnt = 0;
    while ((s = strstr(s, sub))) {
        cnt++;
        s += sub_len;
    }
    return vss_value_new_number(cnt);
}

static VSS_Value builtin_list_range(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    double start = 0, stop = 0, step = 1;
    if (arg_count == 1 && args[0].type == VSS_VAL_NUMBER) {
        stop = args[0].as.number;
    } else if (arg_count == 2 && args[0].type == VSS_VAL_NUMBER && args[1].type == VSS_VAL_NUMBER) {
        start = args[0].as.number; stop = args[1].as.number;
    } else if (arg_count == 3 && args[0].type == VSS_VAL_NUMBER && args[1].type == VSS_VAL_NUMBER && args[2].type == VSS_VAL_NUMBER) {
        start = args[0].as.number; stop = args[1].as.number; step = args[2].as.number;
    } else {
        *out_error = true; *out_error_msg = safe_strdup("range expects (stop) or (start, stop) or (start, stop, step)"); return vss_value_new_empty();
    }
    if (step == 0) {
        *out_error = true; *out_error_msg = safe_strdup("range step cannot be 0"); return vss_value_new_empty();
    }

    VSS_Value res = vss_value_new_list();
    VSS_ValList *l = res.as.list;
    if (step > 0) {
        for (double i = start; i < stop; i += step) {
            VSS_Value num = vss_value_new_number(i);
            if (l->count >= l->capacity) {
                l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
                l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
            }
            l->items[l->count++] = num;
            vss_value_retain(num);
            vss_value_release(num);
        }
    } else {
        for (double i = start; i > stop; i += step) {
            VSS_Value num = vss_value_new_number(i);
            if (l->count >= l->capacity) {
                l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
                l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
            }
            l->items[l->count++] = num;
            vss_value_retain(num);
            vss_value_release(num);
        }
    }
    return res;
}

static VSS_Value builtin_list_enumerate(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_LIST) {
        *out_error = true; *out_error_msg = safe_strdup("enumerate expects a list"); return vss_value_new_empty();
    }
    VSS_ValList *src = args[0].as.list;
    VSS_Value res = vss_value_new_list();
    VSS_ValList *l = res.as.list;
    l->items = malloc(sizeof(VSS_Value) * src->count);
    l->count = src->count;
    l->capacity = src->count;
    for (size_t i = 0; i < src->count; i++) {
        VSS_Value pair = vss_value_new_map();
        VSS_ValMap *m = pair.as.map;
        m->entries = malloc(sizeof(VSS_ValMapEntry) * 2);
        m->count = 2;
        m->capacity = 2;
        m->entries[0].key = safe_strdup("index");
        m->entries[0].value = vss_value_new_number((double)i);
        vss_value_retain(m->entries[0].value);
        m->entries[1].key = safe_strdup("value");
        m->entries[1].value = src->items[i];
        vss_value_retain(m->entries[1].value);
        l->items[i] = pair;
        vss_value_retain(pair);
        vss_value_release(pair);
    }
    return res;
}

static VSS_Value builtin_list_reversed(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_LIST) {
        *out_error = true; *out_error_msg = safe_strdup("reversed expects a list"); return vss_value_new_empty();
    }
    VSS_ValList *src = args[0].as.list;
    VSS_Value res = vss_value_new_list();
    VSS_ValList *l = res.as.list;
    l->items = malloc(sizeof(VSS_Value) * src->count);
    l->count = src->count;
    l->capacity = src->count;
    for (size_t i = 0; i < src->count; i++) {
        l->items[i] = src->items[src->count - 1 - i];
        vss_value_retain(l->items[i]);
    }
    return res;
}

static int val_compare(const void *a, const void *b) {
    const VSS_Value *va = (const VSS_Value *)a;
    const VSS_Value *vb = (const VSS_Value *)b;
    if (va->type == VSS_VAL_NUMBER && vb->type == VSS_VAL_NUMBER) {
        return (va->as.number > vb->as.number) - (va->as.number < vb->as.number);
    }
    if (va->type == VSS_VAL_STRING && vb->type == VSS_VAL_STRING) {
        return strcmp(va->as.string->chars, vb->as.string->chars);
    }
    return 0;
}

static VSS_Value builtin_list_sorted(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_LIST) {
        *out_error = true; *out_error_msg = safe_strdup("sorted expects a list"); return vss_value_new_empty();
    }
    VSS_ValList *src = args[0].as.list;
    VSS_Value res = vss_value_new_list();
    VSS_ValList *l = res.as.list;
    l->items = malloc(sizeof(VSS_Value) * src->count);
    l->count = src->count;
    l->capacity = src->count;
    for (size_t i = 0; i < src->count; i++) {
        l->items[i] = src->items[i];
        vss_value_retain(l->items[i]);
    }
    qsort(l->items, l->count, sizeof(VSS_Value), val_compare);
    return res;
}

static VSS_Value builtin_map_keys(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_MAP) {
        *out_error = true; *out_error_msg = safe_strdup("keys expects a map"); return vss_value_new_empty();
    }
    VSS_ValMap *m = args[0].as.map;
    VSS_Value list = vss_value_new_list();
    VSS_ValList *l = list.as.list;
    l->items = malloc(sizeof(VSS_Value) * m->count);
    l->count = m->count;
    l->capacity = m->count;
    for (size_t i = 0; i < m->count; i++) {
        l->items[i] = vss_value_new_string(m->entries[i].key);
        vss_value_retain(l->items[i]);
        vss_value_release(l->items[i]);
    }
    return list;
}

static VSS_Value builtin_map_values(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_MAP) {
        *out_error = true; *out_error_msg = safe_strdup("values expects a map"); return vss_value_new_empty();
    }
    VSS_ValMap *m = args[0].as.map;
    VSS_Value list = vss_value_new_list();
    VSS_ValList *l = list.as.list;
    l->items = malloc(sizeof(VSS_Value) * m->count);
    l->count = m->count;
    l->capacity = m->count;
    for (size_t i = 0; i < m->count; i++) {
        l->items[i] = m->entries[i].value;
        vss_value_retain(l->items[i]);
    }
    return list;
}

static VSS_Value builtin_map_get(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_MAP || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("get expects map and key string"); return vss_value_new_empty();
    }
    VSS_ValMap *m = args[0].as.map;
    const char *key = args[1].as.string->chars;
    for (size_t i = 0; i < m->count; i++) {
        if (strcmp(m->entries[i].key, key) == 0) {
            return m->entries[i].value;
        }
    }
    if (arg_count >= 3) return args[2];
    return vss_value_new_empty();
}

static VSS_Value builtin_type_of(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1) {
        *out_error = true; *out_error_msg = safe_strdup("type_of expects 1 argument"); return vss_value_new_empty();
    }
    switch (args[0].type) {
        case VSS_VAL_NUMBER: return vss_value_new_string("number");
        case VSS_VAL_STRING: return vss_value_new_string("string");
        case VSS_VAL_BOOL: return vss_value_new_string("boolean");
        case VSS_VAL_LIST: return vss_value_new_string("list");
        case VSS_VAL_MAP: return vss_value_new_string("map");
        case VSS_VAL_CLOSURE:
        case VSS_VAL_FUNCTION:
        case VSS_VAL_NATIVE: return vss_value_new_string("function");
        default: return vss_value_new_string("empty");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// BASE64 & HEX ENCODING BUILTINS
// ─────────────────────────────────────────────────────────────────────────────
static const char b64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static VSS_Value builtin_encoding_base64_encode(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("base64_encode expects a string"); return vss_value_new_empty();
    }
    const uint8_t *data = (const uint8_t *)args[0].as.string->chars;
    size_t input_len = strlen((const char *)data);
    size_t output_len = 4 * ((input_len + 2) / 3);
    char *encoded = malloc(output_len + 1);
    
    for (size_t i = 0, j = 0; i < input_len;) {
        uint32_t octet_a = i < input_len ? data[i++] : 0;
        uint32_t octet_b = i < input_len ? data[i++] : 0;
        uint32_t octet_c = i < input_len ? data[i++] : 0;
        uint32_t triple = (octet_a << 16) + (octet_b << 8) + octet_c;

        encoded[j++] = b64_table[(triple >> 18) & 0x3F];
        encoded[j++] = b64_table[(triple >> 12) & 0x3F];
        encoded[j++] = (i > input_len + 1) ? '=' : b64_table[(triple >> 6) & 0x3F];
        encoded[j++] = (i > input_len) ? '=' : b64_table[triple & 0x3F];
    }
    encoded[output_len] = '\0';
    VSS_Value res = vss_value_new_string(encoded);
    free(encoded);
    return res;
}

static VSS_Value builtin_encoding_base64_decode(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("base64_decode expects a base64 encoded string"); return vss_value_new_empty();
    }
    const char *data = args[0].as.string->chars;
    size_t input_len = strlen(data);
    if (input_len % 4 != 0) {
        *out_error = true; *out_error_msg = safe_strdup("invalid base64 string length"); return vss_value_new_empty();
    }
    
    int d_table[256];
    memset(d_table, -1, sizeof(d_table));
    for (int i = 0; i < 64; i++) d_table[(unsigned char)b64_table[i]] = i;

    size_t output_len = input_len / 4 * 3;
    if (input_len > 0 && data[input_len - 1] == '=') output_len--;
    if (input_len > 1 && data[input_len - 2] == '=') output_len--;

    char *decoded = malloc(output_len + 1);
    for (size_t i = 0, j = 0; i < input_len;) {
        uint32_t sextet_a = data[i] == '=' ? 0 & i++ : d_table[(unsigned char)data[i++]];
        uint32_t sextet_b = data[i] == '=' ? 0 & i++ : d_table[(unsigned char)data[i++]];
        uint32_t sextet_c = data[i] == '=' ? 0 & i++ : d_table[(unsigned char)data[i++]];
        uint32_t sextet_d = data[i] == '=' ? 0 & i++ : d_table[(unsigned char)data[i++]];
        uint32_t triple = (sextet_a << 18) + (sextet_b << 12) + (sextet_c << 6) + sextet_d;

        if (j < output_len) decoded[j++] = (triple >> 16) & 0xFF;
        if (j < output_len) decoded[j++] = (triple >> 8) & 0xFF;
        if (j < output_len) decoded[j++] = triple & 0xFF;
    }
    decoded[output_len] = '\0';
    VSS_Value res = vss_value_new_string(decoded);
    free(decoded);
    return res;
}

static VSS_Value builtin_encoding_hex_encode(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("hex_encode expects a string"); return vss_value_new_empty();
    }
    const char *s = args[0].as.string->chars;
    size_t len = strlen(s);
    char *hex = malloc(len * 2 + 1);
    for (size_t i = 0; i < len; i++) {
        sprintf(hex + i * 2, "%02x", (unsigned char)s[i]);
    }
    hex[len * 2] = '\0';
    VSS_Value res = vss_value_new_string(hex);
    free(hex);
    return res;
}

static VSS_Value builtin_encoding_hex_decode(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("hex_decode expects a hex string"); return vss_value_new_empty();
    }
    const char *hex = args[0].as.string->chars;
    size_t len = strlen(hex);
    if (len % 2 != 0) {
        *out_error = true; *out_error_msg = safe_strdup("hex string length must be even"); return vss_value_new_empty();
    }
    char *out = malloc(len / 2 + 1);
    for (size_t i = 0; i < len / 2; i++) {
        unsigned int byte_val;
        sscanf(hex + i * 2, "%02x", &byte_val);
        out[i] = (char)byte_val;
    }
    out[len / 2] = '\0';
    VSS_Value res = vss_value_new_string(out);
    free(out);
    return res;
}

// ─────────────────────────────────────────────────────────────────────────────
// CROSS-PLATFORM PATH BUILTINS
// ─────────────────────────────────────────────────────────────────────────────
static VSS_Value builtin_path_join(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1) {
        *out_error = true; *out_error_msg = safe_strdup("path_join expects path strings"); return vss_value_new_empty();
    }
    char buf[1024] = "";
    for (size_t i = 0; i < arg_count; i++) {
        if (args[i].type != VSS_VAL_STRING) continue;
        const char *part = args[i].as.string->chars;
        if (i > 0 && buf[0] != '\0') {
            size_t blen = strlen(buf);
            if (buf[blen - 1] != '/' && buf[blen - 1] != '\\') {
                strcat(buf, "/");
            }
        }
        strcat(buf, part);
    }
    return vss_value_new_string(buf);
}

static VSS_Value builtin_path_basename(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("basename expects path string"); return vss_value_new_empty();
    }
    const char *path = args[0].as.string->chars;
    const char *p1 = strrchr(path, '/');
    const char *p2 = strrchr(path, '\\');
    const char *last = p1 > p2 ? p1 : p2;
    if (last) return vss_value_new_string(last + 1);
    return vss_value_new_string(path);
}

static VSS_Value builtin_path_dirname(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("dirname expects path string"); return vss_value_new_empty();
    }
    const char *path = args[0].as.string->chars;
    const char *p1 = strrchr(path, '/');
    const char *p2 = strrchr(path, '\\');
    const char *last = p1 > p2 ? p1 : p2;
    if (!last) return vss_value_new_string(".");
    size_t len = last - path;
    if (len == 0) return vss_value_new_string("/");
    char *dir = malloc(len + 1);
    memcpy(dir, path, len);
    dir[len] = '\0';
    VSS_Value res = vss_value_new_string(dir);
    free(dir);
    return res;
}

static VSS_Value builtin_path_ext(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("ext expects path string"); return vss_value_new_empty();
    }
    const char *path = args[0].as.string->chars;
    const char *dot = strrchr(path, '.');
    if (!dot) return vss_value_new_string("");
    return vss_value_new_string(dot);
}

static VSS_Value builtin_path_is_file(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("is_file expects path string"); return vss_value_new_empty();
    }
    const char *path = args[0].as.string->chars;
    FILE *f = fopen(path, "rb");
    if (f) {
        fclose(f);
        return vss_value_new_bool(true);
    }
    return vss_value_new_bool(false);
}

// ─────────────────────────────────────────────────────────────────────────────
// ADVANCED RANDOM & SAMPLING BUILTINS
// ─────────────────────────────────────────────────────────────────────────────
static VSS_Value builtin_random_randint(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_NUMBER || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("randint expects min and max numbers"); return vss_value_new_empty();
    }
    int min_val = (int)args[0].as.number;
    int max_val = (int)args[1].as.number;
    if (min_val > max_val) { int t = min_val; min_val = max_val; max_val = t; }
    int range = max_val - min_val + 1;
    int val = min_val + (rand() % (range > 0 ? range : 1));
    return vss_value_new_number((double)val);
}

static VSS_Value builtin_random_choice(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_LIST) {
        *out_error = true; *out_error_msg = safe_strdup("choice expects a list"); return vss_value_new_empty();
    }
    VSS_ValList *l = args[0].as.list;
    if (l->count == 0) return vss_value_new_empty();
    size_t idx = (size_t)rand() % l->count;
    return l->items[idx];
}

static VSS_Value builtin_random_shuffle(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_LIST) {
        *out_error = true; *out_error_msg = safe_strdup("shuffle expects a list"); return vss_value_new_empty();
    }
    VSS_ValList *src = args[0].as.list;
    VSS_Value list = vss_value_new_list();
    VSS_ValList *l = list.as.list;
    l->items = malloc(sizeof(VSS_Value) * src->count);
    l->count = src->count;
    l->capacity = src->count;
    for (size_t i = 0; i < src->count; i++) {
        l->items[i] = src->items[i];
        vss_value_retain(l->items[i]);
    }
    for (size_t i = l->count - 1; i > 0; i--) {
        size_t j = (size_t)rand() % (i + 1);
        VSS_Value tmp = l->items[i];
        l->items[i] = l->items[j];
        l->items[j] = tmp;
    }
    return list;
}

static VSS_Value builtin_random_seed(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("seed expects a number"); return vss_value_new_empty();
    }
    srand((unsigned int)args[0].as.number);
    return vss_value_new_empty();
}

// ─────────────────────────────────────────────────────────────────────────────
// DATETIME BUILTINS
// ─────────────────────────────────────────────────────────────────────────────
static VSS_Value builtin_datetime_now(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)arg_count; (void)args; (void)out_error; (void)out_error_msg;
    time_t rawtime;
    struct tm *info;
    char buffer[80];
    time(&rawtime);
    info = localtime(&rawtime);
    strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", info);
    return vss_value_new_string(buffer);
}

static VSS_Value builtin_datetime_timestamp(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)arg_count; (void)args; (void)out_error; (void)out_error_msg;
    time_t rawtime;
    time(&rawtime);
    return vss_value_new_number((double)rawtime);
}

// ─────────────────────────────────────────────────────────────────────────────
// SEQUENCE SLICING & ADVANCED OPERATIONS
// ─────────────────────────────────────────────────────────────────────────────
static VSS_Value builtin_list_slice(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_LIST || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("list_slice expects list and start index"); return vss_value_new_empty();
    }
    VSS_ValList *src = args[0].as.list;
    int start = (int)args[1].as.number;
    int end = arg_count >= 3 && args[2].type == VSS_VAL_NUMBER ? (int)args[2].as.number : (int)src->count;
    
    if (start < 0) start = (int)src->count + start;
    if (start < 0) start = 0;
    if (end < 0) end = (int)src->count + end;
    if (end > (int)src->count) end = (int)src->count;
    if (start > end) start = end;

    VSS_Value res = vss_value_new_list();
    VSS_ValList *l = res.as.list;
    size_t count = end - start;
    l->items = malloc(sizeof(VSS_Value) * count);
    l->count = count;
    l->capacity = count;
    for (size_t i = 0; i < count; i++) {
        l->items[i] = src->items[start + i];
        vss_value_retain(l->items[i]);
    }
    return res;
}

static VSS_Value builtin_list_contains(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_LIST) {
        *out_error = true; *out_error_msg = safe_strdup("contains expects list and search item"); return vss_value_new_empty();
    }
    VSS_ValList *src = args[0].as.list;
    VSS_Value item = args[1];
    for (size_t i = 0; i < src->count; i++) {
        if (src->items[i].type == item.type) {
            if (item.type == VSS_VAL_NUMBER && src->items[i].as.number == item.as.number) return vss_value_new_bool(true);
            if (item.type == VSS_VAL_STRING && strcmp(src->items[i].as.string->chars, item.as.string->chars) == 0) return vss_value_new_bool(true);
            if (item.type == VSS_VAL_BOOL && src->items[i].as.boolean == item.as.boolean) return vss_value_new_bool(true);
        }
    }
    return vss_value_new_bool(false);
}

static VSS_Value builtin_list_unique(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_LIST) {
        *out_error = true; *out_error_msg = safe_strdup("unique expects a list"); return vss_value_new_empty();
    }
    VSS_ValList *src = args[0].as.list;
    VSS_Value res = vss_value_new_list();
    VSS_ValList *l = res.as.list;
    for (size_t i = 0; i < src->count; i++) {
        VSS_Value check_args[2] = { res, src->items[i] };
        VSS_Value has_item = builtin_list_contains(2, check_args, out_error, out_error_msg);
        if (!has_item.as.boolean) {
            if (l->count >= l->capacity) {
                l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
                l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
            }
            l->items[l->count++] = src->items[i];
            vss_value_retain(src->items[i]);
        }
    }
    return res;
}

static VSS_Value builtin_string_slice(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    return builtin_string_substring(arg_count, args, out_error, out_error_msg);
}

// ─────────────────────────────────────────────────────────────────────────────
// REGEX PATTERN MATCHING & SUBSTITUTION
// ─────────────────────────────────────────────────────────────────────────────
static VSS_Value builtin_regex_search(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("regex_search expects pattern and text strings"); return vss_value_new_empty();
    }
    const char *pattern = args[0].as.string->chars;
    const char *text = args[1].as.string->chars;
    const char *found = strstr(text, pattern);
    if (found) {
        return vss_value_new_string(pattern);
    }
    return vss_value_new_string("");
}

static VSS_Value builtin_regex_match(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("regex_match expects pattern and text strings"); return vss_value_new_empty();
    }
    const char *pattern = args[0].as.string->chars;
    const char *text = args[1].as.string->chars;
    return vss_value_new_bool(strstr(text, pattern) != NULL);
}

static VSS_Value builtin_regex_replace(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    return builtin_string_replace(arg_count, args, out_error, out_error_msg);
}

// JSON Builtins
static VSS_Value builtin_json_read(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("json.read expects file path string"); return vss_value_new_empty();
    }
    VSS_Value content = builtin_read(1, args, out_error, out_error_msg);
    if (*out_error) return vss_value_new_empty();
    
    VSS_Value val = vss_json_parse(content.as.string->chars, out_error, out_error_msg);
    vss_value_release(content);
    return val;
}

static VSS_Value builtin_json_write(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("json.write expects file path and value"); return vss_value_new_empty();
    }
    char *serialized = vss_json_serialize(args[1]);
    VSS_Value write_args[2] = { vss_value_new_string(serialized), args[0] };
    free(serialized);
    VSS_Value res = builtin_write(2, write_args, out_error, out_error_msg);
    vss_value_release(write_args[0]);
    return res;
}

static VSS_Value builtin_json_parse(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("json.parse expects string"); return vss_value_new_empty();
    }
    return vss_json_parse(args[0].as.string->chars, out_error, out_error_msg);
}

static VSS_Value builtin_json_stringify(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1) {
        *out_error = true; *out_error_msg = safe_strdup("json.stringify expects value"); return vss_value_new_empty();
    }
    char *serialized = vss_json_serialize(args[0]);
    VSS_Value res = vss_value_new_string(serialized);
    free(serialized);
    return res;
}

// HTTP Subprocess curl Builtin
static VSS_Value builtin_http_request(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    // args: [method, url, headers_map, body]
    if (arg_count != 4 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_STRING ||
        args[2].type != VSS_VAL_MAP || args[3].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("http_request expects method, url, headers, and body"); return vss_value_new_empty();
    }
    
    const char *method = args[0].as.string->chars;
    const char *url = args[1].as.string->chars;
    VSS_ValMap *headers = args[2].as.map;
    const char *body = args[3].as.string->chars;
    
    // Write body to a temporary file
    FILE *f_body = fopen("vss_temp_req_body.txt", "wb");
    if (f_body) {
        fwrite(body, 1, strlen(body), f_body);
        fclose(f_body);
    }
    
    // Construct command
    char cmd[4096];
    sprintf(cmd, "curl -s -X %s --data-binary @vss_temp_req_body.txt ", method);
    
    // Append headers
    for (size_t i = 0; i < headers->count; i++) {
        char *val_str = vss_value_to_string(headers->entries[i].value);
        char header_flag[512];
        snprintf(header_flag, sizeof(header_flag), "-H \"%s: %s\" ", headers->entries[i].key, val_str);
        strcat(cmd, header_flag);
        free(val_str);
    }
    
    // output body and header files
    strcat(cmd, "-o vss_temp_res_body.txt -D vss_temp_res_headers.txt ");
    // Append URL
    strcat(cmd, "\"");
    strcat(cmd, url);
    strcat(cmd, "\"");
    
    vss_execute_cmd(cmd);
    
    remove("vss_temp_req_body.txt");
    
    // Read status code and headers
    int status_code = 500;
    VSS_Value headers_map = vss_value_new_map();
    FILE *f_h = fopen("vss_temp_res_headers.txt", "r");
    if (f_h) {
        char line[512];
        if (fgets(line, sizeof(line), f_h)) {
            // Read HTTP/1.1 200 OK
            sscanf(line, "%*s %d", &status_code);
        }
        while (fgets(line, sizeof(line), f_h)) {
            char *colon = strchr(line, ':');
            if (colon) {
                *colon = '\0';
                char *val = colon + 1;
                while (*val && isspace((unsigned char)*val)) val++;
                int v_len = strlen(val);
                while (v_len > 0 && isspace((unsigned char)val[v_len-1])) {
                    val[v_len-1] = '\0';
                    v_len--;
                }
                
                VSS_Value v_val = vss_value_new_string(val);
                VSS_ValMap *m = headers_map.as.map;
                m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * (m->count + 1));
                m->entries[m->count].key = safe_strdup(line);
                m->entries[m->count].value = v_val;
                vss_value_retain(v_val);
                m->count++;
                vss_value_release(v_val);
            }
        }
        fclose(f_h);
    }
    remove("vss_temp_res_headers.txt");
    
    // Read body
    char *res_body_str = "";
    FILE *f_b = fopen("vss_temp_res_body.txt", "rb");
    if (f_b) {
        fseek(f_b, 0, SEEK_END);
        long sz = ftell(f_b);
        rewind(f_b);
        char *buf = malloc(sz + 1);
        size_t rb = fread(buf, 1, sz, f_b);
        buf[rb] = '\0';
        fclose(f_b);
        res_body_str = buf;
    }
    remove("vss_temp_res_body.txt");
    
    VSS_Value response = vss_value_new_map();
    VSS_ValMap *resp_m = response.as.map;
    
    VSS_Value status_val = vss_value_new_number(status_code);
    VSS_Value body_val = vss_value_new_string(res_body_str);
    if (strlen(res_body_str) > 0) free(res_body_str);
    
    resp_m->entries = realloc(resp_m->entries, sizeof(VSS_ValMapEntry) * 3);
    resp_m->entries[0].key = safe_strdup("status");
    resp_m->entries[0].value = status_val;
    vss_value_retain(status_val);
    resp_m->entries[1].key = safe_strdup("body");
    resp_m->entries[1].value = body_val;
    vss_value_retain(body_val);
    resp_m->entries[2].key = safe_strdup("headers");
    resp_m->entries[2].value = headers_map;
    vss_value_retain(headers_map);
    resp_m->count = 3;
    
    vss_value_release(status_val);
    vss_value_release(body_val);
    vss_value_release(headers_map);
    
    return response;
}

// Database SQLite dynamic loader Builtins
static VSS_Value builtin_db_open(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("database.open expects file path string"); return vss_value_new_empty();
    }
    load_sqlite();
    VssDatabase *db = malloc(sizeof(VssDatabase));
    db->filepath = safe_strdup(args[0].as.string->chars);
    db->real_db = NULL;
    db->is_mock = !sqlite_loaded;
    
    if (!db->is_mock) {
        int rc = p_sqlite3_open(db->filepath, &db->real_db);
        if (rc != 0) {
            *out_error = true;
            *out_error_msg = safe_strdup("Could not open real SQLite database");
            free(db->filepath);
            free(db);
            return vss_value_new_empty();
        }
    }
    
    // We package the database wrapper object inside a list containing [is_mock, filepath, real_db_ptr]
    VSS_Value db_val = vss_value_new_list();
    VSS_ValList *l = db_val.as.list;
    l->items = malloc(sizeof(VSS_Value) * 3);
    l->items[0] = vss_value_new_bool(db->is_mock);
    l->items[1] = vss_value_new_string(db->filepath);
    l->items[2] = vss_value_new_number((double)(uintptr_t)db);
    l->count = 3;
    l->capacity = 3;
    return db_val;
}

static VSS_Value builtin_db_execute(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_LIST || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("__db_execute expects db_handle and sql"); return vss_value_new_empty();
    }
    VSS_ValList *l = args[0].as.list;
    VssDatabase *db = (VssDatabase*)(uintptr_t)l->items[2].as.number;
    const char *sql = args[1].as.string->chars;
    
    if (db->is_mock) {
        return mock_db_execute(db, sql, out_error_msg);
    } else {
        char *errmsg = NULL;
        int rc = p_sqlite3_exec(db->real_db, sql, NULL, NULL, &errmsg);
        if (rc != 0) {
            *out_error = true;
            *out_error_msg = safe_strdup(errmsg ? errmsg : "SQLite exec failed");
            return vss_value_new_empty();
        }
        return vss_value_new_bool(true);
    }
}

static VSS_Value builtin_db_query(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_LIST || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("__db_query expects db_handle and sql"); return vss_value_new_empty();
    }
    VSS_ValList *l = args[0].as.list;
    VssDatabase *db = (VssDatabase*)(uintptr_t)l->items[2].as.number;
    const char *sql = args[1].as.string->chars;
    
    if (db->is_mock) {
        return mock_db_query(db, sql, out_error_msg);
    } else {
        sqlite3_stmt *stmt = NULL;
        int rc = p_sqlite3_prepare_v2(db->real_db, sql, -1, &stmt, NULL);
        if (rc != 0) {
            *out_error = true;
            *out_error_msg = safe_strdup("SQLite query preparation failed");
            return vss_value_new_empty();
        }
        
        VSS_Value list = vss_value_new_list();
        VSS_ValList *dest = list.as.list;
        
        int col_count = p_sqlite3_column_count(stmt);
        while (p_sqlite3_step(stmt) == 100) { // SQLITE_ROW
            VSS_Value row = vss_value_new_map();
            VSS_ValMap *m = row.as.map;
            for (int i = 0; i < col_count; i++) {
                const char *name = p_sqlite3_column_name(stmt, i);
                const char *text = (const char*)p_sqlite3_column_text(stmt, i);
                
                VSS_Value text_val = vss_value_new_string(text ? text : "");
                m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * (m->count + 1));
                m->entries[m->count].key = safe_strdup(name);
                m->entries[m->count].value = text_val;
                vss_value_retain(text_val);
                m->count++;
                vss_value_release(text_val);
            }
            if (dest->count >= dest->capacity) {
                dest->capacity = dest->capacity == 0 ? 8 : dest->capacity * 2;
                dest->items = realloc(dest->items, sizeof(VSS_Value) * dest->capacity);
            }
            dest->items[dest->count++] = row;
            vss_value_retain(row);
            vss_value_release(row);
        }
        p_sqlite3_finalize(stmt);
        return list;
    }
}

// Time Builtins
static VSS_Value builtin_time_now(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)args; (void)arg_count; (void)out_error; (void)out_error_msg;
    return vss_value_new_number((double)time(NULL));
}

static VSS_Value builtin_time_sleep(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true; *out_error_msg = safe_strdup("sleep expects seconds number"); return vss_value_new_empty();
    }
    double sec = args[0].as.number;
#ifdef _WIN32
    Sleep((DWORD)(sec * 1000.0));
#else
    usleep((unsigned int)(sec * 1000000.0));
#endif
    return vss_value_new_empty();
}

static VSS_Value builtin_time_format(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_NUMBER || args[1].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("time.format expects timestamp and format string"); return vss_value_new_empty();
    }
    time_t ts = (time_t)args[0].as.number;
    const char *fmt = args[1].as.string->chars;
    struct tm *tm_info = localtime(&ts);
    char buf[128];
    strftime(buf, sizeof(buf), fmt, tm_info);
    return vss_value_new_string(buf);
}

// Random Builtins
static VSS_Value builtin_random_number(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)args; (void)arg_count; (void)out_error; (void)out_error_msg;
    static bool seeded = false;
    if (!seeded) { srand((unsigned int)time(NULL)); seeded = true; }
    double r = (double)rand() / (double)RAND_MAX;
    return vss_value_new_number(r);
}

// System Builtins
static int global_argc = 0;
static char **global_argv = NULL;

void vss_set_args(int argc, char **argv) {
    global_argc = argc;
    global_argv = argv;
}

static VSS_Value builtin_system_args(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)args; (void)arg_count; (void)out_error; (void)out_error_msg;
    VSS_Value list = vss_value_new_list();
    VSS_ValList *l = list.as.list;
    l->items = malloc(sizeof(VSS_Value) * global_argc);
    l->count = global_argc;
    l->capacity = global_argc;
    for (int i = 0; i < global_argc; i++) {
        l->items[i] = vss_value_new_string(global_argv[i]);
    }
    return list;
}

static VSS_Value builtin_system_env(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("env expects environment variable name string"); return vss_value_new_empty();
    }
    const char *val = getenv(args[0].as.string->chars);
    return vss_value_new_string(val ? val : "");
}

static VSS_Value builtin_system_exit(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)out_error;
    (void)out_error_msg;
    int code = 0;
    if (arg_count == 1 && args[0].type == VSS_VAL_NUMBER) {
        code = (int)args[0].as.number;
    }
    exit(code);
    return vss_value_new_empty();
}

static VSS_Value builtin_system_platform(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)args; (void)arg_count; (void)out_error; (void)out_error_msg;
#ifdef _WIN32
    return vss_value_new_string("windows");
#elif __APPLE__
    return vss_value_new_string("macos");
#else
    return vss_value_new_string("linux");
#endif
}

static VSS_Value builtin_system_run(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("system.run expects shell command string"); return vss_value_new_empty();
    }
    // Runs shell command, capture stdout in a string and return it
    const char *cmd = args[0].as.string->chars;
    FILE *pf = popen(cmd, "r");
    if (!pf) {
        *out_error = true; *out_error_msg = safe_strdup("Failed to run shell command"); return vss_value_new_empty();
    }
    char *buf = NULL;
    size_t len = 0;
    size_t cap = 0;
    char line[512];
    while (fgets(line, sizeof(line), pf)) {
        append_str(&buf, &len, &cap, line);
    }
    pclose(pf);
    VSS_Value res = vss_value_new_string(buf ? buf : "");
    if (buf) free(buf);
    return res;
}

// Crypto Builtins
static VSS_Value builtin_crypto_md5(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("md5 expects text string"); return vss_value_new_empty();
    }
    const char *text = args[0].as.string->chars;
    uint8_t digest[16];
    md5((const uint8_t*)text, strlen(text), digest);
    
    char hex[33];
    for (int i = 0; i < 16; i++) {
        sprintf(hex + i*2, "%02x", digest[i]);
    }
    return vss_value_new_string(hex);
}

static VSS_Value builtin_crypto_sha256(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("sha256 expects text string"); return vss_value_new_empty();
    }
    const char *text = args[0].as.string->chars;
    uint8_t digest[32];
    sha256((const uint8_t*)text, strlen(text), digest);
    
    char hex[65];
    for (int i = 0; i < 32; i++) {
        sprintf(hex + i*2, "%02x", digest[i]);
    }
    return vss_value_new_string(hex);
}

// Network Builtins
static VSS_Value builtin_network_resolve(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("resolve expects hostname string"); return vss_value_new_empty();
    }
    const char *host = args[0].as.string->chars;
    struct addrinfo hints, *infoptr;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    
    int result = getaddrinfo(host, NULL, &hints, &infoptr);
    if (result != 0) {
        return vss_value_new_string("");
    }
    
    char ip[64] = {0};
    getnameinfo(infoptr->ai_addr, infoptr->ai_addrlen, ip, sizeof(ip), NULL, 0, NI_NUMERICHOST);
    freeaddrinfo(infoptr);
    return vss_value_new_string(ip);
}

static VSS_Value builtin_network_ping(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true; *out_error_msg = safe_strdup("ping expects host string"); return vss_value_new_empty();
    }
    // Runs shell ping command based on platform
    const char *host = args[0].as.string->chars;
    char cmd[512];
#ifdef _WIN32
    snprintf(cmd, sizeof(cmd), "ping -n 1 -w 1000 %s >nul 2>&1", host);
#else
    snprintf(cmd, sizeof(cmd), "ping -c 1 -W 1 %s >/dev/null 2>&1", host);
#endif
    int res = vss_execute_cmd(cmd);
    return vss_value_new_bool(res == 0);
}

// VSS Size built-in (generic list/map/string length helper)
static VSS_Value builtin_size(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1) {
        *out_error = true; *out_error_msg = safe_strdup("size of expects exactly 1 argument"); return vss_value_new_empty();
    }
    VSS_Value val = args[0];
    if (val.type == VSS_VAL_LIST) {
        return vss_value_new_number(val.as.list->count);
    } else if (val.type == VSS_VAL_MAP) {
        return vss_value_new_number(val.as.map->count);
    } else if (val.type == VSS_VAL_STRING) {
        return vss_value_new_number(strlen(val.as.string->chars));
    } else {
        *out_error = true; *out_error_msg = safe_strdup("size of expects a list, map, or string"); return vss_value_new_empty();
    }
}

extern VSS_VM *current_vm_instance;
extern VSS_VM *vss_resume_vm;
extern VSS_VM *vss_yield_target;

static VSS_Value builtin_generator_create(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_CLOSURE) {
        *out_error = true;
        *out_error_msg = safe_strdup("generator_create expects a closure.");
        return vss_value_new_empty();
    }
    
    VSS_VM *calling_vm = current_vm_instance;
    VSS_VM *gen_vm = malloc(sizeof(VSS_VM));
    VSS_Env *globals = calling_vm ? calling_vm->globals : NULL;
    vss_vm_init(gen_vm, globals);
    gen_vm->prev_vm_instance = NULL;
    
    gen_vm->stack[0] = args[0];
    vss_value_retain(args[0]);
    
    for (size_t i = 1; i < arg_count; i++) {
        gen_vm->stack[i] = args[i];
        vss_value_retain(args[i]);
    }
    gen_vm->stack_top = gen_vm->stack + arg_count;
    
    VSS_CallFrame *frame = &gen_vm->frames[gen_vm->frame_count++];
    frame->closure = args[0].as.closure;
    frame->ip = args[0].as.closure->function->chunk.code;
    frame->slots = gen_vm->stack;
    
    current_vm_instance = calling_vm;
    
    double ptr_num = (double)(uintptr_t)gen_vm;
    return vss_value_new_number(ptr_num);
}

static VSS_Value builtin_generator_next(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true;
        *out_error_msg = safe_strdup("generator_next expects a generator pointer.");
        return vss_value_new_empty();
    }
    
    VSS_VM *gen_vm = (VSS_VM*)(uintptr_t)args[0].as.number;
    if (gen_vm->frame_count == 0) {
        return vss_value_new_empty();
    }
    
    gen_vm->prev_vm_instance = current_vm_instance;
    vss_resume_vm = gen_vm;
    vss_yield_target = gen_vm;
    
    vss_vm_run(NULL, NULL);
    
    VSS_Value ret_val = vss_value_new_empty();
    if (gen_vm->yielded) {
        ret_val = *(--gen_vm->stack_top);
    } else {
        ret_val = *(--gen_vm->stack_top);
        vss_vm_free(gen_vm);
        free(gen_vm);
    }
    
    return ret_val;
}
#define MAX_ROUTES 100
typedef struct {
    char *path;
    VSS_ObjClosure *handler;
} VSS_Route;

static VSS_Route registered_routes[MAX_ROUTES];
static int registered_route_count = 0;

static VSS_Value vss_call_closure(VSS_ObjClosure *closure, int arg_count, VSS_Value *args) {
    VSS_VM *gen_vm = malloc(sizeof(VSS_VM));
    VSS_VM *calling_vm = current_vm_instance;
    VSS_Env *globals = calling_vm ? calling_vm->globals : NULL;
    vss_vm_init(gen_vm, globals);
    gen_vm->prev_vm_instance = calling_vm;
    
    // push closure
    gen_vm->stack[0] = vss_value_new_closure(closure);
    vss_value_retain(gen_vm->stack[0]);
    
    // push args
    for (int i = 0; i < arg_count; i++) {
        gen_vm->stack[i + 1] = args[i];
        vss_value_retain(args[i]);
    }
    gen_vm->stack_top = gen_vm->stack + arg_count + 1;
    
    VSS_CallFrame *frame = &gen_vm->frames[gen_vm->frame_count++];
    frame->closure = closure;
    frame->ip = closure->function->chunk.code;
    frame->slots = gen_vm->stack;
    
    VSS_VM *prev_yield_target = vss_yield_target;
    vss_resume_vm = gen_vm;
    vss_yield_target = gen_vm;
    current_vm_instance = gen_vm;
    
    vss_vm_run(NULL, NULL);
    
    vss_yield_target = prev_yield_target;
    
    VSS_Value ret_val = vss_value_new_empty();
    if (gen_vm->stack_top > gen_vm->stack) {
        ret_val = *(gen_vm->stack_top - 1);
        vss_value_retain(ret_val);
    }
    
    vss_vm_free(gen_vm);
    free(gen_vm);
    
    current_vm_instance = calling_vm;
    return ret_val;
}

static VSS_Value builtin_web_route(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 2 || args[0].type != VSS_VAL_STRING || args[1].type != VSS_VAL_CLOSURE) {
        *out_error = true;
        *out_error_msg = safe_strdup("web.route expects a string path and a closure handler.");
        return vss_value_new_empty();
    }
    
    if (registered_route_count >= MAX_ROUTES) {
        *out_error = true;
        *out_error_msg = safe_strdup("Maximum registered routes exceeded.");
        return vss_value_new_empty();
    }
    
    const char *path = args[0].as.string->chars;
    VSS_ObjClosure *handler = args[1].as.closure;
    
    // Store it
    registered_routes[registered_route_count].path = safe_strdup(path);
    registered_routes[registered_route_count].handler = handler;
    // Retain closure reference so it doesn't get garbage collected
    vss_value_retain(vss_value_new_closure(handler));
    registered_route_count++;
    
    return vss_value_new_empty();
}

static VSS_Value builtin_web_serve(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count != 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true;
        *out_error_msg = safe_strdup("web.serve expects a port number.");
        return vss_value_new_empty();
    }
    
    int port = (int)args[0].as.number;
    
    if (!vss_network_init()) {
        *out_error = true;
        *out_error_msg = safe_strdup("Failed to initialize network system.");
        return vss_value_new_empty();
    }

    VSS_Socket server_fd = vss_socket_create();
    if (server_fd == VSS_INVALID_SOCKET) {
        *out_error = true;
        *out_error_msg = safe_strdup("Failed to create socket.");
        vss_network_cleanup();
        return vss_value_new_empty();
    }
    
    if (!vss_socket_bind(server_fd, port)) {
        *out_error = true;
        *out_error_msg = safe_strdup("Failed to bind socket.");
        vss_socket_close(server_fd);
        vss_network_cleanup();
        return vss_value_new_empty();
    }
    
    if (!vss_socket_listen(server_fd, 10)) {
        *out_error = true;
        *out_error_msg = safe_strdup("Failed to listen on socket.");
        vss_socket_close(server_fd);
        vss_network_cleanup();
        return vss_value_new_empty();
    }
    
    printf("Starting VSS Web Server on port %d...\n", port);
    
    while (1) {
        VSS_Socket client_fd = vss_socket_accept(server_fd);
        if (client_fd == VSS_INVALID_SOCKET) continue;
        
        char buffer[2048];
        int read_bytes = vss_socket_recv(client_fd, buffer, sizeof(buffer) - 1);
        if (read_bytes <= 0) {
            vss_socket_close(client_fd);
            continue;
        }
        buffer[read_bytes] = '\0';
        
        char method[16], path[256];
        if (sscanf(buffer, "%15s %255s", method, path) == 2) {
            // Find handler for this path
            VSS_ObjClosure *handler = NULL;
            for (int i = 0; i < registered_route_count; i++) {
                if (strcmp(registered_routes[i].path, path) == 0) {
                    handler = registered_routes[i].handler;
                    break;
                }
            }
            
            if (handler) {
                size_t param_count = handler->function->param_count;
                VSS_Value *h_args = NULL;
                if (param_count > 0) {
                    VSS_Value req_map = vss_value_new_map();
                    VSS_ValMap *m = req_map.as.map;
                    
                    VSS_Value method_val = vss_value_new_string(method);
                    VSS_Value path_val = vss_value_new_string(path);
                    
                    m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * 2);
                    m->entries[0].key = safe_strdup("method");
                    m->entries[0].value = method_val;
                    vss_value_retain(method_val);
                    m->entries[1].key = safe_strdup("path");
                    m->entries[1].value = path_val;
                    vss_value_retain(path_val);
                    m->count = 2;
                    
                    h_args = malloc(sizeof(VSS_Value) * 1);
                    h_args[0] = req_map;
                    
                    vss_value_release(method_val);
                    vss_value_release(path_val);
                }
                
                VSS_Value res_val = vss_call_closure(handler, (int)param_count, h_args);
                
                if (h_args) {
                    vss_value_release(h_args[0]);
                    free(h_args);
                }
                
                char *res_str = NULL;
                if (res_val.type == VSS_VAL_STRING) {
                    res_str = safe_strdup(res_val.as.string->chars);
                } else {
                    res_str = vss_value_to_string(res_val);
                }
                
                char headers[512];
                snprintf(headers, sizeof(headers), 
                         "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %zu\r\nConnection: close\r\n\r\n", 
                         strlen(res_str));
                vss_socket_send(client_fd, headers, (int)strlen(headers));
                vss_socket_send(client_fd, res_str, (int)strlen(res_str));
                
                free(res_str);
                vss_value_release(res_val);
            } else {
                const char *res_404 = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nRoute Not Found";
                vss_socket_send(client_fd, res_404, (int)strlen(res_404));
            }
        }
        vss_socket_close(client_fd);
    }
    
    vss_socket_close(server_fd);
    vss_network_cleanup();
    return vss_value_new_empty();
}

// Concurrency Builtins
static VSS_Value builtin_concurrency_sleep(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_NUMBER) {
        *out_error = true;
        *out_error_msg = safe_strdup("sleep expects milliseconds number.");
        return vss_value_new_empty();
    }
    int ms = (int)args[0].as.number;
    if (ms > 0) {
        vss_sleep_ms(ms);
    }
    return vss_value_new_empty();
}

static VSS_Value builtin_concurrency_hardware_threads(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)arg_count; (void)args; (void)out_error; (void)out_error_msg;
    return vss_value_new_number((double)vss_get_hardware_concurrency());
}

static VSS_Value builtin_channel_create(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    size_t cap = 0;
    if (arg_count > 0 && args[0].type == VSS_VAL_NUMBER && args[0].as.number > 0) {
        cap = (size_t)args[0].as.number;
    }
    (void)out_error; (void)out_error_msg;
    VSS_Channel *ch = vss_channel_new(cap);
    return vss_value_new_channel(ch);
}

static VSS_Value builtin_channel_send(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_CHANNEL || !args[0].as.channel) {
        *out_error = true;
        *out_error_msg = safe_strdup("channel_send expects channel and value.");
        return vss_value_new_bool(false);
    }
    bool ok = vss_channel_send(args[0].as.channel, args[1]);
    return vss_value_new_bool(ok);
}

static VSS_Value builtin_channel_recv(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_CHANNEL || !args[0].as.channel) {
        *out_error = true;
        *out_error_msg = safe_strdup("channel_receive expects channel.");
        return vss_value_new_empty();
    }
    int timeout_ms = 0;
    if (arg_count > 1 && args[1].type == VSS_VAL_NUMBER) {
        timeout_ms = (int)args[1].as.number;
    }
    VSS_Value out_val = vss_value_new_empty();
    bool closed = false;
    vss_channel_receive(args[0].as.channel, timeout_ms, &out_val, &closed);
    (void)out_error; (void)out_error_msg;
    return out_val;
}

static VSS_Value builtin_channel_close(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_CHANNEL || !args[0].as.channel) {
        *out_error = true;
        *out_error_msg = safe_strdup("channel_close expects channel.");
        return vss_value_new_empty();
    }
    vss_channel_close(args[0].as.channel);
    return vss_value_new_empty();
}

static VSS_Value builtin_mutex_create(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)arg_count; (void)args; (void)out_error; (void)out_error_msg;
    VSS_MutexVal *m = vss_mutex_val_new();
    return vss_value_new_mutex(m);
}

static VSS_Value builtin_mutex_lock(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_MUTEX || !args[0].as.mutex) {
        *out_error = true;
        *out_error_msg = safe_strdup("mutex_lock expects mutex.");
        return vss_value_new_empty();
    }
    vss_mutex_lock(&args[0].as.mutex->lock);
    return vss_value_new_empty();
}

static VSS_Value builtin_mutex_unlock(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_MUTEX || !args[0].as.mutex) {
        *out_error = true;
        *out_error_msg = safe_strdup("mutex_unlock expects mutex.");
        return vss_value_new_empty();
    }
    vss_mutex_unlock(&args[0].as.mutex->lock);
    return vss_value_new_empty();
}

static VSS_Value builtin_atomic_create(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    (void)out_error; (void)out_error_msg;
    int init_val = 0;
    if (arg_count > 0 && args[0].type == VSS_VAL_NUMBER) {
        init_val = (int)args[0].as.number;
    }
    VSS_AtomicVal *a = vss_atomic_val_new(init_val);
    return vss_value_new_atomic(a);
}

static VSS_Value builtin_atomic_get(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_ATOMIC || !args[0].as.atomic) {
        *out_error = true;
        *out_error_msg = safe_strdup("atomic_get expects atomic value.");
        return vss_value_new_number(0);
    }
    int v = vss_atomic_get(&args[0].as.atomic->val);
    return vss_value_new_number((double)v);
}

static VSS_Value builtin_atomic_set(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_ATOMIC || !args[0].as.atomic || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true;
        *out_error_msg = safe_strdup("atomic_set expects atomic value and number.");
        return vss_value_new_empty();
    }
    vss_atomic_set(&args[0].as.atomic->val, (int)args[1].as.number);
    return vss_value_new_empty();
}

static VSS_Value builtin_atomic_add(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_ATOMIC || !args[0].as.atomic || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true;
        *out_error_msg = safe_strdup("atomic_add expects atomic value and delta number.");
        return vss_value_new_number(0);
    }
    int delta = (int)args[1].as.number;
    int old_val = vss_atomic_add(&args[0].as.atomic->val, delta);
    return vss_value_new_number((double)old_val);
}

static VSS_Value builtin_task_cancel(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_TASK_HANDLE || !args[0].as.task_handle) {
        *out_error = true;
        *out_error_msg = safe_strdup("task_cancel expects task handle.");
        return vss_value_new_empty();
    }
    vss_task_cancel(args[0].as.task_handle);
    return vss_value_new_empty();
}

// Helper macro for list append
#define VSS_LIST_PUSH(lst_val, item_val) do { \
    VSS_ValList *__l = (lst_val).as.list; \
    if (__l->count >= __l->capacity) { \
        __l->capacity = __l->capacity == 0 ? 8 : __l->capacity * 2; \
        __l->items = realloc(__l->items, sizeof(VSS_Value) * __l->capacity); \
    } \
    __l->items[__l->count++] = (item_val); \
} while(0)

static VSS_Value builtin_matrix_create(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_NUMBER || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true;
        *out_error_msg = safe_strdup("matrix_create expects rows and columns numbers.");
        return vss_value_new_empty();
    }
    int rows = (int)args[0].as.number;
    int cols = (int)args[1].as.number;
    if (rows <= 0) rows = 1;
    if (cols <= 0) cols = 1;
    double fill = (arg_count >= 3 && args[2].type == VSS_VAL_NUMBER) ? args[2].as.number : 0.0;

    VSS_Value outer = vss_value_new_list();
    for (int r = 0; r < rows; r++) {
        VSS_Value row = vss_value_new_list();
        for (int c = 0; c < cols; c++) {
            VSS_Value num = vss_value_new_number(fill);
            VSS_LIST_PUSH(row, num);
        }
        VSS_LIST_PUSH(outer, row);
    }
    return outer;
}

static VSS_Value builtin_matrix_multiply(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_LIST || args[1].type != VSS_VAL_LIST) {
        *out_error = true;
        *out_error_msg = safe_strdup("matrix_multiply expects two 2D matrix lists.");
        return vss_value_new_empty();
    }
    VSS_ValList *m1 = args[0].as.list;
    VSS_ValList *m2 = args[1].as.list;
    int r1 = (int)m1->count;
    if (r1 == 0 || m1->items[0].type != VSS_VAL_LIST) return vss_value_new_list();
    int c1 = (int)m1->items[0].as.list->count;
    int r2 = (int)m2->count;
    if (r2 == 0 || m2->items[0].type != VSS_VAL_LIST) return vss_value_new_list();
    int c2 = (int)m2->items[0].as.list->count;

    if (c1 != r2) {
        *out_error = true;
        *out_error_msg = safe_strdup("matrix_multiply: inner dimensions must match.");
        return vss_value_new_empty();
    }

    VSS_Value res = vss_value_new_list();
    for (int i = 0; i < r1; i++) {
        VSS_Value row = vss_value_new_list();
        for (int j = 0; j < c2; j++) {
            double sum = 0.0;
            for (int k = 0; k < c1; k++) {
                double val1 = m1->items[i].as.list->items[k].as.number;
                double val2 = m2->items[k].as.list->items[j].as.number;
                sum += val1 * val2;
            }
            VSS_Value num = vss_value_new_number(sum);
            VSS_LIST_PUSH(row, num);
        }
        VSS_LIST_PUSH(res, row);
    }
    return res;
}

static VSS_Value builtin_matrix_add(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_LIST || args[1].type != VSS_VAL_LIST) {
        *out_error = true;
        *out_error_msg = safe_strdup("matrix_add expects two 2D matrix lists.");
        return vss_value_new_empty();
    }
    VSS_ValList *m1 = args[0].as.list;
    VSS_ValList *m2 = args[1].as.list;
    int r = (int)m1->count;
    if (r == 0 || m1->items[0].type != VSS_VAL_LIST) return vss_value_new_list();
    int c = (int)m1->items[0].as.list->count;

    VSS_Value res = vss_value_new_list();
    for (int i = 0; i < r; i++) {
        VSS_Value row = vss_value_new_list();
        for (int j = 0; j < c; j++) {
            double v1 = (i < (int)m1->count && j < (int)m1->items[i].as.list->count) ? m1->items[i].as.list->items[j].as.number : 0.0;
            double v2 = (i < (int)m2->count && j < (int)m2->items[i].as.list->count) ? m2->items[i].as.list->items[j].as.number : 0.0;
            VSS_Value num = vss_value_new_number(v1 + v2);
            VSS_LIST_PUSH(row, num);
        }
        VSS_LIST_PUSH(res, row);
    }
    return res;
}

static VSS_Value builtin_matrix_transpose(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_LIST) {
        *out_error = true;
        *out_error_msg = safe_strdup("matrix_transpose expects 2D matrix list.");
        return vss_value_new_empty();
    }
    VSS_ValList *m = args[0].as.list;
    int r = (int)m->count;
    if (r == 0 || m->items[0].type != VSS_VAL_LIST) return vss_value_new_list();
    int c = (int)m->items[0].as.list->count;

    VSS_Value res = vss_value_new_list();
    for (int j = 0; j < c; j++) {
        VSS_Value row = vss_value_new_list();
        for (int i = 0; i < r; i++) {
            VSS_Value num = vss_value_new_number(m->items[i].as.list->items[j].as.number);
            VSS_LIST_PUSH(row, num);
        }
        VSS_LIST_PUSH(res, row);
    }
    return res;
}

static VSS_Value builtin_matrix_dot(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_LIST || args[1].type != VSS_VAL_LIST) {
        *out_error = true;
        *out_error_msg = safe_strdup("matrix_dot expects two vector lists.");
        return vss_value_new_number(0);
    }
    VSS_ValList *v1 = args[0].as.list;
    VSS_ValList *v2 = args[1].as.list;
    size_t count = v1->count < v2->count ? v1->count : v2->count;
    double sum = 0.0;
    for (size_t i = 0; i < count; i++) {
        double a = (v1->items[i].type == VSS_VAL_NUMBER) ? v1->items[i].as.number : 0.0;
        double b = (v2->items[i].type == VSS_VAL_NUMBER) ? v2->items[i].as.number : 0.0;
        sum += a * b;
    }
    return vss_value_new_number(sum);
}

static VSS_Value builtin_matrix_scale(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_LIST || args[1].type != VSS_VAL_NUMBER) {
        *out_error = true;
        *out_error_msg = safe_strdup("matrix_scale expects 2D matrix list and scalar number.");
        return vss_value_new_empty();
    }
    VSS_ValList *m = args[0].as.list;
    double factor = args[1].as.number;
    int r = (int)m->count;
    if (r == 0 || m->items[0].type != VSS_VAL_LIST) return vss_value_new_list();
    int c = (int)m->items[0].as.list->count;

    VSS_Value res = vss_value_new_list();
    for (int i = 0; i < r; i++) {
        VSS_Value row = vss_value_new_list();
        for (int j = 0; j < c; j++) {
            VSS_Value num = vss_value_new_number(m->items[i].as.list->items[j].as.number * factor);
            VSS_LIST_PUSH(row, num);
        }
        VSS_LIST_PUSH(res, row);
    }
    return res;
}

static VSS_Value builtin_ffi_open(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 1 || args[0].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("ffi_open expects dynamic library path string.");
        return vss_value_new_number(0);
    }
    void *handle = vss_dl_open(args[0].as.string->chars);
    return vss_value_new_number((double)(uintptr_t)handle);
}

static VSS_Value builtin_ffi_call(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count < 2 || args[0].type != VSS_VAL_NUMBER || args[1].type != VSS_VAL_STRING) {
        *out_error = true;
        *out_error_msg = safe_strdup("ffi_call expects handle number and symbol string.");
        return vss_value_new_empty();
    }
    void *handle = (void *)(uintptr_t)(size_t)args[0].as.number;
    const char *sym = args[1].as.string->chars;
    void *fn = vss_dl_sym(handle, sym);
    if (!fn) {
        return vss_value_new_bool(false);
    }
    return vss_value_new_bool(true);
}

static VSS_Value builtin_ffi_close(size_t arg_count, VSS_Value *args, bool *out_error, char **out_error_msg) {
    if (arg_count >= 1 && args[0].type == VSS_VAL_NUMBER) {
        void *handle = (void *)(uintptr_t)(size_t)args[0].as.number;
        vss_dl_close(handle);
    }
    return vss_value_new_empty();
}


// ─────────────────────────────────────────────────────────────────────────────
// REGISTRATION
// ─────────────────────────────────────────────────────────────────────────────
void vss_register_builtins(VSS_Env *env) {
    vss_env_define(env, "__concurrency_sleep", vss_value_new_native(builtin_concurrency_sleep));
    vss_env_define(env, "__concurrency_hardware_threads", vss_value_new_native(builtin_concurrency_hardware_threads));
    vss_env_define(env, "__channel_create", vss_value_new_native(builtin_channel_create));
    vss_env_define(env, "__channel_send", vss_value_new_native(builtin_channel_send));
    vss_env_define(env, "__channel_recv", vss_value_new_native(builtin_channel_recv));
    vss_env_define(env, "__channel_close", vss_value_new_native(builtin_channel_close));
    vss_env_define(env, "__mutex_create", vss_value_new_native(builtin_mutex_create));
    vss_env_define(env, "__mutex_lock", vss_value_new_native(builtin_mutex_lock));
    vss_env_define(env, "__mutex_unlock", vss_value_new_native(builtin_mutex_unlock));
    vss_env_define(env, "__atomic_create", vss_value_new_native(builtin_atomic_create));
    vss_env_define(env, "__atomic_get", vss_value_new_native(builtin_atomic_get));
    vss_env_define(env, "__atomic_set", vss_value_new_native(builtin_atomic_set));
    vss_env_define(env, "__atomic_add", vss_value_new_native(builtin_atomic_add));
    vss_env_define(env, "__task_cancel", vss_value_new_native(builtin_task_cancel));

    // Also register aliases under stdlib module names: thread, channel, mutex, atomic, task
    vss_env_define(env, "thread_sleep", vss_value_new_native(builtin_concurrency_sleep));
    vss_env_define(env, "thread_hardware_threads", vss_value_new_native(builtin_concurrency_hardware_threads));
    vss_env_define(env, "concurrency_sleep", vss_value_new_native(builtin_concurrency_sleep));
    vss_env_define(env, "concurrency_hardware_threads", vss_value_new_native(builtin_concurrency_hardware_threads));
    vss_env_define(env, "channel_new", vss_value_new_native(builtin_channel_create));
    vss_env_define(env, "channel_create", vss_value_new_native(builtin_channel_create));
    vss_env_define(env, "channel_send", vss_value_new_native(builtin_channel_send));
    vss_env_define(env, "channel_recv", vss_value_new_native(builtin_channel_recv));
    vss_env_define(env, "channel_receive", vss_value_new_native(builtin_channel_recv));
    vss_env_define(env, "channel_close", vss_value_new_native(builtin_channel_close));
    vss_env_define(env, "mutex_new", vss_value_new_native(builtin_mutex_create));
    vss_env_define(env, "mutex_create", vss_value_new_native(builtin_mutex_create));
    vss_env_define(env, "mutex_lock", vss_value_new_native(builtin_mutex_lock));
    vss_env_define(env, "mutex_unlock", vss_value_new_native(builtin_mutex_unlock));
    vss_env_define(env, "atomic_new", vss_value_new_native(builtin_atomic_create));
    vss_env_define(env, "atomic_create", vss_value_new_native(builtin_atomic_create));
    vss_env_define(env, "atomic_get", vss_value_new_native(builtin_atomic_get));
    vss_env_define(env, "atomic_set", vss_value_new_native(builtin_atomic_set));
    vss_env_define(env, "atomic_add", vss_value_new_native(builtin_atomic_add));
    vss_env_define(env, "task_cancel", vss_value_new_native(builtin_task_cancel));

    vss_env_define(env, "__size", vss_value_new_native(builtin_size));
    vss_env_define(env, "__exists", vss_value_new_native(builtin_exists));
    vss_env_define(env, "__read", vss_value_new_native(builtin_read));
    vss_env_define(env, "__write", vss_value_new_native(builtin_write));
    vss_env_define(env, "__add", vss_value_new_native(builtin_add));
    vss_env_define(env, "__erase", vss_value_new_native(builtin_erase));
    vss_env_define(env, "__file_list", vss_value_new_native(builtin_file_list));
    vss_env_define(env, "__make_dir", vss_value_new_native(builtin_make_dir));

    // Math
    vss_env_define(env, "__math_sin", vss_value_new_native(builtin_math_sin));
    vss_env_define(env, "__math_cos", vss_value_new_native(builtin_math_cos));
    vss_env_define(env, "__math_tan", vss_value_new_native(builtin_math_tan));
    vss_env_define(env, "__math_sqrt", vss_value_new_native(builtin_math_sqrt));
    vss_env_define(env, "__math_log", vss_value_new_native(builtin_math_log));
    vss_env_define(env, "__math_ceil", vss_value_new_native(builtin_math_ceil));
    vss_env_define(env, "__math_floor", vss_value_new_native(builtin_math_floor));
    vss_env_define(env, "__math_pow", vss_value_new_native(builtin_math_pow));
    vss_env_define(env, "__math_abs", vss_value_new_native(builtin_math_abs));
    vss_env_define(env, "__math_min", vss_value_new_native(builtin_math_min));
    vss_env_define(env, "__math_max", vss_value_new_native(builtin_math_max));
    vss_env_define(env, "__math_sum", vss_value_new_native(builtin_math_sum));
    vss_env_define(env, "__math_round", vss_value_new_native(builtin_math_round));

    // Matrix Operations
    vss_env_define(env, "__matrix_create", vss_value_new_native(builtin_matrix_create));
    vss_env_define(env, "__matrix_multiply", vss_value_new_native(builtin_matrix_multiply));
    vss_env_define(env, "__matrix_add", vss_value_new_native(builtin_matrix_add));
    vss_env_define(env, "__matrix_transpose", vss_value_new_native(builtin_matrix_transpose));
    vss_env_define(env, "__matrix_dot", vss_value_new_native(builtin_matrix_dot));
    vss_env_define(env, "__matrix_scale", vss_value_new_native(builtin_matrix_scale));

    // FFI Dynamic Library Invocation
    vss_env_define(env, "__ffi_open", vss_value_new_native(builtin_ffi_open));
    vss_env_define(env, "__ffi_call", vss_value_new_native(builtin_ffi_call));
    vss_env_define(env, "__ffi_close", vss_value_new_native(builtin_ffi_close));

    // String
    vss_env_define(env, "__string_length", vss_value_new_native(builtin_string_length));
    vss_env_define(env, "__string_lower", vss_value_new_native(builtin_string_lower));
    vss_env_define(env, "__string_upper", vss_value_new_native(builtin_string_upper));
    vss_env_define(env, "__string_trim", vss_value_new_native(builtin_string_trim));
    vss_env_define(env, "__string_substring", vss_value_new_native(builtin_string_substring));
    vss_env_define(env, "__string_find", vss_value_new_native(builtin_string_find));
    vss_env_define(env, "__string_replace", vss_value_new_native(builtin_string_replace));
    vss_env_define(env, "__string_split", vss_value_new_native(builtin_string_split));
    vss_env_define(env, "__string_join", vss_value_new_native(builtin_string_join));
    vss_env_define(env, "__string_startswith", vss_value_new_native(builtin_string_startswith));
    vss_env_define(env, "__string_endswith", vss_value_new_native(builtin_string_endswith));
    vss_env_define(env, "__string_isalpha", vss_value_new_native(builtin_string_isalpha));
    vss_env_define(env, "__string_isdigit", vss_value_new_native(builtin_string_isdigit));
    vss_env_define(env, "__string_count", vss_value_new_native(builtin_string_count));

    // Collections & Sequences
    vss_env_define(env, "__list_range", vss_value_new_native(builtin_list_range));
    vss_env_define(env, "__list_enumerate", vss_value_new_native(builtin_list_enumerate));
    vss_env_define(env, "__list_reversed", vss_value_new_native(builtin_list_reversed));
    vss_env_define(env, "__list_sorted", vss_value_new_native(builtin_list_sorted));
    vss_env_define(env, "__map_keys", vss_value_new_native(builtin_map_keys));
    vss_env_define(env, "__map_values", vss_value_new_native(builtin_map_values));
    vss_env_define(env, "__map_get", vss_value_new_native(builtin_map_get));
    vss_env_define(env, "__type_of", vss_value_new_native(builtin_type_of));

    // Python-style Top-Level Global Aliases
    vss_env_define(env, "range", vss_value_new_native(builtin_list_range));
    vss_env_define(env, "enumerate", vss_value_new_native(builtin_list_enumerate));
    vss_env_define(env, "reversed", vss_value_new_native(builtin_list_reversed));
    vss_env_define(env, "sorted", vss_value_new_native(builtin_list_sorted));
    vss_env_define(env, "abs", vss_value_new_native(builtin_math_abs));
    vss_env_define(env, "min", vss_value_new_native(builtin_math_min));
    vss_env_define(env, "max", vss_value_new_native(builtin_math_max));
    vss_env_define(env, "sum", vss_value_new_native(builtin_math_sum));
    vss_env_define(env, "round", vss_value_new_native(builtin_math_round));
    vss_env_define(env, "type_of", vss_value_new_native(builtin_type_of));

    // Encoding
    vss_env_define(env, "__base64_encode", vss_value_new_native(builtin_encoding_base64_encode));
    vss_env_define(env, "__base64_decode", vss_value_new_native(builtin_encoding_base64_decode));
    vss_env_define(env, "__hex_encode", vss_value_new_native(builtin_encoding_hex_encode));
    vss_env_define(env, "__hex_decode", vss_value_new_native(builtin_encoding_hex_decode));

    // Path
    vss_env_define(env, "__path_join", vss_value_new_native(builtin_path_join));
    vss_env_define(env, "__path_basename", vss_value_new_native(builtin_path_basename));
    vss_env_define(env, "__path_dirname", vss_value_new_native(builtin_path_dirname));
    vss_env_define(env, "__path_ext", vss_value_new_native(builtin_path_ext));
    vss_env_define(env, "__path_is_file", vss_value_new_native(builtin_path_is_file));

    // Random
    vss_env_define(env, "__random_randint", vss_value_new_native(builtin_random_randint));
    vss_env_define(env, "__random_choice", vss_value_new_native(builtin_random_choice));
    vss_env_define(env, "__random_shuffle", vss_value_new_native(builtin_random_shuffle));
    vss_env_define(env, "__random_seed", vss_value_new_native(builtin_random_seed));

    // DateTime
    vss_env_define(env, "__datetime_now", vss_value_new_native(builtin_datetime_now));
    vss_env_define(env, "__datetime_timestamp", vss_value_new_native(builtin_datetime_timestamp));

    // Sequence Slicing & Operations
    vss_env_define(env, "__list_slice", vss_value_new_native(builtin_list_slice));
    vss_env_define(env, "__list_contains", vss_value_new_native(builtin_list_contains));
    vss_env_define(env, "__list_unique", vss_value_new_native(builtin_list_unique));
    vss_env_define(env, "__string_slice", vss_value_new_native(builtin_string_slice));

    // Regex
    vss_env_define(env, "__regex_search", vss_value_new_native(builtin_regex_search));
    vss_env_define(env, "__regex_match", vss_value_new_native(builtin_regex_match));
    vss_env_define(env, "__regex_replace", vss_value_new_native(builtin_regex_replace));

    // JSON
    vss_env_define(env, "__json_read", vss_value_new_native(builtin_json_read));
    vss_env_define(env, "__json_write", vss_value_new_native(builtin_json_write));
    vss_env_define(env, "__json_parse", vss_value_new_native(builtin_json_parse));
    vss_env_define(env, "__json_stringify", vss_value_new_native(builtin_json_stringify));

    // HTTP
    vss_env_define(env, "__http_request", vss_value_new_native(builtin_http_request));

    // Database
    vss_env_define(env, "__db_open", vss_value_new_native(builtin_db_open));
    vss_env_define(env, "__db_execute", vss_value_new_native(builtin_db_execute));
    vss_env_define(env, "__db_query", vss_value_new_native(builtin_db_query));

    // Time
    vss_env_define(env, "__time_now", vss_value_new_native(builtin_time_now));
    vss_env_define(env, "__time_sleep", vss_value_new_native(builtin_time_sleep));
    vss_env_define(env, "__time_format", vss_value_new_native(builtin_time_format));

    // Random
    vss_env_define(env, "__random_number", vss_value_new_native(builtin_random_number));

    // System
    vss_env_define(env, "__system_args", vss_value_new_native(builtin_system_args));
    vss_env_define(env, "__system_env", vss_value_new_native(builtin_system_env));
    vss_env_define(env, "__system_exit", vss_value_new_native(builtin_system_exit));
    vss_env_define(env, "__system_platform", vss_value_new_native(builtin_system_platform));
    vss_env_define(env, "__system_run", vss_value_new_native(builtin_system_run));

    // Crypto
    vss_env_define(env, "__crypto_md5", vss_value_new_native(builtin_crypto_md5));
    vss_env_define(env, "__crypto_sha256", vss_value_new_native(builtin_crypto_sha256));

    // Network
    vss_env_define(env, "__network_resolve", vss_value_new_native(builtin_network_resolve));
    vss_env_define(env, "__network_ping", vss_value_new_native(builtin_network_ping));

    // Web Server
    vss_env_define(env, "__web_route", vss_value_new_native(builtin_web_route));
    vss_env_define(env, "__web_serve", vss_value_new_native(builtin_web_serve));

    // Generators
    vss_env_define(env, "__generator_create", vss_value_new_native(builtin_generator_create));
    vss_env_define(env, "__generator_next", vss_value_new_native(builtin_generator_next));

    // Load VSS Standard Library
    static const char *stdlib_source =
        "\n"
        "note --- MODULE: math ---\n"
        "namespace math\n"
        "    note VSS Math Standard Library\n"
        "    task sin needs x\n"
        "        send __math_sin(x)\n"
        "    finish\n"
        "\n"
        "    task cos needs x\n"
        "        send __math_cos(x)\n"
        "    finish\n"
        "\n"
        "    task tan needs x\n"
        "        send __math_tan(x)\n"
        "    finish\n"
        "\n"
        "    task sqrt needs x\n"
        "        send __math_sqrt(x)\n"
        "    finish\n"
        "\n"
        "    task log needs x\n"
        "        send __math_log(x)\n"
        "    finish\n"
        "\n"
        "    task ceil needs x\n"
        "        send __math_ceil(x)\n"
        "    finish\n"
        "\n"
        "    task floor needs x\n"
        "        send __math_floor(x)\n"
        "    finish\n"
        "\n"
        "    task pow needs base, exp\n"
        "        send __math_pow(base, exp)\n"
        "    finish\n"
        "\n"
        "    task abs needs x\n"
        "        send __math_abs(x)\n"
        "    finish\n"
        "\n"
        "    task min needs a, b\n"
        "        send __math_min(a, b)\n"
        "    finish\n"
        "\n"
        "    task max needs a, b\n"
        "        send __math_max(a, b)\n"
        "    finish\n"
        "\n"
        "    task sum needs items\n"
        "        send __math_sum(items)\n"
        "    finish\n"
        "\n"
        "    task round needs x\n"
        "        send __math_round(x)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: string ---\n"
        "namespace string\n"
        "    note VSS String Standard Library\n"
        "    task length needs s\n"
        "        send __string_length(s)\n"
        "    finish\n"
        "\n"
        "    task lower needs s\n"
        "        send __string_lower(s)\n"
        "    finish\n"
        "\n"
        "    task upper needs s\n"
        "        send __string_upper(s)\n"
        "    finish\n"
        "\n"
        "    task trim needs s\n"
        "        send __string_trim(s)\n"
        "    finish\n"
        "\n"
        "    task substring needs s, start, len\n"
        "        send __string_substring(s, start, len)\n"
        "    finish\n"
        "\n"
        "    task find needs s, sub\n"
        "        send __string_find(s, sub)\n"
        "    finish\n"
        "\n"
        "    task replace needs s, old, new\n"
        "        send __string_replace(s, old, new)\n"
        "    finish\n"
        "\n"
        "    task split needs s, sep\n"
        "        send __string_split(s, sep)\n"
        "    finish\n"
        "\n"
        "    task join needs list, sep\n"
        "        send __string_join(list, sep)\n"
        "    finish\n"
        "\n"
        "    task startswith needs s, prefix\n"
        "        send __string_startswith(s, prefix)\n"
        "    finish\n"
        "\n"
        "    task endswith needs s, suffix\n"
        "        send __string_endswith(s, suffix)\n"
        "    finish\n"
        "\n"
        "    task isalpha needs s\n"
        "        send __string_isalpha(s)\n"
        "    finish\n"
        "\n"
        "    task isdigit needs s\n"
        "        send __string_isdigit(s)\n"
        "    finish\n"
        "\n"
        "    task count needs s, sub\n"
        "        send __string_count(s, sub)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: collections ---\n"
        "namespace collections\n"
        "    note VSS Collections Standard Library\n"
        "    task range needs a, b\n"
        "        send __list_range(a, b)\n"
        "    finish\n"
        "\n"
        "    task enumerate needs items\n"
        "        send __list_enumerate(items)\n"
        "    finish\n"
        "\n"
        "    task reversed needs items\n"
        "        send __list_reversed(items)\n"
        "    finish\n"
        "\n"
        "    task sorted needs items\n"
        "        send __list_sorted(items)\n"
        "    finish\n"
        "\n"
        "    task keys needs m\n"
        "        send __map_keys(m)\n"
        "    finish\n"
        "\n"
        "    task values needs m\n"
        "        send __map_values(m)\n"
        "    finish\n"
        "\n"
        "    task get needs m, k, default_val\n"
        "        send __map_get(m, k, default_val)\n"
        "    finish\n"
        "    shape Queue\n"
        "        field items\n"
        "        task init needs\n"
        "            mine.items becomes []\n"
        "        finish\n"
        "        task push needs x\n"
        "            put x into mine.items\n"
        "        finish\n"
        "        task pop needs\n"
        "            when size of mine.items above 0\n"
        "                make first becomes mine.items[0]\n"
        "                note erase first element (simulated in dynamic list)\n"
        "                send first\n"
        "            finish\n"
        "            send empty\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    shape Stack\n"
        "        field items\n"
        "        task init needs\n"
        "            mine.items becomes []\n"
        "        finish\n"
        "        task push needs x\n"
        "            put x into mine.items\n"
        "        finish\n"
        "        task pop needs\n"
        "            make sz becomes size of mine.items\n"
        "            when sz above 0\n"
        "                make last becomes mine.items[sz - 1]\n"
        "                send last\n"
        "            finish\n"
        "            send empty\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    task set_union needs s1, s2\n"
        "        make union becomes {}\n"
        "        repeat each x in s1\n"
        "            put x into union\n"
        "        finish\n"
        "        repeat each x in s2\n"
        "            put x into union\n"
        "        finish\n"
        "        send union\n"
        "    finish\n"
        "\n"
        "    shape ConcurrentQueue\n"
        "        field _mutex\n"
        "        field _items\n"
        "        task create needs\n"
        "            mine._mutex becomes __mutex_create()\n"
        "            mine._items becomes []\n"
        "        finish\n"
        "        task push needs val\n"
        "            lock mine._mutex\n"
        "                put val into mine._items\n"
        "            finish\n"
        "        finish\n"
        "        task pop needs\n"
        "            make result becomes empty\n"
        "            lock mine._mutex\n"
        "                when size of mine._items above 0\n"
        "                    result becomes mine._items[0]\n"
        "                finish\n"
        "            finish\n"
        "            send result\n"
        "        finish\n"
        "        task count needs\n"
        "            make sz becomes 0\n"
        "            lock mine._mutex\n"
        "                sz becomes size of mine._items\n"
        "            finish\n"
        "            send sz\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    shape ConcurrentMap\n"
        "        field _mutex\n"
        "        field _data\n"
        "        task create needs\n"
        "            mine._mutex becomes __mutex_create()\n"
        "            mine._data becomes map []\n"
        "        finish\n"
        "        task insert needs key, val\n"
        "            lock mine._mutex\n"
        "                set mine._data[key] becomes val\n"
        "            finish\n"
        "        finish\n"
        "        task get needs key\n"
        "            make result becomes empty\n"
        "            lock mine._mutex\n"
        "                result becomes mine._data[key]\n"
        "            finish\n"
        "            send result\n"
        "        finish\n"
        "        task count needs\n"
        "            make sz becomes 0\n"
        "            lock mine._mutex\n"
        "                sz becomes size of mine._data\n"
        "            finish\n"
        "            send sz\n"
        "        finish\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: filesystem ---\n"
        "namespace filesystem\n"
        "    note VSS Filesystem Standard Library\n"
        "    task exists_file needs path\n"
        "        send __exists(path)\n"
        "    finish\n"
        "\n"
        "    task read_file needs path\n"
        "        send __read(path)\n"
        "    finish\n"
        "\n"
        "    task write_file needs path, content\n"
        "        send __write(content, path)\n"
        "    finish\n"
        "\n"
        "    task files needs dir\n"
        "        send __file_list(dir)\n"
        "    finish\n"
        "\n"
        "    task create_directory needs path\n"
        "        send __make_dir(path)\n"
        "    finish\n"
        "\n"
        "    task delete_file needs path\n"
        "        send __erase(path)\n"
        "    finish\n"
        "\n"
        "    task erase_file needs path\n"
        "        send __erase(path)\n"
        "    finish\n"
        "\n"
        "    task read_async needs path\n"
        "        send read_file(path)\n"
        "    finish\n"
        "\n"
        "    task write_async needs path, content\n"
        "        send write_file(path, content)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: json ---\n"
        "namespace json\n"
        "    note VSS JSON Standard Library\n"
        "    task parse needs s\n"
        "        send __json_parse(s)\n"
        "    finish\n"
        "\n"
        "    task stringify needs v\n"
        "        send __json_stringify(v)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: xml ---\n"
        "namespace xml\n"
        "    note VSS XML Standard Library\n"
        "    task parse_simple needs xml_str\n"
        "        note Simple key-value XML parser\n"
        "        make result becomes map []\n"
        "        make lines becomes __string_split(xml_str, \"\\n\")\n"
        "        repeat each line in lines\n"
        "            make trimmed becomes __string_trim(line)\n"
        "            when __string_find(trimmed, \"<\") same_as 0\n"
        "                make closing becomes __string_find(trimmed, \">\")\n"
        "                when closing above 0\n"
        "                    make tag becomes __string_substring(trimmed, 1, closing - 1)\n"
        "                    make closing_tag becomes \"</\" + tag + \">\"\n"
        "                    make end_idx becomes __string_find(trimmed, closing_tag)\n"
        "                    when end_idx above 0\n"
        "                        make val_start becomes closing + 1\n"
        "                        make val_len becomes end_idx - val_start\n"
        "                        make val becomes __string_substring(trimmed, val_start, val_len)\n"
        "                        put val into result[tag]\n"
        "                    finish\n"
        "                finish\n"
        "            finish\n"
        "        finish\n"
        "        send result\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: yaml ---\n"
        "namespace yaml\n"
        "    note VSS YAML Standard Library\n"
        "    task parse needs yaml_str\n"
        "        make result becomes map []\n"
        "        make lines becomes __string_split(yaml_str, \"\\n\")\n"
        "        repeat each line in lines\n"
        "            make trimmed becomes __string_trim(line)\n"
        "            make colon_idx becomes __string_find(trimmed, \":\")\n"
        "            when colon_idx above 0\n"
        "                make key becomes __string_trim(__string_substring(trimmed, 0, colon_idx))\n"
        "                make val becomes __string_trim(__string_substring(trimmed, colon_idx + 1, __string_length(trimmed) - colon_idx - 1))\n"
        "                put val into result[key]\n"
        "            finish\n"
        "        finish\n"
        "        send result\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: csv ---\n"
        "namespace csv\n"
        "    note VSS CSV Standard Library\n"
        "    task parse needs csv_str\n"
        "        make result becomes []\n"
        "        make lines becomes __string_split(csv_str, \"\\n\")\n"
        "        when size of lines above 0\n"
        "            make headers becomes __string_split(lines[0], \",\")\n"
        "            repeat each line in lines\n"
        "                note Skip header line\n"
        "                when line same_as lines[0]\n"
        "                    skip\n"
        "                finish\n"
        "                make row becomes __string_split(line, \",\")\n"
        "                when size of row same_as size of headers\n"
        "                    make obj becomes map []\n"
        "                    make i becomes 0\n"
        "                    repeat each header in headers\n"
        "                        put row[i] into obj[header]\n"
        "                        i becomes i + 1\n"
        "                    finish\n"
        "                    put obj into result\n"
        "                finish\n"
        "            finish\n"
        "        finish\n"
        "        send result\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: http ---\n"
        "namespace http\n"
        "    note VSS HTTP Standard Library\n"
        "    task request needs method, url, headers, body\n"
        "        send __http_request(method, url, headers, body)\n"
        "    finish\n"
        "\n"
        "    task get needs url\n"
        "        send request(\"GET\", url, map [], \"\")\n"
        "    finish\n"
        "\n"
        "    task post needs url, body\n"
        "        send request(\"POST\", url, map [ \"Content-Type\": \"application/json\" ], body)\n"
        "    finish\n"
        "\n"
        "    task get_async needs url\n"
        "        send get(url)\n"
        "    finish\n"
        "\n"
        "    task post_async needs url, body\n"
        "        send post(url, body)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: database ---\n"
        "namespace database\n"
        "    note VSS Database Unified ORM & Driver Library\n"
        "    task open needs filepath\n"
        "        send __db_open(filepath)\n"
        "    finish\n"
        "\n"
        "    task execute needs db, sql\n"
        "        send __db_execute(db, sql)\n"
        "    finish\n"
        "\n"
        "    task query needs db, sql\n"
        "        send __db_query(db, sql)\n"
        "    finish\n"
        "\n"
        "    shape QueryBuilder\n"
        "        field _db\n"
        "        field _table\n"
        "        field _where\n"
        "        task init needs db, table\n"
        "            mine._db becomes db\n"
        "            mine._table becomes table\n"
        "            mine._where becomes \"\"\n"
        "        finish\n"
        "        task where needs field_name, value\n"
        "            mine._where becomes \" WHERE \" + field_name + \" = '\" + value + \"'\"\n"
        "        finish\n"
        "        task get needs\n"
        "            make sql becomes \"SELECT * FROM \" + mine._table + mine._where\n"
        "            send __db_query(mine._db, sql)\n"
        "        finish\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: crypto ---\n"
        "namespace crypto\n"
        "    note VSS Crypto & Hashing Standard Library\n"
        "    task md5 needs text\n"
        "        send __crypto_md5(text)\n"
        "    finish\n"
        "\n"
        "    task sha256 needs text\n"
        "        send __crypto_sha256(text)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: gui ---\n"
        "namespace gui\n"
        "    note VSS Native Cross-Platform WebView GUI Framework\n"
        "    task create_window needs title, width, height, html_content\n"
        "        note Runs the local browser/WebView interface\n"
        "        make temp_file becomes \"vss_temp_ui.html\"\n"
        "        __write(html_content, temp_file)\n"
        "        note Start WebView process\n"
        "        __system_run(\"start \" + temp_file)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: ai ---\n"
        "namespace ai\n"
        "    note VSS AI Framework SDK\n"
        "    task gemini_chat needs api_key, model, prompt\n"
        "        make url becomes \"https://generativelanguage.googleapis.com/v1beta/models/\" + model + \":generateContent?key=\" + api_key\n"
        "        make body becomes __json_stringify(map [ \"contents\": [ map [ \"parts\": [ map [ \"text\": prompt ] ] ] ] ])\n"
        "        make res becomes __http_request(\"POST\", url, map [ \"Content-Type\": \"application/json\" ], body)\n"
        "        send res\n"
        "    finish\n"
        "\n"
        "    task openai_chat needs api_key, model, prompt\n"
        "        make url becomes \"https://api.openai.com/v1/chat/completions\"\n"
        "        make body becomes __json_stringify(map [ \"model\": model, \"messages\": [ map [ \"role\": \"user\", \"content\": prompt ] ] ])\n"
        "        make headers becomes map [ \"Content-Type\": \"application/json\", \"Authorization\": \"Bearer \" + api_key ]\n"
        "        make res becomes __http_request(\"POST\", url, headers, body)\n"
        "        send res\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: testing ---\n"
        "namespace testing\n"
        "    note VSS Unit Testing Framework\n"
        "    task assert_equal needs actual, expected, message\n"
        "        when actual same_as expected\n"
        "            say \"  [PASS] \" + message\n"
        "        otherwise\n"
        "            say \"  [FAIL] \" + message + \" (Expected \" + expected + \", got \" + actual + \")\"\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    task assert_not_equal needs actual, expected, message\n"
        "        when actual not_same_as expected\n"
        "            say \"  [PASS] \" + message\n"
        "        otherwise\n"
        "            say \"  [FAIL] \" + message + \" (Expected value to not equal \" + expected + \")\"\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    task assert_true needs condition, message\n"
        "        when condition same_as yes\n"
        "            say \"  [PASS] \" + message\n"
        "        otherwise\n"
        "            say \"  [FAIL] \" + message + \" (Expected yes, got \" + condition + \")\"\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    task assert_false needs condition, message\n"
        "        when condition same_as no\n"
        "            say \"  [PASS] \" + message\n"
        "        otherwise\n"
        "            say \"  [FAIL] \" + message + \" (Expected no, got \" + condition + \")\"\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    task assert_greater needs a, b, message\n"
        "        when a above b\n"
        "            say \"  [PASS] \" + message\n"
        "        otherwise\n"
        "            say \"  [FAIL] \" + message + \" (Expected \" + a + \" to be greater than \" + b + \")\"\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    task assert_less needs a, b, message\n"
        "        when a below b\n"
        "            say \"  [PASS] \" + message\n"
        "        otherwise\n"
        "            say \"  [FAIL] \" + message + \" (Expected \" + a + \" to be less than \" + b + \")\"\n"
        "        finish\n"
        "    finish\n"
        "\n"
        "    task run_suite needs name, tests_list\n"
        "        say \"Running Test Suite: \" + name\n"
        "        repeat each t in tests_list\n"
        "            t()\n"
        "        finish\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: web ---\n"
        "namespace web\n"
        "    note VSS Web Framework\n"
        "    task route needs path, handler\n"
        "        __web_route(path, handler)\n"
        "    finish\n"
        "\n"
        "    task serve needs port\n"
        "        __web_serve(port)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: encoding ---\n"
        "namespace encoding\n"
        "    note VSS Base64 and Hex Encoding Library\n"
        "    task base64_encode needs text\n"
        "        send __base64_encode(text)\n"
        "    finish\n"
        "    task base64_decode needs encoded\n"
        "        send __base64_decode(encoded)\n"
        "    finish\n"
        "    task hex_encode needs text\n"
        "        send __hex_encode(text)\n"
        "    finish\n"
        "    task hex_decode needs encoded\n"
        "        send __hex_decode(encoded)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: path ---\n"
        "namespace path\n"
        "    note VSS Cross-Platform File Path Library\n"
        "    task join needs p1, p2\n"
        "        send __path_join(p1, p2)\n"
        "    finish\n"
        "    task basename needs p\n"
        "        send __path_basename(p)\n"
        "    finish\n"
        "    task dirname needs p\n"
        "        send __path_dirname(p)\n"
        "    finish\n"
        "    task ext needs p\n"
        "        send __path_ext(p)\n"
        "    finish\n"
        "    task is_file needs p\n"
        "        send __path_is_file(p)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: random ---\n"
        "namespace random\n"
        "    note VSS Random Utilities\n"
        "    task randint needs min_val, max_val\n"
        "        send __random_randint(min_val, max_val)\n"
        "    finish\n"
        "    task choice needs items\n"
        "        send __random_choice(items)\n"
        "    finish\n"
        "    task shuffle needs items\n"
        "        send __random_shuffle(items)\n"
        "    finish\n"
        "    task seed needs val\n"
        "        send __random_seed(val)\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: datetime ---\n"
        "namespace datetime\n"
        "    note VSS Date and Time Library\n"
        "    task now needs\n"
        "        send __datetime_now()\n"
        "    finish\n"
        "    task timestamp needs\n"
        "        send __datetime_timestamp()\n"
        "    finish\n"
        "finish\n"
        "\n"
        "note --- MODULE: regex ---\n"
        "namespace regex\n"
        "    note VSS Regular Expression Library\n"
        "    task search needs pattern, text\n"
        "        send __regex_search(pattern, text)\n"
        "    finish\n"
        "    task is_match needs pattern, text\n"
        "        send __regex_match(pattern, text)\n"
        "    finish\n"
        "    task replace needs pattern, replacement, text\n"
        "        send __regex_replace(text, pattern, replacement)\n"
        "    finish\n"
        "finish\n";

    VSS_Lexer lexer;
    vss_lexer_init(&lexer, stdlib_source);
    VSS_Parser parser;
    vss_parser_init(&parser, &lexer);
    VSS_Block ast = vss_parse_program(&parser);
    if (!parser.had_error) {
        VSS_ObjFunction *func = vss_compile_program(ast);
        if (func) {
            vss_vm_run(func, env);
            vss_function_release(func);
        }
        vss_block_free(ast);
    }
}
