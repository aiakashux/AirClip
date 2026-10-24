#!/usr/bin/env python3
"""Run isolated Mac behavior/security checks without starting the installed app."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
checks = [
    ('SyncModePolicyCheck', 'Core/SyncMode.swift'),
    ('DeviceDisplayTextCheck', 'Core/DeviceDisplayText.swift'),
    ('DeviceConnectionStatusTextCheck', 'Core/DeviceConnectionStatusText.swift'),
    ('PeerHeartbeatPolicyCheck', 'Core/PeerHeartbeatPolicy.swift'),
    ('DeviceRemovalNoticeCheck', 'Core/DeviceRemovalNotice.swift'),
    ('AddDevicePairingSheetControllerCheck', 'Core/AddDevicePairingSheetController.swift'),
    ('FileTransferMetadataCheck', 'Views/ClipTypeDetector.swift'),
    ('ClipTypeDetectorCheck', 'Views/ClipTypeDetector.swift'),
    ('FileClipCaptureCheck', 'Views/ClipTypeDetector.swift'),
]
with tempfile.TemporaryDirectory(prefix='airclip-policies-') as folder:
    for name, source in checks:
        binary = Path(folder) / name
        extra = []
        if source == "Views/ClipTypeDetector.swift":
            extra.append(str(root/"mac/Airclip/DesignTokens.swift"))
        if name == 'DeviceDisplayTextCheck':
            identity = (root/'mac/Airclip/Core/AirclipIdentity.swift').read_text()
            model = Path(folder) / 'PairedDevice.swift'
            model.write_text(identity.split('// MARK: - AirclipIdentity')[0])
            extra.append(str(model))
        subprocess.run(['xcrun', 'swiftc', *extra, str(root/'mac/Airclip'/source),
                        str(root/'mac/Tests'/f'{name}.swift'), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
        print(f'PASS {name}', flush=True)
for name in ['PeerTrustPolicyCheck', 'PeerAuthCheck', 'HistoryMutationPolicyCheck', 'KeychainMigrationCheck', 'UpdateAndPrivacyCheck']:
    subprocess.run([sys.executable, str(root/'mac/Tests'/f'{name}.py')], check=True)
    print(f'PASS {name}', flush=True)
