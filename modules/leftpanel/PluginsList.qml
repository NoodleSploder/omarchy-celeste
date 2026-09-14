pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../components"
import "../../services"

// The enabled plugins as a vertical list, for the left slideout.
//
// Same data and the same icon rules as modules/bar/PluginsStrip.qml -- that
// one is a horizontal row of bare icons under the bar, this is a named list
// in a side panel, so the layout differs but neither is the other's
// container. Icons are shown unrecoloured for the reason PluginsStrip and
// modules/bar/components/Plugins.qml both document at length: MultiEffect
// colorization renders solid black on this machine, confirmed by probe
// rather than assumed, so a plugin's own icon.png is drawn as shipped and
// everything else falls back to the theme-coloured "extension" glyph.
Item {
    id: root

    signal activated(string id)

    readonly property var pluginList: PluginCatalog.enabledList

    implicitWidth: 320
    implicitHeight: 420

    StyledText {
        id: title

        anchors.left: parent.left
        anchors.top: parent.top
        text: "Plugins"
        font: Tokens.font.body.large
        color: Colours.palette.m3onSurface
    }

    Rectangle {
        id: rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.topMargin: Tokens.padding.small
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.pluginList.length === 0
        text: "No plugins enabled"
        color: Colours.palette.m3outline
    }

    ListView {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.topMargin: Tokens.padding.small
        anchors.bottom: parent.bottom

        clip: true
        spacing: Tokens.spacing.small
        model: root.pluginList
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entry

            required property var modelData

            width: ListView.view ? ListView.view.width : 0
            implicitHeight: Tokens.sizes.bar.innerWidth + Tokens.padding.small * 2
            radius: Tokens.rounding.large
            color: entryArea.containsMouse ? Colours.palette.m3secondaryContainer : "transparent"

            Behavior on color {
                CAnim {}
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.medium

                Item {
                    Layout.preferredWidth: Tokens.sizes.bar.innerWidth
                    Layout.preferredHeight: Tokens.sizes.bar.innerWidth

                    Image {
                        id: icon

                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.small
                        source: entry.modelData.iconPath
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        visible: icon.status === Image.Ready
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: icon.status !== Image.Ready
                        text: "extension"
                        color: entryArea.containsMouse
                            ? Colours.palette.m3onSecondaryContainer
                            : Colours.palette.m3onSurfaceVariant
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: entry.modelData.name || entry.modelData.id
                    font: Tokens.font.body.normal
                    color: entryArea.containsMouse
                        ? Colours.palette.m3onSecondaryContainer
                        : Colours.palette.m3onSurface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            MouseArea {
                id: entryArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated(entry.modelData.id)
            }
        }
    }
}
