pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../components"
import "../../services"

// The right-edge drag-out panel from next_steps.md, ported from the local
// Caelestia backup's modules/drawers/osd + modules/drawers/session (see
// services/SidePanel.qml for the mechanic and why notifications -- Caelestia's
// third stage -- aren't included).
//
// This deliberately does NOT follow Caelestia's own Panels.qml ordering --
// an earlier version of this file did, and was corrected on explicit user
// direction (2026-09-13): "volume/brightness sliders on the left, power
// buttons in the middle with a panel taller than the sliders, notifications
// on the right full height." Spelled out spatially, right (border) to left
// (outermost): notifications, session, sliders.
//
// Stage 0 (hover): an always-present hit area at the right edge -- `hoverZone`
// below -- reveals the OSD just by hovering it, even before anything has
// actually changed volume/brightness. This has to be a separate, non-
// collapsing item from the animated reveal: the reveal's width is 0 while
// closed (that's what makes it invisible/unclickable when idle), so nothing
// hoverable would exist there at all if hovering were only detected on it.
// Stage 1 (reactive): volume + brightness vertical sliders also auto-show
// whenever either changes, regardless of source (scroll, media keys,
// hardware buttons -- see services/SidePanel.qml's Connections). Sliders are
// the innermost/always-present tier -- compact, natural size, no explicit
// height override.
// Stage 2 (drag): press anywhere on the card's background (not on a slider or
// a session button directly -- see `dragArea`'s position in the stacking
// order below) and drag left past SidePanel.dragThreshold to bring in the
// Power/Lock/Logout/Suspend row, sized to `sessionPaneHeight` -- noticeably
// taller than the sliders' own compact size, so the middle pane visibly
// grows once session joins.
// Stage 3 (drag further): the notification drawer (NotifList.qml, backed by
// services/Notifs.qml) joins at the border-adjacent slot, and it is ALWAYS
// full screen height whenever it is open at all -- see `notifsRowHeight`
// below, there is no separate "tall then full" tier the way an earlier
// draft had it. Session and the sliders are unaffected by notifications
// opening; they just get centred within whatever height the row ends up at.
//
// Volume/brightness, session and notifications are three INDEPENDENT
// panels in services/SidePanel.qml (`sessionVisible`/`notifsVisible` are
// plain properties, not derived from one shared stage number) that this
// ONE drag gesture happens to coordinate together, because a physical drag
// is a single continuous motion starting from the sliders. Nothing stops a
// future trigger from opening exactly one of them -- see that file's
// header for the full reasoning. When more than one is open they merge
// into a single card here (an ordinary consequence of a RowLayout sized
// from its visible children, not special-cased); when only one is open it
// renders as its own standalone card the same way.
//
// `row` below is a RightToLeft RowLayout, so declaration order IS visual
// order: notifsColumn declared first = rightmost/flush-border, sessionColumn
// second = middle, osdColumn last = leftmost/outermost. Each divider is
// gated on the conditionally-visible column immediately outward of it
// (divider-by-notifs on notifsOpen, divider-by-session on sessionOpen) --
// sliders have no gate since they're always present whenever root.open is
// true -- so any subset of the three still lays out with no dangling
// divider, the same robustness the previous (mirrored) order had.
Item {
    id: root

    required property var screen
    property int borderThickness: 0
    // Height of the top bar (or the plain top border when the bar is
    // hidden) -- the panel's usable area starts below it, so nothing here
    // ever covers the bar. Bar.qml passes the same value it gives the
    // Border's own borderTop.
    property int topInset: 0

    readonly property string screenName: root.screen ? String(root.screen.name) : ""

    // Only the monitor SidePanel.screenName currently names shows the panel.
    // Celeste instantiates one of these per screen, all watching the same
    // singleton, so without this gate every monitor revealed the sliders,
    // session row and notification drawer at once.
    readonly property bool open: SidePanel.osdVisible && SidePanel.screenName === root.screenName
    readonly property bool sessionOpen: root.open && SidePanel.sessionVisible
    readonly property bool notifsOpen: root.open && SidePanel.notifsVisible

    // The screen's own full height, for the full-height tier below. `root`'s
    // parent is the per-screen content item Bar.qml instantiates this in
    // (the same fullscreen surface the bar itself draws in), so this is the
    // real monitor height, not some already-reduced work area.
    readonly property real screenHeight: root.parent ? root.parent.height : (root.screen ? root.screen.height : 900)

    // The band the panel is actually allowed to occupy: below the bar, above
    // the bottom border. Every vertical size and the panel's own position
    // are expressed against THIS rather than the raw screen, which is what
    // keeps the full-height notification drawer off the top bar -- and it
    // falls out of one formula instead of a special case, because a card
    // centred in this band that happens to be exactly this tall lands
    // flush between the bar and the bottom border on its own.
    readonly property real usableHeight: Math.max(0, root.screenHeight - root.topInset - root.borderThickness)

    // The session (power/lock/logout/suspend) pane's own height -- noticeably
    // taller than the sliders' compact natural size, well short of the
    // screen. This is what makes "the middle pane" visibly taller than the
    // sliders per the user's spec; the buttons themselves stay their natural
    // size and are centred inside this via the filler Items around them
    // below, the same way `Layout.alignment: Qt.AlignVCenter` centres the
    // whole sessionColumn box within a taller row.
    //
    // The floor is the column's own natural height rather than a literal,
    // so adding or resizing a button can't quietly overflow the pane: five
    // buttons at the current size already need more than the 420 this used
    // to hardcode. Not circular -- a ColumnLayout's implicitHeight comes
    // from its children, not from the height assigned to it.
    readonly property real sessionPaneHeight: Math.min(root.usableHeight, Math.max(sessionColumn.implicitHeight, root.usableHeight * 0.55))

    // The notifications column always asks for full screen height whenever
    // it is open at all -- there is no separate tall/full tier. A RowLayout's
    // implicit height is the max of its VISIBLE children's own preferred/
    // implicit heights, so setting this on notifsColumn's Layout.
    // preferredHeight below is enough to make the whole merged card grow to
    // match -- no separate override needed on `reveal` or `row`.
    readonly property real notifsRowHeight: Math.max(0, root.usableHeight - Tokens.padding.large * 2)

    // Flush to the screen edge, NOT inset by the border: the idle hover strip
    // has to sit ON the border, which is compositor-reserved space (Bar.qml's
    // exclusion windows claim borderThickness on each edge), so hovering it
    // costs no app area at all. `reveal` carries the border inset itself
    // instead, so the card still stops at the border's inner edge.
    anchors.right: parent.right

    // Centred in the usable band (below the bar, above the bottom border),
    // not on the raw screen. anchors.verticalCenter would split the reserved
    // space evenly top and bottom, so a full-height card would still have
    // covered the bottom half of the bar; this reserves it all at the top
    // where it belongs. hoverZone and reveal both centre on THIS item, so
    // positioning root is enough to move them together. y recomputes from
    // root.height, which is already animating, so it stays in step with the
    // open/close motion without a Behavior of its own.
    y: root.topInset + (root.usableHeight - root.height) / 2

    // The union of the static hover strip and however much of the card is
    // CURRENTLY revealed. Bar.qml's Region { item: sidePanel } gates pointer
    // input to exactly this geometry (see CLAUDE.md: "region gates pointer
    // input, must cover the actual visual area"), so it has to cover the open
    // card -- but it must not claim more than the hover strip while closed,
    // or it eats clicks in whatever app is underneath.
    //
    // reveal.WIDTH, not reveal.implicitWidth: the implicit value is the
    // target the card would occupy if it were open, which stays at the
    // sliders' full width even while closed -- so keying off it made the
    // shut panel swallow a card's worth of the screen edge permanently.
    // The live width is 0 when closed and animates, so the input region
    // tracks what's actually on screen.
    implicitWidth: Math.max(hoverZone.implicitWidth, reveal.width + root.borderThickness)
    implicitHeight: Math.max(hoverZone.implicitHeight, reveal.height)
    width: implicitWidth
    height: implicitHeight

    // Single source of truth for SidePanel.hovered -- covers the whole union
    // area from outside, so moving between the hover zone, the sliders and
    // the session buttons never produces a spurious exit/enter flicker the
    // way separate per-child MouseAreas did.
    HoverHandler {
        id: hoverHandler
        target: root
        // Passes this instance's own screen: for a hover the pointer is the
        // authority, not the focused window -- hovering the right edge of a
        // monitor you have not clicked into yet should still open it there.
        onHoveredChanged: SidePanel.setHovered(hoverHandler.hovered, root.screenName)
    }

    // Static, always-present hit target: "that area of the screen" the user
    // hovers to reveal the sliders before anything has changed on its own.
    //
    // Exactly as wide as the screen border and no wider. It used to be the
    // width of the closed card (slider + padding, ~62px), which reached well
    // past the border into the app underneath and swallowed clicks there.
    // The border strip is already reserved by the compositor, so confining
    // the strip to it costs the user nothing. The floor keeps a usable target
    // if borders are configured off entirely, where borderThickness is 0.
    Item {
        id: hoverZone
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Math.max(root.borderThickness, Config.border.minThickness)
        implicitHeight: Tokens.sizes.osd.sliderHeight * 2 + Tokens.spacing.medium + Tokens.padding.large * 2
    }

    // The animated slide. `card` (below) fills this exactly, so anything that
    // needs to sit outside the clip -- the border-join fillets -- anchors to
    // `reveal`'s own edges instead of `card`'s, from outside this Item
    // entirely (see the fillets near the bottom of this file: "The fillets
    // sit OUTSIDE this item's bounds" is the same rule modules/bar/Popout.qml
    // documents for its own downward-growing panel).
    Item {
        id: reveal

        // The border inset lives here now rather than on root, so the card
        // still stops at the border's inner edge while root itself reaches
        // the screen edge for the hover strip.
        anchors.right: parent.right
        anchors.rightMargin: root.borderThickness
        anchors.verticalCenter: parent.verticalCenter

        // No outer padding added here any more: each pane in `row` carries
        // its own padding, because each one is now its own rounded block
        // rather than content floating inside one big card.
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        width: root.open ? implicitWidth : 0
        // Explicit, unlike width's own implicit-fallback default: Behavior
        // only intercepts a property that has a real QML binding written to
        // it. Item's built-in "height follows implicitHeight when nothing
        // else claims height" fallback does the assignment at the C++ level,
        // outside that interception path, so `Behavior on height` below
        // silently did nothing until this line existed to give it something
        // to intercept -- confirmed with a live trace: height was still
        // jumping in a single frame even with the Behavior in place, while
        // width (already explicit) animated correctly.
        height: implicitHeight
        // No separate opacity fade: an earlier version faded out over
        // FastEffects (150ms) while width collapsed over DefaultSpatial
        // (500ms), so the card went fully transparent well before the
        // collapse animation finished -- it looked like the panel just
        // vanished instead of sliding shut. Width (and height, below) alone
        // now drive the whole open/close motion, so closing visibly slides
        // the card back into the border instead of cutting out early.
        visible: width > 0
        clip: true

        // row stays right-anchored inside this clipping Item, so animating
        // THIS width is what actually produces the slide -- as it grows,
        // more of row's now-already-full-width left side (the OSD sliders,
        // pushed further left once session is visible) comes out from under
        // the clip. HEIGHT needs the same Behavior for the same reason: this
        // Item has no explicit `height:` binding, so it silently follows
        // Qt Quick's built-in height-equals-implicitHeight default -- and
        // without a Behavior intercepting that, every implicitHeight change
        // (session/notifications joining or leaving, notifications' own
        // tall<->full swing) snapped instantly in a single frame while width
        // was still animating, which is what read as "flicker": the card's
        // vertical extent jumping while its horizontal extent eased in.
        Behavior on width {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Behavior on height {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Background drag-to-reveal-session catcher. Declared BEFORE `row`
        // so its descendants (the sliders, the session buttons) paint -- and
        // hit-test -- on top of it: a press directly on a slider or a button
        // still goes to that widget's own MouseArea first, and this one only
        // ever sees presses landing in the padding/gaps around them. The
        // previous version of this file anchored an equivalent MouseArea
        // AFTER the slider content as a sibling, which put it in front of
        // the whole slider subtree and silently ate every slider drag --
        // never reported by the user, caught only while rebuilding this
        // layout for the border-attachment work.
        MouseArea {
            id: dragArea
            anchors.fill: parent
            property real dragStartX: 0
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor

            onPressed: mouse => {
                dragArea.dragStartX = mouse.x;
                SidePanel.beginDrag();
            }
            onPositionChanged: mouse => {
                if (pressed)
                    SidePanel.updateDrag(mouse.x - dragArea.dragStartX);
            }
            onReleased: SidePanel.endDrag()
        }

        RowLayout {
            id: row

            // Pinned to the border edge, NOT centred. The comment on
            // reveal's width Behavior has always described it as
            // right-anchored -- that is what makes growing the clip box
            // reveal content leftward from the border -- but the code said
            // `anchors.centerIn: parent`, which is different in exactly the
            // way that shows up mid-animation: while reveal is still
            // narrower than row, a centred row overflows BOTH sides and gets
            // cropped on both, so the border-adjacent column is chopped off
            // too and the whole card's contents appear to slide/jump
            // sideways as the crop boundaries move. Right-anchored, the
            // border edge stays put and only the outer (left) side is ever
            // under the clip.
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // Zero spacing and no right margin: the panes butt directly
            // against each other and against the border, so their union
            // reads as one continuous stepped silhouette rather than three
            // separate floating cards. Each pane supplies its own padding.
            spacing: 0
            layoutDirection: Qt.RightToLeft

            // Declared FIRST = rightmost/flush-border in this RightToLeft
            // row, and the tallest step. Loaded lazily so the filesystem-
            // watching service behind it only spins up the first time the
            // drawer is actually pulled out.
            Pane {
                id: notifsPane

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Tokens.sizes.notifs.width + Tokens.padding.large * 2
                Layout.preferredHeight: root.notifsRowHeight + Tokens.padding.large * 2
                visible: root.notifsOpen

                // Square where the arches take over. This pane is always
                // exactly full height, so its top and bottom edges sit flush
                // against the bar and the bottom border rather than floating
                // -- a convex radius there would round the pane away from
                // them and leave a notch of wallpaper in the corner. The two
                // fillets below curve it INTO them instead.
                topLeftRadius: 0
                bottomLeftRadius: 0

                Loader {
                    anchors.centerIn: parent
                    // Explicit height, natural width: NotifList anchors its
                    // own top/bottom to this Loader for height and pins its
                    // width from its header (see that file), so neither side
                    // depends on the pane that's sized from it.
                    height: root.notifsRowHeight
                    active: root.notifsOpen
                    sourceComponent: NotifList {}
                }

                // Arch into the top bar. Same derivation as every other
                // fillet here: the bar continues leftward along this square's
                // TOP edge and the pane continues downward along its RIGHT
                // edge, so the solid quadrant is top-right and the scoop
                // faces the open wallpaper below-left. The bar, the border
                // frame and these panes are all m3surface, so the join reads
                // as one continuous surface.
                InvertedCorner {
                    anchors.right: parent.left
                    anchors.top: parent.top
                    size: Tokens.rounding.extraLarge
                    colour: Colours.tPalette.m3surface
                    corner: InvertedCorner.TopRight
                }

                // Arch into the bottom border: border continues leftward
                // along the BOTTOM edge, pane continues upward along the
                // RIGHT edge -- solid quadrant bottom-right.
                InvertedCorner {
                    anchors.right: parent.left
                    anchors.bottom: parent.bottom
                    size: Tokens.rounding.extraLarge
                    colour: Colours.tPalette.m3surface
                    corner: InvertedCorner.BottomRight
                }
            }

            // Middle step: session buttons, sized noticeably taller than the
            // sliders (root.sessionPaneHeight) per the user's spec, and
            // shorter than notifications, so it steps in on both sides.
            Pane {
                id: sessionPane

                Layout.alignment: Qt.AlignVCenter
                // Width follows the buttons rather than restating their size:
                // sessionColumn is centred in this pane, so its implicit
                // width depends only on its children, never on the pane it
                // sizes. Change SessionButton and the pane widens with it.
                Layout.preferredWidth: sessionColumn.implicitWidth + Tokens.padding.large * 2
                Layout.preferredHeight: root.sessionPaneHeight + Tokens.padding.large * 2
                visible: root.sessionOpen

                // The buttons keep their natural size and are centred in the
                // taller pane by the filler Items around them -- a forced
                // height on a ColumnLayout leaves the slack at the bottom
                // rather than centring its own children.
                ColumnLayout {
                    id: sessionColumn
                    anchors.centerIn: parent
                    height: root.sessionPaneHeight
                    spacing: Tokens.spacing.medium

                    Item { Layout.fillHeight: true }

                    SessionButton { icon: "power_settings_new"; onClicked: Quickshell.execDetached(["omarchy-system-shutdown"]) }
                    SessionButton { icon: "lock"; onClicked: Quickshell.execDetached(["omarchy-system-lock"]) }
                    // Celeste's own settings, deliberately the middle button
                    // of the five -- the only one here that isn't a system
                    // power action. Passes this instance's screen so the
                    // panel opens on the monitor the side panel is showing on.
                    SessionButton { icon: "settings"; onClicked: SettingsPanel.toggle(root.screenName) }
                    SessionButton { icon: "logout"; onClicked: Quickshell.execDetached(["omarchy-system-logout"]) }
                    SessionButton { icon: "bedtime"; onClicked: Quickshell.execDetached(["systemctl", "suspend"]) }

                    Item { Layout.fillHeight: true }
                }

                // Steps up/down into the notifications pane on its right.
                StepFillets { showing: root.notifsOpen }
            }

            // Declared LAST = leftmost/outermost in this RightToLeft row,
            // and the shortest step. Always present whenever root.open --
            // the innermost tier, natural size, no height override.
            Pane {
                id: osdPane

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Tokens.sizes.osd.sliderWidth + Tokens.padding.large * 2
                Layout.preferredHeight: osdColumn.implicitHeight + Tokens.padding.large * 2

                ColumnLayout {
                    id: osdColumn
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.medium

                    VerticalSlider {
                        value: Audio.muted ? 0 : Math.min(1, Audio.volume)
                        icon: Audio.muted ? "volume_off" : (Audio.volume >= 0.67 ? "volume_up" : Audio.volume >= 0.34 ? "volume_down" : Audio.volume > 0 ? "volume_mute" : "volume_off")
                        onMoved: value => Audio.setVolume(value)
                        onToggled: Audio.toggleMute()
                    }

                    VerticalSlider {
                        visible: Brightness.available
                        value: Brightness.brightness
                        icon: "brightness_6"
                        onMoved: value => Brightness.setBrightness(value)
                    }
                }

                // Steps up/down into whichever pane is on its right --
                // session normally, notifications directly if session is
                // closed.
                StepFillets { showing: root.sessionOpen || root.notifsOpen }
            }
        }
    }

    // Border -> card, above the card (bridges the border strip continuing
    // upward past the card into the card's flush right edge). Hidden
    // whenever notifications is open, since it's always full screen height
    // then and the card genuinely touches the top/bottom edges -- no more
    // "border strip continuing past a floating card" to bridge. Faded
    // rather than hard-toggled: `visible` flips the instant notifsOpen
    // changes, but reveal's height takes DefaultSpatial (500ms) to actually
    // reach/leave full height, so a hard pop here would show the fillet
    // floating next to a card that's still mid-collapse/-grow.
    InvertedCorner {
        anchors.right: reveal.right
        anchors.bottom: reveal.top
        size: Config.border.rounding
        colour: Colours.tPalette.m3surface
        corner: InvertedCorner.BottomRight
        visible: opacity > 0
        opacity: root.open && !root.notifsOpen ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
    }

    // Border -> card, below the card.
    InvertedCorner {
        anchors.right: reveal.right
        anchors.top: reveal.bottom
        size: Config.border.rounding
        colour: Colours.tPalette.m3surface
        corner: InvertedCorner.TopRight
        visible: opacity > 0
        opacity: root.open && !root.notifsOpen ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
    }

    // One step of the staircase. Right corners always square -- the pane
    // either butts against the border (rightmost) or against the next pane
    // in (everything else), and in both cases a radius there would cut a
    // notch out of what should read as one continuous shape. Left corners
    // rounded, because that side is always exposed: a shorter pane never
    // reaches its taller neighbour's ends.
    //
    // Colours come straight from the singleton rather than a property on
    // root: QML inline components cannot see the enclosing file's ids.
    component Pane: Rectangle {
        color: Colours.tPalette.m3surface
        topRightRadius: 0
        bottomRightRadius: 0
        topLeftRadius: Tokens.rounding.extraLarge
        bottomLeftRadius: Tokens.rounding.extraLarge
    }

    // The concave joins where a shorter pane steps up into the taller one on
    // its right. Same derivation as the border joins at the bottom of this
    // file, with the taller pane playing the border's role: above the step,
    // the taller pane continues upward along the fillet's right edge and the
    // shorter pane continues leftward along its bottom edge, so the solid
    // quadrant is bottom-right; mirrored below the step.
    //
    // Fills its pane so its children can anchor to the pane's edges and then
    // sit just outside them -- nothing in this chain clips, which is what
    // lets them render in the notch.
    component StepFillets: Item {
        property bool showing: false

        anchors.fill: parent
        visible: showing

        InvertedCorner {
            anchors.right: parent.right
            anchors.bottom: parent.top
            size: Tokens.rounding.extraLarge
            colour: Colours.tPalette.m3surface
            corner: InvertedCorner.BottomRight
        }

        InvertedCorner {
            anchors.right: parent.right
            anchors.top: parent.bottom
            size: Tokens.rounding.extraLarge
            colour: Colours.tPalette.m3surface
            corner: InvertedCorner.TopRight
        }
    }

    component VerticalSlider: Item {
        id: slider

        required property real value
        property string icon: ""
        signal moved(real value)
        signal toggled

        implicitWidth: Tokens.sizes.osd.sliderWidth
        implicitHeight: Tokens.sizes.osd.sliderHeight

        Rectangle {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainerHighest
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            radius: Tokens.rounding.full
            height: parent.height * Math.max(0, Math.min(1, slider.value))
            color: Colours.palette.m3primary

            Behavior on height {
                enabled: !sliderArea.pressed
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.spacing.small
            text: slider.icon
            fontStyle: Tokens.font.icon.small
            color: slider.value > 0.5 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        }

        MouseArea {
            id: sliderArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => slider.moved(1 - mouse.y / height)
            onPositionChanged: mouse => { if (pressed) slider.moved(1 - Math.max(0, Math.min(height, mouse.y)) / height); }
            onClicked: mouse => { if (mouse.button === Qt.RightButton) slider.toggled(); }
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }
    }

    component SessionButton: Rectangle {
        id: button

        required property string icon
        signal clicked

        // Twice the 0.7 these were drawn at before, on explicit request. The
        // pane widens off this on its own -- see sessionPaneHeight's own note
        // and the pane's Layout.preferredWidth -- so this is the only number
        // to change if they're resized again.
        implicitWidth: Tokens.sizes.session.button * 1.4
        implicitHeight: Tokens.sizes.session.button * 1.4
        radius: Tokens.rounding.extraLarge
        color: buttonArea.containsMouse ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

        MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            fontStyle: Tokens.font.icon.large
            color: buttonArea.containsMouse ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
