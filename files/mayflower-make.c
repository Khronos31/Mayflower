/*
 * Mayflower | bin/make (Mach-O)
 * GNU make ignores SHELL from the environment; force SHELL= for recipes.
 * -DREAL_MAKE='"/var/jb/usr/bin/make"'
 * -DDEFAULT_SHELL='"/var/jb/bin/sh"'
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef REAL_MAKE
#	define REAL_MAKE "/var/jb/usr/bin/make"
#endif
#ifndef DEFAULT_SHELL
#	define DEFAULT_SHELL "/var/jb/bin/sh"
#endif

int
main(int argc, char **argv)
{
	const char *jb;
	const char *shell;
	char shell_arg[512];
	char **nargv;
	int i;

	jb = getenv("JB");
	if (jb != NULL && jb[0] != '\0') {
		snprintf(shell_arg, sizeof(shell_arg), "SHELL=%s/bin/sh", jb);
		shell = shell_arg;
	} else {
		snprintf(shell_arg, sizeof(shell_arg), "SHELL=%s", DEFAULT_SHELL);
		shell = shell_arg;
	}

	nargv = calloc((size_t)argc + 2, sizeof(char *));
	if (nargv == NULL) {
		perror("mayflower-make: calloc");
		return 127;
	}
	nargv[0] = argv[0];
	nargv[1] = (char *)shell;
	for (i = 1; i < argc; i++)
		nargv[i + 1] = argv[i];
	nargv[argc + 1] = NULL;

	execv(REAL_MAKE, nargv);
	fprintf(stderr, "mayflower-make: exec \"%s\": %s\n", REAL_MAKE, strerror(errno));
	return 127;
}
