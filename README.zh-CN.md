<div align="center">
  <h1>vv-splits.nvim</h1>

  <p><a href="./README.md">English</a> | <a href="./README.zh-CN.md">中文</a></p>

  <p>想要我的 Neovim 配置？查看 <a href="https://github.com/beixiyo/dotfiles">dotfiles</a></p>

  <p><em>基于原生分隔线 API 的 Neovim / tmux / Kitty / WezTerm 无缝窗口导航与缩放</em></p>

  <p>
    <img src="https://img.shields.io/badge/Neovim-0.12+-57A143?style=flat-square&amp;logo=neovim&amp;logoColor=white" alt="需要 Neovim 0.12+" />
    <img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&amp;logo=lua&amp;logoColor=white" alt="Lua" />
    <img src="https://img.shields.io/badge/Lua_deps-0-2ea44f?style=flat-square" alt="零 Lua 依赖" />
  </p>
</div>

---

## 设计目标

vv-splits 只提供两个动作：在 Neovim split 与外层 multiplexer 之间移动焦点，以及按分隔线方向调整大小

- 使用 Neovim 0.12 的 `win_move_separator()` / `win_move_statusline()`，不执行跳窗补偿 resize
- resize 的方向语义与 tmux `resize-pane -L/-R/-U/-D` 一致：移动当前窗口右侧或下方的边界，只有该方向的最后一个窗口才移动左侧或上方边界，因此 Left/Right、Up/Down 互为逆操作
- 可把真实 split 声明为导航透明窗口，查找过程中不会短暂触发 `WinEnter` / `WinLeave`
- resize 由调用方注入布局事务，插件不硬编码附属面板或其它 vv 插件
- tmux 命令始终使用 `$TMUX_PANE` 精确定位，不写 `@pane-is-vim`
- 内置 tmux、Kitty、WezTerm adapter，也可注入自定义 adapter
- 不注册全局 keymap；键位属于调用方配置

不提供 swap、resize mode、自动创建 split、wrap、Zellij 或旧版 Neovim 兼容层

## 安装

```lua
{
  'beixiyo/vv-splits.nvim',
  event = 'VimEnter',
  opts = {
    amount = 3,
    mux = 'auto',
  },
}
```

Kitty native 模式的前置条件：

- `kitty.conf` 启用 `allow_remote_control yes` 并设置 `listen_on`，Nvim 通过 `$KITTY_LISTEN_ON` 与 `$KITTY_WINDOW_ID` 定位自己的窗口
- `kitten` 可执行文件在 Nvim 的 `PATH` 中；插件以 `kitten @ kitten --match id:<window> <随仓库分发的 kitten>` 在 kitty 进程内执行，无需把 Python 文件复制进 Kitty 配置目录
- Kitty 侧用 `map --when-focus-on var:IS_NVIM <key>` 在 Nvim 聚焦时放行按键；插件在 `attach` / `VimResume` 时设置 `IS_NVIM`，在 `VimSuspend` / `detach` / 退出时清除。shell `precmd` 里再补一次清除即可覆盖 Nvim 被 kill 的情况

## 配置

```lua
require('vv-splits').setup({
  amount = 3,
  mux = 'auto',
  float_behavior = 'previous',

  skip_window = function(win)
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.api.nvim_get_option_value('filetype', { buf = buf }) == 'vv-scrollbar'
  end,

  with_resize = function(action)
    local ok, scrollbar = pcall(require, 'vv-scrollbar')
    if not ok then return action() end
    return scrollbar.with_layout_suspended(action)
  end,
})
```

| 选项 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `amount` | `integer` | `3` | 每次移动的列数或行数 |
| `mux` | `'auto' \| 'tmux' \| 'kitty' \| 'wezterm' \| false \| adapter` | `'auto'` | multiplexer 选择；auto 优先级为 tmux → Kitty → WezTerm |
| `float_behavior` | `'previous' \| 'stop'` | `'previous'` | 浮窗内触发时以 previous split 为起点，或直接停止；解析本身不切换焦点，move 成功才把焦点交给目标，resize 全程保留浮窗焦点 |
| `skip_window` | `fun(win): boolean` | 始终 false | 仅用于导航；返回 true 的真实 split 被视为透明 |
| `with_resize` | `fun(action): boolean` | 直接执行 | resize 外围布局事务，资源恢复由调用方负责 |

