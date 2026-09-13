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

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    clip: true

    implicitWidth: root.groups.length > 0 ? row.implicitWidth + Tokens.padding.medium * 2 : 0
    implicitHeight: Tokens.sizes.bar.innerWidth
    visible: root.groups.length > 0

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

    RowLayout {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.medium
        spacing: root.gap

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
