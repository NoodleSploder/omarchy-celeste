pragma Singleton

// Right-edge drag-out panel state, ported from the local Caelestia backup's
// modules/drawers/ (Interactions.qml + osd/session Wrapper.qml) after the
// live install this session had been using as a reference disappeared
// mid-session -- restored from
// ~/Documents/omarchy.caelestia.backup/quickshell/caelestia.
//
// Caelestia's actual mechanic is simpler than "drag continuously follows the
// cursor": OSD auto-shows on any volume/brightness change (reactive
// Connections, not a keybind -- catches scroll, media keys, hardware
// buttons, anything that changes Audio/Brightness), and dragging past a
// fixed threshold flips a stage forward, which then animates open on its
// own -- ported from a single boolean in Caelestia's own version, widened
// here into two further steps (see `stage` below): session joins, then
// notifications joins (always at full height -- see
// modules/sidepanel/SidePanel.qml's notifsRowHeight).
//
// Notifications (Caelestia's third stage) ARE now implemented, via
// services/Notifs.qml. The original objection -- Omarchy's shell already
// runs the system NotificationServer, and a second one competing for that
// DBus name would risk breaking notification delivery machine-wide -- still
// stands and is still respected: Celeste runs no server. Omarchy persists
// every notification to disk as one JSON file, so Notifs.qml reads those
// directly. See that file's header for the full reasoning.

import QtQuick
import Quickshell.Hyprland

QtObject {
    id: root

    property bool osdVisible: false
    property bool hovered: false

    // Which monitor the panel belongs to right now. Celeste draws one
    // SidePanel per screen, all watching this one singleton, so without this
    // every monitor showed the panel simultaneously -- the volume/brightness
    // OSD, the session row and the notification drawer all appearing four
    // times over on a four-monitor desk.
    //
    // Caelestia genuinely does show its OSD on every screen (its own
    // osd/Wrapper.qml Connections fire in each per-screen instance), and
    // Celeste matched that deliberately at first -- see the note this
    // replaces in Bar.qml. Changed on explicit user request: it should follow
    // the active monitor only.
    //
    // Same ownership shape as Bar.qml's `calendarScreen`: the name IS the
    // owner, so showing it on another monitor reassigns the name, which
    // closes the first one as a side effect of the binding rather than
    // needing any explicit close.
    property string screenName: ""

    // The monitor the user is actually on, for the reactive path -- a volume
    // change has no screen of its own, so it follows focus.
    function focusedScreenName() {
        const mon = Hyprland.focusedMonitor;
        return mon ? String(mon.name) : "";
    }

    // Volume/brightness, the power row, and notifications are three
    // INDEPENDENT panels -- each its own plain `property bool`, not derived
    // from one shared number. Nothing here requires all three (or any
    // particular subset) to be open together; when more than one happens to
    // be open at once they render as one merged, "attached" card (see
    // modules/sidepanel/SidePanel.qml), and when only one is open it renders
    // as its own standalone card -- that fall-out is just how a RowLayout
    // sized from its VISIBLE children already behaves, not special-cased.
    //
    // Right now the ONLY thing that ever sets more than one of these is the
    // drag gesture below, which happens to coordinate all three in sequence
    // because a physical drag is one continuous gesture starting from the
    // sliders. That is a fact about today's one caller, not a constraint on
    // the properties themselves -- a future trigger (a bar icon, an IPC
    // call) can flip exactly one of these independently of the others, e.g.
    // `Notifs`-driven code calling `setNotifsVisible(true)` on its own.
    // Notifications is always full screen height whenever it's open at all
    // -- see modules/sidepanel/SidePanel.qml's notifsRowHeight -- so there is
    // no separate "expanded" tier to track here any more.
    property bool sessionVisible: false
    property bool notifsVisible: false

    function setSessionVisible(visible) { root.sessionVisible = !!visible; }
    function setNotifsVisible(visible) { root.notifsVisible = !!visible; }

    readonly property int dragThreshold: 60
    // How many threshold-widths of travel the drag gesture recognises:
    // 1 = session joins the sliders (taller middle pane), 2 = notifications
    // also joins, at the border-adjacent slot, full height. Purely the
    // drag's own bookkeeping now -- see the comment above `sessionVisible`
    // -- not a source of truth anything else reads.
    readonly property int maxStage: 2
    property int stage: 0

    // `screenName` is optional: hover passes the screen it happened on (the
    // pointer is the authority there, not focus), while the reactive
    // volume/brightness path passes nothing and falls back to the focused
    // monitor.
    function showOsd(screenName) {
        const name = String(screenName || "") || root.focusedScreenName();
        if (name)
            root.screenName = name;
        root.osdVisible = true;
        hideTimer.restart();
    }

    function beginDrag() {
        hideTimer.stop();
    }

    // dragX is cumulative horizontal movement since the press started,
    // negative = dragging left (pulling the panel further out). Converted to
    // a stage by distance: 60px out joins the session row to the sliders,
    // 120px out also joins notifications (at full height).
    //
    // The stage LATCHES -- it only ever moves forward within a gesture, and
    // dragging back toward the border does not retract it. The drag is the
    // trigger, not a live position binding: an earlier version reassigned
    // the stage on every mouse move in both directions, so holding the
    // cursor near a threshold flipped the panels on and off with every few
    // pixels of hand tremor, and each flip retargeted the 500ms open/close
    // animation mid-flight. That thrash is what read as the panel flickering
    // while it opened. Past the threshold it now just animates open and is
    // left alone; closing is the hide timer's job (cursor leaves the panel),
    // not the drag's.
    function updateDrag(dragX) {
        const steps = Math.max(0, Math.min(root.maxStage, Math.floor(-dragX / root.dragThreshold)));
        if (steps <= root.stage)
            return;
        root.stage = steps;
        root.setSessionVisible(steps >= 1);
        root.setNotifsVisible(steps >= 2);
    }

    // Lets the bar (or anything else) jump straight to the notification
    // drawer without the drag, e.g. clicking a notification count -- sets
    // only the notifications panel, leaving session/sliders wherever they
    // already were, which is exactly the point of these being independent.
    function showNotifs(screenName) {
        root.showOsd(screenName);
        root.setNotifsVisible(true);
        root.scheduleHide();
    }

    function endDrag() {
        root.scheduleHide();
    }

    // Called from the single hover-tracking HoverHandler that covers the
    // whole panel (hover zone + revealed content together) in
    // modules/sidepanel/SidePanel.qml. One handler covering the union area,
    // rather than every child MouseArea separately toggling this on
    // enter/exit, avoids the flicker of a spurious exit-then-enter when the
    // cursor crosses from one child into an adjacent one.
    function setHovered(isHovered, screenName) {
        root.hovered = isHovered;
        if (isHovered)
            root.showOsd(screenName);
        else
            root.scheduleHide();
    }

    function scheduleHide() {
        if (root.hovered)
            hideTimer.stop();
        else
            hideTimer.restart();
    }

    property Timer hideTimer: Timer {
        interval: 1600
        onTriggered: {
            if (!root.hovered) {
                root.osdVisible = false;
                root.stage = 0;
                root.setSessionVisible(false);
                root.setNotifsVisible(false);
                root.screenName = "";
            }
        }
    }

    property Connections audioWatch: Connections {
        target: Audio

        function onVolumeChanged() { root.showOsd(); }
        function onMutedChanged() { root.showOsd(); }
    }

    property Connections brightnessWatch: Connections {
        target: Brightness

        function onBrightnessChanged() { root.showOsd(); }
    }
}
