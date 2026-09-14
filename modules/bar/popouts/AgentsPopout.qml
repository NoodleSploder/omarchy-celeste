pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

// Claude Code / Codex / Fireworks usage, in Celeste's own border-attached
// popout style -- see services/AgentUsage.qml for why this reads the same
// JSON records Omarchy's own omarchy.agents plugin reads rather than hosting
// that plugin's native panel (its border/corners come from a shared Ui
// component this repo cannot restyle without changing every Omarchy panel
// on the system).
ColumnLayout {
    id: root

    spacing: Tokens.spacing.medium

    property int selectedIndex: 0

    readonly property var providers: AgentUsage.providers
    readonly property var provider: root.providers.length > 0
        ? root.providers[Math.min(root.selectedIndex, root.providers.length - 1)]
        : null

    readonly property var limits: AgentUsage.limitWindows(root.provider)
    readonly property var balance: root.provider ? AgentUsage.balanceValue(root.provider.balance) : null
    readonly property var models: AgentUsage.modelRows(root.provider)
    readonly property var days: root.provider ? (root.provider.recentDays || []) : []
    readonly property real dayPeak: Math.max(1, AgentUsage.weekPeak(root.provider))

    Component.onCompleted: AgentUsage.watch()
    Component.onDestruction: AgentUsage.unwatch()

    // Always-present, zero-height: pins the popout's width regardless of
    // whether the hero row below is visible (it isn't when there are no
    // providers yet) -- see CLAUDE.md's implicitWidth-on-a-Layout gotcha and
    // BatteryPopout's own comment for why this can't just be a plain
    // implicitWidth on root, and why it can't sit on a conditionally-hidden
    // row either.
    Item { Layout.preferredWidth: 700; implicitHeight: 0 }

    RowLayout {
        Layout.fillWidth: true
        visible: !!root.provider
        spacing: Tokens.spacing.medium

        Item {
            implicitWidth: Tokens.sizes.bar.innerWidth * 1.4
            implicitHeight: Tokens.sizes.bar.innerWidth * 1.4

            Image {
                id: mark
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                source: root.provider ? AgentUsage.iconSource(root.provider.id, Colours.light) : ""
                visible: status === Image.Ready
                onStatusChanged: {
                    if (status === Image.Error && root.provider) {
                        const fallback = AgentUsage.iconFallback(root.provider.id);
                        if (source !== fallback)
                            source = fallback;
                    }
                }
            }

            MaterialIcon {
                anchors.fill: parent
                visible: mark.status !== Image.Ready
                text: "smart_toy"
                color: Colours.palette.m3primary
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            StyledText {
                text: root.provider ? root.provider.name : ""
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.fontSize.large
                font.bold: true
            }
            StyledText {
                text: AgentUsage.heroMeta(root.provider)
                color: Colours.palette.m3outline
                font.pointSize: Tokens.fontSize.small
                font.bold: true
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.providers.length === 0
        text: "No AI coding subscriptions found.\nAgents show up here once you've used them."
        color: Colours.palette.m3outline
        font.pointSize: Tokens.fontSize.small
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.providers.length > 1
        spacing: Tokens.spacing.small

        Repeater {
            model: root.providers

            delegate: Rectangle {
                id: tab

                required property var modelData
                required property int index

                readonly property bool active: index === root.selectedIndex

                Layout.fillWidth: true
                implicitHeight: Tokens.spacing.extraLarge * 1.4
                radius: Tokens.rounding.large
                color: tab.active ? Colours.palette.m3secondaryContainer : "transparent"
                border.width: tab.active ? 0 : 1
                border.color: Colours.palette.m3outlineVariant

                StyledText {
                    anchors.centerIn: parent
                    text: tab.modelData.name
                    color: tab.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font.bold: tab.active
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedIndex = tab.index
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: root.limits.length > 0 || !!root.balance; color: Colours.palette.m3outlineVariant }

    ColumnLayout {
        Layout.fillWidth: true
        visible: !!root.balance
        spacing: Tokens.spacing.small

        StyledText { text: "BALANCE"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }

        RowLayout {
            Layout.fillWidth: true
            StyledText { Layout.fillWidth: true; text: "Prepaid credits"; color: Colours.palette.m3onSurface }
            StyledText {
                text: root.balance ? AgentUsage.formatMoney(root.balance.remaining, root.balance.currency) : ""
                color: (root.balance && root.balance.funded > 0 && root.balance.remaining / root.balance.funded <= 0.1)
                    ? Colours.palette.m3error : Colours.palette.m3onSurface
                font.bold: true
            }
        }

        Meter {
            Layout.fillWidth: true
            visible: !!root.balance && root.balance.funded > 0
            value: root.balance && root.balance.funded > 0 ? root.balance.remaining / root.balance.funded : -1
            alarming: root.balance && root.balance.funded > 0 && root.balance.remaining / root.balance.funded <= 0.1
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.balance ? AgentUsage.balanceDetailText(root.balance) : ""
            color: Colours.palette.m3outline
            font.pointSize: Tokens.fontSize.small
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.limits.length > 0
        spacing: Tokens.spacing.small

        StyledText { text: "LIMITS"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }

        Repeater {
            model: root.limits

            delegate: ColumnLayout {
                id: limitRow

                required property var modelData
                readonly property bool alarming: limitRow.modelData.percent >= 0.9
                readonly property real resetMs: AgentUsage.resetMsFor(limitRow.modelData)

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    StyledText { Layout.fillWidth: true; text: limitRow.modelData.title; color: Colours.palette.m3onSurface }
                    StyledText {
                        text: Math.round(limitRow.modelData.percent * 100) + "%"
                        color: limitRow.alarming ? Colours.palette.m3error : Colours.palette.m3onSurface
                        font.pointSize: Tokens.fontSize.small
                    }
                }

                Meter {
                    Layout.fillWidth: true
                    value: limitRow.modelData.percent
                    alarming: limitRow.alarming
                }

                StyledText {
                    visible: limitRow.resetMs > 0
                    text: "Resets in " + AgentUsage.formatDuration(limitRow.resetMs)
                    color: Colours.palette.m3outline
                    font.pointSize: Tokens.fontSize.small
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: root.days.length > 0; color: Colours.palette.m3outlineVariant }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.days.length > 0
        spacing: Tokens.spacing.small

        StyledText { text: "TOKENS BY DAY"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }

        Repeater {
            model: root.days

            delegate: RowLayout {
                id: dayRow

                required property var modelData
                readonly property bool today: String(dayRow.modelData.date || "") === AgentUsage.todayDate()

                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.preferredWidth: Tokens.spacing.extraLarge * 1.5
                    text: AgentUsage.dayLabel(dayRow.modelData.date, dayRow.today)
                    color: dayRow.today ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    font.bold: dayRow.today
                    font.pointSize: Tokens.fontSize.small
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.spacing.small
                    Rectangle { anchors.fill: parent; radius: height / 2; color: Colours.palette.m3surfaceContainerHighest }
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        height: parent.height; radius: height / 2
                        width: Math.max(height, parent.width * Math.min(1, Number(dayRow.modelData.messageCount || 0) / root.dayPeak))
                        color: dayRow.today ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                }

                StyledText {
                    Layout.preferredWidth: Tokens.spacing.extraLarge * 1.5
                    horizontalAlignment: Text.AlignRight
                    text: AgentUsage.formatTokenCount(Number(dayRow.modelData.messageCount || 0))
                    color: dayRow.today ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    font.bold: true
                    font.pointSize: Tokens.fontSize.small
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: root.models.length > 0; color: Colours.palette.m3outlineVariant }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.models.length > 0
        spacing: Tokens.spacing.small

        StyledText { text: "TOKENS BY MODEL"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }

        Repeater {
            model: root.models

            delegate: Item {
                id: modelRow

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: Tokens.spacing.extraLarge * 1.6

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3surfaceContainer
                }

                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: parent.width * Math.min(1, modelRow.modelData.total / Math.max(1, root.models[0].total))
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3secondaryContainer
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }

                StyledText {
                    anchors.left: parent.left; anchors.leftMargin: Tokens.spacing.small
                    anchors.right: modelTokens.left; anchors.rightMargin: Tokens.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: modelRow.modelData.name
                    color: Colours.palette.m3onSurface
                    font.pointSize: Tokens.fontSize.small
                }

                StyledText {
                    id: modelTokens
                    anchors.right: parent.right; anchors.rightMargin: Tokens.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    text: AgentUsage.formatTokenCount(modelRow.modelData.total)
                    color: Colours.palette.m3outline
                    font.bold: true
                    font.pointSize: Tokens.fontSize.small
                }
            }
        }
    }

    component Meter: Item {
        property real value: -1
        property bool alarming: false

        implicitHeight: Tokens.spacing.extraSmall

        Rectangle { anchors.fill: parent; radius: height / 2; color: Colours.palette.m3surfaceContainerHighest }
        Rectangle {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            height: parent.height; radius: height / 2
            width: parent.width * Math.max(0, Math.min(1, parent.value))
            color: parent.alarming ? Colours.palette.m3error : Colours.palette.m3primary
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }
}
