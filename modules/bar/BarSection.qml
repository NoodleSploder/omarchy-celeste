pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"

// One of the bar's three sections.
//
// Sizing and positioning are set by the caller (see Bar.qml's barContent):
// left is anchored left, right anchored right, middle anchored to the screen
// centre, and each width comes from Config.bar.sections. This item only lays
// its own entries out inside whatever box it is given.
//
// `clip` is the point of the exercise. A section that overflows used to push
// its neighbours along -- a long window title in the left section walked the
// centred group off-centre -- so content that does not fit is now cut off at
// the section boundary instead of displacing anything.
Item {
    id: root

    // Entry records ({ id, enabled, ... }) for this section, already filtered
    // and in order.
    property var entries: []

    // Resolves an entry id to its Component. Passed in rather than imported
    // because the components live in Bar.qml's own scope; the function is
    // called plainly (it reads no `this`), so handing it over as a value is
    // safe.
    property var resolve: null

    // Which end fills first when the content is narrower than the section.
    // The right section hugs the right edge so its icons stay against the
    // screen edge rather than floating in the middle of their box.
    property int alignment: Qt.AlignLeft

    // What this section's entries actually need. Independent of the width the
    // section is given -- the inner row's implicit size comes from its
    // children, never from the box around it -- so "auto" sizing can read it
    // without a circular binding.
    readonly property real contentWidth: layout.implicitWidth

    clip: true

    RowLayout {
        id: layout

        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // Anchored to the section's own edge rather than filling it, and only
        // as wide as the section while the content fits. Once the content is
        // wider, the row keeps its natural width and overflows past the
        // anchored edge's opposite side, so the clip eats the end that matters
        // least: a too-narrow right section loses its leftmost entries and
        // keeps the status icons against the screen edge, instead of running
        // off the right and dropping them.
        anchors.left: root.alignment === Qt.AlignLeft ? parent.left : undefined
        anchors.right: root.alignment === Qt.AlignRight ? parent.right : undefined
        anchors.horizontalCenter: root.alignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
        width: Math.max(implicitWidth, root.width)

        spacing: Tokens.spacing.medium

        // Packing is done with fillWidth spacers on one or both sides, NOT by
        // flipping layoutDirection: RightToLeft would also reverse the entry
        // order, so the right section came out mirrored (power first, plugins
        // last) the first time this was written. Entries always read
        // left-to-right; only which end absorbs the slack changes.
        Item {
            Layout.fillWidth: root.alignment === Qt.AlignHCenter || root.alignment === Qt.AlignRight
        }

        Repeater {
            model: root.entries

            delegate: Loader {
                id: entry

                required property var modelData
                readonly property string entryId: entry.modelData.id

                // A zero-width entry must leave the layout entirely, not
                // just draw nothing: a RowLayout still puts its spacing on
                // either side of a visible child, so a plugin with no bar
                // widget of its own would open a gap the width of two gaps
                // where nothing is drawn. Spacers are the exception -- they
                // are legitimately zero-width and do their work through
                // fillWidth.
                visible: entry.entryId === "spacer" || entry.implicitWidth > 0

                Layout.alignment: Qt.AlignVCenter
                // Any spacer beyond the two that mark the section boundaries
                // still works as an in-section filler.
                Layout.fillWidth: entry.entryId === "spacer"
                // Workspaces is loaded synchronously so the bar does not
                // visibly reflow on startup.
                asynchronous: entry.entryId !== "workspaces"

                sourceComponent: root.resolve ? root.resolve(entry.entryId) : null

                // HostedWidget needs the whole entry (its id and any inline
                // settings); Celeste's own entries ignore it.
                onLoaded: {
                    if (item && "modelData" in item)
                        item.modelData = entry.modelData;
                }
            }
        }

        Item {
            Layout.fillWidth: root.alignment === Qt.AlignHCenter || root.alignment === Qt.AlignLeft
        }
    }
}
