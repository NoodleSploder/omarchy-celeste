pragma Singleton

// Claude Code / Codex / Fireworks usage, for a Celeste-native "agents" status
// popout matching Audio/Network/Bluetooth/Battery's border-attached style.
//
// The real omarchy.agents plugin (/usr/share/omarchy/shell/plugins/agents/)
// draws this data in its own Ui.KeyboardPanel, which Celeste cannot restyle
// without changing that shared component for every Omarchy panel on the
// system (see CLAUDE.md's "AI usage icon" entry for how that was confirmed,
// not guessed, by reading Ui/KeyboardPanel.qml directly). So this service
// reads the SAME underlying data Omarchy's own Main.qml reads -- one JSON
// record per agent under $XDG_STATE_HOME/omarchy/agents/usage/ (or
// ~/.local/state if unset), written by the real `omarchy-agent-usage-update`
// CLI tool -- the same "shell out to the real tool, don't reimplement the
// probing" pattern already used for network/battery/bluetooth. Every
// formatting helper below is ported from that plugin's own Panel.qml /
// Main.qml (verified against the real JSON on disk, not guessed at) --
// see ATTRIBUTION.md.
//
// Deliberately NOT ported: sync-across-devices (aggregateData/snapshot
// merging) -- a single-machine view is what a bar popout needs, and pulling
// that in would mean also reading the user's sync settings, which this
// anchor-free approach has no access to anyway.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || (root.home + "/.local/state")) + "/omarchy/agents/usage"
    readonly property string assetsDir: "/usr/share/omarchy/shell/plugins/agents/assets"

    property var agentIds: []
    property var records: ({})
    property double nowMs: Date.now()

    // Ref-counted like Net.qml's watchDetails()/unwatchDetails(): the CLI
    // refresh only runs while a popout actually has this open, but the
    // status icon still needs SOME data at startup to know whether to show
    // itself at all, hence the unconditional one-shot rescan on completion.
    property int watchers: 0

    function watch() {
        root.watchers++;
        if (root.watchers === 1) {
            refreshTimer.triggeredOnStart = true;
            refreshTimer.running = true;
        }
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
        if (root.watchers === 0)
            refreshTimer.running = false;
    }

    function refreshNow() {
        if (!updateProcess.running)
            updateProcess.running = true;
    }

    // Enabled providers, closest equivalent of Main.qml's own
    // enabledProviders/providerHasData -- an agent with nothing to show
    // (never authenticated, never run) drops out entirely rather than
    // sitting there empty, same as the real plugin.
    readonly property var providers: {
        const out = [];
        for (const id of root.agentIds) {
            const r = root.records[id];
            if (!r)
                continue;
            const hasData = root.numberValue(r.totalPrompts) > 0 || root.numberValue(r.totalSessions) > 0
                || root.numberValue(r.activeDays) > 0 || root.numberValue(r.todayPrompts) > 0
                || root.numberValue(r.todaySessions) > 0 || (Array.isArray(r.limits) && r.limits.length > 0)
                || !!root.balanceValue(r.balance);
            if (hasData)
                out.push(r);
        }
        return out;
    }

    readonly property bool available: root.providers.length > 0

    function numberValue(v) {
        const n = Number(v || 0);
        return isFinite(n) ? Math.round(n) : 0;
    }

    function balanceValue(raw) {
        if (!raw || typeof raw !== "object")
            return null;
        const remaining = Number(raw.remaining);
        if (!isFinite(remaining) || remaining < 0)
            return null;
        const funded = Number(raw.funded);
        return {
            remaining: remaining,
            funded: isFinite(funded) && funded > 0 ? funded : 0,
            spent: Math.max(0, Number(raw.spent) || 0),
            currency: String(raw.currency || "USD"),
            estimated: raw.estimated === true
        };
    }

    // ------------------------------------------------------------- format

    function formatTokenCount(n) {
        if (n === undefined || n === null)
            return "0";
        if (n >= 1e9)
            return (n / 1e9).toFixed(1) + "B";
        if (n >= 1e6)
            return (n / 1e6).toFixed(1) + "M";
        if (n >= 1e3)
            return (n / 1e3).toFixed(1) + "K";
        return String(n);
    }

    function modelWordCase(word) {
        if (word === "gpt")
            return "GPT";
        if (word === "deepseek")
            return "DeepSeek";
        return word.charAt(0).toUpperCase() + word.slice(1);
    }

    function friendlyModelName(id) {
        if (!id)
            return "Unknown";
        const name = String(id).replace(/^claude-/, "").replace(/-\d{8}$/, "");
        const parts = name.split("-");
        const words = [];
        let version = [];
        for (const part of parts) {
            if (part === "")
                continue;
            if (/^\d/.test(part)) {
                version.push(part);
                continue;
            }
            if (version.length > 0) {
                words.push(version.join("."));
                version = [];
            }
            words.push(root.modelWordCase(part));
        }
        if (version.length > 0)
            words.push(version.join("."));
        return words.length > 0 ? words.join(" ") : "Unknown";
    }

    function windowIsLong(text) {
        return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
            || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0;
    }

    function windowTitle(label) {
        const text = String(label || "").toLowerCase();
        if (text.indexOf("month") >= 0)
            return "Monthly";
        if (root.windowIsLong(text))
            return "Weekly";
        if (text.indexOf("session") >= 0)
            return "Session";
        const plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim();
        return plain === "" ? "Limit" : plain;
    }

    // Normalised limit windows for one provider: [{title, percent, resetAt}].
    function limitWindows(provider) {
        if (!provider)
            return [];
        const out = [];
        for (const entry of (provider.limits || [])) {
            const percent = Number(entry.percent);
            if (percent >= 0)
                out.push({
                    title: String(entry.title || "") !== "" ? String(entry.title) : root.windowTitle(entry.label),
                    percent: percent,
                    resetAt: String(entry.resetsAt || "")
                });
        }
        return out;
    }

    // The fullest window -- what actually stops the next prompt.
    function bindingWindow(provider) {
        const windows = root.limitWindows(provider);
        let best = null;
        for (const w of windows) {
            if (!best || w.percent > best.percent)
                best = w;
        }
        return best;
    }

    function resetMsFor(window) {
        if (!window || window.resetAt === "")
            return -1;
        const ms = new Date(window.resetAt).getTime();
        return isFinite(ms) ? ms - root.nowMs : -1;
    }

    function formatDuration(ms) {
        if (!(ms > 0))
            return "now";
        const minutes = Math.floor(ms / 60000);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);
        if (days > 0)
            return days + "d " + (hours % 24) + "h";
        if (hours > 0)
            return hours + "h " + (minutes % 60) + "m";
        return Math.max(1, minutes) + "m";
    }

    function currencyPrefix(currency) {
        const code = String(currency || "USD").toUpperCase();
        if (code === "USD")
            return "$";
        if (code === "EUR")
            return "€";
        if (code === "GBP")
            return "£";
        return code + " ";
    }

    function formatMoney(value, currency) {
        let amount = Number(value);
        if (!isFinite(amount))
            amount = 0;
        return root.currencyPrefix(currency) + amount.toFixed(2);
    }

    function balanceDetailText(b) {
        if (!b || !(b.funded > 0))
            return "";
        let text = root.formatMoney(b.spent, b.currency) + " spent of " + root.formatMoney(b.funded, b.currency) + " funded";
        if (b.estimated)
            text += " · estimated";
        return text;
    }

    function heroMeta(provider) {
        if (!provider)
            return "";
        if (String(provider.usageStatusText || "") !== "")
            return provider.usageStatusText;
        const tier = String(provider.tierLabel || "");
        if (tier === "")
            return "Subscription";
        return tier.charAt(0).toUpperCase() + tier.slice(1);
    }

    function todayDate() {
        const now = new Date(root.nowMs);
        return now.getFullYear() + "-" + String(now.getMonth() + 1).padStart(2, "0") + "-" + String(now.getDate()).padStart(2, "0");
    }

    function dayName(date) {
        const parsed = new Date(String(date || "") + "T00:00:00");
        if (isNaN(parsed.getTime()))
            return String(date || "");
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][parsed.getDay()];
    }

    function dayLabel(date, today) {
        return today ? "Today" : root.dayName(date);
    }

    function weekPeak(provider) {
        const days = provider ? (provider.recentDays || []) : [];
        let peak = 0;
        for (const d of days)
            peak = Math.max(peak, Number(d.messageCount || 0));
        return peak;
    }

    function modelRows(provider) {
        const usageByModel = provider ? (provider.modelUsage || {}) : {};
        const rows = [];
        for (const id in usageByModel) {
            const bucket = usageByModel[id] || {};
            const input = Number(bucket.inputTokens || 0);
            const output = Number(bucket.outputTokens || 0);
            const cacheRead = Number(bucket.cacheReadInputTokens || 0);
            const cacheWrite = Number(bucket.cacheCreationInputTokens || 0);
            rows.push({
                name: root.friendlyModelName(id),
                total: input + output + cacheRead + cacheWrite,
                input: input,
                output: output,
                cacheRead: cacheRead,
                cacheWrite: cacheWrite
            });
        }
        rows.sort((a, b) => b.total - a.total);
        return rows.slice(0, 4);
    }

    // A light-surface twin exists only for codex; Image's own error fallback
    // (see AgentsPopout.qml) covers providers that only ship the base mark.
    function iconSource(providerId, preferLight) {
        if (!providerId)
            return "";
        if (preferLight)
            return "file://" + root.assetsDir + "/" + providerId + "-light.svg";
        return "file://" + root.assetsDir + "/" + providerId + ".svg";
    }

    function iconFallback(providerId) {
        return providerId ? "file://" + root.assetsDir + "/" + providerId + ".svg" : "";
    }

    // ---------------------------------------------------------------- scan

    function rescan() {
        if (!listProcess.running)
            listProcess.running = true;
    }

    property Process listProcess: Process {
        id: listProcess
        command: ["find", root.usageDir, "-maxdepth", "1", "-name", "*.json", "-printf", "%f\\n"]
        stdout: StdioCollector {
            id: listStdout
            waitForEnd: true
            onStreamFinished: {
                const ids = [];
                for (const line of listStdout.text.split("\n")) {
                    const name = line.trim();
                    if (name.slice(-5) === ".json")
                        ids.push(name.slice(0, -5));
                }
                ids.sort();
                root.agentIds = ids;
            }
        }
    }

    property Instantiator readers: Instantiator {
        model: root.agentIds

        delegate: FileView {
            id: view

            required property string modelData

            path: root.usageDir + "/" + view.modelData + ".json"
            printErrors: false
            watchChanges: true

            onLoaded: root.applyRecord(view.modelData, view.text())
            onFileChanged: reload()
        }
    }

    function applyRecord(id, text) {
        try {
            const parsed = JSON.parse(text);
            const next = {};
            for (const k in root.records)
                next[k] = root.records[k];
            next[id] = parsed;
            root.records = next;
        } catch (e) {
            console.warn("AgentUsage: bad record for " + id + ": " + e);
        }
    }

    property Process updateProcess: Process {
        id: updateProcess
        command: ["omarchy-agent-usage-update"]
        onExited: root.rescan()
    }

    property Timer refreshTimer: Timer {
        id: refreshTimer
        interval: 60000
        repeat: true
        onTriggered: root.refreshNow()
    }

    property Timer clock: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    Component.onCompleted: {
        root.rescan();
        root.refreshNow();
    }
}
