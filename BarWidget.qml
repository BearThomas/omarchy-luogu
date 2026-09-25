import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "bearthomas.luogu"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    // FloatingWindow is a child of the loaded panel and needs a visible
    // ancestor, even while KeyboardPanel manages its own popup visibility.
    visible: true
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.setting("iconText", "洛")
    slotSize: Style.bar.statusSlot
    tooltipText: "洛谷"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) {
        if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
      } else if (mouseButton === Qt.LeftButton) {
        root.togglePanel()
      }
    }
  }

  Text {
    // `omarchy bar set` 不带 --json 时会把值写成字符串（"false"），而字符串
    // "false" 在 JS 里是真值，所以这里显式归一化。
    visible: String(root.setting("showUnreadBadge", "true")) !== "false"
      && panelLoader.item
      && (panelLoader.item.unreadMessages + panelLoader.item.unreadNotifications) > 0
    text: {
      var total = panelLoader.item ? panelLoader.item.unreadMessages + panelLoader.item.unreadNotifications : 0
      return total > 99 ? "99+" : String(total)
    }
    anchors.right: button.right
    anchors.top: button.top
    anchors.rightMargin: -Style.space(2)
    anchors.topMargin: -Style.space(2)
    color: Color.accent
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    z: 2
  }

  Timer {
    id: refreshTimer
    // 刷新间隔可配置（manifest 的 refreshIntervalSec，默认 300 秒）
    interval: Math.max(30, Number(root.setting("refreshIntervalSec", 300))) * 1000
    repeat: true
    running: true
    onTriggered: if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  IpcHandler {
    target: "bearthomas.luogu"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { if (panelLoader.item) panelLoader.item.refresh() }
    function details(): void { if (panelLoader.item) panelLoader.item.openDetails() }
  }
}
