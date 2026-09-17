#ifndef VSS_JSON_H
#define VSS_JSON_H

#include "value.h"

VSS_Value vss_json_parse(const char *json_str, bool *out_error, char **out_error_msg);
char *vss_json_serialize(VSS_Value val);

#endif
