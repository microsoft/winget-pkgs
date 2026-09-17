#include "platform.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

VSS_THREAD_LOCAL const char *vss_current_source = NULL;

static char *platform_strdup(const char *s) {
    if (!s) return NULL;
    char *dup = malloc(strlen(s) + 1);
    if (dup) {
        strcpy(dup, s);
    }
    return dup;
}

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#include <windows.h>
#include <shellapi.h>

bool vss_network_init(void) {
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2,2), &wsa) != 0) {
        return false;
    }
    return true;
}

void vss_network_cleanup(void) {
    WSACleanup();
}

VSS_Socket vss_socket_create(void) {
    VSS_Socket sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == INVALID_SOCKET) return VSS_INVALID_SOCKET;
    
    // Set reuseaddr
    int opt = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (const char *)&opt, sizeof(opt));
    return sock;
}

bool vss_socket_bind(VSS_Socket sock, int port) {
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);
    if (bind(sock, (struct sockaddr *)&address, sizeof(address)) == SOCKET_ERROR) {
        return false;
    }
    return true;
}

bool vss_socket_listen(VSS_Socket sock, int backlog) {
    if (listen(sock, backlog) == SOCKET_ERROR) {
        return false;
    }
    return true;
}

VSS_Socket vss_socket_accept(VSS_Socket sock) {
    VSS_Socket client = accept(sock, NULL, NULL);
    if (client == INVALID_SOCKET) return VSS_INVALID_SOCKET;
    return client;
}

int vss_socket_send(VSS_Socket sock, const char *buf, int len) {
    return send(sock, buf, len, 0);
}

int vss_socket_recv(VSS_Socket sock, char *buf, int len) {
    return recv(sock, buf, len, 0);
}

void vss_socket_close(VSS_Socket sock) {
    if (sock != INVALID_SOCKET) {
        closesocket(sock);
    }
}

bool vss_file_exists(const char *path) {
    DWORD dwAttrib = GetFileAttributesA(path);
    return (dwAttrib != INVALID_FILE_ATTRIBUTES && !(dwAttrib & FILE_ATTRIBUTE_DIRECTORY));
}

bool vss_dir_exists(const char *path) {
    DWORD dwAttrib = GetFileAttributesA(path);
    return (dwAttrib != INVALID_FILE_ATTRIBUTES && (dwAttrib & FILE_ATTRIBUTE_DIRECTORY));
}

bool vss_make_dir(const char *path) {
    return CreateDirectoryA(path, NULL) != 0 || GetLastError() == ERROR_ALREADY_EXISTS;
}

bool vss_list_dir_clean_vssc(const char *path) {
    size_t path_len = strlen(path);
    size_t total_len = path_len + 8; // path + "\\*.vssc" + null
    char *search_path = malloc(total_len);
    if (!search_path) return false;
    snprintf(search_path, total_len, "%s\\*.vssc", path);
    
    WIN32_FIND_DATAA fd;
    HANDLE hFind = FindFirstFileA(search_path, &fd);
    free(search_path);
    if (hFind != INVALID_HANDLE_VALUE) {
        do {
            size_t file_len = strlen(fd.cFileName);
            size_t fp_len = path_len + 1 + file_len + 1; // path + "\\" + file + null
            char *filepath = malloc(fp_len);
            if (filepath) {
                snprintf(filepath, fp_len, "%s\\%s", path, fd.cFileName);
                DeleteFileA(filepath);
                free(filepath);
            }
            printf("  Removed: %s\n", fd.cFileName);
        } while (FindNextFileA(hFind, &fd));
        FindClose(hFind);
    }
    return true;
}

int vss_scan_htmvss(const char *path, char ***filenames) {
    size_t path_len = strlen(path);
    size_t total_len = path_len + 10; // path + "\\*.htmvss" + null
    char *search_path = malloc(total_len);
    if (!search_path) {
        *filenames = NULL;
        return 0;
    }
    snprintf(search_path, total_len, "%s\\*.htmvss", path);
    
    WIN32_FIND_DATAA fd;
    HANDLE hFind = FindFirstFileA(search_path, &fd);
    free(search_path);
    if (hFind == INVALID_HANDLE_VALUE) {
        *filenames = NULL;
        return 0;
    }
    
    int count = 0;
    char **list = NULL;
    do {
        list = realloc(list, sizeof(char*) * (count + 1));
        list[count] = platform_strdup(fd.cFileName);
        count++;
    } while (FindNextFileA(hFind, &fd));
    
    FindClose(hFind);
    *filenames = list;
    return count;
}

