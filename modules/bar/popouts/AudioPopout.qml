pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../../core"
import "../../../components"
import "../../../services"

// Mirrors Omarchy's own audio panel (plugins/panels/audio/Panel.qml): one
// hero mute switch that carries both channels, then an OUTPUT and an INPUT
// section each with a section slider and a device list. Bar.qml opens this
// same component for both the speaker and microphone status icons -- Omarchy
// itself has only the one combined panel regardless of which control opened
// it, so `inputMode` no longer changes what's shown, just kept so existing
// call sites setting it don't break.
ColumnLayout {
    id: root

    property bool inputMode: false
    spacing: Tokens.spacing.medium

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: Audio.outputIcon()
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.large
            opacity: Audio.muted ? 0.5 : 1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            StyledText { text: "Audio"; color: Colours.palette.m3onSurface; font.pointSize: Tokens.fontSize.large; font.bold: true }
            StyledText {
                text: Audio.outputVolumeName(Audio.volume, Audio.muted).toUpperCase()
                color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small; font.bold: true
            }
        }
        Rectangle {
            implicitWidth: Tokens.spacing.extraLarge; implicitHeight: Tokens.spacing.large; radius: Tokens.rounding.full
            color: Audio.anyAudible ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
            Rectangle {
                width: Tokens.spacing.medium; height: width; radius: Tokens.rounding.full; anchors.verticalCenter: parent.verticalCenter
                x: Audio.anyAudible ? parent.width - width - Tokens.spacing.extraSmall : Tokens.spacing.extraSmall
                color: Audio.anyAudible ? Colours.palette.m3onPrimary : Colours.palette.m3outline
                Behavior on x { Anim { type: Anim.FastSpatial } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Audio.toggleAllMuted() }
        }
    }

    // Layout.preferredWidth here is what actually sets the popout's width:
    // ColumnLayout recomputes its own implicitWidth from children on every
    // relayout, so a plain `implicitWidth: 600` on the root is silently
    // overwritten back down to the content's natural width the moment it
    // renders (confirmed with an isolated qs probe -- see CLAUDE.md). Pinning
    // it on this zero-content divider is what sticks.
    Rectangle { Layout.fillWidth: true; Layout.preferredWidth: 600; implicitHeight: 1; color: Colours.palette.m3outlineVariant }

    MixerSection {
        Layout.fillWidth: true
        isOutput: true
        percent: Audio.volumePercent; value: Math.min(1, Audio.volume); muted: Audio.muted
        devices: Audio.outputDevices; selected: Audio.sink
        onVolumeRequested: value => Audio.setVolume(value)
        onDeviceSelected: device => Audio.setDefaultSink(device)
        onToggleMute: Audio.toggleMute()
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colours.palette.m3outlineVariant }

    MixerSection {
        Layout.fillWidth: true
        isOutput: false
        percent: Audio.sourceVolumePercent; value: Audio.sourceVolume; muted: Audio.sourceMuted
        devices: Audio.inputDevices; selected: Audio.source
        peak: inputPeak.peak
        onVolumeRequested: value => { if (Audio.hasSource) Audio.source.audio.volume = Math.max(0, Math.min(1, value)); }
        onDeviceSelected: device => Audio.setDefaultSource(device)
        onToggleMute: Audio.toggleSourceMute()
    }

    PwNodePeakMonitor {
        id: inputPeak
        node: Audio.source
        enabled: Audio.hasSource
    }

    component MixerSection: ColumnLayout {
        id: section
        required property bool isOutput
        required property int percent
        required property real value
        required property bool muted
        required property var devices
        required property var selected
        property real peak: -1
        signal volumeRequested(real value)
        signal deviceSelected(var device)
        signal toggleMute()
        spacing: Tokens.spacing.small

        readonly property string title: section.isOutput ? "OUTPUT" : "INPUT"

        RowLayout {
            Layout.fillWidth: true
            StyledText { text: section.title; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }
            Item { Layout.fillWidth: true }
            StyledText {
                text: `${section.percent}%`; color: Colours.palette.m3primary; font.pointSize: Tokens.fontSize.small; font.bold: true
                opacity: section.muted ? 0.5 : 1
            }
        }

        Item {
            Layout.fillWidth: true; implicitHeight: Tokens.spacing.large
            opacity: section.muted ? 0.5 : 1
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: Tokens.spacing.extraSmall; radius: Tokens.rounding.full; color: Colours.palette.m3surfaceContainerHighest }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, section.value)); height: Tokens.spacing.extraSmall; radius: Tokens.rounding.full; color: Colours.palette.m3primary }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, parent.width * section.value - width / 2)); width: Tokens.spacing.medium; height: width; radius: Tokens.rounding.full; color: Colours.palette.m3onSurface }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: mouse => { if (mouse.button === Qt.RightButton) section.toggleMute(); else section.volumeRequested(mouse.x / width); }
                onPositionChanged: mouse => { if (pressed) section.volumeRequested(mouse.x / width); }
            }
        }

        // Live input level, under the input slider only -- mirrors the meter
        // on Omarchy's own mic row so you can see it's actually picking up
        // sound, not just that the slider is set to something.
        Rectangle {
            Layout.fillWidth: true; visible: section.peak >= 0
            implicitHeight: Tokens.spacing.extraSmall
            color: Colours.palette.m3surfaceContainerHighest
            opacity: section.muted ? 0.35 : 1
            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, section.peak))
                color: Colours.palette.m3primary
                Behavior on width { NumberAnimation { duration: 70 } }
            }
        }

        Repeater {
            model: section.devices
            delegate: Rectangle {
                id: deviceRow
                required property var modelData
                readonly property bool active: section.selected && section.selected.id === deviceRow.modelData.id
                Layout.fillWidth: true; implicitHeight: Tokens.spacing.extraLarge; radius: Tokens.rounding.full
                color: active ? Colours.palette.m3surfaceContainerHighest : "transparent"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: Tokens.padding.medium; anchors.rightMargin: Tokens.padding.medium; spacing: Tokens.spacing.medium
                    MaterialIcon {
                        text: section.isOutput ? Audio.sinkGlyph(deviceRow.modelData) : Audio.sourceGlyph(deviceRow.modelData)
                        color: active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }
                    StyledText { Layout.fillWidth: true; text: Audio.deviceName(deviceRow.modelData); elide: Text.ElideRight; color: Colours.palette.m3onSurface; font.bold: active }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: section.deviceSelected(deviceRow.modelData) }
            }
        }

        StyledText {
            visible: section.devices.length === 0
            text: section.isOutput ? "No output devices found" : "No input devices found"
            color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small
        }
    }
}
