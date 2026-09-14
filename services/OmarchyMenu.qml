pragma Singleton

// Omarchy's own root menu (omarchy-menu.jsonc), reparsed with its own
// MenuModel.js (core/MenuModel.js -- see ATTRIBUTION.md) so Celeste can
// render the exact same items/categories/actions in its own panel instead of
// Omarchy's floating KeyboardPanel.
//
// The "apps" provider IS implemented here, from Quickshell's own
// DesktopEntries rather than Omarchy's AppLibrary: that service is only
// handed to plugins whose manifest declares kind "menu" (shell.qml:
// `appLibrary: shell.manifestHasKind(manifest, "menu") ? ... : null`) and
// Celeste declares "bar", so `shell.appLibrary` is null here -- the same
// capability-scoping already hit with pluginRegistry (see CLAUDE.md).
// DesktopEntries is the same underlying source AppLibrary itself wraps.
//
// Icon resolution has the same fallback AppLibrary.qml has, ported for the
// same reason: Quickshell's themed icon lookup (Quickshell.iconPath, backed
// by Qt's QIconTheme / the GTK icon-theme.cache) is only ever built once per
// process and never notices an icon file that appears afterwards -- a newly
// installed app's icon renders as the generic fallback glyph until Celeste
// itself is restarted, no matter how many times the launcher is reopened.
// iconIndex is a private name->file map built by scanning the same
// directories AppLibrary scans, refreshed whenever the app list changes and
// whenever the menu opens (refreshIcons(), called from show()), and checked
// before the themed lookup in iconSource() below.

import QtQuick
import Quickshell
import Quickshell.Io
import "../core/MenuModel.js" as MenuModel

