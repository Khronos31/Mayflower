/*
 * Mayflower | bin/cc and bin/c++ (Mach-O)
 * Run COMPILER, then ldid -S$ENTFILE on the output if it is executable.
 * -DCOMPILER='"clang"' or '"clang++"'
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef COMPILER
#	define COMPILER "clang"
#endif

static const char *
parse_output(int argc, char **argv)
{
	int i;
	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-o") == 0) {
			if (i + 1 < argc)
				return argv[i + 1];
		} else if (strncmp(argv[i], "-o", 2) == 0 && argv[i][2] != '\0') {
			return argv[i] + 2;
		} else if (strcmp(argv[i], "--output") == 0) {
			if (i + 1 < argc)
				return argv[i + 1];
		} else if (strncmp(argv[i], "--output=", 9) == 0) {
			return argv[i] + 9;
		}
	}
	return "a.out";
}

int
main(int argc, char **argv)
{
	pid_t pid;
	int status;
	const char *output;
	const char *ent;
	struct stat st;
	char **cargv;
	int i;

	cargv = calloc((size_t)argc + 2, sizeof(char *));
	if (cargv == NULL) {
		perror("mayflower-cc: calloc");
		return 127;
	}
	cargv[0] = (char *)COMPILER;
	cargv[1] = "-B/var/jb/usr/bin";
	for (i = 1; i < argc; i++)
		cargv[i + 1] = argv[i];
	cargv[argc + 1] = NULL;

	{
		const char *old = getenv("PATH");
		char npath[4096];

		snprintf(npath, sizeof(npath), "/var/jb/usr/bin:/var/jb/bin:%s",
		    old != NULL ? old : "");
		setenv("PATH", npath, 1);
	}

	pid = fork();
	if (pid < 0) {
		perror("mayflower-cc: fork");
		return 127;
	}
	if (pid == 0) {
		execv("/var/jb/usr/bin/" COMPILER, cargv);
		execvp(COMPILER, cargv);
		fprintf(stderr, "mayflower-cc: exec \"%s\": %s\n", COMPILER, strerror(errno));
		_exit(127);
	}
	if (waitpid(pid, &status, 0) < 0) {
		perror("mayflower-cc: waitpid");
		return 127;
	}
	if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
		return WIFEXITED(status) ? WEXITSTATUS(status) : 1;

	output = parse_output(argc, argv);
	if (stat(output, &st) != 0)
		return 0;
	if ((st.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH)) == 0)
		return 0;

	ent = getenv("ENTFILE");
	if (ent == NULL || ent[0] == '\0')
		return 0;

	pid = fork();
	if (pid < 0) {
		perror("mayflower-cc: fork");
		return 127;
	}
	if (pid == 0) {
		char flag[4096];
		snprintf(flag, sizeof(flag), "-S%s", ent);
		execl("/var/jb/usr/bin/ldid", "ldid", flag, output, (char *)NULL);
		execlp("ldid", "ldid", flag, output, (char *)NULL);
		fprintf(stderr, "mayflower-cc: exec ldid: %s\n", strerror(errno));
		_exit(127);
	}
	if (waitpid(pid, &status, 0) < 0) {
		perror("mayflower-cc: waitpid");
		return 127;
	}
	if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
		return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
	return 0;
}
