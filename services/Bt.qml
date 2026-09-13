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

    // ------------------------------------------------------- device grouping
    //
    // Ported from Omarchy's own bluetooth panel (plugins/panels/bluetooth/
    // Model.js) so Celeste's popout groups devices the same way: a device
    // with no human-readable name (BlueZ sometimes exposes only its MAC or a
    // GATT UUID before the name resolves) is filtered out rather than shown
    // as a blank row.

    function deviceLabel(device) {
        return String((device && (device.deviceName || device.name)) || "").trim();
    }

    function _isUuidLike(value) {
        const text = String(value || "").trim();
        if (text === "")
            return false;
        return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(text)
            || /^[0-9a-f]{32}$/i.test(text)
            || /^0x[0-9a-f]{4,32}$/i.test(text);
    }

    function _isAddressLike(value) {
        return /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(String(value || "").trim());
    }

    function hasHumanName(device) {
        const label = root.deviceLabel(device);
        return label !== "" && !root._isUuidLike(label) && !root._isAddressLike(label);
    }

    function _sortedByLabel(devices) {
        const list = devices.slice();
        list.sort((a, b) => root.deviceLabel(a).localeCompare(root.deviceLabel(b)));
        return list;
    }

    readonly property var deviceGroups: {
        const connected = [], known = [], discovered = [];
        for (const d of root.devices) {
            if (!d || !root.hasHumanName(d))
                continue;
            if (d.connected)
                connected.push(d);
            else if (d.paired || d.bonded || d.trusted)
                known.push(d);
            else
                discovered.push(d);
        }
        return {
            connected: root._sortedByLabel(connected),
            known: root._sortedByLabel(known),
            discovered: root._sortedByLabel(discovered)
        };
    }

    readonly property var connectedDevices: root.deviceGroups.connected
    readonly property var knownDevices: root.deviceGroups.known
    readonly property var discoveredDevices: root.deviceGroups.discovered
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
            return root.deviceLabel(root.connectedDevices[0]) || "Connected";
        if (root.connectedCount > 1)
            return `${root.connectedCount} devices`;
        return "Not connected";
    }

    // Playful status phrase while the radio is on -- mirrors Omarchy's own
    // bluetooth panel (plugins/panels/bluetooth/Panel.qml: activePhrases).
    readonly property var activePhrases: [
        "Untangling wires", "Streaming vikings", "Pairing mysteries", "Herding headsets",
        "Taming radios", "Summoning speakers", "Wrangling codecs", "Polishing packets"
    ]
    property int phraseIndex: 0
    readonly property string heroStatusText: {
        if (!root.available)
            return "No adapter";
        if (!root.enabled)
            return "Turned off";
        return root.activePhrases[root.phraseIndex % root.activePhrases.length];
    }

    property Timer phraseTimer: Timer {
        interval: 2800
        repeat: true
        running: root.enabled
        onTriggered: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }

    // ---------------------------------------------------------------- power

    function toggleBluetooth() {
        if (!root.adapter)
            return;
        Quickshell.execDetached(["omarchy-bluetooth-power", root.enabled ? "off" : "on"]);
    }

    // ----------------------------------------------------------- discovery
    //
    // Ref-counted the same way as Net.watchDetails(): each open popout (one
    // per monitor, in principle) calls watchDiscovery()/unwatchDiscovery()
    // from Component.onCompleted/onDestruction, so discovery only actually
    // stops once nobody is looking at the list any more.

    property int _discoveryWatchers: 0

    function watchDiscovery() {
        root._discoveryWatchers++;
        if (root.adapter && root.enabled)
            root.adapter.discovering = true;
    }

    function unwatchDiscovery() {
        root._discoveryWatchers = Math.max(0, root._discoveryWatchers - 1);
        if (root._discoveryWatchers === 0 && root.adapter)
            root.adapter.discovering = false;
    }

    // ------------------------------------------------------------- actions
    //
    // Connect/pair/forget go through the same `omarchy-bluetooth-device`
    // helper Omarchy's own panel uses (it drives bluetoothctl's pairing
    // agent, which the bare BlueZ device object does not handle on its own).
    // Disconnect also calls the device's own disconnect() directly for
    // immediate feedback, same as native.

    property var pendingActions: ({})

    function pendingAction(address) {
        return address && root.pendingActions[address] ? root.pendingActions[address] : "";
    }

    function _setPendingAction(address, action) {
        if (!address)
            return;
        const next = Object.assign({}, root.pendingActions);
        if (action)
            next[address] = action;
        else
            delete next[address];
        root.pendingActions = next;
        if (action)
            pendingTimeout.restart();
    }

    function _deviceCommand(action, address) {
        return ["omarchy-bluetooth-device", action, address];
    }

    function connectDevice(device) {
        if (!device || device.connected)
            return;
        const action = (device.paired || device.bonded || device.trusted) ? "connect" : "pair";
        root._setPendingAction(device.address, "connecting");
        Quickshell.execDetached(root._deviceCommand(action, device.address));
    }

    function disconnectDevice(device) {
        if (!device || !device.connected)
            return;
        root._setPendingAction(device.address, "disconnecting");
        if (device.disconnect)
            device.disconnect();
        Quickshell.execDetached(root._deviceCommand("disconnect", device.address));
    }

    function forgetDevice(device) {
        if (!device || !device.address)
            return;
        root._setPendingAction(device.address, "forgetting");
        Quickshell.execDetached(root._deviceCommand("forget", device.address));
    }

    function _syncPendingActions() {
        const next = Object.assign({}, root.pendingActions);
        let changed = false;
        for (const address in next) {
            const action = next[address];
            let found = null;
            for (const d of root.devices)
                if (d && d.address === address) { found = d; break; }

            const finishedConnecting = action === "connecting" && found && found.connected;
            const finishedDisconnecting = action === "disconnecting" && found && !found.connected;
            const finishedForgetting = action === "forgetting" && (!found || (!found.paired && !found.bonded && !found.trusted));
            if (finishedConnecting || finishedDisconnecting || finishedForgetting) {
                delete next[address];
                changed = true;
            }
        }
        if (changed)
            root.pendingActions = next;
    }

    property Timer pendingSyncTimer: Timer {
        interval: 700
        repeat: true
        running: Object.keys(root.pendingActions).length > 0
        onTriggered: root._syncPendingActions()
    }

    // Safety net: never leave a row reading "Connecting…" forever if BlueZ
    // never reports completion (a rejected pairing, a device that vanished).
    property Timer pendingTimeout: Timer {
        interval: 20000
        repeat: false
        onTriggered: root.pendingActions = ({})
    }
}
