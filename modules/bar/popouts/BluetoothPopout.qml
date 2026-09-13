pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

// Mirrors Omarchy's own bluetooth panel (plugins/panels/bluetooth/Panel.qml):
// hero (icon, rotating status phrase, power toggle), then CONNECTED / PAIRED
// / AVAILABLE device sections. Discovery runs only while a popout is open
// (ref-counted in Bt.qml, in case more than one monitor's popout is open).
ColumnLayout {
    id: root

    spacing: Tokens.spacing.medium

    Component.onCompleted: Bt.watchDiscovery()
    Component.onDestruction: Bt.unwatchDiscovery()

    RowLayout {
        Layout.fillWidth: true; spacing: Tokens.spacing.medium
        MaterialIcon { text: Bt.icon; color: Bt.enabled ? Colours.palette.m3primary : Colours.palette.m3outline; fontStyle: Tokens.font.icon.large }
        ColumnLayout {
            Layout.fillWidth: true; spacing: -2
            StyledText { text: "Bluetooth"; color: Colours.palette.m3onSurface; font.pointSize: Tokens.fontSize.large; font.bold: true }
            StyledText { animate: true; text: Bt.heroStatusText.toUpperCase(); color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small; font.bold: true }
        }
        Rectangle {
            visible: Bt.available
            implicitWidth: Tokens.spacing.extraLarge; implicitHeight: Tokens.spacing.large; radius: Tokens.rounding.full
            color: Bt.enabled ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
            Rectangle {
                width: Tokens.spacing.medium; height: width; radius: Tokens.rounding.full; anchors.verticalCenter: parent.verticalCenter
                x: Bt.enabled ? parent.width - width - Tokens.spacing.extraSmall : Tokens.spacing.extraSmall
                color: Bt.enabled ? Colours.palette.m3onPrimary : Colours.palette.m3outline
                Behavior on x { Anim { type: Anim.FastSpatial } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Bt.toggleBluetooth() }
        }
    }

    // Layout.preferredWidth is what actually pins the popout's width -- see
    // the comment on AudioPopout's divider for why a plain implicitWidth on
    // the root ColumnLayout does not work.
    Rectangle { Layout.fillWidth: true; Layout.preferredWidth: 600; implicitHeight: 1; color: Colours.palette.m3outlineVariant }

    ColumnLayout {
        Layout.fillWidth: true
        visible: Bt.connectedDevices.length > 0
        spacing: Tokens.spacing.small
        StyledText { text: "CONNECTED"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }
        Repeater {
            model: Bt.connectedDevices
            delegate: DeviceRow { required property var modelData; Layout.fillWidth: true; dev: modelData; sectionName: "connected" }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: Bt.knownDevices.length > 0
        spacing: Tokens.spacing.small
        StyledText { text: "PAIRED"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }
        Repeater {
            model: Bt.knownDevices
            delegate: DeviceRow { required property var modelData; Layout.fillWidth: true; dev: modelData; sectionName: "known" }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: Bt.discovering && Bt.discoveredDevices.length > 0
        spacing: Tokens.spacing.small
        StyledText { text: "AVAILABLE"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }
        Repeater {
            model: Bt.discoveredDevices
            delegate: DeviceRow { required property var modelData; Layout.fillWidth: true; dev: modelData; sectionName: "discovered" }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Bt.connectedDevices.length === 0 && Bt.knownDevices.length === 0
            && !(Bt.discovering && Bt.discoveredDevices.length > 0)
        text: !Bt.available ? "No Bluetooth adapter"
            : !Bt.enabled ? "Turn Bluetooth on to scan"
            : "Scanning for devices…"
        color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small
        wrapMode: Text.WordWrap
    }

    // Two-line device row: name + live status, with a forget action that
    // only appears on hover for known/connected devices (not a bare scan
    // result, which has nothing saved to forget).
    component DeviceRow: Rectangle {
        id: row
        required property var dev
        required property string sectionName

        readonly property bool isConnected: !!(row.dev && row.dev.connected)
        readonly property bool isDiscovered: row.sectionName === "discovered"
        readonly property string action: Bt.pendingAction(row.dev ? row.dev.address : "")
        readonly property bool forgetAvailable: !row.isDiscovered

        readonly property string statusText: {
            if (!row.dev)
                return "";
            if (row.action === "forgetting")
                return "Forgetting…";
            if (row.action === "disconnecting")
                return "Disconnecting…";
            if (row.isConnected)
                return row.dev.batteryAvailable ? Math.round(row.dev.battery * 100) + "%" : "Connected";
            if (row.action === "connecting" || row.dev.pairing === true)
                return "Connecting…";
            return "";
        }

        implicitHeight: rowContent.implicitHeight + Tokens.padding.medium
        radius: Tokens.rounding.full
        color: row.isConnected ? Colours.palette.m3surfaceContainerHighest : "transparent"

        HoverHandler { id: rowHover }

        RowLayout {
            id: rowContent
            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.medium; anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            MaterialIcon { text: row.isConnected ? "bluetooth_connected" : "bluetooth"; color: row.isConnected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant }

            ColumnLayout {
                Layout.fillWidth: true; spacing: -2
                StyledText { Layout.fillWidth: true; text: Bt.deviceLabel(row.dev) || "Device"; elide: Text.ElideRight; color: Colours.palette.m3onSurface; font.bold: row.isConnected }
                StyledText {
                    visible: row.statusText !== ""
                    text: row.statusText; color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small
                }
            }

            MaterialIcon {
                visible: row.forgetAvailable && rowHover.hovered
                text: "close"; color: Colours.palette.m3error; fontStyle: Tokens.font.icon.small
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Bt.forgetDevice(row.dev) }
            }
        }

        MouseArea {
            anchors.fill: parent; z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (row.isConnected) Bt.disconnectDevice(row.dev); else Bt.connectDevice(row.dev); }
        }
    }
}
