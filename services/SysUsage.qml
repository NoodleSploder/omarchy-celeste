pragma Singleton

// Memory and CPU usage from /proc.
//
// Caelestia reads these through native collectors. Plain file reads are enough:
// /proc/meminfo is a single small parse, and CPU load is the delta between two
// /proc/stat samples. Both are re-read on a timer -- /proc does not notify.
//
// Deliberately never touches QStorageInfo or any mount-point API. statfs() on a
// direct autofs mount triggers the automount, which parks the QML thread in
// uninterruptible sleep and freezes every surface it draws.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property int interval: 3000

    // ------------------------------------------------------------- memory

    property real memTotal: 0
    property real memAvailable: 0

    readonly property real memUsed: Math.max(0, memTotal - memAvailable)
    readonly property real memPercentage: memTotal > 0 ? memUsed / memTotal : 0

    // -------------------------------------------------------------- cpu

    property real _prevIdle: -1
    property real _prevTotal: -1
    property real cpuPercentage: 0

    function _parseMeminfo(text) {
        let total = 0;
        let avail = 0;
        for (const line of text.split("\n")) {
            if (line.startsWith("MemTotal:"))
                total = parseFloat(line.replace(/[^0-9]/g, ""));
            else if (line.startsWith("MemAvailable:"))
                avail = parseFloat(line.replace(/[^0-9]/g, ""));
            if (total && avail)
                break;
        }
        if (total > 0) {
            root.memTotal = total;
            root.memAvailable = avail;
        }
    }

    function _parseStat(text) {
        const first = text.split("\n")[0];
        if (!first || !first.startsWith("cpu "))
            return;
        const f = first.split(/\s+/).slice(1).map(parseFloat).filter(n => !isNaN(n));
        if (f.length < 5)
            return;
        // user nice system idle iowait irq softirq steal ...
        const idle = f[3] + (f[4] || 0);
        let total = 0;
        for (const v of f)
            total += v;

        if (root._prevTotal >= 0) {
            const dTotal = total - root._prevTotal;
            const dIdle = idle - root._prevIdle;
            // A zero delta means two samples landed in the same tick; keep the
            // previous reading rather than reporting a spurious 0%.
            if (dTotal > 0)
                root.cpuPercentage = Math.max(0, Math.min(1, (dTotal - dIdle) / dTotal));
        }
        root._prevIdle = idle;
        root._prevTotal = total;
    }

    property FileView meminfo: FileView {
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root._parseMeminfo(text())
    }

    property FileView stat: FileView {
        path: "/proc/stat"
        printErrors: false
        onLoaded: root._parseStat(text())
    }

    property Timer poll: Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.meminfo.reload();
            root.stat.reload();
        }
    }
}
