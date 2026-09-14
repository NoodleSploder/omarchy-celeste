pragma Singleton

// Running applications, grouped by window class, for the bar's running-apps
// row and its per-app window-list popout.
//
// No reference implementation for this exists in either Omarchy's own shell
// or the Caelestia install this repo takes its design cues from -- both only
// ever show the single *focused* window (see modules/bar/components/
// ActiveWindow.qml). This groups every mapped toplevel across every monitor
// and workspace by class instead, which is what a taskbar-style icon row
// needs.

import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    readonly property var toplevels: Hyprland.toplevels ? Hyprland.toplevels.values : []

    function _ignored(t) {
        const ipc = t && t.lastIpcObject;
        return !ipc || !ipc.class || ipc.mapped === false;
    }

    // [{ appClass, windows: [HyprlandToplevel, ...] }], insertion-ordered by
    // first appearance so the row doesn't reshuffle as windows come and go.
    readonly property var groups: {
        const order = [];
        const byClass = {};
        for (const t of root.toplevels) {
            if (root._ignored(t))
                continue;
            const cls = String(t.lastIpcObject.class);
            if (!byClass[cls]) {
                byClass[cls] = [];
                order.push(cls);
            }
            byClass[cls].push(t);
        }
        return order.map(cls => ({ appClass: cls, windows: byClass[cls] }));
    }

    function groupFor(appClass) {
        for (const g of root.groups)
            if (g.appClass === appClass)
                return g;
        return null;
    }

    function windowTitle(t) {
        return String((t && t.lastIpcObject && t.lastIpcObject.title) || "");
    }

    function workspaceName(t) {
        return String((t && t.workspace && t.workspace.name) || "");
    }

    // Material Symbol used only when no themed app icon resolves at all.
    readonly property string fallbackGlyph: "select_window"

    function iconSource(appClass) {
        const entry = DesktopEntries.heuristicLookup(appClass);
        const icon = entry ? entry.icon : "";
        return icon ? Quickshell.iconPath(icon, "") : "";
    }

    // Quickshell reports a toplevel's address as bare hex ("55794ad07a20"),
    // while every Hyprland dispatcher expects the 0x-prefixed form. Sending
    // the bare one is not an error you can see: the dispatch returns a
    // "window not found" warning to the caller's stderr and the click simply
    // does nothing. Confirmed by dispatching both forms by hand -- bare
    // warned and changed nothing, prefixed switched workspace and focused the
    // window.
    function hyprAddress(t) {
        const raw = t && t.address ? String(t.address) : "";
        if (raw === "")
            return "";
        return raw.indexOf("0x") === 0 ? raw : "0x" + raw;
    }

    function focus(t) {
        const address = root.hyprAddress(t);
        if (address === "")
            return;
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ window = "address:${address}" })`
            : `focuswindow address:${address}`);
    }

    function close(t) {
        const address = root.hyprAddress(t);
        if (address === "")
            return;
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.window.close({ window = "address:${address}" })`
            : `closewindow address:${address}`);
    }
}
