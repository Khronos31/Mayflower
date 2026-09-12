/*
 * Mayflower | compat/ios_compat.c
 *
 * system(3) and popen(3) for rootless jailbroken iOS. Linked in for packages
 * that set ios_compat=1. Kept free of libiosexec on purpose: libiosexec
 * resolves the interpreter named in a shebang and the shell that ie_system
 * uses, but it does not rewrite an absolute path handed to exec, so linking
 * it would not make the stock system(3) find a shell either.
 */
#include <errno.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
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

#define MAYFLOWER_POPEN_MAX 16
static struct {
  FILE *fp;
  pid_t pid;
} mayflower_popens[MAYFLOWER_POPEN_MAX];

FILE *mayflower_popen(const char *command, const char *mode) {
  if (command == NULL || mode == NULL || (mode[0] != 'r' && mode[0] != 'w')) {
    errno = EINVAL;
    return NULL;
  }

  int slot = -1;
  for (int i = 0; i < MAYFLOWER_POPEN_MAX; i++) {
    if (mayflower_popens[i].fp == NULL) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    errno = EMFILE;
    return NULL;
  }

  int fds[2];
  if (pipe(fds) != 0)
    return NULL;

  posix_spawn_file_actions_t fa;
  posix_spawn_file_actions_init(&fa);
  if (mode[0] == 'r') {
    posix_spawn_file_actions_adddup2(&fa, fds[1], STDOUT_FILENO);
  } else {
    posix_spawn_file_actions_adddup2(&fa, fds[0], STDIN_FILENO);
  }
  posix_spawn_file_actions_addclose(&fa, fds[0]);
  posix_spawn_file_actions_addclose(&fa, fds[1]);

  char *argv[] = {(char *)"sh", (char *)"-c", (char *)command, NULL};
  pid_t pid;
  int err = posix_spawn(&pid, MAYFLOWER_SH, &fa, NULL, argv, environ);
  posix_spawn_file_actions_destroy(&fa);
  if (err != 0) {
    close(fds[0]);
    close(fds[1]);
    errno = err;
    return NULL;
  }

  int parent_end = (mode[0] == 'r') ? fds[0] : fds[1];
  int child_end = (mode[0] == 'r') ? fds[1] : fds[0];
  close(child_end);

  char fdmode[3] = {mode[0], '\0', '\0'};
  FILE *fp = fdopen(parent_end, fdmode);
  if (fp == NULL) {
    close(parent_end);
    while (waitpid(pid, NULL, 0) == -1 && errno == EINTR) {
    }
    return NULL;
  }
  mayflower_popens[slot].fp = fp;
  mayflower_popens[slot].pid = pid;
  return fp;
}

int mayflower_pclose(FILE *fp) {
  pid_t pid = 0;
  for (int i = 0; i < MAYFLOWER_POPEN_MAX; i++) {
    if (mayflower_popens[i].fp == fp) {
      pid = mayflower_popens[i].pid;
      mayflower_popens[i].fp = NULL;
      break;
    }
  }
  if (fclose(fp) != 0)
    return -1;
  if (pid == 0)
    return -1;
  int status;
  while (waitpid(pid, &status, 0) == -1) {
    if (errno != EINTR)
      return -1;
  }
  return status;
}
