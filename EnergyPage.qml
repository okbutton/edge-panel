import QtQuick
import "Home.js" as Home

// Today's energy, like Home Assistant's energy dashboard: power in use now, each
// source's use and cost so far today, and a chart of use by the hour.
Item {
  id: root

  required property var home

  readonly property var sources: home.energy
  readonly property var grid: home.energySources.find(source => source.rate) || null
  readonly property var rateState: grid ? home.states[grid.rate] : null
  readonly property real watts: rateState
    ? parseFloat(rateState.state) * (rateState.attributes.unit_of_measurement === "kW" ? 1000 : 1) : NaN
  readonly property string currency: {
    for (const source of home.energySources) {
      const state = source.cost ? home.states[source.cost] : null
      if (state && state.attributes.unit_of_measurement) return state.attributes.unit_of_measurement
    }
    return ""
  }
  readonly property var totalCost: {
    let total = null
    for (const source of sources) if (source.todayCost !== null) total = (total || 0) + source.todayCost
    return total
  }
  readonly property real hourMax: {
    let most = 0.1
    for (let hour = 0; hour < 24; hour++) {
      let sum = 0
      for (const source of sources) sum += source.hourly[hour]
      most = Math.max(most, sum)
    }
    return most
  }

  component Card: Rectangle {
    id: card

    property string title
    property string value
    property string detail
    property color dot: "transparent"

    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.line
    border.width: Theme.borderWidth
    Pixels {}

    Column {
      anchors.left: parent.left
      anchors.leftMargin: 32
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      Row {
        spacing: 14

        Rectangle {
          visible: card.dot.a > 0
          anchors.verticalCenter: parent.verticalCenter
          width: 18
          height: 18
          radius: 9
          color: card.dot
        }

        Text {
          text: card.title
          color: Theme.textDim
          font.family: Theme.font
          font.pixelSize: 30
        }
      }

      Text {
        text: card.value
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 64
        font.bold: true
      }

      Text {
        visible: text !== ""
        text: card.detail
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: Theme.detailSize
      }
    }
  }

  Grid {
    id: cards
    visible: root.sources.length > 0
    width: 1100
    height: parent.height
    columns: 2
    spacing: Theme.gap

    readonly property real cardWidth: (width - spacing) / 2
    readonly property real cardHeight: (height - spacing) / 2

    Card {
      width: cards.cardWidth
      height: cards.cardHeight
      title: "Using now"
      value: Home.power(root.watts)
    }

    Card {
      width: cards.cardWidth
      height: cards.cardHeight
      title: "Cost today"
      value: root.totalCost === null ? "–" : Home.money(root.totalCost, root.currency)
    }

    Repeater {
      model: root.sources.slice(0, 2)

      Card {
        required property var modelData

        width: cards.cardWidth
        height: cards.cardHeight
        dot: modelData.colour
        title: `${modelData.name} today`
        value: modelData.today === null ? "–" : `${modelData.today.toFixed(1)} kWh`
        detail: Home.money(modelData.todayCost, root.currency)
      }
    }
  }

  // Use by the hour, stacked by source.
  Rectangle {
    id: chart
    visible: root.sources.length > 0
    x: cards.width + Theme.gap
    width: parent.width - x
    height: parent.height
    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.line
    border.width: Theme.borderWidth
    Pixels {}

    Text {
      id: chartTitle
      x: 32
      y: 22
      text: "Today, kWh per hour"
      color: Theme.textDim
      font.family: Theme.font
      font.pixelSize: 30
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: 32
      y: 22
      text: `${root.hourMax.toFixed(1)} kWh`
      color: Theme.textDim
      font.family: Theme.font
      font.pixelSize: 26
    }

    Item {
      id: plot
      x: 32
      y: chartTitle.y + chartTitle.height + 24
      width: parent.width - 64
      height: parent.height - y - 62

      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        color: Theme.line
      }

      Row {
        anchors.fill: parent
        spacing: 8

        Repeater {
          model: 24

          Item {
            id: hour
            required property int index

            width: (plot.width - 23 * 8) / 24
            height: plot.height

            Column {
              anchors.bottom: parent.bottom
              width: parent.width

              Repeater {
                // Drawn top to bottom, so the first source sits on the axis.
                model: root.sources.slice().reverse()

                Rectangle {
                  required property var modelData

                  width: hour.width
                  height: plot.height * modelData.hourly[hour.index] / root.hourMax
                  color: modelData.colour
                }
              }
            }

            Text {
              visible: hour.index % 3 === 0
              anchors.top: parent.bottom
              anchors.topMargin: 10
              anchors.horizontalCenter: parent.horizontalCenter
              text: String(hour.index).padStart(2, "0")
              color: Theme.textDim
              font.family: Theme.font
              font.pixelSize: 24
            }
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.sources.length === 0
    text: "Loading energy…"
    color: Theme.textDim
    font.family: Theme.font
    font.pixelSize: Theme.labelSize
  }
}
