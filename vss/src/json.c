#include "json.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#ifdef _MSC_VER
#define strdup _strdup
#endif

static void skip_whitespace(const char **p) {
    while (**p && isspace((unsigned char)**p)) {
        (*p)++;
    }
}

static char *parse_json_string_raw(const char **p, bool *out_error, char **out_error_msg) {
    if (**p != '"') {
        *out_error = true;
        *out_error_msg = strdup("Expected starting double quote in string");
        return NULL;
    }
    (*p)++; // consume "
    
    size_t capacity = 16;
    size_t length = 0;
    char *buf = malloc(capacity);
    
    while (**p && **p != '"') {
        char c = **p;
        if (c == '\\') {
            (*p)++;
            if (!**p) {
                *out_error = true;
                *out_error_msg = strdup("Unterminated escape sequence in string");
                free(buf);
                return NULL;
            }
            char esc = **p;
            if (esc == 'n') c = '\n';
            else if (esc == 't') c = '\t';
            else if (esc == 'r') c = '\r';
            else if (esc == 'b') c = '\b';
            else if (esc == 'f') c = '\f';
            else if (esc == '"') c = '"';
            else if (esc == '\\') c = '\\';
            else if (esc == '/') c = '/';
            else {
                c = esc;
            }
        }
        
        if (length + 1 >= capacity) {
            capacity *= 2;
            buf = realloc(buf, capacity);
        }
        buf[length++] = c;
        (*p)++;
    }
    
    if (**p != '"') {
        *out_error = true;
        *out_error_msg = strdup("Unterminated JSON string");
        free(buf);
        return NULL;
    }
    (*p)++; // consume closing "
    buf[length] = '\0';
    return buf;
}

static VSS_Value parse_json_value(const char **p, bool *out_error, char **out_error_msg);

static VSS_Value parse_json_object(const char **p, bool *out_error, char **out_error_msg) {
    if (**p != '{') {
        *out_error = true;
        *out_error_msg = strdup("Expected '{' for object");
        return vss_value_new_empty();
    }
    (*p)++; // consume '{'
    skip_whitespace(p);
    
    VSS_Value map_val = vss_value_new_map();
    VSS_ValMap *m = map_val.as.map;
    
    if (**p == '}') {
        (*p)++; // consume '}'
        return map_val;
    }
    
    for (;;) {
        skip_whitespace(p);
        if (**p != '"') {
            *out_error = true;
            *out_error_msg = strdup("Expected string key in object");
            vss_value_release(map_val);
            return vss_value_new_empty();
        }
        char *key = parse_json_string_raw(p, out_error, out_error_msg);
        if (*out_error) {
            vss_value_release(map_val);
            return vss_value_new_empty();
        }
        
        skip_whitespace(p);
        if (**p != ':') {
            *out_error = true;
            *out_error_msg = strdup("Expected ':' after key in object");
            free(key);
            vss_value_release(map_val);
            return vss_value_new_empty();
        }
        (*p)++; // consume ':'
        
        VSS_Value value = parse_json_value(p, out_error, out_error_msg);
        if (*out_error) {
            free(key);
            vss_value_release(map_val);
            return vss_value_new_empty();
        }
        
        m->entries = realloc(m->entries, sizeof(VSS_ValMapEntry) * (m->count + 1));
        m->entries[m->count].key = key;
        m->entries[m->count].value = value;
        vss_value_retain(value);
        m->count++;
        vss_value_release(value);
        
        skip_whitespace(p);
        if (**p == ',') {
            (*p)++; // consume ','
        } else if (**p == '}') {
            (*p)++; // consume '}'
            break;
        } else {
            *out_error = true;
            *out_error_msg = strdup("Expected ',' or '}' in object");
            vss_value_release(map_val);
            return vss_value_new_empty();
        }
    }
    return map_val;
}

static VSS_Value parse_json_array(const char **p, bool *out_error, char **out_error_msg) {
    if (**p != '[') {
        *out_error = true;
        *out_error_msg = strdup("Expected '[' for array");
        return vss_value_new_empty();
    }
    (*p)++; // consume '['
    skip_whitespace(p);
    
    VSS_Value list_val = vss_value_new_list();
    VSS_ValList *l = list_val.as.list;
    
    if (**p == ']') {
        (*p)++; // consume ']'
        return list_val;
    }
    
    for (;;) {
        VSS_Value val = parse_json_value(p, out_error, out_error_msg);
        if (*out_error) {
            vss_value_release(list_val);
            return vss_value_new_empty();
        }
        
        if (l->count >= l->capacity) {
            l->capacity = l->capacity == 0 ? 8 : l->capacity * 2;
            l->items = realloc(l->items, sizeof(VSS_Value) * l->capacity);
        }
        l->items[l->count++] = val;
        vss_value_retain(val);
        vss_value_release(val);
        
        skip_whitespace(p);
        if (**p == ',') {
            (*p)++; // consume ','
        } else if (**p == ']') {
            (*p)++; // consume ']'
            break;
        } else {
            *out_error = true;
            *out_error_msg = strdup("Expected ',' or ']' in array");
            vss_value_release(list_val);
            return vss_value_new_empty();
        }
    }
    return list_val;
}

