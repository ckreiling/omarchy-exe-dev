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
  readonly property bool busy: listProcess.running
  readonly property var rows: Model.groupedRows(vms)

  function refresh() {
    if (listProcess.running) return
    listProcess.running = true
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
    // No passwords or host-key prompts in the desktop shell. A hard deadline
    // also bounds hangs after connecting (ConnectTimeout alone cannot).
    command: ["timeout", "--kill-after=2s", "20s", "ssh",
              "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
              "-o", "ConnectTimeout=8", "-o", "ConnectionAttempts=1",
              "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2",
              "exe.dev", "ls", "--json"]
    stdout: StdioCollector { id: output; waitForEnd: true }
    stderr: StdioCollector { id: errors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = exitCode === 124 || exitCode === 137
          ? "exe.dev timed out. Check your connection and retry."
          : (errors.text.trim() || output.text.trim() || "Could not list VMs (exit " + exitCode + ").")
        return
      }
      try {
        var next = Model.parseVms(output.text)
        root.vms = next
        root.updatedAt = Qt.formatTime(new Date(), "HH:mm:ss")
        root.lastError = ""
      } catch (error) {
        root.lastError = "Could not read exe.dev response: " + error.message
      }
    }
  }
}
