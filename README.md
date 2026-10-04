<div align="center">
  <h1>vv-splits.nvim</h1>

  <p><a href="./README.md">English</a> | <a href="./README.zh-CN.md">中文</a></p>

  <p>Want my Neovim config? See <a href="https://github.com/beixiyo/dotfiles">dotfiles</a></p>

  <p><em>Native Neovim separator movement with seamless tmux, Kitty, and WezTerm navigation</em></p>

  <p>
    <img src="https://img.shields.io/badge/Neovim-0.12+-57A143?style=flat-square&amp;logo=neovim&amp;logoColor=white" alt="Requires Neovim 0.12+" />
    <img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&amp;logo=lua&amp;logoColor=white" alt="Lua" />
    <img src="https://img.shields.io/badge/Lua_deps-0-2ea44f?style=flat-square" alt="Zero Lua dependencies" />
  </p>
</div>

---

vv-splits exposes two operations: move focus across logical Neovim splits and multiplexer panes, and move a separator in a requested direction

- Uses Neovim 0.12 `win_move_separator()` and `win_move_statusline()` instead of compensating resize commands
- Resize follows the tmux `resize-pane` rule: the window's right/bottom boundary moves, and only the last window in that axis moves its left/top boundary, so Left/Right and Up/Down are inverses
- Skips transparent real splits without transient focus changes
- Accepts a caller-owned resize transaction instead of depending on panel plugins
- Targets tmux through `$TMUX_PANE` and never writes `@pane-is-vim`
- Includes tmux, Kitty, and WezTerm adapters
- Registers no global keymaps

It intentionally omits swap, resize mode, split creation, wrapping, Zellij, and legacy Neovim support

## Setup

```lua
require('vv-splits').setup({
  amount = 3,
  mux = 'auto',
  float_behavior = 'previous',
  skip_window = function(win) return false end,
  with_resize = function(action) return action() end,
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `amount` | `integer` | `3` | Resize step in columns or rows |
| `mux` | `'auto' \| 'tmux' \| 'kitty' \| 'wezterm' \| false \| adapter` | `'auto'` | Multiplexer selection; auto prefers tmux, then Kitty, then WezTerm |
| `float_behavior` | `'previous' \| 'stop'` | `'previous'` | Continue from the previous split or stop in floats; focus only changes when a move succeeds |
| `skip_window` | `fun(win): boolean` | always false | Navigation-only transparent-window predicate |
| `with_resize` | `fun(action): boolean` | direct call | Caller-owned layout transaction |

## API

```lua
local splits = require('vv-splits')

splits.move({ direction = 'left' })
splits.resize({ direction = 'right' })
splits.resize({ direction = 'up', amount = 5 })
splits.get_config()
```

Actions return whether Neovim or the configured multiplexer handled the request. `resize()` returns `false` when a local boundary exists but cannot move; it never falls through to the multiplexer in that case

Kitty native mode needs `allow_remote_control`, `kitten` on `PATH`, and `map --when-focus-on var:IS_NVIM <key>` unbinds in `kitty.conf`; the plugin runs its bundled kitten through `kitten @ kitten --match id:<window>` and toggles `IS_NVIM` on attach, suspend, resume, and exit

## Development tests

```sh
./tests/run.sh
./tests/run.sh '中间列'
NVIM_BIN=/path/to/nvim ./tests/run.sh
```

Unix-like systems only; requires Neovim 0.12+ (0.12 stable recommended), Git and POSIX shell.
`./tests/run.sh` prepares pinned vv-utils (`ed9b6ae`) and mini.test sources on first use;
no sibling checkout, personal Neovim configuration or parser installation is required.
Dependencies are cached under `VV_TEST_DEPS_CACHE` (default: `$XDG_CACHE_HOME/nvim-test-deps`
or `~/.cache/nvim-test-deps`); later runs work offline with a populated cache.
`VV_UTILS` optionally overrides the shared source checkout; `NVIM_BIN` defaults to `nvim`.
The optional filter matches a literal substring of the file path or Chinese case name;
no matches fails. The entrypoint does not install system tools.

Real cross-pane integration additionally requires tmux. It starts a dedicated socket in the fixture with `/dev/null` configuration and explicit sleep processes, never the user’s server or interactive shell. Kitty and WezTerm adapters use injected command runners, not installed GUI clients. Missing tmux is an explicit failure, not a skip.

Each case uses a fresh child Neovim and isolated `/tmp` cwd, HOME and XDG directories. Cleanup runs on failure too. Headless tests cover API and state, not visual behavior; CI needs an outer job timeout for blocked RPC.
