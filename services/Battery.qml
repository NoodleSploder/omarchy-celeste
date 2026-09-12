pragma Singleton

// UPower's display device -- the aggregate battery UPower itself nominates,
// which is the right one to show on a bar regardless of how many cells exist.

import QtQuick
import Quickshell
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
}
