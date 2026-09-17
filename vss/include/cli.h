#ifndef VSS_CLI_H
#define VSS_CLI_H

#include "object.h"

int vss_run_cli(int argc, char **argv);

// Serialization helpers
bool vss_serialize_function(VSS_ObjFunction *func, FILE *out);
VSS_ObjFunction *vss_deserialize_function(FILE *in);

#endif
