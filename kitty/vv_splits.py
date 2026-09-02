"""vv-splits 的 Kitty 窗格导航和分隔符方向缩放

由 kitty 本身通过 ``kitten @ kitten <this file> ...`` 运行，
这样 ``handle_result`` 在 kitty 进程内执行，可以访问 ``boss``
"""

from kittens.tui.handler import result_handler


def main(args):
    pass


def resolve_tab(window, boss):
    """仅当 ``window`` 是该 tab 的活跃窗口时，返回拥有它的 tab

    ``Tab.neighboring_window`` 和 ``Tab.resize_window`` 作用于 tab 的活跃窗口，
    否则会移动或缩放到别的 pane
    """
    tab = window.tabref()
    if tab is None or tab.active_window is not window:
        return None
    return tab


def move(window, direction, boss):
    tab = resolve_tab(window, boss)
    if tab is None:
        return
    kitty_direction = {"up": "top", "down": "bottom"}.get(direction, direction)
    neighbors = tab.current_layout.neighbors_for_window(window, tab.windows)
    if not neighbors.get(kitty_direction):
        return
    tab.neighboring_window(kitty_direction)


def resize(window, direction, amount, boss):
    """按 vv-splits 边界规则缩放

    移动窗口右/下侧的边界；只有当窗口是该轴上的最后一个时才改为移动左/上边界。
    Kitty 只暴露活跃窗口在其 split pair 内的放大/缩小，
    所以中间窗口具体移动哪条分隔线由 pair 树决定
    """
    tab = resolve_tab(window, boss)
    if tab is None:
        return

    neighbors = tab.current_layout.neighbors_for_window(window, tab.windows)
    if direction in ("left", "right"):
        has_next = bool(neighbors.get("right"))
        has_prev = bool(neighbors.get("left"))
        grow, shrink = "wider", "narrower"
        forward = direction == "right"
    else:
        has_next = bool(neighbors.get("bottom"))
        has_prev = bool(neighbors.get("top"))
        grow, shrink = "taller", "shorter"
        forward = direction == "down"

    if not has_next and not has_prev:
        return
    if has_next:
        # 拥有右/下边界：前进增长，后退收缩
        tab.resize_window(grow if forward else shrink, amount)
    else:
        # 最后一个窗口：共享的左/上边界移动，所以角色互换
        tab.resize_window(shrink if forward else grow, amount)


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    action = args[1]
    direction = args[2]
    amount = int(args[3]) if action == "resize" else None
    requested_id = int(args[4] if action == "resize" else args[3])
    window = boss.window_id_map.get(requested_id)
    if window is None or requested_id != target_window_id:
        return

    if action == "move":
        move(window, direction, boss)
    elif action == "resize":
        resize(window, direction, amount, boss)