int vss_list_dir(const char *path, char ***filenames) {
    size_t path_len = strlen(path);
    size_t total_len = path_len + 5; // path + "\\*" + null
    char *search_path = malloc(total_len);
    if (!search_path) {
        *filenames = NULL;
        return 0;
    }
    snprintf(search_path, total_len, "%s\\*", path);
    
    WIN32_FIND_DATAA fd;
    HANDLE hFind = FindFirstFileA(search_path, &fd);
    free(search_path);
    if (hFind == INVALID_HANDLE_VALUE) {
        *filenames = NULL;
        return 0;
    }
    
    int count = 0;
    char **list = NULL;
    do {
        if (strcmp(fd.cFileName, ".") == 0 || strcmp(fd.cFileName, "..") == 0) {
            continue;
        }
        list = realloc(list, sizeof(char*) * (count + 1));
        list[count] = platform_strdup(fd.cFileName);
        count++;
    } while (FindNextFileA(hFind, &fd));
    
    FindClose(hFind);
    *filenames = list;
    return count;
}

void vss_launch_browser(int port, const char *filename) {
    char url[512];
    snprintf(url, sizeof(url), "http://localhost:%d/%s", port, filename);
    ShellExecuteA(NULL, "open", url, NULL, NULL, SW_SHOWNORMAL);
}

int vss_execute_cmd(const char *cmd) {
    return system(cmd);
}

char *vss_get_home_dir(void) {
    const char *home = getenv("USERPROFILE");
    if (!home) {
        const char *drive = getenv("HOMEDRIVE");
        const char *path = getenv("HOMEPATH");
        if (drive && path) {
            char *buf = malloc(strlen(drive) + strlen(path) + 1);
            sprintf(buf, "%s%s", drive, path);
            return buf;
        }
    }
    return home ? platform_strdup(home) : NULL;
}

typedef struct {
    VSS_ThreadFunc func;
    void *arg;
} WinThreadAdapterArg;

static DWORD WINAPI win_thread_proc(LPVOID lpParam) {
    WinThreadAdapterArg *adapter = (WinThreadAdapterArg *)lpParam;
    VSS_ThreadFunc fn = adapter->func;
    void *arg = adapter->arg;
    free(adapter);
    void *res = fn(arg);
    return (DWORD)(uintptr_t)res;
}

bool vss_thread_create(VSS_Thread *thread, VSS_ThreadFunc func, void *arg) {
    WinThreadAdapterArg *adapter = malloc(sizeof(WinThreadAdapterArg));
    if (!adapter) return false;
    adapter->func = func;
    adapter->arg = arg;
    *thread = CreateThread(NULL, 0, win_thread_proc, adapter, 0, NULL);
    if (*thread == NULL) {
        free(adapter);
        return false;
    }
    return true;
}

bool vss_thread_join(VSS_Thread thread, void **retval) {
    if (!thread) return false;
    DWORD res = WaitForSingleObject(thread, INFINITE);
    if (res != WAIT_OBJECT_0) return false;
    if (retval) {
        DWORD exit_code = 0;
        GetExitCodeThread(thread, &exit_code);
        *retval = (void *)(uintptr_t)exit_code;
    }
    CloseHandle(thread);
    return true;
}

void vss_mutex_init(VSS_Mutex *mutex) {
    InitializeCriticalSection(mutex);
}

void vss_mutex_lock(VSS_Mutex *mutex) {
    EnterCriticalSection(mutex);
}

void vss_mutex_unlock(VSS_Mutex *mutex) {
    LeaveCriticalSection(mutex);
}

void vss_mutex_destroy(VSS_Mutex *mutex) {
    DeleteCriticalSection(mutex);
}

void vss_cond_init(VSS_Cond *cond) {
    InitializeConditionVariable(cond);
}

void vss_cond_wait(VSS_Cond *cond, VSS_Mutex *mutex) {
    SleepConditionVariableCS(cond, mutex, INFINITE);
}

bool vss_cond_timedwait(VSS_Cond *cond, VSS_Mutex *mutex, int timeout_ms) {
    return SleepConditionVariableCS(cond, mutex, (DWORD)timeout_ms) != 0;
}

void vss_cond_signal(VSS_Cond *cond) {
    WakeConditionVariable(cond);
}

void vss_cond_broadcast(VSS_Cond *cond) {
    WakeAllConditionVariable(cond);
}

void vss_cond_destroy(VSS_Cond *cond) {
    (void)cond;
}

