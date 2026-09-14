pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../components"
import "../../services"

// The enabled plugins as a vertical list, for the left slideout.
//
// Same data and the same icon rules as modules/bar/PluginsStrip.qml -- that
// one is a horizontal row of bare icons under the bar, this is a named list
// in a side panel, so the layout differs but neither is the other's
// container. Icons are shown unrecoloured for the reason PluginsStrip and
// modules/bar/components/Plugins.qml both document at length: MultiEffect
// colorization renders solid black on this machine, confirmed by probe
// rather than assumed, so a plugin's own icon.png is drawn as shipped and
// everything else falls back to the theme-coloured "extension" glyph.
Item {
    id: root

    signal activated(string id)

    property string query: ""

    // Category -> glyph. No manifest carries an icon field and only two
    // installed plugins ship an icon.png, so barWidget.category is the only
    // real signal available; mapping it at least makes rows distinguishable
    // instead of an identical stack of puzzle pieces. Anything uncategorised
    // still falls back to "extension".
    readonly property var categoryGlyphs: ({
        "AI": "smart_toy",
        "Audio": "volume_up",
        "Compositor": "desktop_windows",
        "Development": "code",
        "Files": "folder",
        "Fun": "celebration",
        "Hardware": "memory",
        "Home": "home",
        "Info": "info",
        "Layout": "space_bar",
        "Media": "play_arrow",
        "Network": "wifi",
        "Productivity": "checklist",
        "Status": "notifications",
        "System": "settings",
        "Time": "schedule"
    })

    function glyphFor(entry) {
        return root.categoryGlyphs[entry.category] || "extension";
    }

    readonly property var pluginList: {
        const all = PluginCatalog.enabledList;
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return all;
        // Matches the id too, so searching "omarchy" or a vendor prefix finds
        // things whose display name does not mention it.
        return all.filter(p =>
            String(p.name).toLowerCase().indexOf(q) !== -1
            || String(p.id).toLowerCase().indexOf(q) !== -1);
    }

    implicitWidth: 320
    implicitHeight: 460

    StyledText {
        id: title

        anchors.left: parent.left
        anchors.top: parent.top
        text: "Plugins"
        font: Tokens.font.body.large
        color: Colours.palette.m3onSurface
    }

    Rectangle {
        id: rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.topMargin: Tokens.padding.small
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    // The surface this sits on only asks the compositor for keyboard input
    // while a left panel is open -- see Bar.qml's wantsKeyboard priming. A
    // field here without that would take focus within the QML scene and still
    // never see a keystroke.
    Rectangle {
        id: search

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.topMargin: Tokens.padding.small
        implicitHeight: Tokens.sizes.bar.innerWidth
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHigh

        MaterialIcon {
            id: searchIcon

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            fontStyle: Tokens.font.icon.small
            color: Colours.palette.m3onSurfaceVariant
        }

        TextInput {
            id: searchInput

            anchors.left: searchIcon.right
            anchors.leftMargin: Tokens.spacing.small
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter

            font: Tokens.font.body.normal
            color: Colours.palette.m3onSurface
            selectionColor: Colours.palette.m3primary
            selectedTextColor: Colours.palette.m3onPrimary
            clip: true

            focus: true
            onTextChanged: root.query = text
            // Escape clears rather than closing: the panel's own dismissal is
            // the rail button and clicking away, and a half-typed query is
            // the thing the key most obviously undoes.
            Keys.onEscapePressed: searchInput.text = ""

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text === ""
                text: "Search plugins"
                color: Colours.palette.m3outline
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.pluginList.length === 0
        text: root.query.trim() === "" ? "No plugins enabled" : "No matches"
        color: Colours.palette.m3outline
    }

    ListView {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: search.bottom
        anchors.topMargin: Tokens.padding.small
        anchors.bottom: parent.bottom

        clip: true
        spacing: Tokens.spacing.small
        model: root.pluginList
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entry

            required property var modelData

            width: ListView.view ? ListView.view.width : 0
            implicitHeight: Tokens.sizes.bar.innerWidth + Tokens.padding.small * 2
            radius: Tokens.rounding.large
            color: entryArea.containsMouse ? Colours.palette.m3secondaryContainer : "transparent"

            Behavior on color {
                CAnim {}
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.medium

                Item {
                    Layout.preferredWidth: Tokens.sizes.bar.innerWidth
                    Layout.preferredHeight: Tokens.sizes.bar.innerWidth

                    Image {
                        id: icon

                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.small
                        source: entry.modelData.iconPath
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        visible: icon.status === Image.Ready
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: icon.status !== Image.Ready
                        text: root.glyphFor(entry.modelData)
                        color: entryArea.containsMouse
                            ? Colours.palette.m3onSecondaryContainer
                            : Colours.palette.m3onSurfaceVariant
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: entry.modelData.name || entry.modelData.id
                    font: Tokens.font.body.normal
                    color: entryArea.containsMouse
                        ? Colours.palette.m3onSecondaryContainer
                        : Colours.palette.m3onSurface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            MouseArea {
                id: entryArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Click still launches; the detail pane is the hover job, so
                // the two never compete for the same gesture.
                onClicked: root.activated(entry.modelData.id)

                onEntered: detailDwell.restart()
                onExited: detailDwell.stop()
            }

            // Resting on a row opens its detail pane. Same dwell as the rail
            // itself: long enough that running the pointer down the list to
            // reach one row does not flash a pane for every row on the way.
            Timer {
                id: detailDwell

                interval: LeftPanel.dwell
                onTriggered: LeftPanel.showDetail(entry.modelData.id)
            }
        }
    }
}
