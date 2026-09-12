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

    readonly property int gap: Math.round(Tokens.spacing.medium / 2)

    function collapsed(id) {
        if (id === "lockStatus")
            return !Keyboard.anyLock;
        if (id === "battery")
            return !Battery.present;
        if (id === "bluetooth")
            return !Bt.available;
        return false;
    }

    readonly property var items: (Config.bar.statusIcons || [])
        .filter(e => e && e.enabled && !root.collapsed(e.id))

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    clip: true

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

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

    function updateHover() {
        if (!hover.hovered) {
            root.hoverChanged("", 0);
            return;
        }
        const p = hover.point.position;
        for (let i = 0; i < repeater.count; i++) {
            const icon = repeater.itemAt(i);
            if (!icon)
                continue;
            const local = root.mapToItem(icon, p.x, p.y);
            if (local.x >= 0 && local.x <= icon.width) {
                // null maps to scene coordinates, which for a layer-shell
                // surface are window coordinates -- the space the popout is
                // positioned in. Mapping to the immediate parent would report a
                // few dozen pixels and pin every popout to the left edge.
                const centre = icon.mapToItem(null, icon.width / 2, 0).x;
                root.hoverChanged(icon.entryId, centre);
                return;
            }
        }
        root.hoverChanged("", 0);
    }

    RowLayout {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.medium
        spacing: root.gap

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
                    if (entryId === "lockStatus")
                        return Colours.palette.m3tertiary;
                    return root.colour;
                }

                text: {
                    switch (icon.entryId) {
                    case "lockStatus":
                        return Keyboard.capsLock ? "keyboard_capslock" : "pin";
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
                    }
                    return "help";
                }
            }
        }
    }
}
