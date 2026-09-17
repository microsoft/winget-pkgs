#ifndef vss_platform_h
#define vss_platform_h

#include <stdbool.h>
#include <stddef.h>
#include "common.h"

#ifdef _WIN32
  #include <winsock2.h>
  #include <ws2tcpip.h>
  #include <windows.h>
  typedef SOCKET VSS_Socket;
  #define VSS_INVALID_SOCKET INVALID_SOCKET
  #define VSS_PATH_SEP '\\'
  #define VSS_PATH_SEP_STR "\\"
  typedef HANDLE VSS_Thread;
  typedef CRITICAL_SECTION VSS_Mutex;
  typedef CONDITION_VARIABLE VSS_Cond;
  typedef LONG VSS_AtomicInt;
#else
  #include <pthread.h>
  #include <unistd.h>
  typedef int VSS_Socket;
  #define VSS_INVALID_SOCKET (-1)
  #define VSS_PATH_SEP '/'
  #define VSS_PATH_SEP_STR "/"
  typedef pthread_t VSS_Thread;
  typedef pthread_mutex_t VSS_Mutex;
  typedef pthread_cond_t VSS_Cond;
  typedef int VSS_AtomicInt;
#endif

// Network Sockets API
bool vss_network_init(void);
void vss_network_cleanup(void);

VSS_Socket vss_socket_create(void);
bool vss_socket_bind(VSS_Socket sock, int port);
bool vss_socket_listen(VSS_Socket sock, int backlog);
VSS_Socket vss_socket_accept(VSS_Socket sock);
int vss_socket_send(VSS_Socket sock, const char *buf, int len);
int vss_socket_recv(VSS_Socket sock, char *buf, int len);
void vss_socket_close(VSS_Socket sock);

// Filesystem API
bool vss_file_exists(const char *path);
bool vss_dir_exists(const char *path);
bool vss_make_dir(const char *path);
bool vss_list_dir_clean_vssc(const char *path);
int vss_scan_htmvss(const char *path, char ***filenames);
int vss_list_dir(const char *path, char ***filenames);

// Process and Environment API
void vss_launch_browser(int port, const char *filename);
int vss_execute_cmd(const char *cmd);
char *vss_get_home_dir(void);

// Concurrency & Synchronization API
typedef void *(*VSS_ThreadFunc)(void *arg);
bool vss_thread_create(VSS_Thread *thread, VSS_ThreadFunc func, void *arg);
bool vss_thread_join(VSS_Thread thread, void **retval);

void vss_mutex_init(VSS_Mutex *mutex);
void vss_mutex_lock(VSS_Mutex *mutex);
void vss_mutex_unlock(VSS_Mutex *mutex);
void vss_mutex_destroy(VSS_Mutex *mutex);

void vss_cond_init(VSS_Cond *cond);
void vss_cond_wait(VSS_Cond *cond, VSS_Mutex *mutex);
bool vss_cond_timedwait(VSS_Cond *cond, VSS_Mutex *mutex, int timeout_ms);
void vss_cond_signal(VSS_Cond *cond);
void vss_cond_broadcast(VSS_Cond *cond);
void vss_cond_destroy(VSS_Cond *cond);

int vss_atomic_inc(VSS_AtomicInt *ptr);
int vss_atomic_dec(VSS_AtomicInt *ptr);
int vss_atomic_add(VSS_AtomicInt *ptr, int val);
int vss_atomic_get(VSS_AtomicInt *ptr);
void vss_atomic_set(VSS_AtomicInt *ptr, int val);
bool vss_atomic_cas(VSS_AtomicInt *ptr, int old_val, int new_val);

void vss_sleep_ms(int ms);
int vss_get_hardware_concurrency(void);

// Dynamic Library FFI API
void *vss_dl_open(const char *path);
void *vss_dl_sym(void *handle, const char *symbol);
void vss_dl_close(void *handle);

#endif
