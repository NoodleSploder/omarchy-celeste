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
// Left click activates the item (or opens its menu if it only has one); right
// click always opens the menu. Tray icons are app-provided images rather than
// glyphs, so bar.tray.recolour flattens them to a single palette colour for a
// uniform bar, at the cost of losing multi-colour app icons.
StyledRect {
    id: root

    readonly property var items: SystemTray.items ? SystemTray.items.values : []
    readonly property int iconSize: Math.round(Tokens.sizes.bar.innerWidth * 0.5)

    color: Config.bar.tray.background
        ? Colours.tPalette.m3surfaceContainer
        : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)
    radius: Tokens.rounding.full

    implicitWidth: root.items.length > 0 ? row.implicitWidth + Tokens.padding.small * 2 : 0
    implicitHeight: Tokens.sizes.bar.innerWidth
    visible: root.items.length > 0

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: root.items

            delegate: Item {
                id: entry

                required property var modelData
                readonly property bool recolour: Config.bar.tray.recolour

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
                        if (mouse.button === Qt.RightButton || item.onlyMenu)
                            item.display(entry, entry.width / 2, entry.height);
                        else
                            item.activate();
                    }
                }
            }
        }
    }
}
