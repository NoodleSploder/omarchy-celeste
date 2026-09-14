pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../../core"
import "../../../components"
import "../../../services"

// One icon per running application (grouped by window class), left of the
// status-icon pill. Hover previews that app's open-window list; clicking
// pins the same popout open -- identical wiring to StatusIcons, so both
// land in the same border-attached, downward-growing panel.
StyledRect {
    id: root

    readonly property var groups: Apps.groups
    readonly property int iconSize: Math.round(Tokens.sizes.bar.innerWidth * 0.55)

    // Emitted as the pointer moves across the row. `appClass` is the window
    // class under the cursor (empty when none), `centre` its x midpoint in
    // bar coordinates -- same shape as StatusIcons.hoverChanged.
    signal hoverChanged(string appClass, real centre)
    signal iconClicked(string appClass, real centre)

    readonly property int gap: Tokens.spacing.small

    // See the identical block in StatusIcons.qml -- both pills opt into the
    // same hover/click-to-expand behaviour, toggled independently from the
    // settings panel's Top Bar page (Config.bar.collapse).
    readonly property bool collapsible: Config.bar.collapse.runningApps === true
    readonly property bool expanded: !root.collapsible || hover.hovered

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    clip: true

    implicitWidth: root.groups.length === 0
        ? 0
        : root.collapsible
            ? (root.expanded ? row.implicitWidth + Tokens.padding.medium * 2 : root.implicitHeight)
            : row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: Tokens.sizes.bar.innerWidth
    visible: root.groups.length > 0

    Behavior on implicitWidth {
        enabled: root.collapsible
        Anim {
            type: Anim.FastSpatial
        }
    }

    function iconAt(point) {
        for (let i = 0; i < repeater.count; i++) {
            const icon = repeater.itemAt(i);
            if (!icon)
                continue;
            const local = root.mapToItem(icon, point.x, point.y);
            if (local.x >= 0 && local.x <= icon.width)
                return icon;
        }
        return null;
    }

    function updateHover() {
        if (!hover.hovered) {
            root.hoverChanged("", 0);
            return;
        }
        const icon = root.iconAt(hover.point.position);
        if (!icon) {
            root.hoverChanged("", 0);
            return;
        }
        root.hoverChanged(icon.appClass, icon.mapToItem(null, icon.width / 2, 0).x);
    }

    HoverHandler {
        id: hover

        onPointChanged: root.updateHover()
        onHoveredChanged: {
            if (!hovered)
                root.hoverChanged("", 0);
            else
                root.updateHover();
        }
    }

    TapHandler {
        onSingleTapped: {
            const icon = root.iconAt(hover.point.position);
            if (icon)
                root.iconClicked(icon.appClass, icon.mapToItem(null, icon.width / 2, 0).x);
        }
    }

    // The single glyph shown while collapsed -- "directions_run", the
    // literal running-figure Material Symbol.
    //
    // m3onSurface, not m3onSurfaceVariant: confirmed live (grim screenshot +
    // pixel sampling) that the glyph rendered but was nearly invisible at
    // normal size against this pill's background -- the exact same
    // low-contrast trap fixed on StatusIcons.qml's own collapsed glyph, see
    // its comment.
    MaterialIcon {
        anchors.centerIn: parent
        visible: root.collapsible && !root.expanded
        opacity: root.collapsible && !root.expanded ? 1 : 0
        text: "directions_run"
        color: Colours.palette.m3onSurface

        Behavior on opacity {
            CAnim {}
        }
    }

    RowLayout {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.medium
        spacing: root.gap
        // No Behavior here -- see the identical comment on StatusIcons.qml's
        // own row. An independently-timed opacity fade racing implicitWidth's
        // Anim.FastSpatial reproduced the exact "widened but blank" flicker
        // already documented and fixed for the side panel.
        opacity: root.expanded ? 1 : 0

        Repeater {
            id: repeater

            model: root.groups

            delegate: Item {
                id: icon

                required property var modelData
                readonly property string appClass: icon.modelData.appClass
                readonly property var windows: icon.modelData.windows
                readonly property string iconSource: Apps.iconSource(icon.appClass)
                readonly property bool active: {
                    const t = Hyprland.activeToplevel;
                    return !!(t && icon.windows.some(w => w.address === t.address));
                }

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize

                IconImage {
                    id: img
                    anchors.fill: parent
                    source: icon.iconSource
                    asynchronous: true
                    visible: icon.iconSource !== ""
                }

                MaterialIcon {
                    anchors.fill: parent
                    visible: icon.iconSource === ""
                    text: Apps.fallbackGlyph
                    color: Colours.palette.m3onSurfaceVariant
                }

                Rectangle {
                    visible: icon.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -Tokens.spacing.extraSmall
                    width: Tokens.spacing.extraSmall
                    height: width
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary
                }
            }
        }
    }
}
