// Mayflower | macOS 向け Claude Code を脱獄 iOS で動かすための shim
//
// macOS の libSystem が公開していて iOS の libSystem が公開していない記号を補い、
// 残りは libSystem を再エクスポートして解決する。バイナリの未定義記号 840 個を
// 端末の実行時に dlsym で照合した結果、足りないのは下の4つだけだった。
#include <libkern/OSCacheControl.h>
#include <spawn.h>
#include <stddef.h>

// JIT がコードを書いた後の命令キャッシュ無効化。compiler-rt の組み込み関数で、
// macOS の libSystem は公開しているが iOS は公開していない（dlsym が 0 を返す。
// SDK の tbd に見える _clear_cache は _ne_tracker_clear_cache 等の誤検出）。
void __clear_cache(void *start, void *end) {
  size_t len = (char *)end - (char *)start;
  sys_dcache_flush(start, len);
  sys_icache_invalidate(start, len);
}

// macOS 13 で標準名になった関数。iOS には _np 付きだけがある。
//
// **ヘッダ経由では呼べない。** iOS SDK の spawn.h:179 は _np 付きにも
// API_UNAVAILABLE(ios) を付けている。記号は端末の libSystem に実在する
// （dlsym で確認済み）ので、asm ラベルで直接束ねて可用性属性を迂回する。
extern int mf_addfchdir_np(posix_spawn_file_actions_t *, int)
    __asm__("_posix_spawn_file_actions_addfchdir_np");

int posix_spawn_file_actions_addfchdir(posix_spawn_file_actions_t *acts, int fd) {
  return mf_addfchdir_np(acts, fd);
}

// Apple Silicon の macOS は MAP_JIT 領域の W^X を切り替えるためにこれを使う。
// 脱獄 iOS では dynamic-codesigning の entitlement で RWX が許されるため
// 切り替えは要らない。supported が 0 を返せば呼ぶ側は protect を呼ばない。
int pthread_jit_write_protect_supported_np(void) { return 0; }
void pthread_jit_write_protect_np(int enabled) { (void)enabled; }
