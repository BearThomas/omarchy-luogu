import QtQuick
import qs.Commons
import "Model.js" as Model

// Renders Luogu post / reply Markdown inside the panel.
//
// Layout is done block by block in QML rather than by feeding one HTML string to
// a single Text: block-level constructs (code boxes, tables, quotes, images)
// need real items, and QML's rich text cannot fetch remote <img> sources at all,
// while a plain Image element can. Inline formatting inside a block *is* rich
// text, produced by Model.inlineHtml.
//
// Known gap: there is no LaTeX engine here, so $math$ and $$math$$ are shown in
// tinted monospace instead of being typeset.
Column {
  id: root

  property string markdown: ""
  property var blocks: Model.markdownBlocks(markdown)
  property color foreground: Color.foreground
  property color accentColor: Color.accent
  property string fontFamily: Style.font.family
  property int basePixelSize: Style.font.bodySmall

  // A post can be 30 KB of Markdown (294 blocks in the wildest one sampled).
  // Everything here lives in an un-virtualised Column, so only the first slice
  // is built and the rest stays behind a button.
  property int blockLimit: 120
  property bool expanded: false
  readonly property var shownBlocks: expanded ? blocks : blocks.slice(0, blockLimit)
  readonly property int hiddenBlockCount: Math.max(0, blocks.length - blockLimit)

  readonly property color mutedColor: Qt.darker(foreground, 1.55)
  readonly property color codeFill: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.075)
  readonly property color tableHeaderFill: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.11)
  readonly property color ruleColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  readonly property string monoFamily: "monospace"

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  function hex(value) {
    function part(channel) {
      var scaled = Math.round(Math.max(0, Math.min(1, channel)) * 255).toString(16)
      return scaled.length === 1 ? "0" + scaled : scaled
    }
    return "#" + part(value.r) + part(value.g) + part(value.b)
  }

  function inline(text) {
    return Model.inlineHtml(text, { fg: hex(foreground), accent: hex(accentColor), muted: hex(mutedColor) })
  }

  function headingSize(level) {
    if (level <= 1) return Style.font.heading
    if (level === 2) return Style.font.title
    if (level === 3) return Style.font.subtitle
    return Style.font.body
  }

  function openLink(link) {
    if (link && link !== "") Qt.openUrlExternally(link)
  }

  Repeater {
    model: root.shownBlocks
    delegate: Loader {
      id: blockLoader
      required property var modelData
      width: root.width
      // 高度在加载完成后再绑定（见 onLoaded）。直接写 height: item.implicitHeight
      // 会在 item 仍在构建、内部 Repeater 还没生成委托时就被求值一次（此时
      // implicitHeight 为 0），随后又被改写，QML 会把它判定为 height 绑定环。
      height: 0
      sourceComponent: {
        switch (modelData.type) {
        case "heading": return componentHeading
        case "code": return componentCode
        case "list": return componentList
        case "quote": return componentQuote
        case "table": return componentTable
        case "image": return componentImage
        case "video": return componentVideo
        case "math": return componentMath
        case "hr": return componentRule
        default: return componentParagraph
        }
      }
      onLoaded: {
        item.block = modelData
        height = Qt.binding(function() { return item ? item.implicitHeight : 0 })
      }
    }
  }

  Rectangle {
    visible: root.hiddenBlockCount > 0 && !root.expanded
    width: root.width
    height: Style.space(30)
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
    Text {
      anchors.centerIn: parent
      text: "展开其余 " + root.hiddenBlockCount + " 段"
      color: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    MouseArea { anchors.fill: parent; onClicked: root.expanded = true }
  }

  Component {
    id: componentParagraph
    Text {
      property var block: ({})
      width: parent ? parent.width : 0
      text: root.inline(block.text || "")
      textFormat: Text.RichText
      wrapMode: Text.WordWrap
      color: root.foreground
      linkColor: root.accentColor
      font.family: root.fontFamily
      font.pixelSize: root.basePixelSize
      onLinkActivated: function(link) { root.openLink(link) }
    }
  }

  Component {
    id: componentHeading
    Column {
      property var block: ({})
      width: parent ? parent.width : 0
      spacing: Style.space(2)
      Item { width: 1; height: block.level && block.level <= 2 ? Style.space(6) : Style.space(3) }
      Text {
        width: parent.width
        text: root.inline(block.text || "")
        textFormat: Text.RichText
        wrapMode: Text.WordWrap
        color: block.level && block.level <= 2 ? Color.accent : root.foreground
        linkColor: root.accentColor
        font.family: root.fontFamily
        font.pixelSize: root.headingSize(block.level || 1)
        font.bold: true
        onLinkActivated: function(link) { root.openLink(link) }
      }
    }
  }

  Component {
    id: componentCode
    Column {
      property var block: ({})
      width: parent ? parent.width : 0
      spacing: Style.space(3)
      Text {
        visible: (block.lang || "") !== ""
        width: parent.width
        horizontalAlignment: Text.AlignRight
        text: block.lang || ""
        color: root.mutedColor
        font.family: root.monoFamily
        font.pixelSize: Style.font.caption
      }
      Rectangle {
        width: parent.width
        height: codeText.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: root.codeFill
        Text {
          id: codeText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          // Code keeps its own line breaks and may be arbitrarily wide, so it
          // wraps mid-token instead of being clipped or elided.
          text: block.text || ""
          textFormat: Text.PlainText
          wrapMode: Text.WrapAnywhere
          color: root.foreground
          font.family: root.monoFamily
          font.pixelSize: Math.max(Style.font.caption, root.basePixelSize - 1)
        }
      }
    }
  }

  Component {
    id: componentList
    Column {
      id: listColumn
      property var block: ({})
      width: parent ? parent.width : 0
      spacing: Style.space(4)
      Repeater {
        model: block.items || []
        delegate: Row {
          required property var modelData
          width: listColumn.width
          spacing: Style.space(6)
          Item { width: Style.space(Math.min(6, modelData.depth) * 14); height: 1 }
          Text {
            id: itemMarker
            text: modelData.ordered ? (modelData.number + ".") : "·"
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: root.basePixelSize
          }
          Text {
            width: parent.width - x
            text: root.inline(modelData.text || "")
            textFormat: Text.RichText
            wrapMode: Text.WordWrap
            color: root.foreground
            linkColor: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: root.basePixelSize
            onLinkActivated: function(link) { root.openLink(link) }
          }
        }
      }
    }
  }

  Component {
    id: componentQuote
    Row {
      property var block: ({})
      width: parent ? parent.width : 0
      spacing: Style.space(8)
      Rectangle {
        width: Math.max(2, Style.space(3))
        height: quoteText.height
        radius: width / 2
        color: root.accentColor
      }
      Text {
        id: quoteText
        width: parent.width - x
        text: root.inline(block.text || "")
        textFormat: Text.RichText
        wrapMode: Text.WordWrap
        color: root.mutedColor
        linkColor: root.accentColor
        font.family: root.fontFamily
        font.pixelSize: root.basePixelSize
        onLinkActivated: function(link) { root.openLink(link) }
      }
    }
  }

  Component {
    id: componentTable
    Column {
      id: tableColumn
      property var block: ({})
      readonly property int columnCount: Math.max(1, (block.header || []).length > 0
        ? (block.header || []).length
        : ((block.rows || []).length > 0 ? (block.rows[0] || []).length : 1))
      readonly property real gap: Style.space(6)
      readonly property real cellWidth: Math.max(Style.space(40),
        (width - gap * (columnCount - 1) - Style.space(12)) / columnCount)

      width: parent ? parent.width : 0
      spacing: Style.space(5)

      Item {
        width: parent.width
        height: headerRow.childrenRect.height + Style.space(10)
        visible: (block.header || []).length > 0
        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: root.tableHeaderFill
        }
        Row {
          id: headerRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)
          anchors.topMargin: Style.space(5)
          spacing: tableColumn.gap
          Repeater {
            model: block.header || []
            delegate: Text {
              required property var modelData
              required property int index
              width: tableColumn.cellWidth
              text: root.inline(modelData)
              textFormat: Text.RichText
              wrapMode: Text.WordWrap
              horizontalAlignment: (block.aligns && block.aligns[index] === "center") ? Text.AlignHCenter
                                 : (block.aligns && block.aligns[index] === "right") ? Text.AlignRight : Text.AlignLeft
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: root.basePixelSize
              font.bold: true
              onLinkActivated: function(link) { root.openLink(link) }
            }
          }
        }
      }

      Repeater {
        model: block.rows || []
        delegate: Item {
          required property var modelData
          width: tableColumn.width
          // childrenRect follows the laid-out cells, so the row background can
          // size itself to the tallest cell without a height binding loop.
          height: bodyRow.childrenRect.height + Style.space(10)
          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
          }
          Row {
            id: bodyRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            anchors.topMargin: Style.space(5)
            spacing: tableColumn.gap
            Repeater {
              model: modelData
              delegate: Text {
                required property var modelData
                required property int index
                width: tableColumn.cellWidth
                text: root.inline(modelData)
                textFormat: Text.RichText
                wrapMode: Text.WordWrap
                horizontalAlignment: (block.aligns && block.aligns[index] === "center") ? Text.AlignHCenter
                                   : (block.aligns && block.aligns[index] === "right") ? Text.AlignRight : Text.AlignLeft
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.basePixelSize
                onLinkActivated: function(link) { root.openLink(link) }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: componentImage
    Item {
      property var block: ({})
      readonly property real maxWidth: Math.min(parent ? parent.width : 0, Style.space(720))
      readonly property real ratio: (imageItem.implicitWidth > 0 && imageItem.implicitHeight > 0)
        ? (imageItem.implicitHeight / imageItem.implicitWidth) : 0.5625
      width: parent ? parent.width : 0
      implicitHeight: imageItem.height + (imageCaption.visible ? imageCaption.height + Style.space(4) : 0)

      Image {
        id: imageItem
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: parent.maxWidth
        height: Math.min(parent.maxWidth * parent.ratio, Style.space(420))
        // Decoded at 2x for crispness, but capped: sampled posts carry 3200x1800
        // screenshots and decoding those at full size is pointless here.
        sourceSize.width: Math.min(1400, Math.round(width * 2))
        source: block.url || ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        Rectangle {
          anchors.fill: parent
          visible: imageItem.status !== Image.Ready
          radius: Style.cornerRadius
          color: root.codeFill
          Text {
            anchors.centerIn: parent
            text: imageItem.status === Image.Error ? "图片加载失败" : "图片加载中…"
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        MouseArea {
          anchors.fill: parent
          onClicked: root.openLink(block.url || "")
        }
      }

      Text {
        id: imageCaption
        anchors.top: imageItem.bottom
        anchors.topMargin: Style.space(4)
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        visible: (block.alt || "") !== ""
        horizontalAlignment: Text.AlignHCenter
        text: block.alt || ""
        color: root.mutedColor
        wrapMode: Text.WordWrap
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Component {
    id: componentVideo
    Rectangle {
      property var block: ({})
      width: parent ? parent.width : 0
      height: Style.space(76)
      radius: Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
      border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
      border.width: 1
      Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(14)
        spacing: Style.space(3)
        Text { text: "Bilibili 视频"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: root.basePixelSize; font.bold: true }
        Text { text: block.bvid !== "" ? block.bvid : "题面内嵌视频"; color: root.mutedColor; font.family: root.monoFamily; font.pixelSize: Style.font.caption }
      }
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Style.space(14)
        width: Style.space(96); height: Style.space(32); radius: Style.cornerRadius
        color: videoOpen.containsMouse ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
        Text { anchors.centerIn: parent; text: "打开视频"; color: videoOpen.containsMouse ? Color.background : root.accentColor; font.family: root.fontFamily; font.pixelSize: root.basePixelSize }
        MouseArea { id: videoOpen; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openLink(block.url || "") }
      }
    }
  }

  Component {
    id: componentMath
    Rectangle {
      property var block: ({})
      width: parent ? parent.width : 0
      // 显式声明 implicitHeight：Rectangle 默认 implicitHeight 为 0，而 Loader
      // 是按 item.implicitHeight 排版的，只写 height 会让公式块被压成 0 高并叠到下一块上。
      implicitHeight: mathText.implicitHeight + Style.space(14)
      height: implicitHeight
      radius: Style.cornerRadius
      color: root.codeFill
      Text {
        id: mathText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        // 上边距固定为 padding 的一半（矩形高度 = 文本高度 + 2×padding），
        // 避免用 verticalCenter —— 那会读父级的 height，而父级高度又来自 Loader
        // 的 item.implicitHeight，构成 height 绑定环。
        anchors.topMargin: Style.space(7)
        horizontalAlignment: Text.AlignHCenter
        // 公式块同样走 LaTeX 转换器（原来是等宽显示原文）
        text: Model.latexToHtml(block.text || "")
        textFormat: Text.RichText
        wrapMode: Text.WrapAnywhere
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.basePixelSize
      }
    }
  }

  Component {
    id: componentRule
    Item {
      property var block: ({})
      width: parent ? parent.width : 0
      implicitHeight: Style.space(9)
      Rectangle {
        // implicitHeight 是这里的定值，直接用它算居中的 y，不去读父级 height。
        y: Math.round((parent.implicitHeight - height) / 2)
        width: parent.width
        height: 1
        color: root.ruleColor
      }
    }
  }
}
