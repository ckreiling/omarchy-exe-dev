import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "Model.js" as Model

Column {
  id: root
  property var vm: null
  property int selectedAction: 1
  property bool cursorActive: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string resources: Model.resourceSummary(vm)
  readonly property var facts: Model.detailFacts(vm)

  property bool managementBusy: false
  property bool managementError: false
  property string managementMessage: ""
  property string pendingAction: ""
  property string pendingVmName: ""
  readonly property bool confirming: pendingAction !== "" && !!vm && vm.name === pendingVmName
  readonly property string confirmationLabel: pendingAction === "copy" ? "Create copy" : pendingAction === "restart" ? "Restart VM" : pendingAction === "resume" ? "Resume VM" : "Pause VM"

  signal launchRequested(int action)
  signal actionHovered(int action)
  signal managementRequested(string vmName, string action)
  signal returnFocusRequested()

  function requestManagement(action) {
    if (!vm || !vm.adminAllowed || managementBusy || ["copy", "restart", "pause", "resume"].indexOf(action) < 0) return
    pendingVmName = vm.name
    pendingAction = action
  }

  function cancelPending() {
    pendingAction = ""
    pendingVmName = ""
  }

  function confirmPending() {
    if (!confirming || !vm.adminAllowed || managementBusy) return
    var name = pendingVmName
    var action = pendingAction
    cancelPending()
    managementRequested(name, action)
  }

  onConfirmingChanged: {
    if (confirming) Qt.callLater(function() { if (root.confirming) confirmation.forceActiveFocus() })
    else returnFocusRequested()
  }
  onVmChanged: if (!vm || vm.name !== pendingVmName) cancelPending()
  onVisibleChanged: if (!visible) cancelPending()
  spacing: Style.space(10)

  // Compact label/value rows, with full values available on hover.
  component DetailField: Item {
    id: field
    required property string label
    required property string value
    property string tooltip: ""
    implicitHeight: Math.max(fieldLabel.implicitHeight, fieldValue.implicitHeight)
    Text {
      id: fieldLabel
      width: Style.space(62)
      text: field.label
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      id: fieldValue
      anchors.left: fieldLabel.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      text: field.value
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
    HoverHandler { id: fieldHover }
    Ui.PanelToolTip {
      visible: fieldHover.hovered && (field.tooltip !== "" || fieldValue.truncated)
      text: field.tooltip || field.value
      fontFamily: root.fontFamily
    }
  }

  // The VM identity is in the panel title. Keep connection information
  // together here, rather than scattering it through the machine facts.
  Column {
    width: parent.width
    spacing: Style.space(6)
    Item {
      width: parent.width
      implicitHeight: Math.max(host.implicitHeight, status.implicitHeight)
      Text {
        id: host
        width: Math.max(0, parent.width - status.width - Style.space(12))
        text: root.vm ? root.vm.name + ".exe.xyz" : ""
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        HoverHandler { id: hostHover }
        Ui.PanelToolTip {
          visible: hostHover.hovered && host.truncated
          text: host.text
          fontFamily: root.fontFamily
        }
      }
      Text {
        id: status
        anchors.right: parent.right
        width: Math.min(implicitWidth, parent.width * 0.3)
        text: root.vm ? "● " + root.vm.status : ""
        textFormat: Text.PlainText
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
    Text {
      width: parent.width
      text: Model.networkSummary(root.vm)
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WrapAnywhere
    }
  }

  Text {
    visible: text !== ""
    width: parent.width
    text: root.vm ? root.vm.comment : ""
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WrapAnywhere
  }

  Flow {
    visible: !!root.vm && root.vm.tags.length > 0
    width: parent.width
    spacing: Style.space(5)
    Repeater {
      model: root.vm ? root.vm.tags : []
      Rectangle {
        required property string modelData
        width: Math.min(tagText.implicitWidth + Style.space(12), parent.width)
        height: tagText.implicitHeight + Style.space(6)
        radius: Style.space(4)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.055)
        Text {
          id: tagText
          anchors.centerIn: parent
          width: Math.min(implicitWidth, parent.width - Style.space(12))
          text: "#" + parent.modelData
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  Ui.PanelSeparator { width: parent.width; foreground: root.foreground }

  Column {
    width: parent.width
    spacing: Style.space(9)
    DetailField {
      visible: root.resources !== ""
      width: parent.width
      label: "Size"
      value: root.resources
    }
    Grid {
      id: factsGrid
      width: parent.width
      columns: root.width >= Style.space(420) ? 2 : 1
      columnSpacing: Style.space(16)
      rowSpacing: Style.space(9)
      Repeater {
        model: root.facts
        DetailField {
          required property var modelData
          width: (factsGrid.width - (factsGrid.columns - 1) * factsGrid.columnSpacing) / factsGrid.columns
          label: modelData.label
          value: modelData.value
          tooltip: modelData.tooltip || ""
        }
      }
    }
    DetailField {
      visible: !!root.vm && root.vm.image !== ""
      width: parent.width
      label: "Image"
      value: root.vm ? root.vm.image : ""
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(8)
    Ui.Button {
      width: (parent.width - parent.spacing) / 2
      height: Style.space(36)
      text: "SSH  ·  S"
      iconText: ""
      foreground: root.foreground
      fontFamily: root.fontFamily
      bordered: true
      enabled: !!root.vm && root.vm.shellAllowed && !root.confirming
      opacity: enabled ? 1 : 0.4
      hasCursor: root.cursorActive && root.selectedAction === 1
      tooltipText: enabled ? "SSH to " + root.vm.sshDest : "SSH access is unavailable"
      onHovered: function(on) { if (on) root.actionHovered(1) }
      onClicked: root.launchRequested(1)
    }
    Ui.Button {
      width: (parent.width - parent.spacing) / 2
      height: Style.space(36)
      text: "Browser  ·  B"
      iconText: "󰖟"
      foreground: root.foreground
      fontFamily: root.fontFamily
      bordered: true
      enabled: !!root.vm && root.vm.webAllowed && !root.confirming
      opacity: enabled ? 1 : 0.4
      hasCursor: root.cursorActive && root.selectedAction === 0
      tooltipText: enabled ? "Open " + root.vm.url : "Web access is unavailable"
      onHovered: function(on) { if (on) root.actionHovered(0) }
      onClicked: root.launchRequested(0)
    }
  }

  Row {
    visible: !root.confirming
    width: parent.width
    spacing: Style.space(6)
    Repeater {
      model: [
        {label: "Copy", action: "copy", index: 2},
        {label: "Restart", action: "restart", index: 3},
        {label: root.vm && root.vm.status === "paused" ? "Resume" : "Pause", action: root.vm && root.vm.status === "paused" ? "resume" : "pause", index: 4}
      ]
      Ui.Button {
        required property var modelData
        width: (parent.width - Style.space(12)) / 3
        height: Style.space(28)
        text: modelData.label
        fontSize: Style.font.bodySmall
        foreground: root.foreground
        fontFamily: root.fontFamily
        bordered: true
        enabled: !!root.vm && root.vm.adminAllowed && !root.managementBusy
        opacity: enabled ? 1 : 0.4
        hasCursor: root.cursorActive && root.selectedAction === modelData.index
        tooltipText: !root.vm || !root.vm.adminAllowed ? "VM administration access is required" : modelData.label + " this VM (asks for confirmation)"
        onHovered: function(on) { if (on) root.actionHovered(modelData.index) }
        onClicked: root.requestManagement(modelData.action)
      }
    }
  }

  Column {
    id: confirmation
    visible: root.confirming
    width: parent.width
    spacing: Style.space(8)
    Keys.onPressed: function(event) {
      // Opening a prompt must require a new deliberate press, not held Enter.
      if (event.isAutoRepeat) { event.accepted = true; return }
      if (event.key === Qt.Key_Escape) {
        event.accepted = true
        root.cancelPending()
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        event.accepted = true
        root.confirmPending()
      }
    }
    Text {
      width: parent.width
      text: root.pendingAction === "copy" ? "Create a copy of " + root.pendingVmName + "? This uses additional VM capacity."
        : root.pendingAction === "restart" ? "Restart " + root.pendingVmName + "? Connections and running work will be interrupted."
        : root.pendingAction === "resume" ? "Resume " + root.pendingVmName + "?"
        : "Pause " + root.pendingVmName + "? Running work will be suspended until resumed."
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WrapAnywhere
    }
    Row {
      width: parent.width
      spacing: Style.space(8)
      Ui.Button {
        width: (parent.width - parent.spacing) / 2
        text: root.confirmationLabel
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: !!root.vm && root.vm.adminAllowed && !root.managementBusy
        onClicked: root.confirmPending()
      }
      Ui.Button {
        width: (parent.width - parent.spacing) / 2
        text: "Cancel  ·  Esc"
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.cancelPending()
      }
    }
  }

  Text {
    visible: text !== "" && !root.confirming
    width: parent.width
    text: root.managementMessage
    textFormat: Text.PlainText
    color: root.managementError ? Commons.Color.urgent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WrapAnywhere
  }
}
