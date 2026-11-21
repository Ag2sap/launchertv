from PySide6.QtCore import QObject, Property, QTimer, Signal


class SystemMonitor(QObject):
    """Lightweight CPU and memory usage sampler using Linux procfs."""

    metricsChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._cpu_usage = 0.0
        self._ram_usage = 0.0
        self._cpu_total, self._cpu_idle = self._read_cpu_counters()

        self._timer = QTimer(self)
        self._timer.setInterval(2000)
        self._timer.timeout.connect(self._update_metrics)
        self._timer.start()

        self._update_metrics()

    @Property(float, notify=metricsChanged)
    def cpuUsage(self):
        return self._cpu_usage

    @Property(float, notify=metricsChanged)
    def ramUsage(self):
        return self._ram_usage

    @staticmethod
    def _read_cpu_counters():
        try:
            with open("/proc/stat", "r", encoding="ascii") as stat_file:
                fields = stat_file.readline().split()
            if not fields or fields[0] != "cpu":
                return 0, 0

            values = [int(value) for value in fields[1:]]
            total = sum(values)
            idle = values[3] + (values[4] if len(values) > 4 else 0)
            return total, idle
        except (OSError, ValueError, IndexError):
            return 0, 0

    @staticmethod
    def _read_ram_usage():
        try:
            values = {}
            with open("/proc/meminfo", "r", encoding="ascii") as mem_file:
                for line in mem_file:
                    key, value = line.split(":", 1)
                    if key in ("MemTotal", "MemAvailable"):
                        values[key] = int(value.strip().split()[0])

            total = values.get("MemTotal", 0)
            available = values.get("MemAvailable", 0)
            if total <= 0:
                return 0.0

            used = max(0, total - available)
            return min(100.0, max(0.0, used * 100.0 / total))
        except (OSError, ValueError, IndexError):
            return 0.0

    def _update_metrics(self):
        total, idle = self._read_cpu_counters()
        delta_total = total - self._cpu_total
        delta_idle = idle - self._cpu_idle

        if delta_total > 0:
            busy = max(0, delta_total - delta_idle)
            self._cpu_usage = min(100.0, max(0.0, busy * 100.0 / delta_total))

        self._cpu_total, self._cpu_idle = total, idle
        self._ram_usage = self._read_ram_usage()
        self.metricsChanged.emit()
