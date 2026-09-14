pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../components"
import "../../services"

// Grows down from the main bar when PluginsBar.open is true (see
// services/PluginsBar.qml and modules/bar/components/Plugins.qml), listing
// one icon per enabled Omarchy plugin.
//
// Unlike the popouts in modules/bar/popouts/, this spans the full bar width
// flush against the border on both sides -- a continuation of the bar/
// border frame growing downward, not a floating dropdown -- so there is no
// width mismatch between this and the border to bridge, and no
// InvertedCorner fillets are needed the way Popout.qml's placements need
// them: the flush edges already line up exactly.
//
// The plugin list itself comes from services/PluginCatalog.qml as
// { id, name, iconPath } (see that file for why it's a from-scratch scan of
// Omarchy's own plugin/config files rather than something read off
// Bar.qml's root.pluginRegistry -- that object turned out to be scoped to
// Celeste's own manifest only). iconPath is a plugin's own
// <sourceDir>/icon.png when it ships one (checked in the codebase's actual
// installed plugins: most don't -- there is no icon field in the manifest
// schema at all, only an informal icon.png/preview.png convention a couple
// of plugins use), a fallback glyph otherwise -- Image.status naturally
// reports Error for a missing file, no existence check needed up front.
Item {
    id: root

    readonly property var pluginList: PluginCatalog.enabledList
    property bool open: false
    property int borderThickness: 0

    signal pluginActivated(string id)

    readonly property int stripHeight: Tokens.sizes.bar.innerWidth + Tokens.padding.medium * 2

    // Which icon the pointer is over, for the tooltip below -- name plus its
    // centre x in root's own coordinate space (not window-global like the
    // popouts' hoverChanged signals: the tooltip is positioned relative to
    // this Item, not anchored to a bar surface elsewhere).
    property string hoveredName: ""
    property real hoveredCentre: 0

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.borderThickness
    anchors.rightMargin: root.borderThickness

    implicitHeight: root.open ? root.stripHeight : 0
    height: root.implicitHeight
    visible: root.height > 0

    Behavior on height {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    // Only the row itself clips (for the grow-in animation, so a fixed-height
    // row does not just pop fully visible the instant height becomes
    // nonzero); the tooltip below is a sibling of this, NOT inside it, so it
    // can poke up above the strip into the gap under the bar without being
    // cut off by that same clip.
    Item {
        id: viewport
        anchors.fill: parent
        clip: true

        Rectangle {
            width: parent.width
            height: root.stripHeight
            anchors.top: parent.top
            color: Colours.tPalette.m3surface
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Config.border.rounding
            bottomRightRadius: Config.border.rounding

            RowLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                Repeater {
                    model: root.pluginList

                    delegate: Item {
                        id: entry

                        required property var modelData

                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Tokens.sizes.bar.innerWidth
                        implicitHeight: Tokens.sizes.bar.innerWidth

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.rounding.full
                            color: mouse.containsMouse ? Colours.palette.m3secondaryContainer : "transparent"

                            Behavior on color {
                                CAnim {}
                            }
                        }

                        // Shown as-is, not recoloured -- see
                        // modules/bar/components/Plugins.qml for why a
                        // MultiEffect colorization pass was tried and
                        // confirmed (via a deployed screenshot and an
                        // isolated probe, not guessed) not to work on this
                        // machine. Only a couple of installed plugins
                        // actually ship an icon.png at all, so this is a
                        // narrow, informal-convention code path, not the
                        // row's main appearance -- most entries show the
                        // theme-coloured "extension" glyph below instead.
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
                            anchors.fill: parent
                            visible: icon.status !== Image.Ready
                            text: "extension"
                            color: mouse.containsMouse ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pluginActivated(entry.modelData.id)
                            onEntered: {
                                root.hoveredName = entry.modelData.name;
                                root.hoveredCentre = entry.mapToItem(root, entry.width / 2, 0).x;
                            }
                            onExited: {
                                if (root.hoveredName === entry.modelData.name)
                                    root.hoveredName = "";
                            }
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.pluginList.length === 0
                    text: "No plugins enabled"
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    // The tooltip itself -- a single shared label rather than one per icon,
    // driven by hoveredName/hoveredCentre above, the same "one shared
    // overlay, many hover sources" shape StatusIcons/Tray/RunningApps
    // already use for their popouts. Sits just above the strip, in the gap
    // under the bar, which is only visible because it's a sibling of
    // `viewport` rather than a child of it -- see that Item's clip comment.
    StyledRect {
        id: tooltip

        readonly property bool shown: root.hoveredName !== ""

        y: -implicitHeight - Tokens.spacing.extraSmall
        x: Math.max(0, Math.min(root.hoveredCentre - implicitWidth / 2, root.width - implicitWidth))
        implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: label.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.medium
        color: Colours.palette.m3inverseSurface
        visible: opacity > 0
        opacity: tooltip.shown ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        StyledText {
            id: label
            anchors.centerIn: parent
            text: root.hoveredName
            color: Colours.palette.m3inverseOnSurface
        }
    }
}
