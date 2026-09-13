pragma Singleton

// Default sink and source state, from Quickshell's native PipeWire binding.
//
// PipeWire node properties are not live until something tracks the object --
// PwObjectTracker is what subscribes; without it volume and muted simply never
// update.

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var outputDevices: root.nodes.filter(n => n && n.isSink && !n.isStream)
    readonly property var inputDevices: root.nodes.filter(n => n && !n.isSink && !n.isStream && n.audio)

    readonly property bool hasSink: !!(sink && sink.audio)
    readonly property bool hasSource: !!(source && source.audio)

    readonly property real volume: hasSink ? sink.audio.volume : 0
    readonly property bool muted: hasSink ? sink.audio.muted : false
    readonly property real sourceVolume: hasSource ? source.audio.volume : 0
    readonly property bool sourceMuted: hasSource ? source.audio.muted : false

    // Volume can exceed 1.0 (PipeWire allows boost); clamp for display only.
    readonly property int volumePercent: Math.round(Math.min(1, volume) * 100)
    readonly property int sourceVolumePercent: Math.round(Math.min(1, sourceVolume) * 100)

    // The hero switch in the popout header is the whole panel's on/off, so it
    // carries both channels at once -- muting only the mic must not read as
    // "everything is off".
    readonly property bool anyAudible: (hasSink && !muted) || (hasSource && !sourceMuted)

    function toggleAllMuted() {
        const mute = root.anyAudible;
        if (root.hasSink)
            root.sink.audio.muted = mute;
        if (root.hasSource)
            root.source.audio.muted = mute;
    }

    function setVolume(v) {
        if (root.hasSink)
            root.sink.audio.volume = Math.max(0, Math.min(1.5, v));
    }

    function incrementVolume(step) {
        root.setVolume(root.volume + (step === undefined ? 0.05 : step));
    }

    function decrementVolume(step) {
        root.setVolume(root.volume - (step === undefined ? 0.05 : step));
    }

    function toggleMute() {
        if (root.hasSink)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function toggleSourceMute() {
        if (root.hasSource)
            root.source.audio.muted = !root.source.audio.muted;
    }

    // Strips the noisy prefixes/suffixes PipeWire node descriptions carry
    // ("sof-soundwire Speaker Output" -> "Speaker") -- ports Omarchy's own
    // audio panel Model.js so device names read the same in both places.
    function _friendlyLabel(text) {
        let label = String(text || "").trim();
        label = label.replace(/^sof-soundwire\s+/i, "");
        label = label.replace(/^built-?in audio\s+/i, "");
        label = label.replace(/\s+Output$/i, "");
        label = label.replace(/\s+Input$/i, "");
        label = label.replace(/\bMicrophones\b/g, "Microphone");
        return label;
    }

    function _nodeProps(node) {
        return node && node.ready && node.properties ? node.properties : {};
    }

    function deviceName(node) {
        if (!node)
            return "Unknown device";
        const props = root._nodeProps(node);
        const nickname = root._friendlyLabel(node.nickname || node.nick || props["node.nick"] || props["device.profile.description"] || "");
        if (nickname)
            return nickname;
        return root._friendlyLabel(node.description || props["node.description"] || node.name || "Unknown device");
    }

    function isHeadphones(node) {
        if (!node)
            return false;
        const props = root._nodeProps(node);
        const blob = String([
            node.name, node.description, node.nickname,
            props["device.icon-name"] || "", props["device.product.name"] || ""
        ].join(" ")).toLowerCase();
        return blob.includes("headphone") || blob.includes("headset")
            || blob.includes("earbud") || blob.includes("earphone") || blob.includes("airpod");
    }

    // Material Symbol name for an output device row.
    function sinkGlyph(node) {
        if (!node)
            return "speaker";
        if (root.isHeadphones(node))
            return "headphones";
        const props = root._nodeProps(node);
        const blob = String([
            node.name, node.description, node.nickname,
            props["device.icon-name"] || "", props["device.product.name"] || ""
        ].join(" ")).toLowerCase();
        if (blob.includes("bluetooth"))
            return "bluetooth_audio";
        if (blob.includes("hdmi") || blob.includes("display"))
            return "tv";
        return "speaker";
    }

    // Material Symbol name for an input device row.
    function sourceGlyph(node) {
        if (!node)
            return "mic";
        const props = root._nodeProps(node);
        const blob = String([
            node.name, node.description, node.nickname, props["device.icon-name"] || ""
        ].join(" ")).toLowerCase();
        if (blob.includes("headset"))
            return "headphones";
        if (blob.includes("bluetooth"))
            return "bluetooth_audio";
        if (blob.includes("webcam") || blob.includes("camera"))
            return "videocam";
        return "mic";
    }

    // Material Symbol name for the hero icon, tiered by output level.
    function outputIcon() {
        if (!root.hasSink)
            return "volume_off";
        if (root.isHeadphones(root.sink))
            return "headphones";
        if (root.muted)
            return "volume_off";
        if (root.volume >= 0.67)
            return "volume_up";
        if (root.volume >= 0.34)
            return "volume_down";
        if (root.volume > 0)
            return "volume_mute";
        return "volume_off";
    }

    // Playful mood name for a given output level -- mirrors Omarchy's own
    // audio panel (plugins/panels/audio/Model.js: outputVolumeName), so
    // Celeste's popout and the stock one read the same at the same volume.
    function outputVolumeName(volume, muted) {
        if (muted)
            return "Muted";
        const p = Math.round((volume === undefined ? root.volume : volume) * 100);
        if (p === 0)
            return "Silenced";
        if (p >= 100)
            return "Concert hall";
        if (p >= 85)
            return "Party mode";
        if (p >= 70)
            return "Cranked up";
        if (p >= 50)
            return "Steady groove";
        if (p >= 30)
            return "Easy listening";
        if (p >= 15)
            return "Murmur";
        return "Whisper";
    }

    function setDefaultSink(node) {
        if (!node)
            return;
        Pipewire.preferredDefaultAudioSink = node;
        if (node.id !== undefined && node.name)
            Quickshell.execDetached(["omarchy-audio-output-set-default", String(node.id), String(node.name)]);
    }

    function setDefaultSource(node) {
        if (!node)
            return;
        Pipewire.preferredDefaultAudioSource = node;
        if (node.id !== undefined && node.name)
            Quickshell.execDetached(["omarchy-audio-input-set-default", String(node.id), String(node.name)]);
    }

    property PwObjectTracker tracker: PwObjectTracker {
        objects: [root.sink, root.source].concat(root.nodes)
    }
}
