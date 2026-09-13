pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

// Mirrors Omarchy's own network panel (plugins/panels/network/Panel.qml):
// hero (icon, SSID/status, Wi-Fi toggle), a live connection-details grid,
// Wi-Fi band selection, DNS provider selection, then the Wi-Fi picker.
// The Wi-Fi list itself stays on Quickshell.Networking live bindings; the
// details/band/DNS rows shell out to the same `omarchy-network-*` commands
// the native panel uses, since Quickshell.Networking exposes none of that.
ColumnLayout {
    id: root

    spacing: Tokens.spacing.medium
    property var passwordNetwork: null
    property string passphrase: ""

    Component.onCompleted: Net.watchDetails()
    Component.onDestruction: Net.unwatchDetails()

    readonly property string heroTitle: {
        if (Net.wired)
            return "Ethernet";
        if (Net.wireless)
            return Net.ssid || "Wi-Fi";
        return Net.wifiEnabled ? "Not connected" : "Wi-Fi off";
    }

    readonly property string heroStatus: {
        if (Net.wired || Net.wireless)
            return Net.connectionPhrase.toUpperCase();
        return Net.ready ? "NOT CONNECTED" : "";
    }

    RowLayout {
        Layout.fillWidth: true; spacing: Tokens.spacing.medium
        MaterialIcon { text: Net.icon; color: Net.wifiEnabled || Net.wired ? Colours.palette.m3primary : Colours.palette.m3outline; fontStyle: Tokens.font.icon.large }
        ColumnLayout {
            Layout.fillWidth: true; spacing: -2
            StyledText { text: root.heroTitle; color: Colours.palette.m3onSurface; font.pointSize: Tokens.fontSize.large; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            StyledText {
                animate: true
                visible: text !== ""
                text: root.heroStatus
                color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small; font.bold: true
            }
        }
        Rectangle {
            implicitWidth: Tokens.spacing.extraLarge; implicitHeight: Tokens.spacing.large; radius: Tokens.rounding.full
            color: Net.wifiEnabled ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
            Rectangle {
                width: Tokens.spacing.medium; height: width; radius: Tokens.rounding.full; anchors.verticalCenter: parent.verticalCenter
                x: Net.wifiEnabled ? parent.width - width - Tokens.spacing.extraSmall : Tokens.spacing.extraSmall
                color: Net.wifiEnabled ? Colours.palette.m3onPrimary : Colours.palette.m3outline
                Behavior on x { Anim { type: Anim.FastSpatial } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Net.toggleWifi() }
        }
    }

    // Layout.preferredWidth is what actually pins the popout's width -- see
    // the comment on AudioPopout's divider for why a plain implicitWidth on
    // the root ColumnLayout does not work.
    Rectangle { Layout.fillWidth: true; Layout.preferredWidth: 500; implicitHeight: 1; color: Colours.palette.m3outlineVariant }

    // ---------------------------------------------------------------- stats
    GridLayout {
        Layout.fillWidth: true
        visible: !!Net.info.iface
        columns: 4
        columnSpacing: Tokens.spacing.large
        rowSpacing: Tokens.spacing.extraSmall

        DetailLabel { text: "Ping" }
        DetailValue { Layout.fillWidth: true; text: Net.formatPingLatency(Net.internetPingLatency, Net.hasInternetPing); urgent: Net.internetPingPacketLoss > 0 }
        DetailLabel { text: "Packet Loss" }
        DetailValue { Layout.fillWidth: true; text: Net.formatPacketLoss(Net.internetPingPacketLoss, Net.hasInternetPing); urgent: Net.internetPingPacketLoss > 0 }

        DetailLabel { text: "Receiving" }
        DetailValue { Layout.fillWidth: true; text: Net.hasTransferStats ? Net.formatRate(Net.downloadRate) : "--" }
        DetailLabel { text: "Sending" }
        DetailValue { Layout.fillWidth: true; text: Net.hasTransferStats ? Net.formatRate(Net.uploadRate) : "--" }

        DetailLabel { text: "Downloaded" }
        DetailValue { Layout.fillWidth: true; text: Net.hasTransferStats ? Net.formatBytes(parseFloat(Net.info.rx_bytes || "0")) : "--" }
        DetailLabel { text: "Uploaded" }
        DetailValue { Layout.fillWidth: true; text: Net.hasTransferStats ? Net.formatBytes(parseFloat(Net.info.tx_bytes || "0")) : "--" }

        DetailLabel { text: "IP Address" }
        DetailValue { Layout.fillWidth: true; text: Net.info.ip || "--"; copyable: !!Net.info.ip }
        DetailLabel { text: "Gateway" }
        DetailValue { Layout.fillWidth: true; text: Net.info.gateway || "--"; copyable: !!Net.info.gateway }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: !!Net.info.iface; color: Colours.palette.m3outlineVariant }

    // ------------------------------------------------------------- wifi band
    ColumnLayout {
        Layout.fillWidth: true
        visible: Net.canSelectBand
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            StyledText { text: Net.bandSectionTitle; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }
            Item { Layout.fillWidth: true }
            StyledText { text: "AUTOMATIC"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }
            Rectangle {
                implicitWidth: Tokens.spacing.large; implicitHeight: Tokens.spacing.medium; radius: Tokens.rounding.full
                color: !Net.bandPinned ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
                Rectangle {
                    width: Tokens.spacing.small; height: width; radius: Tokens.rounding.full; anchors.verticalCenter: parent.verticalCenter
                    x: !Net.bandPinned ? parent.width - width - 2 : 2
                    color: !Net.bandPinned ? Colours.palette.m3onPrimary : Colours.palette.m3outline
                    Behavior on x { Anim { type: Anim.FastSpatial } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Net.toggleBandAuto() }
            }
        }

        RowLayout {
            Layout.fillWidth: true; visible: Net.bandPillsVisible; spacing: Tokens.spacing.small
            Repeater {
                model: Net.bandAvailable
                delegate: Rectangle {
                    id: bandPill
                    required property string modelData
                    readonly property bool active: Net.bandSelected === bandPill.modelData
                    Layout.fillWidth: true; implicitHeight: Tokens.spacing.extraLarge; radius: Tokens.rounding.full
                    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
                    StyledText {
                        anchors.centerIn: parent; text: Net.bandLabel(bandPill.modelData)
                        color: bandPill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font.bold: bandPill.active
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Net.setBand(bandPill.modelData) }
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: Net.canSelectBand; color: Colours.palette.m3outlineVariant }

    // -------------------------------------------------------------- dns
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText { text: "DNS PROVIDER"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }

        RowLayout {
            Layout.fillWidth: true; spacing: Tokens.spacing.small
            Repeater {
                model: Net.dnsProviders
                delegate: Rectangle {
                    id: dnsPill
                    required property string modelData
                    readonly property bool active: Net.dnsProvider === dnsPill.modelData
                    Layout.fillWidth: true; implicitHeight: Tokens.spacing.extraLarge; radius: Tokens.rounding.full
                    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
                    StyledText {
                        anchors.centerIn: parent; text: dnsPill.modelData
                        color: dnsPill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font.bold: dnsPill.active
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Net.setDns(dnsPill.modelData) }
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colours.palette.m3outlineVariant }

    // --------------------------------------------------------- wifi picker
    RowLayout {
        Layout.fillWidth: true
        StyledText { text: "WI-FI NETWORKS"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }
        Item { Layout.fillWidth: true }
        MaterialIcon {
            text: "refresh"; color: Colours.palette.m3primary
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Net.scan() }
        }
    }

    Repeater {
        model: Net.wifiEnabled ? Net.sortedWifiNetworks : []
        delegate: ColumnLayout {
            id: networkEntry
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            readonly property bool connected: !!networkEntry.modelData.connected
            readonly property bool protectedNetwork: networkEntry.modelData.security !== undefined && Number(networkEntry.modelData.security) !== 0
            readonly property string sectionTitle: Net.wifiSectionTitle(Net.sortedWifiNetworks, networkEntry.index)

            StyledText {
                visible: networkEntry.sectionTitle !== ""
                text: networkEntry.sectionTitle
                color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true
            }

            Rectangle {
                id: networkRow
                Layout.fillWidth: true; implicitHeight: Tokens.spacing.extraLarge; radius: Tokens.rounding.full
                color: networkEntry.connected ? Colours.palette.m3surfaceContainerHighest : "transparent"

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: Tokens.padding.medium; anchors.rightMargin: Tokens.padding.medium; spacing: Tokens.spacing.medium
                    MaterialIcon { text: Net.networkIcon(networkEntry.modelData); color: networkEntry.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant }
                    StyledText { Layout.fillWidth: true; text: Net.networkName(networkEntry.modelData); elide: Text.ElideRight; color: Colours.palette.m3onSurface; font.bold: networkEntry.connected }
                    MaterialIcon { visible: networkEntry.protectedNetwork; text: "lock"; color: Colours.palette.m3outline; fontStyle: Tokens.font.icon.small }
                    StyledText { text: `${Net.networkStrength(networkEntry.modelData)}%`; color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small }
                    MaterialIcon { visible: networkEntry.connected; text: "check"; color: Colours.palette.m3primary }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (networkEntry.connected) Net.activate(networkEntry.modelData, "");
                        else if (networkEntry.protectedNetwork && !networkEntry.modelData.known) {
                            root.passwordNetwork = networkEntry.modelData;
                            root.passphrase = "";
                        } else Net.activate(networkEntry.modelData, "");
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true; visible: root.passwordNetwork !== null
        implicitHeight: passwordRow.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium; color: Colours.palette.m3surfaceContainer
        ColumnLayout {
            id: passwordRow
            anchors.fill: parent; anchors.margins: Tokens.padding.medium; spacing: Tokens.spacing.small
            StyledText { text: `Password for ${root.passwordNetwork ? Net.networkName(root.passwordNetwork) : "network"}`; color: Colours.palette.m3onSurface; font.pointSize: Tokens.fontSize.small }
            TextInput {
                id: passwordInput
                Layout.fillWidth: true; Layout.preferredHeight: Tokens.spacing.extraLarge
                echoMode: TextInput.Password; color: Colours.palette.m3onSurface; font.family: Tokens.font.sans
                font.pointSize: Tokens.fontSize.normal; clip: true
                text: root.passphrase; onTextChanged: root.passphrase = text
                Rectangle { anchors.fill: parent; z: -1; radius: Tokens.rounding.small; color: Colours.palette.m3surfaceContainerHighest }
                anchors.margins: Tokens.padding.small
            }
            RowLayout {
                Layout.fillWidth: true; Item { Layout.fillWidth: true }
                StyledText { text: "Cancel"; color: Colours.palette.m3outline; MouseArea { anchors.fill: parent; onClicked: root.passwordNetwork = null } }
                StyledText {
                    text: "Connect"; color: Colours.palette.m3primary; font.bold: true
                    MouseArea { anchors.fill: parent; onClicked: { Net.activate(root.passwordNetwork, root.passphrase); root.passwordNetwork = null; } }
                }
            }
        }
    }

    StyledText {
        visible: Net.wifiEnabled && Net.wifiNetworks.length === 0
        text: "Scanning for Wi-Fi networks…"; color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small
        Component.onCompleted: Net.scan()
    }

    component DetailLabel: StyledText {
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.fontSize.small
        opacity: 0.8
    }

    component DetailValue: StyledText {
        id: value
        property bool copyable: false
        property bool urgent: false
        horizontalAlignment: Text.AlignRight
        color: value.urgent ? Colours.palette.m3error : Colours.palette.m3onSurface
        font.pointSize: Tokens.fontSize.small
        font.bold: true
        elide: Text.ElideRight

        MouseArea {
            anchors.fill: parent
            enabled: value.copyable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Net.copyToClipboard(value.text)
        }
    }
}
