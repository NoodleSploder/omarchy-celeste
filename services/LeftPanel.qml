pragma Singleton

// State for the left-edge rail and the panels it opens.
//
// Mirror of services/SidePanel.qml on the other side of the screen, with the
// same per-monitor ownership: screenName IS the owner, so revealing the rail
// on another monitor closes the first as a side effect of the binding rather
// than needing an explicit close.
//
// The rail is a two-stage reveal. Hovering the border strip starts a dwell
// timer and only then shows the rail -- unlike the right edge's OSD, which
// appears immediately -- because this edge holds no live readout worth
// glancing at, so anything less than a deliberate rest of the pointer is
// almost certainly the user reaching for a window instead.

import QtQuick
import Quickshell.Hyprland

QtObject {
    id: root

    property bool hovered: false
    property bool railVisible: false
    property string screenName: ""

    // Which slideout is open: "" | "plugins" | "settings".
    property string panel: ""

    readonly property bool panelOpen: root.panel !== ""

    // How long the pointer must rest on the strip before the rail appears.
    readonly property int dwell: 1000

    function focusedScreenName() {
        const mon = Hyprland.focusedMonitor;
        return mon ? String(mon.name) : "";
    }

    function showRail(screenName) {
        const name = String(screenName || "") || root.focusedScreenName();
        if (name)
            root.screenName = name;
        root.railVisible = true;
        hideTimer.stop();
    }

    function setHovered(isHovered, screenName) {
        root.hovered = isHovered;
        if (isHovered)
            root.showRail(screenName);
        else
            root.scheduleHide();
    }

    // An open slideout pins the rail: the pointer has to leave the strip to
    // reach the panel's contents, and hiding it out from under them then
    // would make the panel unusable.
    function scheduleHide() {
        if (root.hovered || root.panelOpen)
            hideTimer.stop();
        else
            hideTimer.restart();
    }

    function openPanel(name, screenName) {
        const next = String(name || "");
        root.showRail(screenName);
        // Clicking the button of the panel already showing closes it, so each
        // rail icon toggles rather than only ever opening.
        root.panel = (root.panel === next) ? "" : next;
        root.scheduleHide();
    }

    function closePanel() {
        root.panel = "";
        root.scheduleHide();
    }

    function hideAll() {
        root.panel = "";
        root.railVisible = false;
        root.screenName = "";
    }

    property Timer hideTimer: Timer {
        interval: 1600
        onTriggered: {
            if (!root.hovered && !root.panelOpen)
                root.hideAll();
        }
    }
}
