import QtQml
import "Model.js" as Model

// Pure navigation state: no desktop access or command execution. Keeping VM
// identity separate from row position prevents refreshes from retargeting actions.
QtObject {
  id: root
  property var vms: []
  property string query: ""
  property string selectedName: ""
  property string detailName: ""
  property int detailAction: 1 // 0 = browser, 1 = SSH
  readonly property var filteredVms: Model.filterVms(vms, query)
  readonly property var filteredRows: Model.listRows(filteredVms, query)
  readonly property int selectedIndex: Math.max(0, indexOf(filteredVms, selectedName))
  readonly property var selectedVm: filteredVms[selectedIndex] || null
  readonly property var detailVm: vms[indexOf(vms, detailName)] || null
  readonly property bool showingDetails: detailVm !== null
  readonly property var currentVm: showingDetails ? detailVm : selectedVm

  signal launchRequested(var vm, int action)
  signal managementRequested(string action)

  function indexOf(machines, name) {
    for (var i = 0; i < machines.length; i++) {
      if (machines[i].name === name) return i
    }
    return -1
  }

  function selectIndex(index) {
    if (filteredVms[index]) selectedName = filteredVms[index].name
  }

  function move(dx, dy) {
    if (showingDetails) {
      var actions = [1, 0, 2, 3, 4] // SSH, browser, copy, restart, pause/resume
      if (dx !== 0) detailAction = actions[Math.max(0, Math.min(actions.length - 1, actions.indexOf(detailAction) + (dx > 0 ? 1 : -1)))]
      if (dy !== 0) detailAction = dy > 0 ? 2 : 1
      return
    }
    if (dy !== 0) selectIndex(Math.max(0, Math.min(filteredVms.length - 1, selectedIndex + dy)))
  }

  function showDetails(vm) {
    if (!vm || indexOf(vms, vm.name) < 0) return
    selectedName = vm.name
    detailAction = vm.shellAllowed ? 1 : 0
    detailName = vm.name
  }

  function back() { detailName = "" }

  function activateSelection() {
    if (!showingDetails) showDetails(selectedVm)
    else if (detailAction < 2) launchRequested(detailVm, detailAction)
    else managementRequested(detailAction === 2 ? "copy" : detailAction === 3 ? "restart" : detailVm.status === "paused" ? "resume" : "pause")
  }

  function shortcut(action) {
    if (currentVm) launchRequested(currentVm, action)
  }

  function click(vm, action) {
    if (!vm) return
    selectedName = vm.name
    if (action === "details") showDetails(vm)
    else launchRequested(vm, action === "browser" ? 0 : 1)
  }

  function reset() {
    // The host owns the query binding and clears the input on open.
    detailName = ""
    selectedName = ""
    detailAction = 1
  }

  onQueryChanged: {
    selectedName = ""
    detailName = ""
  }
  onVmsChanged: {
    if (detailName !== "" && indexOf(vms, detailName) < 0) detailName = ""
    if (selectedName !== "" && indexOf(vms, selectedName) < 0) selectedName = ""
  }
}
