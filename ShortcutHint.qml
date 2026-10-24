import QtQuick
import qs.Commons
import qs.Commons as Commons

// A guide, not a button: no pointer handler or keyboard focus.
Row {
  id: root
  required property string shortcut
  required property string label
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  spacing: Style.space(6)

  Rectangle {
    width: keyText.implicitWidth + Style.space(10)
    height: keyText.implicitHeight + Style.space(6)
    radius: Style.space(4)
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)
    border.width: 1
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)

    Text {
      id: keyText
      anchors.centerIn: parent
      text: root.shortcut
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    textFormat: Text.PlainText
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
