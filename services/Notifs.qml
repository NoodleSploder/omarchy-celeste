pragma Singleton

// Notifications for Celeste's side-panel drawer (stage 3 of the right-edge
// drag-out panel -- see modules/sidepanel/SidePanel.qml).
//
// WHY THIS READS FILES INSTEAD OF RUNNING A NotificationServer
//
// CLAUDE.md recorded this stage as deliberately skipped, with one open
// question: whether Quickshell's NotificationServer could run in a
// non-claiming/observer mode, because Omarchy's own shell already runs the
// system notification daemon (plugins/notifications/Service.qml) and a
// second server competing for org.freedesktop.Notifications would risk
// breaking notification delivery machine-wide.
//
// That question is now settled, and the answer is that it never needed
// asking: **Celeste does not need a server at all.** Omarchy's own service
// persists every notification to disk as one JSON file per notification --
// its own comment on historyDir is "This directory IS the history" -- so the
// data is readable directly, exactly the way services/AgentUsage.qml reads
// the agents plugin's usage records. No DBus name is claimed here, nothing
// competes with the real daemon, and Celeste sees precisely what Omarchy
// sees because it is the same bytes.
//
// Two other host surfaces were found while confirming this, and both were
// deliberately NOT used:
//
//  - `shell.firstPartyServiceFor("omarchy.notifications")`, which Omarchy
//    does hand to bar-capable plugins (shell.qml builds it for any manifest
//    with bar capabilities). It is a *narrow* proxy -- for notifications it
//    exposes only `doNotDisturb` + `setDoNotDisturb()`, no list and no
//    history -- so it cannot back this panel, and reaching it would mean
//    plumbing Bar.qml's `root.shell` into a singleton that has no access to
//    it. The DND state is read from notifications.json instead, which needs
//    no plumbing and stays correct even if that proxy is ever withdrawn.
//  - Omarchy's `IpcHandler { target: "notifications" }`, reachable as
//    `omarchy-shell notifications <fn>`. This IS used, but only for the
//    actions it actually owns (toggleDnd, clear, dismissAll) -- the same
//    "shell out to the same tool Omarchy uses rather than reimplementing
//    it" rule already followed for network/battery/bluetooth/agents.
//
// The one gap: there is no IPC for dismissing a SINGLE history entry (the
// handler's `dismiss(summary)` acts on on-screen toasts, not history). That
// one path removes the entry's own JSON file directly -- which is exactly
// what the entry is, per the service's own comment above -- and is the only
// place here that writes into Omarchy's state directory.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (root.home + "/.local/state")) + "/omarchy"

    // Paths mirror plugins/notifications/Service.qml exactly (read from that
    // file, not guessed). A notification lives in popupDir while its toast is
    // on screen and is MOVED into historyDir when it expires or is dismissed,
    // so a given notification is in exactly one of the two at any moment --
    // which is why both are scanned and merged into one list below.
    readonly property string popupDir: root.stateDir + "/notifications"
    readonly property string historyDir: root.popupDir + "/history"
    readonly property string settingsPath: root.stateDir + "/notifications.json"

    // Absolute paths of every record file found, and the parsed record for
    // each, keyed by that same path. Keying on the path (not the id) matters:
    // ids repeat across senders and across restarts, whereas Omarchy names
    // each file "<timestamp>-<id>.json", which is unique.
    property var recordPaths: []
    property var records: ({})

    property bool dnd: false

    // Bumped on a timer so "3m ago" labels re-render without every row
    // needing its own clock.
    property double nowMs: Date.now()

    // Newest first. A record with no usable timestamp sorts last rather than
    // being dropped -- a notification with a malformed field is still a
    // notification the user wants to see.
    readonly property var entries: {
        const out = [];
        for (const path of root.recordPaths) {
            const rec = root.records[path];
            if (rec)
                out.push(rec);
        }
        out.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
        return out;
    }

    readonly property int count: root.entries.length

    // ------------------------------------------------------------- actions

    // Omarchy owns DND; toggling it through its own IPC keeps the indicators
    // plugin and anything else watching that state in step, which writing
    // notifications.json directly would not.
    function toggleDnd() {
        Quickshell.execDetached(["omarchy-shell", "-q", "notifications", "toggleDnd"]);
    }

    // `clear` forgets the history; `dismissAll` takes the live toasts off the
    // screen. The panel lists both families, so clearing it means both --
    // otherwise a toast still on screen would reappear in the list the moment
    // it expired into history.
    function clearAll() {
        Quickshell.execDetached(["omarchy-shell", "-q", "notifications", "clear"]);
        Quickshell.execDetached(["omarchy-shell", "-q", "notifications", "dismissAll"]);
        // Don't wait for the filesystem watcher: drop the rows now so the
        // panel empties on the click rather than a beat later.
        root.recordPaths = [];
        root.records = ({});
        rescanTimer.restart();
    }

    // No IPC exists for removing one history entry (see the header). The file
    // IS the entry, so deleting it is the whole operation.
    function dismiss(entry) {
        if (!entry || !entry._path)
            return;
        Quickshell.execDetached(["rm", "-f", String(entry._path)]);
        const nextPaths = root.recordPaths.filter(p => p !== entry._path);
        const nextRecords = ({});
        for (const k in root.records)
            if (k !== entry._path)
                nextRecords[k] = root.records[k];
        root.recordPaths = nextPaths;
        root.records = nextRecords;
    }

    // Omarchy persists each notification's default action as execArgv (a
    // JSON-encoded argv array) precisely so a restored/replayed entry stays
    // clickable -- see persistablePopup() in its Service.qml.
    function hasAction(entry) {
        return !!(entry && entry.execArgv && root.parseArgv(entry.execArgv).length > 0);
    }

    function invoke(entry) {
        const argv = root.parseArgv(entry && entry.execArgv);
        if (argv.length === 0)
            return;
        Quickshell.execDetached(argv);
        root.dismiss(entry);
    }

    function parseArgv(raw) {
        if (!raw)
            return [];
        try {
            const parsed = JSON.parse(String(raw));
            return Array.isArray(parsed) ? parsed.map(String).filter(s => s.length > 0) : [];
        } catch (e) {
            return [];
        }
    }

    // ----------------------------------------------------------- formatting

    // Urgency is the numeric freedesktop scale in the persisted record
    // (0 low / 1 normal / 2 critical), not the string form Caelestia uses.
    function isCritical(entry) {
        return !!entry && Number(entry.urgency) === 2;
    }

    function appName(entry) {
        if (!entry)
            return "";
        const app = String(entry.app || "").trim();
        return app.length > 0 ? app : "Notification";
    }

    function timeAgo(entry) {
        const ts = entry ? Number(entry.timestamp) : 0;
        if (!ts)
            return "";
        const diff = Math.max(0, root.nowMs - ts);
        const mins = Math.floor(diff / 60000);
        if (mins < 1)
            return "now";
        if (mins < 60)
            return mins + "m";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return hours + "h";
        return Math.floor(hours / 24) + "d";
    }

    // Omarchy copies the sender's image next to the record because the
    // original does not outlive the notification. Empty is the common case.
    function imageSource(entry) {
        const img = entry ? String(entry.image || "") : "";
        if (!img)
            return "";
        return img.indexOf("/") === 0 ? "file://" + img : img;
    }

    // -------------------------------------------------------------- scanning

    function rescan() {
        if (!listProcess.running)
            listProcess.running = true;
    }

    // maxdepth 2 covers popupDir (live toasts) and popupDir/history in one
    // pass, since historyDir is nested inside it. `-printf %p` gives absolute
    // paths, which are the keys everything else here is built on.
    property Process listProcess: Process {
        id: listProcess
        command: ["find", root.popupDir, "-maxdepth", "2", "-name", "*.json", "-printf", "%p\\n"]
        stdout: StdioCollector {
            id: listStdout
            waitForEnd: true
            onStreamFinished: {
                const paths = [];
                for (const line of listStdout.text.split("\n")) {
                    const p = line.trim();
                    if (p.slice(-5) === ".json")
                        paths.push(p);
                }
                paths.sort();
                root.recordPaths = paths;

                // Forget records whose file is gone, so a cleared history
                // doesn't leave stale rows behind in `entries`.
                const keep = ({});
                for (const p of paths)
                    if (root.records[p])
                        keep[p] = root.records[p];
                root.records = keep;
            }
        }
    }

    property Instantiator readers: Instantiator {
        model: root.recordPaths

        delegate: FileView {
            id: view

            required property string modelData

            path: view.modelData
            printErrors: false
            watchChanges: true

            onLoaded: root.applyRecord(view.modelData, view.text())
            onFileChanged: reload()
        }
    }

    function applyRecord(path, text) {
        try {
            const parsed = JSON.parse(text);
            // Stamp the source path onto the record so a row can dismiss
            // itself without the list having to carry a parallel index.
            parsed._path = path;
            const next = {};
            for (const k in root.records)
                next[k] = root.records[k];
            next[path] = parsed;
            root.records = next;
        } catch (e) {
            // A record being written right now can be caught mid-flush; the
            // watcher will fire again when it completes, so this is expected
            // and not worth warning about.
        }
    }

    // DND lives in its own settings file, hydrated by Omarchy on startup and
    // written back on every change -- watching it means the panel's toggle
    // reflects changes made anywhere else (the indicators plugin, the
    // omarchy-toggle-notification-silencing CLI, a keybind) and not just its
    // own clicks.
    property FileView settingsFile: FileView {
        id: settingsFile
        path: root.settingsPath
        printErrors: false
        watchChanges: true
        onLoaded: {
            try {
                root.dnd = !!JSON.parse(settingsFile.text()).dnd;
            } catch (e) {
                root.dnd = false;
            }
        }
        onFileChanged: reload()
    }

    // Event-driven rather than polled: new notifications must appear without
    // the panel being open (the bar badge counts them), and a poll fast
    // enough to feel live would run forever for nothing most of the time.
    // inotifywait is the same tool Omarchy's own PluginRegistry uses to watch
    // its plugins directory, so it is a dependency this shell already has.
    property Process watcher: Process {
        running: true
        command: ["inotifywait", "-m", "-r", "-q", "-e", "close_write,create,delete,move",
            "--format", "%w%f", root.popupDir]
        stdout: SplitParser {
            // Debounced: moving a toast into history is a delete plus a
            // create, and a burst of notifications would otherwise re-run
            // `find` once per file.
            onRead: rescanTimer.restart()
        }
    }

    property Timer rescanTimer: Timer {
        id: rescanTimer
        interval: 150
        onTriggered: root.rescan()
    }

    property Timer clock: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    Component.onCompleted: root.rescan()
}
