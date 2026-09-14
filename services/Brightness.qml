pragma Singleton

// Screen backlight brightness, via /sys/class/backlight for live reads
// (FileView + watchChanges, so any change -- this service, a hardware key,
// another app -- is reflected instantly with no polling) and brightnessctl
// for writes (it already handles the exponential-curve/min-value nuances
// backlight devices need, rather than writing raw sysfs values ourselves).
//
// The device directory is discovered at runtime (`ls /sys/class/backlight`)
// rather than hardcoded: it's a real hardware-specific name (this machine's
// is "intel_backlight") that has no reason to be the same on any other.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string device: ""
    property real maxBrightness: 0
    property real rawBrightness: 0

    readonly property bool available: root.device !== "" && root.maxBrightness > 0
    readonly property real brightness: root.available ? Math.max(0, Math.min(1, root.rawBrightness / root.maxBrightness)) : 0

    function setBrightness(fraction) {
        if (!root.available)
            return;
        const clamped = Math.max(0, Math.min(1, fraction));
        // Optimistic local update: brightnessctl's write to sysfs is what
        // FileView will eventually re-read anyway, but that's on the far
        // side of a process spawn + inotify round-trip -- updating here
        // keeps a dragged slider visually attached to the cursor instead of
        // trailing it by a frame or two.
        root.rawBrightness = clamped * root.maxBrightness;
        Quickshell.execDetached(["brightnessctl", "--device=" + root.device, "set", Math.round(clamped * 100) + "%"]);
    }

    function increment(step) {
        root.setBrightness(root.brightness + (step === undefined ? 0.05 : step));
    }

    function decrement(step) {
        root.setBrightness(root.brightness - (step === undefined ? 0.05 : step));
    }

    property Process deviceProc: Process {
        id: deviceProc
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const name = text.trim();
                if (name)
                    root.device = name;
            }
        }
    }

    property FileView maxFile: FileView {
        path: root.device ? "/sys/class/backlight/" + root.device + "/max_brightness" : ""
        printErrors: false
        onLoaded: {
            const n = parseFloat(text());
            if (!isNaN(n))
                root.maxBrightness = n;
        }
    }

    property FileView currentFile: FileView {
        path: root.device ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        watchChanges: true
        printErrors: false
        onLoaded: {
            const n = parseFloat(text());
            if (!isNaN(n))
                root.rawBrightness = n;
        }
        onFileChanged: reload()
    }

    Component.onCompleted: deviceProc.running = true
}
