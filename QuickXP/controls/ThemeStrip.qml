import QtQuick
import qs.QuickXP

// Nine-slice a single frame from a vertical multi-frame theme bitmap (uxtheme ImageLayout=vertical).
Item {
  id: root

  property string imageKey: ""
  property url source: {
    const path = imageKey !== "" ? Theme.image(imageKey) : ""
    if (path === "")
      return ""
    return path.startsWith("file:") ? path : "file://" + path
  }

  property int frames: 1
  property int frame: 0
  property int borderLeft: 0
  property int borderRight: 0
  property int borderTop: 0
  property int borderBottom: 0
  property bool smooth: false

  readonly property real fw: sheet.status === Image.Ready ? sheet.sourceSize.width : 0
  readonly property real fh: sheet.status === Image.Ready && frames > 0
    ? sheet.sourceSize.height / frames
    : 0
  readonly property real fy: fh * Math.max(0, Math.min(frames - 1, frame))
  readonly property bool ready: sheet.status === Image.Ready && fw > 0 && fh > 0

  readonly property real midSrcW: Math.max(1, fw - borderLeft - borderRight)
  readonly property real midSrcH: Math.max(1, fh - borderTop - borderBottom)
  readonly property real midDstW: Math.max(0, width - borderLeft - borderRight)
  readonly property real midDstH: Math.max(0, height - borderTop - borderBottom)

  Image {
    id: sheet
    visible: false
    asynchronous: true
    source: root.source
  }

  component Slice: Image {
    required property real sx
    required property real sy
    required property real sw
    required property real sh
    visible: root.ready && width > 0 && height > 0 && sw > 0 && sh > 0
    source: root.source
    sourceClipRect: Qt.rect(sx, sy, sw, sh)
    smooth: root.smooth
    asynchronous: true
    fillMode: Image.Stretch
  }

  // Top row
  Slice {
    x: 0; y: 0; width: root.borderLeft; height: root.borderTop
    sx: 0; sy: root.fy; sw: root.borderLeft; sh: root.borderTop
  }
  Slice {
    x: root.borderLeft; y: 0; width: root.midDstW; height: root.borderTop
    sx: root.borderLeft; sy: root.fy; sw: root.midSrcW; sh: root.borderTop
  }
  Slice {
    x: root.width - root.borderRight; y: 0; width: root.borderRight; height: root.borderTop
    sx: root.fw - root.borderRight; sy: root.fy; sw: root.borderRight; sh: root.borderTop
  }

  // Middle row
  Slice {
    x: 0; y: root.borderTop; width: root.borderLeft; height: root.midDstH
    sx: 0; sy: root.fy + root.borderTop; sw: root.borderLeft; sh: root.midSrcH
  }
  Slice {
    x: root.borderLeft; y: root.borderTop; width: root.midDstW; height: root.midDstH
    sx: root.borderLeft; sy: root.fy + root.borderTop; sw: root.midSrcW; sh: root.midSrcH
  }
  Slice {
    x: root.width - root.borderRight; y: root.borderTop; width: root.borderRight; height: root.midDstH
    sx: root.fw - root.borderRight; sy: root.fy + root.borderTop; sw: root.borderRight; sh: root.midSrcH
  }

  // Bottom row
  Slice {
    x: 0; y: root.height - root.borderBottom; width: root.borderLeft; height: root.borderBottom
    sx: 0; sy: root.fy + root.fh - root.borderBottom; sw: root.borderLeft; sh: root.borderBottom
  }
  Slice {
    x: root.borderLeft; y: root.height - root.borderBottom; width: root.midDstW; height: root.borderBottom
    sx: root.borderLeft; sy: root.fy + root.fh - root.borderBottom; sw: root.midSrcW; sh: root.borderBottom
  }
  Slice {
    x: root.width - root.borderRight; y: root.height - root.borderBottom; width: root.borderRight; height: root.borderBottom
    sx: root.fw - root.borderRight; sy: root.fy + root.fh - root.borderBottom; sw: root.borderRight; sh: root.borderBottom
  }

  Rectangle {
    anchors.fill: parent
    visible: !root.ready
    color: Theme.color("button", "#ECE9D8")
    border.width: 1
    border.color: Theme.color("border", "#003C74")
    radius: 2
  }
}
