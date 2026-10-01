import QtQuick
import QtTest
import "../../QuickXP/AppCatalogFilter.js" as AppCatalogFilter

TestCase {
  name: "AppCatalogFilter"

  function test_isLaunchable() {
    verify(!AppCatalogFilter.isLaunchable(null))
    verify(!AppCatalogFilter.isLaunchable({ name: "X", noDisplay: true }))
    verify(!AppCatalogFilter.isLaunchable({ name: "  ", noDisplay: false }))
    verify(AppCatalogFilter.isLaunchable({ name: "Terminal", noDisplay: false }))
  }

  function test_filterLaunchable_array() {
    const entries = [
      { name: "Keep", noDisplay: false },
      { name: "Hidden", noDisplay: true },
      { name: "", noDisplay: false },
      { name: "Also", noDisplay: false }
    ]
    const out = AppCatalogFilter.filterLaunchable(entries)
    compare(out.length, 2)
    compare(out[0].name, "Keep")
    compare(out[1].name, "Also")
  }

  function test_filterByQuery_and_sort() {
    const entries = [
      { name: "Zebra", noDisplay: false },
      { name: "Apple", noDisplay: false },
      { name: "Apricot", noDisplay: false }
    ]
    const filtered = AppCatalogFilter.filterByQuery(entries, "ap")
    compare(filtered.length, 2)
    const sorted = AppCatalogFilter.sortByName(filtered)
    compare(sorted[0].name, "Apple")
    compare(sorted[1].name, "Apricot")
  }

  function test_empty_query_keeps_all_launchable() {
    const entries = [
      { name: "A", noDisplay: false },
      { name: "B", noDisplay: true }
    ]
    compare(AppCatalogFilter.filterByQuery(entries, "").length, 1)
  }
}
