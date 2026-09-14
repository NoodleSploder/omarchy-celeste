pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components"

// Contents of the Celeste settings panel. Deliberately just the title for
// now -- the panel, its state singleton and all the Bar.qml wiring exist so
// that actual settings can be added in here without touching any of that
// again.
//
// An Item root with hand-set implicit sizes, not a Layout: MenuPanel sizes
// itself from this item's implicitWidth/implicitHeight, and a Layout root
// silently recomputes its own implicitWidth from its children on every
// relayout (documented at length in CLAUDE.md), which would throw away a
// fixed panel width the moment the panel has real content in it.
Item {
    id: root

    // Matches the launcher's width so Celeste's two bottom-border panels
    // share a footprint rather than each picking their own.
    implicitWidth: Tokens.sizes.launcher.itemWidth
    implicitHeight: title.implicitHeight

    StyledText {
        id: title

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "Celeste Settings"
        font: Tokens.font.body.large
        color: Colours.palette.m3onSurface
    }
}
