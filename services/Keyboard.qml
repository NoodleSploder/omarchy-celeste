pragma Singleton

// Caps and num lock state, read from the kernel LED class.
//
// Hyprland's IPC does not report lock-key state, and Caelestia gets it from a
// native helper. sysfs exposes it directly: every keyboard publishes
// input<N>::capslock / ::numlock, and any of them being lit means the lock is on.
//
// The LED paths are enumerated once with a single subprocess at startup; after
// that this polls by re-reading those files through FileView, which is a
// two-byte read rather than a fork. sysfs does not deliver inotify events for
// LED brightness, so there is nothing to subscribe to. (XMLHttpRequest is not an
// option -- Qt disables GET on local files by default.)

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var capsPaths: []
    property var numPaths: []

    // Per-path latest values, keyed by path.
    property var values: ({})

    function _anyLit(paths) {
        for (const p of paths) {
            const v = root.values[p];
            if (v !== undefined && v !== "" && v !== "0")
                return true;
        }
        return false;
    }

    readonly property bool capsLock: root._anyLit(root.capsPaths)
    readonly property bool numLock: root._anyLit(root.numPaths)
    readonly property bool anyLock: capsLock || numLock

    function report(path, text) {
        const next = {};
        for (const k in root.values)
            next[k] = root.values[k];
        next[path] = String(text || "").trim();
        root.values = next;
    }

    // Missing LEDs are normal -- many keyboards expose none -- in which case both
    // indicators simply stay false and the poll never starts.
    property Process discover: Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock /sys/class/leds/*::numlock 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const caps = [];
                const nums = [];
                for (const line of text.split("\n")) {
                    const p = line.trim();
                    if (!p)
                        continue;
                    if (p.endsWith("::capslock"))
                        caps.push(p + "/brightness");
                    else if (p.endsWith("::numlock"))
                        nums.push(p + "/brightness");
                }
                root.capsPaths = caps;
                root.numPaths = nums;
            }
        }
    }

    readonly property var allPaths: root.capsPaths.concat(root.numPaths)

    property Instantiator readers: Instantiator {
        model: root.allPaths

        delegate: FileView {
            id: view

            required property string modelData

            path: view.modelData
            printErrors: false
            onLoaded: root.report(view.modelData, text())
        }
    }

    property Timer poll: Timer {
        interval: 600
        running: root.allPaths.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            for (let i = 0; i < root.readers.count; i++) {
                const v = root.readers.objectAt(i);
                if (v)
                    v.reload();
            }
        }
    }
}
