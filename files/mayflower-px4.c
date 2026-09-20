/*
 * Mayflower | PATH wrappers for px4d / px4-ts / px4ctl
 *
 * iOS has no XDG_RUNTIME_DIR. If --runtime-dir is omitted (and this is not
 * --help), mkdir 0700 ${JB}/var/run/px4-userland and pass it. validate_directory
 * rejects anything else (INVALID_ARGUMENT on the control endpoint).
 *
 * For px4d only, if --firmware is omitted and
 * ${JB}/usr/share/px4-userland/it930x-firmware.bin is readable, pass that.
 * The blob is still not shipped in the package.
 *
 * -DTOOL '"px4d"' / '"px4-ts"' / '"px4ctl"'
 * -DPX4_INJECT_FIRMWARE 1  for px4d
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#ifndef JB
#	define JB "/var/jb"
#endif
#ifndef TOOL
#	define TOOL "px4d"
#endif

static const char *const kBin = JB "/usr/lib/px4-userland/" TOOL;
static const char *const kFirmware =
    JB "/usr/share/px4-userland/it930x-firmware.bin";

static int
has_opt(int argc, char **argv, const char *opt)
{
	int i;

	for (i = 1; i < argc; i++) {
		if (argv[i] != NULL && strcmp(argv[i], opt) == 0)
			return 1;
	}
	return 0;
}

static int
ensure_rtdir(const char *path)
{
	struct stat st;

	if (stat(path, &st) == 0) {
		if (!S_ISDIR(st.st_mode)) {
			errno = ENOTDIR;
			return -1;
		}
		if (st.st_uid == geteuid() && (st.st_mode & 0777) != 0700)
			(void)chmod(path, 0700);
		return 0;
	}
	if (mkdir(path, 0700) != 0 && errno != EEXIST)
		return -1;
	if (stat(path, &st) == 0 && st.st_uid == geteuid())
		(void)chmod(path, 0700);
	return 0;
}

int
main(int argc, char **argv)
{
	char rtdir[256];
	const char *home;
	char *nargv[96];
	int n = 0;
	int i;
	int help = has_opt(argc, argv, "--help");
	int add_rt = !help && !has_opt(argc, argv, "--runtime-dir");
	int add_fw = 0;

	home = getenv("HOME");
	if (home == NULL || home[0] == '\0')
		home = JB "/var/mobile";
	snprintf(rtdir, sizeof(rtdir), "%s/.px4-userland", home);

#ifdef PX4_INJECT_FIRMWARE
	add_fw = !help && !has_opt(argc, argv, "--firmware") &&
	    access(kFirmware, R_OK) == 0;
#endif

	nargv[n++] = (char *)kBin;
	if (add_rt) {
		if (ensure_rtdir(rtdir) != 0) {
			fprintf(stderr, "px4 wrapper: runtime-dir %s: %s\n",
			    rtdir, strerror(errno));
			return 2;
		}
		nargv[n++] = "--runtime-dir";
		nargv[n++] = rtdir;
	}
	if (add_fw) {
		nargv[n++] = "--firmware";
		nargv[n++] = (char *)kFirmware;
	}
	for (i = 1; i < argc && n < 94; i++)
		nargv[n++] = argv[i];
	nargv[n] = NULL;

	execv(kBin, nargv);
	fprintf(stderr, "px4 wrapper: exec %s: %s\n", kBin, strerror(errno));
	return 127;
}
