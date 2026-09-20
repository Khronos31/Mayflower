/*
 * Mayflower | px4-pcsc-register (Mach-O)
 * Write pcsc-lite reader.conf for the Q3U4 internal reader.
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef JB
#	define JB "/var/jb"
#endif

static int
replace_all(char *buf, size_t bufsz, const char *from, const char *to)
{
	char tmp[8192];
	char *p = buf;
	size_t fl = strlen(from);
	tmp[0] = '\0';
	while (*p) {
		char *hit = strstr(p, from);
		if (!hit) {
			if (strlen(tmp) + strlen(p) + 1 > sizeof(tmp))
				return -1;
			strcat(tmp, p);
			break;
		}
		if (strlen(tmp) + (size_t)(hit - p) + strlen(to) + 1 > sizeof(tmp))
			return -1;
		strncat(tmp, p, (size_t)(hit - p));
		strcat(tmp, to);
		p = hit + fl;
	}
	if (strlen(tmp) + 1 > bufsz)
		return -1;
	memcpy(buf, tmp, strlen(tmp) + 1);
	return 0;
}

static int
run_cmd(char *const argv[])
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
	const char *base, *rt;
	char tmpl[256], ifd[256], conf[256], dir[256];
	char body[8192];
	FILE *fp;
	size_t n;

	if (argc != 3) {
		fprintf(stderr, "usage: px4-pcsc-register BASE_SERIAL RUNTIME_DIR\n");
		return 2;
	}
	base = argv[1];
	rt = argv[2];
	snprintf(tmpl, sizeof(tmpl), "%s/usr/share/px4-userland/px4-userland.conf.in", JB);
	snprintf(ifd, sizeof(ifd), "%s/usr/lib/px4-userland/libpx4-userland-ifd.dylib", JB);
	snprintf(conf, sizeof(conf), "%s/etc/reader.conf.d/px4-userland.conf", JB);

	if (access(tmpl, R_OK) != 0 || access(ifd, R_OK) != 0) {
		fprintf(stderr, "px4-pcsc-register: missing template or IFD dylib\n");
		return 1;
	}
	fp = fopen(tmpl, "r");
	if (!fp) {
		perror("px4-pcsc-register: fopen template");
		return 1;
	}
	n = fread(body, 1, sizeof(body) - 1, fp);
	fclose(fp);
	body[n] = '\0';

	if (replace_all(body, sizeof(body), "@PX4_RUNTIME_DIR@", rt) != 0 ||
	    replace_all(body, sizeof(body), "@PX4_BASE_SERIAL@", base) != 0 ||
	    replace_all(body, sizeof(body), "@PX4_ACCESS@", "user") != 0 ||
	    replace_all(body, sizeof(body), "@PX4_IFD_LIBRARY@", ifd) != 0) {
		fprintf(stderr, "px4-pcsc-register: expand failed\n");
		return 1;
	}

	snprintf(dir, sizeof(dir), "%s/etc/reader.conf.d", JB);
	mkdir(dir, 0755);

	fp = fopen(conf, "w");
	if (!fp) {
		perror("px4-pcsc-register: fopen conf");
		return 1;
	}
	fputs(body, fp);
	fclose(fp);
	printf("wrote %s\n", conf);

	{
		char *a1[] = {"launchctl", "kickstart", "-k", "user/foreground/fr.apdu.pcscd", NULL};
		char *a2[] = {"launchctl", "kickstart", "-k", "system/fr.apdu.pcscd", NULL};
		char *a3[] = {"killall", "-HUP", "pcscd", NULL};
		if (run_cmd(a1) == 0)
			return 0;
		if (run_cmd(a2) == 0)
			return 0;
		(void)run_cmd(a3);
	}
	return 0;
}
