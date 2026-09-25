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
  property string tab: "split"
  property int languageId: 0
  property string code: ""
  property bool enableO2: true
  property bool submitting: false
  property string submitStatus: ""
  property int rid: 0
  property var record: null
  property bool polling: false
  // 本地跑样例（不联网、不产生提交记录）
  // tab：split = 并排 / statement = 只题面 / submit = 只代码。
  // 并排需要 ≥880px：题库页在侧边栏右侧只有 700 多像素，硬分栏会把题面挤成一条。
  readonly property bool canSplit: width >= Style.space(880)
  readonly property bool splitLayout: tab === "split" && canSplit
  // 窄面板放不下并排时：默认看题面，只有明确选了"提交代码"才切到代码
  readonly property bool statementVisible: splitLayout || tab !== "submit"
  readonly property bool codeVisible: splitLayout || tab === "submit"

  // 视图切换：并排需要宽度，窄了就落到代码视图
  function selectTab(key) {
    var wanted = key
    if (key === "split" && !canSplit) {
      // 不要静默忽略：明确告诉用户是宽度不够，并把他导向"看题面"
      root.submitStatus = "面板太窄：把窗口拉宽即可使用「并排」（需要 880px 以上）"
      wanted = "statement"
    }
    root.tab = wanted
    if (wanted === "submit" && root.captchaImage === "" && !captchaProc.running) root.loadCaptcha()
  }
  property var sampleRun: null
  property bool sampleRunning: false
  property string sampleStatus: ""
  // 高亮配色按主题明暗切换（VSCode 的暗/亮两套）
  readonly property bool isDarkTheme: {
    var background = Color.background
    return (0.299 * background.r + 0.587 * background.g + 0.114 * background.b) < 0.5
  }
  // 用外部 nvim 编辑：写临时文件 → 开终端跑 nvim → FileView 监听文件变化同步回来
  property string externalPath: ""
  property string nvimStatus: ""
  readonly property string runnerPath: String(Qt.resolvedUrl("run-samples.sh")).replace("file://", "")
  property string captchaImage: ""
  property bool captchaReady: false
  property string captchaCode: ""

  width: parent ? parent.width : 0
  spacing: Style.space(12)

  signal requestTagTable()

  onPidChanged: if (root.pid !== "" && root.fetchDetail) root.load()
  onTabChanged: if (root.tab === "submit" && root.captchaImage === "" && !captchaProc.running) root.loadCaptcha()
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
    if (root.tab === "submit" && root.captchaImage === "" && !captchaProc.running) root.loadCaptcha()
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

  function sourceExtension() {
    var name = Model.languageName(root.languageId)
    if (/python|pypy/i.test(name)) return ".py"
    if (/java/i.test(name)) return ".java"
    if (/node|javascript/i.test(name)) return ".js"
    if (/rust/i.test(name)) return ".rs"
    if (/go$/i.test(name)) return ".go"
    if (/pascal/i.test(name)) return ".pas"
    if (name === "C") return ".c"
    return ".cpp"
  }

  // 写文件 → 等写完再启动终端（FileView 无法监听尚不存在的文件）
  function openInNvim() {
    if (root.code.trim() === "") { root.nvimStatus = "代码不能为空"; return }
    root.nvimStatus = "正在写入临时文件…"
    var path = "/tmp/luogu-edit/" + (root.pid === "" ? "scratch" : root.pid) + root.sourceExtension()
    root.externalPath = ""
    nvimWriteProc.payloadBase64 = Model.utf8Base64(JSON.stringify({ path: path, code: root.code }))
    nvimWriteProc.running = true
  }

  // 本地编译 + 用样例输入运行 + 与期望输出比对。整个流程不碰洛谷。
  function runSamples() {
    if (root.sampleRunning) return
    if (root.code.trim() === "") { root.sampleStatus = "代码不能为空"; return }
    var samples = root.detail && Array.isArray(root.detail.samples) ? root.detail.samples : []
    if (samples.length === 0) { root.sampleStatus = "这道题没有样例数据"; return }
    root.sampleRunning = true
    root.sampleRun = null
    root.sampleStatus = "正在编译并运行样例…"
    runProc.payloadBase64 = Model.utf8Base64(JSON.stringify({
      language: Model.languageName(root.languageId),
      code: root.code,
      timeLimitMs: root.detail && root.detail.timeLimit > 0 ? root.detail.timeLimit : 1000,
      samples: samples.map(function(item) { return { input: item.input, output: item.output } })
    }))
    runProc.running = true
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

  // 外部编辑器：先落盘（避免 FileView 监听不到还不存在的文件），再开终端
  Process {
    id: nvimWriteProc
    property string payloadBase64: ""
    property string targetPath: ""
    stdinEnabled: true
    command: ["sh", "-c", "set -eu; IFS= read -r encoded; f=$(mktemp); trap 'rm -f \"$f\"' EXIT; printf '%s' \"$encoded\" | base64 -d > \"$f\"; p=$(jq -r .path \"$f\"); mkdir -p \"$(dirname \"$p\")\"; jq -r .code \"$f\" > \"$p\"; printf '%s' \"$p\"", "luogu-nvim-write"]
    onStarted: {
      write(payloadBase64 + "\n")
      payloadBase64 = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { nvimWriteProc.targetPath = String(text || "").trim() }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 || nvimWriteProc.targetPath === "") {
        root.nvimStatus = "写入临时文件失败"
        return
      }
      root.externalPath = nvimWriteProc.targetPath
      root.nvimStatus = "已在 nvim 中打开；保存后自动同步回这里"
      nvimLaunchProc.command = ["omarchy-launch-terminal", "nvim", root.externalPath]
      nvimLaunchProc.running = true
    }
  }

  Process {
    id: nvimLaunchProc
    onExited: function(exitCode) {
      if (exitCode !== 0) root.nvimStatus = "启动 nvim 失败（omarchy-launch-terminal 退出码 " + exitCode + "）"
    }
  }

  // 监听外部编辑器的保存
  FileView {
    id: nvimFile
    path: root.externalPath
    watchChanges: true
    printErrors: false
    onFileChanged: {
      var content = nvimFile.text()
      if (content !== undefined && content !== null && content !== root.code) {
        root.code = content
        root.nvimStatus = "已从 nvim 同步（" + content.length + " 字）"
      }
    }
  }

  // 样例运行器：一行 base64(JSON) 进 stdin，脚本返回 JSON 结果
  Process {
    id: runProc
    property string payloadBase64: ""
    stdinEnabled: true
    command: ["sh", root.runnerPath]
    onStarted: {
      write(payloadBase64 + "\n")
      payloadBase64 = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.sampleRun = JSON.parse(String(text || ""))
          var results = root.sampleRun.results || []
          var passed = 0
          var verdict = "全部通过"
          for (var i = 0; i < results.length; i++) {
            if (results[i].status === "AC") passed++
            else verdict = "有未通过"
          }
          if (root.sampleRun.compile && root.sampleRun.compile.ok === false) verdict = "编译失败"
          root.sampleStatus = verdict + "（" + passed + " / " + results.length + "）"
        } catch (error) {
          root.sampleRun = null
          root.sampleStatus = "运行器返回异常：" + String(error)
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.sampleStatus = "运行器出错：" + message.slice(0, 160)
      }
    }
    onExited: function(exitCode) { root.sampleRunning = false }
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
      // 「NOI/NOI+/CTSC」这种长名字要放得下，所以宽度跟着文字走
      id: difficultyChip
      width: Math.max(Style.space(48), difficultyLabel.implicitWidth + Style.space(12))
      height: Style.space(22)
      radius: Style.space(4)
      color: root.detail ? Model.difficultyColor(root.detail.difficulty) : "transparent"
      Text {
        id: difficultyLabel
        anchors.centerIn: parent
        text: root.detail ? Model.difficultyName(root.detail.difficulty) : ""
        color: Color.background
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    Text {
      width: parent.width - difficultyChip.width - Style.space(10)
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

  // 视图切换：并排 / 只题面 / 只代码。"并排"需要 ≥880px —— 洛谷中心的题库页只有
  // 700 多像素，会自动禁用并排。题面与代码各只有一份，宽度按模式分配。
  Row {
    width: parent.width
    spacing: Style.space(8)
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "视图"
      color: Qt.darker(root.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    Repeater {
      model: [{ key: "split", label: "并排" }, { key: "statement", label: "题面" }, { key: "submit", label: "提交代码" }]
      delegate: Rectangle {
        required property var modelData
        readonly property bool blocked: modelData.key === "split" && !root.canSplit
        width: Style.space(modelData.key === "submit" ? 92 : 72)
        height: Style.space(26)
        radius: Style.cornerRadius
        opacity: blocked ? 0.45 : 1
        color: root.tab === modelData.key && !blocked ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        Text {
          anchors.centerIn: parent
          text: modelData.label
          color: root.tab === modelData.key && !parent.blocked ? Color.background : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.selectTab(modelData.key)
        }
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(Style.space(60), parent.width - Style.space(320))
      elide: Text.ElideRight
      text: root.splitLayout
        ? "左题面 · 右代码 · 右下样例"
        : (root.canSplit
            ? "Ctrl+Enter 提交 · Ctrl+R 跑样例 · Ctrl+/ 注释"
            : "面板太窄：把窗口拉宽就能用「并排」（需要 880px 以上）")
      color: Qt.darker(root.foreground, 1.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(12)

    Column {
      id: statementPane
      visible: root.statementVisible
      width: root.splitLayout ? (parent.width - Style.space(12)) * 0.44 : parent.width
      height: root.splitLayout ? Style.space(620) : implicitHeight
      spacing: Style.space(4)
      Text {
        text: "题面"
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Flickable {
        id: statementPaneFlick
        // 和外层窗口一致的滚轮调优：Omarchy 的 touchpad scroll_factor 是 0.4，
        // 不乘回来会比系统里其它地方明显更慢
        property int wheelStep: 140
        property real wheelPixelFactor: 3.2
        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            var step = event.pixelDelta.y !== 0
              ? event.pixelDelta.y * statementPaneFlick.wheelPixelFactor
              : event.angleDelta.y / 120 * Style.space(statementPaneFlick.wheelStep)
            if (step === 0) return
            var limit = Math.max(0, statementPaneFlick.contentHeight - statementPaneFlick.height)
            statementPaneFlick.contentY = Math.max(0, Math.min(limit, statementPaneFlick.contentY - step))
          }
        }
        width: parent.width
        height: root.splitLayout ? (parent.height - Style.space(18)) : Math.min(Style.space(4000), statementView.implicitHeight + Style.space(6))
        clip: root.splitLayout
        contentWidth: width
        contentHeight: statementView.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

              MarkdownView {
        id: statementView
        width: parent.width
        blockLimit: root.markdownBlockLimit
        markdown: root.detail ? Model.problemStatementMarkdown(root.detail) : ""
        foreground: root.foreground
        accentColor: root.accentColor
        fontFamily: root.fontFamily
        basePixelSize: Style.font.bodySmall
              }
      }
    }


        Column {
          id: codePane
          visible: root.codeVisible
          width: root.splitLayout ? parent.width - (parent.width - Style.space(12)) * 0.44 - Style.space(12) : parent.width
          height: root.splitLayout ? Style.space(620) : implicitHeight
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
            Rectangle {
              readonly property bool ready: !root.sampleRunning && root.code.trim() !== ""
              width: Style.space(104)
              height: Style.space(34)
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              Text {
                anchors.centerIn: parent
                text: root.sampleRunning ? "运行中…" : "本地跑样例"
                color: parent.ready ? root.foreground : Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runSamples() }
            }
            Rectangle {
              width: Style.space(96)
              height: Style.space(34)
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              Text { anchors.centerIn: parent; text: "用 nvim"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openInNvim() }
            }
            Text {
              // 210+150+92+104+96 = 652，再加 5 个间距；原式漏了"用 nvim"那 96px，整行会溢出
        width: Math.max(Style.space(60), parent.width - Style.space(652) - Style.space(50))
        visible: parent.width > Style.space(760)
              anchors.verticalCenter: parent.verticalCenter
              text: "Ctrl+Enter 提交 · Ctrl+R 跑样例 · Ctrl+/ 注释"
              elide: Text.ElideRight
              color: Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
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

          // 样例结果：本地跑出来的判定（不联网、不产生提交记录）
          Rectangle {
            visible: root.sampleStatus !== "" || root.sampleRun !== null
            width: parent.width
            height: sampleBody.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)

            Column {
              id: sampleBody
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(10)
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: root.sampleStatus
                color: {
                  if (root.sampleRun === null) return root.foreground
                  if (root.sampleRun.compile && root.sampleRun.compile.ok === false) return Color.urgent
                  var results = root.sampleRun.results || []
                  for (var i = 0; i < results.length; i++) if (results[i].status !== "AC") return Color.urgent
                  return Color.accent
                }
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Text {
                width: parent.width
                visible: root.sampleRun !== null && root.sampleRun.compile && root.sampleRun.compile.ok === false && root.sampleRun.compile.message !== ""
                text: root.sampleRun && root.sampleRun.compile ? root.sampleRun.compile.message : ""
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 8
                elide: Text.ElideRight
                color: Color.urgent
                font.family: "monospace"
                font.pixelSize: Style.font.caption
              }

              Repeater {
                model: root.sampleRun ? (root.sampleRun.results || []) : []
                delegate: Column {
                  required property var modelData
                  width: sampleBody.width
                  spacing: Style.space(4)
                  Text {
                    width: parent.width
                    text: "样例 " + modelData.index + "   " + modelData.status + "   " + modelData.timeMs + "ms"
                    color: modelData.status === "AC" ? Color.accent : Color.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: modelData.status === "WA"
                    Column {
                      width: (parent.width - Style.space(8)) / 2
                      spacing: 2
                      Text { text: "期望输出"; color: Qt.darker(root.foreground, 1.5); font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                      Text { width: parent.width; text: modelData.expected; wrapMode: Text.WrapAnywhere; maximumLineCount: 6; elide: Text.ElideRight; color: root.foreground; font.family: "monospace"; font.pixelSize: Style.font.caption }
                    }
                    Column {
                      width: (parent.width - Style.space(8)) / 2
                      spacing: 2
                      Text { text: "实际输出"; color: Qt.darker(root.foreground, 1.5); font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                      Text { width: parent.width; text: modelData.stdout === "" ? "(空)" : modelData.stdout; wrapMode: Text.WrapAnywhere; maximumLineCount: 6; elide: Text.ElideRight; color: root.foreground; font.family: "monospace"; font.pixelSize: Style.font.caption }
                    }
                  }
                  Text {
                    width: parent.width
                    visible: modelData.status === "RE" && modelData.stderr !== ""
                    text: modelData.stderr
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: Color.urgent
                    font.family: "monospace"
                    font.pixelSize: Style.font.caption
                  }
                  Text {
                    width: parent.width
                    visible: modelData.status === "TLE"
                    text: "超出时限（本地按 " + (root.detail && root.detail.timeLimit > 0 ? root.detail.timeLimit : 1000) + "ms + 2s 宽限）"
                    color: Color.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }

          Text {
            width: parent.width
            visible: root.nvimStatus !== ""
            elide: Text.ElideRight
            text: root.nvimStatus + (root.externalPath !== "" ? "   " + root.externalPath : "")
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          // 代码编辑：CodeEditor（行号 + 语法高亮 + 自动缩进/括号补全）。
          // 快捷键：Ctrl+Enter 提交、Ctrl+R 跑样例、Ctrl+/ 注释。
          CodeEditor {
            id: codeEditor
            width: parent.width
            height: Style.space(340)
            text: root.code
            language: Model.languageName(root.languageId)
            foreground: root.foreground
            accentColor: Color.accent
            fontFamily: root.monoFamily
            dark: root.isDarkTheme
            onTextChanged: root.code = text
            onSubmitted: root.submit()
            onRunRequested: root.runSamples()
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


  }
