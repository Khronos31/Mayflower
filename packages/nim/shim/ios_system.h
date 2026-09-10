/* Force-included (-include) when building the csources bootstrap on rootless
 * jailbroken iOS. system(3) is marked unavailable in the iOS SDK and would
 * exec /bin/sh, which does not exist on rootless jailbreaks. */
#ifndef NIM_IOS_SYSTEM_H
#define NIM_IOS_SYSTEM_H
#include <stdlib.h>
int nim_ios_system(const char *command);
#define system nim_ios_system
#endif
