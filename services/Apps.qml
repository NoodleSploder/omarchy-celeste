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

    function focus(t) {
        if (!t || !t.address)
            return;
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ window = "address:${t.address}" })`
            : `focuswindow address:${t.address}`);
    }

    function close(t) {
        if (!t || !t.address)
            return;
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.window.close({ window = "address:${t.address}" })`
            : `closewindow address:${t.address}`);
    }
}
