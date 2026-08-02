#ifndef VSS_VERSION_H
#define VSS_VERSION_H

#ifndef VSS_VERSION_STRING
#define _x0123 "dev"
#endif

#ifndef VSS_BUILD_TYPE
#define _x0030 "Debug"
#endif
#if defined(_WIN32) || defined(_WIN64)
#if defined(_M_ARM64) || defined(__aarch64__)
#define _x0094 "Windows ARM64"
#else
#define _x0094 "Windows x64"
#endif
#elif defined(__APPLE__)
#if defined(__arm64__) || defined(__aarch64__)
#define _x0094 "macOS ARM64 (Apple Silicon)"
#else
#define _x0094 "macOS x64 (Intel)"
#endif
#elif defined(__linux__)
#if defined(__aarch64__)
#define _x0094 "Linux ARM64"
#else
#define _x0094 "Linux x64"
#endif
#else
#define _x0094 "Unknown Platform"
#endif

#endif
