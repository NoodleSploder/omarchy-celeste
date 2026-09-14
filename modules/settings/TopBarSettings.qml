pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../components"
import "../../services"

// Top Bar settings: how the bar's three sections are sized.
//
// Which entries land in which section is NOT set here -- that still comes
// from the order of `bar.entries` and its two spacer boundaries, and
// rearranging elements by drag and drop is deliberately a later job. This
// page only sizes the sections, which is the half that fixes the centred
// group drifting as the focused window's title changes length.
//
// Every value written goes through Config.writeBarSections, which merges into
// the user's shell.json rather than replacing it.
Item {
    id: root

    readonly property var cfg: Config.bar.sections || ({})
    readonly property string mode: String(root.cfg.mode || "auto")
    readonly property var percent: root.cfg.percent || ({})
    readonly property var fixed: root.cfg.fixed || ({})

    readonly property var keys: ["left", "middle", "right"]

    function percentOf(key) {
        return Math.max(0, Math.min(100, Number(root.percent[key]) || 0));
    }

    // A fixed width is either a pixel count or the sentinel "remaining".
    function fixedOf(key) {
        const v = root.fixed[key];
        return String(v) === "remaining" ? "remaining" : Math.max(0, Number(v) || 0);
    }

    function isRemaining(key) {
        return root.fixedOf(key) === "remaining";
    }

    // --------------------------------------------------------- orientation
    //
    // Every entry except the two section-boundary spacers is eligible: this
    // never touches bar.entries' order or its enabled flag, only which of
    // Portrait / Landscape / Both / Off Config.entryVisibility() reports for
    // it, which Bar.qml's sectionEntriesFor()/hostedBarEntriesFor() read to
    // decide whether a given monitor (screen.height > screen.width) shows it.
    // Both is the default -- unset, this list changes nothing from today.
    readonly property var orientationEntries: (Config.bar.entries || [])
        .filter(e => e && e.enabled && e.id !== "spacer")

    // Celeste's own bare-word entries get a hand-written label; anything else
    // is a plugin id, and PluginCatalog already carries the human name Omarchy
    // itself shows for it (see PluginDetail.qml, which resolves the same way).
    readonly property var builtinLabels: ({
        logo: "Logo",
        activeWindow: "Active window title",
        workspaces: "Workspace switcher",
        clock: "Date / time",
        tray: "System tray",
        runningApps: "Running apps",
        statusIcons: "Status icons",
        power: "Power menu"
    })

    function labelFor(id) {
        if (root.builtinLabels[id])
            return root.builtinLabels[id];
        for (const p of PluginCatalog.enabledList)
            if (p.id === id)
                return p.name;
        return id;
    }

    function visibilityFor(id) {
        const entry = root.orientationEntries.find(e => e.id === id);
        return Config.entryVisibility(entry || null);
    }

    // Always writes the whole sections object: the config merge replaces
    // objects key by key, so sending a partial one would drop the mode or the
    // other unit's values.
    function persist(mode, percent, fixed) {
        Config.writeBarSections({
            mode: mode,
            percent: percent,
            fixed: fixed
        });
    }

    function snapshotPercent() {
        const out = {};
        for (const k of root.keys)
            out[k] = root.percentOf(k);
        return out;
    }

    function snapshotFixed() {
        const out = {};
        for (const k of root.keys)
            out[k] = root.fixedOf(k);
        return out;
    }

    function setMode(mode) {
        root.persist(mode, root.snapshotPercent(), root.snapshotFixed());
    }

    function bumpPercent(key, delta) {
        const next = root.snapshotPercent();
        next[key] = Math.max(0, Math.min(100, next[key] + delta));
        root.persist(root.mode, next, root.snapshotFixed());
    }

    function bumpFixed(key, delta) {
        const next = root.snapshotFixed();
        if (next[key] === "remaining")
            return;
        next[key] = Math.max(0, next[key] + delta);
        root.persist(root.mode, root.snapshotPercent(), next);
    }

    function toggleRemaining(key) {
        const next = root.snapshotFixed();
        next[key] = next[key] === "remaining" ? 250 : "remaining";
        root.persist(root.mode, root.snapshotPercent(), next);
    }

    // ------------------------------------------------ collapsible groups

    function setCollapse(key, value) {
        const next = {
            statusIcons: Config.bar.collapse.statusIcons === true,
            runningApps: Config.bar.collapse.runningApps === true
        };
        next[key] = value;
        Config.writeBarCollapse(next);
    }

    // A Flickable, not a plain ColumnLayout anchored to fill: the portrait
    // list below grows with however many entries are enabled, and the panel
    // itself (SettingsContent.qml) is a fixed height -- content that outgrows
    // it needs to scroll rather than spill past the panel's bottom edge or
    // get silently clipped.
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledText {
                text: "Section widths"
                font: Tokens.font.body.normal
                color: Colours.palette.m3onSurface
            }

            Item {
                Layout.fillWidth: true
            }

            Choice {
                label: "Auto"
                active: root.mode === "auto"
                onClicked: root.setMode("auto")
            }

            Choice {
                label: "Percentage"
                active: root.mode === "percent"
                onClicked: root.setMode("percent")
            }

            Choice {
                label: "Fixed"
                active: root.mode === "fixed"
                onClicked: root.setMode("fixed")
            }
        }

        Repeater {
            // Auto sizes itself from what the sections contain, so there is
            // nothing per-section to set.
            model: root.mode === "auto" ? [] : root.keys

            delegate: RowLayout {
                id: row

                required property string modelData
                readonly property bool remaining: root.mode === "fixed" && root.isRemaining(row.modelData)

                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.preferredWidth: 70
                    text: row.modelData.charAt(0).toUpperCase() + row.modelData.slice(1)
                    font: Tokens.font.body.normal
                    color: Colours.palette.m3onSurface
                }

                Stepper {
                    enabled: !row.remaining
                    value: row.remaining
                        ? "--"
                        : root.mode === "percent"
                            ? root.percentOf(row.modelData) + "%"
                            : root.fixedOf(row.modelData) + "px"
                    onDecrement: root.mode === "percent"
                        ? root.bumpPercent(row.modelData, -5)
                        : root.bumpFixed(row.modelData, -25)
                    onIncrement: root.mode === "percent"
                        ? root.bumpPercent(row.modelData, 5)
                        : root.bumpFixed(row.modelData, 25)
                }

                // Only meaningful in fixed mode -- a percentage already says
                // how the space is divided, so there is nothing left over to
                // claim.
                Choice {
                    visible: root.mode === "fixed"
                    label: "Remaining"
                    active: row.remaining
                    onClicked: root.toggleRemaining(row.modelData)
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
        }

        StyledText {
            text: "Orientation"
            font: Tokens.font.body.normal
            color: Colours.palette.m3onSurface
        }

        StyledText {
            Layout.fillWidth: true
            text: "Show each item on portrait monitors, landscape ones, both (the default), or neither."
            font: Tokens.font.body.small
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.orientationEntries

            delegate: RowLayout {
                id: orientationRow

                required property var modelData
                readonly property var vis: root.visibilityFor(orientationRow.modelData.id)

                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.labelFor(orientationRow.modelData.id)
                    font: Tokens.font.body.normal
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                Choice {
                    label: "Both"
                    active: orientationRow.vis.portrait && orientationRow.vis.landscape
                    onClicked: Config.writeBarEntryVisibility(orientationRow.modelData.id, true, true)
                }

                Choice {
                    label: "Portrait"
                    active: orientationRow.vis.portrait && !orientationRow.vis.landscape
                    onClicked: Config.writeBarEntryVisibility(orientationRow.modelData.id, true, false)
                }

                Choice {
                    label: "Landscape"
                    active: !orientationRow.vis.portrait && orientationRow.vis.landscape
                    onClicked: Config.writeBarEntryVisibility(orientationRow.modelData.id, false, true)
                }

                Choice {
                    label: "Off"
                    active: !orientationRow.vis.portrait && !orientationRow.vis.landscape
                    onClicked: Config.writeBarEntryVisibility(orientationRow.modelData.id, false, false)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
        }

        StyledText {
            text: "Collapsible icon groups"
            font: Tokens.font.body.normal
            color: Colours.palette.m3onSurface
        }

        StyledText {
            Layout.fillWidth: true
            text: "Collapsible starts the group behind a single circular icon; hover or click it to expand, move away to collapse it again."
            font: Tokens.font.body.small
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledText {
                Layout.fillWidth: true
                text: "System icons"
                font: Tokens.font.body.normal
                color: Colours.palette.m3onSurface
            }

            Choice {
                label: "Expanded"
                active: Config.bar.collapse.statusIcons !== true
                onClicked: root.setCollapse("statusIcons", false)
            }

            Choice {
                label: "Collapsible"
                active: Config.bar.collapse.statusIcons === true
                onClicked: root.setCollapse("statusIcons", true)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledText {
                Layout.fillWidth: true
                text: "Running apps"
                font: Tokens.font.body.normal
                color: Colours.palette.m3onSurface
            }

            Choice {
                label: "Expanded"
                active: Config.bar.collapse.runningApps !== true
                onClicked: root.setCollapse("runningApps", false)
            }

            Choice {
                label: "Collapsible"
                active: Config.bar.collapse.runningApps === true
                onClicked: root.setCollapse("runningApps", true)
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.mode === "auto"
                ? "The middle takes exactly the width its widgets need, so nothing there gets squeezed out as you add them. The window title on the left shortens to make room."
                : "The middle section stays centred on the screen whatever the other two contain, and each section clips instead of pushing its neighbours along."
            font: Tokens.font.body.small
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }
        }
    }

    // ---------------------------------------------------------- components

    // A pill that reads as on or off. Used for both the mode selector and the
    // per-section "Remaining" switch, since they behave identically.
    component Choice: Rectangle {
        id: choice

        required property string label
        property bool active: false
        signal clicked

        implicitWidth: choiceText.implicitWidth + Tokens.padding.large * 2
        implicitHeight: Tokens.sizes.bar.innerWidth * 0.8
        radius: Tokens.rounding.full
        color: choice.active
            ? Colours.palette.m3primary
            : choiceArea.containsMouse ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh

        Behavior on color {
            CAnim {}
        }

        StyledText {
            id: choiceText

            anchors.centerIn: parent
            text: choice.label
            font: Tokens.font.body.small
            color: choice.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        }

        MouseArea {
            id: choiceArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.clicked()
        }
    }

    // Minus / value / plus. Click-driven rather than an editable field -- see
    // the note at the top of SettingsContent.qml about keyboard focus.
    component Stepper: RowLayout {
        id: stepper

        required property string value
        property bool enabled: true
        signal decrement
        signal increment

        spacing: Tokens.spacing.small

        StepButton {
            glyph: "remove"
            enabled: stepper.enabled
            onClicked: stepper.decrement()
        }

        StyledText {
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignHCenter
            text: stepper.value
            font: Tokens.font.body.normal
            color: stepper.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
        }

        StepButton {
            glyph: "add"
            enabled: stepper.enabled
            onClicked: stepper.increment()
        }
    }

    component StepButton: Rectangle {
        id: stepButton

        required property string glyph
        property bool enabled: true
        signal clicked

        implicitWidth: Tokens.sizes.bar.innerWidth * 0.8
        implicitHeight: Tokens.sizes.bar.innerWidth * 0.8
        radius: Tokens.rounding.full
        opacity: stepButton.enabled ? 1 : 0.35
        color: stepArea.containsMouse && stepButton.enabled
            ? Colours.palette.m3surfaceContainerHighest
            : Colours.palette.m3surfaceContainerHigh

        Behavior on color {
            CAnim {}
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: stepButton.glyph
            fontStyle: Tokens.font.icon.small
            color: Colours.palette.m3onSurface
        }

        MouseArea {
            id: stepArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: stepButton.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: stepButton.clicked()
        }
    }

    // Same track/knob switch PluginDetail.qml uses for "Show on Celeste bar",
    // generalised for reuse here rather than duplicated.
}
