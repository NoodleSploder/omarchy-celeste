pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

// The status pill: a row of state glyphs in one rounded container.
//
// Entries come from Config.bar.statusIcons in declared order. An entry may
// collapse to zero width -- lockStatus shows nothing while neither caps nor num
// lock is on -- so the row is built from a filtered model rather than hiding
// delegates in place, which would leave their spacing behind.
StyledRect {
    id: root

    property color colour: Colours.palette.m3secondary

    // Emitted as the pointer moves across the pill. `name` is the entry id under
    // the cursor (empty when none), `centre` its x midpoint in bar coordinates,
    // so the popout can point at the exact glyph rather than the whole pill.
    signal hoverChanged(string name, real centre)

    // The containing Celeste surface owns the connected panel. Pass the icon's
    // centre as well, so a click can toggle the same anchored popout as hover.
    signal iconClicked(string name, real centre)

    readonly property int gap: Math.round(Tokens.spacing.medium / 2)

    function collapsed(id) {
        if (id === "capsLock")
            return !Keyboard.capsLock;
        if (id === "numLock")
            return !Keyboard.numLock;
        if (id === "battery")
            return !Battery.present;
        if (id === "bluetooth")
            return !Bt.available;
        if (id === "agents")
            return !AgentUsage.available;
        return false;
    }

    readonly property var items: (Config.bar.statusIcons || [])
        .filter(e => e && e.enabled && !root.collapsed(e.id))

    // See the identical block in RunningApps.qml -- both pills opt into the
    // same hover/click-to-expand behaviour, toggled independently from the
    // settings panel's Top Bar page (Config.bar.collapse).
    readonly property bool collapsible: Config.bar.collapse.statusIcons === true
    readonly property bool expanded: !root.collapsible || hover.hovered

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    clip: true

    implicitWidth: root.collapsible
        ? (root.expanded ? row.implicitWidth + Tokens.padding.medium * 2 : root.implicitHeight)
        : row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

    Behavior on implicitWidth {
        enabled: root.collapsible
        Anim {
            type: Anim.FastSpatial
        }
    }

    TapHandler {
        onSingleTapped: {
            const icon = root.iconAt(hover.point.position);
            if (icon)
                root.iconClicked(icon.entryId,
                    icon.mapToItem(null, icon.width / 2, 0).x);
        }
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

    function entryAt(point) {
        const icon = root.iconAt(point);
        return icon ? icon.entryId : "";
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
        // null maps to scene coordinates, which for a layer-shell surface are
        // window coordinates -- the space the popout is positioned in.
        root.hoverChanged(icon.entryId, icon.mapToItem(null, icon.width / 2, 0).x);
    }

    // The single glyph shown while collapsed. "tune" reads as a generic
    // system-controls icon without colliding with the left panel's own gear
    // glyph ("settings"), which means something different (Celeste's own
    // settings panel).
    //
    // m3onSurface, not root.colour (m3secondary): confirmed live with a
    // grim screenshot that the glyph rendered but was invisible at normal
    // size -- m3secondary sits too close to the pill's own background in
    // this theme, the same low-contrast trap CLAUDE.md already documents for
    // the notifications drawer's critical-row stripe. Caught by sampling
    // actual pixel colours inside the circle (no glyph-coloured pixels at
    // all), not by eyeballing a thumbnail.
    MaterialIcon {
        anchors.centerIn: parent
        visible: root.collapsible && !root.expanded
        opacity: root.collapsible && !root.expanded ? 1 : 0
        text: "tune"
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
        // No Behavior here, deliberately: an independently-timed opacity
        // fade racing implicitWidth's own Anim.FastSpatial is exactly the
        // flicker bug already documented (and fixed the same way) for the
        // side panel -- confirmed live here too, a grim screenshot caught
        // the pill fully widened by hover but still faded to ~0 opacity, so
        // it read as a blank pill. Width + clip alone does the reveal now:
        // opacity snaps instantly, so content is never out of sync with how
        // much of the row is actually un-clipped.
        opacity: root.expanded ? 1 : 0

        Repeater {
            id: repeater

            model: root.items

            delegate: MaterialIcon {
                id: icon

                required property var modelData
                readonly property string entryId: icon.modelData.id

                Layout.alignment: Qt.AlignVCenter

                color: {
                    if (entryId === "battery" && Battery.low)
                        return Colours.palette.m3error;
                    if (entryId === "capsLock" || entryId === "numLock")
                        return Colours.palette.m3tertiary;
                    return root.colour;
                }

                text: {
                    switch (icon.entryId) {
                    case "capsLock":
                        return "keyboard_capslock";
                    case "numLock":
                        // Material Symbols has no dedicated numlock glyph --
                        // confirmed by grepping the actual font file's glyph
                        // names, not assumed -- so this is the closest
                        // generic keyboard-lock icon, kept visually distinct
                        // from capsLock's own specific glyph.
                        return "keyboard_lock";
                    case "audio":
                        if (Audio.muted || Audio.volumePercent === 0)
                            return "volume_off";
                        return Audio.volumePercent < 50 ? "volume_down" : "volume_up";
                    case "microphone":
                        return Audio.sourceMuted ? "mic_off" : "mic";
                    case "network":
                        return Net.icon;
                    case "bluetooth":
                        return Bt.icon;
                    case "battery":
                        return Battery.icon;
                    case "agents":
                        return "smart_toy";
                    }
                    return "help";
                }
            }
        }
    }
}
