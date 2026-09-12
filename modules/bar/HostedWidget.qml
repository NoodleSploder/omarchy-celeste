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

    readonly property var metadata: root.registry ? root.registry.metadataFor(root.widgetId) : null

    readonly property var widgetComponent: {
        if (!root.registry)
            return null;
        const widgets = root.registry.widgets;
        const entry = widgets ? widgets[root.widgetId] : null;
        return entry ? entry.component : null;
    }

    readonly property bool available: root.widgetComponent !== null

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: root.barSize
    visible: root.available

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
        barSize: root.barSize
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
        }
    }
}
