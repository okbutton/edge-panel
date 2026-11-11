import QtQuick

// A screen that slides in from the right over the app controls, opened from an icon in
// the panel's header. Tap the arrow, or drag from its left edge, to go back.
// Its content goes below the header; "tabs" go in the header beside the title.
Rectangle {
  id: root

  property string title
  property string icon
  property bool open: false
  property bool dragging: false
  property real dragX: 0
  readonly property real headerHeight: header.height
  default property alias content: body.data
  property alias tabs: tabArea.data

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
  // See-through: the window's own background is behind, so none of its own.
  color: Theme.seeThrough ? "transparent" : Theme.background

  Behavior on x {
    enabled: !root.dragging
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
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
      id: titleText
      anchors.left: back.right
      anchors.leftMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      text: `${root.icon}  ${root.title}`
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: 44
      font.bold: true
    }

    Item {
      id: tabArea
      anchors.left: titleText.right
      anchors.leftMargin: 56
      anchors.right: parent.right
      anchors.rightMargin: 32
      height: parent.height
      clip: true
    }
  }

  Item {
    id: body
    x: 28
    y: header.height
    width: parent.width - 56
    height: parent.height - y - 28
  }

  // Drag from the left edge to go back.
  MouseArea {
    y: header.height
    width: 48
    height: parent.height - y
    preventStealing: true
    onPositionChanged: mouse => root.follow(mapToItem(root.parent, mouse.x, mouse.y).x)
    onReleased: root.release()
  }
}
