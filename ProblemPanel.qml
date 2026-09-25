import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// 自包含的题目视图：自己取题面、自己管提交与评测轮询。
//
// 为什么单独做一份而不是复用「洛谷中心」里那个题库页：比赛窗口点题目时，如果
// 跳去题库页，就把那边的导航层级改掉了（返回回不到比赛），两个窗口还会抢同一份
// 状态。这里的所有状态都归自己，窗口关掉即销毁。
Column {
  id: root

  property string pid: ""
  property string uid: ""
  property string clientId: ""
  property string csrfToken: ""
  property var tagTable: ({ byId: {}, groups: [] })
  property color foreground: Color.foreground
  property color accentColor: Color.accent
  property string fontFamily: Style.font.family
  property string monoFamily: "monospace"
  // 来自插件设置：默认提交语言、Markdown 渲染上限
  property int defaultLanguageId: 28
  property int markdownBlockLimit: 120

  readonly property var languageIds: detail && Array.isArray(detail.acceptLanguages) ? detail.acceptLanguages : []
  readonly property var tagNames: Model.tagNames(detail ? detail.tags : [], tagTable)
  readonly property var languageOptions: {
    var names = []
    for (var i = 0; i < languageIds.length; i++) names.push(Model.languageName(languageIds[i]))
    return names
  }

  // 题库页已经自己取过一次题面，这里就别再发一遍：fetchDetail=false 时只接收
  // 外面传进来的 preloadedDetail。
  property bool fetchDetail: true
  property var preloadedDetail: null
  property var detail: null
  property bool loading: false
  property string tab: "statement"
  property int languageId: 0
  property string code: ""
  property bool enableO2: true
  property bool submitting: false
  property string submitStatus: ""
  property int rid: 0
  property var record: null
  property bool polling: false
  property string captchaImage: ""
  property bool captchaReady: false
  property string captchaCode: ""

  width: parent ? parent.width : 0
  spacing: Style.space(12)

  signal requestTagTable()

  onPidChanged: if (root.pid !== "" && root.fetchDetail) root.load()
  onPreloadedDetailChanged: root.adoptPreloaded()
  Component.onCompleted: root.adoptPreloaded()

  function adoptPreloaded() {
    if (root.fetchDetail) return
    var incoming = root.preloadedDetail
    if (!incoming || incoming.pid === "") {
      // 题库页切换题目时会先清空，这里跟着清，避免残留上一题
      root.detail = null
      root.code = ""
      root.record = null
      root.submitStatus = ""
      return
    }
    if (root.detail && root.detail.pid === incoming.pid) return
    root.applyDetail(incoming)
  }

  // 题面到位后统一处理：默认语言 + 预填上次的代码
  function applyDetail(parsed) {
    root.detail = parsed
    var ids = parsed.acceptLanguages || []
    var preferred = 0
    if (ids.indexOf(parsed.lastLanguage) >= 0) preferred = parsed.lastLanguage
    else if (ids.indexOf(root.defaultLanguageId) >= 0) preferred = root.defaultLanguageId
    else if (ids.indexOf(28) >= 0) preferred = 28
    else {
      for (var i = 0; i < ids.length; i++) { if (ids[i] !== 5) { preferred = ids[i]; break } }
      if (preferred === 0 && ids.length > 0) preferred = ids[0]
    }
    root.languageId = preferred
    root.code = parsed.lastCode
  }

  function load() {
    if (root.pid === "" || root.uid === "") return
    root.loading = true
    root.detail = null
    root.record = null
    root.rid = 0
    root.submitStatus = ""
    root.polling = false
    root.captchaImage = ""
    root.captchaReady = false
    root.captchaCode = ""
    recordTimer.stop()
    detailProc.command = ["sh", "-c", "curl -sS --max-time 25 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/problem/$3?_contentOnly=1\"", "luogu-pwindow-problem", uid, clientId, pid]
    detailProc.running = true
    root.requestTagTable()
  }

  // 比赛题的提交接口会先要验证码（实测 P17466 用非法语言也先回「验证码错误」），
  // 普通题不填也能过 —— 所以只有填了才把 captcha 放进请求体。
  function loadCaptcha() {
    if (captchaProc.running) return
    root.captchaReady = false
    root.captchaImage = ""
    root.captchaCode = ""
    // Referer 要和提交时一致（都是题目页）：验证码是按会话 + 来源页绑定的，
    // 用首页去取、用题目页去交，容易被判「验证码错误」。
    captchaProc.command = ["sh", "-c", "set -eu; out=$(mktemp); trap 'rm -f \"$out\"' EXIT; type=$(curl -sS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'Cache-Control: no-cache' -H 'X-Requested-With: XMLHttpRequest' -H \"Referer: https://www.luogu.com.cn/problem/$3\" -H \"Cookie: _uid=$1;__client_id=$2\" -o \"$out\" -w '%{content_type}' \"https://www.luogu.com.cn/api/verify/captcha?_t=$(date +%s%N)\"); data=$(base64 -w0 \"$out\"); jq -nc --arg type \"$type\" --arg data \"$data\" '{mime:$type,data:$data}'", "luogu-pwindow-captcha", uid, clientId, pid]
    captchaProc.running = true
  }

  function pickLanguage(name) {
    for (var i = 0; i < languageIds.length; i++) {
      if (Model.languageName(languageIds[i]) === name) { root.languageId = languageIds[i]; return }
    }
  }

  function submit() {
    if (root.code.trim() === "") { root.submitStatus = "代码不能为空"; return }
    // 实测：不管普通题还是比赛题，提交都要验证码（语言校验通过后就是验证码校验）
    if (root.captchaCode.trim() === "") { root.submitStatus = "请填写验证码（点图片可换一张）"; return }
    if (root.csrfToken === "") { root.submitStatus = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (root.languageId <= 0) { root.submitStatus = "请选择语言"; return }
    if (submitProc.running) return
    root.submitting = true
    root.submitStatus = "正在提交…"
    root.rid = 0
    root.record = null
    submitProc.pid = root.pid
    var body = { code: root.code, lang: root.languageId, enableO2: root.enableO2, captcha: root.captchaCode.trim() }
    submitProc.payloadBase64 = Model.utf8Base64(JSON.stringify(body))
    submitProc.running = true
  }

  Process {
    id: detailProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loading = false
        var parsed = Model.parseProblemDetail(String(text || ""))
        if (parsed.pid === "") { root.submitStatus = "题目读取失败，可能不存在或不可见"; return }
        root.applyDetail(parsed)
      }
    }
    onExited: function(exitCode) { root.loading = false }
  }

  // 走 stdin 传 base64：Quickshell 的 Process 没有关闭 stdin 的办法，curl 的
  // `--data-binary @-` 会一直等 EOF（详见 README 的交题一节）。
  Process {
    id: submitProc
    property string pid: ""
    property string payloadBase64: ""
    property bool succeeded: false
    property string errorMessage: ""
    stdinEnabled: true
    command: ["sh", "-c", "set -eu; IFS= read -r encoded; f=$(mktemp); trap 'rm -f \"$f\"' EXIT; printf '%s' \"$encoded\" | base64 -d > \"$f\"; curl -sS --max-time 30 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/problem/$3' -H \"X-CSRF-Token: $4\" -H 'Content-Type: application/json' -H \"Cookie: _uid=$1;__client_id=$2\" --data-binary @\"$f\" -w '|%{http_code}' \"https://www.luogu.com.cn/fe/api/problem/submit/$3\"", "luogu-pwindow-submit", uid, clientId, pid, csrfToken]
    onStarted: {
      write(payloadBase64 + "\n")
      payloadBase64 = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.splitHttpCode(text)
        submitProc.succeeded = Model.writeResponseSucceeded(parsed.body, parsed.code)
        submitProc.errorMessage = Model.writeFailureMessage(parsed.code, parsed.body)
        if (submitProc.succeeded) {
          var result = Model.parseSubmitResult(parsed.body)
          if (result.rid > 0) { root.submitting = true; root.poll(result.rid) }
          else { root.submitting = false; root.submitStatus = "已提交，但没解析出评测编号；去洛谷看结果吧" }
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "" && submitProc.errorMessage === "") submitProc.errorMessage = message.slice(0, 160)
      }
    }
    onExited: function(exitCode) {
      if (!succeeded) {
        root.submitting = false
        root.submitStatus = "提交失败：" + (errorMessage || "请稍后重试")
        // 验证码是一次性的：这次用掉了，下次要换一张
        if (String(errorMessage).indexOf("验证码") >= 0) { root.captchaImage = ""; root.captchaReady = false; root.loadCaptcha() }
      }
    }
  }

  Process {
    id: captchaProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(String(text || ""))
          var data = String(result.data || "")
          var mime = String(result.mime || "image/jpeg")
          if (data === "") throw new Error("empty")
          root.captchaImage = "data:" + mime + ";base64," + data
          root.captchaReady = true
        } catch (error) {
          root.captchaImage = ""
          root.captchaReady = false
        }
      }
    }
    onExited: function(exitCode) { if (exitCode !== 0) { root.captchaImage = ""; root.captchaReady = false } }
  }

  Process {
    id: recordProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseRecord(String(text || ""))
        if (parsed.rid <= 0) return
        root.record = parsed
        if (Model.isPendingVerdict(parsed.status)) {
          root.submitStatus = "评测中… " + parsed.finishedCaseCount + " / " + parsed.testcaseCount
        } else {
          root.polling = false
          recordTimer.stop()
          root.submitting = false
          root.submitStatus = "评测完成"
        }
      }
    }
  }

  Timer {
    id: recordTimer
    interval: 1500
    repeat: true
    onTriggered: {
      if (!root.polling || root.rid <= 0) { stop(); return }
      if (recordProc.running) return
      recordProc.command = ["sh", "-c", "curl -sS --max-time 20 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/record/$3?_contentOnly=1\"", "luogu-pwindow-record", uid, clientId, String(root.rid)]
      recordProc.running = true
    }
  }

  function poll(rid) {
    if (rid <= 0) return
    root.rid = rid
    root.polling = true
    root.submitStatus = "已提交，等待评测…"
    recordTimer.restart()
    recordTimer.triggered()
  }

  Text {
    visible: root.loading
    text: "正在读取题目…"
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Row {
    width: parent.width
    spacing: Style.space(10)
    Rectangle {
      width: Style.space(56)
      height: Style.space(22)
      radius: Style.space(4)
      color: root.detail ? Model.difficultyColor(root.detail.difficulty) : "transparent"
      Text {
        anchors.centerIn: parent
        text: root.detail ? Model.difficultyName(root.detail.difficulty) : ""
        color: Color.background
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    Text {
      width: parent.width - Style.space(66)
      text: root.detail ? (root.detail.pid + "  " + root.detail.name) : root.pid
      wrapMode: Text.WordWrap
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
      font.bold: true
    }
  }

  Text {
    width: parent.width
    visible: root.detail !== null
    text: root.detail
      ? ((root.detail.timeLimit > 0 ? root.detail.timeLimit + "ms / " + Math.round(root.detail.memoryLimit / 1024) + "MB" : "")
         + (root.tagNames.length > 0 ? "    " + root.tagNames.join(" · ") : "")
         + (root.detail.accepted ? "    已通过" : (root.detail.submitted ? "    尝试过" : "    未做过")))
      : ""
    wrapMode: Text.WordWrap
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Row {
    width: parent.width
    spacing: Style.space(8)
    Repeater {
      model: [{ key: "statement", label: "题面" }, { key: "submit", label: "提交代码" }]
      delegate: Rectangle {
        required property var modelData
        width: Style.space(92)
        height: Style.space(28)
        radius: Style.cornerRadius
        color: root.tab === modelData.key ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        Text {
          anchors.centerIn: parent
          text: modelData.label
          color: root.tab === modelData.key ? Color.background : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.tab = modelData.key
            if (modelData.key === "submit" && root.captchaImage === "" && !captchaProc.running) root.loadCaptcha()
          }
        }
      }
    }
  }

  MarkdownView {
    visible: root.tab === "statement" && !root.loading
    width: parent.width
    blockLimit: root.markdownBlockLimit
    markdown: root.detail ? Model.problemStatementMarkdown(root.detail) : ""
    foreground: root.foreground
    accentColor: root.accentColor
    fontFamily: root.fontFamily
    basePixelSize: Style.font.bodySmall
  }

  Column {
    visible: root.tab === "submit"
    width: parent.width
    spacing: Style.space(8)

    Row {
      width: parent.width
      spacing: Style.space(10)
      Dropdown {
        width: Style.space(210)
        label: "语言"
        options: root.languageOptions
        value: Model.languageName(root.languageId)
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(newValue) { root.pickLanguage(newValue) }
      }
      Toggle {
        width: Style.space(150)
        label: "O2 优化"
        checked: root.enableO2
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.enableO2 = !root.enableO2
      }
      Rectangle {
        readonly property bool ready: root.code.trim() !== "" && !root.submitting
        width: Style.space(92)
        height: Style.space(34)
        radius: Style.cornerRadius
        color: ready ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
        Text {
          anchors.centerIn: parent
          text: root.submitting ? "评测中…" : "提交"
          color: parent.ready ? Color.background : Qt.darker(root.foreground, 1.3)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(8)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "验证码"
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Rectangle {
        width: Style.space(120)
        height: Style.space(42)
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
        Image {
          anchors.fill: parent
          anchors.margins: Style.space(3)
          fillMode: Image.PreserveAspectFit
          source: root.captchaImage
          cache: false
        }
        Text {
          anchors.centerIn: parent
          visible: root.captchaImage === ""
          text: captchaProc.running ? "读取中…" : "点此获取"
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadCaptcha() }
      }
      TextField {
        width: Style.space(140)
        placeholderText: "验证码"
        text: root.captchaCode
        foreground: root.foreground
        font.family: root.fontFamily
        onTextChanged: root.captchaCode = text
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(300)
        text: "每次提交都需要验证码（点图片可换一张）"
        color: Qt.darker(root.foreground, 1.6)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    // 代码可能很长，TextArea 自己不会滚动，套一层 Flickable。
    Flickable {
      width: parent.width
      height: Style.space(260)
      clip: true
      contentWidth: width
      contentHeight: codeArea.contentHeight + Style.space(16)
      boundsBehavior: Flickable.StopAtBounds

      QQC.TextArea {
        id: codeArea
        width: parent.width
        placeholderText: "在这里写代码（上次提交的代码会自动填进来）"
        wrapMode: QQC.TextArea.WrapAnywhere
        selectByMouse: true
        text: root.code
        color: root.foreground
        placeholderTextColor: Qt.darker(root.foreground, 1.6)
        selectionColor: Style.selectionFillFor(root.foreground, Color.accent)
        selectedTextColor: root.foreground
        font.family: root.monoFamily
        font.pixelSize: Style.font.bodySmall
        readonly property var borderSpec: Border.controlSpec(codeArea.activeFocus ? "focus" : "normal", root.foreground, Color.accent)
        leftPadding: Style.spacing.controlPaddingX + Border.left(borderSpec)
        rightPadding: Style.spacing.controlPaddingX + Border.right(borderSpec)
        topPadding: Style.spacing.inputPaddingY + Border.top(borderSpec)
        bottomPadding: Style.spacing.inputPaddingY + Border.bottom(borderSpec)
        background: BorderSurface {
          color: Style.controlFill(codeArea.activeFocus, false, root.foreground, Color.accent)
          borderSpec: codeArea.borderSpec
          radius: Style.cornerRadius
        }
        onTextChanged: root.code = text
      }
    }

    Rectangle {
      visible: root.submitStatus !== "" || root.record !== null
      width: parent.width
      height: verdictBody.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)

      Column {
        id: verdictBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        Row {
          width: parent.width
          spacing: Style.space(8)
          Text {
            visible: root.record !== null
            text: root.record ? Model.verdictShort(root.record.status) : ""
            color: root.record ? Model.verdictColor(root.record.status) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
          Text {
            width: parent.width - Style.space(72)
            text: root.submitStatus + (root.rid > 0 ? "   #" + root.rid : "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Text {
          width: parent.width
          visible: root.record !== null
          text: root.record
            ? (Model.verdictName(root.record.status) + " · " + root.record.score + " 分 · "
               + root.record.time + "ms · " + root.record.memory + "KB · "
               + Model.languageName(root.record.language) + (root.record.enableO2 ? " (O2)" : ""))
            : ""
          wrapMode: Text.WordWrap
          color: Qt.darker(root.foreground, 1.45)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          width: parent.width
          visible: root.record !== null && !root.record.compileSuccess
          text: root.record ? ("编译错误：" + root.record.compileMessage) : ""
          wrapMode: Text.WordWrap
          color: Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.record ? root.record.subtasks : []
          delegate: Column {
            required property var modelData
            width: verdictBody.width
            spacing: Style.space(4)
            Text {
              width: parent.width
              text: "子任务 " + modelData.id + "   " + Model.verdictShort(modelData.status) + "   " + modelData.score + " 分   " + modelData.time + "ms · " + modelData.memory + "KB"
              color: Model.verdictColor(modelData.status)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Flow {
              width: parent.width
              spacing: Style.space(4)
              Repeater {
                model: modelData.testCases
                delegate: Rectangle {
                  required property var modelData
                  width: Style.space(58)
                  height: Style.space(18)
                  radius: Style.space(3)
                  color: Model.verdictColor(modelData.status)
                  Text {
                    anchors.centerIn: parent
                    text: "#" + modelData.id + " " + Model.verdictShort(modelData.status)
                    color: Color.background
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
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
