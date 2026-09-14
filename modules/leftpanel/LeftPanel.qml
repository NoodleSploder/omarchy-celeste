pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../components"
import "../../services"
import "../settings" as SettingsModule

// The left edge: a hover strip, a two-icon rail, and the panels those icons
// slide out.
//
// Geometrically this is the mirror of modules/sidepanel/SidePanel.qml, and it
// reuses that file's hard-won rules rather than rediscovering them:
//
//  - The hover strip is exactly the width of the screen border and no wider.
//    The border is compositor-reserved (Bar.qml's exclusion windows claim it),
//    so hovering there costs no app area; anything wider eats clicks in
//    whatever window is underneath.
//  - Everything is sized and positioned against the band between the bar and
//    the bottom border, never the raw screen, so nothing ever covers the bar.
//  - Cards are flush-square on the border edge and rounded on the free side,
//    with concave fillets bridging into the border above and below.
//
// The one deliberate difference is the dwell: the right edge reveals its OSD
// the moment you touch the strip because it is showing you a live value,
// while this edge only holds buttons, so it waits for the pointer to settle
// (LeftPanel.dwell) before appearing.
Item {
    id: root

    required property var screen
    property int borderThickness: 0
    property int topInset: 0

    readonly property string screenName: root.screen ? String(root.screen.name) : ""

    readonly property bool mine: LeftPanel.screenName === root.screenName
    readonly property bool railOpen: LeftPanel.railVisible && root.mine
    readonly property string panel: root.mine ? LeftPanel.panel : ""

    readonly property real screenHeight: root.parent ? root.parent.height : (root.screen ? root.screen.height : 900)
    readonly property real usableHeight: Math.max(0, root.screenHeight - root.topInset - root.borderThickness)

    // Matches the right edge's slider stack exactly, per the request that the
    // two hover targets be the same height.
    readonly property real stripHeight:
        Tokens.sizes.osd.sliderHeight * 2 + Tokens.spacing.medium + Tokens.padding.large * 2

    // Was 0.9 of the session button; these sit in a narrow rail rather than a
    // power menu and only needed to be tappable, not prominent.
    readonly property real buttonSize: Tokens.sizes.session.button * 0.65

    anchors.left: parent.left

    // Centred in the usable band rather than the screen: anchoring to the
    // screen's centre would split the reserved space evenly top and bottom
    // and let a tall panel ride up over the bar.
    y: root.topInset + (root.usableHeight - root.height) / 2

    // Covers the hover strip plus whatever is currently revealed. Bar.qml's
    // Region gates pointer input to exactly this geometry, and it must not
    // claim more than the strip while closed -- reveal.width is the LIVE
    // animated width, not the implicit target, so a shut panel does not sit
    // on a slab of the screen edge.
    implicitWidth: Math.max(hoverZone.implicitWidth, rail.width + slideout.width + detail.width + root.borderThickness)
    implicitHeight: Math.max(hoverZone.implicitHeight, Math.max(rail.height, Math.max(slideout.height, detail.height)))
    width: implicitWidth
    height: implicitHeight

    HoverHandler {
        id: hoverHandler

        target: root
        // The pointer is the authority for a hover, not the focused window:
        // brushing the left edge of a monitor you have not clicked into yet
        // should still open it there.
        onHoveredChanged: {
            if (hoverHandler.hovered)
                dwellTimer.restart();
            else {
                dwellTimer.stop();
                LeftPanel.setHovered(false, root.screenName);
            }
        }
    }

    // The rail only appears once the pointer has genuinely settled. Without
    // this, crossing the edge on the way to a window would flash it open.
    Timer {
        id: dwellTimer

        interval: LeftPanel.dwell
        onTriggered: LeftPanel.setHovered(true, root.screenName)
    }

    // Always-present hit target, exactly the border's width.
    Item {
        id: hoverZone

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Math.max(root.borderThickness, Config.border.minThickness)
        implicitHeight: root.stripHeight
    }

    // ---------------------------------------------------------------- rail

    Item {
        id: rail

        anchors.left: parent.left
        anchors.leftMargin: root.borderThickness
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: root.buttonSize + Tokens.padding.large * 2
        implicitHeight: railColumn.implicitHeight + Tokens.padding.large * 2

        width: root.railOpen ? implicitWidth : 0
        height: implicitHeight
        visible: width > 0
        clip: true

        Behavior on width {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.tPalette.m3surface
            // Square against the border, and square on the right too once a
            // slideout is open: the two then read as one continuous stepped
            // card rather than a pill with a slab bolted to it.
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: root.panel !== "" ? 0 : Tokens.rounding.extraLarge
            bottomRightRadius: root.panel !== "" ? 0 : Tokens.rounding.extraLarge
        }

        // Pinned to the border edge so the buttons stay put while the card
        // animates open, rather than sliding in from the middle.
        ColumnLayout {
            id: railColumn

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.large
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.medium

            // A glyph, not assets/plugin.png. That asset is a fixed-colour
            // bitmap and cannot follow the theme -- the MultiEffect
            // colorization pass that would recolour it renders solid black on
            // this machine (confirmed by probe, see PluginsList.qml) -- so
            // next to a theme-coloured Material gear it always read as a
            // different weight and palette. "extension" is the same glyph the
            // plugins list already falls back to for plugins without an icon.
            RailButton {
                active: root.panel === "plugins"
                glyph: "extension"
                onClicked: LeftPanel.openPanel("plugins", root.screenName)
            }

            RailButton {
                active: root.panel === "settings"
                glyph: "settings"
                onClicked: LeftPanel.openPanel("settings", root.screenName)
            }
        }
    }

    // Border -> rail. Anchored to the rail's BORDER-side edge, mirroring the
    // right panel where the fillets sit on the card's right (border) edge:
    // above the card the border continues UP along the fillet's LEFT edge and
    // the card continues RIGHT along its BOTTOM edge, so the solid quadrant is
    // bottom-left; below the card it is top-left.
    InvertedCorner {
        anchors.left: rail.left
        anchors.bottom: rail.top
        size: Config.border.rounding
        colour: Colours.tPalette.m3surface
        corner: InvertedCorner.BottomLeft
        visible: rail.width > 0
    }

    InvertedCorner {
        anchors.left: rail.left
        anchors.top: rail.bottom
        size: Config.border.rounding
        colour: Colours.tPalette.m3surface
        corner: InvertedCorner.TopLeft
        visible: rail.width > 0
    }

    // Rail -> slideout, where the taller slideout steps up past the shorter
    // rail. Same geometry as the right panel's own step joins: above the step
    // the slideout continues UP along the fillet's RIGHT edge and the rail
    // continues LEFT along its BOTTOM edge, so the solid quadrant is
    // bottom-right; below the step it is top-right.
    InvertedCorner {
        anchors.right: rail.right
        anchors.bottom: rail.top
        size: Tokens.rounding.extraLarge
        colour: Colours.tPalette.m3surface
        corner: InvertedCorner.BottomRight
        visible: rail.width > 0 && slideout.width > 0
    }

    InvertedCorner {
        anchors.right: rail.right
        anchors.top: rail.bottom
        size: Tokens.rounding.extraLarge
        colour: Colours.tPalette.m3surface
        corner: InvertedCorner.TopRight
        visible: rail.width > 0 && slideout.width > 0
    }

    // ------------------------------------------------------------ slideout

    Item {
        id: slideout

        anchors.left: rail.right
        anchors.verticalCenter: parent.verticalCenter

        readonly property real contentWidth: content.item ? content.item.implicitWidth : 0
        readonly property real contentHeight: content.item ? content.item.implicitHeight : 0

        implicitWidth: slideout.contentWidth + Tokens.padding.large * 2
        implicitHeight: Math.min(root.usableHeight, slideout.contentHeight + Tokens.padding.large * 2)

        width: root.panel !== "" ? implicitWidth : 0
        height: implicitHeight
        visible: width > 0
        clip: true

        Behavior on width {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.tPalette.m3surface
            // Square where it meets the rail, and square on the right too
            // once the detail pane abuts it, so the three read as one card.
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: detail.width > 0 ? 0 : Tokens.rounding.extraLarge
            bottomRightRadius: detail.width > 0 ? 0 : Tokens.rounding.extraLarge
        }

        Loader {
            id: content

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.large
            anchors.verticalCenter: parent.verticalCenter
            // Natural size: the slideout is measured FROM this, so giving it
            // the slideout's own geometry would be circular.
            width: slideout.contentWidth
            height: Math.max(0, slideout.height - Tokens.padding.large * 2)

            active: root.panel !== ""
            sourceComponent: root.panel === "plugins" ? pluginsContent
                : root.panel === "settings" ? settingsContent
                : null
        }
    }

    // Third step: the hovered plugin's detail pane, outboard of the plugins
    // list. Only ever open alongside that list -- LeftPanel clears the detail
    // id when the slideout changes -- so it can assume a slideout to its left.
    Item {
        id: detail

        anchors.left: slideout.right
        anchors.verticalCenter: parent.verticalCenter

        readonly property bool showing: root.panel === "plugins" && LeftPanel.detailPluginId !== ""
        readonly property real contentWidth: detailContent.item ? detailContent.item.implicitWidth : 0
        readonly property real contentHeight: detailContent.item ? detailContent.item.implicitHeight : 0

        implicitWidth: detail.contentWidth + Tokens.padding.large * 2
        implicitHeight: Math.min(root.usableHeight, detail.contentHeight + Tokens.padding.large * 2)

        width: detail.showing ? implicitWidth : 0
        height: implicitHeight
        visible: width > 0
        clip: true

        Behavior on width {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.tPalette.m3surface
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: Tokens.rounding.extraLarge
            bottomRightRadius: Tokens.rounding.extraLarge
        }

        Loader {
            id: detailContent

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.large
            anchors.verticalCenter: parent.verticalCenter
            width: detail.contentWidth
            height: Math.max(0, detail.height - Tokens.padding.large * 2)

            active: detail.showing
            sourceComponent: detail.showing ? detailComponent : null
        }
    }

    // The detail pane is shorter than the plugins list beside it, so the same
    // step join applies here as between the rail and the list.
    InvertedCorner {
        anchors.right: detail.left
        anchors.bottom: detail.top
        size: Tokens.rounding.extraLarge
        colour: Colours.tPalette.m3surface
        corner: InvertedCorner.BottomRight
        visible: detail.width > 0 && detail.height < slideout.height
    }

    InvertedCorner {
        anchors.right: detail.left
        anchors.top: detail.bottom
        size: Tokens.rounding.extraLarge
        colour: Colours.tPalette.m3surface
        corner: InvertedCorner.TopRight
        visible: detail.width > 0 && detail.height < slideout.height
    }

    Component {
        id: detailComponent

        PluginDetail {
            pluginId: LeftPanel.detailPluginId
        }
    }

    Component {
        id: pluginsContent

        PluginsList {
            onActivated: id => {
                root.pluginActivated(id);
                LeftPanel.closePanel();
            }
        }
    }

    Component {
        id: settingsContent

        SettingsModule.SettingsContent {}
    }

    signal pluginActivated(string id)

    // ---------------------------------------------------------- components

    component RailButton: Rectangle {
        id: button

        property string glyph: ""
        property bool active: false
        signal clicked

        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize
        radius: Tokens.rounding.medium
        color: button.active
            ? Colours.palette.m3secondaryContainer
            : buttonArea.containsMouse ? Colours.palette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainer

        Behavior on color {
            CAnim {}
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: button.glyph
            fontStyle: Tokens.font.icon.small
            color: button.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
