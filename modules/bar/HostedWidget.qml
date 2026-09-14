pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

// Renders an Omarchy bar widget inside Celeste.
//
// The host publishes its widget catalogue through PluginBarWidgetRegistryApi,
// documented as being "for third-party full-bar implementations": each entry
// carries a `component` this can load. Reading `registry.widgets` (rather than
// only calling metadataFor) is what creates the binding dependency, so the
// widget reloads when a plugin is enabled or disabled.
//
// After loading, the host's own convention is to assign `bar`, `moduleName` and
// `settings` if the widget declares them -- twice, immediately and via
// Qt.callLater, because some widgets finish wiring themselves a tick later.
Item {
    id: root

    required property string widgetId
    required property var registry
    required property var shell
    required property var settings
    required property int barSize

    // The full bar height, which is not the widget height: panels use it to work
    // out where the bar strip is, so clicks there are forwarded to the bar
    // rather than treated as an outside click that dismisses the panel.
    property int barTotalSize: root.barSize

    // The bar surface that owns this copy, so the owner can pick the instance on
    // the focused monitor when summoning a panel.
    property var hostScreen: null

    // Host the widget purely as an anchor: it stays live so its panel can open,
    // but occupies no width and draws nothing. Useful when Celeste already shows
    // the same information natively -- a calendar panel without a second clock.
    readonly property bool hidden: !!(root.settings && root.settings.hidden)

    // The loaded widget, exposed so the owner can call open()/close() on it.
    readonly property var widgetItem: loader.item

    signal registered(string id, var self)
    signal unregistered(string id, var self)

    readonly property var metadata: root.registry ? root.registry.metadataFor(root.widgetId) : null

    readonly property var widgetComponent: {
        if (!root.registry)
            return null;
        const widgets = root.registry.widgets;
        const entry = widgets ? widgets[root.widgetId] : null;
        return entry ? entry.component : null;
    }

    readonly property bool available: root.widgetComponent !== null

    // 1, not 0: panels position themselves from the anchor's geometry, and a
    // zero-width anchor gives them nothing to centre on -- the panel then falls
    // back to the middle of the screen. The same reason the border exclusion
    // windows are 1x1 rather than 0x0.
    // Omarchy sizes its own bar icons from Style.bar tokens Celeste has no say
    // over -- a 27px slot around a 16px canvas with a 13px glyph -- so a hosted
    // widget renders small and carries ~11px of its own horizontal slack. These
    // two knobs are how Celeste presents them at its own scale without editing
    // anything system-wide:
    //
    //   contentScale enlarges the whole widget, glyph and slot together.
    //   uniformCell is the width every icon-sized widget REPORTS, whatever its
    //   own padding happens to be.
    //
    // The uniform cell is what makes them evenly spaced. Measured on real
    // widgets, their natural widths run 21 to 33px for an identical 16px glyph
    // canvas -- each pads its slot differently -- so the pitch between icons
    // wandered even though the glyphs matched. Reporting one width puts them on
    // a regular grid; the glyph stays centred, so a cell narrower than the
    // widget's own padding trims slack rather than clipping anything.
    //
    // Widgets wider than twice the cell are text, not icons (a hosted clock is
    // ~100px), and keep their natural width -- snapping those to an icon cell
    // would cut them off.
    property real contentScale: 1
    property real uniformCell: 0

    readonly property real naturalWidth:
        loader.item ? loader.item.implicitWidth * root.contentScale : 0

    // A plugin with no bar widget of its own -- a panel or overlay that was
    // switched on for the bar -- must take NO space. It is easy to fall into
    // giving it a cell: its natural width is 0 because there is no item, and 0
    // satisfies the icon-sized test below, so it would reserve a full blank
    // cell and open a visible hole in the row.
    implicitWidth: root.hidden
        ? 1
        : (!root.available || root.naturalWidth <= 0)
            ? 0
            : (root.uniformCell > 0 && root.naturalWidth <= root.uniformCell * 2)
                ? root.uniformCell
                : root.naturalWidth
    implicitHeight: root.barSize
    visible: root.available && !root.hidden
    // An anchor-only widget must still be laid out, or its panel has nothing to
    // position against; it is merely zero-width and transparent.
    opacity: root.hidden ? 0 : 1

    function injectProps() {
        const target = loader.item;
        if (!target)
            return;
        if ("bar" in target)
            target.bar = shim;
        if ("moduleName" in target)
            target.moduleName = root.widgetId;
        if ("settings" in target)
            target.settings = root.settings;
    }

    BarApiShim {
        id: shim

        pluginId: root.widgetId
        moduleName: root.widgetId
        shell: root.shell
        barSize: root.barTotalSize
    }

    Loader {
        id: loader

        // Centred and counter-sized rather than filling: the widget lays
        // itself out at its natural size and the scale transform does the
        // enlarging, so nothing inside has to know it is being scaled.
        anchors.centerIn: parent
        width: root.contentScale === 1 ? parent.width : parent.width / root.contentScale
        height: root.contentScale === 1 ? parent.height : parent.height / root.contentScale
        scale: root.contentScale
        active: root.available
        sourceComponent: root.widgetComponent
        asynchronous: true

        onLoaded: {
            root.injectProps();
            Qt.callLater(root.injectProps);
            root.registered(root.widgetId, root);
        }
    }

    Component.onDestruction: root.unregistered(root.widgetId, root)
}
