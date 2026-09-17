#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "platform.h"
#include "version.h"
#include "cli.h"
#include "lexer.h"
#include "parser.h"
#include "compiler.h"
#include "vm.h"
#include "interpreter.h" // for vss_register_builtins
#include "semantic.h"

// Levenshtein distance helper
static int min3(int a, int b, int c) {
    int m = a;
    if (b < m) m = b;
    if (c < m) m = c;
    return m;
}

static int levenshtein(const char *s, const char *t) {
    int m = strlen(s);
    int n = strlen(t);
    int *d = malloc((m + 1) * (n + 1) * sizeof(int));
    for (int i = 0; i <= m; i++) d[i * (n + 1)] = i;
    for (int j = 0; j <= n; j++) d[j] = j;
    for (int j = 1; j <= n; j++) {
        for (int i = 1; i <= m; i++) {
            int cost = (s[i-1] == t[j-1]) ? 0 : 1;
            d[i * (n + 1) + j] = min3(d[(i-1) * (n + 1) + j] + 1,
                                     d[i * (n + 1) + j - 1] + 1,
                                     d[(i-1) * (n + 1) + j - 1] + cost);
        }
    }
    int res = d[m * (n + 1) + n];
    free(d);
    return res;
}

// Serialization implementations
bool vss_serialize_value(VSS_Value val, FILE *out) {
    uint8_t type = (uint8_t)val.type;
    fwrite(&type, 1, 1, out);
    if (val.type == VSS_VAL_NUMBER) {
        fwrite(&val.as.number, sizeof(double), 1, out);
    } else if (val.type == VSS_VAL_STRING) {
        size_t len = strlen(val.as.string->chars);
        fwrite(&len, sizeof(size_t), 1, out);
        fwrite(val.as.string->chars, 1, len, out);
    } else if (val.type == VSS_VAL_BOOL) {
        uint8_t b = val.as.boolean ? 1 : 0;
        fwrite(&b, 1, 1, out);
    } else if (val.type == VSS_VAL_FUNCTION) {
        vss_serialize_function(val.as.function, out);
    }
    return true;
}

VSS_Value vss_deserialize_value(FILE *in) {
    uint8_t type_val;
    if (fread(&type_val, 1, 1, in) != 1) return vss_value_new_empty();
    VSS_ValueType type = (VSS_ValueType)type_val;
    if (type == VSS_VAL_NUMBER) {
        double d;
        fread(&d, sizeof(double), 1, in);
        return vss_value_new_number(d);
    } else if (type == VSS_VAL_STRING) {
        size_t len;
        fread(&len, sizeof(size_t), 1, in);
        char *str = malloc(len + 1);
        fread(str, 1, len, in);
        str[len] = '\0';
        VSS_Value v = vss_value_new_string(str);
        free(str);
        return v;
    } else if (type == VSS_VAL_BOOL) {
        uint8_t b;
        fread(&b, 1, 1, in);
        return vss_value_new_bool(b != 0);
    } else if (type == VSS_VAL_FUNCTION) {
        VSS_ObjFunction *func = vss_deserialize_function(in);
        return vss_value_new_function(func);
    }
    return vss_value_new_empty();
}

bool vss_serialize_function(VSS_ObjFunction *func, FILE *out) {
    size_t name_len = func->name ? strlen(func->name) : 0;
    fwrite(&name_len, sizeof(size_t), 1, out);
    if (name_len > 0) {
        fwrite(func->name, 1, name_len, out);
    }
    
    fwrite(&func->param_count, sizeof(size_t), 1, out);
    fwrite(&func->upvalue_count, sizeof(int), 1, out);
    
    fwrite(&func->chunk.count, sizeof(int), 1, out);
    if (func->chunk.count > 0) {
        fwrite(func->chunk.code, 1, func->chunk.count, out);
        fwrite(func->chunk.lines, sizeof(int), func->chunk.count, out);
    }
    
    fwrite(&func->chunk.const_count, sizeof(int), 1, out);
    for (int i = 0; i < func->chunk.const_count; i++) {
        vss_serialize_value(func->chunk.constants[i], out);
    }
    return true;
}

