#ifndef VSS_COMMON_H
#define VSS_COMMON_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifndef VSS_THREAD_LOCAL
#if defined(_MSC_VER)
#define VSS_THREAD_LOCAL __declspec(thread)
#elif defined(__GNUC__) || defined(__clang__)
#define VSS_THREAD_LOCAL __thread
#else
#define VSS_THREAD_LOCAL _Thread_local
#endif
#endif

extern VSS_THREAD_LOCAL const char *vss_current_source;

#endif

