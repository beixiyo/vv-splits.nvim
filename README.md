<div align="center">
  <h1>vv-splits.nvim</h1>

  <p><a href="./README.md">English</a> | <a href="./README.zh-CN.md">中文</a></p>

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

## Test

```bash
bash tests/run.sh
```

The suite uses real Neovim splits and an isolated tmux socket; it never connects to the user's tmux server

See [README.zh-CN.md](./README.zh-CN.md) for the complete design and adapter contract