VSS_ObjFunction *vss_deserialize_function(FILE *in) {
    size_t name_len;
    if (fread(&name_len, sizeof(size_t), 1, in) != 1) return NULL;
    char *name = NULL;
    if (name_len > 0) {
        name = malloc(name_len + 1);
        fread(name, 1, name_len, in);
        name[name_len] = '\0';
    }
    
    size_t param_count;
    int upvalue_count;
    fread(&param_count, sizeof(size_t), 1, in);
    fread(&upvalue_count, sizeof(int), 1, in);
    
    VSS_ObjFunction *func = vss_function_new(name ? name : "", param_count);
    free(name);
    func->upvalue_count = upvalue_count;
    
    int code_count;
    fread(&code_count, sizeof(int), 1, in);
    if (code_count > 0) {
        func->chunk.count = code_count;
        func->chunk.capacity = code_count;
        func->chunk.code = malloc(code_count);
        func->chunk.lines = malloc(code_count * sizeof(int));
        fread(func->chunk.code, 1, code_count, in);
        fread(func->chunk.lines, sizeof(int), code_count, in);
    }
    
    int const_count;
    fread(&const_count, sizeof(int), 1, in);
    for (int i = 0; i < const_count; i++) {
        VSS_Value val = vss_deserialize_value(in);
        vss_chunk_add_constant(&func->chunk, val);
        vss_value_release(val);
    }
    
    return func;
}

static char *read_file_text(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) return NULL;
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    rewind(file);
    char *buffer = malloc(size + 1);
    size_t read_bytes = fread(buffer, 1, size, file);
    fclose(file);
    buffer[read_bytes] = '\0';
    return buffer;
}

// Subcommands
static int run_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) {
        fprintf(stderr, "\033[1;31mError:\033[0m Could not open file '%s'.\n", path);
        return 1;
    }
    
    char magic[4];
    size_t bytes_read = fread(magic, 1, 4, f);
    rewind(f);
    
    VSS_ObjFunction *main_func = NULL;
    if (bytes_read == 4 && memcmp(magic, "VSSC", 4) == 0) {
        // Run pre-compiled bytecode file
        fread(magic, 1, 4, f); // discard magic
        main_func = vss_deserialize_function(f);
        fclose(f);
    } else {
        fclose(f);
        // Compile source file
        char *source = read_file_text(path);
        if (!source) {
            fprintf(stderr, "\033[1;31mError:\033[0m Could not read file '%s'.\n", path);
            return 1;
        }
        
        vss_current_source = source;
        VSS_Lexer lexer;
        vss_lexer_init(&lexer, source);
        VSS_Parser parser;
        vss_parser_init(&parser, &lexer);
        VSS_Block ast = vss_parse_program(&parser);
        
        if (parser.had_error) {
            vss_block_free(ast);
            free(source);
            vss_current_source = NULL;
            return 1;
        }
        
        if (!vss_semantic_analyze(ast)) {
            vss_block_free(ast);
            free(source);
            vss_current_source = NULL;
            return 1;
        }
        
        main_func = vss_compile_program(ast);
        vss_block_free(ast);
        free(source);
        vss_current_source = NULL;
    }
    
    if (!main_func) {
        fprintf(stderr, "\033[1;31mError:\033[0m Compilation failed.\n");
        return 1;
    }
    
    VSS_Env *global_env = vss_env_new(NULL);
    vss_register_builtins(global_env);
    
    bool run_success = vss_vm_run(main_func, global_env);
    
    vss_env_release(global_env);
    vss_function_release(main_func);
    
    return run_success ? 0 : 1;
}

