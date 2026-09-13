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
import Quickshell.Io
import Quickshell.Networking

QtObject {
    id: root

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property bool ready: root.devices.length > 0
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function _firstDevice(deviceType) {
        let fallback = null;
        for (const d of root.devices)
            if (d && d.type === deviceType) {
                if (d.connected)
                    return d;
                if (!fallback)
                    fallback = d;
            }
        return fallback;
    }

    readonly property var wifiDevice: root._firstDevice(DeviceType.Wifi)
    readonly property var wiredDevice: root._firstDevice(DeviceType.Wired)

    readonly property bool wired: !!(wiredDevice && wiredDevice.connected)
    readonly property bool wireless: !wired && !!(wifiDevice && wifiDevice.connected)
    readonly property bool connected: wired || wireless
    readonly property var wifiNetworks: root.wifiDevice && root.wifiDevice.networks
        ? root.wifiDevice.networks.values : []

    function networkName(network) {
        return String((network && (network.ssid || network.name)) || "Hidden network");
    }

    function networkStrength(network) {
        return Math.max(0, Math.min(100, Number(network && network.strength) || 0));
    }

    function networkIcon(network) {
        const strength = root.networkStrength(network);
        if (strength >= 75) return "signal_wifi_4_bar";
        if (strength >= 50) return "network_wifi_3_bar";
        if (strength >= 25) return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function scan() {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = true;
    }

    function activate(network, passphrase) {
        if (!network)
            return;
        if (network.connected) {
            network.disconnect();
        } else if (passphrase && typeof network.connectWithPsk === "function") {
            network.connectWithPsk(passphrase);
        } else if (typeof network.connect === "function") {
            network.connect();
        }
    }

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
        if (root.connected && root.activeNetwork)
            return "wifi";               // filled, connected glyph rather than the open-wireframe variant
        return "wifi_off";
    }

    readonly property string label: {
        if (root.wired)
            return "Wired";
        if (!root.ready)
            return "";
        return root.ssid || (root.wireless ? "Connected" : "Offline");
    }

    // Networks sorted the way Omarchy's own network panel groups its list:
    // connected first, then known, then by signal -- so "KNOWN NETWORKS" /
    // "OTHER NETWORKS" section headers land in the right place.
    readonly property var sortedWifiNetworks: {
        const list = (root.wifiNetworks || []).slice();
        list.sort((a, b) => {
            const aConn = !!(a && a.connected), bConn = !!(b && b.connected);
            if (aConn !== bConn)
                return aConn ? -1 : 1;
            const aKnown = !!(a && a.known), bKnown = !!(b && b.known);
            if (aKnown !== bKnown)
                return aKnown ? -1 : 1;
            return (Number(b && b.strength) || 0) - (Number(a && a.strength) || 0);
        });
        return list;
    }

    function wifiSectionTitle(list, index) {
        if (index < 0 || index >= list.length)
            return "";
        const net = list[index];
        if (!net)
            return "";
        if (net.known && index === 0)
            return "KNOWN NETWORKS";
        if (!net.known && (index === 0 || (list[index - 1] && list[index - 1].known)))
            return "OTHER NETWORKS";
        return "";
    }

    // Playful status phrase while a link is up -- mirrors Omarchy's own
    // network panel (plugins/panels/network/Panel.qml: connectionPhrases),
    // so Celeste's popout reads the same while "connected" without a
    // static-looking subtitle.
    readonly property var connectionPhrases: [
        "Wiring bits", "Handling packets", "Sorting frames", "Hauling bytes",
        "Routing crumbs", "Counting collisions", "Bending light"
    ]
    property int connectionPhraseIndex: 0
    readonly property string connectionPhrase: root.connectionPhrases[root.connectionPhraseIndex % root.connectionPhrases.length]

    property Timer connectionPhraseTimer: Timer {
        interval: 2800
        repeat: true
        running: root.connected
        onTriggered: root.connectionPhraseIndex = (root.connectionPhraseIndex + 1) % root.connectionPhrases.length
    }

    // ---------------------------------------------------------- live details
    //
    // Ping, throughput and IP/gateway aren't exposed by Quickshell.Networking
    // at all, so this shells out to the same `omarchy-network-*` commands
    // Omarchy's own network panel uses, and ports its Model.js math for
    // throughput rate and rolling ping/packet-loss averages. Kept in this
    // singleton (rather than per-popout state) so watch/unwatch just ref-counts
    // rather than resetting whenever a popout is closed and reopened.

    property var info: ({})
    property real _prevRxBytes: 0
    property real _prevTxBytes: 0
    property real _prevSampleTime: 0
    property string _prevIface: ""
    property real downloadRate: 0
    property real uploadRate: 0
    property string _pingIface: ""
    property var routerPingSamples: []
    property var internetPingSamples: []
    property real routerPingLatency: -1
    property real internetPingLatency: -1
    property int internetPingPacketLoss: 0
    readonly property int pingHistoryWindow: 24
    readonly property int pingAverageWindow: 5
    readonly property bool hasInternetPing: root.internetPingSamples.length > 0
    readonly property bool hasTransferStats: root.info.rx_bytes !== undefined

    property string dnsProvider: "DHCP"
    property string bandCurrent: ""
    property string bandSelected: "auto"
    property var bandAvailable: []

    property int _detailsWatchers: 0
    readonly property bool detailsActive: root._detailsWatchers > 0

    function watchDetails() {
        root._detailsWatchers++;
        root.refreshDetails();
    }

    function unwatchDetails() {
        root._detailsWatchers = Math.max(0, root._detailsWatchers - 1);
        if (root._detailsWatchers === 0) {
            root._prevSampleTime = 0;
            root.downloadRate = 0;
            root.uploadRate = 0;
            root._pingIface = "";
            root.routerPingSamples = [];
            root.internetPingSamples = [];
            root.routerPingLatency = -1;
            root.internetPingLatency = -1;
            root.internetPingPacketLoss = 0;
        }
    }

    function refreshDetails() {
        if (!detailsProc.running)
            detailsProc.running = true;
        if (!dnsProc.running)
            dnsProc.running = true;
        if (!bandProc.running)
            bandProc.running = true;
    }

    function _parseKeyValue(raw) {
        const next = {};
        const lines = String(raw || "").split("\n");
        for (const line of lines) {
            if (!line)
                continue;
            const idx = line.indexOf("\t");
            if (idx === -1)
                continue;
            next[line.substring(0, idx)] = line.substring(idx + 1).trim();
        }
        return next;
    }

    function _updateDetails(raw) {
        const next = root._parseKeyValue(raw);
        root.info = next;
        root._updateThroughput(next);
        root._updatePingLatency(next);
    }

    function _updateThroughput(next) {
        const iface = next.iface || "";
        const rx = parseFloat(next.rx_bytes || "0");
        const tx = parseFloat(next.tx_bytes || "0");
        const now = Date.now() / 1000;
        if (iface !== root._prevIface || root._prevSampleTime === 0) {
            root._prevIface = iface;
            root._prevRxBytes = rx;
            root._prevTxBytes = tx;
            root._prevSampleTime = now;
            root.downloadRate = 0;
            root.uploadRate = 0;
            return;
        }
        const dt = now - root._prevSampleTime;
        if (dt > 0) {
            root.downloadRate = Math.max(0, (rx - root._prevRxBytes) / dt);
            root.uploadRate = Math.max(0, (tx - root._prevTxBytes) / dt);
        }
        root._prevIface = iface;
        root._prevRxBytes = rx;
        root._prevTxBytes = tx;
        root._prevSampleTime = now;
    }

    function _pingSampleValue(raw) {
        const value = parseFloat(raw);
        return (!isFinite(value) || value < 0) ? null : value;
    }

    function _averagePing(samples) {
        const window = samples.slice(Math.max(0, samples.length - root.pingAverageWindow));
        let total = 0, count = 0;
        for (const v of window) {
            if (typeof v === "number" && isFinite(v) && v >= 0) {
                total += v;
                count++;
            }
        }
        return count > 0 ? total / count : -1;
    }

    function _packetLoss(samples) {
        if (samples.length === 0)
            return 0;
        let lost = 0;
        for (const v of samples)
            if (v === null)
                lost++;
        return Math.round((lost / samples.length) * 100);
    }

    function _updatePingLatency(next) {
        const iface = next.iface || "";
        if (iface === "" || iface !== root._pingIface) {
            root.routerPingSamples = [];
            root.internetPingSamples = [];
        }
        root._pingIface = iface;
        if (next.router_ping_ms !== undefined) {
            const v = root.routerPingSamples.concat([root._pingSampleValue(next.router_ping_ms)]);
            root.routerPingSamples = v.slice(Math.max(0, v.length - root.pingHistoryWindow));
        }
        if (next.internet_ping_ms !== undefined) {
            const v = root.internetPingSamples.concat([root._pingSampleValue(next.internet_ping_ms)]);
            root.internetPingSamples = v.slice(Math.max(0, v.length - root.pingHistoryWindow));
        }
        root.routerPingLatency = root._averagePing(root.routerPingSamples);
        root.internetPingLatency = root._averagePing(root.internetPingSamples);
        root.internetPingPacketLoss = root._packetLoss(root.internetPingSamples);
    }

    function formatBytes(bytes) {
        let n = Number(bytes);
        if (!isFinite(n) || n < 0)
            n = 0;
        if (n < 1024)
            return Math.round(n) + " B";
        if (n < 1024 * 1024)
            return (n / 1024).toFixed(1) + " KB";
        if (n < 1024 * 1024 * 1024)
            return (n / (1024 * 1024)).toFixed(1) + " MB";
        return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB";
    }

    function formatRate(bytesPerSec) {
        return root.formatBytes(bytesPerSec) + "/s";
    }

    function formatPingLatency(ms, hasSamples) {
        if (hasSamples === false)
            return "--";
        const value = parseFloat(ms);
        if (!isFinite(value) || value < 0)
            return "Timeout";
        return value.toFixed(value > 0 && value < 10 ? 1 : 0) + " ms";
    }

    function formatPacketLoss(percent, hasSamples) {
        if (hasSamples === false)
            return "--";
        const value = parseInt(percent, 10);
        if (!value || value < 0)
            return "0%";
        return value + "%";
    }

    function bandLabel(band) {
        if (band === "auto")
            return "Auto";
        if (!band)
            return "";
        return band + "ghz";
    }

    readonly property bool bandPinned: root.bandSelected !== "auto"
    readonly property bool canSelectBand: root.wireless && (root.bandAvailable.length > 1 || root.bandPinned)
    readonly property bool bandPillsVisible: root.canSelectBand && root.bandPinned
    readonly property string bandSectionTitle: {
        if (root.bandPinned)
            return "WI-FI BAND";
        const label = root.bandLabel(root.bandCurrent);
        return label === "" ? "WI-FI BAND" : "WI-FI BAND: " + label.toUpperCase();
    }

    function setBand(band) {
        if (!band || bandActionProc.running)
            return;
        bandActionProc.command = ["omarchy-network-band", band];
        bandActionProc.running = true;
    }

    function toggleBandAuto() {
        if (root.bandPinned) {
            root.setBand("auto");
            return;
        }
        if (root.bandCurrent !== "")
            root.setBand(root.bandCurrent);
    }

    readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]

    function setDns(provider) {
        if (!provider || dnsActionProc.running)
            return;
        if (provider === "Custom") {
            Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-dns Custom"]);
            return;
        }
        dnsActionProc.command = ["bash", "-c", "omarchy-dns " + provider];
        dnsActionProc.running = true;
    }

    function _shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function copyToClipboard(value) {
        if (!value)
            return;
        Quickshell.execDetached(["bash", "-c", "printf %s " + root._shellQuote(String(value)) + " | wl-copy"]);
    }

    property Process detailsProc: Process {
        id: detailsProc
        command: ["omarchy-network-status", "--verbose"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._updateDetails(text)
        }
    }

    property Process dnsProc: Process {
        id: dnsProc
        command: ["omarchy-dns"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.dnsProvider = String(text).trim() || "DHCP"
        }
    }

    property Process bandProc: Process {
        id: bandProc
        command: ["omarchy-network-band"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const kv = root._parseKeyValue(text);
                root.bandCurrent = kv.band || "";
                root.bandSelected = kv.selected || "auto";
                root.bandAvailable = String(kv.available || "").split(" ").filter(t => t !== "");
            }
        }
    }

    property Process bandActionProc: Process {
        id: bandActionProc
        onExited: root.refreshDetails()
    }

    property Process dnsActionProc: Process {
        id: dnsActionProc
        onExited: exitCode => { if (exitCode === 0) root.refreshDetails(); }
    }

    property Timer detailsPollTimer: Timer {
        interval: 1500
        repeat: true
        running: root.detailsActive
        triggeredOnStart: true
        onTriggered: if (!detailsProc.running) detailsProc.running = true
    }

    property Timer bandPollTimer: Timer {
        interval: 4000
        repeat: true
        running: root.detailsActive
        onTriggered: if (!bandProc.running) bandProc.running = true
    }
}
