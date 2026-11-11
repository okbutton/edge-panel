import QtQuick

// Pixel-art touches for a bordered box, from the skin: a hard drop shadow and stepped
// corners. Put one inside any Rectangle with a border; it does nothing unless the skin
// asks for them.
Item {
  id: root

  readonly property Item box: parent
  readonly property int step: Math.max(1, Theme.borderWidth)
  // Inside a box that clips (a list row), the shadow would be cut off, so it's left out.
  readonly property bool showShadow: Theme.shadow > 0 && !box.clip

  anchors.fill: parent

  // Behind the box, down and to the right. It belongs to the box itself, as only a direct
  // child with a negative z draws beneath its parent.
  Rectangle {
    parent: root.box
    visible: root.showShadow
    z: -1
    x: Theme.shadow
    y: Theme.shadow
    width: root.width
    height: root.height
    color: Theme.shadowColor
  }

  // Each corner: the outermost square goes, filled with the background, and a border
  // square one step in turns the corner into a stair.
  Repeater {
    model: Theme.pixelCorners ? [[0, 0], [1, 0], [0, 1], [1, 1]] : []

    Item {
      required property var modelData

      readonly property bool atRight: modelData[0] === 1
      readonly property bool atBottom: modelData[1] === 1

      Rectangle {
        x: parent.atRight ? root.width - root.step : 0
        y: parent.atBottom ? root.height - root.step : 0
        width: root.step
        height: root.step
        color: Theme.background
      }

      Rectangle {
        x: parent.atRight ? root.width - 2 * root.step : root.step
        y: parent.atBottom ? root.height - 2 * root.step : root.step
        width: root.step
        height: root.step
        color: root.box.border ? root.box.border.color : Theme.line
      }
    }
  }
}
