/*
 * Mayflower | epgstation PATH wrapper (Mach-O)
 *
 * argv[0] は常にこのラッパのパス。EPGStation は子を
 * spawn(process.argv[0], [ServiceExecutor.js]) で起こす。
 * index.js を EXTRA_ARGV で焼き付けると、子も operator になり IPC が切れる。
 *
 * 引数が無ければ dist/index.js。あればそれを node に渡す。
 * --jitless は node-24 ラッパを経由せず node-bin へ直接付ける。
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef NODE_BIN
#	error NODE_BIN required
#endif
#ifndef INDEX_JS
#	error INDEX_JS required
#endif
#ifndef ROOT
#	error ROOT required
#endif

int
main(int argc, char **argv)
{
	char **nargv;
	int i;

	if (chdir(ROOT) != 0) {
		fprintf(stderr, "epgstation: chdir \"%s\": %s\n", ROOT, strerror(errno));
		return 127;
	}

	if (argc <= 1) {
		char *def[] = { argv[0], "--jitless", INDEX_JS, NULL };
		execv(NODE_BIN, def);
		fprintf(stderr, "epgstation: exec \"%s\": %s\n", NODE_BIN, strerror(errno));
		return 127;
	}

	nargv = calloc((size_t)argc + 2, sizeof(char *));
	if (nargv == NULL) {
		perror("epgstation: calloc");
		return 127;
	}
	nargv[0] = argv[0];
	nargv[1] = "--jitless";
	for (i = 1; i < argc; i++)
		nargv[i + 1] = argv[i];
	nargv[argc + 1] = NULL;
	execv(NODE_BIN, nargv);
	fprintf(stderr, "epgstation: exec \"%s\": %s\n", NODE_BIN, strerror(errno));
	return 127;
}
