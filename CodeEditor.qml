import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "Model.js" as Model

// 自绘代码编辑器：行号栏 + 高亮层 + 可编辑层 + 自动补全。
//
// 对齐是这里最容易踩的地方，两条规矩：
//  1. **两层必须是同一种元素**（都是 TextEdit），否则字体度量/内容偏移不一致，
//     光标就和文字错位。TextEdit 自己支持 cursorDelegate，不需要 TextArea。
//  2. 高亮层是 RichText，而 RichText 会像 HTML 一样**折叠连续空格** —— 缩进会被
//     吃掉，于是高亮文字比光标"靠左"。所以 Model.highlightCode 把空格写成
//     &nbsp;、Tab 展开成 4 个空格。
// 另外必须 NoWrap + 横向滚动：一旦折行，两层的换行位置就未必一致。
Item {
  id: root

  property string text: ""
  property string language: "C++14 (GCC 9)"
  property color foreground: Color.foreground
  property color accentColor: Color.accent
  property bool dark: true
  property string fontFamily: "monospace"
  property int pixelSize: Style.font.bodySmall
  property int indentWidth: 4
  property bool readOnly: false
  property bool completionsEnabled: true
  property alias cursorPosition: editor.cursorPosition

  readonly property int lineCount: editor.lineCount
  // 实际行高只能从可编辑层量出来（TextEdit 用的是字体自身行距）
  readonly property real measuredLineHeight: {
    var lines = Math.max(1, editor.lineCount)
    var usable = editor.contentHeight - editor.topPadding - editor.bottomPadding
    return usable > 0 ? usable / lines : Math.ceil(metrics.height)
  }
  readonly property real gutterHeight: lineCount * measuredLineHeight
  readonly property real editorHeight: editor.contentHeight
  readonly property real highlightHeight: highlightLayer.contentHeight

  // 统一的滚轮换算。**不要假设一个事件就是 120 单位**：Omarchy 的 Util.wheelSteps
  // 注释提到某些鼠标/合成器组合远超 120；反过来实测触控板给的值可能很小，按
  // /120 折算会几乎不动 —— 那正是"滚得慢"的来源。这里同时打印原始值以便按真机
  // 数据调参（调试完删掉 console.log 即可）。
  function wheelStepFor(event, pixelFactor, stepSize) {
    var pixel = event.pixelDelta ? event.pixelDelta.y : 0
    var angle = event.angleDelta ? event.angleDelta.y : 0
    var step = pixel !== 0 ? pixel * pixelFactor : angle / 120 * Style.space(stepSize)
    return step
  }

  function applyWheel(flick, step) {
    if (!flick || step === 0) return
    var limit = Math.max(0, flick.contentHeight - flick.height)
    flick.contentY = Math.max(0, Math.min(limit, flick.contentY - step))
  }


  property var completions: []
  property int completionIndex: 0

  signal submitted()
  signal runRequested()
  signal saveRequested()

  implicitHeight: Style.space(300)

  FontMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
  }

  function diag() {
    return {
      lines: editor.lineCount,
      editorContentH: Math.round(editor.contentHeight * 100) / 100,
      highlightContentH: Math.round(highlightLayer.contentHeight * 100) / 100,
      topPad: editor.topPadding,
      leftPad: editor.leftPadding,
      measuredLineHeight: Math.round(measuredLineHeight * 100) / 100,
      completions: root.completions.length
    }
  }

  // 外部只通过 loadText 灌入内容，避免双向绑定打架
  function loadText(value) {
    var next = String(value === undefined || value === null ? "" : value)
    if (editor.text !== next) editor.text = next
    if (root.text !== next) root.text = next
  }

  function insertAtCursor(snippet) {
    var content = editor.text
    var position = editor.cursorPosition
    editor.text = content.slice(0, position) + snippet + content.slice(position)
    editor.cursorPosition = position + snippet.length
  }

  function currentLineIndent() {
    var content = editor.text
    var start = content.lastIndexOf("\n", Math.max(0, editor.cursorPosition - 1)) + 1
    var end = content.indexOf("\n", start)
    if (end < 0) end = content.length
    var line = content.slice(start, end)
    return /^[ \t]*/.exec(line)[0]
  }

  function toggleLineComment(marker) {
    var content = editor.text
    var start = content.lastIndexOf("\n", Math.max(0, editor.cursorPosition - 1)) + 1
    var end = content.indexOf("\n", start)
    if (end < 0) end = content.length
    var line = content.slice(start, end)
    var trimmed = line.replace(/^[ \t]*/, "")
    var prefix = line.slice(0, line.length - trimmed.length)
    var next = trimmed.indexOf(marker) === 0
      ? prefix + trimmed.slice(marker.length)
      : prefix + marker + trimmed
    editor.text = content.slice(0, start) + next + content.slice(end)
    editor.cursorPosition = start + next.length
  }

  // ---- 自动补全 -------------------------------------------------------------
  function refreshCompletions() {
    if (!root.completionsEnabled || root.readOnly) { root.completions = []; return }
    var prefix = Model.wordBefore(editor.text, editor.cursorPosition)
    if (prefix.length < 1) { root.completions = []; return }
    // completionMatches 已经丢掉与 prefix 完全相同的候选
    root.completions = Model.completionMatches(root.language, prefix)
    root.completionIndex = 0
  }

  function acceptCompletion() {
    if (root.completions.length === 0) return false
    var item = root.completions[Math.max(0, Math.min(root.completionIndex, root.completions.length - 1))]
    var prefix = Model.wordBefore(editor.text, editor.cursorPosition)
    var start = editor.cursorPosition - prefix.length
    var content = editor.text
    editor.text = content.slice(0, start) + item.text + content.slice(editor.cursorPosition)
    editor.cursorPosition = start + item.text.length
    root.completions = []
    return true
  }

  function moveCompletion(delta) {
    if (root.completions.length === 0) return false
    var next = root.completionIndex + delta
    if (next < 0) next = root.completions.length - 1
    if (next >= root.completions.length) next = 0
    root.completionIndex = next
    return true
  }

  onTextChanged: if (editor.text !== root.text) editor.text = root.text

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
    border.width: 1
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    clip: true

    Flickable {
      id: verticalFlick
      // 滚轮调优（同「洛谷中心」窗口）：默认步进在触控板上太慢
      property int wheelStep: 220
      property real wheelPixelFactor: 5.0
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          var step = wheelStepFor(event, verticalFlick.wheelPixelFactor, verticalFlick.wheelStep)
          if (step !== 0) event.accepted = true
          applyWheel(verticalFlick, step)
        }
      }
      anchors.fill: parent
      anchors.margins: Style.space(6)
      clip: true
      contentWidth: width
      contentHeight: Math.max(codeRow.height, height)
      boundsBehavior: Flickable.StopAtBounds
      QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

      Row {
        id: codeRow
        width: verticalFlick.width
        spacing: Style.space(6)

        // 行号栏
        Column {
          id: gutter
          width: Style.space(Math.max(24, 10 + String(root.lineCount).length * 9))
          Repeater {
            model: root.lineCount
            delegate: Text {
              required property int index
              width: gutter.width
              height: root.measuredLineHeight
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignRight
              text: index + 1
              color: Qt.darker(root.foreground, 2.1)
              font.family: root.fontFamily
              font.pixelSize: root.pixelSize
            }
          }
        }

        // 横向滚动的代码区（两层叠加 + 补全弹窗）
        Flickable {
          id: horizontalFlick
          width: codeRow.width - gutter.width - codeRow.spacing
          height: codeRow.height
          contentWidth: Math.max(codeContent.width, width)
          contentHeight: height
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          QQC.ScrollBar.horizontal: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

          Item {
            id: codeContent
            width: Math.max(editor.contentWidth + Style.space(40), horizontalFlick.width)
            height: Math.max(editor.contentHeight, highlightLayer.contentHeight)

            // 着色层：只读 RichText TextEdit（和下面那层同一种元素，度量一致）
            TextEdit {
              id: highlightLayer
              width: parent.width
              text: Model.highlightCode(editor.text, root.language, root.dark)
              textFormat: TextEdit.RichText
              readOnly: true
              selectByMouse: false
              activeFocusOnPress: false
              wrapMode: TextEdit.NoWrap
              padding: 0
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: root.pixelSize
            }

            // 可编辑层：文字透明，只保留光标与选区
            TextEdit {
              id: editor
              width: parent.width
              text: root.text
              readOnly: root.readOnly
              wrapMode: TextEdit.NoWrap
              selectByMouse: true
              persistentSelection: true
              padding: 0
              color: "transparent"
              selectionColor: Style.selectionFillFor(root.foreground, root.accentColor)
              font.family: root.fontFamily
              font.pixelSize: root.pixelSize
              cursorDelegate: Rectangle {
                width: 2
                height: editor.cursorRectangle.height
                color: root.accentColor
                visible: editor.activeFocus && editor.cursorVisible
              }
              onTextChanged: {
                if (root.text !== text) root.text = text
                root.refreshCompletions()
              }
              onCursorPositionChanged: root.refreshCompletions()
              onActiveFocusChanged: if (!activeFocus) root.completions = []

              Keys.onPressed: function(event) {
                var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                var shift = (event.modifiers & Qt.ShiftModifier) !== 0
                // 补全弹窗优先吃掉上下键和回车/Tab
                if (root.completions.length > 0) {
                  if (event.key === Qt.Key_Down) { root.moveCompletion(1); event.accepted = true; return }
                  if (event.key === Qt.Key_Up) { root.moveCompletion(-1); event.accepted = true; return }
                  if (event.key === Qt.Key_Escape) { root.completions = []; event.accepted = true; return }
                  if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) && !ctrl) {
                    root.acceptCompletion()
                    event.accepted = true
                    return
                  }
                }
                if (ctrl && event.key === Qt.Key_Return) { root.submitted(); event.accepted = true; return }
                if (ctrl && event.key === Qt.Key_R) { root.runRequested(); event.accepted = true; return }
                if (ctrl && event.key === Qt.Key_S) { root.saveRequested(); event.accepted = true; return }
                if (ctrl && event.key === Qt.Key_Slash) {
                  root.toggleLineComment(root.language.toLowerCase().indexOf("python") >= 0 ? "# " : "// ")
                  event.accepted = true
                  return
                }
                if (ctrl && event.key === Qt.Key_Space) { root.refreshCompletions(); event.accepted = root.completions.length > 0; return }
                if (event.key === Qt.Key_Tab) {
                  root.insertAtCursor(new Array(root.indentWidth + 1).join(" "))
                  event.accepted = true
                  return
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  var indent = root.currentLineIndent()
                  var charBefore = editor.text.slice(0, editor.cursorPosition)
                  var trimmed = charBefore.replace(/\s+$/, "")
                  var lastChar = trimmed.slice(-1)
                  var openBrace = lastChar === "{" || (root.language.toLowerCase().indexOf("python") >= 0 && lastChar === ":")
                  root.insertAtCursor("\n" + indent + (openBrace ? new Array(root.indentWidth + 1).join(" ") : ""))
                  event.accepted = true
                  return
                }
                var pairs = { "(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'" }
                var key = event.text
                if (key.length === 1 && pairs[key] !== undefined) {
                  root.insertAtCursor(key + pairs[key])
                  editor.cursorPosition -= 1
                  event.accepted = true
                }
              }
            }

            // TextEdit 没有 placeholder，自己画一个
            Text {
              anchors.left: parent.left
              anchors.top: parent.top
              visible: editor.text === "" && !root.readOnly
              text: "在这里写代码（上次提交的代码会自动填进来）"
              color: Qt.darker(root.foreground, 1.7)
              font.family: root.fontFamily
              font.pixelSize: root.pixelSize
            }

            // 自动补全弹窗：贴着光标
            Rectangle {
              id: completionPopup
              visible: root.completions.length > 0
              x: Math.min(editor.cursorRectangle.x, Math.max(0, codeContent.width - width))
              y: editor.cursorRectangle.y + editor.cursorRectangle.height
              width: Style.space(360)
              height: completionColumn.implicitHeight + Style.space(8)
              radius: Style.cornerRadius
              color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.97)
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              z: 10

              Column {
                id: completionColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(4)
                spacing: 0
                Repeater {
                  model: root.completions
                  delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: completionColumn.width
                    height: Style.space(22)
                    radius: Style.space(3)
                    color: index === root.completionIndex
                      ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28)
                      : "transparent"
                    Row {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.leftMargin: Style.space(6)
                      anchors.rightMargin: Style.space(6)
                      spacing: Style.space(6)
                      Text {
                        width: parent.width - Style.space(54)
                        elide: Text.ElideRight
                        text: modelData.text
                        color: modelData.snippet ? root.accentColor : root.foreground
                        font.family: "monospace"
                        font.pixelSize: root.pixelSize
                      }
                      Text {
                        width: Style.space(44)
                        horizontalAlignment: Text.AlignRight
                        text: modelData.snippet ? "片段" : ""
                        color: Qt.darker(root.foreground, 1.6)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onEntered: root.completionIndex = index
                      onClicked: { root.completionIndex = index; root.acceptCompletion(); editor.forceActiveFocus() }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Component.onCompleted: root.loadText(root.text)
}
