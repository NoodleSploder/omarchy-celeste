pragma Singleton

// Bluetooth adapter and connected-device summary.

import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool enabled: !!(adapter && adapter.enabled)
    readonly property bool discovering: !!(adapter && adapter.discovering)

    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedDevices: root.devices.filter(d => d && d.connected)
    readonly property int connectedCount: root.connectedDevices.length
    readonly property bool connected: root.connectedCount > 0

    readonly property string icon: {
        if (!root.available || !root.enabled)
            return "bluetooth_disabled";
        return root.connected ? "bluetooth_connected" : "bluetooth";
    }

    readonly property string label: {
        if (!root.available)
            return "No adapter";
        if (!root.enabled)
            return "Bluetooth off";
        if (root.connectedCount === 1)
            return String(root.connectedDevices[0].name || "Connected");
        if (root.connectedCount > 1)
            return `${root.connectedCount} devices`;
        return "Not connected";
    }
}
