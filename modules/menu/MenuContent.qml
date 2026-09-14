pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../core"
import "../../components"
import "../../services"

// Omarchy's menu data (services/OmarchyMenu.qml) rendered as a Caelestia-style
// launcher: a scrolling list of two-line rows with the search field pinned to
// the BOTTOM, not the top -- the same arrangement as the real Caelestia
// launcher's modules/launcher/Content.qml (list anchored above a bottom
// SearchBar), which is what this was asked to match.
//
// Deliberately an Item root rather than a ColumnLayout: a Layout recomputes
// its own implicitWidth from its children every relayout and silently
// discards the width set on it (see CLAUDE.md), and this panel needs a fixed
// launcher width. Anchoring by hand also mirrors how Caelestia's own Content
// lays out the list against the search bar.
//
// Icons come from two different places and cannot share one renderer: menu
// entries carry literal Nerd Font glyphs out of omarchy-menu.jsonc (so they
// need Tokens.font.mono, NOT MaterialIcon's Material Symbols face), while app
// rows carry a freedesktop icon name that resolves to a themed image.
Item {
    id: root

    readonly property int rowHeight: Tokens.sizes.launcher.itemHeight
    readonly property int gap: Tokens.spacing.medium
    // Six rows before it starts scrolling: enough that the common categories
    // all fit without the panel growing taller than the screen once a search
    // matches half the tree (root alone is ~10 entries, a search can be 100+).
    readonly property int maxListHeight: root.rowHeight * 6

    implicitWidth: Tokens.sizes.launcher.itemWidth
    implicitHeight: crumb.height + (crumb.visible ? root.gap : 0) + list.height + root.gap + search.height

    // ------------------------------------------------------------ breadcrumb

    Item {
        id: crumb

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !OmarchyMenu.atRoot && OmarchyMenu.query.trim() === ""
        height: visible ? Tokens.spacing.extraLarge : 0

        StyledRect {
            id: backButton

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: parent.height
            implicitHeight: parent.height
            radius: Tokens.rounding.full
            color: backArea.containsMouse ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: "chevron_left"
                color: backArea.containsMouse ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: OmarchyMenu.back()
            }
        }

        // Ancestors dimmed, the route you are actually in bold -- the back
        // button above says where you'd land, so repeating the current title
        // inside it (an earlier pass did) just printed "Apps  Apps".
        Row {
            anchors.left: backButton.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: {
                    const trail = OmarchyMenu.routeStack.slice(1, -1).map(id => {
                        const e = OmarchyMenu.items[id];
                        return e ? (e.title || e.label) : id;
                    });
                    return trail.length > 0 ? trail.join("  ›  ") + "  ›  " : "";
                }
                color: Colours.palette.m3outline
                font.pointSize: Tokens.fontSize.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: OmarchyMenu.currentTitle
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.fontSize.small
                font.bold: true
            }
        }
    }

    // ------------------------------------------------------------------ list

    ListView {
        id: list

        anchors.top: crumb.bottom
        anchors.topMargin: crumb.visible ? root.gap : 0
        anchors.left: parent.left
        anchors.right: parent.right

        height: Math.min(root.maxListHeight, Math.max(root.rowHeight, contentHeight))

        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: OmarchyMenu.selected
        model: OmarchyMenu.visibleRows

        // Keyboard selection can walk past the visible window; keep the
        // cursor on screen without yanking the list around when it doesn't
        // have to move.
        Connections {
            target: OmarchyMenu
            function onSelectedChanged(): void {
                list.positionViewAtIndex(OmarchyMenu.selected, ListView.Contain);
            }
        }

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool current: row.index === OmarchyMenu.selected
            readonly property bool isApp: row.modelData.kind === "app"
            // Menu entries have no descriptions of their own (checked: the
            // JSONC has none at all), so during a search their trail through
            // the tree stands in -- which is also what makes a hit from four
            // levels deep readable.
            readonly property string subtitle: {
                const description = String(row.modelData.description || "");
                if (description !== "")
                    return description;
                if (OmarchyMenu.query.trim() !== "")
                    return String(row.modelData.path || "");
                return "";
            }

            width: list.width
            height: root.rowHeight

            StyledRect {
                anchors.fill: parent
                anchors.rightMargin: list.interactive ? Tokens.spacing.small : 0
                radius: Tokens.rounding.large
                color: row.current ? Colours.palette.m3secondaryContainer : "transparent"
            }

            Item {
                id: iconSlot

                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.medium
                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: Math.round(root.rowHeight * 0.62)
                implicitHeight: implicitWidth

                IconImage {
                    id: appIcon
                    anchors.fill: parent
                    asynchronous: true
                    visible: row.isApp && source !== ""
                    source: row.isApp ? Quickshell.iconPath(row.modelData.appIcon, "application-x-executable") : ""
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    // nf-fa-circle for an entry with no glyph of its own.
                    text: row.modelData.icon || ""
                    font.family: Tokens.font.mono
                    font.pointSize: Tokens.fontSize.extraLarge
                    color: row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                }
            }

            Column {
                anchors.left: iconSlot.right
                anchors.leftMargin: Tokens.spacing.medium
                anchors.right: trailing.left
                anchors.rightMargin: Tokens.spacing.medium
                anchors.verticalCenter: parent.verticalCenter

                spacing: -1

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.label
                    color: row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font.pointSize: Tokens.fontSize.normal
                }

                StyledText {
                    width: parent.width
                    visible: row.subtitle !== ""
                    elide: Text.ElideRight
                    text: row.subtitle
                    color: row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                    font.pointSize: Tokens.fontSize.small
                    opacity: row.current ? 0.75 : 1
                }
            }

            MaterialIcon {
                id: trailing

                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.medium + (list.interactive ? Tokens.spacing.small : 0)
                anchors.verticalCenter: parent.verticalCenter

                visible: row.modelData.childCount > 0 || row.modelData.provider !== ""
                text: "chevron_right"
                color: row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hover and the keyboard cursor are the same highlight, so
                // moving the mouse over a row makes Enter act on that row.
                onEntered: OmarchyMenu.selected = row.index
                onClicked: OmarchyMenu.activate(row.modelData)
            }
        }
    }

    StyledText {
        anchors.centerIn: list
        visible: OmarchyMenu.visibleRows.length === 0
        text: OmarchyMenu.query.trim() !== "" ? "No matches" : "Nothing here"
        color: Colours.palette.m3outline
        font.pointSize: Tokens.fontSize.small
    }

    // ------------------------------------------------------------- searchbar

    StyledRect {
        id: search

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        implicitHeight: Tokens.spacing.extraLarge * 1.35
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainer

        MaterialIcon {
            id: searchIcon

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.large
            anchors.verticalCenter: parent.verticalCenter

            text: "search"
            color: Colours.palette.m3onSurfaceVariant
        }

        TextInput {
            id: searchInput

            anchors.left: searchIcon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: clearButton.left
            anchors.rightMargin: Tokens.spacing.small
            anchors.verticalCenter: parent.verticalCenter

            color: Colours.palette.m3onSurface
            font.family: Tokens.font.sans
            font.pointSize: Tokens.fontSize.normal
            clip: true
            focus: true

            text: OmarchyMenu.query
            onTextChanged: OmarchyMenu.query = text

            // A declarative `focus: true` alone claims QML's own FocusScope
            // focus but does not reliably request actual Wayland keyboard
            // focus from a WlrKeyboardFocus.OnDemand surface (confirmed live:
            // typing went to the window behind the menu until this was
            // added) -- force it explicitly the moment this content exists,
            // which for a Loader-driven popup is exactly when it's opened.
            Component.onCompleted: searchInput.forceActiveFocus()

            Keys.onUpPressed: OmarchyMenu.moveSelection(-1)
            Keys.onDownPressed: OmarchyMenu.moveSelection(1)
            Keys.onReturnPressed: OmarchyMenu.activateSelected()
            Keys.onEnterPressed: OmarchyMenu.activateSelected()
            Keys.onTabPressed: OmarchyMenu.moveSelection(1)
            Keys.onBacktabPressed: OmarchyMenu.moveSelection(-1)

            Keys.onEscapePressed: {
                if (searchInput.text !== "")
                    searchInput.text = "";
                else if (!OmarchyMenu.atRoot)
                    OmarchyMenu.back();
                else
                    OmarchyMenu.close();
            }

            // Backspace on an empty field climbs back out of a submenu, so
            // the whole drill-down is reachable without leaving the keyboard.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Backspace && searchInput.text === "" && !OmarchyMenu.atRoot) {
                    OmarchyMenu.back();
                    event.accepted = true;
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                visible: searchInput.text === ""
                text: OmarchyMenu.atRoot ? "Search apps and settings…" : "Search…"
                color: Colours.palette.m3outline
                font.pointSize: Tokens.fontSize.normal
            }
        }

        StyledRect {
            id: clearButton

            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.small
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: parent.implicitHeight - Tokens.padding.small * 2
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: clearArea.containsMouse ? Colours.palette.m3secondaryContainer : "transparent"
            opacity: searchInput.text !== "" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: searchInput.text !== ""
                cursorShape: Qt.PointingHandCursor
                onClicked: searchInput.text = ""
            }
        }
    }
}
