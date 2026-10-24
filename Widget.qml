import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "cmk.exe-dev"
  ipcTarget: "cmk.exe-dev"
  manageIpc: false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color urgent: Commons.Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property int selectedIndex: 0
  property int selectedAction: 1 // 0 = browser, 1 = SSH
  property bool cursorActive: false
  readonly property var filteredVms: Model.filterVms(service.vms, filterField.text)
  readonly property var filteredRows: Model.listRows(filteredVms, filterField.text)

  onFilteredVmsChanged: {
    selectedIndex = 0
    list.contentY = 0
  }

  function focusFilter() {
    cursorActive = false
    filterField.forceActiveFocus()
    filterField.selectAll()
  }

  function focusList() {
    keys.forceActiveFocus()
    cursorActive = filteredVms.length > 0
    Qt.callLater(scrollToSelection)
  }

  function activate(vm, action) {
    if (!vm || (action === 1 ? !vm.shellAllowed : !vm.webAllowed)) return
    try {
      Quickshell.execDetached(action === 1 ? Model.sshCommand(vm) : Model.browserCommand(vm))
      root.close()
    } catch (error) {
      service.lastError = "Could not launch: " + error.message
    }
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    selectedIndex = Math.max(0, Math.min(filteredVms.length - 1, selectedIndex + dy))
    if (dx !== 0) selectedAction = dx > 0 ? 1 : 0
    scrollToSelection()
  }

  function scrollToSelection() {
    for (var i = 0; i < rows.count; i++) {
      var item = rows.itemAt(i)
      if (item && item.modelData.vmIndex === selectedIndex) {
        var y = item.y
        if (y < list.contentY) list.contentY = y
        else if (y + item.height > list.contentY + list.height)
          list.contentY = y + item.height - list.height
        return
      }
    }
  }

  onOpenedChanged: if (opened) {
    filterField.text = ""
    cursorActive = false
    list.contentY = 0
    service.refresh()
  }

  VmService {
    id: service
    active: root.opened
    refreshIntervalSec: Number(root.setting("refreshIntervalSec", 60)) || 60
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { service.refresh() }
    function status(): string {
      return JSON.stringify({count: service.vms.length, busy: service.busy,
        updatedAt: service.updatedAt, error: service.lastError, opened: root.opened,
        filter: filterField.text, filterFocused: filterField.activeFocus,
        filteredCount: root.filteredVms.length,
        selectedVm: root.filteredVms[root.selectedIndex] ? root.filteredVms[root.selectedIndex].name : null})
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰒋"
    foreground: service.lastError !== "" ? root.urgent : root.barForeground
    tooltipText: "exe.dev · " + service.vms.length + " VMs"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) service.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: fittedContentWidth(Style.space(520))
    contentHeight: fittedContentHeight(top.implicitHeight + vmColumn.implicitHeight + bottom.implicitHeight + Style.space(24), Style.space(900))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: filterField.activeFocus
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activate(root.filteredVms[root.selectedIndex], root.selectedAction)
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "/") root.focusFilter()
        else if (text.toLowerCase() === "r") service.refresh()
        else if (text.toLowerCase() === "b") root.activate(root.filteredVms[root.selectedIndex], 0)
        else if (text.toLowerCase() === "s") root.activate(root.filteredVms[root.selectedIndex], 1)
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Column {
          id: top
          width: parent.width
          spacing: Style.space(12)

        Item {
          width: parent.width
          implicitHeight: header.implicitHeight
          Column {
            id: header
            width: Math.max(0, parent.width - headerActions.width - Style.space(12))
            spacing: Style.space(4)
            Text {
              text: "exe.dev"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: service.busy ? "Refreshing machines…" : service.vms.length + " virtual machines"
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
          Row {
            id: headerActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            PanelActionButton {
              iconText: "󰖟"
              tooltipText: "Open exe.dev dashboard"
              bordered: true
              foreground: root.foreground
              onClicked: { Quickshell.execDetached(["omarchy-launch-browser", "https://exe.dev/"]); root.close() }
            }
            PanelActionButton {
              iconText: "󰑓"
              tooltipText: "Refresh VMs (R)"
              bordered: true
              enabled: !service.busy
              foreground: root.foreground
              onClicked: service.refresh()
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        TextField {
          id: filterField
          width: parent.width
          placeholderText: "Fuzzy find VM name (/)"
          foreground: root.foreground
          font.family: root.fontFamily
          // Consume Enter here: returning to list focus must not also launch a VM.
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.focusList()
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              text = ""
              root.focusList()
              event.accepted = true
            }
          }
        }

        Text {
          width: parent.width
          visible: service.vms.length > 0 && root.filteredVms.length === 0
          text: "No VMs match this name."
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          width: parent.width
          visible: service.lastError !== ""
          text: service.lastError.slice(0, 500) + (service.vms.length ? "\nShowing the last successful list." : "\nRun ssh exe.dev in a terminal to check authentication, then refresh.")
          textFormat: Text.PlainText
          color: root.urgent
          wrapMode: Text.Wrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          visible: service.vms.length === 0 && service.lastError === ""
          width: parent.width
          text: service.busy ? "Connecting over SSH…" : "No VMs yet. Create one at exe.dev."
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        }

        Flickable {
          id: list
          width: parent.width
          // Header/error/footer remain pinned; only the VM list scrolls.
          height: Math.max(0, Math.min(vmColumn.implicitHeight,
            keys.height - top.implicitHeight - bottom.implicitHeight - Style.space(24)))
          contentWidth: width
          contentHeight: vmColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: vmColumn
            width: list.width
            spacing: Style.space(4)
            Repeater {
              id: rows
              model: root.filteredRows
              delegate: Item {
                id: row
                required property var modelData
                readonly property var vm: modelData.vm
                width: vmColumn.width
                implicitHeight: modelData.kind === "group" ? Style.space(32) : Style.space(76)

                PanelSectionHeader {
                  visible: row.modelData.kind === "group"
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(16)
                  text: (row.modelData.label === "Untagged" ? "UNTAGGED" : "#" + row.modelData.label.toUpperCase()) + "  ·  " + row.modelData.count
                  elide: Text.ElideRight
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                CursorSurface {
                  anchors.fill: parent
                  visible: row.vm !== null
                  bordered: true
                  foreground: root.foreground
                  hasCursor: root.cursorActive && root.selectedIndex === row.modelData.vmIndex

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.vm ? row.vm.emoji : ""
                    textFormat: Text.PlainText
                    font.pixelSize: Style.font.title
                    width: Style.space(28)
                    horizontalAlignment: Text.AlignHCenter
                  }

                  Column {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(48)
                    anchors.right: actions.left
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(3)
                    Text {
                      width: parent.width
                      text: row.vm ? row.vm.name : ""
                      textFormat: Text.PlainText
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      visible: text !== ""
                      text: row.vm ? row.vm.comment : ""
                      textFormat: Text.PlainText
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: row.vm ? (row.vm.publicWeb ? "Public web · " : "") + row.vm.status + (row.vm.tags.length ? " · #" + row.vm.tags.join(" #") : "") : ""
                      textFormat: Text.PlainText
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    PanelActionButton {
                      iconText: "󰖟"
                      tooltipText: row.vm ? "Open " + row.vm.url : ""
                      bordered: true
                      enabled: !!row.vm && row.vm.webAllowed
                      foreground: root.foreground
                      hasCursor: root.cursorActive && root.selectedIndex === row.modelData.vmIndex && root.selectedAction === 0
                      onHovered: function(on) {
                        if (on) { root.cursorActive = true; root.selectedIndex = row.modelData.vmIndex; root.selectedAction = 0 }
                      }
                      onClicked: root.activate(row.vm, 0)
                    }
                    PanelActionButton {
                      iconText: ""
                      tooltipText: row.vm ? "SSH to " + row.vm.sshDest : ""
                      bordered: true
                      enabled: !!row.vm && row.vm.shellAllowed
                      foreground: root.foreground
                      hasCursor: root.cursorActive && root.selectedIndex === row.modelData.vmIndex && root.selectedAction === 1
                      onHovered: function(on) {
                        if (on) { root.cursorActive = true; root.selectedIndex = row.modelData.vmIndex; root.selectedAction = 1 }
                      }
                      onClicked: root.activate(row.vm, 1)
                    }
                  }
                }
              }
            }
          }
        }

        Column {
          id: bottom
          width: parent.width
          spacing: Style.space(12)
        PanelSeparator { foreground: root.foreground }
        Text {
          width: parent.width
          text: (filterField.activeFocus ? "Enter return to list · Esc clear filter" : "↑↓ select · ←→ action · Enter open · / filter · R refresh") + (service.updatedAt ? "\nUpdated " + service.updatedAt : "")
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        }
      }
    }
  }
}
