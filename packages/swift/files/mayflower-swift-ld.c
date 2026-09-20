/*
 * Mayflower | mayflower-swift-ld (Mach-O)
 * Run real ld, then ldid on -o output unless SWIFT_NO_LDID is set.
 */
#include <errno.h>
#include <libgen.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

static int
is_executable(const char *path)
{
	struct stat st;
	if (stat(path, &st) != 0)
		return 0;
	return (st.st_mode & S_IXUSR) != 0;
}

static void
get_selfdir(char *selfdir, size_t n)
{
	char self[PATH_MAX];
	char tmp[PATH_MAX];
	uint32_t size = sizeof(self);
	selfdir[0] = '\0';
	if (_NSGetExecutablePath(self, &size) != 0)
		return;
	snprintf(tmp, sizeof(tmp), "%s", self);
	snprintf(selfdir, n, "%s", dirname(tmp));
}

static int
find_real_ld(char *out, size_t outsz)
{
	const char *env;
	const char *cands[] = { "/var/jb/usr/bin/ld", "/usr/bin/ld", NULL };
	char selfdir[PATH_MAX];
	char *pathenv, *save, *dir, cand[PATH_MAX];
	int i;

	env = getenv("MAYFLOWER_REAL_LD");
	if (env && env[0] && is_executable(env)) {
		snprintf(out, outsz, "%s", env);
		return 0;
	}
	get_selfdir(selfdir, sizeof(selfdir));
	for (i = 0; cands[i]; i++) {
		if (!is_executable(cands[i]))
			continue;
		if (strstr(cands[i], "mayflower-swift"))
			continue;
		if (selfdir[0] && strncmp(cands[i], selfdir, strlen(selfdir)) == 0 &&
		    cands[i][strlen(selfdir)] == '/')
			continue;
		snprintf(out, outsz, "%s", cands[i]);
		return 0;
	}
	pathenv = getenv("PATH");
	if (!pathenv)
		return -1;
	pathenv = strdup(pathenv);
	if (!pathenv)
		return -1;
	for (dir = strtok_r(pathenv, ":", &save); dir; dir = strtok_r(NULL, ":", &save)) {
		if (!dir[0])
			continue;
		if (selfdir[0] && strcmp(dir, selfdir) == 0)
			continue;
		if (strstr(dir, "mayflower-swift-tools"))
			continue;
		snprintf(cand, sizeof(cand), "%s/ld", dir);
		if (!is_executable(cand))
			continue;
		snprintf(out, outsz, "%s", cand);
		free(pathenv);
		return 0;
	}
	free(pathenv);
	return -1;
}

static const char *
parse_output(int argc, char **argv)
{
	int i;
	for (i = 1; i < argc; i++)
		if (strcmp(argv[i], "-o") == 0 && i + 1 < argc)
			return argv[i + 1];
	return NULL;
}

static int
run_argv(char *const argv[])
{
	pid_t pid;
	int status;
	pid = fork();
	if (pid < 0)
		return -1;
	if (pid == 0) {
		execvp(argv[0], argv);
		_exit(127);
	}
	if (waitpid(pid, &status, 0) < 0)
		return -1;
	return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}

int
main(int argc, char **argv)
{
	char real_ld[PATH_MAX];
	char **cargv;
	int i, rc;
	const char *outpath;
	const char *ent;
	struct stat st;
	char selfdir[PATH_MAX];
	char cand_ent[PATH_MAX];
	static const char *fallback_fixed[] = {
		"/var/jb/usr/lib/llvm-19/libexec/entitlements.plist",
		"/var/jb/usr/lib/llvm-19/entitlements.plist",
		"/var/jb/usr/share/ldid/entitlements.plist",
		NULL
	};

	if (find_real_ld(real_ld, sizeof(real_ld)) != 0) {
		fprintf(stderr, "mayflower-swift-ld: real ld not found\n");
		return 127;
	}
	cargv = calloc((size_t)argc + 1, sizeof(char *));
	if (!cargv)
		return 127;
	cargv[0] = real_ld;
	for (i = 1; i < argc; i++)
		cargv[i] = argv[i];
	cargv[argc] = NULL;
	rc = run_argv(cargv);
	if (rc != 0)
		return rc;
	if (getenv("SWIFT_NO_LDID"))
		return 0;
	outpath = parse_output(argc, argv);
	if (!outpath || stat(outpath, &st) != 0)
		return 0;
	/* shell checked -f only */
	ent = getenv("SWIFT_LDID_ENTITLEMENTS");
	if (!ent)
		ent = getenv("CLANG_LDID_ENTITLEMENTS");
	if (!ent) {
		get_selfdir(selfdir, sizeof(selfdir));
		if (selfdir[0]) {
			snprintf(cand_ent, sizeof(cand_ent), "%s/../entitlements.plist", selfdir);
			if (access(cand_ent, R_OK) == 0)
				ent = cand_ent;
			else {
				snprintf(cand_ent, sizeof(cand_ent), "%s/../../entitlements.plist", selfdir);
				if (access(cand_ent, R_OK) == 0)
					ent = cand_ent;
			}
		}
	}
	if (!ent) {
		for (i = 0; fallback_fixed[i]; i++)
			if (access(fallback_fixed[i], R_OK) == 0) {
				ent = fallback_fixed[i];
				break;
			}
	}
	{
		char flag[4096];
		char *ldid_argv[4];
		ldid_argv[0] = "ldid";
		if (ent) {
			snprintf(flag, sizeof(flag), "-S%s", ent);
			ldid_argv[1] = flag;
		} else {
			ldid_argv[1] = "-S";
		}
		ldid_argv[2] = (char *)outpath;
		ldid_argv[3] = NULL;
		return run_argv(ldid_argv);
	}
}