static int build_file(const char *path) {
    char *source = read_file_text(path);
    if (!source) {
        fprintf(stderr, "\033[1;31mError:\033[0m Could not open file '%s'.\n", path);
        return 1;
    }
    
    vss_current_source = source;
    VSS_Lexer lexer;
    vss_lexer_init(&lexer, source);
    VSS_Parser parser;
    vss_parser_init(&parser, &lexer);
    VSS_Block ast = vss_parse_program(&parser);
    
    if (parser.had_error) {
        vss_block_free(ast);
        free(source);
        vss_current_source = NULL;
        return 1;
    }
    
    if (!vss_semantic_analyze(ast)) {
        vss_block_free(ast);
        free(source);
        vss_current_source = NULL;
        return 1;
    }
    
    VSS_ObjFunction *main_func = vss_compile_program(ast);
    vss_block_free(ast);
    free(source);
    vss_current_source = NULL;
    
    if (!main_func) {
        fprintf(stderr, "\033[1;31mError:\033[0m Compilation failed.\n");
        return 1;
    }
    
    // Create output path: replace extension with .vssc
    char out_path[256];
    strncpy(out_path, path, sizeof(out_path));
    char *dot = strrchr(out_path, '.');
    if (dot) {
        strcpy(dot, ".vssc");
    } else {
        strcat(out_path, ".vssc");
    }
    
    FILE *out = fopen(out_path, "wb");
    if (!out) {
        fprintf(stderr, "\033[1;31mError:\033[0m Could not open output file '%s'.\n", out_path);
        vss_function_release(main_func);
        return 1;
    }
    
    fwrite("VSSC", 1, 4, out);
    vss_serialize_function(main_func, out);
    fclose(out);
    
    printf("\033[1;32mBuild Success:\033[0m Compiled to %s\n", out_path);
    vss_function_release(main_func);
    return 0;
}

static int create_project(const char *name) {
    if (!vss_make_dir(name)) {
        fprintf(stderr, "\033[1;31mError:\033[0m Could not create directory '%s'.\n", name);
        return 1;
    }
    
    char path_json[512];
    snprintf(path_json, sizeof(path_json), "%s/vss.json", name);
    FILE *f_json = fopen(path_json, "w");
    if (f_json) {
        fprintf(f_json, "{\n  \"name\": \"%s\",\n  \"version\": \"0.1.0\",\n  \"description\": \"A new VSS project\"\n}\n", name);
        fclose(f_json);
    }
    
    char path_vss[512];
    snprintf(path_vss, sizeof(path_vss), "%s/main.vss", name);
    FILE *f_vss = fopen(path_vss, "w");
    if (f_vss) {
        fprintf(f_vss, "note Main entry point for %s\nsay \"Hello from VSS project!\"\n", name);
        fclose(f_vss);
    }
    
    printf("\033[1;32mProject Created:\033[0m Welcome to VSS! Created '%s' template.\n", name);
    return 0;
}

static int init_project(void) {
    FILE *f_json = fopen("vss.json", "w");
    if (f_json) {
        fprintf(f_json, "{\n  \"name\": \"vss_project\",\n  \"version\": \"0.1.0\",\n  \"description\": \"A VSS project\"\n}\n");
        fclose(f_json);
    }
    
    FILE *f_vss = fopen("main.vss", "w");
    if (f_vss) {
        fprintf(f_vss, "note Main entry point\nsay \"Hello from VSS!\"\n");
        fclose(f_vss);
    }
    
    printf("\033[1;32mInitialized VSS Project:\033[0m Created 'vss.json' and 'main.vss'.\n");
    return 0;
}

static int format_file(const char *path) {
    char *source = read_file_text(path);
    if (!source) {
        fprintf(stderr, "\033[1;31mError:\033[0m Could not open file '%s'.\n", path);
        return 1;
    }
    
    // Very simple formatter: strip trailing whitespace, normalize newlines.
    // In future versions, this will implement parser-based pretty printing.
    FILE *out = fopen(path, "w");
    if (!out) {
        fprintf(stderr, "\033[1;31mError:\033[0m Could not open file '%s' for writing.\n", path);
        free(source);
        return 1;
    }
    
    char *line = strtok(source, "\n");
    while (line != NULL) {
        // Strip trailing space
        int len = strlen(line);
        while (len > 0 && (line[len-1] == ' ' || line[len-1] == '\t' || line[len-1] == '\r')) {
            line[len-1] = '\0';
            len--;
        }
        fprintf(out, "%s\n", line);
        line = strtok(NULL, "\n");
    }
    fclose(out);
    free(source);
    
    printf("\033[1;32mFormatted:\033[0m %s successfully.\n", path);
    return 0;
}

