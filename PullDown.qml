import QtQuick
import Quickshell
import Quickshell.Hyprland

// Slides down over the app controls: workspaces and media, whichever app has focus.
// Dragged open from the header in shell.qml, and shut from the grip along its bottom.
Rectangle {
  id: root

  property bool open: false
  property bool dragging: false
  property real dragY: 0

  // Follows a finger while dragging, then settles open or shut.
  function follow(stageY) {
    dragging = true
    dragY = Math.max(0, Math.min(height, stageY))
  }

  function release() {
    if (!dragging) return
    open = dragY > height / 2
    dragging = false
  }

  y: dragging ? dragY - height : (open ? 0 : -height)
  color: Theme.background
  visible: y > -height

  Behavior on y {
    enabled: !root.dragging
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Item {
    id: workspacesArea
    x: 28
    y: 28
    width: 1250
    height: parent.height - grip.height - 44

    Text {
      id: workspacesTitle
      text: "Workspaces"
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: 38
      font.bold: true
    }

    Row {
      id: workspaces
      anchors.top: workspacesTitle.bottom
      anchors.topMargin: 20
      anchors.bottom: parent.bottom
      width: parent.width
      spacing: Theme.gap

      Repeater {
        model: [1, 2, 3, 4, 5]

        Rectangle {
          required property int modelData
          readonly property bool current: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData

          width: (workspaces.width - 4 * workspaces.spacing) / 5
          height: workspaces.height
          radius: Theme.radius
          color: current ? Theme.accent : Theme.surface

          Text {
            anchors.centerIn: parent
            text: parent.modelData
            color: parent.current ? Theme.background : Theme.text
            font.family: Theme.font
            font.pixelSize: 96
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            onClicked: Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = "${parent.modelData}" })`])
          }
        }
      }
    }
  }

  MediaCard {
    x: workspacesArea.x + workspacesArea.width + 28
    y: 28
    width: parent.width - x - 28
    height: parent.height - grip.height - 44
  }

  Rectangle {
    id: grip
    anchors.bottom: parent.bottom
    width: parent.width
    height: 84
    color: Theme.surface

    Rectangle {
      anchors.centerIn: parent
      width: 160
      height: 10
      radius: 5
      color: Theme.textDim
    }

    MouseArea {
      anchors.fill: parent
      preventStealing: true
      onPositionChanged: mouse => root.follow(mapToItem(root.parent, mouse.x, mouse.y).y)
      onReleased: root.release()
      onClicked: root.open = false
    }
  }
}
