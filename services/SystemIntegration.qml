pragma Singleton

// Status + apply/remove for the external Hyprland config Celeste's own
// features depend on -- see docs/EXTERNAL-CONFIG.md's "Required" and
// "Recommended" sections, which this is the live, in-panel counterpart of.
//
// IMPORTANT LIMITATION, read before extending this file: Omarchy's plugin
// enable/disable/remove (omarchy-plugin-enable/-disable/-remove) has NO
// lifecycle hooks at all -- confirmed by reading those scripts directly, not
// assumed. Enabling/disabling a plugin is pure data: it flips an entry in
// shell.json's disabledPlugins[] (or moves a bar-kind plugin's id into
// bar.id) and nothing else. There is no "run this when the user disables
// me" mechanism, and once Celeste itself is disabled or removed, none of
// its QML -- this file included -- is running any more to react to that.
//
// So this can only ever be a Celeste-owned settings panel the user drives
// themselves (Celeste Settings -> System), not something that actually
// fires off Omarchy's own enable/disable/remove commands. The practical
// consequence, and the thing the System settings page tells the user
// directly: turn an item off HERE before disabling or removing Celeste
// through Omarchy, since nothing will do it afterwards.
//
// Every write this file makes is scoped to a marker block it owns (`-- BEGIN
// noodlesploder.celeste (<tag>)` / `-- END ...`) and never touches
// unmarked content, even content that does the same thing -- see
// `shortcutsStatus`/`gesturesStatus` below. That matters concretely on the
// machine this was built on: bindings.lua and input.lua already carry this
// exact configuration, hand-written before this feature existed, with no
// marker at all. Treating that as "already managed" and offering to
// "remove" it would delete hand-authored content Celeste never wrote.
// Reported as "external" instead -- present and correct, just not something
// this panel can safely offer to undo.
//
// Deliberately NOT covered here, and why (matches docs/EXTERNAL-CONFIG.md):
//   - Selecting Celeste as the active bar (omarchy shell.json bar.id) --
//     already handled by `omarchy plugin enable` itself for a bar-kind
//     plugin (confirmed by reading omarchy-plugin-enable: it sets bar.id
//     automatically and prints "Now using <id> as the bar"). Nothing for
//     Celeste to add.
//   - Per-monitor workspace blocks / SUPER+1..6 rebinding -- a personal
//     Hyprland workspace-numbering scheme, not a Celeste dependency. Celeste
//     works fine on plain global workspaces; wiring this into Celeste's own
//     lifecycle would silently reach into config that has nothing to do
//     with which bar is active.
//   - The dock hotplug recovery workaround -- EXTERNAL-CONFIG.md files this
//     under "This machine only" for a reason: it is a fix for a kernel bug
//     on this specific hardware, unrelated to Celeste. Bundling it into
//     Celeste's lifecycle would be scope creep the doc itself argues
//     against.
//   - Required CLI tools (brightnessctl, inotify-tools) -- reported as a
//     status check only. Installing packages can require an interactive
//     sudo password prompt, which a headless Process launched from a
//     settings toggle cannot supply (see the Omarchy skill's own privilege
//     rule: an interactive command needs a visible terminal). The panel
//     shows what is missing and the exact command to run, not a button that
//     silently runs one.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string bindingsPath: root.home + "/.config/hypr/bindings.lua"
    readonly property string inputPath: root.home + "/.config/hypr/input.lua"
    readonly property string autostartPath: root.home + "/.config/hypr/autostart.lua"

    readonly property string shortcutsBegin: "-- BEGIN noodlesploder.celeste (shortcuts)"
    readonly property string shortcutsEnd: "-- END noodlesploder.celeste (shortcuts)"
    readonly property string gesturesBegin: "-- BEGIN noodlesploder.celeste (gestures)"
    readonly property string gesturesEnd: "-- END noodlesploder.celeste (gestures)"

    // "managed"  -- our own marker block is present (we can safely remove it)
    // "external" -- the content Celeste needs is present, but not inside our
    //               marker (hand-written, or added before this feature
    //               existed) -- present and correct, but not ours to remove
    // "absent"   -- neither; the feature will not work until this is added
    function statusFor(text, beginMarker, needleRe) {
        if (text.indexOf(beginMarker) !== -1)
            return "managed";
        if (needleRe.test(text))
            return "external";
        return "absent";
    }

    // Mutable, not `readonly property string x: fileView.text()` -- that
    // shape was tried first and silently never populates inside a
    // pragma Singleton: isolated with a minimal reproduction (a singleton
    // QtObject with exactly this binding stayed permanently empty, while the
    // identical binding in a plain, non-singleton QtObject loaded correctly
    // straight away). Matches why Config.qml and OmarchyMenu.qml never use
    // this shape either -- both assign into a mutable property from
    // onLoaded/onFileChanged instead, which is what these three now do too.
    property string bindingsText: ""
    property string inputText: ""
    property string autostartText: ""

    readonly property string shortcutsStatus: root.statusFor(
        root.bindingsText, root.shortcutsBegin, /celeste:menu|celeste:overview\b/)
    readonly property string gesturesStatus: root.statusFor(
        root.inputText, root.gesturesBegin, /celeste:overviewShow|celeste:overviewHide/)

    // The exact diagnostic CLAUDE.md documents for this: a stray, uncommented
    // exec_on_start line starting a second full Omarchy shell.
    readonly property bool autostartHasStrayLine: {
        const lines = root.autostartText.split("\n");
        for (const line of lines) {
            const t = line.trim();
            if (t.indexOf("quickshell") !== -1
                && t.indexOf("/usr/share/omarchy/shell") !== -1
                && t.indexOf("--") !== 0)
                return true;
        }
        return false;
    }

    property int duplicateShellCount: 1
    property string lastAction: ""
    property string lastResult: ""

    function refreshDuplicateCheck() {
        duplicateCheck.running = true;
    }

    Component.onCompleted: root.refreshDuplicateCheck()

    // ------------------------------------------------------------- writers
    //
    // Every write: back up first, use awk (not sed) for the marker-range
    // delete so the marker text is matched as a literal substring, never as
    // a regex -- bindings.lua's own name has a "." in it, which sed would
    // treat as "any character". Reload Hyprland and check for config errors
    // afterward; a broken write rolls itself back from the backup it just
    // made, so a bad apply cannot leave the user's Hyprland unusable.

    // luaBody strings below use plain, real newlines and real quotes -- the
    // single escaping layer, _q(), is what turns them into a safe shell
    // double-quoted argument. Escaping them again here (an earlier draft
    // did) double-escapes: the shell layer sees a literal backslash-quote
    // pair instead of a quote, which is not valid Lua syntax once written to
    // the file. One escaping layer, applied once, in _q().
    function applyShortcuts() {
        root.lastAction = "shortcuts";
        writer.command = ["bash", "-c", root._applyScript(
            root.bindingsPath, root.shortcutsBegin, root.shortcutsEnd,
            "hl.unbind(\"SUPER + SPACE\")\n" +
            "o.bind(\"SUPER + SPACE\", \"Omarchy menu\", hl.dsp.global(\"celeste:menu\"))\n" +
            "hl.unbind(\"CTRL + TAB\")\n" +
            "o.bind(\"CTRL + TAB\", \"Workspace overview\", hl.dsp.global(\"celeste:overview\"))",
            "celeste:menu|celeste:overview")];
        writer.running = true;
    }

    function removeShortcuts() {
        root.lastAction = "shortcuts";
        writer.command = ["bash", "-c", root._removeScript(
            root.bindingsPath, root.shortcutsBegin, root.shortcutsEnd)];
        writer.running = true;
    }

    function applyGestures() {
        root.lastAction = "gestures";
        writer.command = ["bash", "-c", root._applyScript(
            root.inputPath, root.gesturesBegin, root.gesturesEnd,
            "hl.gesture({ fingers = 4, direction = \"horizontal\", action = \"workspace\" })\n" +
            "hl.gesture({ fingers = 4, direction = \"up\", action = function() hl.dispatch(hl.dsp.global(\"celeste:overviewShow\")) end })\n" +
            "hl.gesture({ fingers = 4, direction = \"down\", action = function() hl.dispatch(hl.dsp.global(\"celeste:overviewHide\")) end })",
            "celeste:overviewShow|celeste:overviewHide")];
        writer.running = true;
    }

    function removeGestures() {
        root.lastAction = "gestures";
        writer.command = ["bash", "-c", root._removeScript(
            root.inputPath, root.gesturesBegin, root.gesturesEnd)];
        writer.running = true;
    }

    // Comments out the stray autostart line rather than deleting it, so the
    // reason it is inert stays visible in the file if anyone looks. Backs up
    // first; no-ops (reports "clean") if the line is already gone or already
    // commented -- safe to click more than once.
    function fixAutostart() {
        root.lastAction = "autostart";
        writer.command = ["bash", "-c", [
            "set -euo pipefail",
            "F=" + root._q(root.autostartPath),
            "[[ -f \"$F\" ]] || { echo missing; exit 0; }",
            "if ! grep -qE '^[^-].*quickshell.*/usr/share/omarchy/shell' \"$F\" 2>/dev/null; then echo clean; exit 0; fi",
            "cp \"$F\" \"$F.bak.$(date -u +%Y%m%d%H%M%S)\"",
            "sed -i -E 's#^([[:space:]]*)(o\\.exec_on_start\\(\"quickshell[^\"]*/usr/share/omarchy/shell\"\\).*)#\\1-- \\2  -- disabled by Celeste (starts a duplicate shell)#' \"$F\"",
            "echo fixed"
        ].join(" && ")];
        writer.running = true;
    }

    function _q(s) {
        return "\"" + String(s).replace(/"/g, "\\\"") + "\"";
    }

    // Appends a fresh marker block, but only when neither the marker nor the
    // equivalent hand-written content is already there -- see the "managed"/
    // "external"/"absent" status this mirrors.
    // externalPattern is a defence-in-depth check, not the only guard: the
    // settings page only ever offers "Apply" when shortcutsStatus/
    // gesturesStatus already read "absent", so this path should not normally
    // be reachable with equivalent hand-written content in the file. But the
    // write script should never trust a caller for something this
    // consequential -- appending our own marked block on top of unmarked
    // content doing the same thing would leave two conflicting hl.unbind/
    // o.bind (or hl.gesture) calls for the same key/gesture, so it refuses
    // and reports "external" instead, same as the UI's own status read.
    function _applyScript(path, beginMarker, endMarker, luaBody, externalPattern) {
        return [
            "set -euo pipefail",
            "F=" + root._q(path),
            "if grep -qF -- " + root._q(beginMarker) + " \"$F\"; then echo already-managed; exit 0; fi",
            "if grep -qE -- " + root._q(externalPattern) + " \"$F\"; then echo external; exit 0; fi",
            "cp \"$F\" \"$F.bak.$(date -u +%Y%m%d%H%M%S)\"",
            "printf '\\n%s\\n%s\\n%s\\n' " + root._q(beginMarker) + " " + root._q(luaBody) + " " + root._q(endMarker) + " >> \"$F\"",
            "if ! hyprctl reload >/tmp/celeste-hypr-reload.log 2>&1; then " +
                "LAST=$(ls -t \"${F}\".bak.* | head -1); cp \"$LAST\" \"$F\"; " +
                "echo reload-failed; cat /tmp/celeste-hypr-reload.log; exit 1; " +
            "fi",
            "errors=$(hyprctl configerrors 2>/dev/null || true)",
            "if [[ -n \"$errors\" && \"$errors\" != \"no errors\"* ]]; then " +
                "LAST=$(ls -t \"${F}\".bak.* | head -1); cp \"$LAST\" \"$F\"; hyprctl reload >/dev/null 2>&1 || true; " +
                "echo config-errors; echo \"$errors\"; exit 1; " +
            "fi",
            "echo applied"
        ].join(" && ");
    }

    // Deletes exactly the marker-delimited range with awk's index() (a plain
    // substring search), never a regex -- the marker text itself contains
    // "." and "(", both regex metacharacters a sed pattern would have to be
    // escaped for. index() sidesteps that entirely.
    //
    // Buffers one line behind rather than printing immediately, so the blank
    // line _applyScript always inserts just before BEGIN can be dropped
    // retroactively once BEGIN is actually seen, instead of being left
    // behind permanently -- confirmed by testing an apply/remove cycle in
    // isolation: without this, every toggle off left one more blank line at
    // the same spot than the last, growing without bound.
    function _removeScript(path, beginMarker, endMarker) {
        return [
            "set -euo pipefail",
            "F=" + root._q(path),
            "if ! grep -qF -- " + root._q(beginMarker) + " \"$F\"; then echo not-managed; exit 0; fi",
            "cp \"$F\" \"$F.bak.$(date -u +%Y%m%d%H%M%S)\"",
            "awk -v b=" + root._q(beginMarker) + " -v e=" + root._q(endMarker) + " '" +
                "index($0,b)==1{skip=1; if (have && prev==\"\") have=0; next} " +
                "index($0,e)==1{skip=0; next} " +
                "skip{next} " +
                "{if (have) print prev; prev=$0; have=1} " +
                "END{if (have) print prev}" +
                "' \"$F\" > \"$F.tmp\" && mv \"$F.tmp\" \"$F\"",
            "if ! hyprctl reload >/tmp/celeste-hypr-reload.log 2>&1; then " +
                "LAST=$(ls -t \"${F}\".bak.* | head -1); cp \"$LAST\" \"$F\"; " +
                "echo reload-failed; cat /tmp/celeste-hypr-reload.log; exit 1; " +
            "fi",
            "echo removed"
        ].join(" && ");
    }

    property FileView bindingsFile: FileView {
        path: root.bindingsPath
        watchChanges: true
        printErrors: false
        onLoaded: root.bindingsText = text()
        onFileChanged: reload()
    }

    property FileView inputFile: FileView {
        path: root.inputPath
        watchChanges: true
        printErrors: false
        onLoaded: root.inputText = text()
        onFileChanged: reload()
    }

    property FileView autostartFile: FileView {
        path: root.autostartPath
        watchChanges: true
        printErrors: false
        onLoaded: root.autostartText = text()
        onFileChanged: reload()
    }

    property Process writer: Process {
        id: writer
        stdout: StdioCollector {
            id: writerOut
            waitForEnd: true
            onStreamFinished: {
                root.lastResult = writerOut.text.trim();
                bindingsFile.reload();
                inputFile.reload();
                autostartFile.reload();
                root.refreshDuplicateCheck();
            }
        }
    }

    // CLAUDE.md's own documented diagnostic, run literally: "There must be
    // exactly one." pgrep -c -f alone miscounts (it also matches the wrapper
    // command line), so this greps the full command lines instead and counts
    // rows, the same as the manual check.
    property Process duplicateCheck: Process {
        id: duplicateCheck
        command: ["bash", "-c", "ps -eo cmd | grep quickshell | grep -v grep | grep -c '/usr/share/omarchy/shell' || true"]
        stdout: StdioCollector {
            id: dupOut
            waitForEnd: true
            onStreamFinished: {
                const n = parseInt(dupOut.text.trim(), 10);
                root.duplicateShellCount = isNaN(n) ? 1 : n;
            }
        }
    }

    property bool hasBrightnessctl: true
    property bool hasInotifywait: true

    property Process toolCheck: Process {
        id: toolCheck
        command: ["bash", "-c", "command -v brightnessctl >/dev/null && echo b:1 || echo b:0; command -v inotifywait >/dev/null && echo i:1 || echo i:0"]
        stdout: StdioCollector {
            id: toolOut
            waitForEnd: true
            onStreamFinished: {
                const text = toolOut.text;
                root.hasBrightnessctl = text.indexOf("b:1") !== -1;
                root.hasInotifywait = text.indexOf("i:1") !== -1;
            }
        }
    }

    function refreshToolCheck() {
        toolCheck.running = true;
    }
}
