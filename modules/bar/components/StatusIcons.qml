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

    RowLayout {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.medium
        spacing: root.gap

        Repeater {
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
