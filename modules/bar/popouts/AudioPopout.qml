pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

// Output and input volume, each draggable.
ColumnLayout {
    id: root

    property bool inputMode: false

    spacing: Tokens.spacing.small

    StyledText {
        text: root.inputMode ? "Microphone" : "Volume"
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.fontSize.small
    }

    RowLayout {
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: root.inputMode
                ? (Audio.sourceMuted ? "mic_off" : "mic")
                : (Audio.muted ? "volume_off" : "volume_up")
            color: Colours.palette.m3primary

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.inputMode ? Audio.toggleSourceMute() : Audio.toggleMute()
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 180
            implicitHeight: Tokens.spacing.medium

            Rectangle {
                id: track

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Tokens.spacing.small
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                Rectangle {
                    width: parent.width * (root.inputMode ? Audio.sourceVolume : Math.min(1, Audio.volume))
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: (root.inputMode ? Audio.sourceMuted : Audio.muted)
                        ? Colours.palette.m3outline : Colours.palette.m3primary
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => {
                    if (pressed)
                        root.apply(mouse.x / width);
                }
                onClicked: mouse => root.apply(mouse.x / width)
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 40
            horizontalAlignment: Text.AlignRight
            text: `${root.inputMode ? Audio.sourceVolumePercent : Audio.volumePercent}%`
            color: Colours.palette.m3onSurface
        }
    }

    function apply(fraction) {
        const v = Math.max(0, Math.min(1, fraction));
        if (root.inputMode) {
            if (Audio.hasSource)
                Audio.source.audio.volume = v;
        } else {
            Audio.setVolume(v);
        }
    }
}
