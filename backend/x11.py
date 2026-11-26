"""
X11 window management helpers.

Uses xprop/xwininfo for window properties and libX11 for EWMH client
messages. Window discovery is deliberately PID/class scoped: LauncherTV
must never claim unrelated windows just because they appeared recently.
"""

import ctypes
import ctypes.util
import os
import re
import subprocess


class _XClientMessageEvent(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_int),
        ("serial", ctypes.c_ulong),
        ("send_event", ctypes.c_int),
        ("display", ctypes.c_void_p),
        ("window", ctypes.c_ulong),
        ("message_type", ctypes.c_ulong),
        ("format", ctypes.c_int),
        ("data_l", ctypes.c_long * 5),
        ("_pad", ctypes.c_byte * 64),
    ]


_lib = None


def _xlib():
    global _lib
    if _lib is not None:
        return _lib
    path = ctypes.util.find_library("X11")
    if not path:
        return None
    _lib = ctypes.CDLL(path)
    _lib.XOpenDisplay.restype = ctypes.c_void_p
    _lib.XOpenDisplay.argtypes = [ctypes.c_char_p]
    _lib.XCloseDisplay.argtypes = [ctypes.c_void_p]
    _lib.XDefaultRootWindow.restype = ctypes.c_ulong
    _lib.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    _lib.XInternAtom.restype = ctypes.c_ulong
    _lib.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    _lib.XSendEvent.argtypes = [
        ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
        ctypes.c_long, ctypes.c_void_p,
    ]
    _lib.XFlush.argtypes = [ctypes.c_void_p]
    return _lib


def _send_ewmh(window_id, message_name, data):
    """Send an EWMH client message to the root window."""
    lib = _xlib()
    if not lib:
        return
    dpy = lib.XOpenDisplay(None)
    if not dpy:
        return
    try:
        root = lib.XDefaultRootWindow(dpy)
        atom = lib.XInternAtom(dpy, message_name, 0)
        evt = _XClientMessageEvent()
        evt.type = 33
        evt.send_event = 1
        evt.display = dpy
        evt.window = window_id
        evt.message_type = atom
        evt.format = 32
        for i, value in enumerate(data[:5]):
            evt.data_l[i] = value
        mask = (1 << 20) | (1 << 19)
        lib.XSendEvent(dpy, root, 0, mask, ctypes.byref(evt))
        lib.XFlush(dpy)
    finally:
        lib.XCloseDisplay(dpy)


def _intern(name):
    lib = _xlib()
    if not lib:
        return 0
    dpy = lib.XOpenDisplay(None)
    if not dpy:
        return 0
    try:
        return lib.XInternAtom(dpy, name, 0)
    finally:
        lib.XCloseDisplay(dpy)


def _run(cmd, timeout=3):
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        ).stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""


def get_all_window_ids():
    """Return all managed X11 window IDs as hexadecimal strings."""
    out = _run(["xprop", "-root", "_NET_CLIENT_LIST"])
    match = re.search(r"#\s*(.+)", out)
    if not match:
        return set()
    return {
        item.strip().rstrip(",")
        for item in match.group(1).split(",")
        if item.strip()
    }


def window_pid(wid):
    out = _run(["xprop", "-id", str(wid), "_NET_WM_PID"])
    match = re.search(r"=\s*(\d+)", out)
    return int(match.group(1)) if match else None


def window_class(wid):
    out = _run(["xprop", "-id", str(wid), "WM_CLASS"])
    return [value.lower() for value in re.findall(r'"([^"]+)"', out)]


def window_matches_class(wid, wm_class):
    target = (wm_class or "").strip().lower()
    return bool(target) and target in window_class(wid)


def find_windows_for_pids(pids):
    pid_set = {int(pid) for pid in pids if pid}
    if not pid_set:
        return []
    return [
        wid for wid in get_all_window_ids()
        if window_pid(wid) in pid_set
    ]


def find_windows_by_pid(pid):
    return find_windows_for_pids({pid})


def process_tree_pids(root_pid):
    """Return root PID and current descendants using /proc parent IDs."""
    root_pid = int(root_pid)
    parents = {}
    try:
        entries = os.listdir("/proc")
    except OSError:
        return {root_pid}

    for entry in entries:
        if not entry.isdigit():
            continue
        try:
            raw = open(f"/proc/{entry}/stat", encoding="utf-8").read()
            tail = raw[raw.rfind(")") + 1:].split()
            if len(tail) > 1:
                parents[int(entry)] = int(tail[1])
        except (OSError, ValueError, IndexError):
            continue

    result = {root_pid}
    changed = True
    while changed:
        changed = False
        for pid, ppid in parents.items():
            if ppid in result and pid not in result:
                result.add(pid)
                changed = True
    return result


def find_window_by_name(name):
    for wid in get_all_window_ids():
        out = _run(["xprop", "-id", wid, "_NET_WM_NAME", "WM_NAME"])
        if name in out:
            return wid
    return None


def window_name(wid):
    out = _run(["xprop", "-id", str(wid), "_NET_WM_NAME", "WM_NAME"])
    match = re.search(r'"(.+?)"', out)
    return match.group(1) if match else ""


def find_window_by_class(wm_class):
    """Find the first window whose WM_CLASS matches (case-insensitive)."""
    if not wm_class:
        return None
    for wid in get_all_window_ids():
        if window_matches_class(wid, wm_class):
            return wid
    return None


def is_window_minimized(wid):
    """Use EWMH hidden state, with X window map state as a fallback."""
    state = _run(["xprop", "-id", str(wid), "_NET_WM_STATE"])
    if "_NET_WM_STATE_HIDDEN" in state:
        return True
    info = _run(["xwininfo", "-id", str(wid)])
    return "Map State: IsUnMapped" in info


def remove_decorations(wid):
    _run([
        "xprop", "-id", str(wid),
        "-f", "_MOTIF_WM_HINTS", "32c",
        "-set", "_MOTIF_WM_HINTS", "0x2, 0x0, 0x0, 0x0, 0x0",
    ])


def set_fullscreen(wid):
    wid_int = int(wid, 16) if isinstance(wid, str) else int(wid)
    fs_atom = _intern(b"_NET_WM_STATE_FULLSCREEN")
    _send_ewmh(wid_int, b"_NET_WM_STATE", [1, fs_atom, 0, 1, 0])


def activate_window(wid):
    wid_int = int(wid, 16) if isinstance(wid, str) else int(wid)
    _send_ewmh(wid_int, b"_NET_ACTIVE_WINDOW", [2, 0, 0, 0, 0])


def restore_window(wid):
    """Unhide and activate a minimized application window without resizing it."""
    wid_int = int(wid, 16) if isinstance(wid, str) else int(wid)
    hidden_atom = _intern(b"_NET_WM_STATE_HIDDEN")
    _send_ewmh(wid_int, b"_NET_WM_STATE", [0, hidden_atom, 0, 1, 0])
    activate_window(wid_int)


def activate_by_name(name):
    wid = find_window_by_name(name)
    if wid:
        activate_window(wid)
        return True
    return False
