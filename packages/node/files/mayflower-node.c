/*
 * Mayflower | node-N PATH wrapper (Mach-O)
 * -DNODE_BIN='"/var/jb/usr/lib/nodejs-24/node-bin"'
 * -DDEFAULT_NPM_PREFIX='"/var/jb/usr"'
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef NODE_BIN
#	error NODE_BIN required
#endif
#ifndef DEFAULT_NPM_PREFIX
#	define DEFAULT_NPM_PREFIX "/var/jb/usr"
#endif

int
main(int argc, char **argv)
{
	char **nargv;
	int i, allow_jit = 0;
	const char *v;

	if (getenv("NPM_CONFIG_PREFIX") == NULL)
		setenv("NPM_CONFIG_PREFIX", DEFAULT_NPM_PREFIX, 1);

	v = getenv("NODE_IOS_ALLOW_JIT");
	if (v != NULL && strcmp(v, "1") == 0)
		allow_jit = 1;

	if (allow_jit) {
		execv(NODE_BIN, argv);
	} else {
		nargv = calloc((size_t)argc + 2, sizeof(char *));
		if (nargv == NULL) {
			perror("mayflower-node: calloc");
			return 127;
		}
		nargv[0] = argv[0];
		nargv[1] = "--jitless";
		for (i = 1; i < argc; i++)
			nargv[i + 1] = argv[i];
		nargv[argc + 1] = NULL;
		execv(NODE_BIN, nargv);
	}
	fprintf(stderr, "mayflower-node: exec \"%s\": %s\n", NODE_BIN, strerror(errno));
	return 127;
}
