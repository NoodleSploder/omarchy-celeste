pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "ClockModel.js" as Model
import "../../../core" as Celeste

// Omarchy's calendar, rendered inside a Celeste panel.
//
// Omarchy draws this in plugins/panels/clock/Panel.qml, where the content is
// inline inside a KeyboardPanel -- its own floating window. A floating card
// cannot be reparented into a panel that grows out of the border, so the view
// and its state are ported here instead, verbatim where possible, and the panel
// plumbing (open/close/focus/panel switching) is dropped.
//
// Upstream is MIT licensed; see ATTRIBUTION.md. It imports qs.Commons and qs.Ui
// directly, so Style, Color and the Ui controls are the very same ones the
// Omarchy panel uses and it renders identically.
//
// This is a fork: if Omarchy changes its calendar, this will not follow.
Item {
    id: root

    implicitWidth: calendarColumn.implicitWidth
    implicitHeight: Math.min(calendarColumn.implicitHeight, 560)

    // ---- date state

    property date today: new Date()
    readonly property string todayKey: Model.keyForDate(today)

    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property date viewDate: new Date(viewYear, viewMonth, 1)
    readonly property bool viewingCurrentMonth:
        viewYear === today.getFullYear() && viewMonth === today.getMonth()

    readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

    // ---- settings, persisted in Celeste's own config rather than a bar entry

    property var settings: Celeste.Config.clockPanel

    function setting(key, fallback) {
        const v = root.settings ? root.settings[key] : undefined;
        return (v === undefined || v === null) ? fallback : v;
    }

    function persistSettings(values) {
        const next = {};
        for (const k in root.settings)
            next[k] = root.settings[k];
        for (const k in values)
            next[k] = values[k];
        root.settings = next;
        Celeste.Config.writeClockPanel(next);
    }

    readonly property int birthYear: Model.parseBirthYear(setting("birthYear", 0), today.getFullYear())
    readonly property int age: Model.ageFromBirthYear(birthYear, today.getFullYear())
    readonly property int lifeExpectancy: Model.parseLifeExpectancy(setting("lifeExpectancy", 0))
    readonly property real lifeDone: Model.lifeProgress(age, lifeExpectancy)
    readonly property int lifeDonePercent: Model.lifeProgressPercent(age, lifeExpectancy)
    property bool editingLife: false

    readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", null), Qt.locale().firstDayOfWeek)
    readonly property var labelLocale: Qt.locale("en_US")
    readonly property string nextWeekStartLabel: labelLocale.dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)
    readonly property var weekdays: Model.weekdayOrder(weekStart)
    readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)

    // ---- metrics and colours, matching the Omarchy panel exactly

    readonly property color contentForeground: Color.foreground
    readonly property string contentFontFamily: Style.font.family

    readonly property int cellWidth: Style.space(52)
    readonly property int cellHeight: Style.space(34)
    readonly property int cellSpacing: Style.space(2)
    readonly property int weekColumnWidth: Style.space(32)
    readonly property int gutterWidth: Style.space(14)

    // ---- behaviour

    function goToToday() {
        root.viewYear = root.today.getFullYear();
        root.viewMonth = root.today.getMonth();
    }

    function moveMonth(delta) {
        const d = new Date(root.viewYear, root.viewMonth + delta, 1);
        root.viewYear = d.getFullYear();
        root.viewMonth = d.getMonth();
    }

    function setWeekStart(day) {
        root.persistSettings({ weekStartDay: Model.normalizedWeekStart(day, Qt.locale().firstDayOfWeek) });
    }

    function toggleWeekStart() {
        root.setWeekStart(Model.toggledWeekStart(root.weekStart));
    }

    // English short day names, matching the rest of the interface.
    function weekdayLabel(weekday) {
        return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase();
    }

    function startEditingLife() {
        root.editingLife = true;
    }

    function cancelEditingLife() {
        root.editingLife = false;
    }

    function clearLife() {
        root.persistSettings({ birthYear: 0, lifeExpectancy: 0 });
        root.editingLife = false;
    }

    function commitLife(born, expectancy) {
        root.persistSettings({
            birthYear: Number(born) || 0,
            lifeExpectancy: Number(expectancy) || 0
        });
        root.editingLife = false;
    }

    function handleLifeKey(event, other) {
        if (event.key === Qt.Key_Escape) {
            root.cancelEditingLife();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.editingLife = false;
            event.accepted = true;
        }
    }

    SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: {
            if (Model.keyForDate(date) === String(root.todayKey))
                return;
            const wasCurrent = root.viewingCurrentMonth;
            root.today = date;
            if (wasCurrent)
                root.goToToday();
        }
    }

    Flickable {
      id: calendarScroll
      anchors.fill: parent
        implicitWidth: calendarColumn.implicitWidth
      contentWidth: calendarColumn.width
      contentHeight: calendarColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height || contentWidth > width

      Column {
        id: calendarColumn
        // Never narrower than the grid. The popup width is capped to what
        // the screen allows, and a fixed seven-column grid would otherwise
        // lose its last days off the edge instead of scrolling.
        width: Math.max(calendarScroll.width, gridColumn.width)
        spacing: Style.space(8)

        // ---- Hero: today, centered. Once the view has stepped back
        //      it is also the way home — clicking the date you are
        //      looking for beats hunting for a reset button.
        Item {
          width: parent.width
          height: heroRow.height

          Row {
            id: heroRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(22)

            Text {
              // Baseline-aligned, not center-aligned: "July 26" carries a
              // descender, so centering the two boxes leaves the icon
              // sitting visibly low against the digits.
              anchors.baseline: heroDate.baseline
              text: "󰃭"
              color: heroMouse.containsMouse
                ? Style.hoverStateColor(root.contentForeground, Color.accent)
                : root.contentForeground
              font.family: root.contentFontFamily
              // Decorative, and deliberately outside the Style.font.*
              // scale. Sized so the glyph reads at the cap height of the
              // date beside it rather than towering over it.
              font.pixelSize: 48
            }

            Text {
              id: heroDate
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: Qt.formatDate(root.today, "MMMM d")
              color: heroMouse.containsMouse
                ? Style.hoverStateColor(root.contentForeground, Color.accent)
                : root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: 52
              font.bold: true
            }
          }

          MouseArea {
            id: heroMouse
            x: heroRow.x
            y: heroRow.y
            width: heroRow.width
            height: heroRow.height
            enabled: !root.viewingCurrentMonth
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goToToday()

            PanelToolTip {
              visible: heroMouse.containsMouse
              text: "Back to today"
              fontFamily: root.contentFontFamily
            }
          }
        }

        // ---- Year progress, doubling as the rule under the hero:
        //      a plain hairline said nothing, and whole days done
        //      over days in the year says the same thing louder.
        Item {
          width: parent.width
          height: yearBlock.y + yearBlock.height

          Item {
            id: yearBlock
            y: Style.space(6)
            anchors.horizontalCenter: parent.horizontalCenter
            width: gridColumn.width
            height: Math.max(yearLabel.implicitHeight, Style.space(10))

            TapHandler {
              enabled: !root.editingLife
              onDoubleTapped: root.startEditingLife()
            }

            Row {
              visible: root.editingLife
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(10)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "BORN"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              TextField {
                id: bornField
                width: Style.space(70)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "year"
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                inputMethodHints: Qt.ImhDigitsOnly

                Keys.onPressed: function(event) { root.handleLifeKey(event, expectancyField) }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
                leftPadding: Style.space(6)
                text: "LIVE TO"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              TextField {
                id: expectancyField
                width: Style.space(60)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "90"
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                inputMethodHints: Qt.ImhDigitsOnly

                Keys.onPressed: function(event) { root.handleLifeKey(event, bornField) }
              }
            }

            Text {
              id: yearLabel
              textFormat: Text.PlainText
              visible: !root.editingLife
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.today.getFullYear()
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.letterSpacing: 1
            }

            Text {
              id: yearPercent
              textFormat: Text.PlainText
              visible: !root.editingLife
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.yearDonePercent + "%"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Rectangle {
              id: yearTrack
              visible: !root.editingLife
              anchors.left: yearLabel.right
              anchors.right: yearPercent.left
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(6)
              radius: Style.cornerRadius > 0 ? height / 2 : 0
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

              Rectangle {
                width: Math.round(parent.width * root.yearDone)
                height: parent.height
                radius: parent.radius
                color: Style.selectedStateColor(root.contentForeground, Color.accent)

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              }
            }
          }
        }

        // ---- Memento mori. Only here once someone has gone looking and
        //      given an age; the same rail as the year above it, measured
        //      against a nominal lifetime.
        Item {
          visible: root.birthYear > 0
          width: parent.width
          height: visible ? lifeBlock.height : 0

          Item {
            id: lifeBlock
            anchors.horizontalCenter: parent.horizontalCenter
            width: gridColumn.width
            height: Math.max(lifeLabel.implicitHeight, Style.space(10))

            Text {
              id: lifeLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "LIFE"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.letterSpacing: 1
            }

            Text {
              id: lifePercent
              textFormat: Text.PlainText
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.lifeDonePercent + "%"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Rectangle {
              anchors.left: lifeLabel.right
              anchors.right: lifePercent.left
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(6)
              radius: Style.cornerRadius > 0 ? height / 2 : 0
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

              Rectangle {
                width: Math.round(parent.width * root.lifeDone)
                height: parent.height
                radius: parent.radius
                color: Style.selectedStateColor(root.contentForeground, Color.accent)

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              }
            }

            TapHandler {
              onDoubleTapped: root.clearLife()
            }

            MouseArea {
              id: lifeMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton

              PanelToolTip {
                visible: lifeMouse.containsMouse
                text: "Memento Mori"
                fontFamily: root.contentFontFamily
              }
            }
          }
        }

        // ---- Month grid: week numbers down a gutter on the left, then
        //      the seven day columns. Always six rows, so the popup is
        //      exactly as tall in February as it is in August.
        Item {
          width: parent.width
          height: gridColumn.y + gridColumn.height

          WheelHandler {
            onWheel: function(event) {
              // Horizontal wheels and touchpad side-scrolls report y === 0;
              // without this they would every one read as "next month".
              if (event.angleDelta.y === 0) return
              root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
            }
          }

          Column {
            id: gridColumn
            // The meter above is a solid rule; the grid needs room to
            // read as its own block rather than hanging off it.
            y: Style.space(18)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(3)

            Row {
              id: headerRow
              spacing: root.cellSpacing

              // The week-number heading doubles as the week-start toggle.
              // It is the one control in the panel whose meaning is not
              // self-evident, so it carries a tooltip naming the day the
              // click will switch to.
              Rectangle {
                width: root.weekColumnWidth
                height: Style.space(16)
                radius: Style.cornerRadius
                color: weekStartMouse.containsMouse
                  ? Style.hoverFillFor(root.contentForeground, Color.accent)
                  : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "W"
                  color: weekStartMouse.containsMouse
                    ? Style.hoverStateColor(root.contentForeground, Color.accent)
                    : Qt.darker(root.contentForeground, 1.9)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                  font.bold: true
                }

                MouseArea {
                  id: weekStartMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleWeekStart()
                }

                PanelToolTip {
                  visible: weekStartMouse.containsMouse
                  text: "Start weeks on " + root.nextWeekStartLabel
                  fontFamily: root.contentFontFamily
                }
              }

              Item {
                width: root.gutterWidth
                height: Style.space(16)
              }

              Repeater {
                model: root.weekdays

                Text {
                  textFormat: Text.PlainText
                  required property var modelData
                  width: root.cellWidth
                  height: Style.space(16)
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: root.weekdayLabel(modelData)
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                  font.bold: true
                }
              }
            }

            Repeater {
              model: root.weeks

              Row {
                required property var modelData
                spacing: root.cellSpacing

                Text {
                  textFormat: Text.PlainText
                  width: root.weekColumnWidth
                  height: root.cellHeight
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: modelData.week
                  color: Qt.darker(root.contentForeground, 1.9)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }

                Item {
                  width: root.gutterWidth
                  height: root.cellHeight
                }

                Repeater {
                  model: modelData.days

                  Rectangle {
                    required property var modelData

                    width: root.cellWidth
                    height: root.cellHeight
                    radius: Style.cornerRadius
                    // Today is outlined, not filled: a lit-up block shouts
                    // over a grid this quiet.
                    color: "transparent"
                    border.width: modelData.today ? Style.spacing.hairline : 0
                    border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                    Text {
                      textFormat: Text.PlainText
                      anchors.centerIn: parent
                      text: modelData.day
                      color: modelData.inMonth
                        ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground)
                        : Qt.darker(root.contentForeground, 2.2)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: modelData.today
                    }
                  }
                }
              }
            }
          }

          // Hairline down the week-number gutter, drawn only beside the
          // day rows so it does not cut through the header band.
          Rectangle {
            x: gridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
            y: gridColumn.y + headerRow.height + gridColumn.spacing
            width: Style.spacing.hairline
            height: gridColumn.height - headerRow.height - gridColumn.spacing
            color: root.contentForeground
            opacity: 0.1
          }
        }

        // ---- Month stepping, spanning the grid it drives. The chevrons
        //      sit on the grid's outer bounds, the same edges the year
        //      rail above uses, so the row reads as the panel's other
        //      full-width rail instead of a cluster floating in space.
        //      The label is centered and fixed-width, so it holds still
        //      from "MAY" to "SEPTEMBER".
        Item {
          width: parent.width
          height: monthNav.height

          Item {
            id: monthNav
            anchors.horizontalCenter: parent.horizontalCenter
            width: gridColumn.width
            height: monthLabel.implicitHeight + Style.space(10)

            Text {
              id: monthLabel
              textFormat: Text.PlainText
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              // Fixed width so the chevrons hold still between a
              // "MAY 2026" and a "SEPTEMBER 2026".
              width: Style.space(130)
              horizontalAlignment: Text.AlignHCenter
              text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.letterSpacing: 1
            }

            PanelActionButton {
              // Pulled out by the button's own padding so the glyph, not
              // its hit box, lines up with the "2026" on the year rail.
              anchors.left: parent.left
              anchors.leftMargin: -Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰅁"
              tooltipText: "Previous month"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.moveMonth(-1)
            }

            PanelActionButton {
              anchors.right: parent.right
              anchors.rightMargin: -Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰅂"
              tooltipText: "Next month"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.moveMonth(1)
            }
          }
        }
      }
    }
}
