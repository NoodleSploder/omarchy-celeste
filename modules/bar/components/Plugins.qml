pragma ComponentBehavior: Bound

import QtQuick
import "../../../core"
import "../../../components"
import "../../../services"

// A single bar button that previews (hover) or pins open (click) the
// PluginsStrip below the bar -- see services/PluginsBar.qml for the state
// and why "pinned" is its own thing rather than the shared popout mechanism.
//
// Uses assets/plugin.png (a plain plug/extension silhouette with real alpha,
// not a Material Symbols glyph -- there isn't a close enough match in that
// font) shown as-is rather than recoloured to the theme's foreground tone.
// A MultiEffect colorization pass (the same technique Tray.qml uses for its
// own icon recolouring) was tried first and confirmed NOT to work on this
// machine -- verified two ways, not guessed: the deployed button rendered
// solid black regardless of colorizationColor, and an isolated qs -p probe
// (MultiEffect, layer.enabled set correctly per Tray.qml's own pattern)
// grabbed-to-image and still came back solid black instead of the probe's
// test red. So Tray.qml's own `Config.bar.tray.recolour` option -- off by
// default -- has likely never actually worked either; it just never got
// visually exercised before now. Rather than ship a broken tint, this button
// keeps the asset's natural black and instead guarantees contrast the way
// every other icon-bearing pill in this bar already does: a permanent
// theme-derived m3surfaceContainer-family background, not a transparent one
// that would let a fixed-colour glyph disappear against the bar on some
// themes.
StyledRect {
    id: root

    readonly property int iconSize: Math.round(Tokens.sizes.bar.innerWidth * 0.55)

    color: PluginsBar.pinned
        ? Colours.palette.m3secondaryContainer
        : hover.hovered ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: Tokens.sizes.bar.innerWidth

    Behavior on color {
        CAnim {}
    }

    Image {
        id: icon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: Qt.resolvedUrl("../../../assets/plugin.png")
        asynchronous: true
        fillMode: Image.PreserveAspectFit
    }

    HoverHandler {
        id: hover
        onHoveredChanged: PluginsBar.hovered = hover.hovered
    }

    TapHandler {
        onSingleTapped: PluginsBar.togglePinned()
    }
}
