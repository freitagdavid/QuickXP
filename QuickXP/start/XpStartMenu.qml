import QtQuick
import Quickshell
import qs.QuickXP
import "../StartSearchModel.js" as StartSearchModel
import "StartMenuLayout.js" as StartMenuLayout

// XP dual-column Start — sizes/colors/images from Theme.startPanel.
// Vista/7: search field under All Programs in the left column when GenerationPolicy.startSearch is on.
Item {
  id: root

  property var host: null
  property var programsNode: null

  property string searchQuery: ""
  property int resultsFocusIndex: -1

  // Lowercase haystack + pin map; searchResults is updated imperatively (not a
  // binding) so rebuilds cannot form a QML binding loop.
  property var appSearchIndex: []
  property var pinSet: ({})
  property var searchResults: []

  // Search chrome when the startSearch toggle is on (default for shell vista/win7),
  // or when Start menu layout override is Vista/7 ("Search Start" choices).
  readonly property bool searchEnabled: StartMenuLayout.useStartSearch(
    GenerationPolicy.featureEnabled("startSearch")
      || GenerationPolicy.isVistaOrLater("startMenu"))
  readonly property bool searchActive: searchEnabled && searchQuery.trim() !== ""

  function rebuildSearchIndex() {
    root.appSearchIndex = StartSearchModel.buildAppSearchIndex(AppCatalog.applications)
    root.pinSet = StartSearchModel.pinIdSet(StartPinStore.pinIds)
  }

  function refreshSearchResults() {
    if (!root.searchActive) {
      if (root.searchResults.length)
        root.searchResults = []
      return
    }
    root.searchResults = StartSearchModel.buildResults(root.searchQuery, {
      appIndex: root.appSearchIndex,
      pinSet: root.pinSet,
      recentItems: RecentCatalog.recentItems,
      rawMfuScores: Config.options.startMfuScores,
      settings: StartSearchModel.defaultSettingsIndex()
    })
  }

  function prepareOpen() {
    root.rebuildSearchIndex()
    root.refreshSearchResults()
  }

  onSearchQueryChanged: root.refreshSearchResults()
  onSearchActiveChanged: root.refreshSearchResults()

  Connections {
    target: AppCatalog
    function on_RevisionChanged() {
      root.rebuildSearchIndex()
      root.refreshSearchResults()
    }
  }

  Connections {
    target: StartPinStore
    function on_RevisionChanged() {
      root.rebuildSearchIndex()
      root.refreshSearchResults()
    }
  }

  Connections {
    target: RecentCatalog
    function on_RevisionChanged() {
      root.refreshSearchResults()
    }
  }

  Connections {
    target: StartMfuStore
    function on_RevisionChanged() {
      root.refreshSearchResults()
    }
  }

  Connections {
    target: Config.options
    function onStartMfuScoresChanged() {
      root.refreshSearchResults()
    }
  }

  readonly property int leftW: Number(Theme.value("startPanel", "leftColumnWidth", 190))
  readonly property int rightW: Number(Theme.value("startPanel", "rightColumnWidth", 190))
  readonly property int bodyH: Number(Theme.value("startPanel", "bodyHeight", 336))
  readonly property color outerBorder: String(Theme.value("startPanel", "outerBorder", Theme.color("border", "#003C74")))

  width: Number(Theme.value("startPanel", "width", leftW + rightW))
  // Outer 2px border margins are inside this height (Luna DefaultPaneSize 440).
  height: Number(Theme.value("startPanel", "height", 440))
  implicitHeight: height

  readonly property bool submenuOpen: rightCol.submenuOpen || leftCol.submenuOpen

  function closeSubmenus() {
    leftCol.closeSubmenus()
    rightCol.closeSubmenus()
  }

  function clearSearch() {
    root.searchQuery = ""
    root.resultsFocusIndex = -1
    if (leftCol.searchField)
      leftCol.searchField.text = ""
  }

  function resetFocus() {
    rightCol.focusIndex = -1
    root.resultsFocusIndex = -1
    root.clearSearch()
    if (root.searchEnabled && leftCol.searchField)
      Qt.callLater(() => leftCol.searchField.forceActiveFocus())
  }

  function activateSearchResult(node) {
    if (!node || !host)
      return
    if (node.kind === "header")
      return
    if (node.kind === "app") {
      leftCol.activateNode(node)
      return
    }
    if (node.kind === "setting") {
      if (typeof host.openSetting === "function")
        host.openSetting(node.tab)
      return
    }
    if (node.kind === "action") {
      leftCol.activateNode(node)
    }
  }

  function activateHighlightedResult() {
    const rows = root.searchResults
    if (!rows.length)
      return false
    let idx = root.resultsFocusIndex
    if (idx < 0 || idx >= rows.length || !StartSearchModel.isSelectable(rows[idx]))
      idx = StartSearchModel.firstSelectableIndex(rows)
    if (idx < 0)
      return false
    root.activateSearchResult(rows[idx])
    return true
  }

  function handleSearchKey(event) {
    if (!event || !root.searchEnabled)
      return
    if (event.key === Qt.Key_Escape) {
      if (StartSearchModel.escClearsQuery(root.searchQuery)) {
        root.clearSearch()
        if (leftCol.searchField)
          leftCol.searchField.forceActiveFocus()
      } else if (host && typeof host.close === "function") {
        host.close()
      }
      event.accepted = true
      return
    }
    if (!root.searchActive) {
      event.accepted = false
      return
    }
    if (event.key === Qt.Key_Down) {
      root.resultsFocusIndex = StartSearchModel.moveFocus(
        root.searchResults, root.resultsFocusIndex, 1)
      if (root.resultsFocusIndex < 0)
        root.resultsFocusIndex = StartSearchModel.firstSelectableIndex(root.searchResults)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Up) {
      const next = StartSearchModel.moveFocus(
        root.searchResults, root.resultsFocusIndex, -1)
      root.resultsFocusIndex = next
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.activateHighlightedResult())
        event.accepted = true
      else
        event.accepted = false
      return
    }
    event.accepted = false
  }

  function handleKey(event) {
    if (!event)
      return
    // When the search field has focus it handles keys via keyPressed.
    // Fallback path if xpFocus receives arrows/Esc while search is enabled.
    if (root.searchEnabled) {
      root.handleSearchKey(event)
      return
    }
    event.accepted = false
  }

  function activateNode(node) {
    rightCol.activateNode(node)
  }

  Rectangle {
    anchors.fill: parent
    color: GenerationPolicy.glass ? "transparent" : root.outerBorder
  }

  Column {
    id: stack
    anchors.fill: parent
    anchors.margins: 2
    spacing: 0

    XpStartUserTile {
      id: userBar
      width: parent.width
      host: root.host

      HoverHandler {
        onHoveredChanged: {
          if (hovered && leftCol.submenuOpen)
            leftCol.closeSubmenus()
        }
      }
    }

    // Take remaining height so places/MFU never spill under the footer
    // (fixed bodyH + bar + footer exceeds the padded stack).
    Row {
      id: bodyRow
      width: parent.width
      height: Math.max(0, stack.height - userBar.height - footer.height)
      spacing: 0
      clip: true

      XpStartLeftColumn {
        id: leftCol
        height: parent.height
        host: root.host
        programsNode: root.programsNode
        searchEnabled: root.searchEnabled
        searchActive: root.searchActive
        searchResults: root.searchResults
        resultsFocusIndex: root.resultsFocusIndex
        onAllProgramsOpened: rightCol.closeSubmenus()
        onResultActivated: (node) => root.activateSearchResult(node)
        onResultHovered: (index) => root.resultsFocusIndex = index
        onSearchEdited: (text) => {
          root.searchQuery = text
          root.resultsFocusIndex = -1
          if (leftCol.submenuOpen)
            leftCol.closeSubmenus()
        }
        onSearchKeyPressed: (event) => root.handleSearchKey(event)
      }

      XpStartRightColumn {
        id: rightCol
        height: parent.height
        host: root.host
        onPeerHovered: leftCol.closeSubmenus()
      }
    }

    XpStartFooter {
      id: footer
      width: parent.width
      host: root.host

      HoverHandler {
        onHoveredChanged: {
          if (hovered && leftCol.submenuOpen)
            leftCol.closeSubmenus()
        }
      }
    }
  }
}
