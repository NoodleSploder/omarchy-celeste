pragma Singleton

// Celeste's design system: Material 3 Expressive rounding, spacing, padding,
// type scale, motion curves and component sizes.
//
// The values are the Material 3 Expressive specification figures, matching the
// set Caelestia uses (see ATTRIBUTION.md). They are plain data, so this is the
// authoritative copy -- nothing native is needed to serve them.

import QtQuick
import qs.Commons

QtObject {
    id: root

    // User-facing scale factors. Each family is scaled independently so a user
    // can loosen spacing without also inflating corner radii.
    property real roundingScale: 1
    property real spacingScale: 1
    property real paddingScale: 1
    property real fontScale: 1

    function _s(value, scale) {
        return Math.round(value * scale);
    }

    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: root._s(4, root.roundingScale)
        readonly property int small: root._s(8, root.roundingScale)
        readonly property int medium: root._s(12, root.roundingScale)
        readonly property int large: root._s(16, root.roundingScale)
        readonly property int largeIncreased: root._s(20, root.roundingScale)
        readonly property int extraLarge: root._s(28, root.roundingScale)
        readonly property int extraLargeIncreased: root._s(32, root.roundingScale)
        readonly property int extraExtraLarge: root._s(48, root.roundingScale)
        // Any radius past half the shorter side pins a pill; this is the
        // "fully rounded" sentinel.
        readonly property int full: 1000000
    }

    readonly property QtObject spacing: QtObject {
        readonly property int extraSmall: root._s(4, root.spacingScale)
        readonly property int small: root._s(8, root.spacingScale)
        readonly property int medium: root._s(12, root.spacingScale)
        readonly property int large: root._s(16, root.spacingScale)
        readonly property int largeIncreased: root._s(20, root.spacingScale)
        readonly property int extraLarge: root._s(28, root.spacingScale)
        readonly property int extraLargeIncreased: root._s(32, root.spacingScale)
        readonly property int extraExtraLarge: root._s(48, root.spacingScale)
    }

    readonly property QtObject padding: QtObject {
        readonly property int extraSmall: root._s(4, root.paddingScale)
        readonly property int small: root._s(8, root.paddingScale)
        readonly property int medium: root._s(12, root.paddingScale)
        readonly property int large: root._s(16, root.paddingScale)
        readonly property int largeIncreased: root._s(20, root.paddingScale)
        readonly property int extraLarge: root._s(28, root.paddingScale)
        readonly property int extraLargeIncreased: root._s(32, root.paddingScale)
        readonly property int extraExtraLarge: root._s(48, root.paddingScale)
    }

    readonly property QtObject fontSize: QtObject {
        readonly property int small: root._s(11, root.fontScale)
        readonly property int smaller: root._s(12, root.fontScale)
        readonly property int normal: root._s(13, root.fontScale)
        readonly property int larger: root._s(15, root.fontScale)
        readonly property int large: root._s(18, root.fontScale)
        readonly property int extraLarge: root._s(28, root.fontScale)
    }

    // ------------------------------------------------------------- motion
    //
    // Durations in ms; curves as cubic bezier control points consumed directly
    // by easing.bezierCurve. The "expressive" families are what give the shell
    // its slight overshoot -- note the >1 control values on the spatial curves.

    readonly property QtObject anim: QtObject {
        readonly property QtObject durations: QtObject {
            readonly property int small: 200
            readonly property int normal: 400
            readonly property int large: 600
            readonly property int extraLarge: 1000
            readonly property int expressiveFastSpatial: 350
            readonly property int expressiveDefaultSpatial: 500
            readonly property int expressiveSlowSpatial: 650
            readonly property int expressiveFastEffects: 150
            readonly property int expressiveDefaultEffects: 200
            readonly property int expressiveSlowEffects: 300
        }

        readonly property var emphasized: [0.05, 0, 2.0 / 15.0, 0.06, 1.0 / 6.0, 0.4, 5.0 / 24.0, 0.82, 0.25, 1, 1, 1]
        readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        readonly property var standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property var standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property var expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property var expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property var expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property var expressiveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
        readonly property var expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property var expressiveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    }

    // -------------------------------------------------------------- fonts

    // Families come from config, defaulting to the faces Caelestia used.
    //
    // Deliberately NOT inherited from Style.font.family: Omarchy's font setting
    // is shared with the terminals (omarchy font set rewrites alacritty, kitty,
    // ghostty and foot), so it is monospace by design. A shell bar wants a
    // proportional face, and following the terminal font would make that
    // impossible without breaking every terminal.
    readonly property QtObject font: QtObject {
        readonly property string sans: Config.appearance.font.sans
        readonly property string mono: Config.appearance.font.mono
        readonly property string material: Config.appearance.font.material

        readonly property QtObject body: QtObject {
            readonly property font small: Qt.font({ family: root.font.sans, pointSize: root.fontSize.small })
            readonly property font smaller: Qt.font({ family: root.font.sans, pointSize: root.fontSize.smaller })
            readonly property font normal: Qt.font({ family: root.font.sans, pointSize: root.fontSize.normal })
            readonly property font larger: Qt.font({ family: root.font.sans, pointSize: root.fontSize.larger })
            readonly property font large: Qt.font({ family: root.font.sans, pointSize: root.fontSize.large })
            readonly property font extraLarge: Qt.font({ family: root.font.sans, pointSize: root.fontSize.extraLarge })
        }

        readonly property QtObject icon: QtObject {
            readonly property font small: Qt.font({ family: root.font.material, pointSize: root.fontSize.larger })
            readonly property font normal: Qt.font({ family: root.font.material, pointSize: root.fontSize.large })
            readonly property font large: Qt.font({ family: root.font.material, pointSize: root.fontSize.extraLarge })
        }
    }

    // -------------------------------------------------------------- sizes

    readonly property QtObject sizes: QtObject {
        readonly property QtObject bar: QtObject {
            readonly property int innerWidth: 40
            readonly property int windowPreviewSize: 400
            readonly property int trayMenuWidth: 300
            readonly property int batteryWidth: 250
            readonly property int networkWidth: 320
            readonly property int kbLayoutWidth: 320
        }

        readonly property QtObject dashboard: QtObject {
            readonly property int tabIndicatorHeight: 3
            readonly property int tabIndicatorSpacing: 5
            readonly property int userWidth: 340
            readonly property int logoSize: 30
            readonly property int uptimeSize: 30
            readonly property int dateTimeWidth: 110
            readonly property int mediaWidth: 200
            readonly property int mediaProgressSweep: 180
            readonly property int mediaProgressThickness: 6
            readonly property int resourceProgressThickness: 6
            readonly property int weatherWidth: 275
            readonly property int mediaCoverArtSize: 200
            readonly property int perfHeroCardWidth: 400
            readonly property int perfUsageShapeSize: 100
            readonly property int perfNetworkCardWidth: 390
            readonly property int perfNetworkCardHeight: 220
        }

        readonly property QtObject launcher: QtObject {
            readonly property int itemWidth: 600
            readonly property int itemHeight: 57
            readonly property int wallpaperWidth: 280
            readonly property int wallpaperHeight: 200
        }

        readonly property QtObject notifs: QtObject {
            readonly property int width: 430
            readonly property int badge: 20
        }

        readonly property QtObject osd: QtObject {
            readonly property int sliderWidth: 30
            readonly property int sliderHeight: 150
        }

        readonly property QtObject session: QtObject {
            readonly property int button: 80
        }

        readonly property QtObject sidebar: QtObject {
            readonly property int width: 430
        }

        readonly property QtObject utilities: QtObject {
            readonly property int width: 430
            readonly property int toastWidth: 430
        }
    }
}