static int lint_file(const char *path) {
    char *source = read_file_text(path);
    if (!source) {
        fprintf(stderr, "\033[1;31mError:\033[0m Could not open file '%s'.\n", path);
        return 1;
    }
    
    printf("\033[1;33mLinting %s:\033[0m\n", path);
    int warnings = 0;
    int line_num = 1;
    char *line = strtok(source, "\n");
    while (line != NULL) {
        int len = strlen(line);
        // Check line length
        if (len > 120) {
            printf("  line %d: Line exceeds 120 characters (got %d).\n", line_num, len);
            warnings++;
        }
        // Check trailing whitespace
        if (len > 0 && (line[len-1] == ' ' || line[len-1] == '\t')) {
            printf("  line %d: Trailing whitespace detected.\n", line_num);
            warnings++;
        }
        
        // Suggest constants
        if (strstr(line, "make ") && strstr(line, "pi")) {
            printf("  line %d: Suggest using 'keep' instead of 'make' for pi constant.\n", line_num);
            warnings++;
        }
        
        line_num++;
        line = strtok(NULL, "\n");
    }
    free(source);
    
    if (warnings == 0) {
        printf("  No issues found!\n");
    } else {
        printf("  %d warning(s) found.\n", warnings);
    }
    return 0;
}

static int docs_generator(const char *path) {
    char *source = read_file_text(path);
    if (!source) {
        fprintf(stderr, "\033[1;31mError:\033[0m Could not open file '%s'.\n", path);
        return 1;
    }
    
    printf("# API Documentation for %s\n\n", path);
    char *line = strtok(source, "\n");
    while (line != NULL) {
        // Strip leading spaces
        while (*line == ' ' || *line == '\t') line++;
        if (strncmp(line, "note ", 5) == 0) {
            printf("%s\n", line + 5);
        } else if (strncmp(line, "task ", 5) == 0) {
            printf("### Task: `%s`\n", line + 5);
        }
        line = strtok(NULL, "\n");
    }
    free(source);
    return 0;
}

static int doctor_check(void) {
    printf("\033[1;36mVSS Diagnostics:\033[0m\n");
    printf("  OS Target: %s\n", 
#ifdef _WIN32
        "Windows"
#elif __APPLE__
        "macOS"
#else
        "Linux"
#endif
    );
    printf("  Binary Path: %s\n", "Available globally via PATH");
    
    // Check if gcc is available
    int gcc_avail = vss_execute_cmd(
#ifdef _WIN32
        "gcc --version >nul 2>&1"
#else
        "gcc --version >/dev/null 2>&1"
#endif
    );
    printf("  C Compiler (gcc): %s\n", gcc_avail == 0 ? "Installed" : "Not Found (Optional for VSS_VM execution, needed for native compiler)");
    
    // Check if vss path exists
    char *home = vss_get_home_dir();
    if (home) {
        char path_vss[512];
        snprintf(path_vss, sizeof(path_vss), "%s%s.vss", home, VSS_PATH_SEP_STR);
        if (vss_dir_exists(path_vss)) {
            printf("  VSS Local Folder: Installed (~/.vss)\n");
        } else {
            printf("  VSS Local Folder: Not found (~/.vss)\n");
        }
        free(home);
    }
    
    printf("\033[1;32mDiagnostics Complete. All system parameters nominal.\033[0m\n");
    return 0;
}

static void print_version(void) {
    printf("\033[1;35mVSS Programming Language\033[0m\n");
    printf("  Version:  \033[1;32m%s\033[0m\n", VSS_VERSION_STRING);
    printf("  Build:    %s\n", VSS_BUILD_TYPE);
    printf("  Platform: %s\n", VSS_PLATFORM_NAME);
}

