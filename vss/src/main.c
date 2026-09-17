#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef _WIN32
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <sys/types.h>
#else
#include <io.h>
#define dup _dup
#define dup2 _dup2
#define close _close
#endif
#include "platform.h"

#include "lexer.h"
#include "parser.h"
#include "interpreter.h"
#include "env.h"
#include "ast.h"
#include "compiler.h"
#include "vm.h"
#include "cli.h"
#include "vss_concurrency.h"

// Set buffered trace flag to 0 since we cleaned up trace logs in vm.c

static char *read_file_text(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) return NULL;

    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    rewind(file);

    char *buffer = (char *)malloc((size_t)size + 1);
    size_t read_count = fread(buffer, 1, (size_t)size, file);
    fclose(file);

    if (read_count != (size_t)size) {
        free(buffer);
        fprintf(stderr, "Could not fully read file: %s\n", path);
        return NULL;
    }

    buffer[size] = '\0';
    return buffer;
}

static char selected_default_file[256] = "";

static void start_server(int port) {
    if (!vss_network_init()) {
        fprintf(stderr, "Failed to initialize network system.\n");
        return;
    }

    VSS_Socket server_fd = vss_socket_create();
    if (server_fd == VSS_INVALID_SOCKET) {
        perror("socket failed");
        vss_network_cleanup();
        return;
    }
    
    if (!vss_socket_bind(server_fd, port)) {
        perror("bind failed");
        vss_socket_close(server_fd);
        vss_network_cleanup();
        return;
    }
    
    if (!vss_socket_listen(server_fd, 10)) {
        perror("listen failed");
        vss_socket_close(server_fd);
        vss_network_cleanup();
        return;
    }

    // Scan for htmvss files in current working directory
    char **filenames = NULL;
    int count = vss_scan_htmvss(".", &filenames);
    bool found_default = false;

    if (count == 0) {
        printf("No .htmvss files found in the current project.\n");
    } else {
        // 1. check for index.htmvss
        for (int i = 0; i < count; i++) {
            if (strcmp(filenames[i], "index.htmvss") == 0) {
                strncpy(selected_default_file, "index.htmvss", sizeof(selected_default_file) - 1);
                found_default = true;
                break;
            }
        }
        // 2. check for main.htmvss
        if (!found_default) {
            for (int i = 0; i < count; i++) {
                if (strcmp(filenames[i], "main.htmvss") == 0) {
                    strncpy(selected_default_file, "main.htmvss", sizeof(selected_default_file) - 1);
                    found_default = true;
                    break;
                }
            }
        }
        // 3. check for single file
        if (!found_default) {
            if (count == 1) {
                strncpy(selected_default_file, filenames[0], sizeof(selected_default_file) - 1);
                found_default = true;
            } else {
                // 4. multiple files: list and select
                printf("Multiple .htmvss files found:\n");
                for (int i = 0; i < count; i++) {
                    printf("  %d) %s\n", i + 1, filenames[i]);
                }
                printf("Enter number to select (default is 1): ");
                int choice = 1;
                char input_buf[64];
                if (fgets(input_buf, sizeof(input_buf), stdin)) {
                    int parsed = atoi(input_buf);
                    if (parsed >= 1 && parsed <= count) {
                        choice = parsed;
                    }
                }
                strncpy(selected_default_file, filenames[choice - 1], sizeof(selected_default_file) - 1);
                found_default = true;
            }
        }
    }

    if (filenames) {
        for (int i = 0; i < count; i++) {
            free(filenames[i]);
        }
        free(filenames);
    }
    
    fprintf(stderr, "VSS Dev Server started on http://localhost:%d/\n", port);
    fprintf(stderr, "Press Ctrl+C to stop.\n");
    
    if (found_default && strlen(selected_default_file) > 0) {
        if (vss_file_exists(selected_default_file)) {
            vss_launch_browser(port, selected_default_file);
        }
    }
    
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
            char *filename = path;
            if (filename[0] == '/') filename++;
            if (strlen(filename) == 0) {
                filename = selected_default_file;
            }
            
            size_t fn_len = strlen(filename);
            bool is_htmvss = (fn_len > 7 && strcmp(filename + fn_len - 7, ".htmvss") == 0);
            
            FILE *f = fopen(filename, "r");
            if (!f) {
                const char *res_404 = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nFile Not Found";
                vss_socket_send(client_fd, res_404, strlen(res_404));
            } else {
                fclose(f);
                if (is_htmvss) {
                    int stdout_dup = dup(1);
                    FILE *temp_f = freopen("temp_serve.html", "w", stdout);
                    if (temp_f) {
                        char *source = read_file_text(filename);
                        if (source) {
                            VSS_Lexer lexer;
                            vss_lexer_init(&lexer, source);
                            VSS_Parser parser;
                            vss_parser_init(&parser, &lexer);
                            VSS_Block ast = vss_parse_program(&parser);
                            if (!parser.had_error) {
                                VSS_ObjFunction *main_func = vss_compile_program(ast);
                                VSS_Env *global_env = vss_env_new(NULL);
                                vss_register_builtins(global_env);
                                bool run_success = vss_vm_run(main_func, global_env);
                                if (!run_success) {
                                    printf("\n<div style='color:red;border:1px solid red;padding:10px;margin-top:10px;'>VSS_VM Runtime Error</div>");
                                }
                                vss_env_release(global_env);
                                vss_function_release(main_func);
                            } else {
                                printf("\n<div style='color:red;border:1px solid red;padding:10px;margin-top:10px;'>VSS_Parser Syntax Error</div>");
                            }
                            vss_block_free(ast);
                            free(source);
                        }
                        fflush(stdout);
                        dup2(stdout_dup, 1);
                        close(stdout_dup);
                        
                        char *html = read_file_text("temp_serve.html");
                        remove("temp_serve.html");
                        if (html) {
                            char headers[512];
                            snprintf(headers, sizeof(headers), "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %zu\r\nConnection: close\r\n\r\n", strlen(html));
                            vss_socket_send(client_fd, headers, strlen(headers));
                            vss_socket_send(client_fd, html, strlen(html));
                            free(html);
                        } else {
                            const char *res_500 = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nCould not read VSS output";
                            vss_socket_send(client_fd, res_500, strlen(res_500));
                        }
                    } else {
                        dup2(stdout_dup, 1);
                        close(stdout_dup);
                        const char *res_500 = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nCould not redirect stdout";
                        vss_socket_send(client_fd, res_500, strlen(res_500));
                    }
                } else {
                    char *content = read_file_text(filename);
                    if (content) {
                        char headers[512];
                        snprintf(headers, sizeof(headers), "HTTP/1.1 200 OK\r\nContent-Length: %zu\r\nConnection: close\r\n\r\n", strlen(content));
                        vss_socket_send(client_fd, headers, strlen(headers));
                        vss_socket_send(client_fd, content, strlen(content));
                        free(content);
                    } else {
                        const char *res_500 = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nCould not read file";
                        vss_socket_send(client_fd, res_500, strlen(res_500));
                    }
                }
            }
        }
        vss_socket_close(client_fd);
    }
    vss_socket_close(server_fd);
    vss_network_cleanup();
}

int main(int argc, char **argv) {
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);
    vss_concurrency_init();
    extern void vss_set_args(int argc, char **argv);
    vss_set_args(argc, argv);
    int res = 0;
    if (argc == 2 && (strcmp(argv[1], "--serve") == 0 || strcmp(argv[1], "-s") == 0)) {
        start_server(8080);
    } else {
        res = vss_run_cli(argc, argv);
    }
    vss_concurrency_cleanup();
    return res;
}
