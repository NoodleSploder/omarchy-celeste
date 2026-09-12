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
    implicitWidth: root.hidden ? 1 : (loader.item ? loader.item.implicitWidth : 0)
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

        anchors.fill: parent
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
