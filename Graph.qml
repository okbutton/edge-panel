import QtQuick

// A line graph of recent values, newest on the right, filled beneath. "second" draws
// another series over it as a plain line, as with network upload against download.
Canvas {
  id: root

  property var values: []
  property var second: []
  property real maximum: 100
  property int length: 60
  property color colour: Theme.accent
  property color secondColour: Theme.text

  onValuesChanged: requestPaint()
  onSecondChanged: requestPaint()
  onMaximumChanged: requestPaint()

  function trace(context, series) {
    const step = width / (length - 1)
    const start = length - series.length
    context.beginPath()
    for (let i = 0; i < series.length; i++) {
      const x = (start + i) * step
      const y = height - 3 - (height - 6) * Math.min(1, series[i] / Math.max(maximum, 1e-9))
      if (i === 0) context.moveTo(x, y)
      else context.lineTo(x, y)
    }
  }

  onPaint: {
    const context = getContext("2d")
    context.reset()
    context.lineWidth = 4
    context.lineJoin = "round"

    if (values.length > 1) {
      trace(context, values)
      context.strokeStyle = colour
      context.stroke()
      context.lineTo(width, height)
      context.lineTo((length - values.length) * width / (length - 1), height)
      context.closePath()
      context.fillStyle = Qt.rgba(colour.r, colour.g, colour.b, 0.18)
      context.fill()
    }

    if (second.length > 1) {
      trace(context, second)
      context.strokeStyle = secondColour
      context.stroke()
    }
  }
}
