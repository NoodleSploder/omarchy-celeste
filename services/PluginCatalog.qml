pragma Singleton

// Enabled Omarchy plugins, for the Plugins bar button's expandable strip
// (modules/bar/components/Plugins.qml, modules/bar/PluginsStrip.qml).
//
// Bar.qml's `pluginRegistry` (assigned by the host, PluginRegistryApi.qml in
// the Omarchy shell) is deliberately NOT the full catalogue -- confirmed by
// reading that file after `pluginsRevision` came back `undefined` on deploy:
// it's "a read-only, self-scoped registry view for an installed third-party
// plugin. The host updates manifest/enabled when it rescans; no host
// registry object is retained here" -- i.e. Celeste's own `pluginRegistry`
// only ever knows about Celeste itself (`installedPlugins` contains exactly
// one entry: its own manifest). The full, all-plugins `PluginRegistry` stays
// inside shell.qml and is not hosted out to third-party bars at all -- a
// third-party plugin gets summon/hide/toggle authority over other plugins
// (that IS granted, confirmed via Bar.qml's own doc comment and working
// `root.shell.toggle()` calls elsewhere in this file), but not the ability
// to enumerate them.
//
// So this reads the same files Omarchy's own PluginRegistry.qml reads
// (~/.config/omarchy/plugins/*/manifest.json, the first-party manifests
// under /usr/share/omarchy/shell/plugins, and ~/.config/omarchy/shell.json
// for enabled/disabled state) directly, the same move already made for
// services/OmarchyMenu.qml (reads Omarchy's own menu jsonc rather than going
// through a restricted API) -- and reimplements a faithful subset of
// PluginRegistry.qml's isEnabled()/findEntryLocation() logic in plain JS,
// since there is no way to call the real functions from here. Skipped
// deliberately: the "bar" kind special case (excluded one level up, a bar
// option isn't a togglable plugin) and clone resolution (clonedFrom) -- an
// edge case for plugins that replace a first-party one, not needed for a
// "here's what's enabled" listing.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string firstPartyDir: "/usr/share/omarchy/shell/plugins"
    readonly property string thirdPartyDir: root.home + "/.config/omarchy/plugins"
    readonly property string shellConfigPath: root.home + "/.config/omarchy/shell.json"

    // Raw scan result: one object per manifest found, each stamped with
    // __sourceDir/__isFirstParty (same shape PluginRegistry.qml's own scan
    // produces internally).
    property var manifests: []
    property var shellConfig: ({})

    function isDisabled(id) {
        return Array.isArray(root.shellConfig.disabledPlugins) && root.shellConfig.disabledPlugins.indexOf(id) !== -1;
    }

    function isReferenced(id) {
        const bar = root.shellConfig.bar;
        if (bar && bar.layout) {
            for (const section of ["left", "center", "right"]) {
                const arr = bar.layout[section];
                if (Array.isArray(arr) && arr.some(e => (typeof e === "string" ? e : (e && e.id)) === id))
                    return true;
            }
        }
        return Array.isArray(root.shellConfig.plugins) && root.shellConfig.plugins.some(e => e && e.id === id);
    }

    // Mirrors PluginRegistry.isEnabled(), minus the "bar" kind branch (the
    // caller already filters those out) and clone resolution.
    function isEnabled(manifest) {
        if (root.isDisabled(manifest.id))
            return false;
        if (manifest.__isFirstParty)
            return true;
        return root.isReferenced(manifest.id);
    }

    // Enabled plugins as [{ id, name, iconPath }], sorted by name.
    // iconPath points at <sourceDir>/icon.png -- an informal convention only
    // a couple of installed plugins actually use (there is no icon field in
    // the manifest schema at all); Image.status reports Error for everyone
    // else and the strip falls back to a generic glyph, no existence check
    // needed here.
    readonly property var enabledList: {
        const firstParty = {};
        const thirdParty = {};
        for (const m of root.manifests) {
            if (!m || !m.id || !Array.isArray(m.kinds))
                continue;
            if (m.__isFirstParty)
                firstParty[m.id] = m;
            else
                thirdParty[m.id] = m;
        }
        // Third party never shadows first party; the omarchy.* namespace is
        // reserved -- same rule PluginRegistry.qml's own merge enforces.
        const merged = {};
        for (const id in firstParty)
            merged[id] = firstParty[id];
        for (const id in thirdParty) {
            if (firstParty[id] || id.indexOf("omarchy.") === 0)
                continue;
            merged[id] = thirdParty[id];
        }

        // Only kinds with an actual summon-able surface belong in a row of
        // clickable icons -- a "service" (background, polkit, notifications,
        // lock, ...) or a plain "bar-widget" (agents, the bar's own built-in
        // widgets) has nothing for shell.toggle() to open, so it would just
        // sit there doing nothing on click. Checked a sample of first-party
        // manifests directly rather than assuming: osd/dev-gallery -> panel,
        // clipboard/emojis/image-picker/reminders -> overlay, menu -> menu
        // (+bar-widget) all have a real surface; background/polkit/
        // notifications/lock -> service and agents -> bar-widget do not.
        const summonable = ["panel", "overlay", "menu"];
        const out = [];
        for (const id in merged) {
            const m = merged[id];
            if (m.kinds.indexOf("bar") !== -1)
                continue;
            if (!m.kinds.some(k => summonable.indexOf(k) !== -1))
                continue;
            if (!root.isEnabled(m))
                continue;
            const dir = String(m.__sourceDir || "");
            out.push({
                id: id,
                name: String(m.name || id),
                iconPath: dir ? "file://" + dir + "/icon.png" : ""
            });
        }
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }

    function rescan() {
        scanProcess.running = true;
    }

    // Same shape as PluginRegistry.qml's own rescan(): scan_firstparty finds
    // manifest.json / *.manifest.json two-to-three levels under the
    // first-party dir (bar widgets group as e.g. widgets/Clock.manifest.json
    // alongside sibling widgets, hence mindepth 2); scan_thirdparty is a flat
    // one-level-deep directory of plugin folders. Each manifest is stamped
    // with its source directory and first-party flag via jq and streamed out
    // as one JSON object per line, then collected into a single array --
    // simpler for this read-only use than the real registry's textual
    // ===kind::dir=== framing, which exists there to survive arbitrarily
    // malformed manifests one at a time.
    property Process scanProcess: Process {
        id: scanProcess

        command: ["bash", "-c", "" +
            "emit() { local kind=\"$1\" manifest=\"$2\" sub fp; " +
            "  if [[ ${manifest##*/} == manifest.json ]]; then sub=\"${manifest%/manifest.json}\"; else sub=\"$(dirname -- \"$manifest\")\"; fi; " +
            "  fp=false; [[ \"$kind\" == firstparty ]] && fp=true; " +
            "  jq -c --arg dir \"$sub\" --argjson fp \"$fp\" '. + {__sourceDir: $dir, __isFirstParty: $fp}' \"$manifest\" 2>/dev/null; " +
            "}; " +
            "scan_fp() { local dir=\"$1\"; [[ -d \"$dir\" ]] || return 0; " +
            "  while IFS= read -r m; do emit firstparty \"$m\"; done < <(find \"$dir\" -mindepth 2 -maxdepth 3 -type f \\( -name manifest.json -o -name '*.manifest.json' \\) 2>/dev/null | sort); " +
            "}; " +
            "scan_tp() { local dir=\"$1\"; [[ -d \"$dir\" ]] || return 0; " +
            "  for sub in \"$dir\"/*/; do [[ -f \"$sub/manifest.json\" ]] || continue; emit thirdparty \"$sub/manifest.json\"; done; " +
            "}; " +
            "{ scan_fp \"$0\"; scan_tp \"$1\"; } | jq -s '.'",
            root.firstPartyDir, root.thirdPartyDir]

        stdout: StdioCollector {
            id: scanStdout
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.manifests = JSON.parse(scanStdout.text || "[]");
                } catch (e) {
                    console.warn("PluginCatalog: bad scan output: " + e);
                    root.manifests = [];
                }
            }
        }
    }

    property FileView configFile: FileView {
        id: configFile

        path: root.shellConfigPath
        watchChanges: true
        printErrors: false

        onLoaded: {
            try {
                root.shellConfig = JSON.parse(configFile.text());
            } catch (e) {
                root.shellConfig = {};
            }
        }
        onFileChanged: reload()
    }

    Component.onCompleted: root.rescan()
}
