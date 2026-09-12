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

    readonly property bool hasSink: !!(sink && sink.audio)
    readonly property bool hasSource: !!(source && source.audio)

    readonly property real volume: hasSink ? sink.audio.volume : 0
    readonly property bool muted: hasSink ? sink.audio.muted : false
    readonly property real sourceVolume: hasSource ? source.audio.volume : 0
    readonly property bool sourceMuted: hasSource ? source.audio.muted : false

    // Volume can exceed 1.0 (PipeWire allows boost); clamp for display only.
    readonly property int volumePercent: Math.round(Math.min(1, volume) * 100)
    readonly property int sourceVolumePercent: Math.round(Math.min(1, sourceVolume) * 100)

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

    property PwObjectTracker tracker: PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
