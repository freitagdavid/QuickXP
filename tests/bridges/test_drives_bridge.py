"""DrivesBridge pure helpers (no live udisks)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "QuickXP" / "services"))
import DrivesBridge as db  # noqa: E402


SAMPLE = """
{
  "blockdevices": [
    {
      "name": "sda",
      "path": "/dev/sda",
      "type": "disk",
      "rm": false,
      "hotplug": false,
      "children": [
        {
          "name": "sda1",
          "path": "/dev/sda1",
          "type": "part",
          "rm": false,
          "mountpoint": "/"
        }
      ]
    },
    {
      "name": "sdb",
      "path": "/dev/sdb",
      "type": "disk",
      "rm": true,
      "hotplug": true,
      "children": [
        {
          "name": "sdb1",
          "path": "/dev/sdb1",
          "type": "part",
          "rm": true,
          "label": "USBSTICK",
          "mountpoint": "/run/media/u/USBSTICK"
        }
      ]
    }
  ]
}
"""


def test_parse_lsblk_json_removable_only():
    drives = db.parse_lsblk_json(SAMPLE)
    assert len(drives) == 1
    assert drives[0]["path"] == "/dev/sdb1"
    assert drives[0]["label"] == "USBSTICK"
    assert drives[0]["mountpoint"].endswith("USBSTICK")


def test_parse_invalid():
    assert db.parse_lsblk_json("{") == []
    assert db.parse_lsblk_json("") == []


def test_open_and_eject_commands():
    assert db.open_command("") is None
    cmd = db.open_command("/media/foo")
    if cmd is not None:
        assert cmd[-1] == "/media/foo"
    ejects = db.eject_commands("/dev/sdb1")
    if ejects:
        assert ejects[0][1] == "unmount"
        assert ejects[1][1] == "power-off"


def test_handle_line_list_prefix():
    # LIST uses live lsblk; just ensure unknown op errors.
    assert db.handle_line("NOPE") == "ERR unknown"
    assert db.handle_line("") == ""
