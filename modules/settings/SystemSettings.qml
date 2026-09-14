pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../components"
import "../../services"

// System settings: the external Hyprland config Celeste's own shortcut and
// gesture features depend on -- see docs/EXTERNAL-CONFIG.md and
// services/SystemIntegration.qml's own header comment for the full
// reasoning, especially the platform limitation this page opens with.
//
// Every control here is click-driven, same reasoning as TopBarSettings.qml:
// no keyboard focus is primed for this panel, so a text field would be dead
// on arrival.
Item {
    id: root

    readonly property var si: SystemIntegration

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content

            width: parent.width
            spacing: Tokens.spacing.medium

            // ------------------------------------------------------ notice

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: noticeText.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainerHigh

                StyledText {
                    id: noticeText
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    wrapMode: Text.WordWrap
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    text: "Omarchy's own plugin enable/disable/remove has no way to run code when it fires -- flipping a plugin off just stops its QML, including this panel. So nothing here can react automatically: turn an item off HERE before disabling or removing Celeste through Omarchy, since nothing will do it afterwards."
                }
            }

            // --------------------------------------------------- shortcuts

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "Global shortcuts"
                        font: Tokens.font.body.normal
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "SUPER+Space opens Celeste's menu, Ctrl+Tab the overview. Without this, both are unreachable by keyboard."
                        font: Tokens.font.body.small
                        color: Colours.palette.m3outline
                        wrapMode: Text.WordWrap
                    }
                }

                StatusBadge {
                    status: root.si.shortcutsStatus
                }

                ActionButton {
                    label: "Apply"
                    visible: root.si.shortcutsStatus === "absent"
                    onClicked: root.si.applyShortcuts()
                }

                ActionButton {
                    label: "Remove"
                    visible: root.si.shortcutsStatus === "managed"
                    onClicked: root.si.removeShortcuts()
                }
            }

            // ---------------------------------------------------- gestures

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "Touchpad gestures"
                        font: Tokens.font.body.normal
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "4-finger swipe to change workspace, 4-finger up/down to show/hide the overview."
                        font: Tokens.font.body.small
                        color: Colours.palette.m3outline
                        wrapMode: Text.WordWrap
                    }
                }

                StatusBadge {
                    status: root.si.gesturesStatus
                }

                ActionButton {
                    label: "Apply"
                    visible: root.si.gesturesStatus === "absent"
                    onClicked: root.si.applyGestures()
                }

                ActionButton {
                    label: "Remove"
                    visible: root.si.gesturesStatus === "managed"
                    onClicked: root.si.removeGestures()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.si.shortcutsStatus === "external" || root.si.gesturesStatus === "external"
                text: "Already configured outside Celeste (hand-written, or added before this page existed) -- present and working, but not something this page can safely offer to remove."
                font: Tokens.font.body.small
                color: Colours.palette.m3outline
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colours.palette.m3outlineVariant
            }

            // ------------------------------------------------- diagnostics

            StyledText {
                text: "Diagnostics"
                font: Tokens.font.body.normal
                color: Colours.palette.m3onSurface
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: root.si.duplicateShellCount > 1
                        ? "Two Omarchy shells are running at once (found " + root.si.duplicateShellCount + ") -- doubled bar height, panels opening twice. Usually a stray autostart line; see below."
                        : "One Omarchy shell running -- normal."
                    font: Tokens.font.body.small
                    color: root.si.duplicateShellCount > 1 ? Colours.palette.m3error : Colours.palette.m3outline
                    wrapMode: Text.WordWrap
                }

                ActionButton {
                    label: "Recheck"
                    onClicked: root.si.refreshDuplicateCheck()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium
                visible: root.si.autostartHasStrayLine

                StyledText {
                    Layout.fillWidth: true
                    text: "autostart.lua starts a second shell on its own line -- the direct cause of the doubling above."
                    font: Tokens.font.body.small
                    color: Colours.palette.m3error
                    wrapMode: Text.WordWrap
                }

                ActionButton {
                    label: "Fix"
                    onClicked: root.si.fixAutostart()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colours.palette.m3outlineVariant
            }

            // ------------------------------------------------------- tools

            StyledText {
                text: "Required tools"
                font: Tokens.font.body.normal
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.fillWidth: true
                visible: !root.si.hasBrightnessctl || !root.si.hasInotifywait
                text: {
                    const missing = [];
                    if (!root.si.hasBrightnessctl)
                        missing.push("brightnessctl");
                    if (!root.si.hasInotifywait)
                        missing.push("inotify-tools");
                    return "Missing: " + missing.join(", ") + ". Installing can need a password prompt this panel cannot show -- run in a terminal:\n  omarchy pkg add " + missing.join(" ");
                }
                font: Tokens.font.body.small
                color: Colours.palette.m3error
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.si.hasBrightnessctl && root.si.hasInotifywait
                text: "brightnessctl and inotify-tools are both installed."
                font: Tokens.font.body.small
                color: Colours.palette.m3outline
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    // ---------------------------------------------------------- components

    component StatusBadge: Rectangle {
        id: badge

        required property string status

        implicitWidth: badgeText.implicitWidth + Tokens.padding.large * 2
        implicitHeight: Tokens.sizes.bar.innerWidth * 0.8
        radius: Tokens.rounding.full
        color: badge.status === "managed"
            ? Colours.palette.m3primary
            : badge.status === "external"
                ? Colours.palette.m3tertiary
                : Colours.palette.m3surfaceContainerHigh

        Behavior on color {
            CAnim {}
        }

        StyledText {
            id: badgeText
            anchors.centerIn: parent
            text: badge.status === "managed" ? "On" : badge.status === "external" ? "External" : "Off"
            font: Tokens.font.body.small
            color: badge.status === "managed"
                ? Colours.palette.m3onPrimary
                : badge.status === "external"
                    ? Colours.palette.m3onTertiary
                    : Colours.palette.m3onSurface
        }
    }

    component ActionButton: Rectangle {
        id: actionButton

        required property string label
        signal clicked

        implicitWidth: actionText.implicitWidth + Tokens.padding.large * 2
        implicitHeight: Tokens.sizes.bar.innerWidth * 0.8
        radius: Tokens.rounding.full
        color: actionArea.containsMouse
            ? Colours.palette.m3surfaceContainerHighest
            : Colours.palette.m3surfaceContainerHigh

        Behavior on color {
            CAnim {}
        }

        StyledText {
            id: actionText
            anchors.centerIn: parent
            text: actionButton.label
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurface
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }
}
