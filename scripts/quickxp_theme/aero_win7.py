"""Windows 7 logical-key map.

Same binding records as aero_vista.BINDINGS (classes, part, images, group).
The list stays empty so a Win7 .msstyles parses on the shared decoder and
then stops, instead of pretending Vista parts are the superbar and orb.
"""

from __future__ import annotations

BINDINGS: list[dict] = []

NOT_IMPLEMENTED = "Win7 map is not implemented yet"