static VSS_Value parse_json_value(const char **p, bool *out_error, char **out_error_msg) {
    skip_whitespace(p);
    if (!**p) {
        *out_error = true;
        *out_error_msg = strdup("Unexpected end of JSON string");
        return vss_value_new_empty();
    }
    
    char c = **p;
    if (c == '{') {
        return parse_json_object(p, out_error, out_error_msg);
    } else if (c == '[') {
        return parse_json_array(p, out_error, out_error_msg);
    } else if (c == '"') {
        char *str = parse_json_string_raw(p, out_error, out_error_msg);
        if (*out_error) return vss_value_new_empty();
        VSS_Value val = vss_value_new_string(str);
        free(str);
        return val;
    } else if (c == '-' || isdigit((unsigned char)c)) {
        char *endptr;
        double d = strtod(*p, &endptr);
        if (*p == endptr) {
            *out_error = true;
            *out_error_msg = strdup("Invalid number format in JSON");
            return vss_value_new_empty();
        }
        *p = endptr;
        return vss_value_new_number(d);
    } else if (strncmp(*p, "true", 4) == 0) {
        *p += 4;
        return vss_value_new_bool(true);
    } else if (strncmp(*p, "false", 5) == 0) {
        *p += 5;
        return vss_value_new_bool(false);
    } else if (strncmp(*p, "null", 4) == 0) {
        *p += 4;
        return vss_value_new_empty();
    } else {
        *out_error = true;
        char msg[128];
        snprintf(msg, sizeof(msg), "Unexpected character '%c' in JSON value", c);
        *out_error_msg = strdup(msg);
        return vss_value_new_empty();
    }
}

VSS_Value vss_json_parse(const char *json_str, bool *out_error, char **out_error_msg) {
    const char *p = json_str;
    *out_error = false;
    *out_error_msg = NULL;
    VSS_Value val = parse_json_value(&p, out_error, out_error_msg);
    if (!*out_error) {
        skip_whitespace(&p);
        if (*p) {
            *out_error = true;
            *out_error_msg = strdup("Extra data after valid JSON value");
            vss_value_release(val);
            return vss_value_new_empty();
        }
    }
    return val;
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

static void append_char(char **buf, size_t *len, size_t *cap, char c) {
    char s[2] = {c, '\0'};
    append_str(buf, len, cap, s);
}

static void serialize_value_helper(VSS_Value val, char **buf, size_t *len, size_t *cap) {
    if (val.type == VSS_VAL_NUMBER) {
        char num[64];
        if (val.as.number == (double)(long long)val.as.number) {
            sprintf(num, "%lld", (long long)val.as.number);
        } else {
            sprintf(num, "%.17g", val.as.number);
        }
        append_str(buf, len, cap, num);
    } else if (val.type == VSS_VAL_STRING) {
        append_char(buf, len, cap, '"');
        const char *p = val.as.string->chars;
        while (*p) {
            if (*p == '"') append_str(buf, len, cap, "\\\"");
            else if (*p == '\\') append_str(buf, len, cap, "\\\\");
            else if (*p == '\n') append_str(buf, len, cap, "\\n");
            else if (*p == '\t') append_str(buf, len, cap, "\\t");
            else if (*p == '\r') append_str(buf, len, cap, "\\r");
            else {
                append_char(buf, len, cap, *p);
            }
            p++;
        }
        append_char(buf, len, cap, '"');
    } else if (val.type == VSS_VAL_BOOL) {
        append_str(buf, len, cap, val.as.boolean ? "true" : "false");
    } else if (val.type == VSS_VAL_EMPTY) {
        append_str(buf, len, cap, "null");
    } else if (val.type == VSS_VAL_LIST) {
        append_char(buf, len, cap, '[');
        VSS_ValList *l = val.as.list;
        for (size_t i = 0; i < l->count; i++) {
            if (i > 0) append_str(buf, len, cap, ", ");
            serialize_value_helper(l->items[i], buf, len, cap);
        }
        append_char(buf, len, cap, ']');
    } else if (val.type == VSS_VAL_MAP) {
        append_char(buf, len, cap, '{');
        VSS_ValMap *m = val.as.map;
        for (size_t i = 0; i < m->count; i++) {
            if (i > 0) append_str(buf, len, cap, ", ");
            append_char(buf, len, cap, '"');
            const char *p = m->entries[i].key;
            while (*p) {
                if (*p == '"') append_str(buf, len, cap, "\\\"");
                else if (*p == '\\') append_str(buf, len, cap, "\\\\");
                else append_char(buf, len, cap, *p);
                p++;
            }
            append_str(buf, len, cap, "\": ");
            serialize_value_helper(m->entries[i].value, buf, len, cap);
        }
        append_char(buf, len, cap, '}');
    } else {
        append_str(buf, len, cap, "null");
    }
}

char *vss_json_serialize(VSS_Value val) {
    char *buf = NULL;
    size_t len = 0;
    size_t cap = 0;
    serialize_value_helper(val, &buf, &len, &cap);
    return buf;
}
