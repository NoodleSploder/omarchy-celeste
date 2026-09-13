pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../../../core"
import "../../../components"

// StatusNotifierItem tray icons.
//
// Hover previews the item's menu in the same border-attached popout every
// other bar row uses; clicking pins it open. A tray-only app (running but
// with no window right now -- GlobalProtect, Teams minimized, etc.) has no
// window list the way modules/bar/components/RunningApps.qml can show, so
// this is "the same popout treatment, but its content is whatever the app's
// own tray menu offers" rather than a window list. An item with no menu at
// all (rare) falls back to activate() directly on click, same as before.
StyledRect {
    id: root

    readonly property var items: SystemTray.items ? SystemTray.items.values : []
    readonly property int iconSize: Math.round(Tokens.sizes.bar.innerWidth * 0.5)

    // Emitted as the pointer moves across the row. `itemId` is the tray
    // item's id under the cursor (empty when none, or when it has no menu to
    // show), `centre` its x midpoint in bar coordinates -- same shape as
    // StatusIcons.hoverChanged / RunningApps.hoverChanged.
    signal hoverChanged(string itemId, real centre)
    signal iconClicked(string itemId, real centre)

    color: Config.bar.tray.background
        ? Colours.tPalette.m3surfaceContainer
        : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)
    radius: Tokens.rounding.full

    implicitWidth: root.items.length > 0 ? row.implicitWidth + Tokens.padding.small * 2 : 0
    implicitHeight: Tokens.sizes.bar.innerWidth
    visible: root.items.length > 0

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
        if (!icon || !icon.hasMenu) {
            root.hoverChanged("", 0);
            return;
        }
        root.hoverChanged(icon.itemId, icon.mapToItem(null, icon.width / 2, 0).x);
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

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Repeater {
            id: repeater

            model: root.items

            delegate: Item {
                id: entry

                required property var modelData
                readonly property bool recolour: Config.bar.tray.recolour
                readonly property string itemId: String(entry.modelData ? entry.modelData.id : "")
                readonly property bool hasMenu: !!(entry.modelData && entry.modelData.menu)

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize

                IconImage {
                    id: image

                    anchors.fill: parent
                    source: entry.modelData ? entry.modelData.icon : ""
                    asynchronous: true
                    // Hidden when recolouring: MultiEffect draws it instead.
                    visible: !entry.recolour
                    layer.enabled: entry.recolour
                }

                MultiEffect {
                    anchors.fill: parent
                    source: image
                    visible: entry.recolour
                    colorization: 1
                    colorizationColor: Colours.palette.m3onSurfaceVariant
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const item = entry.modelData;
                        if (!item)
                            return;
                        if (entry.hasMenu)
                            root.iconClicked(entry.itemId, entry.mapToItem(null, entry.width / 2, 0).x);
                        else
                            item.activate();
                    }
                }
            }
        }
    }
}
