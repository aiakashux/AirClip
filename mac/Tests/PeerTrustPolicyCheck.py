"""Compile the production trust predicate and reject removed devices."""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).parents[1] / "Airclip/Core/PeerManager.swift").read_text()
start = source.index("func isTrustedPeer(")
end = source.index("\n}\n", start) + 2
policy = source[start:end]
harness = policy + r'''
precondition(!isTrustedPeer(
    theirAirclipId: "space", ourAirclipId: "space",
    deviceId: "removed", pairedDeviceIds: ["phone"]
))
precondition(!isTrustedPeer(
    theirAirclipId: "other", ourAirclipId: "space",
    deviceId: "phone", pairedDeviceIds: ["phone"]
))
precondition(isTrustedPeer(
    theirAirclipId: "space", ourAirclipId: "space",
    deviceId: "phone", pairedDeviceIds: ["phone"]
))
'''
with tempfile.TemporaryDirectory(prefix="airclip-peer-trust-") as folder:
    swift = Path(folder) / "check.swift"
    swift.write_text(harness)
    subprocess.run(["xcrun", "swift", str(swift)], check=True)
