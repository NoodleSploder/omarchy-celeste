pragma Singleton

// Connectivity summary for the bar: is anything up, wired or wireless, and how
// strong is the signal.
//
// Two things about Quickshell's Networking binding drive the defensiveness here.
// It populates asynchronously -- `devices` is empty for the first few seconds of
// a session, so "no devices" must read as "unknown", not "offline". And a
// device's `network` is null until the active connection resolves, so the SSID
// falls back to scanning `networks` for the active entry.

import QtQuick
import Quickshell
import Quickshell.Networking

QtObject {
    id: root

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property bool ready: root.devices.length > 0
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function _firstConnected(deviceType) {
        for (const d of root.devices)
            if (d && d.type === deviceType && d.connected)
                return d;
        return null;
    }

    readonly property var wifiDevice: root._firstConnected(DeviceType.Wifi)
    readonly property var wiredDevice: root._firstConnected(DeviceType.Wired)

    readonly property bool wired: !!wiredDevice
    readonly property bool wireless: !wiredDevice && !!wifiDevice
    readonly property bool connected: wired || wireless

    // The active network object, whichever way this backend exposes it.
    readonly property var activeNetwork: {
        const d = root.wifiDevice;
        if (!d)
            return null;
        if (d.network)
            return d.network;
        const list = d.networks ? d.networks.values : null;
        if (list)
            for (const n of list)
                if (n && (n.active || n.connected))
                    return n;
        return null;
    }

    readonly property string ssid: {
        const n = root.activeNetwork;
        if (!n)
            return "";
        return String(n.ssid || n.name || "");
    }

    readonly property int strength: {
        const n = root.activeNetwork;
        if (!n || n.strength === undefined)
            return 0;
        return Math.max(0, Math.min(100, n.strength));
    }

    readonly property string icon: {
        if (root.wired)
            return "lan";
        if (!root.ready)
            return "wifi_find";          // still resolving; do not claim offline
        if (!root.wifiEnabled)
            return "wifi_off";
        if (!root.wireless)
            return "signal_wifi_bad";
        if (!root.activeNetwork)
            return "signal_wifi_4_bar";  // connected, strength not yet known
        const bars = ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar",
                      "network_wifi_3_bar", "signal_wifi_4_bar"];
        return bars[Math.max(0, Math.min(bars.length - 1, Math.round(root.strength / 100 * (bars.length - 1))))];
    }

    readonly property string label: {
        if (root.wired)
            return "Wired";
        if (!root.ready)
            return "";
        return root.ssid || (root.wireless ? "Connected" : "Offline");
    }
}
