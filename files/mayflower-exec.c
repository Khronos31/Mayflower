/*
 * Mayflower | generic PATH wrapper (Mach-O)
 *
 * Compile:
 *   cc -O2 -o out mayflower-exec.c -DTOOL='"/real/bin"' \
 *     [-DSETENV0_KEY='"K"' -DSETENV0_VAL='"V"' -DSETENV0_OVERRIDE=0] ... \
 *     [-DEXTRA_ARGV0='"arg"' -DEXTRA_ARGV1='"arg"']
 *
 * SETENV*_OVERRIDE: 0 = set only if unset; 1 = always set.
 * EXTRA_ARGV* are inserted after argv[0] before user args (npm-cli, -tools-directory, …).
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef TOOL
#	error TOOL required
#endif

static void
maybe_setenv(const char *key, const char *val, int override)
{
	if (!override && getenv(key) != NULL)
		return;
	setenv(key, val, 1);
}

int
main(int argc, char **argv)
{
	char **nargv;
	int extra = 0;
	int i, j;

#ifdef SETENV0_KEY
	maybe_setenv(SETENV0_KEY, SETENV0_VAL, SETENV0_OVERRIDE);
#endif
#ifdef SETENV1_KEY
	maybe_setenv(SETENV1_KEY, SETENV1_VAL, SETENV1_OVERRIDE);
#endif
#ifdef SETENV2_KEY
	maybe_setenv(SETENV2_KEY, SETENV2_VAL, SETENV2_OVERRIDE);
#endif
#ifdef SETENV3_KEY
	maybe_setenv(SETENV3_KEY, SETENV3_VAL, SETENV3_OVERRIDE);
#endif
#ifdef SETENV4_KEY
	maybe_setenv(SETENV4_KEY, SETENV4_VAL, SETENV4_OVERRIDE);
#endif
#ifdef SETENV5_KEY
	maybe_setenv(SETENV5_KEY, SETENV5_VAL, SETENV5_OVERRIDE);
#endif

#ifdef EXTRA_ARGV0
	extra++;
#endif
#ifdef EXTRA_ARGV1
	extra++;
#endif
#ifdef EXTRA_ARGV2
	extra++;
#endif

	if (extra == 0) {
		execv(TOOL, argv);
		fprintf(stderr, "mayflower-exec: exec \"%s\": %s\n", TOOL, strerror(errno));
		return 127;
	}

	nargv = calloc((size_t)argc + (size_t)extra + 1, sizeof(char *));
	if (nargv == NULL) {
		perror("mayflower-exec: calloc");
		return 127;
	}
	nargv[0] = argv[0];
	j = 1;
#ifdef EXTRA_ARGV0
	nargv[j++] = EXTRA_ARGV0;
#endif
#ifdef EXTRA_ARGV1
	nargv[j++] = EXTRA_ARGV1;
#endif
#ifdef EXTRA_ARGV2
	nargv[j++] = EXTRA_ARGV2;
#endif
	for (i = 1; i < argc; i++)
		nargv[j++] = argv[i];
	nargv[j] = NULL;

	execv(TOOL, nargv);
	fprintf(stderr, "mayflower-exec: exec \"%s\": %s\n", TOOL, strerror(errno));
	return 127;
}
