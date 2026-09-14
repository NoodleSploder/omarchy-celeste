pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../components"
import "../../services"

// Stage 3 of the right-edge drag-out panel: the notification drawer.
//
// Design follows Caelestia's sidebar notification list
// (modules/sidebar/Notif.qml + NotifGroupList.qml in the backup): a count
// header with per-list controls, then compact rows of summary-over-body with
// a relative timestamp, critical ones lifted onto the secondary container
// colour, and swipe-sideways-to-dismiss. What is NOT ported is the machinery
// underneath it -- LazyListView, ScriptModel, TransformWatcher, Props and
// ScreenState all come from Caelestia's native C++ plugin, which Celeste
// categorically cannot use (ATTRIBUTION.md: "Celeste requires no native
// code"). A plain ListView over services/Notifs.qml's `entries` replaces
// them; the history Omarchy keeps is capped at 10 entries plus whatever
// toasts are live, so nothing here needs the virtualisation that machinery
// exists to provide.
ColumnLayout {
    id: root

    // Height-only anchors to the Loader that instantiates this (modules/
    // sidepanel/SidePanel.qml's notifsColumn): that Loader's own height is
    // driven by root.notifsRowHeight there (always full screen height while
    // notifications is open at all), but a Loader does not automatically
    // resize its loaded item to match its own size -- without this, the
    // Loader would grow taller while this content stayed clumped at its
    // natural size, leaving a dead gap below it. WIDTH is deliberately left
    // alone: it
    // still comes from this ColumnLayout's own implicit sizing (pinned via
    // the header row's Layout.preferredWidth below, the usual
    // implicitWidth-on-a-Layout-is-silently-overwritten workaround
    // documented in CLAUDE.md) -- anchoring width here too would make the
    // Loader's width depend on this item's width while this item's width
    // depends on the Loader's, a circular binding.
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    spacing: Tokens.spacing.small

    // ------------------------------------------------------------- header

    RowLayout {
        Layout.fillWidth: true
        // The width pin lives here rather than on the ColumnLayout root: a
        // plain implicitWidth on a Layout root is silently recomputed from
        // its children on every relayout (documented at length in CLAUDE.md),
        // so it must be set on an always-visible CHILD to take effect. This
        // header is always visible, including in the empty state below.
        Layout.preferredWidth: Tokens.sizes.notifs.width
        spacing: Tokens.spacing.small

        StyledText {
            text: "Notifications"
            font: Tokens.font.body.large
            color: Colours.palette.m3onSurface
        }

        // Count badge, hidden at zero rather than showing "0".
        Rectangle {
            visible: Notifs.count > 0
            implicitWidth: Math.max(Tokens.sizes.notifs.badge, badgeText.implicitWidth + Tokens.padding.small)
            implicitHeight: Tokens.sizes.notifs.badge
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary

            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: Notifs.count
                color: Colours.palette.m3onPrimary
                font: Tokens.font.body.small
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // Do-not-disturb. Routed through Omarchy's own IPC (see
        // Notifs.toggleDnd) so the indicators plugin and the
        // omarchy-toggle-notification-silencing CLI stay in step with it.
        HeaderButton {
            icon: Notifs.dnd ? "notifications_off" : "notifications_active"
            active: Notifs.dnd
            onClicked: Notifs.toggleDnd()
        }

        HeaderButton {
            icon: "clear_all"
            enabled: Notifs.count > 0
            onClicked: Notifs.clearAll()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    // -------------------------------------------------------------- empty

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Tokens.sizes.osd.sliderHeight
        visible: Notifs.count === 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "notifications_none"
                fontStyle: Tokens.font.icon.large
                color: Colours.palette.m3outline
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Nothing to catch up on"
                color: Colours.palette.m3outline
            }
        }
    }

    // --------------------------------------------------------------- list

    ListView {
        id: list

        Layout.fillWidth: true
        // Fills whatever height the tall/full tier above has given this
        // panel (see NotifList's root anchors comment), but never shrinks
        // below its own natural content size -- a single notification still
        // gets a short list rather than a bare minimum-height sliver, and
        // this is also what the list falls back to if it's ever embedded
        // somewhere that does NOT stretch it. Scrolling (not growing the
        // whole card off-screen) is what handles more content than fits.
        Layout.fillHeight: true
        Layout.minimumHeight: Math.min(contentHeight, Tokens.sizes.osd.sliderHeight * 2.6)
        visible: Notifs.count > 0

        clip: true
        spacing: Tokens.spacing.small
        model: Notifs.entries
        boundsBehavior: Flickable.StopAtBounds

        delegate: NotifRow {}
    }

    // ---------------------------------------------------------- components

    component HeaderButton: Rectangle {
        id: btn

        required property string icon
        property bool active: false
        property bool enabled: true
        signal clicked

        implicitWidth: Tokens.sizes.notifs.badge + Tokens.padding.small * 2
        implicitHeight: Tokens.sizes.notifs.badge + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        opacity: btn.enabled ? 1 : 0.35
        color: btn.active
            ? Colours.palette.m3primaryContainer
            : btnArea.containsMouse ? Colours.palette.m3surfaceContainerHighest : "transparent"

        Behavior on color {
            CAnim {}
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            fontStyle: Tokens.font.icon.small
            color: btn.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component NotifRow: Item {
        id: rowItem

        required property var modelData
        required property int index

        readonly property bool critical: Notifs.isCritical(rowItem.modelData)
        readonly property bool actionable: Notifs.hasAction(rowItem.modelData)

        width: ListView.view ? ListView.view.width : 0
        implicitHeight: card.implicitHeight

        // Swipe sideways past a fraction of the row's width to dismiss --
        // Caelestia's own gesture (NotifGroupList.qml releases at
        // Config.notifs.clearThreshold of the width, snapping back below
        // that). Held on the wrapper rather than the card so the card can
        // keep its own hover/click handling underneath.
        Rectangle {
            id: card

            x: dragHandle.offset
            width: parent.width
            implicitHeight: content.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            opacity: 1 - Math.min(1, Math.abs(dragHandle.offset) / (parent.width * 0.6))

            color: rowItem.critical
                ? Colours.palette.m3secondaryContainer
                : rowArea.containsMouse
                    ? Colours.palette.m3surfaceContainerHighest
                    : Colours.palette.m3surfaceContainerHigh

            Behavior on color {
                CAnim {}
            }

            Behavior on x {
                enabled: !dragHandle.dragging
                Anim {
                    type: Anim.FastSpatial
                }
            }

            // Urgency marker. The container colour alone is not enough: in
            // themes where m3secondaryContainer sits close to
            // m3surfaceContainerHigh (this machine's does) a critical row is
            // nearly indistinguishable from a normal one, which is the one
            // distinction in this list that must never be subtle. A solid
            // accent stripe reads at a glance in any theme.
            Rectangle {
                visible: rowItem.critical
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.padding.small
                implicitWidth: 3
                radius: Tokens.rounding.full
                color: Colours.palette.m3error
            }

            RowLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: rowItem.critical
                    ? Tokens.padding.medium + Tokens.spacing.small
                    : Tokens.padding.medium
                spacing: Tokens.spacing.small

                // Sender image if the record carries one (Omarchy copies the
                // sender's original next to the record, because the original
                // does not outlive the notification), else the app's themed
                // icon, else a generic bell. Each step only renders when the
                // one before it produced nothing.
                Item {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Tokens.sizes.bar.innerWidth * 0.7
                    implicitHeight: Tokens.sizes.bar.innerWidth * 0.7

                    Image {
                        id: notifImage
                        anchors.fill: parent
                        source: Notifs.imageSource(rowItem.modelData)
                        visible: source != "" && status === Image.Ready
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: width
                        sourceSize.height: height
                        asynchronous: true
                    }

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        visible: !notifImage.visible && source != "" && status === Image.Ready
                        source: {
                            const name = String(rowItem.modelData.appIcon || "");
                            // Empty-string fallback, matching Apps.qml:
                            // a missing icon yields "" and this Image stays
                            // hidden so the glyph below shows instead.
                            return name ? Quickshell.iconPath(name, "") : "";
                        }
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: width
                        sourceSize.height: height
                        asynchronous: true
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !notifImage.visible && !appIcon.visible
                        text: "notifications"
                        fontStyle: Tokens.font.icon.small
                        color: rowItem.critical
                            ? Colours.palette.m3onSecondaryContainer
                            : Colours.palette.m3onSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: rowItem.modelData.summary || Notifs.appName(rowItem.modelData)
                            font: Tokens.font.body.normal
                            color: rowItem.critical
                                ? Colours.palette.m3onSecondaryContainer
                                : Colours.palette.m3onSurface
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            text: Notifs.timeAgo(rowItem.modelData)
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        // Bodies arrive with hard newlines that would make
                        // row heights jump around; collapse them and let
                        // wrapping decide the shape instead.
                        text: String(rowItem.modelData.body || "").replace(/\n/g, " ")
                        visible: text.length > 0
                        color: rowItem.critical
                            ? Colours.palette.m3onSecondaryContainer
                            : Colours.palette.m3outline
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    StyledText {
                        text: Notifs.appName(rowItem.modelData)
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                        opacity: 0.8
                    }
                }

                // Dismiss, on hover only -- a permanently visible X on every
                // row would compete with the content for attention in a list
                // this narrow.
                MaterialIcon {
                    Layout.alignment: Qt.AlignTop
                    text: "close"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: rowArea.containsMouse || closeArea.containsMouse ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -Tokens.padding.small
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismiss(rowItem.modelData)
                    }
                }
            }

            // Declared AFTER the content it shares space with, deliberately
            // and unusually: this one must NOT win the hit-test over the
            // close button above. It does not, because closeArea is a
            // descendant of an earlier sibling only in paint terms -- so the
            // margins below keep this area clear of it. (See CLAUDE.md on
            // sibling order being real input z-order: the general rule is
            // "background catchers go first", and the exception here is that
            // this one is not a background catcher, it is the row's own
            // click/drag target and the close button sits on top of it.)
            MouseArea {
                id: rowArea

                anchors.fill: parent
                anchors.rightMargin: Tokens.sizes.bar.innerWidth
                hoverEnabled: true
                cursorShape: rowItem.actionable
                    ? (dragHandle.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor)
                    : (dragHandle.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor)

                onPressed: mouse => dragHandle.begin(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        dragHandle.move(mouse.x);
                }
                onReleased: dragHandle.release()
                onCanceled: dragHandle.release()

                onClicked: {
                    // A click that was really the end of a swipe must not
                    // also fire the notification's action.
                    if (dragHandle.moved)
                        return;
                    if (rowItem.actionable)
                        Notifs.invoke(rowItem.modelData);
                }
            }
        }

        // Swipe state, kept out of the MouseArea so both the card's x binding
        // and the click guard can read it.
        QtObject {
            id: dragHandle

            property real offset: 0
            property real startX: 0
            property bool dragging: false
            property bool moved: false

            function begin(x) {
                dragHandle.startX = x;
                dragHandle.dragging = true;
                dragHandle.moved = false;
            }

            function move(x) {
                dragHandle.offset = x - dragHandle.startX;
                if (Math.abs(dragHandle.offset) > 4)
                    dragHandle.moved = true;
            }

            function release() {
                dragHandle.dragging = false;
                if (Math.abs(dragHandle.offset) > rowItem.width * 0.35)
                    Notifs.dismiss(rowItem.modelData);
                else
                    dragHandle.offset = 0;
            }
        }
    }
}
