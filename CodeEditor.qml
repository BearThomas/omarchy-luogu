import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "Model.js" as Model

// 自绘代码编辑器：行号栏 + 高亮层（Text/RichText）+ 透明 TextEdit 叠加。
//
// 为什么这么做：QML 没有可用的语法高亮控件。做法是让 TextEdit 的文字完全透明
// （color 透明），真正的着色由下面那层 RichText 负责；光标只能用 cursorDelegate
// 自己画（否则会跟着透明），选中仍然靠 selectionColor 背景显示。
// **必须 NoWrap + 横向滚动**：一旦折行，两层的换行位置就未必一致，会整段错位，
// 这也正好和 VSCode 的默认行为一致。
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
  property alias cursorPosition: editor.cursorPosition

  readonly property int lineCount: editor.lineCount
  // 兜底值（内容为空时用）：TextEdit 用的是字体行距取整，不是加行间距
  readonly property real lineHeight: Math.ceil(metrics.height)

  // 实际行高只能从可编辑层量出来（TextEdit/TextArea 用的是字体自身的行距，
  // 和我按 FontMetrics 估的值并不相等 —— 估错了三层就会错位）。
  readonly property real measuredLineHeight: {
    var lines = Math.max(1, editor.lineCount)
    var usable = editor.contentHeight - editor.topPadding - editor.bottomPadding
    return usable > 0 ? usable / lines : lineHeight
  }

  // 供探针/自检用：三层（行号栏 / 高亮层 / 可编辑层）高度是否一致
  readonly property real gutterHeight: lineCount * measuredLineHeight
  readonly property real highlightHeight: highlightLayer.implicitHeight
  readonly property real editorHeight: editor.contentHeight - editor.topPadding - editor.bottomPadding

  function diag() {
    return {
      lines: editor.lineCount,
      contentH: Math.round(editor.contentHeight * 100) / 100,
      topPad: editor.topPadding,
      bottomPad: editor.bottomPadding,
      fontMetricsH: Math.round(metrics.height * 100) / 100,
      pixelSize: root.pixelSize,
      formulaLineHeight: Math.round(lineHeight * 100) / 100,
      measuredLineHeight: Math.round(measuredLineHeight * 100) / 100
    }
  }

  signal submitted()
  signal runRequested()
  signal saveRequested()

  implicitHeight: Style.space(300)

  FontMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
  }

  // 外部只通过 loadText 灌入内容，避免双向绑定打架
  function loadText(value) {
    var next = String(value === undefined || value === null ? "" : value)
    if (editor.text !== next) editor.text = next
    if (root.text !== next) root.text = next
  }

  function insertAtCursor(snippet) {
    var text = editor.text
    var position = editor.cursorPosition
    editor.text = text.slice(0, position) + snippet + text.slice(position)
    editor.cursorPosition = position + snippet.length
  }

  function currentLineIndent() {
    var text = editor.text
    var start = text.lastIndexOf("\n", Math.max(0, editor.cursorPosition - 1)) + 1
    var end = text.indexOf("\n", start)
    if (end < 0) end = text.length
    var line = text.slice(start, end)
    var indent = /^[ \t]*/.exec(line)[0]
    return indent
  }

  function toggleLineComment(marker) {
    var text = editor.text
    var start = text.lastIndexOf("\n", Math.max(0, editor.cursorPosition - 1)) + 1
    var end = text.indexOf("\n", start)
    if (end < 0) end = text.length
    var line = text.slice(start, end)
    var trimmed = line.replace(/^[ \t]*/, "")
    var prefix = line.slice(0, line.length - trimmed.length)
    var next = trimmed.indexOf(marker) === 0
      ? prefix + trimmed.slice(marker.length)
      : prefix + marker + trimmed
    editor.text = text.slice(0, start) + next + text.slice(end)
    editor.cursorPosition = start + next.length
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

        // 横向滚动的代码区（两层叠加）
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
            width: Math.max(editor.implicitWidth, horizontalFlick.width)
            height: editor.implicitHeight

            // 着色层
            Text {
              id: highlightLayer
              width: parent.width
              text: Model.highlightCode(editor.text, root.language, root.dark)
              textFormat: Text.RichText
              wrapMode: Text.NoWrap
              lineHeight: root.measuredLineHeight
              lineHeightMode: Text.FixedHeight
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: root.pixelSize
            }

            // 可编辑层：文字透明，只保留光标与选区
            QQC.TextArea {
              id: editor
              width: parent.width
              height: Math.max(highlightLayer.implicitHeight, root.height - Style.space(12))
              text: root.text
              readOnly: root.readOnly
              wrapMode: QQC.TextArea.NoWrap
              selectByMouse: true
              persistentSelection: true
              color: "transparent"
              selectionColor: Style.selectionFillFor(root.foreground, root.accentColor)
              font.family: root.fontFamily
              font.pixelSize: root.pixelSize
              padding: 0
              background: null
              cursorDelegate: Rectangle {
                width: 2
                height: editor.cursorRectangle.height
                color: root.accentColor
                visible: editor.activeFocus && editor.cursorVisible
              }
              onTextChanged: if (root.text !== text) root.text = text

              Keys.onPressed: function(event) {
                var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                var shift = (event.modifiers & Qt.ShiftModifier) !== 0
                if (ctrl && event.key === Qt.Key_Return) { root.submitted(); event.accepted = true; return }
                if (ctrl && event.key === Qt.Key_R) { root.runRequested(); event.accepted = true; return }
                if (ctrl && event.key === Qt.Key_S) { root.saveRequested(); event.accepted = true; return }
                if (ctrl && event.key === Qt.Key_Slash) { root.toggleLineComment(root.language.toLowerCase().indexOf("python") >= 0 ? "# " : "// "); event.accepted = true; return }
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
                if (!shift && pairs[key] !== undefined) {
                  root.insertAtCursor(key + pairs[key])
                  editor.cursorPosition -= 1
                  event.accepted = true
                }
              }
            }
          }
        }
      }
    }
  }

  // 组件首次出现时把外部内容同步进来
  Component.onCompleted: root.loadText(root.text)
}
