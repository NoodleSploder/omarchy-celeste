pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components"
import "../../services"

// Detail pane for one plugin, opened by resting on its row in the plugins
// list. Today it holds a single switch: whether the plugin appears on the
// Celeste bar.
//
// That switch writes Config.bar.entries. Bar.qml's componentFor() sends any
// id it does not recognise to HostedWidget, which resolves it against the
// host's bar-widget registry -- so an Omarchy plugin id in the entries list
// simply renders on Celeste's bar, no per-plugin support needed here.
//
// New entries land immediately to the right of the date/time -- Celeste's
// "clock" entry. That sits inside the centred section, between the two
// "spacer" boundaries, so a newly shown plugin appears beside the clock
// rather than off in the status cluster.
//
// Successive additions go to the right of each other rather than all
// stacking directly against the clock, so the order they were switched on in
// reads left to right. Plugin ids are namespaced ("omarchy.clock",
// "tmn73.calendar") while Celeste's own entries are bare words ("clock",
// "tray"), which is the same distinction Bar.qml's componentFor() already
// relies on to decide what is a hosted widget.
Item {
    id: root

    required property string pluginId

    readonly property var entry: {
        for (const p of PluginCatalog.enabledList)
            if (p.id === root.pluginId)
                return p;
        return null;
    }

    readonly property string title: root.entry ? root.entry.name : root.pluginId

    readonly property var barEntries: Config.bar.entries || []

    readonly property bool onCelesteBar:
        root.barEntries.some(e => e && e.id === root.pluginId)

    function toggleOnCelesteBar() {
        const next = [];
        let removed = false;
        for (const e of root.barEntries) {
            if (e && e.id === root.pluginId) {
                removed = true;
                continue;
            }
            // Copied rather than referenced: these objects come from the
            // merged config and are about to be serialised back out.
            const copy = {};
            for (const k in e)
                copy[k] = e[k];
            next.push(copy);
        }
        if (!removed) {
            let at = next.findIndex(e => e && e.id === "clock");
            if (at < 0) {
                // No clock on the bar to sit beside; fall back to the end.
                next.push({ id: root.pluginId, enabled: true });
            } else {
                // Step past plugins already switched on, so this one joins
                // the right-hand end of that run instead of jumping the queue.
                while (at + 1 < next.length
                    && next[at + 1]
                    && String(next[at + 1].id).indexOf(".") !== -1)
                    at++;
                next.splice(at + 1, 0, { id: root.pluginId, enabled: true });
            }
        }
        Config.writeBarEntries(next);
    }

    implicitWidth: 300
    implicitHeight: 200

    StyledText {
        id: title

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.title
        font: Tokens.font.body.large
        color: Colours.palette.m3onSurface
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.WordWrap
    }

    StyledText {
        id: subtitle

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        text: root.pluginId
        font: Tokens.font.body.small
        color: Colours.palette.m3outline
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Rectangle {
        id: rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: subtitle.bottom
        anchors.topMargin: Tokens.padding.small
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    // ------------------------------------------------------------- toggle

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.topMargin: Tokens.padding.medium
        implicitHeight: Tokens.sizes.bar.innerWidth

        StyledText {
            anchors.left: parent.left
            anchors.right: switchTrack.left
            anchors.rightMargin: Tokens.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            text: "Show on Celeste bar"
            font: Tokens.font.body.normal
            color: Colours.palette.m3onSurface
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: switchTrack

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Tokens.sizes.bar.innerWidth * 1.3
            implicitHeight: Tokens.sizes.bar.innerWidth * 0.7
            radius: Tokens.rounding.full
            color: root.onCelesteBar
                ? Colours.palette.m3primary
                : Colours.palette.m3surfaceContainerHighest

            Behavior on color {
                CAnim {}
            }

            Rectangle {
                id: knob

                width: parent.height - 6
                height: width
                radius: Tokens.rounding.full
                y: 3
                x: root.onCelesteBar ? parent.width - width - 3 : 3
                color: root.onCelesteBar
                    ? Colours.palette.m3onPrimary
                    : Colours.palette.m3outline

                Behavior on x {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Behavior on color {
                    CAnim {}
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Tokens.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleOnCelesteBar()
            }
        }
    }

    StyledText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: "Shown just right of the date and time. Not every plugin draws a bar widget -- one that has none will take no space."
        font: Tokens.font.body.small
        color: Colours.palette.m3outline
        wrapMode: Text.WordWrap
    }
}
