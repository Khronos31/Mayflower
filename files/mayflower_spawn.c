/*
 * Mayflower | process-local posix_spawn shebang fix
 *
 * Dopamine's systemhook replaces __posix_spawn and does not retry shebang
 * scripts (EPERM). libiosexec dyld interpose never sees those calls.
 *
 * This object fishhooks posix_spawn / posix_spawnp in the hosting binary so
 * that EPERM/ENOEXEC on a script is retried with the interpreter argv, same
 * idea as ie_posix_spawn. Link with -lmayflower_spawn (and preferably
 * -liosexec for other ie_* call sites).
 */
#include "fishhook.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <spawn.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int (*orig_posix_spawn)(pid_t *, const char *,
    const posix_spawn_file_actions_t *, const posix_spawnattr_t *,
    char *const[], char *const[]);
static int (*orig_posix_spawnp)(pid_t *, const char *,
    const posix_spawn_file_actions_t *, const posix_spawnattr_t *,
    char *const[], char *const[]);

static bool
looks_like_script(const char *path)
{
	int fd;
	char buf[2];
	ssize_t n;
	if (!path || !path[0])
		return false;
	fd = open(path, O_RDONLY);
	if (fd < 0)
		return false;
	n = read(fd, buf, 2);
	close(fd);
	return n == 2 && buf[0] == '#' && buf[1] == '!';
}

static char **
shebang_argv2(const char *path, char *const argv[], int *owned)
{
	char line[PATH_MAX];
	int fd;
	ssize_t n;
	char *nl, *interp, *arg1 = NULL;
	int argc = 0, i, j;
	char **out;

	*owned = 0;
	fd = open(path, O_RDONLY);
	if (fd < 0)
		return NULL;
	n = read(fd, line, sizeof(line) - 1);
	close(fd);
	if (n < 3 || line[0] != '#' || line[1] != '!')
		return NULL;
	line[n] = '\0';
	nl = strchr(line, '\n');
	if (nl)
		*nl = '\0';
	interp = line + 2;
	while (*interp == ' ' || *interp == '\t')
		interp++;
	if (!*interp)
		return NULL;
	{
		char *sp = interp;
		while (*sp && *sp != ' ' && *sp != '\t')
			sp++;
		if (*sp) {
			*sp++ = '\0';
			while (*sp == ' ' || *sp == '\t')
				sp++;
			if (*sp)
				arg1 = sp;
		}
	}
	for (argc = 0; argv && argv[argc]; argc++)
		;
	out = calloc((size_t)argc + 4, sizeof(char *));
	if (!out)
		return NULL;
	j = 0;
	out[j++] = strdup(interp);
	if (arg1)
		out[j++] = strdup(arg1);
	out[j++] = strdup(path);
	*owned = j;
	for (i = 1; i < argc; i++)
		out[j++] = argv[i];
	out[j] = NULL;
	return out;
}

static void
free_owned(char **a, int owned)
{
	int i;
	if (!a)
		return;
	for (i = 0; i < owned; i++)
		free(a[i]);
	free(a);
}

static int
spawn_with_shebang(int (*spawnfn)(pid_t *, const char *,
    const posix_spawn_file_actions_t *, const posix_spawnattr_t *,
    char *const[], char *const[]),
    pid_t *pid, const char *path,
    const posix_spawn_file_actions_t *fa, const posix_spawnattr_t *attr,
    char *const argv[], char *const envp[])
{
	int err, owned = 0;
	char **nargv;

	err = spawnfn(pid, path, fa, attr, argv, envp);
	if (err != EPERM && err != ENOEXEC)
		return err;
	if (!looks_like_script(path))
		return err;

	nargv = shebang_argv2(path, argv, &owned);
	if (!nargv)
		return errno ? errno : err;
	err = spawnfn(pid, nargv[0], fa, attr, nargv, envp);
	free_owned(nargv, owned);
	return err;
}

static int
hooked_posix_spawn(pid_t *pid, const char *path,
    const posix_spawn_file_actions_t *fa, const posix_spawnattr_t *attr,
    char *const argv[], char *const envp[])
{
	return spawn_with_shebang(orig_posix_spawn, pid, path, fa, attr, argv, envp);
}

static int
hooked_posix_spawnp(pid_t *pid, const char *file,
    const posix_spawn_file_actions_t *fa, const posix_spawnattr_t *attr,
    char *const argv[], char *const envp[])
{
	/* PATH search still uses original; shebang retry only for absolute hits via spawn */
	return spawn_with_shebang(orig_posix_spawnp, pid, file, fa, attr, argv, envp);
}

__attribute__((constructor))
static void
mayflower_spawn_init(void)
{
	struct rebinding rebs[] = {
		{"posix_spawn", (void *)hooked_posix_spawn, (void **)&orig_posix_spawn},
		{"posix_spawnp", (void *)hooked_posix_spawnp, (void **)&orig_posix_spawnp},
	};
	rebind_symbols(rebs, 2);
}
