pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../../../core"
import "../../../components"

// A tray item's own DBus menu, rendered with Celeste's styling instead of
// Quickshell's default popup (QsMenuAnchor via item.display(...)), so a
// tray-only app -- one with no window right now, like GlobalProtect or a
// minimized Teams -- gets the same border-attached panel every other bar row
// uses. The per-level rendering (and why submenus nest) lives in
// TrayMenuLevel.qml.
ColumnLayout {
    id: root

    required property string itemId

    // Resolve the tray item by id. Used for the header only; anything that
    // must be correct at the instant itemId changes calls itemForId()
    // directly instead -- see reloadRoot().
    readonly property var item: root.itemForId(root.itemId)

    readonly property string displayName: root.item ? String(root.item.tooltipTitle || root.item.title || root.item.id || "") : ""

    function itemForId(id) {
        const items = SystemTray.items ? SystemTray.items.values : [];
        for (const it of items)
            if (it && String(it.id) === id)
                return it;
        return null;
    }

    // Popout.qml's Loader only tears content down on open/close, and hovering
    // from one tray icon straight to the next never passes popoutName through
    // "" -- so this one object is reused across completely different apps and
    // has to re-point itself on itemId alone.
    //
    // It must NOT read root.item to do that. A derived binding is still stale
    // while the changed-handler of its own dependency runs: inside
    // onItemIdChanged, itemId is already the new item but root.item still
    // evaluates to the previous one (verified with an isolated qs probe).
    // Snapshotting root.item.menu here is what made every menu render one app
    // behind its header -- Remmina's icon showing Teams' menu and vice versa,
    // consistently, because the header is a live binding and the menu was a
    // stale snapshot. Recomputing the lookup from itemId sidesteps the whole
    // binding-order question.
    onItemIdChanged: root.reloadRoot()
    Component.onCompleted: root.reloadRoot()

    function reloadRoot() {
        root.maxMenuHeight = 0;
        rootLevel.setSource("");

        const item = root.itemForId(root.itemId);
        if (item && item.menu)
            rootLevel.setSource(Qt.resolvedUrl("TrayMenuLevel.qml"), {
                handle: item.menu,
                isRoot: true
            });
    }

    // The tallest this item's menu has been while open. Descending into a
    // shorter submenu would otherwise shrink the popout out from under a
    // stationary cursor, and Bar.qml's hover-leave-closes-popout logic would
    // close the whole thing mid-click -- reported as "I can't click into the
    // submenus, the panel closes". Reset per tray item, not per submenu.
    property real maxMenuHeight: 0

    function noteMenuHeight(h) {
        if (h > root.maxMenuHeight)
            root.maxMenuHeight = h;
    }

    spacing: Tokens.spacing.medium

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 320
        spacing: Tokens.spacing.medium

        IconImage {
            visible: root.item && root.item.icon
            implicitWidth: Tokens.font.icon.large.pointSize
            implicitHeight: Tokens.font.icon.large.pointSize
            source: root.item ? root.item.icon : ""
            asynchronous: true
        }

        MaterialIcon {
            visible: !root.item || !root.item.icon
            text: "apps"
            fontStyle: Tokens.font.icon.large
            color: Colours.palette.m3primary
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.displayName || "Tray item"
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.fontSize.large
            font.bold: true
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colours.palette.m3outlineVariant }

    Loader {
        id: rootLevel

        Layout.fillWidth: true

        onImplicitHeightChanged: root.noteMenuHeight(rootLevel.implicitHeight)
    }

    StyledText {
        visible: rootLevel.status !== Loader.Ready
        text: "No menu available"
        color: Colours.palette.m3outline
        font.pointSize: Tokens.fontSize.small
    }

    // Tops the popout up to maxMenuHeight -- see noteMenuHeight above.
    Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(0, root.maxMenuHeight - rootLevel.implicitHeight)
    }
}
