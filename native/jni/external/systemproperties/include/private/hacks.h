#pragma once

#include <stdio.h>
#include <syscall.h>

// Missing defines
#ifndef PR_SET_VMA
#define PR_SET_VMA 0x53564d41
#endif
#ifndef PR_SET_VMA_ANON_NAME
#define PR_SET_VMA_ANON_NAME 0
#endif

// Missing functions
#define fsetxattr(...) syscall(__NR_fsetxattr, __VA_ARGS__)
#define getline compat_getline
ssize_t compat_getline(char **, size_t *, FILE *);

// Rename symbols
#pragma redefine_extname __system_property_set _system_property_set2
#pragma redefine_extname __system_property_find _system_property_find2
#pragma redefine_extname __system_property_read_callback _system_property_read_callback2
#pragma redefine_extname __system_property_foreach __system_property_foreach2
#pragma redefine_extname __system_property_wait __system_property_wait2
#pragma redefine_extname __system_property_read __system_property_read2
#pragma redefine_extname __system_property_get __system_property_get2
#pragma redefine_extname __system_property_find_nth __system_property_find_nth2
#pragma redefine_extname __system_property_set_filename __system_property_set_filename2
#pragma redefine_extname __system_property_area_init __system_property_area_init2
#pragma redefine_extname __system_property_area_serial __system_property_area_serial2
#pragma redefine_extname __system_property_add __system_property_add2
#pragma redefine_extname __system_property_update __system_property_update2
#pragma redefine_extname __system_property_serial __system_property_serial2
#pragma redefine_extname __system_properties_init __system_properties_init2
#pragma redefine_extname __system_property_wait_any __system_property_wait_any2
