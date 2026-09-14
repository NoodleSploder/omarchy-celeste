pragma Singleton

// Celeste's configuration tree: built-in defaults deep-merged with the user's
// JSON file.
//
// Primary path is ~/.config/celeste/shell.json. If that does not exist, an
// existing ~/.config/caelestia/shell.json is read instead, so a machine
// migrating from Caelestia keeps its settings without an extra step.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string primaryPath: home + "/.config/celeste/shell.json"
    readonly property string legacyPath: home + "/.config/caelestia/shell.json"

    // Which file actually supplied the loaded values; surfaced for diagnostics.
    property string loadedFrom: ""

    // 12h vs 24h follows the locale unless the user overrides it.
    readonly property bool localeIsTwelveHour:
        Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("a") !== -1

    readonly property var defaults: ({
        appearance: {
            transparency: { enabled: false, base: 0.78, layers: 0.58 },
            // Caelestia's faces. GoogleSansFlex is its upstream default but is
            // not packaged on Arch; Rubik is the face it uses for the clock and
            // workspaces and is a close match for the rest.
            font: {
                sans: "Rubik",
                mono: "CaskaydiaCove NF",
                material: "Material Symbols Rounded"
            }
        },
        border: { thickness: 10, minThickness: 4, rounding: 25, enabled: true },
        bar: {
            persistent: true,
            showOnHover: true,
            excludedScreens: [],
            activeWindow: { compact: false, inverted: false, showOnHover: true },
            // Clicking the clock opens this plugin's panel. It is hosted
            // invisibly as an anchor, so it needs no entry in the bar.
            // Omarchy's calendar popup belongs to omarchy.clock -- its widget is
            // "the date/time label for the bar, and the host for the calendar
            // popup". tmn73.calendar is a separate third-party plugin that looks
            // similar; point calendarWidget at it instead if that is wanted.
            clock: { background: false, showDate: true, showIcon: true, calendarWidget: "" },
            // Extra plugins to keep live purely so their panels can be opened.
            anchorWidgets: [],
            // Clicking a status icon opens the matching Omarchy plugin's own
            // panel, which is far richer than anything Celeste reimplements: a
            // full mixer, the network list, the device list. Each is hosted
            // invisibly as an anchor. Set an entry to "" to fall back to
            // Celeste's built-in hover popout only.
            //
            // Declared here but Bar.qml's statusIconsComponent never actually
            // reads this map -- audio/microphone/network/bluetooth/battery
            // (and now agents too, see CLAUDE.md's "AI usage icon" entry) all
            // got full Celeste-native popout reimplementations instead, so
            // this is dormant, kept only so a future pass can switch one over
            // deliberately -- see roadmap item 2.
            statusIconPanels: {
                audio: "omarchy.audio",
                microphone: "omarchy.audio",
                network: "omarchy.network",
                bluetooth: "omarchy.bluetooth",
                battery: "omarchy.power"
            },
            tray: { background: false, compact: false, recolour: false },
            popouts: { tray: true, statusIcons: true, activeWindow: true },
            scrollActions: { workspaces: true, volume: true, brightness: true },
            workspaces: {
                shown: 5,
                activeIndicator: true,
                activeTrail: false,
                occupiedBg: false,
                perMonitorWorkspaces: true,
                showWindows: false,
                showWindowsOnSpecialWorkspaces: false
            },
            // workspaces + clock sit together between the two spacers so
            // they're the group centred in the bar (matches Caelestia's own
            // default shell.json, which centres workspaces/clock/media/
            // resources as a group and keeps activeWindow on the far left,
            // beside the logo) -- an earlier pass here had activeWindow
            // between the spacers instead, which put the workspace selector
            // off to the left next to the logo instead of centred.
            entries: [
                { id: "logo", enabled: true },
                { id: "activeWindow", enabled: true },
                { id: "spacer", enabled: true },
                { id: "workspaces", enabled: true },
                { id: "clock", enabled: true },
                { id: "spacer", enabled: true },
                { id: "plugins", enabled: true },
                { id: "tray", enabled: true },
                { id: "runningApps", enabled: true },
                { id: "statusIcons", enabled: true },
                { id: "power", enabled: true }
            ],
            // How the three sections of the bar are sized. Which entries fall
            // in which section is still `entries` above: the two "spacer"
            // entries are the section boundaries (before the first = left,
            // between = middle, after the second = right), so there is one
            // source of truth for order and no migration for existing configs.
            //
            // Positioning is independent of sizing and never configurable:
            // left is anchored left, right anchored right, middle anchored to
            // the screen centre. That is what stops a long window title in the
            // left section from shoving the centred group off-centre, which is
            // the whole reason this exists.
            //
            // mode "percent": each width is a percentage of the usable bar.
            // mode "fixed":   each width is in pixels, except the string
            //                 "remaining", which splits whatever the fixed
            //                 sections leave over between the sections asking
            //                 for it.
            sections: {
                mode: "percent",
                percent: { left: 33, middle: 34, right: 33 },
                fixed: { left: 250, middle: "remaining", right: 250 }
            },
            statusIcons: [
                // Two independent entries, not one shared "lockStatus" slot:
                // caps and num lock can both be on at once, and a single
                // slot could only ever show one of them (whichever the
                // ternary preferred) -- see StatusIcons.qml's collapsed()/
                // text logic.
                { id: "capsLock", enabled: true },
                { id: "numLock", enabled: true },
                { id: "audio", enabled: true },
                { id: "microphone", enabled: true },
                // Claude Code / Codex / Fireworks usage -- see
                // modules/bar/popouts/AgentsPopout.qml and
                // services/AgentUsage.qml. Got a full Celeste-native popout
                // like audio/network/etc.: an earlier pass hosted
                // omarchy.agents' own real panel as an anchor instead, which
                // worked for data but not looks (that panel's border/corners
                // come from a shared Omarchy Ui component this repo cannot
                // restyle without changing it for every Omarchy panel on the
                // system) -- see CLAUDE.md's "AI usage icon" entry.
                { id: "agents", enabled: true },
                { id: "kbLayout", enabled: false },
                { id: "network", enabled: true },
                { id: "bluetooth", enabled: true },
                { id: "battery", enabled: true }
            ]
        },
        dashboard: { enabled: true, showOnHover: false, dragThreshold: 30, mediaUpdateInterval: 500 },
        sidebar: { dragThreshold: 50 },
        clockPanel: { weekStartDay: null, birthYear: 0, lifeExpectancy: 0 },
        services: { useTwelveHourClock: root.localeIsTwelveHour, defaultPlayer: "", brightnessIncrement: 0.1 }
    })

    property var user: ({})

    // Objects merge recursively; arrays replace wholesale. An `entries` override
    // is therefore a complete replacement, not an element-wise patch -- which is
    // what a user reordering their bar expects.
    function merge(base, over) {
        if (over === undefined || over === null)
            return base;
        if (Array.isArray(base) || Array.isArray(over))
            return over;
        if (typeof base !== "object" || typeof over !== "object")
            return over;
        const out = {};
        for (const k in base)
            out[k] = base[k];
        for (const k in over)
            out[k] = (k in base) ? merge(base[k], over[k]) : over[k];
        return out;
    }

    readonly property var effective: merge(defaults, user)

    readonly property var appearance: effective.appearance
    readonly property var border: effective.border
    readonly property var bar: effective.bar
    readonly property var dashboard: effective.dashboard
    readonly property var sidebar: effective.sidebar
    readonly property var services: effective.services

    // Settings for the ported Omarchy calendar panel. Omarchy stores these on
    // the bar entry; Celeste keeps them in its own config file.
    readonly property var clockPanel: effective.clockPanel

    function writeClockPanel(values) {
        const next = {};
        for (const k in root.user)
            next[k] = root.user[k];
        next.clockPanel = values;
        root.user = next;
        writer.setText(JSON.stringify(next, null, 2));
    }

    // Persists the bar's section sizing (the settings panel's Top Bar page).
    //
    // Only bar.sections is touched: anything else the user has under `bar` --
    // notably their own `entries` order -- is copied through untouched, since
    // this writes the whole user object back and a shallow overwrite of `bar`
    // would silently discard the rest of it.
    function writeBarSections(values) {
        const next = {};
        for (const k in root.user)
            next[k] = root.user[k];
        const bar = {};
        for (const k in (root.user.bar || ({})))
            bar[k] = root.user.bar[k];
        bar.sections = values;
        next.bar = bar;
        root.user = next;
        writer.setText(JSON.stringify(next, null, 2));
    }

    property FileView writer: FileView {
        path: root.primaryPath
        printErrors: false
        atomicWrites: true
    }

    function _apply(text, path) {
        try {
            root.user = JSON.parse(text) || ({});
            root.loadedFrom = path;
        } catch (e) {
            console.warn("celeste: ignoring unparseable config " + path + ": " + e);
            root.user = ({});
        }
    }

    property FileView primary: FileView {
        path: root.primaryPath
        watchChanges: true
        // Absence is a normal, handled state, not an error worth logging.
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._apply(text(), root.primaryPath)
        // No primary config: fall back to a Caelestia file if one is present.
        onLoadFailed: legacy.reload()
    }

    property FileView legacy: FileView {
        path: root.legacyPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (root.loadedFrom !== root.primaryPath)
                root._apply(text(), root.legacyPath);
        }
        onLoadFailed: {
            if (root.loadedFrom === "")
                root.user = ({});
        }
    }
}