int vss_atomic_inc(VSS_AtomicInt *ptr) {
    return (int)InterlockedIncrement(ptr);
}

int vss_atomic_dec(VSS_AtomicInt *ptr) {
    return (int)InterlockedDecrement(ptr);
}

int vss_atomic_add(VSS_AtomicInt *ptr, int val) {
    return (int)InterlockedAdd(ptr, val);
}

int vss_atomic_get(VSS_AtomicInt *ptr) {
    return (int)InterlockedCompareExchange(ptr, 0, 0);
}

void vss_atomic_set(VSS_AtomicInt *ptr, int val) {
    InterlockedExchange(ptr, (LONG)val);
}

bool vss_atomic_cas(VSS_AtomicInt *ptr, int old_val, int new_val) {
    return InterlockedCompareExchange(ptr, (LONG)new_val, (LONG)old_val) == (LONG)old_val;
}

void vss_sleep_ms(int ms) {
    Sleep((DWORD)ms);
}

int vss_get_hardware_concurrency(void) {
    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);
    return (int)sysinfo.dwNumberOfProcessors;
}

void *vss_dl_open(const char *path) {
    if (!path) return NULL;
    return (void *)LoadLibraryA(path);
}

void *vss_dl_sym(void *handle, const char *symbol) {
    if (!handle || !symbol) return NULL;
    return (void *)GetProcAddress((HMODULE)handle, symbol);
}

void vss_dl_close(void *handle) {
    if (handle) FreeLibrary((HMODULE)handle);
}

#else
// POSIX Implementation (Linux/macOS)
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>

bool vss_network_init(void) {
    return true;
}

void vss_network_cleanup(void) {
    // No-op
}

VSS_Socket vss_socket_create(void) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return VSS_INVALID_SOCKET;
    
    int opt = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    return sock;
}

bool vss_socket_bind(VSS_Socket sock, int port) {
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);
    if (bind(sock, (struct sockaddr *)&address, sizeof(address)) < 0) {
        return false;
    }
    return true;
}

bool vss_socket_listen(VSS_Socket sock, int backlog) {
    if (listen(sock, backlog) < 0) {
        return false;
    }
    return true;
}

VSS_Socket vss_socket_accept(VSS_Socket sock) {
    int client = accept(sock, NULL, NULL);
    if (client < 0) return VSS_INVALID_SOCKET;
    return client;
}

int vss_socket_send(VSS_Socket sock, const char *buf, int len) {
    return send(sock, buf, len, 0);
}

int vss_socket_recv(VSS_Socket sock, char *buf, int len) {
    return recv(sock, buf, len, 0);
}

void vss_socket_close(VSS_Socket sock) {
    if (sock >= 0) {
        close(sock);
    }
}

bool vss_file_exists(const char *path) {
    return access(path, F_OK) == 0;
}

bool vss_dir_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

bool vss_make_dir(const char *path) {
    return mkdir(path, 0777) == 0;
}

bool vss_list_dir_clean_vssc(const char *path) {
    DIR *d = opendir(path);
    if (d) {
        size_t path_len = strlen(path);
        struct dirent *dir;
        while ((dir = readdir(d)) != NULL) {
            char *ext = strrchr(dir->d_name, '.');
            if (ext && strcmp(ext, ".vssc") == 0) {
                size_t file_len = strlen(dir->d_name);
                size_t fp_len = path_len + 1 + file_len + 1; // path + "/" + file + null
                char *filepath = malloc(fp_len);
                if (filepath) {
                    snprintf(filepath, fp_len, "%s/%s", path, dir->d_name);
                    remove(filepath);
                    free(filepath);
                }
                printf("  Removed: %s\n", dir->d_name);
            }
        }
        closedir(d);
    }
    return true;
}

int vss_scan_htmvss(const char *path, char ***filenames) {
    DIR *d = opendir(path);
    if (!d) {
        *filenames = NULL;
        return 0;
    }
    
    int count = 0;
    char **list = NULL;
    struct dirent *dir;
    while ((dir = readdir(d)) != NULL) {
        char *ext = strrchr(dir->d_name, '.');
        if (ext && strcmp(ext, ".htmvss") == 0) {
            list = realloc(list, sizeof(char*) * (count + 1));
            list[count] = platform_strdup(dir->d_name);
            count++;
        }
    }
    closedir(d);
    *filenames = list;
    return count;
}

