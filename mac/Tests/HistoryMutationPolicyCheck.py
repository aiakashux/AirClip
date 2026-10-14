"""Compile the production mutation policy and verify stale history stays deleted."""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).parents[1] / "Airclip/Core/LocalHistoryStore.swift").read_text()
start = source.index("enum HistoryMutationPolicy")
end = source.index("\nenum HistoryMutationStore", start)
policy = source[start:end]
harness = policy + r'''
precondition(!HistoryMutationPolicy.accepts(
    messageId: "old", fromDeviceId: "mac", timestampMs: 100,
    clearedThroughMs: 100, deletedMessageIds: []
))
precondition(!HistoryMutationPolicy.accepts(
    messageId: "different-id", fromDeviceId: "mac", timestampMs: 201,
    clearedThroughMs: 100, deletedMessageIds: [], deletedSourceTimes: ["mac|200"]
))
precondition(HistoryMutationPolicy.accepts(
    messageId: "new", fromDeviceId: "mac", timestampMs: 5_000,
    clearedThroughMs: 100, deletedMessageIds: [], deletedSourceTimes: ["mac|200"]
))
'''
with tempfile.TemporaryDirectory(prefix="airclip-history-policy-") as folder:
    swift = Path(folder) / "check.swift"
    swift.write_text(harness)
    subprocess.run(["xcrun", "swift", str(swift)], check=True)
