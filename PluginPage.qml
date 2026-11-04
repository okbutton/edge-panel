import QtQuick
import Quickshell.Io

// One swipeable page. Its buttons are either fixed ("actions"), or come from a
// command that prints a JSON array of them ("live"), run only while the page is showing.
Item {
  id: root

  required property var page
  required property bool showing

  property var liveActions: []
  readonly property var actions: page.live ? liveActions : (page.actions || [])
  readonly property int rows: actions.length <= 5 ? 1 : 2
  readonly property int columns: Math.max(1, Math.ceil(actions.length / rows))

  Process {
    id: live
    command: root.page.live ? root.page.live.command : []

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.liveActions = JSON.parse(text)
        } catch (error) {
          console.warn(`Bad output from live page ${root.page.name}: ${error.message}`)
        }
      }
    }
  }

  Timer {
    interval: root.page.live ? (root.page.live.interval || 2000) : 2000
    running: !!root.page.live && root.showing
    repeat: true
    triggeredOnStart: true
    onTriggered: live.running = true
  }

  Grid {
    id: grid
    anchors.fill: parent
    columns: root.columns
    spacing: Theme.gap

    Repeater {
      model: root.actions

      ActionButton {
        required property var modelData

        action: modelData
        width: (grid.width - (root.columns - 1) * grid.spacing) / root.columns
        height: (grid.height - (root.rows - 1) * grid.spacing) / root.rows
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.actions.length === 0
    text: root.page.live ? "Nothing to show" : "No controls on this page"
    color: Theme.textDim
    font.family: Theme.font
    font.pixelSize: Theme.labelSize
  }
}
