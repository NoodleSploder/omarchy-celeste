pragma Singleton

// Shared state for the workspace overview, including the machinery that lets a
// window be dragged from one monitor's overview onto another's.
//
// QML drag-and-drop only reaches DropAreas inside the window the drag began in,
// and each monitor's overview is its own layer-shell surface. Rather than
// attempt a Wayland-level drag between surfaces, this exploits the implicit
// pointer grab: while a button is held, the originating surface keeps receiving
// motion events even after the cursor crosses onto another monitor -- just with
// out-of-bounds coordinates.
//
// So every workspace card registers its rectangle in GLOBAL layout coordinates,
// and the dragging surface hit-tests all of them itself. Every overview shares
// this singleton, so the card under the cursor highlights on its own monitor.

import QtQuick
import Quickshell

QtObject {
    id: root

    property bool open: false

    // workspaceId -> { x, y, width, height, monitor }
    property var cards: ({})

    // Drag state, in global layout coordinates.
    property bool dragging: false
    property var draggedToplevel: null
    property int draggedFromWorkspace: -1
    property real cursorX: 0
    property real cursorY: 0
    property real grabOffsetX: 0
    property real grabOffsetY: 0
    property real ghostWidth: 0
    property real ghostHeight: 0

    signal closeRequested()

    function registerCard(id, rect) {
        const next = {};
        for (const k in root.cards)
            next[k] = root.cards[k];
        next[String(id)] = rect;
        root.cards = next;
    }

    function unregisterCard(id) {
        const next = {};
        for (const k in root.cards)
            if (k !== String(id))
                next[k] = root.cards[k];
        root.cards = next;
    }

    function cardAt(x, y) {
        for (const k in root.cards) {
            const c = root.cards[k];
            if (x >= c.x && x < c.x + c.width && y >= c.y && y < c.y + c.height)
                return parseInt(k);
        }
        return -1;
    }

    readonly property int hoveredWorkspace: root.dragging ? root.cardAt(root.cursorX, root.cursorY) : -1

    // The ghost rectangle follows the cursor in global coordinates so each
    // surface can decide whether any of it falls on that monitor.
    readonly property real ghostX: root.cursorX - root.grabOffsetX
    readonly property real ghostY: root.cursorY - root.grabOffsetY

    function beginDrag(toplevel, fromWorkspace, offsetX, offsetY, w, h) {
        root.draggedToplevel = toplevel;
        root.draggedFromWorkspace = fromWorkspace;
        root.grabOffsetX = offsetX;
        root.grabOffsetY = offsetY;
        root.ghostWidth = w;
        root.ghostHeight = h;
        root.dragging = true;
    }

    function endDrag() {
        root.dragging = false;
        root.draggedToplevel = null;
        root.draggedFromWorkspace = -1;
    }

    function toggle() {
        root.open = !root.open;
    }

    function close() {
        root.open = false;
        root.endDrag();
    }
}
