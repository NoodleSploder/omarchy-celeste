pragma Singleton

// A full Material 3 colour scheme synthesised from the active Omarchy theme.
//
// Omarchy's qs.Commons Color exposes a handful of flat tokens (background,
// foreground, accent, urgent, muted) read from the current theme file. Material
// 3 components expect ~50 named roles. This singleton derives the whole scheme
// from those few bases, so Celeste follows omarchy-theme-switcher instead of
// carrying a palette of its own.
//
// Every step is expressed as "contrast away from the surface" rather than
// "lighter" or "darker", so one set of numbers serves light and dark themes.

import QtQuick
import qs.Commons

QtObject {
    id: root

    readonly property color base: Color.background
    readonly property color fg: Color.foreground
    readonly property color accent: Color.accent
    readonly property color urgent: Color.urgent
    readonly property color muted: Color.muted

    // WCAG relative luminance; decides the polarity of every tonal step.
    function luminance(c) {
        function lin(v) {
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    readonly property bool light: luminance(base) > 0.5

    // Toward white for t > 0, toward black for t < 0.
    function shade(c, t) {
        if (t >= 0)
            return Qt.rgba(c.r + (1 - c.r) * t, c.g + (1 - c.g) * t, c.b + (1 - c.b) * t, c.a);
        const k = 1 + t;
        return Qt.rgba(c.r * k, c.g * k, c.b * k, c.a);
    }

    // Positive t always means "more contrast against the background".
    function lift(c, t) {
        return shade(c, root.light ? -t : t);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // Readable foreground for an arbitrary container colour.
    function on(c) {
        return luminance(c) > 0.5 ? shade(c, -0.82) : shade(c, 0.9);
    }

    // Omarchy has no success token, so Celeste supplies one.
    readonly property color success: Qt.rgba(0.42, 0.71, 0.44, 1)

    readonly property QtObject palette: QtObject {
        id: pal

        // neutral / surface family
        readonly property color m3background: root.base
        readonly property color m3onBackground: root.fg
        readonly property color m3surface: root.base
        readonly property color m3onSurface: root.fg
        readonly property color m3surfaceDim: root.lift(root.base, -0.04)
        readonly property color m3surfaceBright: root.lift(root.base, 0.14)
        readonly property color m3surfaceVariant: root.lift(root.base, 0.10)
        readonly property color m3onSurfaceVariant: root.mix(root.fg, root.muted, 0.55)
        readonly property color m3surfaceTint: root.accent

        readonly property color m3surfaceContainerLowest: root.lift(root.base, -0.03)
        readonly property color m3surfaceContainerLow: root.lift(root.base, 0.04)
        readonly property color m3surfaceContainer: root.lift(root.base, 0.07)
        readonly property color m3surfaceContainerHigh: root.lift(root.base, 0.11)
        readonly property color m3surfaceContainerHighest: root.lift(root.base, 0.16)

        readonly property color m3outline: root.muted
        readonly property color m3outlineVariant: root.mix(root.muted, root.base, 0.55)
        readonly property color m3neutral: root.muted
        readonly property color m3shadow: Qt.rgba(0, 0, 0, 1)
        readonly property color m3scrim: Qt.rgba(0, 0, 0, 1)

        readonly property color m3inverseSurface: root.fg
        readonly property color m3inverseOnSurface: root.base
        readonly property color m3inversePrimary: root.shade(root.accent, root.light ? 0.35 : -0.35)

        // primary
        readonly property color m3primary: root.accent
        readonly property color m3onPrimary: root.on(root.accent)
        readonly property color m3primaryContainer: root.lift(root.accent, -0.45)
        readonly property color m3onPrimaryContainer: root.lift(root.accent, 0.55)
        readonly property color m3primaryFixed: root.shade(root.accent, 0.45)
        readonly property color m3primaryFixedDim: root.shade(root.accent, 0.2)
        readonly property color m3onPrimaryFixed: root.shade(root.accent, -0.78)
        readonly property color m3onPrimaryFixedVariant: root.shade(root.accent, -0.5)

        // secondary -- a desaturated sibling of the accent
        readonly property color _secondary: root.mix(root.accent, root.muted, 0.45)
        readonly property color m3secondary: pal._secondary
        readonly property color m3onSecondary: root.on(pal._secondary)
        readonly property color m3secondaryContainer: root.lift(root.base, 0.13)
        readonly property color m3onSecondaryContainer: root.fg
        readonly property color m3secondaryFixed: root.shade(pal._secondary, 0.45)
        readonly property color m3secondaryFixedDim: root.shade(pal._secondary, 0.2)
        readonly property color m3onSecondaryFixed: root.shade(pal._secondary, -0.78)
        readonly property color m3onSecondaryFixedVariant: root.shade(pal._secondary, -0.5)

        // tertiary -- accent rotated 30 degrees around the wheel
        readonly property color m3tertiary: Qt.hsla(
            (root.accent.hslHue + 0.083) % 1.0,
            Math.max(0.18, root.accent.hslSaturation * 0.85),
            root.accent.hslLightness, 1)
        readonly property color m3onTertiary: root.on(pal.m3tertiary)
        readonly property color m3tertiaryContainer: root.lift(pal.m3tertiary, -0.45)
        readonly property color m3onTertiaryContainer: root.lift(pal.m3tertiary, 0.55)
        readonly property color m3tertiaryFixed: root.shade(pal.m3tertiary, 0.45)
        readonly property color m3tertiaryFixedDim: root.shade(pal.m3tertiary, 0.2)
        readonly property color m3onTertiaryFixed: root.shade(pal.m3tertiary, -0.78)
        readonly property color m3onTertiaryFixedVariant: root.shade(pal.m3tertiary, -0.5)

        // error / success
        readonly property color m3error: root.urgent
        readonly property color m3onError: root.on(root.urgent)
        readonly property color m3errorContainer: root.lift(root.urgent, -0.45)
        readonly property color m3onErrorContainer: root.lift(root.urgent, 0.55)
        readonly property color m3success: root.success
        readonly property color m3onSuccess: root.on(root.success)
        readonly property color m3successContainer: root.lift(root.success, -0.45)
        readonly property color m3onSuccessContainer: root.lift(root.success, 0.55)
    }

    // ------------------------------------------------------------ tPalette
    //
    // The translucent variant. Only surface roles differ, and only while
    // transparency is enabled -- otherwise it is the opaque palette.

    readonly property bool transparency: Config.appearance.transparency.enabled
    readonly property real surfaceAlpha: Config.appearance.transparency.base
    readonly property real containerAlpha: Config.appearance.transparency.layers

    function alpha(c, a) {
        return root.transparency ? Qt.rgba(c.r, c.g, c.b, a) : c;
    }

    readonly property QtObject tPalette: QtObject {
        readonly property color m3background: root.alpha(pal.m3background, root.surfaceAlpha)
        readonly property color m3onBackground: pal.m3onBackground
        readonly property color m3surface: root.alpha(pal.m3surface, root.surfaceAlpha)
        readonly property color m3onSurface: pal.m3onSurface
        readonly property color m3surfaceDim: root.alpha(pal.m3surfaceDim, root.surfaceAlpha)
        readonly property color m3surfaceBright: root.alpha(pal.m3surfaceBright, root.surfaceAlpha)
        readonly property color m3surfaceVariant: root.alpha(pal.m3surfaceVariant, root.containerAlpha)
        readonly property color m3onSurfaceVariant: pal.m3onSurfaceVariant
        readonly property color m3surfaceContainerLowest: root.alpha(pal.m3surfaceContainerLowest, root.containerAlpha)
        readonly property color m3surfaceContainerLow: root.alpha(pal.m3surfaceContainerLow, root.containerAlpha)
        readonly property color m3surfaceContainer: root.alpha(pal.m3surfaceContainer, root.containerAlpha)
        readonly property color m3surfaceContainerHigh: root.alpha(pal.m3surfaceContainerHigh, root.containerAlpha)
        readonly property color m3surfaceContainerHighest: root.alpha(pal.m3surfaceContainerHighest, root.containerAlpha)
    }
}