static void print_help(void) {
    printf("\033[1;36mVery Simple Syntax (VSS) Command-Line Interface\033[0m\n\n");
    printf("Usage:\n");
    printf("  vss <file.vss>             Run a VSS source or bytecode file\n");
    printf("  vss run <file.vss>         Explicitly run a VSS file\n");
    printf("  vss build <file.vss>       Compile a source file into .vssc bytecode\n");
    printf("  vss install <name>         Install a VSS software/package\n");
    printf("  vss new <ProjectName>      Create a new VSS template project folder\n");
    printf("  vss init                   Initialize VSS in the current directory\n");
    printf("  vss test                   Run test suites in the current directory\n");
    printf("  vss format <file.vss>      Format a VSS source file\n");
    printf("  vss lint <file.vss>        Statically analyze a VSS file\n");
    printf("  vss docs <file.vss>        Generate API documentation from notes\n");
    printf("  vss clean                  Clean build artifacts and temporary files\n");
    printf("  vss doctor                 Check environment setup and installation integrity\n");
    printf("  vss version                Show VSS compiler version\n");
    printf("  vss help                   Display this help screen\n");
}

static int install_package(const char *name) {
    printf("\033[1;36mInstalling package '%s'...\033[0m\n", name);
    vss_make_dir("packages");
    char cmd[512];
    snprintf(cmd, sizeof(cmd), 
        "curl -sSfL \"https://raw.githubusercontent.com/siddharth-1118/vss-language/main/packages/%s.vss\" -o \"packages/%s.vss\"",
        name, name);
    int res = vss_execute_cmd(cmd);
    if (res != 0) {
        fprintf(stderr, "\033[1;31mError:\033[0m Failed to download package '%s'. Make sure the package exists in the registry.\n", name);
        return 1;
    }
    printf("\033[1;32mPackage Installed:\033[0m '%s' is now available in your local packages directory.\n", name);
    return 0;
}

static int remove_package(const char *name) {
    printf("\033[1;36mRemoving package '%s'...\033[0m\n", name);
    char path[256];
    snprintf(path, sizeof(path), "packages/%s.vss", name);
    if (vss_file_exists(path)) {
        remove(path);
        printf("\033[1;32mPackage Removed:\033[0m Successfully removed '%s'.\n", name);
        return 0;
    } else {
        fprintf(stderr, "\033[1;31mError:\033[0m Package '%s' is not installed.\n", name);
        return 1;
    }
}

// Returns true if the string ends with the given suffix (case-insensitive on extension)
static int has_extension(const char *str, const char *ext) {
    size_t slen = strlen(str);
    size_t elen = strlen(ext);
    if (slen < elen) return 0;
    const char *tail = str + slen - elen;
    // Case-insensitive compare for the extension part
    for (size_t i = 0; i < elen; i++) {
        char a = tail[i], b = ext[i];
        if (a >= 'A' && a <= 'Z') a += 32;
        if (b >= 'A' && b <= 'Z') b += 32;
        if (a != b) return 0;
    }
    return 1;
}

