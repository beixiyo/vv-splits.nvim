#!/bin/sh
# Unix-like 测试入口：固定依赖源码、隔离用户 Git/终端环境，再交给共享 mini.test runner
set -eu

tests_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$tests_dir/.." && pwd)
export NVIM_BIN="${NVIM_BIN:-nvim}"
export VV_TEST_DEPS_CACHE="${VV_TEST_DEPS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/nvim-test-deps}"

command -v "$NVIM_BIN" >/dev/null 2>&1 || { printf 'Tests require Neovim 0.12+.\n' >&2; exit 1; }
command -v git >/dev/null 2>&1 || { printf 'Tests require Git.\n' >&2; exit 1; }

# 不读取用户的签名、hooks、Git 目录及正在运行的复用器会话
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_CONFIG GIT_CONFIG_COUNT GIT_TEMPLATE_DIR
unset GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
unset TMUX TMUX_PANE STY KITTY_LISTEN_ON KITTY_WINDOW_ID WEZTERM_PANE NVIM NVIM_LISTEN_ADDRESS

# 显式源码路径优先；否则检出固定 commit 到缓存，不使用本机依赖的未提交代码
dependency() (
  name=$1
  revision=$2
  override=${3:-}
  if [ -n "$override" ]; then
    CDPATH= cd -- "$override" && pwd
    exit
  fi

  parent="$VV_TEST_DEPS_CACHE/sources/$name"
  target="$parent/$revision"
  if [ -d "$target/.git" ] && [ "$(git -C "$target" rev-parse HEAD)" = "$revision" ]; then
    printf '%s\n' "$target"
    exit
  fi

  mkdir -p "$parent"
  lock="$target.lock"
  if ! mkdir "$lock" 2>/dev/null; then
    printf 'Dependency preparation already in progress: %s\n' "$name" >&2
    exit 1
  fi
  staging=''
  trap 'if [ -n "$staging" ]; then rm -rf "$staging"; fi; rmdir "$lock"' 0
  trap 'exit 1' HUP INT TERM
  staging=$(mktemp -d "$parent/.download.XXXXXX")

  source="https://github.com/beixiyo/$name.git"
  candidate="$(dirname -- "$repo")/$name"
  # 本地已有固定 Git 对象时可离线复用；工作区及暂存改动不会进入依赖缓存
  if [ -d "$candidate" ] && git -C "$candidate" cat-file -e "$revision^{commit}" 2>/dev/null; then
    source=$candidate
  fi

  printf 'Preparing %s at %s\n' "$name" "$revision" >&2
  git -C "$staging" init --quiet
  git -C "$staging" fetch --quiet --depth=1 "$source" "$revision"
  git -C "$staging" -c core.hooksPath=/dev/null checkout --quiet --detach FETCH_HEAD
  test "$(git -C "$staging" rev-parse HEAD)" = "$revision"
  if [ -e "$target" ]; then
    printf 'Invalid dependency cache; remove it and retry: %s\n' "$target" >&2
    exit 1
  fi
  mv "$staging" "$target"
  CDPATH= cd -- "$target" && pwd
)

VV_UTILS=$(dependency vv-utils.nvim ed9b6ae29cdba6ff53e281d7bb32537edb68b9fd "${VV_UTILS:-}")
export VV_UTILS
command -v tmux >/dev/null 2>&1 || { printf 'Splits integration tests require tmux.\n' >&2; exit 1; }
exec sh "$VV_UTILS/dev/test/run.sh" "$repo" "$@"
