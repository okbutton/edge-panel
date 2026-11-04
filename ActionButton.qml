import QtQuick
import Quickshell
import "Plugins.js" as Plugins

Rectangle {
  id: root

  required property var action
  property bool armed: false

  readonly property color statusColor: action.status === "working" ? Theme.accent
    : action.status === "blocked" ? Theme.danger
    : action.status === "done" ? Theme.text
    : Theme.textDim

  function trigger() {
    if (action.confirm && !armed) {
      armed = true
      disarm.restart()
      return
    }
    armed = false
    const command = Plugins.command(action)
    if (command) Quickshell.execDetached(command)
  }

  radius: Theme.radius
  color: armed ? Theme.danger : touch.pressed ? Theme.surfacePressed : Theme.surface
  border.color: action.active || touch.pressed ? (action.danger ? Theme.danger : Theme.accent) : Theme.line
  border.width: action.active ? 4 : 2

  // A dangerous button needs a second tap, so a stray touch can't close anything.
  Timer {
    id: disarm
    interval: 3000
    onTriggered: root.armed = false
  }

  Column {
    anchors.centerIn: parent
    width: parent.width - 24
    spacing: 14

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.action.icon || ""
      color: root.armed ? Theme.background
        : root.action.status ? root.statusColor
        : root.action.danger ? Theme.danger
        : Theme.text
      font.family: Theme.font
      font.pixelSize: Theme.iconSize
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: root.armed ? "Tap again" : root.action.label
      color: root.armed ? Theme.background : root.action.detail ? Theme.text : Theme.textDim
      font.family: Theme.font
      font.pixelSize: Theme.labelSize
    }

    Text {
      width: parent.width
      visible: !!root.action.detail
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: root.action.detail || ""
      color: root.statusColor
      font.family: Theme.font
      font.pixelSize: Theme.detailSize
    }
  }

  MouseArea {
    id: touch
    anchors.fill: parent
    onClicked: root.trigger()
  }
}
