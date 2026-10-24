.pragma library

function normalizeVm(raw) {
  if (!raw || typeof raw !== "object") throw new Error("Invalid VM record");
  var name = String(raw.vm_name || "");
  if (!/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(name) || name.length > 63)
    throw new Error("Invalid VM name");
  var dest = raw.ssh_dest === undefined ? name + ".exe.xyz" : String(raw.ssh_dest);
  // Accept documented direct and username-routed destinations, never options,
  // shell syntax, ports, or hosts outside exe.dev's VM domain.
  if (!/^(?:[A-Za-z0-9_+.-]+@)?[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.exe\.xyz$/.test(dest))
    throw new Error("Invalid SSH destination for " + name);
  var tags = Array.isArray(raw.tags) ? raw.tags.filter(function(t) {
    return typeof t === "string" && t.trim() !== "";
  }) : [];
  return {
    name: name,
    emoji: String(raw.emoji || "🖥️"),
    comment: String(raw.comment || ""),
    tags: tags,
    group: tags.length ? tags[0] : "Untagged",
    sshDest: dest,
    // The requested canonical VM URL, not arbitrary server-provided schemes.
    url: "https://" + name + ".exe.xyz/",
    status: String(raw.status || "unknown"),
    cpus: metadataNumber(raw.allocated_cpus),
    memoryBytes: metadataNumber(raw.memory_capacity_bytes),
    diskBytes: metadataNumber(raw.disk_capacity_bytes),
    region: typeof raw.region === "string" ? raw.region : "",
    regionDisplay: typeof raw.region_display === "string" ? raw.region_display : "",
    image: typeof raw.image === "string" ? raw.image : "",
    createdAt: typeof raw.created_at === "string" ? raw.created_at : "",
    proxyPort: Number.isInteger(raw.proxy_port) && raw.proxy_port > 0 && raw.proxy_port <= 65535 ? raw.proxy_port : 0,
    egressPolicy: typeof raw.egress_policy === "string" ? raw.egress_policy : "",
    emailReceiveEnabled: typeof raw.email_receive_enabled === "boolean" ? raw.email_receive_enabled : null,
    publicWeb: raw.proxy_share === "public" || !!(raw.sharing && raw.sharing.public_proxy),
    adminAllowed: !!(raw.access && raw.access.admin === true),
    shellAllowed: !(raw.access && raw.access.shell === false),
    webAllowed: !(raw.access && raw.access.web === false)
  };
}

// Optional display metadata must not invent resource values when absent.
function metadataNumber(value) {
  return typeof value === "number" && isFinite(value) && value > 0 ? value : 0;
}

function formatBytes(bytes) {
  if (!metadataNumber(bytes)) return "";
  var units = ["B", "KiB", "MiB", "GiB", "TiB"];
  var unit = 0;
  while (bytes >= 1024 && unit < units.length - 1) { bytes /= 1024; unit++; }
  return Math.round(bytes * 10) / 10 + " " + units[unit];
}

function resourceSummary(vm) {
  if (!vm) return "";
  var parts = [];
  if (vm.cpus) parts.push(vm.cpus + (vm.cpus === 1 ? " vCPU" : " vCPUs"));
  if (vm.memoryBytes) parts.push(formatBytes(vm.memoryBytes) + " RAM");
  if (vm.diskBytes) parts.push(formatBytes(vm.diskBytes) + " disk");
  return parts.join(" · ");
}

function networkSummary(vm) {
  if (!vm) return "";
  var parts = [];
  if (vm.proxyPort) parts.push("Port " + vm.proxyPort);
  parts.push(vm.publicWeb ? "Public web" : "Private web");
  if (vm.egressPolicy)
    parts.push("Egress: " + (vm.egressPolicy === "all" ? "all destinations" : vm.egressPolicy === "integrations" ? "integrations only" : vm.egressPolicy));
  return parts.join(" · ");
}

function createdAgo(createdAt, now) {
  if (!createdAt) return "";
  var timestamp = Date.parse(createdAt);
  if (!isFinite(timestamp)) return "";
  if (typeof now !== "number" || !isFinite(now)) now = Date.now();
  var seconds = Math.max(0, (now - timestamp) / 1000);
  if (seconds < 60) return "Created just now";
  var count, unit;
  if (seconds < 3600) { count = Math.floor(seconds / 60); unit = "minute"; }
  else if (seconds < 86400) { count = Math.floor(seconds / 3600); unit = "hour"; }
  else { count = Math.floor(seconds / 86400); unit = "day"; }
  return "Created " + count + " " + unit + (count === 1 ? "" : "s") + " ago";
}

function detailFacts(vm) {
  if (!vm) return [];
  var facts = [];
  if (vm.region || vm.regionDisplay)
    facts.push({label: "Region", value: vm.region ? vm.region.toUpperCase() : vm.regionDisplay, tooltip: vm.regionDisplay || ""});
  if (typeof vm.emailReceiveEnabled === "boolean")
    facts.push({label: "Email", value: vm.emailReceiveEnabled ? "Receive on" : "Receive off"});
  return facts;
}

function parseVms(text) {
  var data = JSON.parse(text);
  if (!data || !Array.isArray(data.vms))
    throw new Error(data && typeof data.error === "string" ? data.error : "Expected a VM list");
  var seen = [];
  var vms = data.vms.map(normalizeVm);
  vms.forEach(function(vm) {
    if (seen.indexOf(vm.name) >= 0) throw new Error("Duplicate VM: " + vm.name);
    seen.push(vm.name);
  });
  return vms.sort(function(a, b) {
    return a.group.localeCompare(b.group) || a.name.localeCompare(b.name);
  });
}

// Higher scores win; -Infinity means the query is not a subsequence.
// Validated VM names have at most 63 characters, so these score tiers keep
// exact > prefix > substring > scattered matches regardless of alignment.
function fuzzyScore(vmName, input) {
  var name = vmName.toLowerCase();
  var query = String(input || "").trim().toLowerCase();
  if (!query) return 0;
  if (query.length > name.length) return -Infinity;
  if (name === query) return 1000000;
  if (name.indexOf(query) === 0) return 100000 - name.length;

  var substring = name.indexOf(query);
  if (substring !== -1) return 10000 - substring * 2 - name.length;

  // prev[j] is the best alignment ending at name[j] for the preceding
  // query character. Evaluate every alignment, not just the first match.
  var prev = new Array(name.length).fill(-Infinity);
  for (var i = 0; i < query.length; i++) {
    var next = new Array(name.length).fill(-Infinity);
    for (var j = 0; j < name.length; j++) {
      if (name[j] !== query[i]) continue;
      var boundary = j === 0 || name[j - 1] === "-" ? 8 : 0;
      var reward = 10 + boundary;
      if (i === 0) {
        next[j] = reward - j;
        continue;
      }
      for (var k = 0; k < j; k++) {
        var gap = j - k - 1;
        var adjacency = gap === 0 ? 12 : 0;
        next[j] = Math.max(next[j], prev[k] + reward + adjacency - gap);
      }
    }
    prev = next;
  }
  return Math.max.apply(null, prev);
}

function filterVms(vms, query) {
  var needle = String(query || "").trim();
  if (!needle) return vms.slice(); // Preserve the default tag/name ordering.
  return vms.map(function(vm) {
    return {vm: vm, score: fuzzyScore(vm.name, needle)};
  }).filter(function(match) {
    return match.score !== -Infinity;
  }).sort(function(a, b) {
    return b.score - a.score || a.vm.name.localeCompare(b.vm.name);
  }).map(function(match) { return match.vm; });
}

// vms must be the already-filtered/ranked list so row indices and keyboard
// actions refer to the same VM. Search results must not be regrouped.
function listRows(vms, query) {
  if (!String(query || "").trim()) return groupedRows(vms);
  return vms.map(function(vm, index) {
    return {kind: "vm", label: "", count: 0, vm: vm, vmIndex: index};
  });
}

function groupedRows(vms) {
  var rows = [];
  var groups = [];
  vms.forEach(function(vm) { if (groups.indexOf(vm.group) < 0) groups.push(vm.group); });
  groups.forEach(function(group) {
    var members = vms.filter(function(vm) { return vm.group === group; });
    rows.push({kind: "group", label: group, count: members.length, vm: null, vmIndex: -1});
    members.forEach(function(vm) {
      rows.push({kind: "vm", label: "", count: 0, vm: vm, vmIndex: vms.indexOf(vm)});
    });
  });
  return rows;
}

function sshCommand(vm) {
  // Validate again at the action boundary; no shell evaluates any VM metadata.
  var safe = normalizeVm({vm_name: vm.name, ssh_dest: vm.sshDest});
  return ["omarchy-launch-terminal", "ssh", "--", safe.sshDest];
}

// Fixed command/host and validated arguments only: SSH joins remote arguments
// into a command string, so never pass arbitrary metadata or an arbitrary verb.
function managementCommand(vm, action) {
  if (["restart", "pause", "resume", "copy"].indexOf(action) < 0)
    throw new Error("Unsupported VM action");
  if (!vm || vm.adminAllowed !== true) throw new Error("VM administration is not allowed");
  var safe = normalizeVm({vm_name: vm.name});
  return ["timeout", "--kill-after=2s", "120s", "ssh",
    "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
    "-o", "ConnectTimeout=8", "-o", "ConnectionAttempts=1",
    "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2",
    "exe.dev", action === "copy" ? "cp" : action, safe.name, "--json"];
}

function replCommand() {
  // Omarchy floats this app-id. xdg-terminal-exec adapts it to the user's
  // configured terminal; no transient Hyprland rule or shell wrapper needed.
  return ["omarchy-launch-terminal", "--app-id=org.omarchy.terminal",
    "--title=exe.dev", "ssh", "exe.dev"];
}

function browserCommand(vm) {
  var safe = normalizeVm({vm_name: vm.name});
  return ["omarchy-launch-browser", safe.url];
}
