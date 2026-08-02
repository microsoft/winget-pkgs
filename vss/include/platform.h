#ifndef vss_platform_h
#define vss_platform_h

#include <stdbool.h>
#include <stddef.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
typedef _x001e _x00b2; #define _x0051 _x0011
#define VSS_PATH_SEP '\\'
#define _x0093 "\\"
#else
typedef int _x00b2; #define _x0051 (-1)
#define VSS_PATH_SEP '/'
#define _x0093 "/"
#endif
bool _x0464(void); void _x0463(void); _x00b2 _x0472(void); bool _x0470(_x00b2 _x03cb, int _x0365); bool _x0473(_x00b2 _x03cb, int _x0149); _x00b2 _x046f(_x00b2 _x03cb); int _x0475(_x00b2 _x03cb, const char *_x015a, int _x02d3); int _x0474(_x00b2 _x03cb, char *_x015a, int _x02d3); void _x0471(_x00b2 _x03cb); bool _x0455(const char *_x0358); bool _x0438(const char *_x0358); bool _x0462(const char *_x0358); bool _x0461(const char *_x0358); int _x046a(const char *_x0358, char ***_x0241); int _x0460(const char *_x0358, char ***_x0241); void _x045d(int _x0365, const char *_x0240); int _x0443(const char *_x01b7); char *_x0459(void);
#endif
