/*
 * Mayflower | compat/ios_compat.h
 *
 * Force-included (-include) for packages that set ios_compat=1.
 *
 * system(3) is the one process-spawning function that Apple still marks
 * __IOS_PROHIBITED in the iOS SDK:
 *
 *   __swift_unavailable("Use posix_spawn APIs or NSTask instead. ...")
 *   __API_AVAILABLE(macos(10.0)) __IOS_PROHIBITED
 *   int system(const char *) __DARWIN_ALIAS_C(system);
 *
 * Removing the attribute is not enough on a rootless jailbreak: the real
 * system(3) execs /bin/sh, and rootless has no /bin/sh. So the call is
 * redirected to an implementation that uses the shell under the jailbreak
 * prefix instead.
 *
 * The real headers are pulled in first on purpose. Defining the macro before
 * <stdlib.h> is read would rename the declaration itself, which then carries
 * the unavailable attribute over to the replacement. That is the trap that
 * catches anyone force-including <libiosexec.h> directly.
 */
#ifndef MAYFLOWER_IOS_COMPAT_H
#define MAYFLOWER_IOS_COMPAT_H

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

int mayflower_system(const char *command);

#ifdef __cplusplus
}
#endif

#undef system
#define system mayflower_system

#endif /* MAYFLOWER_IOS_COMPAT_H */
