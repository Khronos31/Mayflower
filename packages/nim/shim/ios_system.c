/* system(3) replacement for rootless jailbroken iOS: runs the command with
 * the shell under /var/jb instead of /bin/sh. */
#include <errno.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef NIM_IOS_SH
#define NIM_IOS_SH "/var/jb/bin/sh"
#endif

extern char **environ;

int nim_ios_system(const char *command) {
  if (command == NULL)
    return access(NIM_IOS_SH, X_OK) == 0;

  char *argv[] = {"sh", "-c", (char *)command, NULL};
  pid_t pid;
  int err = posix_spawn(&pid, NIM_IOS_SH, NULL, NULL, argv, environ);
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