int vss_list_dir(const char *path, char ***filenames) {
    DIR *d = opendir(path);
    if (!d) {
        *filenames = NULL;
        return 0;
    }
    
    int count = 0;
    char **list = NULL;
    struct dirent *dir;
    while ((dir = readdir(d)) != NULL) {
        if (strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0) {
            continue;
        }
        list = realloc(list, sizeof(char*) * (count + 1));
        list[count] = platform_strdup(dir->d_name);
        count++;
    }
    closedir(d);
    *filenames = list;
    return count;
}

void vss_launch_browser(int port, const char *filename) {
    char launch_cmd[512];
#ifdef __APPLE__
    snprintf(launch_cmd, sizeof(launch_cmd), "open http://localhost:%d/%s 2>/dev/null &", port, filename);
#else
    snprintf(launch_cmd, sizeof(launch_cmd), "xdg-open http://localhost:%d/%s 2>/dev/null &", port, filename);
#endif
    system(launch_cmd);
}

int vss_execute_cmd(const char *cmd) {
    return system(cmd);
}

char *vss_get_home_dir(void) {
    const char *home = getenv("HOME");
    return home ? platform_strdup(home) : NULL;
}

bool vss_thread_create(VSS_Thread *thread, VSS_ThreadFunc func, void *arg) {
    return pthread_create(thread, NULL, func, arg) == 0;
}

bool vss_thread_join(VSS_Thread thread, void **retval) {
    return pthread_join(thread, retval) == 0;
}

void vss_mutex_init(VSS_Mutex *mutex) {
    pthread_mutex_init(mutex, NULL);
}

void vss_mutex_lock(VSS_Mutex *mutex) {
    pthread_mutex_lock(mutex);
}

void vss_mutex_unlock(VSS_Mutex *mutex) {
    pthread_mutex_unlock(mutex);
}

void vss_mutex_destroy(VSS_Mutex *mutex) {
    pthread_mutex_destroy(mutex);
}

void vss_cond_init(VSS_Cond *cond) {
    pthread_cond_init(cond, NULL);
}

void vss_cond_wait(VSS_Cond *cond, VSS_Mutex *mutex) {
    pthread_cond_wait(cond, mutex);
}

bool vss_cond_timedwait(VSS_Cond *cond, VSS_Mutex *mutex, int timeout_ms) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    ts.tv_sec += timeout_ms / 1000;
    ts.tv_nsec += (timeout_ms % 1000) * 1000000;
    if (ts.tv_nsec >= 1000000000) {
        ts.tv_sec += 1;
        ts.tv_nsec -= 1000000000;
    }
    return pthread_cond_timedwait(cond, mutex, &ts) == 0;
}

void vss_cond_signal(VSS_Cond *cond) {
    pthread_cond_signal(cond);
}

void vss_cond_broadcast(VSS_Cond *cond) {
    pthread_cond_broadcast(cond);
}

void vss_cond_destroy(VSS_Cond *cond) {
    pthread_cond_destroy(cond);
}

int vss_atomic_inc(VSS_AtomicInt *ptr) {
    return __atomic_add_fetch(ptr, 1, __ATOMIC_SEQ_CST);
}

int vss_atomic_dec(VSS_AtomicInt *ptr) {
    return __atomic_sub_fetch(ptr, 1, __ATOMIC_SEQ_CST);
}

int vss_atomic_add(VSS_AtomicInt *ptr, int val) {
    return __atomic_add_fetch(ptr, val, __ATOMIC_SEQ_CST);
}

int vss_atomic_get(VSS_AtomicInt *ptr) {
    return __atomic_load_n(ptr, __ATOMIC_SEQ_CST);
}

void vss_atomic_set(VSS_AtomicInt *ptr, int val) {
    __atomic_store_n(ptr, val, __ATOMIC_SEQ_CST);
}

bool vss_atomic_cas(VSS_AtomicInt *ptr, int old_val, int new_val) {
    return __atomic_compare_exchange_n(ptr, &old_val, new_val, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
}

void vss_sleep_ms(int ms) {
    usleep(ms * 1000);
}

int vss_get_hardware_concurrency(void) {
    long nprocs = sysconf(_SC_NPROCESSORS_ONLN);
    return nprocs > 0 ? (int)nprocs : 4;
}

void *vss_dl_open(const char *path) {
    if (!path) return NULL;
    return dlopen(path, RTLD_NOW | RTLD_GLOBAL);
}

void *vss_dl_sym(void *handle, const char *symbol) {
    if (!handle || !symbol) return NULL;
    return dlsym(handle, symbol);
}

void vss_dl_close(void *handle) {
    if (handle) dlclose(handle);
}

#endif