QtObject {
    id: root

    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    readonly property string home: Quickshell.env("HOME")
    readonly property string defaultMenuPath: root.omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
    readonly property string userMenuPath: root.home + "/.config/omarchy/extensions/omarchy-menu.jsonc"

    property var defaultItems: []
    property var userItems: []

    readonly property var merged: MenuModel.mergeMenuSources(root.defaultItems, root.userItems)
    readonly property var items: root.merged.items
    readonly property var itemOrder: root.merged.itemOrder

    property var whenResults: ({})
    property var checkedResults: ({})

    // Icon name (e.g. "plex") -> file path on disk. See the header comment.
    property var iconIndex: ({})
    property var pendingIconIndex: ({})

    // Navigation: a stack of item ids, root always at index 0. The current
    // route is the top of the stack; "back" just pops it. Kept as a stack
    // (not a single "route" string) so closing and reopening always starts
    // at root without extra bookkeeping, and the breadcrumb trail falls out
    // of the stack itself.
    property var routeStack: ["root"]
    readonly property string route: root.routeStack[root.routeStack.length - 1]
    readonly property bool atRoot: root.routeStack.length <= 1

    property bool open: false
    property string query: ""

    // Keyboard cursor into visibleRows. Reset on anything that rebuilds the
    // list (typing, drilling in, reopening) rather than clamped reactively --
    // a binding that both reads visibleRows and writes an index derived from
    // it is exactly the shape that loops.
    property int selected: 0

    onQueryChanged: root.selected = 0
    onRouteChanged: root.selected = 0

    function moveSelection(delta) {
        const count = root.visibleRows.length;
        if (count === 0)
            return;
        root.selected = ((root.selected + delta) % count + count) % count;
    }

    function activateSelected() {
        const rows = root.visibleRows;
        if (root.selected >= 0 && root.selected < rows.length)
            root.activate(rows[root.selected]);
    }

    // Which monitor is showing it -- captured once at open, not re-evaluated
    // live, so moving focus elsewhere while it's open doesn't relocate it out
    // from under the user. Same shape as Bar.qml's own calendarScreen.
    property string screenName: ""

    function toggle(screenName) {
        if (root.open)
            root.close();
        else
            root.show(screenName);
    }

    function show(screenName) {
        root.routeStack = ["root"];
        root.query = "";
        root.screenName = String(screenName || "");
        root.open = true;
        root.refreshGuards();
        root.refreshIcons();
    }

    function close() {
        root.open = false;
    }

    function openRoute(id) {
        const resolved = MenuModel.resolveRoute(root.items, root.itemOrder, id);
        root.routeStack = root.routeStack.concat([resolved]);
        root.query = "";
    }

    function back() {
        if (root.routeStack.length > 1)
            root.routeStack = root.routeStack.slice(0, -1);
    }

    // Entries directly under the current route, guard-filtered and in
    // declared order -- root.qmlite MenuModel.isVisible already recurses to
    // hide an empty submenu (a category whose every child is when:-hidden
    // hides itself in turn).
    readonly property var currentChildren: {
        const out = [];
        for (const id of root.itemOrder) {
            const entry = root.items[id];
            if (!entry || entry.parent !== root.route)
                continue;
            if (!MenuModel.isVisible(root.items, root.itemOrder, root.whenResults, entry, 0))
                continue;
            out.push(MenuModel.displayRow(root.items, root.itemOrder, root.checkedResults, entry, "", 0, ""));
        }
        return out;
    }

    readonly property string currentTitle: {
        const entry = MenuModel.item(root.items, root.route);
        return entry ? (entry.title || entry.label) : "";
    }

    // Search hits every visible item in the whole tree, not just the current
    // route's children -- typing "theme" from root jumps straight to
    // Style > Theme the same way Omarchy's own menu does.
    readonly property var searchResults: {
        const q = root.query.trim();
        if (!q)
            return [];
        const scored = [];
        for (const id of root.itemOrder) {
            const entry = root.items[id];
            if (!entry)
                continue;
            const visible = MenuModel.isVisible(root.items, root.itemOrder, root.whenResults, entry, 0);
            if (!MenuModel.matchesQuery(entry, q, visible))
                continue;
            const row = MenuModel.displayRow(root.items, root.itemOrder, root.checkedResults, entry, "", MenuModel.searchScore(root.items, entry, q), "");
            scored.push(row);
        }
        scored.sort((a, b) => a.score - b.score);
        return scored;
    }

    // ----------------------------------------------------------------- apps
    //
    // omarchy-menu.jsonc declares `"apps": {..., "provider":"apps"}` -- a
    // submenu whose rows the shell fills in at runtime. Omarchy's own menu
    // fills it from AppLibrary; this fills it from DesktopEntries, shaped
    // into the same row records the JSONC-derived ones use so one delegate
    // renders both.

    readonly property var appEntries: {
        const model = DesktopEntries.applications;
        const values = model ? model.values : [];
        const out = [];
        for (const entry of values) {
            if (!entry || entry.noDisplay)
                continue;
            out.push(entry);
        }
        out.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
        return out;
    }

    function appRow(entry, score) {
        return {
            itemId: "app:" + String(entry.id || entry.name),
            kind: "app",
            label: String(entry.name || ""),
            title: "",
            description: String(entry.comment || entry.genericName || ""),
            icon: "",
            appIcon: String(entry.icon || ""),
            appEntry: entry,
            action: "",
            provider: "",
            target: "",
            childCount: 0,
            checked: false,
            path: "Apps",
            score: score === undefined ? 0 : score
        };
    }

    readonly property var appRows: root.appEntries.map(e => root.appRow(e, 0))

    // Resolves an app's raw Icon= value to a real image source: the fallback
    // index first (it catches icons installed after this process started),
    // falling back to Quickshell's themed lookup otherwise. Mirrors
    // AppLibrary.qml's own iconSource() -- see the header comment.
    function iconSource(icon) {
        const value = String(icon || "");
        if (value.length === 0)
            return Quickshell.iconPath("application-x-executable", true);
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0)
            return value;
        if (value.charAt(0) === "/")
            return root.fileUrl(value);
        const found = root.iconIndex[value];
        if (found)
            return root.fileUrl(found);
        const themed = Quickshell.iconPath(value, true);
        if (themed.length > 0)
            return themed;
        return Quickshell.iconPath("application-x-executable", true);
    }

    function fileUrl(path) {
        if (!path)
            return "";
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
    }

    // Rescans the icon directories. Safe to call any time; a scan already in
    // flight is left to finish rather than restarted.
    function refreshIcons() {
        if (!iconIndexScan.running)
            iconIndexScan.running = true;
    }

    // Same directory list and same "svg before png, first hit per name wins"
    // rule as AppLibrary.qml's own scan, so the two stay consistent.
    function iconIndexScanCommand() {
        return [
            'dirs="$HOME/.icons $HOME/.local/share/icons";',
            'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
            'for ext in svg png; do',
            '  for base in $dirs; do',
            '    [[ -d $base ]] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) -name "*.$ext" 2>/dev/null;',
            '  done;',
            '  find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null;',
            'done'
        ].join(' ');
    }

    function indexIconLine(path) {
        const value = String(path || "").trim();
        if (value.length === 0)
            return;
        const slash = value.lastIndexOf("/");
        const file = slash >= 0 ? value.slice(slash + 1) : value;
        const dot = file.lastIndexOf(".");
        const name = dot > 0 ? file.slice(0, dot) : file;
        if (name.length > 0 && root.pendingIconIndex[name] === undefined)
            root.pendingIconIndex[name] = value;
    }

    // Scored on the same 0-is-best scale MenuModel.searchScore uses, so app
    // hits and menu hits can be sorted against each other in one list rather
    // than one family always winning.
    function appScore(entry, query) {
        const q = query.toLowerCase();
        const name = String(entry.name || "").toLowerCase();
        if (name === q)
            return 0;
        if (name.startsWith(q))
            return 1;
        const words = name.split(/[\s\-_.]+/);
        for (const word of words)
            if (word.startsWith(q))
                return 2;
        if (name.indexOf(q) >= 0)
            return 4;
        const generic = String(entry.genericName || "").toLowerCase();
        if (generic.indexOf(q) >= 0)
            return 6;
        try {
            for (const keyword of (entry.keywords || []))
                if (String(keyword).toLowerCase().indexOf(q) >= 0)
                    return 7;
        } catch (e) {}
        const comment = String(entry.comment || "").toLowerCase();
        if (comment.indexOf(q) >= 0)
            return 8;
        return -1;
    }

    readonly property var appResults: {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return [];
        const scored = [];
        for (const entry of root.appEntries) {
            const score = root.appScore(entry, q);
            if (score >= 0)
                scored.push(root.appRow(entry, score));
        }
        scored.sort((a, b) => a.score - b.score || a.label.localeCompare(b.label));
        return scored;
    }

    // Searching hits menu entries and installed apps together; the "apps"
    // route on its own lists every app, the way drilling into any other
    // category lists its children.
    readonly property var visibleRows: {
        if (root.query.trim()) {
            const combined = root.searchResults.concat(root.appResults);
            combined.sort((a, b) => a.score - b.score);
            return combined;
        }
        if (root.route === "apps")
            return root.appRows;
        return root.currentChildren;
    }

    // A row with children (kind menu/link, no action of its own) drills in;
    // a link jumps straight to its target instead of nesting under "link".
    function activate(row) {
        if (!row)
            return;
        if (row.kind === "app") {
            if (row.appEntry)
                row.appEntry.execute();
            root.close();
            return;
        }
        if (row.provider === "apps") {
            root.openRoute("apps");
            return;
        }
        if (row.provider) {
            // Other providers (fonts, ...) are bash enumerations Celeste does
            // not run itself; hand those to Omarchy's own menu rather than
            // showing an empty submenu.
            root.close();
            Quickshell.execDetached(["bash", "-lc", "omarchy-menu toggle " + row.itemId]);
            return;
        }
        if (row.action) {
            root.runAction(row.action);
            root.close();
            return;
        }
        if (row.kind === "link" || row.kind === "menu") {
            root.openRoute(row.target || row.itemId);
        }
    }

    function runAction(action) {
        const command = String(action || "");
        if (!command)
            return;
        Quickshell.execDetached(["bash", "-lc", command]);
    }

    // ------------------------------------------------------------- loading

    function parseAndStore(text, isUser) {
        const parsed = MenuModel.parseMenuJsonc(text);
        if (isUser)
            root.userItems = parsed;
        else
            root.defaultItems = parsed;
    }

    property FileView defaultMenuFile: FileView {
        path: root.defaultMenuPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.parseAndStore(text(), false);
            root.refreshGuards();
        }
        onFileChanged: reload()
    }

    property FileView userMenuFile: FileView {
        path: root.userMenuPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.parseAndStore(text(), true);
            root.refreshGuards();
        }
        onLoadFailed: {
            root.userItems = [];
            root.refreshGuards();
        }
        onFileChanged: reload()
    }

    // ---------------------------------------------------------------- guards
    //
    // `when:`/`checked:` are bash expressions; batched into one process per
    // (re)load exactly like Omarchy's own Menu.qml, using the identical
    // script generator (core/MenuModel.js: guardScript) so the answers agree.

    property bool guardsPending: false

    function refreshGuards() {
        if (guardProc.running) {
            root.guardsPending = true;
            return;
        }
        root.guardsPending = false;

        const script = MenuModel.guardScript(root.items);
        if (!script) {
            root.whenResults = ({});
            root.checkedResults = ({});
            return;
        }
        guardProc.collected = "";
        guardProc.command = ["bash", "-lc", script];
        guardProc.running = true;
    }

    property Process guardProc: Process {
        id: guardProc
        property string collected: ""
        stdout: SplitParser {
            onRead: data => guardProc.collected += data + "\n"
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                if (root.guardsPending)
                    Qt.callLater(() => root.refreshGuards());
                return;
            }

            const nextWhen = ({});
            const nextChecked = ({});
            for (const raw of guardProc.collected.split("\n")) {
                const line = raw.trim();
                if (!line)
                    continue;
                const colon = line.lastIndexOf(":");
                if (colon < 0)
                    continue;
                const value = line.substring(colon + 1) === "1";
                const rest = line.substring(0, colon);
                const tagAt = rest.lastIndexOf(":");
                if (tagAt < 0)
                    continue;
                const id = rest.substring(0, tagAt);
                const tag = rest.substring(tagAt + 1);
                if (tag === "w")
                    nextWhen[id] = value;
                else if (tag === "c")
                    nextChecked[id] = value;
            }
            root.whenResults = nextWhen;
            root.checkedResults = nextChecked;

            if (root.guardsPending)
                Qt.callLater(() => root.refreshGuards());
        }
    }

    // Every Timer/Process in a QtObject singleton must be an explicit
    // property, not a bare child -- QtObject has no default child-content
    // property the way Item does, and this fails with "Cannot assign to
    // non-existent default property" otherwise (already hit twice elsewhere
    // in this repo; see CLAUDE.md).
    property Process iconIndexScan: Process {
        id: iconIndexScan
        command: ["bash", "-c", root.iconIndexScanCommand()]
        stdout: SplitParser {
            onRead: line => root.indexIconLine(line)
        }
        onStarted: root.pendingIconIndex = ({})
        // Swapping the property re-evaluates every iconSource() binding, so
        // newly found icons appear without rebuilding the row list.
        onExited: root.iconIndex = root.pendingIconIndex
    }

    // Coalesces a burst of app-list changes (a package install touches many
    // desktop entries at once) into a single rescan, same as AppLibrary.qml.
    property Timer iconIndexDebounce: Timer {
        id: iconIndexDebounce
        interval: 750
        onTriggered: if (!iconIndexScan.running) iconIndexScan.running = true
    }

    property Connections desktopEntriesWatch: Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            iconIndexDebounce.restart();
        }
    }

    Component.onCompleted: root.refreshIcons()
}
