pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../../core"
import "../../../components"

// Now-playing summary for the active MPRIS player.
//
// Player choice prefers services.defaultPlayer by identity, then any player that
// is actually playing, then the first available -- so a browser tab that is
// merely paused does not outrank the app you are listening to.
StyledRect {
    id: root

    readonly property var players: Mpris.players ? Mpris.players.values : []

    readonly property var player: {
        const list = root.players;
        if (list.length === 0)
            return null;

        const preferred = String(Config.services.defaultPlayer || "");
        if (preferred)
            for (const p of list)
                if (p && String(p.identity || "").toLowerCase() === preferred.toLowerCase())
                    return p;

        for (const p of list)
            if (p && p.playbackState === MprisPlaybackState.Playing)
                return p;

        return list[0];
    }

    readonly property bool hasMedia: !!player
    readonly property bool playing: hasMedia && player.playbackState === MprisPlaybackState.Playing

    readonly property string trackTitle: hasMedia ? String(player.trackTitle || "") : ""
    readonly property string trackArtist: hasMedia ? String(player.trackArtist || "") : ""

    readonly property string label: {
        if (!root.hasMedia)
            return "";
        if (root.trackArtist && root.trackTitle)
            return `${root.trackArtist} — ${root.trackTitle}`;
        return root.trackTitle || root.trackArtist;
    }

    readonly property int padding: Tokens.padding.small
    readonly property int maxWidth: 260

    color: "transparent"
    radius: Tokens.rounding.full

    implicitWidth: hasMedia ? Math.min(layout.implicitWidth + padding * 2, maxWidth) : 0
    implicitHeight: Tokens.sizes.bar.innerWidth
    visible: hasMedia
    clip: true

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (!root.hasMedia)
                return;
            if (mouse.button === Qt.MiddleButton) {
                if (root.player.canGoNext)
                    root.player.next();
            } else if (root.player.canTogglePlaying) {
                root.player.togglePlaying();
            }
        }
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: root.playing ? "pause" : "play_arrow"
            color: Colours.palette.m3primary
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.maxWidth - Tokens.sizes.bar.innerWidth
            text: root.label
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
            animate: true
        }
    }
}
