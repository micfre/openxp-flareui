"""Skin-seam harness: run OXP-FUI's Lua under lupa against a stubbed WoW API
and a fake OpenXP (Seam 1 of the spec's testing decisions).

Everything the tests observe goes through this Env: firing events, running
slash commands, flipping combat, reading frame state back as Python values.
"""

from __future__ import annotations

import pathlib

import lupa

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
ADDON_DIR = REPO_ROOT / "src" / "OXP-FUI"
LUA_DIR = pathlib.Path(__file__).resolve().parent / "lua"

# TOC order; kept in sync with src/OXP-FUI/OXP-FUI.toc (build test enforces).
ADDON_FILES = ["Core.lua", "Locale.lua", "Theme.lua", "Engine.lua", "SettingsPanel.lua"]


def _lua_literal(value) -> str:
    """Render a Python value (dict/list/str/num/bool/None) as Lua source."""
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(value, dict):
        pairs = ", ".join(f"[{_lua_literal(k)}] = {_lua_literal(v)}" for k, v in value.items())
        return "{" + pairs + "}"
    if isinstance(value, (list, tuple)):
        return "{" + ", ".join(_lua_literal(v) for v in value) + "}"
    raise TypeError(f"cannot render {value!r} as Lua")


class Env:
    """One lupa LuaRuntime = one simulated client with one addon session."""

    def __init__(self, *, openxp: bool = True, openxp_version: str = "1.3.48",
                 db: dict | None = None, load_addon: bool = True):
        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        self._eval_file(str(LUA_DIR / "wow_api.lua"))
        if openxp:
            self.run(f"HARNESS.openxpVersion = {_lua_literal(openxp_version)}")
            self._eval_file(str(LUA_DIR / "fake_openxp.lua"))
        if db is not None:
            self.run(f"OXPFUIDB = {_lua_literal(db)}")
        if load_addon:
            self.load_addon()

    # -- loading -----------------------------------------------------------

    def _eval_file(self, path_str: str, *args) -> None:
        """Load a Lua file as a chunk called with WoW-style varargs.

        Files are read in Python and load()ed from the string so the harness
        needs no Lua filesystem access; the path is only the chunk name used
        in error messages.
        """
        src = pathlib.Path(path_str).read_text()
        args_lua = ", ".join(_lua_literal(a) for a in args)
        self.lua.execute(
            f"local chunk = assert(load([==[{src}]==], {path_str!r})); chunk({args_lua})"
        )

    def load_addon(self) -> None:
        """Load the addon's Lua files in TOC order with WoW varargs.

        WoW hands every file of an addon the same two varargs: the addon name
        and one private namespace table shared by all its files. The namespace
        table is created here and passed by value to every chunk.
        """
        self.run("_G.__OXPFUI_NAMESPACE = {}")
        for fname in ADDON_FILES:
            path = ADDON_DIR / fname
            if not path.exists():
                raise FileNotFoundError(path)
            self._eval_file_ns(str(path))
        self.run("_G.OXPFUI_NAMESPACE = __OXPFUI_NAMESPACE")

    def _eval_file_ns(self, path_str: str) -> None:
        """Load one addon file, receiving ('OXP-FUI', <namespace table>)."""
        src = pathlib.Path(path_str).read_text()
        self.lua.execute(
            f"local chunk = assert(load([==[{src}]==], {path_str!r})); "
            'chunk("OXP-FUI", __OXPFUI_NAMESPACE)'
        )

    # -- driving the simulated client --------------------------------------

    def boot(self) -> None:
        """Simulate the load sequence: ADDON_LOADED (OpenXP, then ours) + login."""
        self.fire("ADDON_LOADED", "OpenXP")
        self.fire("ADDON_LOADED", "OXP-FUI")
        self.fire("PLAYER_LOGIN")

    def fire(self, event: str, *args) -> None:
        args_lua = ", ".join(_lua_literal(a) for a in (event, *args))
        self.run(f"HARNESS.FireEvent({args_lua})")

    def set_combat(self, flag: bool) -> None:
        self.run(f"HARNESS.inCombat = {'true' if flag else 'false'}")

    def slash(self, cmd: str) -> None:
        self.run(f"HARNESS.RunSlash({_lua_literal(cmd)})")

    def run(self, lua_src: str):
        """Evaluate Lua in the simulated client's global environment."""
        return self.lua.execute(lua_src)

    def install_skins(self, lua_src: str) -> None:
        """Register test skin modules through the public extension API."""
        self.run(lua_src)

    # -- observation --------------------------------------------------------

    def chat(self) -> list[str]:
        return list(self.run("local t = {}; for i = 1, #HARNESS.chat do t[i] = HARNESS.chat[i] end; return t"))

    def calls_made_on(self, frame_name: str, method: str | None = None) -> int:
        """Count recorded mutating calls on a frame (optionally one method)."""
        if method is None:
            return self.run(f"return _G[{frame_name!r}] and #_G[{frame_name!r}].__calls or 0")
        return self.run(
            f"local n = 0; local f = _G[{frame_name!r}]; "
            f"if f then for _, c in ipairs(f.__calls) do if c[1] == {method!r} then n = n + 1 end end end; "
            "return n"
        )

    def openxp_calls(self, fn: str) -> int:
        return self.run(f"return (HARNESS.calls and HARNESS.calls[{fn!r}]) or 0")
