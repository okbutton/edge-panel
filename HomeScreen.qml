import QtQuick

// The Home Assistant screen, opened from the house in the panel's header. Its pages swipe
// sideways like an app's, and the tabs beside its title jump straight to one.
SideScreen {
  id: root

  required property var home
  property int gridColumns: 6
  property int gridRows: 3

  // Energy comes first, when Home Assistant's energy dashboard is set up.
  readonly property var pages: (home.showEnergy ? [{ name: "Energy", energy: true }] : []).concat(home.pages)

  function show(index) {
    open = true
    pager.positionViewAtIndex(index, ListView.Beginning)
  }

  title: "Home"
  icon: "\u{F02DC}"

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

  tabs: Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 40

    Repeater {
      model: root.pages

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

  ListView {
    id: pager

    anchors.fill: parent
    orientation: ListView.Horizontal
    snapMode: ListView.SnapOneItem
    highlightRangeMode: ListView.StrictlyEnforceRange
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    model: root.pages

    delegate: Loader {
      required property var modelData

      width: pager.width
      height: pager.height
      sourceComponent: modelData.energy ? energyPage : buttonPage

      Component {
        id: energyPage

        EnergyPage { home: root.home }
      }

      Component {
        id: buttonPage

        Grid {
          id: grid

          columns: root.gridColumns
          spacing: Theme.gap

          Repeater {
            model: modelData.actions

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
    }
  }

  Text {
    anchors.centerIn: parent
    width: parent.width - 200
    visible: root.pages.length === 0
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: !root.home.configured ? "Add your Home Assistant URL and a long-lived access token to home.json"
      : root.home.error || "Loading…"
    color: Theme.textDim
    font.family: Theme.font
    font.pixelSize: Theme.labelSize
  }
}
