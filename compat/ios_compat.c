/*
 * Mayflower | compat/ios_compat.c
 *
 * system(3) for rootless jailbroken iOS. Linked in for packages that set
 * ios_compat=1. Kept free of libiosexec on purpose: libiosexec resolves the
 * interpreter named in a shebang and the shell that ie_system uses, but it
 * does not rewrite an absolute path handed to exec, so linking it would not
 * make the stock system(3) find a shell either.
 */
#include <errno.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef MAYFLOWER_SH
#define MAYFLOWER_SH "/var/jb/bin/sh"
#endif

extern char **environ;

int mayflower_system(const char *command) {
  /* system(NULL) asks whether a shell is available. */
  if (command == NULL)
    return access(MAYFLOWER_SH, X_OK) == 0;

  char *argv[] = {(char *)"sh", (char *)"-c", (char *)command, NULL};
  pid_t pid;
  int err = posix_spawn(&pid, MAYFLOWER_SH, NULL, NULL, argv, environ);
  if (err != 0) {
    errno = err;
    return -1;
  }

  int status;
  while (waitpid(pid, &status, 0) == -1) {
    if (errno != EINTR)
      return -1;
  }
  return status;
}
