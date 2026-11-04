import QtQuick

// The Home Assistant screen. It slides in from the right over the app controls: drag in
// from the right edge, or tap the house in the header. Drag from its left edge, or tap
// the arrow, to go back. Its pages swipe sideways like an app's.
Rectangle {
  id: root

  required property var home
  property int gridColumns: 6
  property int gridRows: 3

  property bool open: false
  property bool dragging: false
  property real dragX: 0

  // Follows a finger while dragging, then settles open or shut.
  function follow(stageX) {
    dragging = true
    dragX = Math.max(0, Math.min(width, stageX))
  }

  function release() {
    if (!dragging) return
    open = dragX < width / 2
    dragging = false
  }

  x: dragging ? dragX : (open ? 0 : width)
  visible: x < width
  color: Theme.background

  Behavior on x {
    enabled: !root.dragging
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Binding {
    target: root.home
    property: "active"
    value: root.visible
  }

  Binding {
    target: root.home
    property: "perPage"
    value: root.gridColumns * root.gridRows
  }

  Item {
    id: header
    width: parent.width
    height: 92

    Text {
      id: back
      x: 32
      anchors.verticalCenter: parent.verticalCenter
      text: "\u{F0141}"
      color: Theme.textDim
      font.family: Theme.font
      font.pixelSize: 56

      MouseArea {
        anchors.fill: parent
        anchors.margins: -20
        onClicked: root.open = false
      }
    }

    Text {
      id: title
      anchors.left: back.right
      anchors.leftMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      text: "\u{F02DC}  Home"
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: 44
      font.bold: true
    }

    // One tab per page; tap to jump there.
    Row {
      anchors.left: title.right
      anchors.leftMargin: 56
      anchors.right: parent.right
      anchors.rightMargin: 32
      anchors.verticalCenter: parent.verticalCenter
      spacing: 40
      clip: true

      Repeater {
        model: root.home.pages

        Text {
          required property var modelData
          required property int index

          text: modelData.name
          color: index === pager.currentIndex ? Theme.accent : Theme.textDim
          font.family: Theme.font
          font.pixelSize: 34
          font.bold: index === pager.currentIndex

          MouseArea {
            anchors.fill: parent
            anchors.margins: -16
            onClicked: pager.positionViewAtIndex(parent.index, ListView.Beginning)
          }
        }
      }
    }
  }

  ListView {
    id: pager

    x: 28
    y: header.height
    width: parent.width - 56
    height: parent.height - y - 28
    orientation: ListView.Horizontal
    snapMode: ListView.SnapOneItem
    highlightRangeMode: ListView.StrictlyEnforceRange
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    model: root.home.pages

    delegate: Grid {
      id: grid
      required property var modelData

      width: pager.width
      height: pager.height
      columns: root.gridColumns
      spacing: Theme.gap

      Repeater {
        model: grid.modelData.actions

        ActionButton {
          required property var modelData

          action: modelData
          onTriggered: root.home.press(modelData)
          width: (grid.width - (root.gridColumns - 1) * grid.spacing) / root.gridColumns
          height: (grid.height - (root.gridRows - 1) * grid.spacing) / root.gridRows
        }
      }
    }
  }

  Text {
    anchors.centerIn: pager
    width: pager.width - 200
    visible: root.home.pages.length === 0
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: !root.home.configured ? "Add your Home Assistant URL and a long-lived access token to home.json"
      : root.home.error || "Loading…"
    color: Theme.textDim
    font.family: Theme.font
    font.pixelSize: Theme.labelSize
  }

  // Drag from the left edge to go back.
  MouseArea {
    x: 0
    y: header.height
    width: 48
    height: parent.height - y
    preventStealing: true
    onPositionChanged: mouse => root.follow(mapToItem(root.parent, mouse.x, mouse.y).x)
    onReleased: root.release()
  }
}
