import shlex
import subprocess
import threading
import time

from PySide6.QtCore import QObject, Signal, Slot, Property

from . import x11


class AppLauncher(QObject):
    launched = Signal(str)
    sessionDetected = Signal(str, str, str, int, object)
    settingsRequested = Signal()
    loadingChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._loading_id = ""

    def _get_loading_id(self):
        return self._loading_id

    def _set_loading_id(self, val):
        if self._loading_id != val:
            self._loading_id = val
            self.loadingChanged.emit()

    loadingId = Property(str, _get_loading_id, _set_loading_id, notify=loadingChanged)

    @Slot(str, str, str, str, str)
    def launch(
        self,
        exec_cmd: str,
        desktop_id: str = "",
        wm_class: str = "",
        app_name: str = "",
        icon_source: str = "",
    ):
        if exec_cmd == "__settings__":
            self.settingsRequested.emit()
            return

        self._set_loading_id(desktop_id)

        # Reuse an existing matching window, but do not claim it as a
        # LauncherTV-launched session unless it was tracked earlier.
        if wm_class:
            existing = x11.find_window_by_class(wm_class)
            if existing:
                x11.remove_decorations(existing)
                x11.restore_window(existing)
                self._set_loading_id("")
                return

        try:
            parts = shlex.split(exec_cmd)
        except ValueError:
            parts = exec_cmd.split()

        if not parts:
            self._set_loading_id("")
            return

        windows_before = x11.get_all_window_ids()

        try:
            proc = subprocess.Popen(
                parts,
                start_new_session=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.launched.emit(desktop_id)

            threading.Thread(
                target=self._track_launched_windows,
                args=(
                    proc.pid, windows_before, desktop_id,
                    app_name or desktop_id or "Application",
                    icon_source, wm_class,
                ),
                daemon=True,
            ).start()
        except FileNotFoundError:
            self._set_loading_id("")

    def _track_launched_windows(
        self, pid, windows_before, desktop_id, app_name, icon_source, wm_class
    ):
        """Track only PID descendants or new windows matching the app class."""
        tracked = set()
        first_found_at = None

        for attempt in range(60):
            current = x11.get_all_window_ids()
            pids = x11.process_tree_pids(pid)
            candidates = set(x11.find_windows_for_pids(pids))

            if wm_class:
                new_windows = current - windows_before
                candidates.update(
                    wid for wid in new_windows
                    if x11.window_matches_class(wid, wm_class)
                )

            for wid in candidates - tracked:
                if "LauncherTV" in x11.window_name(wid):
                    continue
                x11.remove_decorations(wid)
                x11.set_fullscreen(wid)
                tracked.add(wid)

            if tracked and first_found_at is None:
                first_found_at = attempt

            # Continue briefly after the first match to catch sibling windows.
            if first_found_at is not None and attempt - first_found_at >= 12:
                break
            time.sleep(0.2)

        if tracked:
            self.sessionDetected.emit(
                desktop_id, app_name, icon_source, pid, sorted(tracked)
            )
