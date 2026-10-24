import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root
  property var vms: []
  property string lastError: ""
  property string updatedAt: ""
  property bool active: false
  property int refreshIntervalSec: 60
  property bool refreshPending: false
  readonly property bool busy: listProcess.running
  readonly property var rows: Model.groupedRows(vms)
  readonly property bool managementBusy: managementProcess.running
  property string managementVmName: ""
  property string managementAction: ""
  property string managementMessage: ""
  property bool managementError: false

  function refresh() {
    if (listProcess.running) { refreshPending = true; return }
    refreshPending = false
    listProcess.running = true
  }

  function manage(vmName, action) {
    if (managementProcess.running) return
    // Look up the latest record: never act on an old detail-view snapshot.
    var vm = null
    for (var i = 0; i < vms.length; i++) {
      if (vms[i].name === vmName) { vm = vms[i]; break }
    }
    managementVmName = vmName
    managementAction = action
    managementError = false
    try {
      managementProcess.command = Model.managementCommand(vm, action)
      managementMessage = action === "copy" ? "Creating a copy…" : action === "pause" ? "Pausing…" : action === "resume" ? "Resuming…" : "Restarting…"
      managementProcess.running = true
    } catch (error) {
      managementMessage = error.message
      managementError = true
    }
  }

  function readList(exitCode) {
    if (exitCode !== 0) {
      lastError = exitCode === 124 || exitCode === 137
        ? "exe.dev timed out. Check your connection and retry."
        : (errors.text.trim() || output.text.trim() || "Could not list VMs (exit " + exitCode + ").")
      return
    }
    try {
      var next = Model.parseVms(output.text)
      vms = next
      updatedAt = Qt.formatTime(new Date(), "HH:mm:ss")
      lastError = ""
    } catch (error) {
      lastError = "Could not read exe.dev response: " + error.message
    }
  }

  Component.onCompleted: refresh()

  Timer {
    running: root.active
    interval: Math.max(15, root.refreshIntervalSec) * 1000
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: listProcess
    command: ["timeout", "--kill-after=2s", "20s", "ssh",
              "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
              "-o", "ConnectTimeout=8", "-o", "ConnectionAttempts=1",
              "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2",
              "exe.dev", "ls", "--json"]
    stdout: StdioCollector { id: output; waitForEnd: true }
    stderr: StdioCollector { id: errors; waitForEnd: true }
    onExited: function(exitCode) {
      root.readList(exitCode)
      if (root.refreshPending) Qt.callLater(root.refresh)
    }
  }

  Process {
    id: managementProcess
    stdout: StdioCollector { id: managementOutput; waitForEnd: true }
    stderr: StdioCollector { id: managementErrors; waitForEnd: true }
    onExited: function(exitCode) {
      root.managementError = exitCode !== 0
      if (exitCode === 124 || exitCode === 137) {
        root.managementMessage = "Request timed out; its outcome may be unknown. Refresh before retrying."
      } else if (exitCode !== 0) {
        root.managementMessage = (managementErrors.text.trim() || managementOutput.text.trim() || "exe.dev command failed (exit " + exitCode + ").").slice(0, 500)
      } else {
        root.managementMessage = root.managementAction === "copy" ? "Copy created. Refreshing machines…"
          : root.managementAction === "pause" ? "VM paused."
          : root.managementAction === "resume" ? "VM resumed." : "Restart requested."
        // Some API errors may be returned as a JSON object. Never hide those.
        try {
          var response = JSON.parse(managementOutput.text)
          if (response && typeof response.error === "string" && response.error !== "") {
            root.managementError = true
            root.managementMessage = response.error.slice(0, 500)
          } else if (root.managementAction === "copy" && response && typeof response.vm_name === "string") {
            var copied = Model.normalizeVm({vm_name: response.vm_name})
            root.managementMessage = "Created " + copied.name + "."
          }
        } catch (error) {
          // Exit status is authoritative when no parseable response is returned.
          // Do not invite a duplicate copy by reporting a successful command as failed.
        }
      }
      // Queue a fresh query even if an earlier list request is still running.
      Qt.callLater(root.refresh)
    }
  }
}
