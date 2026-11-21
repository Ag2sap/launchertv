#!/usr/bin/env python3
import atexit
import os
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from backend.config import AppConfig
from backend.hotkey import HomeKeyDaemon, apply_key_grab
from backend.icon_provider import IconProvider
from backend.launcher import AppLauncher
from backend.models import (
    AppListModel,
    CategoryListModel,
    discover_applications,
    get_most_used_apps,
)
from backend.weather import WeatherProvider
from backend.workspace import WorkspaceModel
from backend.system_monitor import SystemMonitor
from backend.x11 import activate_by_name


def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

    app = QGuiApplication(sys.argv)
    app.setApplicationName("LauncherTV")
    app.setOrganizationName("LauncherTV")

    engine = QQmlApplicationEngine()
    engine.addImageProvider("icons", IconProvider())

    config = AppConfig()
    all_apps = discover_applications()

    category_model = CategoryListModel()
    category_model.load_from(all_apps)

    most_used_model = AppListModel(get_most_used_apps(all_apps, config))
    launcher = AppLauncher()
    workspace_model = WorkspaceModel()
    launcher.sessionDetected.connect(workspace_model.registerSession)

    def on_launched(desktop_id: str):
        config.recordLaunch(desktop_id)
        most_used_model.reset_apps(get_most_used_apps(all_apps, config))

    launcher.launched.connect(on_launched)

    weather = WeatherProvider(config.weatherLocation)
    system_monitor = SystemMonitor()

    ctx = engine.rootContext()
    ctx.setContextProperty("appConfig", config)
    ctx.setContextProperty("categoryModel", category_model)
    ctx.setContextProperty("mostUsedModel", most_used_model)
    ctx.setContextProperty("appLauncher", launcher)
    ctx.setContextProperty("weather", weather)
    ctx.setContextProperty("systemMonitor", system_monitor)
    ctx.setContextProperty("workspaceModel", workspace_model)

    qml_path = Path(__file__).resolve().parent / "qml" / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not engine.rootObjects():
        sys.exit(1)

    grab_state = [config.grabHomeKey]
    if grab_state[0]:
        apply_key_grab(True)

    atexit.register(lambda: apply_key_grab(False))

    def on_config_changed():
        new = config.grabHomeKey
        if new != grab_state[0]:
            grab_state[0] = new
            apply_key_grab(new)

    config.configChanged.connect(on_config_changed)
    HomeKeyDaemon(lambda: activate_by_name("LauncherTV")).start()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