Neovide 会自动禁用 mux。显式传入 `mux = false` 也只操作 Neovim split

## API

```lua
local splits = require('vv-splits')

splits.move({ direction = 'left' })
splits.resize({ direction = 'right' })
splits.resize({ direction = 'up', amount = 5 })

local config = splits.get_config()
```

`direction` 只能是 `left`、`right`、`up`、`down`。动作返回 boolean：`move()` 表示焦点已切换或 mux 已接管；`resize()` 表示窗口几何确实发生了变化或 mux 已接管。存在本地边界但因 `winminwidth` / `winminheight` 或屏幕边缘无法移动时返回 `false`，不会转交 mux

## Resize 语义

以三列 `A | B | C` 为例：

| 焦点 | Left | Right |
|---|---|---|
| A | A 的右边界左移，A 变窄 | A 的右边界右移，A 变宽 |
| B | B 的右边界左移，B 变窄 | B 的右边界右移，B 变宽 |
| C（最后一列） | B\|C 边界左移，C 变宽 | B\|C 边界右移，C 变窄 |

两列布局下，无论焦点在哪一侧，Left/Right 操作的都是同一条共享分隔线。tmux 回退遵循同一规则；WezTerm 与 Kitty 只能按各自的 split 树选择最近的同轴边界，方向一致但中间窗口具体移动哪条分隔线由终端决定

## 自定义 mux adapter

```lua
require('vv-splits').setup({
  mux = {
    attach = function() end,
    detach = function() end,
    move = function(direction) return false end,
    resize = function(direction, amount) return false end,
  },
})
```

`attach()` / `detach()` 可选且必须幂等；`move()` / `resize()` 返回是否接管动作

## 模块结构

```text
lua/vv-splits/
├── init.lua                 公共 facade
├── config.lua               配置与公共类型
├── direction.lua            方向映射
├── window/                  origin 与邻居解析
├── navigation/              逻辑焦点移动
├── resize/                  边界选择与原生 resize
└── mux/
    ├── init.lua             adapter 解析与生命周期
    ├── process.lua          无 shell 的进程执行
    ├── tmux/
    ├── kitty/
    └── wezterm/
```

每个职责目录只通过自己的 `init.lua` 暴露给上层

## 开发测试

```sh
./tests/run.sh
./tests/run.sh '中间列'
NVIM_BIN=/path/to/nvim ./tests/run.sh
```

仅支持 Unix-like 系统；要求 Neovim 0.12+（建议使用 0.12 稳定版）、Git 和 POSIX shell
直接运行 `./tests/run.sh`，首次自动准备固定版本 vv-utils（`ed9b6ae`）与 mini.test 源码，
不要求兄弟仓库、个人 Neovim 配置或预装 parser。依赖保存在 `VV_TEST_DEPS_CACHE`，
默认 `$XDG_CACHE_HOME/nvim-test-deps` 或 `~/.cache/nvim-test-deps`；缓存齐全后可离线运行
`VV_UTILS` 可显式覆盖共享源码路径；`NVIM_BIN` 默认 `nvim`。过滤词按文件路径或中文用例名
做字面子串匹配，无匹配视为失败。入口不安装系统工具

真实跨 pane 集成额外要求 tmux。使用 fixture 内专属 socket、`/dev/null` 配置与显式 sleep 进程，不连接用户 server 或启动交互 shell。Kitty / WezTerm 适配器注入命令执行器，不要求安装 GUI 客户端。缺少 tmux 会明确失败，不 skip

每个 case 使用全新 child Neovim，cwd、HOME、XDG 与临时文件隔离在独立 `/tmp` 目录；失败路径同样清理。headless 覆盖 API 与状态，不替代视觉验证；CI 需外层 job timeout 中断阻塞 RPC