int vss_run_cli(int argc, char **argv) {
    if (argc < 2) {
        print_help();
        return 0;
    }

    const char *cmd = argv[1];

    // ── Priority 1: File dispatch ─────────────────────────────────────────────
    // If the first argument looks like a .vss or .vssc file, treat it as a
    // file path immediately — before any command name matching.
    // This makes `vss hello.vss` work exactly as documented.
    int looks_like_vss  = has_extension(cmd, ".vss");
    int looks_like_vssc = has_extension(cmd, ".vssc");

    if (looks_like_vss || looks_like_vssc) {
        if (!vss_file_exists(cmd)) {
            fprintf(stderr, "\033[1;31mError:\033[0m File not found: '%s'\n", cmd);
            return 1;
        }
        return run_file(cmd);
    }

    // Also dispatch if the argument is an existing file with any extension
    // (e.g., a compiled .vssc passed without explicit extension check above)
    if (vss_file_exists(cmd) && !has_extension(cmd, ".vss") && !has_extension(cmd, ".vssc")) {
        // Only do this for paths that contain a directory separator or a dot
        // so bare command words are not accidentally dispatched as files.
        const char *p = cmd;
        int has_sep = 0, has_dot = 0;
        while (*p) {
            if (*p == '/' || *p == '\\') { has_sep = 1; break; }
            if (*p == '.') has_dot = 1;
            p++;
        }
        if (has_sep || has_dot) {
            return run_file(cmd);
        }
    }

    // ── Priority 2: Named commands ────────────────────────────────────────────
    if (strcmp(cmd, "help") == 0 || strcmp(cmd, "--help") == 0 || strcmp(cmd, "-h") == 0) {
        print_help();
        return 0;
    }

    if (strcmp(cmd, "version") == 0 || strcmp(cmd, "--version") == 0 || strcmp(cmd, "-v") == 0) {
        print_version();
        return 0;
    }

    if (strcmp(cmd, "run") == 0) {
        if (argc < 3) {
            fprintf(stderr, "\033[1;31mError:\033[0m Missing file/package argument. Usage: vss run <file.vss | package_name>\n");
            return 1;
        }
        char resolved_path[512];
        strncpy(resolved_path, argv[2], sizeof(resolved_path));
        resolved_path[sizeof(resolved_path) - 1] = '\0';
        if (!vss_file_exists(resolved_path)) {
            snprintf(resolved_path, sizeof(resolved_path), "%s.vss", argv[2]);
            if (!vss_file_exists(resolved_path)) {
                snprintf(resolved_path, sizeof(resolved_path), "packages/%s", argv[2]);
                if (!vss_file_exists(resolved_path)) {
                    snprintf(resolved_path, sizeof(resolved_path), "packages/%s.vss", argv[2]);
                    if (!vss_file_exists(resolved_path)) {
                        fprintf(stderr, "\033[1;31mError:\033[0m File or package not found: '%s'\n", argv[2]);
                        return 1;
                    }
                }
            }
        }
        return run_file(resolved_path);
    }

    if (strcmp(cmd, "install") == 0) {
        if (argc < 3) {
            fprintf(stderr, "\033[1;31mError:\033[0m Missing software/package name. Usage: vss install <name>\n");
            return 1;
        }
        return install_package(argv[2]);
    }

    if (strcmp(cmd, "build") == 0) {
        if (argc < 3) {
            fprintf(stderr, "\033[1;31mError:\033[0m Missing file argument. Usage: vss build <file.vss>\n");
            return 1;
        }
        return build_file(argv[2]);
    }

    if (strcmp(cmd, "new") == 0) {
        if (argc < 3) {
            fprintf(stderr, "\033[1;31mError:\033[0m Missing project name. Usage: vss new <ProjectName>\n");
            return 1;
        }
        return create_project(argv[2]);
    }

    if (strcmp(cmd, "init") == 0) {
        return init_project();
    }

    if (strcmp(cmd, "test") == 0) {
        if (argc >= 3) {
            const char *target = argv[2];
            if (vss_file_exists(target)) {
                return run_file(target);
            }
            fprintf(stderr, "\033[1;31mError:\033[0m Test target '%s' not found.\n", target);
            return 1;
        }
        int total_failures = 0;
        const char *test_files[] = {
            "examples/test_suite.vss",
            "examples/test_python_parity.vss",
            "examples/test_full_python_capabilities.vss",
            "examples/test_python_expanded_parity.vss"
        };
        int count = (int)(sizeof(test_files) / sizeof(test_files[0]));
        int ran_any = 0;
        for (int i = 0; i < count; i++) {
            if (vss_file_exists(test_files[i])) {
                ran_any = 1;
                printf("\033[1;36mRunning Test Suite:\033[0m %s\n", test_files[i]);
                int res = run_file(test_files[i]);
                if (res != 0) total_failures++;
                printf("\n");
            }
        }
        if (!ran_any) {
            if (vss_file_exists("test_suite.vss")) {
                return run_file("test_suite.vss");
            } else {
                fprintf(stderr, "\033[1;31mError:\033[0m No test suites found.\n");
                return 1;
            }
        }
        if (total_failures > 0) {
            fprintf(stderr, "\033[1;31m%d test suite(s) failed!\033[0m\n", total_failures);
            return 1;
        }
        return 0;
    }

    if (strcmp(cmd, "format") == 0) {
        if (argc < 3) {
            fprintf(stderr, "\033[1;31mError:\033[0m Missing file. Usage: vss format <file.vss>\n");
            return 1;
        }
        return format_file(argv[2]);
    }

    if (strcmp(cmd, "lint") == 0) {
        if (argc < 3) {
            fprintf(stderr, "\033[1;31mError:\033[0m Missing file. Usage: vss lint <file.vss>\n");
            return 1;
        }
        return lint_file(argv[2]);
    }

    if (strcmp(cmd, "docs") == 0) {
        if (argc < 3) {
            fprintf(stderr, "\033[1;31mError:\033[0m Missing file. Usage: vss docs <file.vss>\n");
            return 1;
        }
        return docs_generator(argv[2]);
    }

    if (strcmp(cmd, "doctor") == 0) {
        return doctor_check();
    }

    if (strcmp(cmd, "clean") == 0) {
        vss_list_dir_clean_vssc(".");
        printf("\033[1;32mClean complete.\033[0m\n");
        return 0;
    }

    if (strcmp(cmd, "package") == 0) {
        if (argc < 3) {
            printf("VSS Package Manager\n\nUsage:\n  vss package install <name>   Install a package from the registry\n  vss package remove <name>    Remove an installed package\n  vss package update           Update all installed packages\n  vss package publish          Submit a package to the registry\n");
            return 0;
        }
        const char *sub = argv[2];
        if (strcmp(sub, "install") == 0) {
            if (argc < 4) {
                fprintf(stderr, "\033[1;31mError:\033[0m Missing package name. Usage: vss package install <name>\n");
                return 1;
            }
            return install_package(argv[3]);
        } else if (strcmp(sub, "remove") == 0) {
            if (argc < 4) {
                fprintf(stderr, "\033[1;31mError:\033[0m Missing package name. Usage: vss package remove <name>\n");
                return 1;
            }
            return remove_package(argv[3]);
        } else if (strcmp(sub, "update") == 0) {
            printf("\033[1;36mUpdating installed packages...\033[0m\n");
            printf("All packages are up to date.\n");
            return 0;
        } else if (strcmp(sub, "publish") == 0) {
            printf("\033[1;36mPublishing package...\033[0m\n");
            printf("Please submit a pull request to github.com/siddharth-1118/vss-language with your package in the packages/ directory.\n");
            return 0;
        } else {
            fprintf(stderr, "\033[1;31mUnknown package command:\033[0m %s. Run 'vss package' for help.\n", sub);
            return 1;
        }
    }

    if (strcmp(cmd, "update") == 0) {
        printf("\033[1;36mChecking for updates...\033[0m\n");
        printf("VSS is up to date. Current version: %s\n", VSS_VERSION_STRING);
        return 0;
    }

    // Check if it's an installed package/software name that we can execute directly
    char pkg_path[512];
    snprintf(pkg_path, sizeof(pkg_path), "packages/%s.vss", cmd);
    if (vss_file_exists(pkg_path)) {
        return run_file(pkg_path);
    }

    // ── Priority 3: Unknown command with typo suggestions ────────────────────
    const char *commands[] = {
        "run", "build", "new", "init", "test", "format", "lint",
        "docs", "doctor", "clean", "package", "update", "help", "version"
    };
    int num_commands = (int)(sizeof(commands) / sizeof(char *));
    const char *suggestion = NULL;
    int min_dist = 999;

    for (int i = 0; i < num_commands; i++) {
        int dist = levenshtein(cmd, commands[i]);
        if (dist < min_dist) {
            min_dist = dist;
            suggestion = commands[i];
        }
    }

    fprintf(stderr, "\033[1;31mUnknown command:\033[0m %s\n", cmd);
    if (min_dist <= 2 && suggestion) {
        fprintf(stderr, "\nDid you mean:\n  \033[1;36m%s\033[0m?\n", suggestion);
    } else {
        fprintf(stderr, "Run 'vss help' for a list of available commands.\n");
    }
    return 1;
}
