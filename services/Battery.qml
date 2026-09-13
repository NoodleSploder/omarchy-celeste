pragma Singleton

// UPower's display device -- the aggregate battery UPower itself nominates,
// which is the right one to show on a bar regardless of how many cells exist.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

QtObject {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: !!(device && device.isPresent)
    readonly property real percentage: present ? device.percentage : 0
    readonly property int percent: Math.round(percentage * 100)
    readonly property bool onBattery: UPower.onBattery
    readonly property bool discharging: present && onBattery
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: present && device.state === UPowerDeviceState.FullyCharged
    readonly property bool low: present && percent <= 20 && !charging

    // Idle in the sense that current isn't visibly flowing either way, so the
    // "time to full" / "charge rate" numbers below are suppressed to "-"
    // rather than showing a stale or meaningless reading.
    readonly property bool batteryFull: root.fullyCharged || (!root.discharging && root.percentage >= 1)

    // Material Symbols has discrete battery glyphs in 1/7 steps.
    readonly property string icon: {
        if (!present)
            return "battery_unknown";
        if (charging)
            return "battery_charging_full";
        if (fullyCharged || percent >= 95)
            return "battery_full";
        const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar",
                       "battery_4_bar", "battery_5_bar", "battery_6_bar"];
        return steps[Math.max(0, Math.min(steps.length - 1, Math.round(percent / 100 * (steps.length - 1))))];
    }

    // Playful status phrase while current is flowing -- mirrors Omarchy's own
    // power panel (plugins/panels/power/Panel.qml: chargingPhrases /
    // onBatteryPhrases).
    readonly property var chargingPhrases: [
        "Pumping power", "Injecting electrons", "Pouring juice", "Amassing watts",
        "Hoarding joules", "Sucking volts", "Topping reserves", "Soaking amps", "Inhaling kilowatts"
    ]
    readonly property var onBatteryPhrases: [
        "Slurping power", "Spending joules", "Draining watts", "Burning electrons",
        "Sipping juice", "Spending coulombs", "Bleeding amps", "Guzzling volts", "Munching reserves"
    ]
    property int phraseIndex: 0
    readonly property var activePhrases: {
        if (root.fullyCharged || root.batteryFull)
            return [];
        if (root.charging)
            return root.chargingPhrases;
        if (root.discharging)
            return root.onBatteryPhrases;
        return [];
    }
    readonly property string heroStatusText: {
        if (!root.present)
            return "";
        if (root.fullyCharged || root.batteryFull)
            return "Fully charged";
        if (root.activePhrases.length > 0)
            return root.activePhrases[root.phraseIndex % root.activePhrases.length];
        return root.discharging ? "On battery" : "Charging";
    }

    property Timer phraseTimer: Timer {
        interval: 2800
        repeat: true
        running: root.activePhrases.length > 0
        onTriggered: root.phraseIndex = (root.phraseIndex + 1) % Math.max(1, root.activePhrases.length)
    }

    // ---------------------------------------------------------------- stats
    //
    // Battery size/cycles/time-to-full/rate aren't exposed by UPower's Qt
    // binding, so this shells out to the same `omarchy-battery-status
    // --shell` Omarchy's own power panel uses.

    property var info: ({})
    readonly property bool hasInfo: root.info.percentage !== undefined

    property int _detailsWatchers: 0
    readonly property bool detailsActive: root._detailsWatchers > 0

    function watchDetails() {
        root._detailsWatchers++;
        root.refreshDetails();
    }

    function unwatchDetails() {
        root._detailsWatchers = Math.max(0, root._detailsWatchers - 1);
    }

    function refreshDetails() {
        if (!root.present)
            return;
        if (!detailsProc.running)
            detailsProc.running = true;
        if (!profilesProc.running)
            profilesProc.running = true;
    }

    function _parseKeyValue(raw) {
        const next = {};
        for (const line of String(raw || "").split("\n")) {
            const idx = line.indexOf("\t");
            if (idx <= 0)
                continue;
            next[line.substring(0, idx)] = line.substring(idx + 1).trim();
        }
        return next;
    }

    // -------------------------------------------------------- power profile

    property var profiles: []
    property string activeProfile: ""

    function profileIcon(name) {
        if (name === "power-saver")
            return "eco";
        if (name === "balanced")
            return "balance";
        if (name === "performance")
            return "bolt";
        return "settings";
    }

    function profileLabel(name) {
        const text = String(name || "");
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    function setProfile(name) {
        if (!name || profileActionProc.running)
            return;
        profileActionProc.command = ["omarchy-powerprofiles-set", root.discharging ? "battery" : "ac", name];
        profileActionProc.running = true;
    }

    property Process detailsProc: Process {
        id: detailsProc
        command: ["omarchy-battery-status", "--shell"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const next = root._parseKeyValue(text);
                if (Object.keys(next).length > 0)
                    root.info = next;
            }
        }
    }

    property Process profilesProc: Process {
        id: profilesProc
        command: ["omarchy-powerprofiles-list", "--active-state"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const list = [];
                let active = "";
                for (const line of String(text || "").split("\n")) {
                    const trimmed = line.trim();
                    if (!trimmed)
                        continue;
                    const parts = trimmed.split("\t");
                    list.push(parts[0]);
                    if (parts[1] === "1")
                        active = parts[0];
                }
                if (list.length > 0) {
                    root.profiles = list;
                    root.activeProfile = active;
                }
            }
        }
    }

    property Process profileActionProc: Process {
        id: profileActionProc
        onExited: root.refreshDetails()
    }

    property Timer detailsPollTimer: Timer {
        interval: 5000
        repeat: true
        running: root.detailsActive
        triggeredOnStart: true
        onTriggered: root.refreshDetails()
    }
}
