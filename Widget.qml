import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "Model.js" as Model

Ui.Panel {
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
  readonly property string clickAction: String(root.setting("clickAction", "ssh"))
  property bool cursorActive: false
  property real savedListContentY: 0
  property double now: Date.now()

  Timer {
    interval: 15000
    repeat: true
    running: root.opened && navigation.showingDetails
    onTriggered: root.now = Date.now()
  }

  function openRepl() {
    try {
      Quickshell.execDetached(Model.replCommand())
      root.close()
    } catch (error) {
      service.lastError = "Could not open exe.dev: " + error.message
    }
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

  function focusFilter() {
    navigation.back()
    cursorActive = false
    filterField.forceActiveFocus()
    filterField.selectAll()
  }

  function focusList() {
    keys.forceActiveFocus()
    cursorActive = navigation.filteredVms.length > 0
    Qt.callLater(scrollToSelection)
  }

  function backOrClose() {
    if (navigation.showingDetails) {
      navigation.back()
      root.focusList()
    } else root.close()
  }

  function scrollToSelection() {
    if (navigation.showingDetails) return
    for (var i = 0; i < rows.count; i++) {
      var item = rows.itemAt(i)
      if (item && item.modelData.vmIndex === navigation.selectedIndex) {
        var y = item.y
        if (y < list.contentY) list.contentY = y
        else if (y + item.height > list.contentY + list.height)
          list.contentY = y + item.height - list.height
        return
      }
    }
  }

  onOpenedChanged: if (root.opened) {
    navigation.reset()
    filterField.text = ""
    cursorActive = false
    savedListContentY = 0
    list.contentY = 0
    service.refresh()
  }

  VmService {
    id: service
    active: root.opened
    refreshIntervalSec: Number(root.setting("refreshIntervalSec", 60)) || 60
  }

  VmNavigation {
    id: navigation
    vms: service.vms
    query: filterField.text
    onLaunchRequested: function(vm, action) { root.activate(vm, action) }
    onManagementRequested: function(action) { detailView.requestManagement(action) }
    onQueryChanged: list.contentY = 0
    onShowingDetailsChanged: {
      if (showingDetails) {
        root.now = Date.now()
        root.savedListContentY = list.contentY
        list.contentY = 0
      } else Qt.callLater(function() {
        if (!navigation.showingDetails) {
          list.contentY = Math.max(0, Math.min(root.savedListContentY, list.contentHeight - list.height))
          root.scrollToSelection()
        }
      })
    }
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
        filteredCount: navigation.filteredVms.length,
        selectedVm: navigation.selectedVm ? navigation.selectedVm.name : null,
        view: navigation.showingDetails ? "details" : "list",
        detailVm: navigation.detailVm ? navigation.detailVm.name : null,
        clickAction: root.clickAction, managementBusy: service.managementBusy})
    }
  }

  Ui.BarIconButton {
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

  Ui.KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(headerColumn.implicitHeight + bodyContent.implicitHeight + footer.implicitHeight + Style.space(24), Style.space(900))

    Ui.PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: filterField.activeFocus || detailView.confirming
      onCloseRequested: root.backOrClose()
      onMoveRequested: function(dx, dy) {
        root.cursorActive = true
        navigation.move(dx, dy)
        root.scrollToSelection()
      }
      onActivateRequested: {
        root.cursorActive = true
        navigation.activateSelection()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "/") root.focusFilter()
        else if (text.toLowerCase() === "r") service.refresh()
        else if (text.toLowerCase() === "b") navigation.shortcut(0)
        else if (text.toLowerCase() === "s") navigation.shortcut(1)
        else if (text.toLowerCase() === "e" && !navigation.showingDetails) root.openRepl()
      }

      Column {
        width: parent.width
        spacing: Style.space(12)

        Column {
          id: headerColumn
          width: parent.width
          spacing: Style.space(12)

          Item {
            width: parent.width
            implicitHeight: Math.max(header.implicitHeight, headerActions.implicitHeight, backButton.visible ? backButton.implicitHeight : 0)
            Ui.PanelActionButton {
              id: backButton
              visible: navigation.showingDetails
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              iconText: "←"
              tooltipText: "Back to machines (Esc)"
              foreground: root.foreground
              size: Style.space(28)
              onClicked: root.backOrClose()
            }
            Column {
              id: header
              anchors.verticalCenter: parent.verticalCenter
              x: backButton.visible ? backButton.width + Style.space(8) : 0
              width: Math.max(0, parent.width - x - headerActions.width - Style.space(12))
              spacing: Style.space(4)
              Item {
                width: parent.width
                implicitHeight: Math.max(panelTitle.implicitHeight, createdAge.implicitHeight)
                Text {
                  id: panelTitle
                  width: Math.max(0, Math.min(implicitWidth, parent.width - (createdAge.visible ? createdAge.width + Style.space(10) : 0)))
                  text: navigation.detailVm ? navigation.detailVm.emoji + "  " + navigation.detailVm.name : "exe.dev"
                  textFormat: Text.PlainText
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  HoverHandler { id: titleHover }
                  Ui.PanelToolTip {
                    visible: titleHover.hovered && panelTitle.truncated
                    text: panelTitle.text
                    fontFamily: root.fontFamily
                  }
                }
                Text {
                  id: createdAge
                  visible: text !== ""
                  anchors.left: panelTitle.right
                  anchors.leftMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.min(implicitWidth, parent.width * 0.48)
                  text: navigation.detailVm ? Model.createdAgo(navigation.detailVm.createdAt, root.now) : ""
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  HoverHandler { id: createdHover }
                  Ui.PanelToolTip {
                    visible: createdHover.hovered && !!navigation.detailVm
                    text: createdAge.text + "\n" + (navigation.detailVm ? navigation.detailVm.createdAt : "")
                    fontFamily: root.fontFamily
                  }
                }
              }
              Text {
                visible: !navigation.showingDetails
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
              Ui.PanelActionButton {
                iconText: "󰖟"
                tooltipText: "Open exe.dev dashboard"
                bordered: true
                foreground: root.foreground
                onClicked: { Quickshell.execDetached(["omarchy-launch-browser", "https://exe.dev/"]); root.close() }
              }
              Ui.PanelActionButton {
                iconText: "󰑓"
                tooltipText: "Refresh VMs (R)"
                bordered: true
                enabled: !service.busy
                foreground: root.foreground
                onClicked: service.refresh()
              }
            }
          }

          Ui.PanelSeparator { foreground: root.foreground }

          Ui.TextField {
            id: filterField
            visible: !navigation.showingDetails
            width: parent.width
            placeholderText: "Fuzzy find VM name (/)"
            foreground: root.foreground
            font.family: root.fontFamily
            // Consume Enter here: returning to the list must not open details.
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
            visible: service.lastError !== ""
            text: service.lastError.slice(0, 500) + (service.vms.length ? "\nShowing the last successful list." : "\nRun ssh exe.dev in a terminal to check authentication, then refresh.")
            textFormat: Text.PlainText
            color: root.urgent
            wrapMode: Text.Wrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: !navigation.showingDetails && navigation.filteredVms.length === 0
            width: parent.width
            text: service.vms.length > 0 ? "No VMs match this name." : (service.busy ? "Connecting over SSH…" : "No VMs yet. Create one at exe.dev.")
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
          height: Math.max(0, Math.min(bodyContent.implicitHeight,
            keys.height - headerColumn.implicitHeight - footer.implicitHeight - Style.space(24)))
          contentWidth: width
          contentHeight: bodyContent.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: bodyContent
            width: list.width

            Column {
              visible: !navigation.showingDetails
              width: parent.width
              spacing: Style.space(4)
              Repeater {
                id: rows
                model: navigation.filteredRows
                delegate: Item {
                  id: row
                  required property var modelData
                  readonly property var vm: modelData.vm
                  width: bodyContent.width
                  implicitHeight: modelData.kind === "group" ? Style.space(32) : Style.space(68)

                  Ui.PanelSectionHeader {
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

                  Ui.CursorSurface {
                    anchors.fill: parent
                    visible: row.vm !== null
                    bordered: true
                    foreground: root.foreground
                    hasCursor: root.cursorActive && navigation.selectedIndex === row.modelData.vmIndex

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
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(14)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(5)
                      Item {
                        width: parent.width
                        implicitHeight: vmName.implicitHeight
                        Text {
                          id: vmName
                          width: Math.max(0, parent.width - vmStatus.width - Style.space(12))
                          text: row.vm ? row.vm.name : ""
                          textFormat: Text.PlainText
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          font.bold: true
                          elide: Text.ElideRight
                        }
                        Text {
                          id: vmStatus
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          width: Math.min(implicitWidth, parent.width * 0.28)
                          text: row.vm ? row.vm.status : ""
                          textFormat: Text.PlainText
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                        }
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
                    }

                    MouseArea {
                      anchors.fill: parent
                      enabled: row.vm !== null
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onEntered: {
                        if (!filterField.activeFocus) {
                          root.cursorActive = true
                          navigation.selectIndex(row.modelData.vmIndex)
                        }
                      }
                      onClicked: {
                        keys.forceActiveFocus()
                        root.cursorActive = true
                        navigation.click(row.vm, root.clickAction)
                      }
                    }
                  }
                }
              }
            }

            VmDetail {
              id: detailView
              visible: navigation.showingDetails
              width: parent.width
              vm: navigation.detailVm
              foreground: root.foreground
              fontFamily: root.fontFamily
              selectedAction: navigation.detailAction
              cursorActive: root.cursorActive
              managementBusy: service.managementBusy
              managementError: service.managementError
              managementMessage: vm && vm.name === service.managementVmName ? service.managementMessage : ""
              onManagementRequested: function(vmName, action) { service.manage(vmName, action) }
              onReturnFocusRequested: if (root.opened) keys.forceActiveFocus()
              onLaunchRequested: function(action) { root.activate(navigation.detailVm, action) }
              onActionHovered: function(action) {
                root.cursorActive = true
                navigation.detailAction = action
              }
            }
          }
        }

        Column {
          id: footer
          width: parent.width
          spacing: Style.space(10)
          Ui.PanelSeparator { foreground: root.foreground }
          Flow {
            width: parent.width
            spacing: Style.space(14)
            visible: !navigation.showingDetails
            opacity: filterField.activeFocus ? 0.45 : 1
            ShortcutHint { shortcut: "S"; label: "SSH"; foreground: root.foreground; fontFamily: root.fontFamily }
            ShortcutHint { shortcut: "B"; label: "Browser"; foreground: root.foreground; fontFamily: root.fontFamily }
            ShortcutHint { shortcut: "Enter"; label: "Details"; foreground: root.foreground; fontFamily: root.fontFamily }
            ShortcutHint { shortcut: "/"; label: "Filter"; foreground: root.foreground; fontFamily: root.fontFamily }
            ShortcutHint { shortcut: "E"; label: "exe.dev"; foreground: root.foreground; fontFamily: root.fontFamily }
          }
          Text {
            width: parent.width
            text: detailView.confirming ? "Enter confirm · Esc cancel" : filterField.activeFocus ? "Enter return to list · Esc clear filter" : (navigation.showingDetails
              ? "←→ / ↑↓ action · Enter select · Esc back to list"
              : "↑↓ select · Click " + (root.clickAction === "browser" ? "browser" : root.clickAction === "details" ? "details" : "SSH") + " · R refresh · Esc close")
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }
      }
    }
  }
}
