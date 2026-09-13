// iOS 16's libc++.1.dylib does not export std::__1::__libcpp_verbose_abort.
// Clang 19 libc++ headers emit calls to it when compiling with -fno-exceptions.
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

namespace std {
inline namespace __1 {
__attribute__((noreturn)) void __libcpp_verbose_abort(char const* format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  abort();
}
}  // namespace __1
}  // namespace std
