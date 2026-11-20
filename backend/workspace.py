from PySide6.QtCore import (
    Qt, QAbstractListModel, QModelIndex, QByteArray, Signal,
    Slot, Property, QTimer,
)

from . import x11


class WorkspaceModel(QAbstractListModel):
    """Tracks only application windows discovered from LauncherTV launches."""

    NameRole = Qt.UserRole + 1
    IconSourceRole = Qt.UserRole + 2
    DesktopIdRole = Qt.UserRole + 3

    _role_names = {
        NameRole: QByteArray(b"name"),
        IconSourceRole: QByteArray(b"iconSource"),
        DesktopIdRole: QByteArray(b"desktopId"),
    }

    countChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._sessions = []
        self._visible = []
        self._count = 0

        self._timer = QTimer(self)
        self._timer.setInterval(1200)
        self._timer.timeout.connect(self.refresh)
        self._timer.start()

    def roleNames(self):
        return self._role_names

    def rowCount(self, parent=QModelIndex()):
        return len(self._visible)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self._visible):
            return None
        session = self._visible[index.row()]
        if role == self.NameRole:
            return session["name"]
        if role == self.IconSourceRole:
            return session["icon_source"]
        if role == self.DesktopIdRole:
            return session["desktop_id"]
        return None

    def _get_count(self):
        return self._count

    count = Property(int, _get_count, notify=countChanged)

    @Slot(str, str, str, int, object)
    def registerSession(self, desktop_id, name, icon_source, pid, window_ids):
        ids = {str(wid) for wid in (window_ids or [])}
        if not ids:
            return

        existing = next((s for s in self._sessions if s["pid"] == int(pid)), None)
        if existing:
            existing["windows"].update(ids)
            if name:
                existing["name"] = name
            if icon_source:
                existing["icon_source"] = icon_source
        else:
            self._sessions.append({
                "pid": int(pid),
                "desktop_id": desktop_id or str(pid),
                "name": name or desktop_id or "Application",
                "icon_source": icon_source or "image://icons/application-x-executable",
                "windows": ids,
                "minimized": False,
            })
        self.refresh()

    @Slot()
    def refresh(self):
        current_ids = x11.get_all_window_ids()
        changed = False
        kept = []

        for session in self._sessions:
            alive = session["windows"].intersection(current_ids)
            if alive != session["windows"]:
                session["windows"] = alive
                changed = True
            if not alive:
                changed = True
                continue

            minimized = all(x11.is_window_minimized(wid) for wid in alive)
            if minimized != session["minimized"]:
                session["minimized"] = minimized
                changed = True
            kept.append(session)

        if len(kept) != len(self._sessions):
            self._sessions = kept

        visible = [s for s in self._sessions if s["minimized"]]
        old_keys = [(s["pid"], tuple(sorted(s["windows"]))) for s in self._visible]
        new_keys = [(s["pid"], tuple(sorted(s["windows"]))) for s in visible]

        if changed or old_keys != new_keys:
            old_count = self._count
            self.beginResetModel()
            self._visible = visible
            self._count = len(visible)
            self.endResetModel()
            if old_count != self._count:
                self.countChanged.emit()

    @Slot(int, result=bool)
    def restoreAt(self, row):
        if row < 0 or row >= len(self._visible):
            return False
        session = self._visible[row]
        for wid in session["windows"]:
            x11.restore_window(wid)
        return True
