#ifndef VSS_VERSION_H
#define VSS_VERSION_H

// These are injected at compile time by the build system via -D flags.
// Example: gcc ... -DVSS_VERSION_STRING="1.0.0" -DVSS_BUILD_TYPE="Release"
// Falls back to development defaults if not provided.

#ifndef VSS_VERSION_STRING
#define VSS_VERSION_STRING "3.1.0"
#endif

#ifndef VSS_BUILD_TYPE
#define VSS_BUILD_TYPE "Debug"
#endif

// Platform detection
#if defined(_WIN32) || defined(_WIN64)
  #if defined(_M_ARM64) || defined(__aarch64__)
    #define VSS_PLATFORM_NAME "Windows ARM64"
  #else
    #define VSS_PLATFORM_NAME "Windows x64"
  #endif
#elif defined(__APPLE__)
  #if defined(__arm64__) || defined(__aarch64__)
    #define VSS_PLATFORM_NAME "macOS ARM64 (Apple Silicon)"
  #else
    #define VSS_PLATFORM_NAME "macOS x64 (Intel)"
  #endif
#elif defined(__linux__)
  #if defined(__aarch64__)
    #define VSS_PLATFORM_NAME "Linux ARM64"
  #else
    #define VSS_PLATFORM_NAME "Linux x64"
  #endif
#else
  #define VSS_PLATFORM_NAME "Unknown Platform"
#endif

#endif
