import QtQuick
// Aliased so the kit's styled TextField from qs.Ui keeps winning the plain
// `TextField` name; only the multi-line editor is taken from Controls.
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "bearthomas.luogu"
  ipcTarget: "bearthomas.luogu"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  property string uid: ""
  property string clientId: ""
  property string statusText: "未登录"
  property bool loading: false
  property var profile: Model.parseProfile(null)
  property string loginMode: "cookie"
  property string loginUsername: ""
  property string loginPassword: ""
  property string loginCaptcha: ""
  property string captchaImage: ""
  property string loginCsrfToken: ""
  property var contests: []
  property bool contestLoading: false
  property string contestView: "list"
  property bool contestDetailOpen: false
  property bool problemWindowOpen: false
  property string problemWindowPid: ""
  property int contestPage: 1
  property int contestCount: 0
  property var contestDetail: null
  property bool contestDetailLoading: false
  property var notifications: []
  property var messages: []
  property var feedItems: []
  property var ownFeedItems: []
  property string feedMode: "watching"
  property bool ownFeedLoading: false
  property bool feedMoreLoading: false
  property bool feedHasMore: true
  property bool ownFeedHasMore: true
  property int feedPage: 1
  property int ownFeedPage: 1
  property var postItems: []
  property int unreadNotifications: 0
  property int unreadMessages: 0
  property bool activityLoading: false
  property bool credentialsReady: false
  property int credentialReadsPending: 0
  property bool detailOpen: false
  property string detailPage: "overview"
  property string detailTargetWorkspace: ""
  property string actionStatusText: ""
  property string csrfToken: ""
  property string benbenDraft: ""
  property bool benbenEditorOpen: false
  property string chatDraft: ""
  property var tagTable: ({ byId: {}, groups: [] })
  property var accountSecurity: null
  property var accountPrizes: null
  property var accountBindings: null
  property bool accountLoading: false
  property int accountPending: 0
  property string userSpaceSlogan: ""
  property string userSpaceIntro: ""
  property string userSpaceBackground: ""
  property bool userSpaceSaving: false
  property string userSpaceStatus: ""
  // 云剪贴板（读；写接口尚未探到，见 README）
  property var pasteItems: []
  property int pasteCount: 0
  property int pastePage: 1
  property bool pasteLoading: false
  property bool pasteHasMore: true
  property var pasteDetail: null
  property string pasteDetailId: ""
  property bool pasteDetailLoading: false
  // 云剪贴板的写操作：新建/编辑都要图形验证码（GET /lg4/captcha）
  property bool pasteComposerOpen: false
  property string pasteComposerMode: "create"
  property string pasteDraftData: ""
  property bool pasteDraftPublic: false
  property string pasteCaptchaImage: ""
  property bool pasteCaptchaReady: false
  property string pasteCaptchaCode: ""
  property bool pasteSaving: false
  property string pasteWriteStatus: ""
  property bool pasteDeleteConfirm: false
  property bool tagTableLoading: false
  property string problemView: "list"
  property var problemList: []
  property int problemCount: 0
  property int problemPage: 1
  property bool problemListLoading: false
  property string problemKeyword: ""
  property string problemDifficultyName: "全部"
  property string problemTagName: "全部标签"
  property string problemOrderName: "默认"
  property var problemDetail: null
  property string problemDetailPid: ""
  property bool problemDetailLoading: false
  property var solutionList: []
  property int solutionCount: 0
  property bool solutionLoading: false
  property var solutionArticle: null
  property bool articleLoading: false
  property var problemPosts: []
  property int problemPostCount: 0
  property int problemPostPage: 1
  property bool problemPostsLoading: false
  property string threadId: ""
  property var threadPost: null
  property var threadReplies: []
  property bool threadLoading: false
  property int threadPage: 1
  property var postDetail: null
  property string postDetailId: ""
  property bool postDetailLoading: false
  property var postReplies: []
  property int postReplyPage: 1
  property var chatSessions: []
  property var chatMessages: []
  property string chatSelectedUid: ""
  property string chatSelectedName: ""
  property string chatSelectedColor: ""
  property bool chatLoading: false
  property string chatSearchKeyword: ""
  property var chatSearchResults: []
  property bool chatSearching: false
  property string chatSearchQueried: ""
  property string postTitleDraft: ""
  property bool postEditorOpen: false
  // Luogu identifies a board by its slug: 学术版 is "academics". The old "P"
  // matched no board (the read API returns an empty forum name for it).
  property string postForumDraft: "academics"
  property var postForums: Model.parseForums(null)
  property bool forumsProbed: false
  property string postCaptchaDraft: ""
  property string postCaptchaImage: ""
  property bool postCaptchaReady: false
  property string postContentDraft: ""
  property string problemPostTitleDraft: ""
  property string problemPostContentDraft: ""
  property string problemPostCaptchaDraft: ""
  property bool problemDiscussionEditorOpen: false
  property string replyCaptchaImage: ""
  property bool replyCaptchaReady: false
  property string replyPostId: ""
  property string replyCaptcha: ""
  property string replyDraft: ""
  property int heatmapHoverIndex: -1
  property real heatmapHoverX: 0
  property real heatmapHoverY: 0

  // Credentials used to be read only from open(), so right after a shell restart
  // the unread badge stayed empty and the 详细信息 window refused to open (it
  // needs profile.uid) until the popout had been opened once. Load them up front.
  Component.onCompleted: {
    loadCredentials()
    loadProblemDrafts()
  }

  function open() {
    root.controller.show()
    if (uid === "" || clientId === "") {
      credentialsReady = false
      statusText = "正在恢复登录状态…"
      loadCredentials()
    } else {
      credentialsReady = true
      refresh()
    }
    if (credentialsReady && uid === "" && clientId === "" && loginMode === "password" && !captchaProc.running) requestCaptcha()
  }

  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function openDetails() {
    if (profile.uid > 0) {
      var workspace = Hyprland.focusedWorkspace
      detailTargetWorkspace = workspace && workspace.id > 0 ? String(workspace.id) : ""
      detailPage = "overview"
      // The detail view is a separate desktop window. Close the anchored
      // KeyboardPanel first so the two surfaces do not cover each other.
      root.controller.hide()
      // Just flip the flag: detailLoader below builds the window for this open.
      // Never keep one FloatingWindow around and toggle its visibility — see the
      // comment on the loader for why that only works once per shell session.
      detailOpen = true
    }
  }
  function closeDetails() {
    detailOpen = false
    detailPlacementTimer.stop()
  }

  // Placement runs on a repeat timer instead of a single shot because a new
  // toplevel is not mapped yet on the first tick, and Hyprland tiles it before
  // it settles into floating (observed: floating 980x740 at ~400 ms, tiled
  // 482x950 at ~500 ms, floating again from ~600 ms on).
  //
  // `float({ action = "on" })` — NOT "set". In the Lua dispatch API "set" is a
  // toggle: two "set" calls leave the window tiled again, and an unknown action
  // returns "ok" and toggles as well. "on"/"enable" are the idempotent
  // force-float forms, which is what a repeating timer needs.
  //
  // `center` also runs on every tick from the second on, not once: centering is
  // computed from the width the compositor knows at that instant, so a single
  // early call uses the tiled width (482) and parks the window at x=518 instead
  // of x=260 — off toward the right edge. Repeating it means the last call is
  // always made with settled geometry, whichever tick that turns out to be.
  //
  // `move` and `focus` stay single-shot: repeating focus would yank keyboard
  // focus back for up to a second if the user clicks elsewhere right after
  // opening, and repeating the workspace move would fight a manual move.
  //
  // Quickshell 0.3.1 has no `Hyprland.clients`, so the compositor's own view of
  // the window cannot be polled from here — hence convergence instead of a
  // read-back. `float`/`move`/`resize` answer "ok" even when nothing matches and
  // log nothing; `center`/`focus` do log a failed dispatch, which is why they
  // wait for the second tick, when the toplevel exists. That keeps a normal open
  // warning-free in the journal.
  Timer {
    id: detailPlacementTimer
    interval: 250
    repeat: true
    property int attempts: 0
    onTriggered: {
      if (!root.detailOpen) { stop(); return }
      attempts++
      var windowSelector = 'title:^(洛谷中心)$'
      if (attempts === 1 && root.detailTargetWorkspace !== "")
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + root.detailTargetWorkspace + '", window = "' + windowSelector + '", follow = false })')
      Hyprland.dispatch('hl.dsp.window.float({ action = "on", window = "' + windowSelector + '" })')
      Hyprland.dispatch('hl.dsp.window.resize({ x = 980, y = 740, relative = false, window = "' + windowSelector + '" })')
      if (attempts >= 2) {
        Hyprland.dispatch('hl.dsp.window.center({ window = "' + windowSelector + '" })')
        if (attempts === 2) Hyprland.dispatch('hl.dsp.focus({ window = "' + windowSelector + '" })')
      }
      if (attempts >= 6) stop()
    }
  }

  // Debounce for the 私信 user search so typing a name fires one request instead
  // of one per keystroke.
  Timer {
    id: chatSearchTimer
    interval: 350
    repeat: false
    onTriggered: root.searchUsers()
  }
  onDetailOpenChanged: {
    detailPlacementTimer.attempts = 0
    if (detailOpen) {
      detailPlacementTimer.restart()
      ensurePostCaptcha()
    } else {
      detailPlacementTimer.stop()
      forumsProbed = false
    }
  }
  function openNotifications() { Qt.openUrlExternally("https://www.luogu.com.cn/user/notification") }
  function openMessages() { Qt.openUrlExternally("https://www.luogu.com.cn/chat") }
  function heatmapInfo(index) {
    var total = 26 * 7
    var today = new Date()
    today.setHours(0, 0, 0, 0)
    var target = new Date(today.getTime() - (total - 1 - index) * 86400000)
    function pad(value) { return value < 10 ? "0" + value : String(value) }
    var key = target.getFullYear() + "-" + pad(target.getMonth() + 1) + "-" + pad(target.getDate())
    var daily = root.profile.dailyCounts || []
    for (var i = 0; i < daily.length; i++) {
      if (daily[i].date === key) return { date: key, count: daily[i].count || 0, passed: daily[i].passed || 0 }
    }
    return { date: key, count: 0, passed: 0 }
  }
  function heatmapColor(level) {
    if (level <= 0) return Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.07)
    return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20 + Math.min(4, level) * 0.18)
  }

  function logout() {
    uid = ""
    clientId = ""
    profile = Model.parseProfile(null)
    contests = []
    notifications = []
    messages = []
    feedItems = []
    postItems = []
    unreadNotifications = 0
    unreadMessages = 0
    credentialsReady = true
    statusText = "已退出"
    secretClear.running = true
    fileClear.running = true
  }

  function loadCredentials() {
    credentialReadsPending = 2
    secretRead.running = true
    fileRead.running = true
  }

  function saveCredentials() {
    if (uid.trim() === "" || clientId.trim() === "") {
      statusText = "请填写 UID 和 __client_id"
      return
    }
    secretStore.secret = JSON.stringify({ uid: uid.trim(), clientId: clientId.trim() })
    secretStore.running = true
    fileStore.secret = secretStore.secret
    fileStore.running = true
    statusText = "正在保存登录信息…"
    // Credentials are already available in memory. Refresh immediately so a
    // successful login does not depend on Secret Service/file I/O callbacks.
    Qt.callLater(root.refresh)
  }

  function requestCaptcha() {
    if (captchaProc.running) return
    captchaProc.loginReady = false
    captchaImage = ""
    loginCaptcha = ""
    statusText = "正在获取验证码…"
    captchaProc.running = true
  }

  function loginWithPassword() {
    if (loginUsername.trim() === "" || loginPassword === "" || loginCaptcha.trim() === "") {
      statusText = "请填写账号、密码和验证码"
      return
    }
    if (loginCsrfToken === "" || !captchaProc.loginReady) {
      statusText = "请先获取验证码"
      requestCaptcha()
      return
    }
    if (passwordLoginProc.running) return
    statusText = "正在登录洛谷…"
    var username = loginUsername.trim()
    if (/^1[0-9]{10}$/.test(username)) {
      username = "+86" + username
      statusText = "已自动补充 +86，正在登录洛谷…"
    }
    passwordLoginProc.username = username
    passwordLoginProc.password = loginPassword
    passwordLoginProc.captcha = loginCaptcha
    passwordLoginProc.running = true
  }

  function publishBenben() {
    if (benbenDraft.trim() === "") { statusText = "请输入犇犇内容"; return }
    if (csrfToken === "") { statusText = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (benbenProc.running) return
    benbenProc.content = benbenDraft.trim()
    benbenProc.succeeded = false
    benbenProc.errorMessage = ""
    actionStatusText = "正在发布犇犇…"
    statusText = "正在发布犇犇…"
    benbenProc.running = true
  }

  // --- 私信 -----------------------------------------------------------------
  readonly property var problemDifficultyOptions: ["全部", "入门", "普及-", "普及", "普及+/提高-", "提高", "提高+/省选-", "省选/NOI-", "NOI/NOI+/CTS"]
  readonly property var problemTagOptions: {
    var names = ["全部标签"]
    var groups = root.tagTable.groups || []
    for (var i = 0; i < groups.length; i++) names.push(groups[i].name)
    return names
  }
  readonly property var problemOrderOptions: ["默认", "难度 ↑", "难度 ↓", "编号 ↓"]
  readonly property int problemPageCount: Math.max(1, Math.ceil(root.problemCount / 50))
  readonly property var problemTagNames: Model.tagNames(root.problemDetail ? root.problemDetail.tags : [], root.tagTable)


  function openProblemDiscussions(pid) {
    if (!pid) return
    root.problemView = "discussions"
    root.problemPosts = []
    root.problemPostCount = 0
    root.problemPostTitleDraft = ""
    root.problemPostContentDraft = ""
    root.problemPostCaptchaDraft = ""
    root.problemDiscussionEditorOpen = false
    if (root.postCaptchaImage === "" && !postCaptchaProc.running) root.requestPostCaptcha()
    loadProblemPosts(1)
  }

  function loadProblemPosts(page) {
    if (!root.problemDetail || problemPostsProc.running) return
    root.problemPostPage = Math.max(1, page)
    root.problemPostsLoading = true
    problemPostsProc.command = ["sh", "-c", "curl -sS --max-time 25 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/discuss?forum=$3&_contentOnly=1&page=$4\"", "luogu-problemposts", uid, clientId, root.problemDetail.pid, String(root.problemPostPage)]
    problemPostsProc.running = true
  }

  function openThread(id) {
    if (!id) return
    root.problemView = "thread"
    root.threadPost = null
    root.threadReplies = []
    root.threadPage = 1
    root.threadId = String(id)
    loadThreadPage(1)
  }

  function loadThreadPage(page) {
    if (threadProc.running) return
    root.threadPage = Math.max(1, page)
    threadProc.page = root.threadPage
    root.threadLoading = true
    threadProc.command = ["sh", "-c", "curl -sS --max-time 25 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/discuss/$3?_contentOnly=1&page=$4\"", "luogu-thread", uid, clientId, String(root.threadId), String(root.threadPage)]
    threadProc.running = true
  }

  function loadMoreThreadReplies() {
    if (threadProc.running || root.threadPost === null) return
    if (root.threadReplies.length >= root.threadPost.replyTotal) return
    loadThreadPage(root.threadPage + 1)
  }

  // 打开题目时把提交区准备好：语言默认上次用的那个，代码预填上次提交的代码。




  // 比赛里的题目开自己的窗口：不再跳到「洛谷中心」的题库页，免得改掉那边的
  // 导航层级（返回时回不到比赛），也避免两个窗口抢同一份题目状态。
  function openProblemWindow(pid) {
    var identifier = String(pid || "").trim()
    if (identifier === "") return
    problemWindowPid = identifier
    problemWindowOpen = true
    problemPlacementTimer.restart()
  }

  function closeProblemWindow() {
    problemWindowOpen = false
    problemPlacementTimer.stop()
  }

  function closeContestDetail() {
    contestDetailOpen = false
    contestPlacementTimer.stop()
  }

  function loadContestPage(page) {
    if (contestLoading) return
    contestPage = Math.max(1, page)
    refresh()
  }

  readonly property int contestPageCount: Math.max(1, Math.ceil(root.contestCount / 20))

  // 插件的用户设置（manifest 的 barWidget.schema，值存在 shell.json 的 bar 布局条目里）
  function setting(name, fallback) {
    var value = root.settings ? root.settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property int markdownBlockLimit: Math.max(20, Number(setting("markdownBlockLimit", 120)))

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

  readonly property int defaultLanguageId: Model.languageIdByName(setting("defaultLanguage", "C++14 (GCC 9)"))

  function loadTagTable() {
    if (tagTableProc.running || root.tagTable.groups.length > 0) return
    root.tagTableLoading = true
    tagTableProc.command = ["sh", "-c", "curl -sS --max-time 25 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"Cookie: _uid=$1;__client_id=$2\" 'https://www.luogu.com.cn/_lfe/tags/zh-CN'", "luogu-tags", uid, clientId]
    tagTableProc.running = true
  }

  function openProblemBank() {
    loadTagTable()
    if (root.problemList.length === 0 && !problemListProc.running) searchProblems(1)
  }

  function searchProblems(page) {
    if (problemListProc.running) return
    root.problemPage = Math.max(1, page)
    root.problemListLoading = true
    var query = "?_contentOnly=1&page=" + root.problemPage
    var keyword = root.problemKeyword.trim()
    if (keyword !== "") query += "&keyword=" + encodeURIComponent(keyword)
    var difficulty = root.problemDifficultyOptions.indexOf(root.problemDifficultyName)
    if (difficulty > 0) query += "&difficulty=" + difficulty
    var tagIndex = root.problemTagOptions.indexOf(root.problemTagName)
    if (tagIndex > 0) {
      var group = root.tagTable.groups[tagIndex - 1]
      if (group) query += "&tag=" + group.id
    }
    if (root.problemOrderName === "难度 ↑") query += "&orderBy=difficulty&order=asc"
    else if (root.problemOrderName === "难度 ↓") query += "&orderBy=difficulty&order=desc"
    else if (root.problemOrderName === "编号 ↓") query += "&orderBy=pid&order=desc"
    problemListProc.command = ["sh", "-c", "curl -sS --max-time 25 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/problem/list$3\"", "luogu-problemlist", uid, clientId, query]
    problemListProc.running = true
  }
  function openProblem(pid) {
    if (!pid) return
    root.problemDetailPid = String(pid)
    root.problemView = "detail"
    root.problemDetail = null
    root.problemDetailLoading = true
    // 题目详情接口不带题解数，列表要点了才知道，先清掉上一题的残留值。
    root.solutionList = []
    root.solutionCount = 0
    problemDetailProc.command = ["sh", "-c", "curl -sS --max-time 25 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/problem/$3?_contentOnly=1\"", "luogu-problem", uid, clientId, pid]
    problemDetailProc.running = true
  }

  function openSolutions(pid) {
    if (!pid) return
    root.problemView = "solutions"
    root.solutionList = []
    root.solutionCount = 0
    root.solutionLoading = true
    solutionsProc.command = ["sh", "-c", "curl -sS --max-time 25 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/problem/solution/$3?_contentOnly=1\"", "luogu-solutions", uid, clientId, pid]
    solutionsProc.running = true
  }

  function openArticle(lid) {
    if (!lid) return
    root.problemView = "article"
    root.solutionArticle = null
    root.articleLoading = true
    articleProc.command = ["sh", "-c", "curl -sS --max-time 25 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/article/$3?_contentOnly=1\"", "luogu-article", uid, clientId, lid]
    articleProc.running = true
  }

  function openPost(id) {
    var identifier = String(id || "").trim()
    if (!/^\d+$/.test(identifier)) return
    postDetailId = identifier
    postDetail = null
    postReplies = []
    postReplyPage = 1
    postDetailLoading = true
    // Replying is a normal thing to do right after reading, so put the target id
    // in the form and make sure a captcha is on screen.
    replyPostId = identifier
    if (replyCaptchaImage === "" && !replyCaptchaProc.running) requestReplyCaptcha()
    loadPostPage(1)
  }

  function closePost() {
    postDetail = null
    postDetailId = ""
    postReplies = []
    postReplyPage = 1
    postDetailLoading = false
  }

  function loadPostPage(page) {
    if (postDetailId === "") return
    postDetailLoading = true
    postDetailProc.page = page
    postDetailProc.command = [
      "sh", "-c",
      "curl -sS --max-time 20 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/discuss/$3?_contentOnly=1&page=$4\"",
      "luogu-postdetail", uid, clientId, postDetailId, String(page)
    ]
    postDetailProc.running = true
  }

  function loadMoreReplies() {
    if (postDetailProc.running) return
    postReplyPage = postReplyPage + 1
    loadPostPage(postReplyPage)
  }

  // 洛谷账号设置（只读）：奖项认证 / 账号安全 / 第三方绑定。三个都是 GET，
  // 「改」的接口探不到（设置页 HTML 对非浏览器客户端是 302 自我循环）。
  function loadAccountSettings() {
    if (uid === "" || clientId === "") return
    accountPending = 3
    accountLoading = true
    // 编辑框初值 = 服务器当前值（页面打开时同步一次，避免自动刷新打断输入）
    userSpaceSlogan = root.profile.slogan
    userSpaceIntro = root.profile.introduction
    userSpaceBackground = root.profile.background
    userSpaceStatus = ""
    var base = ["sh", "-c", "curl -sS --max-time 15 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/$3?_contentOnly=1\"", "luogu-account", uid, clientId]
    accountPrizeProc.command = base.concat(["user/setting/prize"])
    accountPrizeProc.running = true
    accountSecurityProc.command = base.concat(["user/setting/security"])
    accountSecurityProc.running = true
    accountBindingsProc.command = base.concat(["user/setting"])
    accountBindingsProc.running = true
  }

  // 写回洛谷个人空间设置。实测 POST /user/setting/userSpace 是**部分更新**：
  // 只改请求体里出现的键（空体 {} 返回 {"id":uid} 且什么都不变），所以这里只发
  // 真正改动过的字段，避免误伤背景图之类。
  function saveUserSpace() {
    if (csrfToken === "") { userSpaceStatus = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (root.userSpaceProcRunning()) return
    // 归一化后再比较：profile 里缺字段时是 undefined，而输入框是 ""，直接比会把
    // 空串当成「改动过」，于是每次保存都多送一个空 background（实测服务器会忽略，
    // 但那是运气，不能依赖）。
    function serverValue(value) { return value === undefined || value === null ? "" : String(value) }
    var body = {}
    if (userSpaceSlogan !== serverValue(root.profile.slogan)) body.slogan = userSpaceSlogan
    if (userSpaceIntro !== serverValue(root.profile.introduction)) body.introduction = userSpaceIntro
    if (userSpaceBackground !== serverValue(root.profile.background)) body.background = userSpaceBackground
    if (Object.keys(body).length === 0) { userSpaceStatus = "没有改动"; return }
    userSpaceSaving = true
    userSpaceStatus = "正在保存…"
    userSpaceProc.payloadBase64 = Model.utf8Base64(JSON.stringify(body))
    userSpaceProc.running = true
  }

  function userSpaceProcRunning() { return userSpaceProc.running }

  function pasteCommand(path) {
    return ["sh", "-c", "curl -sS --max-time 15 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/paste' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/$3\"", "luogu-paste", uid, clientId, path]
  }

  function loadPastes(append) {
    if (uid === "" || clientId === "" || pasteListProc.running) return
    var next = append ? root.pastePage + 1 : 1
    pasteListProc.page = next
    pasteListProc.append = append
    pasteListProc.command = pasteCommand("paste?_contentOnly=1&page=" + next)
    root.pasteLoading = true
    pasteListProc.running = true
  }

  function openPasteDetail(id) {
    var wanted = String(id || "").trim()
    if (wanted === "") return
    root.pasteDetailId = wanted
    root.pasteDetail = null
    root.pasteDetailLoading = true
    pasteDetailProc.command = pasteCommand("paste/" + wanted + "?_contentOnly=1")
    pasteDetailProc.running = true
  }

  function closePasteDetail() {
    root.pasteDetailId = ""
    root.pasteDetail = null
    root.pasteDetailLoading = false
  }

  // 复制到系统剪贴板：借一个隐藏 TextArea 走 Qt 的剪贴板。
  function copyToClipboard(value) {
    clipboardHelper.text = String(value === undefined || value === null ? "" : value)
    clipboardHelper.selectAll()
    clipboardHelper.copy()
  }

  function refreshPasteCaptcha() {
    if (pasteCaptchaProc.running) return
    root.pasteCaptchaReady = false
    root.pasteCaptchaImage = ""
    root.pasteCaptchaCode = ""
    pasteCaptchaProc.command = ["sh", "-c", "set -eu; out=$(mktemp); trap 'rm -f \"$out\"' EXIT; type=$(curl -sS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'Cache-Control: no-cache' -H 'X-Requested-With: XMLHttpRequest' -H \"Referer: https://www.luogu.com.cn/\" -H \"Cookie: _uid=$1;__client_id=$2\" -o \"$out\" -w '%{content_type}' \"https://www.luogu.com.cn/lg4/captcha?_t=$(date +%s%N)\"); data=$(base64 -w0 \"$out\"); jq -nc --arg type \"$type\" --arg data \"$data\" '{mime:$type,data:$data}'", "luogu-paste-captcha", uid, clientId]
    pasteCaptchaProc.running = true
  }

  function openPasteComposer() {
    root.pasteComposerMode = "create"
    root.pasteDraftData = ""
    root.pasteDraftPublic = false
    root.pasteWriteStatus = ""
    root.pasteComposerOpen = true
    root.refreshPasteCaptcha()
  }

  function startPasteEdit() {
    if (!root.pasteDetail) return
    root.pasteComposerMode = "edit"
    root.pasteDraftData = root.pasteDetail.data
    root.pasteDraftPublic = root.pasteDetail.isPublic
    root.pasteWriteStatus = ""
    root.pasteComposerOpen = true
    root.refreshPasteCaptcha()
  }

  function closePasteComposer() {
    root.pasteComposerOpen = false
    root.pasteWriteStatus = ""
  }

  // 新建走 POST /paste/_new，编辑走 POST /paste/_edit；两者都带图形验证码
  // （路由名来自 GET /_lfe/config 的 route.paste.* —— 社区文档里的 /paste/new 已过时）
  function submitPasteWrite() {
    if (csrfToken === "") { root.pasteWriteStatus = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (root.pasteSaving) return
    var editing = root.pasteComposerMode === "edit"
    if (root.pasteDraftData === "" && !editing) { root.pasteWriteStatus = "内容不能为空"; return }
    // 新建实测必须带验证码；编辑不强制（删除就完全不需要验证码），填了才发
    if (!editing && root.pasteCaptchaCode.trim() === "") { root.pasteWriteStatus = "请填写验证码（点图片可换一张）"; return }
    var body = { data: root.pasteDraftData, public: root.pasteDraftPublic }
    if (root.pasteCaptchaCode.trim() !== "") body.captcha = root.pasteCaptchaCode.trim()
    if (editing) {
      if (root.pasteDetailId === "") { root.pasteWriteStatus = "没有正在编辑的剪贴板"; return }
      body.id = root.pasteDetailId
    }
    root.pasteSaving = true
    root.pasteWriteStatus = root.pasteComposerMode === "edit" ? "正在保存…" : "正在创建…"
    pasteWriteProc.target = editing ? "paste/_edit" : "paste/_new"
    pasteWriteProc.query = editing ? ("?id=" + encodeURIComponent(root.pasteDetailId)) : ""
    pasteWriteProc.httpMethod = "POST"
    pasteWriteProc.payloadBase64 = Model.utf8Base64(JSON.stringify(body))
    pasteWriteProc.running = true
  }

  // 删除：DELETE /paste/_edit?id=<id>（浏览器实测；不需要验证码）。破坏性操作，
  // 界面上要点两次才不会误删。
  function deletePaste(id) {
    var wanted = String(id || "").trim()
    if (wanted === "") return
    if (csrfToken === "") { root.pasteWriteStatus = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (root.pasteSaving) return
    root.pasteDeleteConfirm = false
    root.pasteSaving = true
    root.pasteWriteStatus = "正在删除…"
    pasteWriteProc.target = "paste/_edit"
    pasteWriteProc.query = "?id=" + encodeURIComponent(wanted)
    pasteWriteProc.httpMethod = "DELETE"
    pasteWriteProc.payloadBase64 = ""
    pasteWriteProc.running = true
  }

  function pastePreview(item) {
    var first = item.data.split("\n")[0]
    return first.length > 0 ? first : "(空)"
  }

  function accountDone() {
    accountPending = Math.max(0, accountPending - 1)
    if (accountPending === 0) accountLoading = false
  }

  function openDetailPage(key) {
    detailPage = key
    if (key === "problems") { openProblemBank(); return }
    if (key === "account") { loadAccountSettings(); return }
    if (key === "paste") { loadPastes(false); return }
    if (key !== "chat") return
    if (chatSelectedUid === "" && chatSessions.length > 0) openChatWith(chatSessions[0].uid, chatSessions[0].name, chatSessions[0].color)
    else if (chatSelectedUid !== "") loadChatMessages()
  }

  function openChatWith(uid, name, color) {
    var identifier = String(uid || "").trim()
    if (identifier === "") return
    chatSelectedUid = identifier
    chatSelectedName = name || ""
    chatSelectedColor = color || ""
    chatSearchKeyword = ""
    chatSearchResults = []
    chatSearchQueried = ""
    chatMessages = []
    // A conversation with no history yet is absent from the server's list, so
    // keep a local row for it until a refresh returns a real one.
    var known = false
    for (var i = 0; i < chatSessions.length; i++) if (String(chatSessions[i].uid) === identifier) known = true
    if (!known) {
      var next = chatSessions.slice()
      next.unshift({ uid: Number(identifier), name: chatSelectedName || "洛谷用户", ccfLevel: 0, content: "", time: 0 })
      chatSessions = next
    }
    loadChatMessages()
  }

  function loadChatMessages() {
    if (chatSelectedUid === "") return
    chatLoading = true
    chatRecordProc.command = [
      "sh", "-c",
      "curl -sS --max-time 15 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: _uid=$1;__client_id=$2\" \"https://www.luogu.com.cn/api/chat/record?user=$3\"",
      "luogu-chatrecord", uid, clientId, chatSelectedUid
    ]
    chatRecordProc.running = true
  }

  function searchUsers() {
    var keyword = chatSearchKeyword.trim()
    if (keyword === "") { chatSearchResults = []; chatSearching = false; return }
    if (chatSearchProc.running) return
    chatSearching = true
    chatSearchProc.keyword = keyword
    chatSearchProc.command = [
      "sh", "-c",
      "curl -sS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"Cookie: _uid=$1;__client_id=$2\" --get --data-urlencode \"keyword=$3\" 'https://www.luogu.com.cn/api/user/search'",
      "luogu-chatsearch", uid, clientId, keyword
    ]
    chatSearchProc.running = true
  }

  function sendPrivateMessage() {
    if (!/^\d+$/.test(chatSelectedUid)) { statusText = "请先在左侧选择一个会话"; return }
    if (chatDraft.trim() === "") { statusText = "请输入私信内容"; return }
    if (csrfToken === "") { statusText = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (chatProc.running) return
    chatProc.target = chatSelectedUid
    chatProc.content = chatDraft.trim()
    chatProc.succeeded = false
    chatProc.errorMessage = ""
    actionStatusText = "正在发送私信…"
    statusText = actionStatusText
    chatProc.running = true
  }

  // Luogu gates every discussion write behind a captcha ("验证码错误" comes back
  // before title/content/forum are even looked at). Its image lives at
  // /api/verify/captcha and is bound to the session cookies; the login form's
  // /lg4/captcha is a different captcha and cannot be reused here.
  function requestPostCaptcha() {
    if (postCaptchaProc.running || uid === "" || clientId === "") return
    postCaptchaReady = false
    postCaptchaImage = ""
    postCaptchaDraft = ""
    postCaptchaProc.running = true
  }

  function requestReplyCaptcha() {
    if (replyCaptchaProc.running || uid === "" || clientId === "") return
    replyCaptchaReady = false
    replyCaptchaImage = ""
    replyCaptcha = ""
    replyCaptchaProc.running = true
  }

  function ensurePostCaptcha() {
    if (detailPage !== "posts") return
    if (!forumsProbed && !forumPermProc.running) forumPermProc.running = true
    if (postCaptchaImage === "" && !postCaptchaProc.running) requestPostCaptcha()
  }

  // Posting permission is per board, not per account: GET /discuss?forum=<slug>
  // reports canPost for that board alone (academics/problem true, siteaffairs
  // false for this account). Refusing here keeps the captcha for a board that
  // would only answer with a refusal.
  function forumEntry(slug) {
    for (var i = 0; i < postForums.length; i++) if (postForums[i].value === slug) return postForums[i]
    return null
  }
  function forumCanPost(slug) {
    var entry = forumEntry(slug)
    return entry === null || entry.canPost === undefined ? true : entry.canPost === true
  }
  function forumLabel(slug) {
    var entry = forumEntry(slug)
    return entry === null ? slug : String(entry.name || entry.label || slug)
  }

  onDetailPageChanged: ensurePostCaptcha()

  function publishPost() {
    if (!forumCanPost(postForumDraft)) {
      statusText = "你在「" + forumLabel(postForumDraft) + "」没有发帖权限，请换一个版面"
      return
    }
    if (postTitleDraft.trim() === "" || postContentDraft.trim() === "") { statusText = "请填写帖子标题和内容"; return }
    if (postCaptchaDraft.trim() === "") {
      statusText = postCaptchaReady ? "请输入验证码" : "正在获取验证码，请稍候再试"
      if (!postCaptchaReady) requestPostCaptcha()
      return
    }
    if (csrfToken === "") { statusText = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (postProcWrite.running) return
    postProcWrite.title = postTitleDraft.trim()
    postProcWrite.forum = postForumDraft.trim() !== "" ? postForumDraft.trim() : "academics"
    postProcWrite.captcha = postCaptchaDraft.trim()
    postProcWrite.content = postContentDraft.trim()
    postProcWrite.succeeded = false
    postProcWrite.errorMessage = ""
    postProcWrite.problemContext = false
    actionStatusText = "正在发布帖子…"
    statusText = "正在发布帖子…"
    postProcWrite.running = true
  }

  function publishProblemPost() {
    if (!root.problemDetail || root.problemDetail.pid === "") return
    if (problemPostTitleDraft.trim() === "" || problemPostContentDraft.trim() === "") {
      statusText = "请填写讨论标题和内容"
      return
    }
    if (problemPostCaptchaDraft.trim() === "") {
      statusText = postCaptchaReady ? "请输入验证码" : "正在获取验证码，请稍候再试"
      if (!postCaptchaReady) requestPostCaptcha()
      return
    }
    if (csrfToken === "") { statusText = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (postProcWrite.running) return
    postProcWrite.title = problemPostTitleDraft.trim()
    postProcWrite.forum = String(root.problemDetail.pid)
    postProcWrite.captcha = problemPostCaptchaDraft.trim()
    postProcWrite.content = problemPostContentDraft.trim()
    postProcWrite.succeeded = false
    postProcWrite.errorMessage = ""
    postProcWrite.problemContext = true
    actionStatusText = "正在发布题目讨论…"
    statusText = actionStatusText
    postProcWrite.running = true
  }

  function replyPost() {
    if (!/^\d+$/.test(replyPostId.trim()) || replyDraft.trim() === "") { statusText = "请填写帖子 ID 和回复内容"; return }
    if (replyCaptcha.trim() === "") {
      statusText = replyCaptchaReady ? "请输入验证码" : "正在获取验证码，请稍候再试"
      if (!replyCaptchaReady) requestReplyCaptcha()
      return
    }
    if (csrfToken === "") { statusText = "CSRF 令牌尚未准备好，请稍后再试"; return }
    if (replyProc.running) return
    replyProc.postId = replyPostId.trim()
    replyProc.captcha = replyCaptcha.trim()
    replyProc.content = replyDraft.trim()
    replyProc.succeeded = false
    replyProc.errorMessage = ""
    actionStatusText = "正在发表回复…"
    statusText = "正在发表回复…"
    replyProc.running = true
  }

  // Response parsing lives in Model.js so it can be unit tested outside the
  // shell. The write commands below deliberately do not pass -f to curl: Luogu
  // rejects a write with an HTTP 4xx whose JSON body holds the real reason
  // ("验证码错误", "会话超时，请刷新页面后重试"), and -f throws that body away and
  // leaves an empty stdout, which is what produced the useless
  // "洛谷没有返回…" message.
  function writeResponseSucceeded(body, httpCode) { return Model.writeResponseSucceeded(body, httpCode) }
  function writeResponseMessage(body) { return Model.writeResponseMessage(body) }
  function splitHttpCode(output) { return Model.splitHttpCode(output) }
  function writeFailureMessage(httpCode, body) { return Model.writeFailureMessage(httpCode, body) }

  function finishWrite(message) {
    actionStatusText = message
    statusText = message
    refresh()
  }

  function failWrite(prefix, message, fallback) {
    var detail = message && message !== "" ? message : (fallback && fallback !== "" ? fallback : "请刷新登录状态后重试")
    actionStatusText = prefix + "：" + detail
    statusText = actionStatusText
    // An expired or rejected CSRF token is the one write failure the widget can
    // repair on its own: drop it so the next attempt scrapes a fresh one.
    if (detail.indexOf("CSRF") >= 0 || detail.indexOf("会话超时") >= 0) {
      csrfToken = ""
      csrfProc.running = true
    }
  }

  function applyCredentials(raw) {
    try {
      var saved = JSON.parse(String(raw || ""))
      if (root.uid === "") root.uid = String(saved.uid || "")
      if (root.clientId === "") root.clientId = String(saved.clientId || "")
    } catch (error) {
      // Another credential backend may still provide the session.
    }
    credentialReadsPending = Math.max(0, credentialReadsPending - 1)
    if (credentialReadsPending === 0) {
      credentialsReady = true
      if (root.uid !== "" && root.clientId !== "") root.refresh()
      else statusText = "未登录"
    }
  }

  function refresh() {
    if (uid === "" || clientId === "") {
      statusText = "请先登录"
      return
    }
    if (apiProc.running) return
    loading = true
    contestLoading = true
    statusText = "正在连接洛谷…"
    apiProc.command = [
      "curl", "-fsS", "--max-time", "12",
      "-A", "vscode-luogu@4.17.1",
      "-H", "X-Requested-With: XMLHttpRequest",
      "-H", "Referer: https://www.luogu.com.cn/",
      "-H", "x-lentille-request: content-only",
      "-H", "Cookie: _uid=" + uid + ";__client_id=" + clientId,
      "https://www.luogu.com.cn/user/" + encodeURIComponent(uid) + "?_contentOnly=1"
    ]
    apiProc.running = true
    contestProc.command = [
      "sh", "-c",
      "set -u; uid=\"$1\"; client=\"$2\"; page=\"$3\"; cookie=\"_uid=$uid;__client_id=$client\"; now=$(date +%s); list=$(curl -fsS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: $cookie\" \"https://www.luogu.com.cn/contest/list?_contentOnly=1&page=$page\") || exit 1; details='[]'; for id in $(printf '%s' \"$list\" | jq -r --argjson now \"$now\" '[.data.contests.result[] | select(.endTime > $now)][0:8][].id'); do joined=$(curl -fsS --max-time 10 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'x-lentille-request: content-only' -H \"Cookie: $cookie\" \"https://www.luogu.com.cn/contest/$id?_contentOnly=1\" | jq -c '.data.joined // null' 2>/dev/null || printf 'null'); details=$(printf '%s' \"$details\" | jq -c --arg id \"$id\" --argjson joined \"$joined\" '. + [{id: ($id | tonumber), joined: $joined}]' 2>/dev/null || printf '%s' \"$details\"); done; printf '%s' \"$list\" | jq -c --argjson details \"$details\" --argjson page \"$page\" '{count: .data.contests.count, perPage: .data.contests.perPage, page: $page, contests: (reduce $details[] as $detail ((.data.contests.result | map(. + {joined: null})); map(if .id == $detail.id then . + {joined: $detail.joined} else . end)))}'",
      "luogu-contests", uid, clientId, String(contestPage)
    ]
    contestProc.running = true
    activityLoading = true
    activityProc.command = [
      "sh", "-c",
      "uid=\"$1\"; client=\"$2\"; cookie=\"_uid=$uid;__client_id=$client\"; headers=\"-A vscode-luogu@4.17.1 -H X-Requested-With:XMLHttpRequest -H Referer:https://www.luogu.com.cn/ -H x-lentille-request:content-only -H Cookie:$cookie\"; notice=$(curl -fsS --max-time 12 $headers 'https://www.luogu.com.cn/user/notification?_contentOnly=1&page=1' 2>/dev/null || printf '{}'); chat=$(curl -fsS --max-time 12 $headers 'https://www.luogu.com.cn/chat?_contentOnly=1' 2>/dev/null || printf '{}'); jq -nc --argjson notice \"$notice\" --argjson chat \"$chat\" '{notice:$notice,chat:$chat}'",
      "luogu-activity", uid, clientId
    ]
    activityProc.running = true
    csrfProc.running = true
    if (detailOpen && detailPage === "chat" && chatSelectedUid !== "") loadChatMessages()
    feedProc.target = "watching"
    // 关注动态要走 HTML 片段（/feed/watching），不能用 /api/feed/watching：
    // JSON 版每条形如 {uid,time,type,comment}，**没有姓名字段**，所以界面上所有人
    // 都退化成「洛谷用户」；HTML 片段里带 feed-username 和 /user/<uid> 链接。
    feedPage = 1
    feedProc.page = 1
    feedProc.append = false
    feedProc.target = "watching"
    feedProc.command = feedCommand("watching", 1)
    feedProc.running = true
    postProc.command = ["curl", "-fsS", "--max-time", "12", "-A", "vscode-luogu@4.17.1", "-H", "X-Requested-With: XMLHttpRequest", "-H", "Referer: https://www.luogu.com.cn/", "-H", "x-lentille-request: content-only", "-H", "Cookie: _uid=" + uid + ";__client_id=" + clientId, "https://www.luogu.com.cn/discuss?_contentOnly=1&page=1"]
    postProc.running = true
  }

  function applyProfile(raw) {
    var next = Model.parseProfile(raw)
    if (next.uid <= 0 || next.name === "") {
      statusText = "登录信息无效或洛谷返回异常"
      return
    }
    profile = next
    statusText = "已连接 · " + next.name
  }

  function formatRanking(value) { return Model.rankingLabel(value) }

  function openContestDetail(id) {
    if (!id) return
    contestView = "detail"
    contestDetailOpen = true
    contestPlacementTimer.restart()
    contestDetail = null
    contestDetailLoading = true
    contestDetailProc.command = ["curl", "-fsS", "--max-time", "15", "-A", "vscode-luogu@4.17.1", "-H", "X-Requested-With: XMLHttpRequest", "-H", "Referer: https://www.luogu.com.cn/", "-H", "x-lentille-request: content-only", "-H", "Cookie: _uid=" + uid + ";__client_id=" + clientId, "https://www.luogu.com.cn/contest/" + id + "?_contentOnly=1"]
    contestDetailProc.running = true
  }

  // 犇犇的两个入口共用一个命令构造：只有页号不同。
  function feedCommand(target, page) {
    var mine = target === "mine"
    var url = mine
      ? ("https://www.luogu.com.cn/feed/my?page=" + page + "&_contentOnly=1")
      : ("https://www.luogu.com.cn/feed/watching?page=" + page)
    var argv = ["curl", "-fsS", "--max-time", "15",
      "-A", "vscode-luogu@4.17.1",
      "-H", "X-Requested-With: XMLHttpRequest",
      "-H", "Referer: https://www.luogu.com.cn/"]
    if (mine) argv = argv.concat(["-H", "x-lentille-request: content-only"])
    return argv.concat(["-H", "Cookie: _uid=" + uid + ";__client_id=" + clientId, url])
  }

  function loadMoreFeed() {
    if (feedProc.running || feedMoreLoading) return
    var mine = root.feedMode === "mine"
    if (mine && !root.ownFeedHasMore) return
    if (!mine && !root.feedHasMore) return
    root.feedMoreLoading = true
    var next = (mine ? root.ownFeedPage : root.feedPage) + 1
    feedProc.target = mine ? "mine" : "watching"
    feedProc.page = next
    feedProc.append = true
    feedProc.command = feedCommand(feedProc.target, next)
    feedProc.running = true
  }

  function loadOwnFeed() {
    root.ownFeedPage = 1
    feedProc.page = 1
    feedProc.append = false
    if (uid === "" || clientId === "" || feedProc.running) return
    ownFeedLoading = true
    feedProc.target = "mine"
    feedProc.command = feedCommand("mine", 1)
    feedProc.running = true
  }

  Process {
    id: secretRead
    command: ["secret-tool", "lookup", "service", "omarchy-luogu", "account", "default"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.applyCredentials(text)
      }
    }
  }

  Process {
    id: contestProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.contestLoading = false
        var raw = String(text || "").trim()
        if (raw === "") {
          root.contests = []
          return
        }
        var page = Model.parseContestPage(raw)
        root.contests = page.contests
        root.contestCount = page.count
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text || "").trim() !== "") root.contestLoading = false
      }
    }
    onExited: function(exitCode) {
      root.contestLoading = false
      if (exitCode !== 0 && root.contests.length === 0) root.statusText = "比赛列表读取失败"
    }
  }

  Process {
    id: contestDetailProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.contestDetailLoading = false
        var detail = Model.parseContestDetail(String(text || "{}"))
        if (detail.id > 0) root.contestDetail = detail
        else root.statusText = "比赛详情读取失败"
      }
    }
    onExited: function() { root.contestDetailLoading = false }
  }

  Process {
    id: activityProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.activityLoading = false
        var parsed = Model.parseActivity(String(text || "{}"))
        root.notifications = parsed.notifications
        root.messages = parsed.messages
        root.chatSessions = Model.parseChatSessions(String(text || "{}"))
        root.unreadNotifications = parsed.unreadNotifications
        root.unreadMessages = parsed.unreadMessages
      }
    }
    onExited: function(exitCode) {
      root.activityLoading = false
    }
  }

  Process {
    id: csrfProc
    // No X-Requested-With here, on purpose. With that header Luogu answers "/"
    // with a 37-byte stub page whose csrf token is the two characters ":)" —
    // not the real page — so the scrape used to hand that garbage to every write
    // request and they all came back as InvalidCSRFTokenException. The full page
    // (and the real "1790346447:HGUqzFKa/FZjo...=" token) is served when only
    // Referer is sent.
    command: ["sh", "-c", "set -eu; page=$(curl -fsS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'Referer: https://www.luogu.com.cn/' -H \"Cookie: _uid=$1;__client_id=$2\" 'https://www.luogu.com.cn/'); printf '%s' \"$page\" | sed -n 's/.*meta name=\"csrf-token\" content=\"\\([^\"]*\\\)\".*/\\1/p' | head -1", "luogu-csrf", uid, clientId]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var token = String(text || "").trim()
        // Anything that is not a real token (the ":)" stub page, or an empty
        // scrape) counts as "not ready yet", so the write paths report that up
        // front instead of sending garbage and blaming the server afterwards.
        root.csrfToken = /^[0-9]{6,}:[A-Za-z0-9+/=]{8,}$/.test(token) ? token : ""
      }
    }
  }

  Process {
    id: feedProc
    property string target: "watching"
    property int page: 1
    property bool append: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseFeed(String(text || "{}"))
        var mine = feedProc.target === "mine"
        var previous = mine ? root.ownFeedItems : root.feedItems
        var merged = feedProc.append ? Model.mergeFeedItems(previous, parsed) : parsed
        // 一整页都没有新内容 => 到底了，把「加载更多」收起来
        var hasMore = parsed.length > 0 && (!feedProc.append || merged.length > previous.length)
        if (mine) {
          root.ownFeedItems = merged
          root.ownFeedHasMore = hasMore
          root.ownFeedPage = feedProc.append ? feedProc.page : 1
          root.ownFeedLoading = false
        } else {
          root.feedItems = merged
          root.feedHasMore = hasMore
          root.feedPage = feedProc.append ? feedProc.page : 1
        }
        root.feedMoreLoading = false
      }
    }
    onExited: function() {
      if (feedProc.target === "mine") root.ownFeedLoading = false
      root.feedMoreLoading = false
    }
  }

  Process {
    id: postProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "{}")
        root.postItems = Model.parsePosts(raw)
        if (!root.forumsProbed) root.postForums = Model.parseForums(raw)
      }
    }
  }

  // Asks each public board whether this account may post in it. Read-only and
  // run once per details-window session, because the answer is a permission and
  // can change while the shell stays up.
  Process {
    id: forumPermProc
    command: ["sh", "-c", "set -eu; uid=\"$1\"; client=\"$2\"; cookie=\"_uid=$uid;__client_id=$client\"; headers=\"-A vscode-luogu@4.17.1 -H X-Requested-With:XMLHttpRequest -H x-lentille-request:content-only -H Referer:https://www.luogu.com.cn/ -H Cookie:$cookie\"; base='https://www.luogu.com.cn/discuss?_contentOnly=1&page=1'; list=$(curl -fsS --max-time 12 $headers \"$base\" | jq -c '[.data.publicForums[] | {slug: .slug, name: .name}]'); out='[]'; for slug in $(printf '%s' \"$list\" | jq -r '.[].slug'); do name=$(printf '%s' \"$list\" | jq -r --arg s \"$slug\" '.[] | select(.slug == $s) | .name'); can=$(curl -fsS --max-time 12 $headers \"$base&forum=$slug\" | jq -r '.data.canPost // false'); out=$(printf '%s' \"$out\" | jq -c --arg s \"$slug\" --arg n \"$name\" --argjson c \"$can\" '. + [{slug: $s, name: $n, canPost: $c}]'); done; printf '%s' \"$out\"", "luogu-forums", uid, clientId]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.postForums = Model.parseForumPermissions(String(text || "[]"))
        root.forumsProbed = true
      }
    }
  }

  Process {
    id: benbenProc
    property string content: ""
    command: ["sh", "-c", "set -eu; curl -sS --max-time 15 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"X-CSRF-Token: $3\" -H 'Content-Type: application/x-www-form-urlencoded' -H \"Cookie: _uid=$1;__client_id=$2\" --data-urlencode \"content=$4\" -w '|%{http_code}' 'https://www.luogu.com.cn/api/feed/postBenben'", "luogu-benben", uid, clientId, csrfToken, content]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.splitHttpCode(text)
        benbenProc.succeeded = root.writeResponseSucceeded(parsed.body, parsed.code)
        if (benbenProc.errorMessage === "") benbenProc.errorMessage = root.writeFailureMessage(parsed.code, parsed.body)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "" && benbenProc.errorMessage === "") benbenProc.errorMessage = message.slice(0, 160)
      }
    }
    property bool succeeded: false
    property string errorMessage: ""
    onExited: function(exitCode) {
      if (exitCode === 0 && succeeded) {
        root.benbenDraft = ""
        root.benbenEditorOpen = false
        root.finishWrite("犇犇已发布")
      } else {
        root.failWrite("犇犇发布失败", errorMessage, "请刷新登录状态后重试")
      }
    }
  }

  Process {
    id: chatProc
    property string target: ""
    property string content: ""
    command: ["sh", "-c", "set -eu; payload=$(jq -nc --arg user \"$4\" --arg content \"$5\" '{user:($user|tonumber),content:$content}'); curl -sS --max-time 15 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"X-CSRF-Token: $3\" -H 'Content-Type: application/json' -H \"Cookie: _uid=$1;__client_id=$2\" -d \"$payload\" -w '|%{http_code}' 'https://www.luogu.com.cn/api/chat/new'", "luogu-chat", uid, clientId, csrfToken, target, content]
    property bool succeeded: false
    property string errorMessage: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.splitHttpCode(text)
        chatProc.succeeded = root.writeResponseSucceeded(parsed.body, parsed.code)
        if (chatProc.errorMessage === "") chatProc.errorMessage = root.writeFailureMessage(parsed.code, parsed.body)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "" && chatProc.errorMessage === "") chatProc.errorMessage = message.slice(0, 160)
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && succeeded) {
        root.chatDraft = ""
        root.finishWrite("私信已发送")
        root.loadChatMessages()
      } else {
        root.failWrite("私信发送失败", errorMessage, "请检查登录状态或内容")
      }
    }
  }

  // Conversation history for the currently selected user. The endpoint returns
  // the newest page of messages, oldest first, capped at perPage (50).
  Process {
    id: chatRecordProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.chatLoading = false
        var raw = String(text || "").trim()
        var next = Model.parseChatRecord(raw, root.uid)
        // An empty list is a real answer only when the payload actually carried
        // a message box; anything else is a failed fetch, and clobbering the
        // thread with [] would read as "this conversation is empty".
        if (next.length > 0 || raw.indexOf('"messages"') >= 0) root.chatMessages = next
        else root.statusText = "聊天记录读取失败"
      }
    }
    onExited: function(exitCode) { root.chatLoading = false }
  }

  // Reads a post (and one page of its replies) as JSON so the plugin can lay the
  // Markdown out itself instead of sending the reader to the website.
  Process {
    id: postDetailProc
    property int page: 1
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.postDetailLoading = false
        var raw = String(text || "").trim()
        if (postDetailProc.page > 1) {
          root.postReplies = root.postReplies.concat(Model.parseReplies(raw))
          return
        }
        var detail = Model.parsePostDetail(raw)
        if (detail.id > 0) {
          root.postDetail = detail
          root.postReplies = detail.replies
        } else {
          root.postDetail = null
          root.postDetailId = ""
          root.statusText = "帖子读取失败，可能已被删除或不可见"
        }
      }
    }
    onExited: function(exitCode) { root.postDetailLoading = false }
  }

  // 题库：标签表（505 条 id→名称）只取一次，其余按需请求。
  Process {
    id: tagTableProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.tagTableLoading = false
        var parsed = Model.parseTagTable(String(text || ""))
        if (parsed.groups.length > 0) root.tagTable = parsed
        else root.statusText = "题库标签读取失败"
      }
    }
    onExited: function(exitCode) { root.tagTableLoading = false }
  }

  Process {
    id: problemListProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.problemListLoading = false
        var parsed = Model.parseProblemList(String(text || ""))
        root.problemList = parsed.problems
        root.problemCount = parsed.count
        if (parsed.problems.length === 0 && parsed.count === 0) root.statusText = "没有匹配的题目"
      }
    }
    onExited: function(exitCode) { root.problemListLoading = false }
  }

  Process {
    id: problemDetailProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.problemDetailLoading = false
        var detail = Model.parseProblemDetail(String(text || ""))
        if (detail.pid !== "") {
          root.problemDetail = detail
        } else {
          root.statusText = "题目读取失败，可能不存在或不可见"
        }
      }
    }
    onExited: function(exitCode) { root.problemDetailLoading = false }
  }

  Process {
    id: solutionsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.solutionLoading = false
        var parsed = Model.parseSolutions(String(text || ""))
        root.solutionList = parsed.solutions
        root.solutionCount = parsed.count
      }
    }
    onExited: function(exitCode) { root.solutionLoading = false }
  }

  Process {
    id: articleProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.articleLoading = false
        var parsed = Model.parseArticle(String(text || ""))
        if (parsed.lid !== "") root.solutionArticle = parsed
        else root.statusText = "题解读取失败"
      }
    }
    onExited: function(exitCode) { root.articleLoading = false }
  }

  // 题目讨论：每题一个版面（slug 就是题号），帖子列表用已有的 parsePosts 解析。
  Process {
    id: problemPostsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.problemPostsLoading = false
        var parsed = Model.parsePosts(String(text || ""))
        root.problemPosts = parsed
        root.problemPostCount = parsed.length
      }
    }
    onExited: function(exitCode) { root.problemPostsLoading = false }
  }

  Process {
    id: threadProc
    property int page: 1
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.threadLoading = false
        var raw = String(text || "").trim()
        if (threadProc.page > 1) {
          root.threadReplies = root.threadReplies.concat(Model.parseReplies(raw))
          return
        }
        var post = Model.parsePostDetail(raw)
        if (post.id > 0) {
          root.threadPost = post
          root.threadReplies = post.replies
        } else {
          root.statusText = "帖子读取失败"
        }
      }
    }
    onExited: function(exitCode) { root.threadLoading = false }
  }

  // 交题：代码可能上万字符，走 stdin 传 base64。
  // 这里不能让 curl 用 `--data-binary @-`：Quickshell 的 Process 只有 write()，
  // 没有关闭 stdin 的办法，curl 会一直等 EOF 把请求挂住（实测就是这样卡住的）。
  // 所以退一步：shell 读**一行** base64（不依赖 EOF），解码进临时文件再交给 curl。

  // 评测轮询：status 0/1 是 Waiting/Judging，出结果就停。


  QQC.TextArea {
    id: clipboardHelper
    visible: false
    width: 0
    height: 0
  }

  // 图形验证码（新的一套，异常类是 CaptchaChallengeException，与交题的
  // InvalidCaptchaException 不是同一套，所以用 /lg4/captcha 而不是 /api/verify/captcha）
  Process {
    id: pasteCaptchaProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(String(text || ""))
          var data = String(result.data || "")
          if (data === "") throw new Error("empty")
          root.pasteCaptchaImage = "data:" + String(result.mime || "image/jpeg") + ";base64," + data
          root.pasteCaptchaReady = true
        } catch (error) {
          root.pasteCaptchaImage = ""
          root.pasteCaptchaReady = false
          root.pasteWriteStatus = "验证码获取失败，点图片重试"
        }
      }
    }
    onExited: function(exitCode) { if (exitCode !== 0) { root.pasteCaptchaImage = ""; root.pasteCaptchaReady = false } }
  }

  Process {
    id: pasteWriteProc
    property string target: "paste/_new"
    property string query: ""
    property string httpMethod: "POST"
    property string payloadBase64: ""
    property string resultId: ""
    stdinEnabled: true
    // $4 = 路径，$5 = query（删除是 DELETE /paste/_edit?id=…），$6 = 方法
    command: ["sh", "-c", "set -eu; IFS= read -r encoded; f=$(mktemp); trap 'rm -f \"$f\"' EXIT; printf '%s' \"$encoded\" | base64 -d > \"$f\"; curl -sS --max-time 20 -X $6 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"X-CSRF-Token: $3\" -H 'Content-Type: application/json' -H \"Cookie: _uid=$1;__client_id=$2\" --data-binary @\"$f\" -w '|%{http_code}' \"https://www.luogu.com.cn/$4$5\"", "luogu-paste-write", uid, clientId, csrfToken, target, query, httpMethod]
    onStarted: {
      write(payloadBase64 + "\n")
      payloadBase64 = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.splitHttpCode(text)
        var ok = Model.writeResponseSucceeded(parsed.body, parsed.code)
        var result = Model.parsePasteWrite(parsed.body)
        pasteWriteProc.resultId = result.id
        var deleting = pasteWriteProc.httpMethod === "DELETE"
        if (ok && (result.id !== "" || deleting)) {
          root.pasteWriteStatus = deleting
            ? "已删除 /paste/" + result.id
            : (root.pasteComposerMode === "edit"
                ? "已保存"
                : "已创建 /paste/" + result.id + "（链接已复制）")
          if (!deleting && root.pasteComposerMode === "create") root.copyToClipboard("https://www.luogu.com.cn/paste/" + result.id)
          if (!deleting) root.pasteComposerOpen = false
        } else {
          root.pasteWriteStatus = "失败：" + (result.message !== "" ? result.message : Model.writeFailureMessage(parsed.code, parsed.body))
          if (String(root.pasteWriteStatus).indexOf("验证码") >= 0) root.refreshPasteCaptcha()
        }
      }
    }
    onExited: function(exitCode) {
      var wasDelete = pasteWriteProc.httpMethod === "DELETE"
      root.pasteSaving = false
      pasteWriteProc.httpMethod = "POST"
      pasteWriteProc.query = ""
      root.loadPastes(false)
      if (wasDelete) {
        root.closePasteDetail()
        pasteWriteProc.resultId = ""
        return
      }
      if (pasteWriteProc.resultId !== "") {
        root.openPasteDetail(pasteWriteProc.resultId)
        pasteWriteProc.resultId = ""
      }
    }
  }

  Process {
    id: pasteListProc
    property int page: 1
    property bool append: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parsePasteList(String(text || ""))
        root.pasteItems = pasteListProc.append ? root.pasteItems.concat(parsed.items) : parsed.items
        root.pasteCount = parsed.count
        root.pastePage = pasteListProc.append ? pasteListProc.page : 1
        root.pasteHasMore = parsed.items.length >= parsed.perPage
        root.pasteLoading = false
      }
    }
    onExited: function(exitCode) { root.pasteLoading = false }
  }

  Process {
    id: pasteDetailProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parsePaste(String(text || ""))
        root.pasteDetail = parsed.id === "" ? null : parsed
        root.pasteDetailLoading = false
      }
    }
    onExited: function(exitCode) { root.pasteDetailLoading = false }
  }

  // 个人信息写回：走 stdin 传 base64（同交题那套，避免引号问题）
  Process {
    id: userSpaceProc
    property string payloadBase64: ""
    stdinEnabled: true
    property bool succeeded: false
    property string errorMessage: ""
    command: ["sh", "-c", "set -eu; IFS= read -r encoded; f=$(mktemp); trap 'rm -f \"$f\"' EXIT; printf '%s' \"$encoded\" | base64 -d > \"$f\"; curl -sS --max-time 20 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/user/setting' -H \"X-CSRF-Token: $3\" -H 'Content-Type: application/json' -H \"Cookie: _uid=$1;__client_id=$2\" --data-binary @\"$f\" -w '|%{http_code}' 'https://www.luogu.com.cn/user/setting/userSpace'", "luogu-userspace", uid, clientId, csrfToken]
    onStarted: {
      write(payloadBase64 + "\n")
      payloadBase64 = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.splitHttpCode(text)
        userSpaceProc.succeeded = root.writeResponseSucceeded(parsed.body, parsed.code)
        userSpaceProc.errorMessage = root.writeFailureMessage(parsed.code, parsed.body)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "" && userSpaceProc.errorMessage === "") userSpaceProc.errorMessage = message.slice(0, 160)
      }
    }
    onExited: function(exitCode) {
      root.userSpaceSaving = false
      if (exitCode === 0 && succeeded) {
        root.userSpaceStatus = "已保存"
        root.refresh()
      } else {
        root.userSpaceStatus = "保存失败：" + (errorMessage || "请稍后重试")
      }
    }
  }

  Process {
    id: accountPrizeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.accountPrizes = Model.parsePrizeSettings(String(text || ""))
        root.accountDone()
      }
    }
    onExited: function(exitCode) { root.accountDone() }
  }

  Process {
    id: accountSecurityProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.accountSecurity = Model.parseAccountSecurity(String(text || ""))
        root.accountDone()
      }
    }
    onExited: function(exitCode) { root.accountDone() }
  }

  Process {
    id: accountBindingsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.accountBindings = Model.parseAccountBindings(String(text || ""))
        root.accountDone()
      }
    }
    onExited: function(exitCode) { root.accountDone() }
  }

  // One search box covers both cases: Luogu matches a numeric keyword against
  // the uid itself and anything else against the user name.
  Process {
    id: chatSearchProc
    property string keyword: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.chatSearching = false
        root.chatSearchQueried = chatSearchProc.keyword
        root.chatSearchResults = Model.parseUserSearch(String(text || ""))
      }
    }
    onExited: function(exitCode) { root.chatSearching = false }
  }

  Process {
    id: postProcWrite
    property string title: ""
    property string forum: "P"
    property string captcha: ""
    property string content: ""
    property bool succeeded: false
    property string errorMessage: ""
    property bool problemContext: false
    command: ["sh", "-c", "set -eu; payload=$(jq -nc --arg captcha \"$4\" --arg content \"$6\" --arg title \"$5\" --arg forum \"$7\" '{captcha:$captcha,content:$content,title:$title,forum:$forum}'); curl -sS --max-time 15 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"X-CSRF-Token: $3\" -H 'Content-Type: application/json' -H \"Cookie: _uid=$1;__client_id=$2\" -d \"$payload\" -w '|%{http_code}' 'https://www.luogu.com.cn/api/discuss/post'", "luogu-post", uid, clientId, csrfToken, captcha, title, content, forum]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.splitHttpCode(text)
        postProcWrite.succeeded = root.writeResponseSucceeded(parsed.body, parsed.code)
        if (postProcWrite.errorMessage === "") postProcWrite.errorMessage = root.writeFailureMessage(parsed.code, parsed.body)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "" && postProcWrite.errorMessage === "") postProcWrite.errorMessage = message.slice(0, 160)
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && succeeded) {
        if (problemContext) {
          root.problemPostTitleDraft = ""
          root.problemPostContentDraft = ""
          root.problemPostCaptchaDraft = ""
          root.problemDiscussionEditorOpen = false
          root.finishWrite("题目讨论已发布")
          root.loadProblemPosts(1)
        } else {
          root.postTitleDraft = ""
          root.postContentDraft = ""
          root.postCaptchaDraft = ""
          root.postEditorOpen = false
          root.finishWrite("帖子已发布")
        }
      } else {
        root.failWrite(problemContext ? "题目讨论发布失败" : "帖子发布失败", errorMessage, "请检查验证码或发帖权限")
        // A captcha is single use: whatever the reason, the typed code cannot be
        // sent again, so hand the user a fresh image right away.
        if (String(errorMessage).indexOf("验证码") >= 0) root.requestPostCaptcha()
      }
    }
  }

  Process {
    id: replyProc
    property string postId: ""
    property string captcha: ""
    property string content: ""
    property bool succeeded: false
    property string errorMessage: ""
    command: ["sh", "-c", "set -eu; payload=$(jq -nc --arg captcha \"$4\" --arg content \"$5\" '{captcha:$captcha,content:$content}'); curl -sS --max-time 15 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"X-CSRF-Token: $3\" -H 'Content-Type: application/json' -H \"Cookie: _uid=$1;__client_id=$2\" -d \"$payload\" -w '|%{http_code}' \"https://www.luogu.com.cn/api/discuss/reply/$6\"", "luogu-reply", uid, clientId, csrfToken, captcha, content, postId]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.splitHttpCode(text)
        replyProc.succeeded = root.writeResponseSucceeded(parsed.body, parsed.code)
        if (replyProc.errorMessage === "") replyProc.errorMessage = root.writeFailureMessage(parsed.code, parsed.body)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "" && replyProc.errorMessage === "") replyProc.errorMessage = message.slice(0, 160)
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && succeeded) {
        root.replyDraft = ""
        root.replyCaptcha = ""
        root.finishWrite("回复已发表")
        // Re-read the open thread so the reply shows up where it was written.
        if (root.postDetail !== null) { root.postReplyPage = 1; root.loadPostPage(1) }
      } else {
        root.failWrite("回复失败", errorMessage, "请检查验证码、帖子 ID 或权限")
        if (String(errorMessage).indexOf("验证码") >= 0) root.requestReplyCaptcha()
      }
    }
  }

  Process {
    id: captchaProc
    property bool loginReady: false
    // 登录用的 cookie jar 放在**私有目录**里（0700）而不是 /tmp 的固定路径：
    // /tmp 是全局可读的，common umask 下 jar 会是 0644 —— 同机其他账号能读到里面
    // 的会话 cookie。这里 umask 077 + 显式 chmod 700，登录结束后由下一个命令删掉。
    command: ["sh", "-c", "set -eu; umask 077; login_dir=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/luogu-login\"; mkdir -p \"$login_dir\"; chmod 700 \"$login_dir\"; jar=\"$login_dir/cookies.txt\"; rm -f \"$jar\"; page=$(curl -fsS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -c \"$jar\" 'https://www.luogu.com.cn/auth/login'); csrf=$(printf '%s' \"$page\" | sed -n 's/.*meta name=\"csrf-token\" content=\"\\([^\"]*\\\)\".*/\\1/p' | head -1); image=$(curl -fsS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'Cache-Control: no-cache' -H 'Referer: https://www.luogu.com.cn/' -b \"$jar\" \"https://www.luogu.com.cn/lg4/captcha?_t=$(date +%s%N)\" | base64 -w0); jq -nc --arg csrf \"$csrf\" --arg image \"$image\" '{csrfToken:$csrf,captcha:$image}'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(String(text || ""))
          root.loginCsrfToken = String(result.csrfToken || "")
          root.captchaImage = String(result.captcha || "")
          captchaProc.loginReady = root.loginCsrfToken !== "" && root.captchaImage !== ""
          root.statusText = captchaProc.loginReady ? "验证码已更新" : "验证码获取失败"
        } catch (error) {
          captchaProc.loginReady = false
          root.statusText = "验证码获取失败"
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        captchaProc.loginReady = false
        root.statusText = "验证码获取失败"
      }
    }
  }

  // Discussion captcha, used by both the post and the reply form. Each form gets
  // its own fetch because a captcha is consumed by the attempt that submits it,
  // so sharing one image would make the second form fail. The response is a
  // session-bound JPEG (the login captcha is a different endpoint and format),
  // so the mime type is carried through instead of being assumed.
  Process {
    id: postCaptchaProc
    command: ["sh", "-c", "set -eu; out=$(mktemp); trap 'rm -f \"$out\"' EXIT; type=$(curl -sS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'Cache-Control: no-cache' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"Cookie: _uid=$1;__client_id=$2\" -o \"$out\" -w '%{content_type}' \"https://www.luogu.com.cn/api/verify/captcha?_t=$(date +%s%N)\"); data=$(base64 -w0 \"$out\"); jq -nc --arg type \"$type\" --arg data \"$data\" '{mime:$type,data:$data}'", "luogu-post-captcha", uid, clientId]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(String(text || ""))
          var data = String(result.data || "")
          var mime = String(result.mime || "image/jpeg")
          if (data === "") throw new Error("empty captcha")
          root.postCaptchaImage = "data:" + mime + ";base64," + data
          root.postCaptchaReady = true
          root.statusText = "验证码已获取"
          // Both forms need their own captcha (a captcha is consumed by the
          // attempt that submits it). Fetch the reply one right after this
          // succeeds so the two requests never overlap.
          if (root.detailPage === "posts" && root.replyCaptchaImage === "" && !replyCaptchaProc.running) root.requestReplyCaptcha()
        } catch (error) {
          root.postCaptchaReady = false
          root.postCaptchaImage = ""
          root.statusText = "验证码获取失败，可点图片重试"
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        postCaptchaReady = false
        postCaptchaImage = ""
        statusText = "验证码获取失败，可点图片重试"
      }
    }
  }

  Process {
    id: replyCaptchaProc
    command: ["sh", "-c", "set -eu; out=$(mktemp); trap 'rm -f \"$out\"' EXIT; type=$(curl -sS --max-time 12 -A 'vscode-luogu@4.17.1' -H 'Cache-Control: no-cache' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H \"Cookie: _uid=$1;__client_id=$2\" -o \"$out\" -w '%{content_type}' \"https://www.luogu.com.cn/api/verify/captcha?_t=$(date +%s%N)\"); data=$(base64 -w0 \"$out\"); jq -nc --arg type \"$type\" --arg data \"$data\" '{mime:$type,data:$data}'", "luogu-reply-captcha", uid, clientId]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(String(text || ""))
          var data = String(result.data || "")
          var mime = String(result.mime || "image/jpeg")
          if (data === "") throw new Error("empty captcha")
          root.replyCaptchaImage = "data:" + mime + ";base64," + data
          root.replyCaptchaReady = true
        } catch (error) {
          root.replyCaptchaReady = false
          root.replyCaptchaImage = ""
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        replyCaptchaReady = false
        replyCaptchaImage = ""
      }
    }
  }

  Process {
    id: passwordLoginProc
    property string username: ""
    property string password: ""
    property string captcha: ""
    stdinEnabled: true
    command: ["sh", "-c", "set -eu; umask 077; username=''; password=''; captcha=''; IFS= read -r username; IFS= read -r password; IFS= read -r captcha; login_dir=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/luogu-login\"; jar=\"$login_dir/cookies.txt\"; headers=$(mktemp); body=$(mktemp); trap 'rm -f \"$headers\" \"$body\" \"$jar\"; rmdir \"$login_dir\" 2>/dev/null || true' EXIT; payload=$(jq -nc --arg username \"$username\" --arg password \"$password\" --arg captcha \"$captcha\" '{username:$username,password:$password,captcha:$captcha}'); curl -sS --max-time 15 -A 'vscode-luogu@4.17.1' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.luogu.com.cn/' -H 'Content-Type: application/json' -H \"X-CSRF-Token: $1\" -b \"$jar\" -c \"$jar\" -d \"$payload\" -D \"$headers\" 'https://www.luogu.com.cn/do-auth/password' -o \"$body\"; uid=$(sed -n 's/^set-cookie:.*_uid=\\([^;]*\\).*/\\1/ip' \"$headers\" | tail -1); client=$(sed -n 's/^set-cookie:.*__client_id=\\([^;]*\\).*/\\1/ip' \"$headers\" | tail -1); jq -nc --arg uid \"$uid\" --arg clientId \"$client\" --rawfile body \"$body\" '{uid:$uid,clientId:$clientId,body:$body}'", "login", loginCsrfToken]
    onStarted: {
      write(username + "\n")
      write(password + "\n")
      write(captcha + "\n")
      password = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(String(text || ""))
          var uidValue = String(result.uid || "")
          var clientValue = String(result.clientId || "")
          var responseBody = String(result.body || "")
          if (uidValue !== "" && clientValue !== "") {
            root.uid = uidValue
            root.clientId = clientValue
            root.saveCredentials()
            root.loginPassword = ""
            root.loginCaptcha = ""
          } else if (responseBody.indexOf("二次验证") >= 0 || responseBody.indexOf("locked") >= 0) {
            root.statusText = "账号需要二次验证，暂未完成"
          } else {
            root.statusText = "密码登录失败，请检查账号、密码或验证码"
            root.requestCaptcha()
          }
        } catch (error) {
          root.statusText = "密码登录响应解析失败"
          root.requestCaptcha()
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.statusText = "密码登录请求失败"
    }
  }

  // Secret Service is preferred, but some minimal Omarchy sessions do not
  // expose a D-Bus secret service to Quickshell. Keep a 0600 fallback so the
  // login remains persistent without putting credentials in shell.json.
  Process {
    id: fileRead
    command: ["sh", "-c", "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/luogu-session.json\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyCredentials(text)
    }
  }

  Process {
    id: secretStore
    property string secret: ""
    stdinEnabled: true
    command: ["secret-tool", "store", "--label=Omarchy Luogu session", "service", "omarchy-luogu", "account", "default"]
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        statusText = "登录信息已保存"
      }
    }
  }

  Process {
    id: secretClear
    command: ["secret-tool", "clear", "service", "omarchy-luogu", "account", "default"]
  }

  Process {
    id: fileClear
    command: ["sh", "-c", "state_dir=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy\"; rm -f \"$state_dir/luogu-session.json\""]
  }

  Process {
    id: fileStore
    property string secret: ""
    stdinEnabled: true
    command: ["sh", "-c", "umask 077; state_dir=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy\"; mkdir -p \"$state_dir\"; cat > \"$state_dir/luogu-session.json\""]
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.statusText = "登录信息保存失败"
    }
  }

  // ---- 本地代码草稿 --------------------------------------------------------
  // 洛谷只会给你"上次提交过的代码"，正在写、还没交的那份一关窗口就没了。草稿
  // 存在本地一个文件里（{pid: {code, lang, at}}，0600，umask 077），写的时候
  // 先落到同目录临时文件再 mv，避免中断留下半个文件。
  property var problemDrafts: ({})
  property bool problemDraftsReady: false
  property string pendingDraftPayload: ""
  readonly property int problemDraftLimit: 40
  readonly property string draftFileName: "luogu-drafts.json"

  function loadProblemDrafts() {
    if (!draftsRead.running) draftsRead.running = true
  }

  function problemDraftFor(pid) {
    var entry = problemDrafts[String(pid || "")]
    return entry === undefined ? null : entry
  }

  function storeProblemDraft(pid, code, languageId) {
    var key = String(pid || "")
    if (key === "") return
    var next = {}
    for (var existing in problemDrafts) if (existing !== key) next[existing] = problemDrafts[existing]
    // 清空代码 = 删掉这份草稿（否则"恢复"会把一片空白当成你的进度）
    if (String(code || "").trim() !== "") {
      next[key] = { code: code, lang: Number(languageId) || 0, at: Math.floor(Date.now() / 1000) }
    }
    var keys = Object.keys(next)
    keys.sort(function(a, b) { return (Number(next[b].at) || 0) - (Number(next[a].at) || 0) })
    var trimmed = {}
    for (var i = 0; i < keys.length && i < problemDraftLimit; i++) trimmed[keys[i]] = next[keys[i]]
    problemDrafts = trimmed
    writeProblemDrafts()
  }

  function writeProblemDrafts() {
    var payload = JSON.stringify(problemDrafts)
    if (draftsWrite.running) { pendingDraftPayload = payload; return }
    draftsWrite.payload = payload
    draftsWrite.running = true
  }

  Process {
    id: draftsRead
    command: ["sh", "-c", "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/luogu-drafts.json\" 2>/dev/null || true", "luogu-drafts-read"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        var parsed = null
        if (raw !== "") {
          try { parsed = JSON.parse(raw) } catch (error) { parsed = null }
        }
        root.problemDrafts = (parsed && typeof parsed === "object") ? parsed : ({})
        root.problemDraftsReady = true
        if (parsed === null && raw !== "") root.statusText = "本地草稿文件无法解析，已按空处理"
      }
    }
  }

  Process {
    id: draftsWrite
    property string payload: ""
    stdinEnabled: true
    command: ["sh", "-c", "set -eu; umask 077; state_dir=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy\"; mkdir -p \"$state_dir\"; target=\"$state_dir/luogu-drafts.json\"; IFS= read -r encoded; tmp=$(mktemp \"$state_dir/.luogu-drafts.XXXXXX\"); trap 'rm -f \"$tmp\"' EXIT; printf '%s' \"$encoded\" | base64 -d > \"$tmp\"; chmod 600 \"$tmp\"; mv \"$tmp\" \"$target\"", "luogu-drafts-write"]
    onStarted: {
      write(Model.utf8Base64(payload) + "\n")
      payload = ""
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.statusText = "本地草稿保存失败"
      if (root.pendingDraftPayload !== "") {
        draftsWrite.payload = root.pendingDraftPayload
        root.pendingDraftPayload = ""
        draftsWrite.running = true
      }
    }
  }

  Process {
    id: apiProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loading = false
        var raw = String(text || "").trim()
        if (!raw) {
          root.statusText = "洛谷没有返回数据"
          return
        }
        try { root.applyProfile(raw) }
        catch (error) { root.statusText = "洛谷数据解析失败" }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text || "").trim() !== "") root.statusText = "洛谷连接失败"
      }
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0 && root.statusText === "正在连接洛谷…") root.statusText = "洛谷连接失败"
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    // Follow the actual bar slot instead of centering the panel on screen.
    // KeyboardPanel uses anchorItem plus the bar section to choose the
    // correct left/center/right placement automatically.
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    Flickable {
      anchors.fill: parent
      contentWidth: contentColumn.width
      contentHeight: contentColumn.implicitHeight
      clip: true

      Column {
        id: contentColumn
        width: Style.space(390)
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(14)

          Text {
            text: "洛"
            color: Color.accent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.title * 2
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              text: root.profile.name === "" ? "洛谷" : root.profile.name
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: root.statusText + (root.profile.uid > 0 && (root.unreadMessages + root.unreadNotifications) > 0 ? " · 消息 " + (root.unreadMessages + root.unreadNotifications) : "")
              width: Style.space(300)
              elide: Text.ElideRight
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        Rectangle { width: parent.width; height: Style.spacing.hairline; color: root.contentForeground; opacity: 0.14 }

        Column {
          visible: root.profile.uid > 0
          width: parent.width
          spacing: Style.space(7)

          Text { text: "PROFILE"; color: Qt.darker(root.contentForeground, 1.7); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
          Row {
            spacing: Style.space(18)
            Text { text: "咕值  " + root.profile.guzhi; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true }
            Text { text: "等级分  " + (root.profile.elo > 0 ? root.profile.elo : "—"); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body }
            Text { text: "排名  " + root.formatRanking(root.profile.ranking); color: Qt.darker(root.contentForeground, 1.3); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
          }
          Text {
            text: "基础 " + root.profile.guScores.basic + "  ·  练习 " + root.profile.guScores.practice + "  ·  社区 " + root.profile.guScores.social + "  ·  比赛 " + root.profile.guScores.contest + "  ·  成就 " + root.profile.guScores.prize
            color: Qt.darker(root.contentForeground, 1.45)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Column {
          visible: root.profile.uid > 0 || root.contests.length > 0 || root.contestLoading
          width: parent.width
          spacing: Style.space(7)

          Row {
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            Text { width: parent.width - Style.space(72); text: "RECENT CONTESTS"; color: Qt.darker(root.contentForeground, 1.7); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
            Text { width: Style.space(72); horizontalAlignment: Text.AlignRight; text: root.contestLoading ? "读取中…" : (root.contests.length > 0 ? root.contests.length + " 场" : "暂无"); color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
          }

          ListView {
            id: contestList
            width: parent.width
            height: Math.min(root.contests.length, 4) * Style.space(59)
            spacing: Style.space(5)
            clip: true
            interactive: false
            model: root.contests.slice(0, 4)
            delegate: Rectangle {
              required property var modelData
              required property int index
              readonly property var contestData: modelData
              width: contestList.width
              height: Style.space(54)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)

              Column {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(9)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Row {
                  width: parent.width
                  Text { width: parent.width - Style.space(76); text: contestData.name; elide: Text.ElideRight; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Text { width: Style.space(76); horizontalAlignment: Text.AlignRight; text: Model.contestStatus(contestData); color: Model.contestStatusColor(contestData) === "accent" ? Color.accent : (Model.contestStatusColor(contestData) === "muted" ? Qt.darker(root.contentForeground, 1.5) : root.contentForeground); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
                Row {
                  width: parent.width
                  Text { width: parent.width - Style.space(100); text: Model.formatContestTime(contestData.startTime) + " - " + Model.formatContestTime(contestData.endTime); color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  Text { width: Style.space(100); horizontalAlignment: Text.AlignRight; text: "报名 " + Model.contestSignupLabel(contestData); color: contestData.joined === true ? Color.accent : Qt.darker(root.contentForeground, 1.35); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openContestDetail(contestData.id) }
            }
          }

          // 这一段本来就在这个「最近比赛」区块里，之前被误粘到了洛谷中心私信页的
          // 末尾（在那边既没用又会把私信页撑高），现在放回它该在的地方。
          Text {
            visible: root.contests.length > 4
            width: parent.width
            text: "还有 " + (root.contests.length - 4) + " 场比赛，打开详细信息查看全部"
            color: Color.accent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Column {
          visible: !root.credentialsReady
          width: parent.width
          spacing: Style.space(8)
          Text { text: "正在恢复洛谷会话…"; color: Qt.darker(root.contentForeground, 1.25); font.family: root.contentFontFamily; font.pixelSize: Style.font.body }
        }

        Column {
          visible: root.credentialsReady && root.profile.uid <= 0
          width: parent.width
          spacing: Style.space(8)

          Text { text: "LOGIN WITH COOKIE"; color: Qt.darker(root.contentForeground, 1.7); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
          Row {
            spacing: Style.space(6)
            Rectangle {
              width: Style.space(120)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: root.loginMode === "cookie" ? Color.accent : "transparent"
              Text {
                anchors.centerIn: parent
                text: "Cookie 登录"
                color: root.loginMode === "cookie" ? Color.background : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                anchors.fill: parent
                onClicked: root.loginMode = "cookie"
              }
            }

            Rectangle {
              width: Style.space(120)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: root.loginMode === "password" ? Color.accent : "transparent"
              Text {
                anchors.centerIn: parent
                text: "密码登录"
                color: root.loginMode === "password" ? Color.background : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                anchors.fill: parent
                onClicked: {
                  root.loginMode = "password"
                  root.requestCaptcha()
                }
              }
            }
          }

          Column {
            visible: root.loginMode === "cookie"
            width: parent.width
            spacing: Style.space(8)
            TextField { id: uidField; width: parent.width; placeholderText: "洛谷 UID"; text: root.uid; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.uid = text }
            TextField { id: clientField; width: parent.width; placeholderText: "__client_id"; text: root.clientId; echoMode: TextInput.Password; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.clientId = text }
            Rectangle {
              width: parent.width
              height: Style.space(34)
              radius: Style.cornerRadius
              color: saveMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
              Text { anchors.centerIn: parent; text: "保存并验证"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { id: saveMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.saveCredentials() }
            }
          }

          Column {
            visible: root.loginMode === "password"
            width: parent.width
            spacing: Style.space(8)
            TextField { width: parent.width; placeholderText: "用户名或手机号（手机号请加 +86）"; text: root.loginUsername; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.loginUsername = text }
            Text { text: "中国大陆手机号可直接输入 11 位数字，插件会自动补 +86；其他地区请手动填写地区码。"; color: Qt.darker(root.contentForeground, 1.55); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; width: parent.width }
            TextField { width: parent.width; placeholderText: "密码"; text: root.loginPassword; echoMode: TextInput.Password; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.loginPassword = text }
            Row {
              spacing: Style.space(8)
              TextField { width: Style.space(170); placeholderText: "验证码"; text: root.loginCaptcha; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.loginCaptcha = text }
              Image { width: Style.space(120); height: Style.space(42); fillMode: Image.PreserveAspectFit; source: root.captchaImage === "" ? "" : "data:image/png;base64," + root.captchaImage }
              Rectangle {
                width: Style.space(30)
                height: Style.space(30)
                radius: Style.cornerRadius
                color: captchaMouse.containsMouse
                  ? Style.hoverFillFor(root.contentForeground, Color.accent)
                  : "transparent"
                Text {
                  anchors.centerIn: parent
                  text: "↻"
                  color: root.contentForeground
                  font.pixelSize: Style.font.body
                }
                MouseArea {
                  id: captchaMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: root.requestCaptcha()
                }
              }
            }
            Rectangle {
              width: parent.width
              height: Style.space(34)
              radius: Style.cornerRadius
              color: loginMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
              Text { anchors.centerIn: parent; text: "登录"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { id: loginMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.loginWithPassword() }
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(10)
          Rectangle {
            width: Style.space(88)
            height: Style.space(30)
            radius: Style.cornerRadius
            color: refreshMouse.containsMouse
              ? Style.hoverFillFor(root.contentForeground, Color.accent)
              : "transparent"

            Text {
              anchors.centerIn: parent
              text: root.loading ? "读取中…" : "刷新"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: refreshMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.refresh()
            }
          }

          Rectangle {
            width: Style.space(108)
            height: Style.space(30)
            visible: root.profile.uid > 0
            radius: Style.cornerRadius
            color: detailMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
            Text { anchors.centerIn: parent; text: "详细信息"; color: detailMouse.containsMouse ? Color.background : Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
            MouseArea { id: detailMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openDetails() }
          }

          Rectangle {
            width: Style.space(88)
            height: Style.space(30)
            radius: Style.cornerRadius
            visible: root.profile.uid > 0
            color: logoutMouse.containsMouse
              ? Style.hoverFillFor(root.contentForeground, Color.accent)
              : "transparent"

            Text {
              anchors.centerIn: parent
              text: "退出登录"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: logoutMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                root.logout()
              }
            }
          }
        }
      }
    }
  }

  // The details window is built fresh for every open and destroyed on close.
  //
  // Quickshell does not re-map a FloatingWindow after the compositor has closed
  // it: `visible = true` afterwards is accepted and then silently ignored, so a
  // single long-lived instance opens exactly once per shell session and looks
  // dead afterwards ("详细信息 点不开"). Since this window has no decorations and
  // no close button, SUPER+Q — a compositor-side close — is how it normally gets
  // dismissed, which is precisely the case that bricks it. Recreating the object
  // per open avoids the dead state entirely.
  Loader {
    id: detailLoader
    active: root.detailOpen
    sourceComponent: detailWindowComponent
  }

  Component {
    id: detailWindowComponent

    FloatingWindow {
      id: detailWindow
      title: "洛谷中心"
      visible: true
      color: Color.background
      implicitWidth: 980
      implicitHeight: 740
      minimumSize: Qt.size(760, 560)

      // Fires for a compositor-side close too (SUPER+Q), which drops the flag and
      // destroys this object through the loader above.
      onVisibleChanged: {
        if (!visible) root.detailOpen = false
      }
    Row {
      id: detailLayout
      anchors.fill: parent
      anchors.margins: Style.space(24)
      spacing: Style.space(18)

      // 侧边栏是窗口自己的导航，固定在原地；只有右边的内容区滚动。
      Rectangle {
        id: detailSidebar
        width: Style.space(150)
        height: parent.height
        radius: Style.cornerRadius
        color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.045)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(12)
          spacing: Style.space(6)
          Text { text: "LUOGU"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1.5; leftPadding: Style.space(6) }
            Repeater {
              model: [
                { key: "overview", label: "概览" },
                { key: "contest", label: "比赛" },
                { key: "problems", label: "题库" },
                { key: "benben", label: "犇犇" },
                { key: "posts", label: "帖子" },
                { key: "chat", label: "私信" },
                { key: "notice", label: "通知" },
                { key: "paste", label: "剪贴板" },
                { key: "account", label: "设置" }
              ]
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: Style.space(34)
                radius: Style.cornerRadius
                color: root.detailPage === modelData.key
                  ? Color.accent
                  : (detailNavHit.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent")
                Text { anchors.left: parent.left; anchors.leftMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: root.detailPage === modelData.key ? Color.background : root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                MouseArea { id: detailNavHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openDetailPage(modelData.key) }
              }
            }
            Item { width: 1; height: 1 }
            Text { text: "未读  " + (root.unreadMessages + root.unreadNotifications); color: Qt.darker(root.contentForeground, 1.35); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; leftPadding: Style.space(6) }
          }
        }

      Flickable {
        id: detailFlick
        width: parent.width - detailSidebar.width - detailLayout.spacing
        height: parent.height
        clip: true
        contentWidth: width
        // 私信页是应用式布局：它自己占满可视区并在内部滚动，所以内容高度直接
        // 取可视区高度。其余页面仍按内容高度（可滚动）。
        contentHeight: root.detailPage === "chat" ? height : detailColumn.implicitHeight

        // Qt 默认的滚轮步进对一篇 6000px 的长帖太小，而且这台机器触控板的
        // scroll_factor 是 0.4（Omarchy 默认），两指滑动到这里只剩 40% 速度。
        // 所以自己算步进：滚轮一格走 wheelStep 像素，触控板把已经缩水的
        // pixelDelta 乘回去（0.4 × 2.5 ≈ 1.0，即恢复到正常手感）。
        // 两个数字都可以直接调；内层 ListView（私信）会先消费滚轮事件，不受影响。
        property int wheelStep: 220
        property real wheelPixelFactor: 5.0
        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            var step = wheelStepFor(event, detailFlick.wheelPixelFactor, detailFlick.wheelStep)
            if (step !== 0) event.accepted = true
            applyWheel(detailFlick, step)
          }
        }

      Column {
        id: detailColumn
        width: detailFlick.width
        spacing: Style.space(22)

        Text {
          visible: root.actionStatusText !== ""
          width: parent.width
          text: root.actionStatusText
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: root.actionStatusText.indexOf("失败") >= 0 ? Color.urgent : Color.accent
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Row {
          visible: root.detailPage === "overview"
          width: parent.width
          Text {
            width: parent.width - Style.space(130)
            text: "洛谷中心"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.iconLarge
            font.bold: true
          }
          Text {
            width: Style.space(130)
            horizontalAlignment: Text.AlignRight
            text: root.profile.name + " · UID " + root.profile.uid
            color: Qt.darker(root.contentForeground, 1.35)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Row {
          visible: root.detailPage === "overview"
          width: parent.width
          spacing: Style.space(10)
          Repeater {
            model: [
              { label: "咕值", value: root.profile.guzhi },
              { label: "通过题目", value: root.profile.passedProblems },
              { label: "提交题目", value: root.profile.submittedProblems },
              { label: "当前等级分", value: root.profile.elo > 0 ? root.profile.elo : "—" }
            ]
            delegate: Rectangle {
              required property var modelData
              width: (detailColumn.width - Style.space(30)) / 4
              height: Style.space(76)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.07)
              Column {
                anchors.centerIn: parent
                spacing: Style.space(5)
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
              }
            }
          }
        }

        // 身份卡：头像 + 名字（按洛谷的名字配色）+ 签名/简介 + 关注粉丝 / 入坑天数 / 等级
        Rectangle {
          visible: root.detailPage === "overview"
          width: parent.width
          height: identityBody.implicitHeight + Style.space(24)
          radius: Style.cornerRadius
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)

          Row {
            id: identityBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(12)
            spacing: Style.space(14)

            Rectangle {
              width: Style.space(64)
              height: Style.space(64)
              radius: Style.space(10)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
              Image {
                anchors.fill: parent
                anchors.margins: Style.space(1)
                source: root.profile.avatar
                sourceSize.width: 256
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: root.profile.avatar !== "" && status === Image.Ready
              }
              Text {
                anchors.centerIn: parent
                visible: root.profile.avatar === ""
                text: "洛"
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.heading
              }
            }

            Column {
              width: parent.width - Style.space(64) - Style.space(14)
              spacing: Style.space(4)

              Row {
                width: parent.width
                spacing: Style.space(6)
                Text {
                  width: Math.max(Style.space(60), parent.width - Style.space(60))
                  text: root.profile.name || "未登录"
                  elide: Text.ElideRight
                  color: Model.userColor({ color: root.profile.color }, root.contentForeground)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.heading
                  font.bold: true
                }
                Text {
                  width: Style.space(54)
                  horizontalAlignment: Text.AlignRight
                  text: root.profile.verified ? "✓ 认证" : ""
                  color: Model.userColor({ color: root.profile.color }, Color.accent)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                width: parent.width
                visible: root.profile.introduction !== "" || root.profile.slogan !== ""
                text: root.profile.introduction !== "" ? root.profile.introduction : root.profile.slogan
                elide: Text.ElideRight
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                width: parent.width
                text: "UID " + root.profile.uid
                  + "   排名 " + root.formatRanking(root.profile.ranking)
                  + "   关注 " + root.profile.followingCount
                  + "   粉丝 " + root.profile.followerCount
                wrapMode: Text.WordWrap
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                width: parent.width
                text: (root.profile.registerTime > 0
                        ? "入坑 " + Math.max(0, Math.floor((Date.now() / 1000 - root.profile.registerTime) / 86400)) + " 天（" + Model.formatChatTime(root.profile.registerTime) + "）"
                        : "")
                  + (root.profile.ccfLevel > 0 ? "   CCF " + root.profile.ccfLevel + " 级" : "")
                  + (root.profile.xcpcLevel > 0 ? "   XCPC " + root.profile.xcpcLevel + " 级" : "")
                wrapMode: Text.WordWrap
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                width: parent.width
                visible: root.profile.elo > 0
                text: "等级分 " + root.profile.elo
                  + (root.profile.eloDelta !== 0 ? "（" + (root.profile.eloDelta > 0 ? "+" : "") + root.profile.eloDelta + "）" : "")
                  + (root.profile.eloContest !== "" ? "   " + root.profile.eloContest : "")
                elide: Text.ElideRight
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // 获奖记录（接口的 data.prizes，例如 CSP-J 一等奖 304 分 #3512）
        Column {
          visible: root.detailPage === "overview" && root.profile.prizes.length > 0
          width: parent.width
          spacing: Style.space(6)

          Text { text: "获奖"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }

          Repeater {
            model: root.profile.prizes
            delegate: Rectangle {
              required property var modelData
              width: parent.width
              height: Style.space(38)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
              Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)
                Text { width: Style.space(38); text: modelData.year > 0 ? String(modelData.year) : ""; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                Text { width: Style.space(74); elide: Text.ElideRight; text: modelData.contest + (modelData.event !== "" ? " " + modelData.event : ""); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Text { width: Style.space(76); text: modelData.prize; color: Model.userColor({ color: root.profile.color }, Color.accent); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                Text {
                  width: parent.width - Style.space(38) - Style.space(74) - Style.space(76) - Style.space(32)
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideRight
                  text: (modelData.score > 0 ? modelData.score + " 分" : "") + (modelData.rank > 0 ? "   #" + modelData.rank : "")
                  color: Qt.darker(root.contentForeground, 1.45)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }

        Column {
          visible: root.detailPage === "overview"
          width: parent.width
          spacing: Style.space(8)
          Text { text: "做题热力图"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
          Rectangle {
            width: Style.space(26 * 12 + 25 * 4 + 32)
            anchors.horizontalCenter: parent.horizontalCenter
            height: Style.space(150)
            radius: Style.cornerRadius
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.045)
            Canvas {
              anchors.fill: parent
              anchors.margins: Style.space(16)
              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cols = 26
                var rows = 7
                var gap = 4
                var cell = Math.max(5, Math.min(16, (width - (cols - 1) * gap) / cols))
                var rawCounts = root.profile.dailyCounts || []
                var countByDate = {}
                for (var d = 0; d < rawCounts.length; d++) {
                  if (rawCounts[d].date) countByDate[rawCounts[d].date] = rawCounts[d]
                }
                var today = new Date()
                today.setHours(0, 0, 0, 0)
                var counts = []
                function pad(value) { return value < 10 ? "0" + value : String(value) }
                function dateKey(date) { return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate()) }
                for (var day = cols * rows - 1; day >= 0; day--) {
                  var target = new Date(today.getTime() - day * 86400000)
                  counts.push(countByDate[dateKey(target)] || { count: 0 })
                }
                var maxCount = 1
                for (var m = 0; m < counts.length; m++) {
                  var candidate = Number(counts[m].count || counts[m].value || counts[m].total || 0)
                  if (candidate > maxCount) maxCount = candidate
                }
                for (var i = 0; i < cols * rows; i++) {
                  var item = counts[i]
                  var value = Number(item.count || item.value || item.total || 0)
                  var ratio = Math.max(0, Math.min(1, value / maxCount))
                  var level = value <= 0 ? 0 : (ratio > 0.75 ? 4 : (ratio > 0.5 ? 3 : (ratio > 0.25 ? 2 : 1)))
                  ctx.fillStyle = root.heatmapColor(level)
                  ctx.fillRect((i / rows | 0) * (cell + gap), (i % rows) * (cell + gap), cell, cell)
                }
              }
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onPositionChanged: function(mouse) {
                var localX = mouse.x - Style.space(16)
                var localY = mouse.y - Style.space(16)
                var cols = 26
                var rows = 7
                var gap = 4
                var gridWidth = width - Style.space(32)
                var cell = Math.max(5, Math.min(16, (gridWidth - (cols - 1) * gap) / cols))
                var col = Math.floor(localX / (cell + gap))
                var row = Math.floor(localY / (cell + gap))
                if (localX < 0 || localY < 0 || col < 0 || col >= cols || row < 0 || row >= rows) root.heatmapHoverIndex = -1
                else {
                  root.heatmapHoverIndex = col * rows + row
                  root.heatmapHoverX = mouse.x
                  root.heatmapHoverY = mouse.y
                }
              }
              onExited: root.heatmapHoverIndex = -1
            }
            Rectangle {
              visible: root.heatmapHoverIndex >= 0
              x: Math.min(parent.width - width - Style.space(8), Math.max(Style.space(8), root.heatmapHoverX + Style.space(8)))
              y: Math.max(Style.space(8), root.heatmapHoverY - height - Style.space(8))
              width: heatmapTooltip.implicitWidth + Style.space(18)
              height: heatmapTooltip.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: "#24292f"
              z: 4
              Text {
                id: heatmapTooltip
                anchors.centerIn: parent
                text: {
                  var info = root.heatmapInfo(root.heatmapHoverIndex)
                  return info.date + "\n提交 " + info.count + " · 通过 " + info.passed
                }
                color: "#f0f6fc"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                lineHeight: 1.2
              }
            }
            Row {
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              anchors.leftMargin: Style.space(16)
              anchors.bottomMargin: Style.space(8)
              spacing: Style.space(4)
              Text { text: "少"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              Repeater {
                model: [0, 1, 2, 3, 4]
                delegate: Rectangle { required property var modelData; width: Style.space(11); height: Style.space(11); radius: 2; color: root.heatmapColor(modelData) }
              }
              Text { text: "多"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
            }
            Text {
              anchors.centerIn: parent
              visible: !root.profile.dailyCounts || root.profile.dailyCounts.length === 0
              text: "洛谷未返回热力图数据"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        Column {
          visible: root.detailPage === "overview"
          width: parent.width
          spacing: Style.space(8)
          Text { text: "等级分趋势"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
          Rectangle {
            width: parent.width
            height: Style.space(170)
            radius: Style.cornerRadius
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.045)
            Canvas {
              anchors.fill: parent
              anchors.margins: Style.space(18)
              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var history = (root.profile.eloHistory || []).slice().reverse()
                if (history.length === 0) return
                var minValue = history[0].rating
                var maxValue = history[0].rating
                for (var i = 1; i < history.length; i++) { minValue = Math.min(minValue, history[i].rating); maxValue = Math.max(maxValue, history[i].rating) }
                if (maxValue === minValue) { maxValue += 1; minValue -= 1 }
                ctx.strokeStyle = Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
                ctx.lineWidth = 1
                for (var grid = 0; grid < 3; grid++) {
                  var gy = grid * height / 2
                  ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
                }
                ctx.strokeStyle = "#5faea4"
                ctx.lineWidth = 3
                ctx.beginPath()
                for (var j = 0; j < history.length; j++) {
                  var x = history.length === 1 ? width / 2 : j * width / (history.length - 1)
                  var y = height - (Number(history[j].rating) - minValue) / (maxValue - minValue) * height
                  if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.stroke()
                ctx.fillStyle = "#8bd5ca"
                for (var k = 0; k < history.length; k++) {
                  var px = history.length === 1 ? width / 2 : k * width / (history.length - 1)
                  var py = height - (Number(history[k].rating) - minValue) / (maxValue - minValue) * height
                  ctx.beginPath(); ctx.arc(px, py, 4, 0, Math.PI * 2); ctx.fill()
                }
              }
            }
            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(18)
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(8)
              visible: root.profile.eloHistory.length > 0 && root.profile.eloHistory.length < 3
              text: "记录较少，参加更多比赛后趋势会更完整"
              color: Qt.darker(root.contentForeground, 1.45)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
            Text { anchors.centerIn: parent; visible: root.profile.eloHistory.length === 0; text: "暂无等级分历史"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
          }
        }

        Row {
          visible: root.detailPage === "notice"
          width: parent.width
          Column {
            visible: root.detailPage === "notice"
            width: parent.width
            spacing: Style.space(10)
            Row {
              width: parent.width
              Text { width: parent.width - Style.space(118); text: "通知中心"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
              Rectangle {
                width: Style.space(118)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: "transparent"
                Text { anchors.centerIn: parent; text: "打开通知中心"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; onClicked: root.openNotifications() }
              }
            }
            Text { visible: root.activityLoading; text: "正在读取通知…"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
            Repeater {
              model: root.notifications
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: noticeBody.implicitHeight + Style.space(22)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.045)
                border.width: 1
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
                Column {
                  id: noticeBody
                  anchors.fill: parent
                  anchors.margins: Style.space(11)
                  spacing: Style.space(5)
                  Text { width: parent.width; text: modelData.title; wrapMode: Text.WordWrap; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Text { text: modelData.content; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
              }
            }
            Text { visible: !root.activityLoading && root.notifications.length === 0; text: "暂无通知，或洛谷暂未返回通知列表"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
          }
        }

        // 私信：左侧是会话列表 / 用户搜索，右侧是对话线程。旧版只是两个裸输入框
        // （"对方 UID" + "发送私信"），既看不到历史也没法确认对方是谁；这里换成
        // 真正的对话框：选会话（或按用户名/UID 搜索）→ 读历史 → 就地回复。
        Column {
          id: chatPage
          visible: root.detailPage === "chat"
          width: parent.width
          spacing: Style.space(10)
          // 高度必须显式给足：私信页是「应用式」布局（内部自己滚），如果只靠
          // 子项隐式高度，外层 Flickable 算出来的内容高度会比实际布局小，
          // 页面底部（含发送框）会被裁掉。
          // 还要减掉自己的 y：detailColumn 顶部的操作状态文字（按下回车后立刻
          // 变成"正在发送私信…"）在列里排在本页上方，一出现就把整页往下推
          // （实测 +39px），发送框正好被推出可视区挡住。减去 y 之后两种状态
          // 都留出同样的 20px 余量。
          height: Math.max(Style.space(240), detailFlick.height - Math.max(0, y))

          Row {
            width: parent.width
            Text { width: parent.width - Style.space(110); text: "私信"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.iconLarge; font.bold: true }
            Rectangle {
              width: Style.space(110)
              height: Style.space(28)
              color: "transparent"
              Text { anchors.centerIn: parent; text: "打开洛谷私信"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; onClicked: root.openMessages() }
            }
          }

          Row {
            id: chatLayout
            width: parent.width
            // 标题行 + 间距之外的空间全部给对话区；不设下限兜底，避免整页超出
            // 可视区导致外层也跟着滚。
            height: Math.max(Style.space(240), chatPage.height - Style.space(38))
            spacing: Style.space(12)

            // ---- 左栏：搜索框 + 会话/搜索结果（共用一个 ListView）----
            Column {
              width: Style.space(236)
              height: parent.height
              spacing: Style.space(6)

              TextField {
                id: chatSearchField
                width: parent.width
                placeholderText: "搜索用户名或 UID"
                text: root.chatSearchKeyword
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                onTextChanged: {
                  root.chatSearchKeyword = text
                  chatSearchTimer.restart()
                }
              }
              Text {
                visible: root.chatSearching
                text: "搜索中…"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                visible: !root.chatSearching && root.chatSearchKeyword.trim() !== "" && root.chatSearchQueried === root.chatSearchKeyword.trim() && root.chatSearchResults.length === 0
                text: "没有匹配的用户"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                visible: root.chatSearchKeyword.trim() === "" && root.chatSessions.length === 0
                text: "暂无会话"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

          ListView {
                id: chatSideList
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: Style.space(4)
                model: root.chatSearchKeyword.trim() !== "" ? root.chatSearchResults : root.chatSessions
                delegate: Rectangle {
                  required property var modelData
                  readonly property bool searching: root.chatSearchKeyword.trim() !== ""
                  width: chatSideList.width
                  height: Style.space(52)
                  radius: Style.cornerRadius
                  color: String(modelData.uid) === root.chatSelectedUid
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
                    : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
                  Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Style.space(9)
                    anchors.rightMargin: Style.space(9)
                    anchors.topMargin: Style.space(7)
                    spacing: Style.space(2)
                    Row {
                      width: parent.width
                      Text {
                        width: parent.width - Style.space(58)
                        text: modelData.name
                        elide: Text.ElideRight
                        color: Model.userColor(modelData, root.contentForeground)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                      }
                      Text {
                        width: Style.space(58)
                        horizontalAlignment: Text.AlignRight
                        text: modelData.time ? Model.formatChatTime(modelData.time) : ""
                        color: Qt.darker(root.contentForeground, 1.55)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                    Text {
                      width: parent.width
                      elide: Text.ElideRight
                      text: (parent.parent.searching || !modelData.content)
                        ? ("UID " + modelData.uid + (modelData.ccfLevel > 0 ? "  ·  CCF " + modelData.ccfLevel : ""))
                        : modelData.content
                      color: Qt.darker(root.contentForeground, 1.45)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                  MouseArea { anchors.fill: parent; onClicked: root.openChatWith(modelData.uid, modelData.name, modelData.color) }
                }
              }
            }

            // ---- 右栏：当前对话 ----
            Column {
              width: parent.width - Style.space(236) - Style.space(12)
              height: parent.height
              spacing: Style.space(6)

              Row {
                width: parent.width
                Text {
                  width: parent.width - Style.space(76)
                  text: root.chatSelectedUid === ""
                    ? "选择左侧的一个会话"
                    : root.chatSelectedName + "  ·  UID " + root.chatSelectedUid
                  elide: Text.ElideRight
                  // 标题用对方的名字颜色（洛谷的 Red/Orange/Gray…）
                  color: Model.userColor({ color: root.chatSelectedColor }, root.contentForeground)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
                Text {
                  width: Style.space(76)
                  horizontalAlignment: Text.AlignRight
                  visible: root.chatLoading
                  text: "读取中…"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Rectangle {
                width: parent.width
                height: parent.height - Style.space(84)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.035)
                border.width: 1
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.11)

                Text {
                  anchors.centerIn: parent
                  visible: root.chatSelectedUid === ""
                  text: "还没有选择会话"
                  color: Qt.darker(root.contentForeground, 1.55)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                Text {
                  anchors.centerIn: parent
                  visible: root.chatSelectedUid !== "" && !root.chatLoading && root.chatMessages.length === 0
                  text: "还没有聊过，发第一条消息吧"
                  color: Qt.darker(root.contentForeground, 1.55)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                ListView {
                  id: chatThread
                  anchors.fill: parent
                  anchors.margins: Style.space(10)
                  clip: true
                  spacing: Style.space(8)
                  model: root.chatMessages
                  onCountChanged: Qt.callLater(function() { chatThread.positionViewAtEnd() })
                  delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool showTime: index === 0
                      || (Number(modelData.time) - Number(root.chatMessages[index - 1].time) >= 5 * 60)
                    width: chatThread.width
                    height: bubble.implicitHeight + (showTime ? chatTimeSeparator.implicitHeight + Style.space(10) : 0)
                    Text {
                      id: chatTimeSeparator
                      visible: parent.showTime
                      anchors.top: parent.top
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: Model.formatChatStamp(modelData.time)
                      color: Qt.darker(root.contentForeground, 1.65)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                    }
                    Rectangle {
                      id: bubble
                      readonly property bool mine: modelData.mine === true
                      // Width follows the natural single-line width of the text
                      // (implicitWidth ignores the wrapping width), capped so a
                      // long message still leaves the other side visible.
                      implicitHeight: bubbleInner.implicitHeight + Style.space(14)
                      width: Math.min(chatThread.width * 0.74, bubbleText.implicitWidth + Style.space(22))
                      height: implicitHeight
                      anchors.top: parent.top
                      anchors.topMargin: parent.showTime ? chatTimeSeparator.implicitHeight + Style.space(10) : 0
                      x: mine ? parent.width - width : 0
                      radius: Style.cornerRadius
                      color: mine
                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.85)
                        : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
                      Column {
                        id: bubbleInner
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Style.space(7)
                        spacing: 0
                        Text {
                          id: bubbleText
                          width: parent.width
                          text: modelData.content
                          textFormat: Text.PlainText
                          wrapMode: Text.WordWrap
                          maximumLineCount: 8
                          elide: Text.ElideRight
                          color: bubble.mine ? Color.background : root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.bodySmall
                        }
                      }
                    }
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(8)
                TextField {
                  width: parent.width - Style.space(88)
                  enabled: root.chatSelectedUid !== ""
                  placeholderText: root.chatSelectedUid === "" ? "先选择会话" : "输入私信内容，回车发送"
                  text: root.chatDraft
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  onTextChanged: root.chatDraft = text
                  onAccepted: root.sendPrivateMessage()
                }
                Rectangle {
                  width: Style.space(80)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  readonly property bool ready: root.chatSelectedUid !== "" && root.chatDraft.trim() !== ""
                  color: ready ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.18)
                  Text {
                    anchors.centerIn: parent
                    text: "发送"
                    color: parent.ready ? Color.background : Qt.darker(root.contentForeground, 1.3)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  MouseArea { anchors.fill: parent; onClicked: root.sendPrivateMessage() }
                }
              }
            }
          }
        }

        Column {
          visible: root.detailPage === "contest"
          width: parent.width
          spacing: Style.space(10)

          Row {
            id: contestHeaderRow
            width: parent.width
            spacing: Style.space(8)
            // 标题吃剩余宽度（而不是「容器宽度 - 猜的常数」），这样按钮实际多宽
            // 都不会把「下一页」挤出容器：原来 (w-196)+96+44+44+3×8 比 w 多 12px。
            Text { id: contestHeading; text: "比赛"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.iconLarge; font.bold: true }
            // 5 个子项 = 4 个间隔，别按 3 个算（差 8px 就会把「下一页」顶出去）
            Item {
              width: Math.max(1, contestHeaderRow.width - contestHeading.width - contestCountLabel.width
                - contestPrevButton.width - contestNextButton.width - contestHeaderRow.spacing * 4)
              height: 1
            }
            Text { id: contestCountLabel; text: root.contestCount > 0 ? ("共 " + root.contestCount + " 场") : ""; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
            Rectangle {
              id: contestPrevButton
              width: Style.space(52)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: root.contestPage > 1 ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.09) : "transparent"
              Text { anchors.centerIn: parent; text: "上一页"; color: root.contestPage > 1 ? root.contentForeground : Qt.darker(root.contentForeground, 1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadContestPage(root.contestPage - 1) }
            }
            Rectangle {
              id: contestNextButton
              width: Style.space(52)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: root.contestPage < root.contestPageCount ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.09) : "transparent"
              Text { anchors.centerIn: parent; text: "下一页"; color: root.contestPage < root.contestPageCount ? root.contentForeground : Qt.darker(root.contentForeground, 1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadContestPage(root.contestPage + 1) }
            }
          }

          Text {
            visible: root.contestLoading
            text: "正在读取比赛…"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          // 点一场比赛 -> 开独立的「洛谷比赛」窗口（不再在列表里内嵌详情）
          Repeater {
            model: root.contests
            delegate: Rectangle {
              required property var modelData
              readonly property bool ended: modelData.endTime > 0 && modelData.endTime * 1000 < Date.now()
              width: parent.width
              height: Style.space(58)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(3)
                Row {
                  width: parent.width
                  Text { width: parent.width - Style.space(76); elide: Text.ElideRight; text: modelData.name; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Text { width: Style.space(76); horizontalAlignment: Text.AlignRight; text: Model.contestStatus(modelData); color: Model.contestStatusColor(modelData) === "accent" ? Color.accent : Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
                Row {
                  width: parent.width
                  Text { width: parent.width - Style.space(110); text: Model.formatContestTime(modelData.startTime) + " - " + Model.formatContestTime(modelData.endTime); color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  Text { width: Style.space(110); horizontalAlignment: Text.AlignRight; text: ended ? (modelData.problemCount > 0 ? modelData.problemCount + " 题" : "已结束") : ("报名 " + Model.contestSignupLabel(modelData)); color: modelData.joined === true ? Color.accent : Qt.darker(root.contentForeground, 1.35); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openContestDetail(modelData.id) }
            }
          }

          Text {
            visible: !root.contestLoading && root.contests.length === 0
            text: "暂无比赛数据"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Column {
          visible: root.detailPage === "benben"
          width: parent.width
          spacing: Style.space(10)
          Row {
            width: parent.width
            Text { width: parent.width - Style.space(242); text: root.benbenEditorOpen ? "发布犇犇" : "犇犇动态"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.iconLarge; font.bold: true }
            Rectangle {
              width: Style.space(92)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: root.benbenEditorOpen ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
              Text { anchors.centerIn: parent; text: root.benbenEditorOpen ? "← 返回动态" : "写犇犇"; color: root.benbenEditorOpen ? root.contentForeground : Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.benbenEditorOpen = !root.benbenEditorOpen }
            }
            Rectangle {
              width: Style.space(130)
              height: Style.space(28)
              color: "transparent"
              Text { anchors.centerIn: parent; text: "打开洛谷犇犇"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally("https://www.luogu.com.cn/") }
            }
          }
          Row {
            visible: root.benbenEditorOpen
            width: parent.width
            spacing: Style.space(8)
            TextField { width: parent.width - Style.space(96); placeholderText: "发布一条犇犇"; text: root.benbenDraft; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.benbenDraft = text }
            Rectangle {
              width: Style.space(88)
              height: Style.space(34)
              radius: Style.cornerRadius
              color: Color.accent
              Text { anchors.centerIn: parent; text: "发布"; color: Color.background; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { anchors.fill: parent; onClicked: root.publishBenben() }
            }
          }
          Row {
            visible: !root.benbenEditorOpen
            width: parent.width
            spacing: Style.space(8)
            Repeater {
              model: [{ key: "watching", label: "关注动态" }, { key: "mine", label: "我的犇犇" }]
              delegate: Rectangle {
                required property var modelData
                width: Style.space(96)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: root.feedMode === modelData.key ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: modelData.label; color: root.feedMode === modelData.key ? Color.background : root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.feedMode = modelData.key
                    if (modelData.key === "mine" && root.ownFeedItems.length === 0) root.loadOwnFeed()
                  }
                }
              }
            }
          }
          // 犇犇 bodies are markdown and often long (a reply chain is one string
          // joined with `||`), so the box height has to follow the wrapped text.
          // With a fixed height the tall ones overflowed their rectangle and drew
          // over the entry below — which reads as doubled/overlapping text
          // ("有些犇犇容易重"). Capped at 6 lines so one entry cannot swallow the
          // page, eliding the tail instead.
          Repeater {
            visible: !root.benbenEditorOpen
            model: root.feedMode === "mine" ? root.ownFeedItems : root.feedItems
            delegate: Rectangle {
              required property var modelData
              width: parent.width
              height: feedBody.implicitHeight + Style.space(20)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)

              Column {
                id: feedBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(4)

                Row {
                  width: parent.width
                  spacing: Style.space(6)
                  Text {
                    width: Math.max(Style.space(90), parent.width - Style.space(80))
                    // profile.uid 是字符串、modelData.uid 是数字，直接 === 永远为假
                    text: modelData.name || (String(modelData.uid) === String(root.profile.uid) ? root.profile.name : "UID " + modelData.uid)
                    elide: Text.ElideRight
                    color: Model.userColor(modelData, root.contentForeground)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }
                  Text {
                    width: Style.space(74)
                    horizontalAlignment: Text.AlignRight
                    text: modelData.uid > 0 ? "UID " + modelData.uid : ""
                    color: Qt.darker(root.contentForeground, 1.55)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Text {
                  text: Model.feedInlineHtml(modelData.content, Color.accent)
                  textFormat: Text.RichText
                  width: parent.width
                  wrapMode: Text.WordWrap
                  maximumLineCount: 6
                  elide: Text.ElideRight
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text { text: modelData.time; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              }
            }
          }
          Rectangle {
            readonly property bool hasItems: root.feedMode === "mine" ? root.ownFeedItems.length > 0 : root.feedItems.length > 0
            readonly property bool hasMore: root.feedMode === "mine" ? root.ownFeedHasMore : root.feedHasMore
            visible: !root.benbenEditorOpen && hasItems && (hasMore || root.feedMoreLoading)
            width: parent.width
            height: Style.space(30)
            radius: Style.cornerRadius
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.07)
            Text {
              anchors.centerIn: parent
              text: root.feedMoreLoading ? "读取中…" : "加载更多"
              color: Color.accent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadMoreFeed() }
          }
          Text { visible: !root.benbenEditorOpen && (root.feedMode === "mine" ? (root.ownFeedLoading || root.ownFeedItems.length === 0) : root.feedItems.length === 0); text: root.feedMode === "mine" && root.ownFeedLoading ? "正在读取我的犇犇…" : "暂无犇犇"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
        }

        // 题库：搜题（关键词 / 难度 / 标签 / 排序）→ 看题 → 题解。
        // 题面和题解都是 Markdown，直接交给 MarkdownView 排版。
        Column {
          visible: root.detailPage === "problems"
          width: parent.width
          spacing: Style.space(10)

          // ---------------- 列表态 ----------------
          Column {
            visible: root.problemView === "list"
            width: parent.width
            spacing: Style.space(10)

            Row {
              width: parent.width
              Text { width: parent.width - Style.space(120); text: "题库"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.iconLarge; font.bold: true }
              Rectangle {
                width: Style.space(120)
                height: Style.space(28)
                color: "transparent"
                Text { anchors.centerIn: parent; text: "打开洛谷题库"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://www.luogu.com.cn/problem/list") }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              TextField {
                width: parent.width - Style.space(96)
                placeholderText: "关键词或题号（P1001）"
                text: root.problemKeyword
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                onTextChanged: root.problemKeyword = text
                onAccepted: root.searchProblems(1)
              }
              Rectangle {
                width: Style.space(88)
                height: Style.space(34)
                radius: Style.cornerRadius
                color: Color.accent
                Text { anchors.centerIn: parent; text: "搜索"; color: Color.background; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.searchProblems(1) }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(10)
              Dropdown {
                width: Style.space(150)
                label: "难度"
                options: root.problemDifficultyOptions
                value: root.problemDifficultyName
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: function(newValue) { root.problemDifficultyName = newValue; root.searchProblems(1) }
              }
              Dropdown {
                width: Style.space(190)
                label: "算法标签"
                options: root.problemTagOptions
                value: root.problemTagName
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: function(newValue) { root.problemTagName = newValue; root.searchProblems(1) }
              }
              Dropdown {
                width: Style.space(130)
                label: "排序"
                options: root.problemOrderOptions
                value: root.problemOrderName
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: function(newValue) { root.problemOrderName = newValue; root.searchProblems(1) }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              Text {
                width: parent.width - Style.space(178)
                text: root.problemListLoading
                  ? "正在读取题库…"
                  : ("共 " + root.problemCount + " 题 · 第 " + root.problemPage + " / " + root.problemPageCount + " 页"
                     + (root.tagTableLoading ? " · 标签表读取中…" : ""))
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              Rectangle {
                width: Style.space(80)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.problemPage > 1 ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.09) : "transparent"
                Text { anchors.centerIn: parent; text: "上一页"; color: root.problemPage > 1 ? root.contentForeground : Qt.darker(root.contentForeground, 1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.problemPage > 1) root.searchProblems(root.problemPage - 1) }
              }
              Rectangle {
                width: Style.space(80)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.problemPage < root.problemPageCount ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.09) : "transparent"
                Text { anchors.centerIn: parent; text: "下一页"; color: root.problemPage < root.problemPageCount ? root.contentForeground : Qt.darker(root.contentForeground, 1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.problemPage < root.problemPageCount) root.searchProblems(root.problemPage + 1) }
              }
            }

            Repeater {
              model: root.problemList
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: Style.space(54)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
                Row {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(9)
                  spacing: Style.space(10)
                  Rectangle {
                    // 难度名长短差别很大（「入门」到「NOI/NOI+/CTSC」），固定宽度会截断
                    id: problemDifficultyChip
                    width: Math.max(Style.space(46), problemDifficultyLabel.implicitWidth + Style.space(12))
                    height: Style.space(20)
                    radius: Style.space(4)
                    color: Model.difficultyColor(modelData.difficulty)
                    Text {
                      id: problemDifficultyLabel
                      anchors.centerIn: parent
                      text: Model.difficultyName(modelData.difficulty)
                      color: Color.background
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                  Column {
                    width: parent.width - problemDifficultyChip.width - Style.space(10) - Style.space(52) - Style.space(10)
                    spacing: Style.space(2)
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.pid + "  " + modelData.name; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Text { width: parent.width; elide: Text.ElideRight; text: Model.tagNames(modelData.tags, root.tagTable).join(" · ") + (modelData.totalSubmit > 0 ? "   提交 " + Model.compactCount(modelData.totalSubmit) : ""); color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  }
                  Text {
                    width: Style.space(52)
                    horizontalAlignment: Text.AlignRight
                    text: modelData.accepted ? "已通过" : (modelData.submitted ? "尝试过" : "")
                    color: modelData.accepted ? Color.accent : Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openProblem(modelData.pid) }
              }
            }

            // 列表底部同样给一组翻页：题库一页 50 条，翻到末尾不用再滚回顶部
            Row {
              width: parent.width
              spacing: Style.space(8)
              Text {
                width: parent.width - Style.space(178)
                text: "第 " + root.problemPage + " / " + root.problemPageCount + " 页 · 共 " + root.problemCount + " 题"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              Rectangle {
                width: Style.space(80)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.problemPage > 1 ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "上一页"; color: root.problemPage > 1 ? root.contentForeground : Qt.darker(root.contentForeground, 1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.problemPage > 1) root.searchProblems(root.problemPage - 1) }
              }
              Rectangle {
                width: Style.space(80)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.problemPage < root.problemPageCount ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"
                Text { anchors.centerIn: parent; text: "下一页"; color: root.problemPage < root.problemPageCount ? root.contentForeground : Qt.darker(root.contentForeground, 1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.problemPage < root.problemPageCount) root.searchProblems(root.problemPage + 1) }
              }
            }

          }

          // ---------------- 看题 ----------------
          // ---------------- 看题 ----------------
          // 题面、提交、评测（含验证码）统一交给 ProblemPanel：这里原本还有一份
          // 提交 UI，而且没有验证码字段 —— 洛谷的提交是「语言校验 → 验证码 →
          // 代码」，所以从那份 UI 交题必然被判「验证码错误」。两份实现合一后不会
          // 再出现「改了一份忘了另一份」。
          Column {
            visible: root.problemView === "detail"
            width: parent.width
            spacing: Style.space(12)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: backProblem.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: "← 返回题库"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { id: backProblem; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.problemView = "list"; root.problemDetail = null } }
              }
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: openSolution.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: root.solutionCount > 0 ? "题解 " + root.solutionCount : "题解"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { id: openSolution; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.problemDetail) root.openSolutions(root.problemDetail.pid) }
              }
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: openDiscussion.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: "讨论"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { id: openDiscussion; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.problemDetail) root.openProblemDiscussions(root.problemDetail.pid) }
              }
              Rectangle {
                width: Style.space(110)
                height: Style.space(28)
                color: "transparent"
                Text { anchors.centerIn: parent; text: "在洛谷打开"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.problemDetail) Qt.openUrlExternally("https://www.luogu.com.cn/problem/" + root.problemDetail.pid) }
              }
            }

            ProblemPanel {
              id: problemPagePanel
              width: parent.width
              pid: root.problemDetailPid
              defaultLanguageId: root.defaultLanguageId
              markdownBlockLimit: root.markdownBlockLimit
              uid: root.uid
              clientId: root.clientId
              csrfToken: root.csrfToken
              tagTable: root.tagTable
              draftHost: root
              // 题面由本页自己取（下面的题解/讨论/发帖也要用它），组件只负责显示
              fetchDetail: false
              preloadedDetail: root.problemDetail
              foreground: root.contentForeground
              accentColor: Color.accent
              fontFamily: root.contentFontFamily
              onRequestTagTable: root.loadTagTable()
            }
          }

          // ---------------- 题目讨论列表 ----------------
          Column {
            visible: root.problemView === "discussions"
            width: parent.width
            spacing: Style.space(10)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: backFromDiscussions.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: "← 返回题目"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { id: backFromDiscussions; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.problemView = "detail" }
              }
              Text {
                width: Math.max(Style.space(120), parent.width - Style.space(root.problemDiscussionEditorOpen ? 204 : 384))
                text: root.problemDiscussionEditorOpen ? "发布题目讨论" : (root.problemDetail ? ("讨论 · " + root.problemDetail.pid) : "讨论")
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: root.problemDiscussionEditorOpen ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
                Text { anchors.centerIn: parent; text: root.problemDiscussionEditorOpen ? "← 返回讨论" : "发布讨论"; color: root.problemDiscussionEditorOpen ? root.contentForeground : Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.problemDiscussionEditorOpen = !root.problemDiscussionEditorOpen }
              }
              Rectangle {
                visible: !root.problemDiscussionEditorOpen
                width: Style.space(80)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: root.problemPostPage > 1 ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.09) : "transparent"
                Text { anchors.centerIn: parent; text: "上一页"; color: root.problemPostPage > 1 ? root.contentForeground : Qt.darker(root.contentForeground, 1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadProblemPosts(root.problemPostPage - 1) }
              }
              Rectangle {
                visible: !root.problemDiscussionEditorOpen
                width: Style.space(80)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.09)
                Text { anchors.centerIn: parent; text: "下一页"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadProblemPosts(root.problemPostPage + 1) }
              }
            }

            Column {
              visible: root.problemDiscussionEditorOpen
              width: parent.width
              spacing: Style.space(7)
              Text { text: "发布这道题的讨论"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1.1 }
              TextField { width: parent.width; placeholderText: "讨论标题"; text: root.problemPostTitleDraft; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.problemPostTitleDraft = text }
              QQC.TextArea {
                id: problemDiscussionBody
                width: parent.width; height: Style.space(105)
                placeholderText: "写下你的题目讨论（支持洛谷 Markdown）"; wrapMode: QQC.TextArea.Wrap; selectByMouse: true
                text: root.problemPostContentDraft; color: root.contentForeground
                placeholderTextColor: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall
                onTextChanged: root.problemPostContentDraft = text
                background: BorderSurface { color: Style.controlFill(problemDiscussionBody.activeFocus, false, root.contentForeground, Color.accent); borderSpec: Border.controlSpec(problemDiscussionBody.activeFocus ? "focus" : "normal", root.contentForeground, Color.accent); radius: Style.cornerRadius }
              }
              Row {
                width: parent.width; spacing: Style.space(8)
                Rectangle {
                  width: Style.space(120)
                  height: Style.space(42)
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
                  Image { anchors.fill: parent; anchors.margins: 3; fillMode: Image.PreserveAspectFit; source: root.postCaptchaImage; cache: false }
                  Text { anchors.centerIn: parent; visible: root.postCaptchaImage === ""; text: postCaptchaProc.running ? "读取中…" : "点击获取"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.requestPostCaptcha() }
                }
                TextField { width: Style.space(120); placeholderText: "验证码"; text: root.problemPostCaptchaDraft; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.problemPostCaptchaDraft = text }
                Rectangle {
                  width: Style.space(88)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: Color.accent
                  Text { anchors.centerIn: parent; text: postProcWrite.running ? "发布中…" : "发布讨论"; color: Color.background; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.publishProblemPost() }
                }
                Rectangle {
                  width: Style.space(88)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: "transparent"
                  Text { anchors.centerIn: parent; text: "换验证码"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.requestPostCaptcha() }
                }
              }
              Text { text: "当前题目：" + (root.problemDetail ? root.problemDetail.pid : "") + " · 需要洛谷验证码"; color: Qt.darker(root.contentForeground, 1.55); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
            }

            Text {
              visible: !root.problemDiscussionEditorOpen && (root.problemPostsLoading || root.problemPosts.length === 0)
              text: root.problemPostsLoading ? "正在读取讨论…" : "这题还没有讨论"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              visible: !root.problemDiscussionEditorOpen
              model: root.problemPosts
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: Style.space(50)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
                Column {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(9)
                  spacing: Style.space(2)
                  Text { width: parent.width; elide: Text.ElideRight; text: modelData.title; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Text { width: parent.width; elide: Text.ElideRight; text: modelData.author + " · " + Model.formatChatStamp(modelData.time) + " · 回复 " + modelData.replyCount; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openThread(modelData.id) }
              }
            }
          }

          // ---------------- 单个讨论帖 ----------------
          Column {
            visible: root.problemView === "thread"
            width: parent.width
            spacing: Style.space(12)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: backToDiscussions.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: "← 返回讨论"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { id: backToDiscussions; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.problemView = "discussions" }
              }
              Rectangle {
                width: Style.space(110)
                height: Style.space(28)
                color: "transparent"
                Text { anchors.centerIn: parent; text: "在洛谷打开"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.threadId !== "") Qt.openUrlExternally("https://www.luogu.com.cn/discuss/" + root.threadId) }
              }
            }

            Text {
              width: parent.width
              text: root.threadPost ? root.threadPost.title : ""
              wrapMode: Text.WordWrap
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              width: parent.width
              text: root.threadPost ? (root.threadPost.author + " · " + Model.formatChatStamp(root.threadPost.time) + " · " + root.threadPost.replyTotal + " 条回复") : ""
              wrapMode: Text.WordWrap
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: root.threadLoading && root.threadPost === null
              text: "正在读取帖子…"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MarkdownView {
              visible: root.threadPost !== null
              width: parent.width
              blockLimit: root.markdownBlockLimit
              markdown: root.threadPost ? root.threadPost.content : ""
              foreground: root.contentForeground
              accentColor: Color.accent
              fontFamily: root.contentFontFamily
              basePixelSize: Style.font.bodySmall
            }

            Rectangle {
              visible: root.threadPost !== null
              width: parent.width
              height: 1
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.16)
            }

            Row {
              width: parent.width
              visible: root.threadPost !== null
              Text {
                width: parent.width - Style.space(110)
                text: root.threadPost ? "回复 " + root.threadPost.replyTotal : ""
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
              Text {
                width: Style.space(110)
                horizontalAlignment: Text.AlignRight
                text: "已显示 " + root.threadReplies.length
                color: Qt.darker(root.contentForeground, 1.55)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Repeater {
              model: root.threadReplies
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: threadReplyBody.implicitHeight + Style.space(20)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                Column {
                  id: threadReplyBody
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(10)
                  spacing: Style.space(6)
                  Text { width: parent.width; text: modelData.author + " · " + Model.formatChatStamp(modelData.time); color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  MarkdownView { width: parent.width; blockLimit: root.markdownBlockLimit; markdown: modelData.content; foreground: root.contentForeground; accentColor: Color.accent; fontFamily: root.contentFontFamily; basePixelSize: Style.font.bodySmall }
                }
              }
            }

            Rectangle {
              visible: root.threadPost !== null && root.threadReplies.length < root.threadPost.replyTotal
              width: parent.width
              height: Style.space(30)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.07)
              Text { anchors.centerIn: parent; text: threadProc.running ? "读取中…" : "加载更多回复"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadMoreThreadReplies() }
            }
          }

          // ---------------- 题解列表 ----------------
          Column {
            visible: root.problemView === "solutions"
            width: parent.width
            spacing: Style.space(10)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: backToProblem.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: "← 返回题目"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { id: backToProblem; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.problemView = "detail" }
              }
              Text {
                width: parent.width - Style.space(102)
                text: root.problemDetail ? ("题解 · " + root.problemDetail.pid + " · 共 " + root.solutionCount + " 篇") : "题解"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
            }

            Text {
              visible: root.solutionLoading
              text: "正在读取题解…"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              model: root.solutionList
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: solutionBody.implicitHeight + Style.space(18)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
                Column {
                  id: solutionBody
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(10)
                  spacing: Style.space(4)
                  Text { width: parent.width; elide: Text.ElideRight; text: modelData.title; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Text { width: parent.width; elide: Text.ElideRight; text: modelData.author + " · " + Model.formatChatStamp(modelData.time) + " · 赞 " + Model.compactCount(modelData.upvote) + " · 回复 " + modelData.replyCount; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openArticle(modelData.lid) }
              }
            }
          }

          // ---------------- 题解全文 ----------------
          Column {
            visible: root.problemView === "article"
            width: parent.width
            spacing: Style.space(12)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: backToSolutions.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: "← 返回题解"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { id: backToSolutions; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.problemView = "solutions" }
              }
              Rectangle {
                width: Style.space(110)
                height: Style.space(28)
                color: "transparent"
                Text { anchors.centerIn: parent; text: "在洛谷打开"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.solutionArticle) Qt.openUrlExternally("https://www.luogu.com.cn/article/" + root.solutionArticle.lid) }
              }
            }

            Text {
              width: parent.width
              text: root.solutionArticle ? root.solutionArticle.title : ""
              wrapMode: Text.WordWrap
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              width: parent.width
              text: root.solutionArticle ? (root.solutionArticle.author + " · " + Model.formatChatStamp(root.solutionArticle.time) + " · 赞 " + root.solutionArticle.upvote) : ""
              wrapMode: Text.WordWrap
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: root.articleLoading
              text: "正在读取题解…"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MarkdownView {
              visible: !root.articleLoading
              width: parent.width
              blockLimit: root.markdownBlockLimit
              markdown: root.solutionArticle ? root.solutionArticle.content : ""
              foreground: root.contentForeground
              accentColor: Color.accent
              fontFamily: root.contentFontFamily
              basePixelSize: Style.font.bodySmall
            }
          }
        }

        Column {
          visible: root.detailPage === "posts"
          width: parent.width
          spacing: Style.space(10)

          // 列表态
          Column {
            visible: root.postDetail === null
            width: parent.width
            spacing: Style.space(10)
            Row {
              width: parent.width
              Text { width: parent.width - Style.space(242); text: root.postEditorOpen ? "发布新帖" : "帖子浏览"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.iconLarge; font.bold: true }
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: root.postEditorOpen ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
                Text { anchors.centerIn: parent; text: root.postEditorOpen ? "← 返回列表" : "写帖子"; color: root.postEditorOpen ? root.contentForeground : Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.postEditorOpen = !root.postEditorOpen }
              }
              Rectangle {
                width: Style.space(130)
                height: Style.space(28)
                color: "transparent"
                Text { anchors.centerIn: parent; text: "打开讨论区"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally("https://www.luogu.com.cn/discuss") }
              }
            }
            // Laid out like Luogu's own post page: title, board, a real multi-line
            // body, then the captcha image next to the code box, then submit. The
            // previous one-row form squeezed title/board/captcha into equal thirds
            // with placeholder-only labels and a single-line body, which is what
            // made it look wrong.
            Column {
              visible: root.postEditorOpen
              width: parent.width
              spacing: Style.space(8)
              Text { text: "发布新帖"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1.2 }
              TextField {
                width: parent.width
                placeholderText: "标题"
                text: root.postTitleDraft
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                onTextChanged: root.postTitleDraft = text
              }
              Dropdown {
                width: Style.space(240)
                label: "版面"
                options: root.postForums
                value: root.postForumDraft
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onChanged: function(newValue) { root.postForumDraft = newValue }
              }
              QQC.TextArea {
                id: postContentArea
                width: parent.width
                height: Style.space(160)
                placeholderText: "帖子内容（支持洛谷 Markdown）"
                wrapMode: QQC.TextArea.Wrap
                selectByMouse: true
                text: root.postContentDraft
                color: root.contentForeground
                placeholderTextColor: Qt.darker(root.contentForeground, 1.6)
                selectionColor: Style.selectionFillFor(root.contentForeground, Color.accent)
                selectedTextColor: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                readonly property var borderSpec: Border.controlSpec(postContentArea.activeFocus ? "focus" : "normal", root.contentForeground, Color.accent)
                leftPadding: Style.spacing.controlPaddingX + Border.left(borderSpec)
                rightPadding: Style.spacing.controlPaddingX + Border.right(borderSpec)
                topPadding: Style.spacing.inputPaddingY + Border.top(borderSpec)
                bottomPadding: Style.spacing.inputPaddingY + Border.bottom(borderSpec)
                background: BorderSurface {
                  color: Style.controlFill(postContentArea.activeFocus, false, root.contentForeground, Color.accent)
                  borderSpec: postContentArea.borderSpec
                  radius: Style.cornerRadius
                }
                onTextChanged: root.postContentDraft = text
              }
              Row {
                width: parent.width
                spacing: Style.space(8)
                Text {
                  text: "验证码"
                  anchors.verticalCenter: parent.verticalCenter
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
                Rectangle {
                  width: Style.space(120)
                  height: Style.space(42)
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
                  Image {
                    anchors.fill: parent
                    anchors.margins: Style.space(3)
                    fillMode: Image.PreserveAspectFit
                    source: root.postCaptchaImage
                    cache: false
                  }
                  Text {
                    anchors.centerIn: parent
                    visible: root.postCaptchaImage === ""
                    text: postCaptchaProc.running ? "读取中…" : "点此获取"
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.requestPostCaptcha() }
                }
                TextField {
                  width: Style.space(140)
                  placeholderText: "验证码"
                  text: root.postCaptchaDraft
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  onTextChanged: root.postCaptchaDraft = text
                }
                Rectangle {
                  width: Style.space(88)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: postCaptchaMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"
                  Text { anchors.centerIn: parent; text: "换一张"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                  MouseArea { id: postCaptchaMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.requestPostCaptcha() }
                }
              }
              Row {
                width: parent.width
                spacing: Style.space(10)
                Rectangle {
                  width: Style.space(88)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: root.forumCanPost(root.postForumDraft)
                    ? Color.accent
                    : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                  Text {
                    anchors.centerIn: parent
                    text: "发帖"
                    color: root.forumCanPost(root.postForumDraft) ? Color.background : Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.publishPost() }
                }
                Text {
                  width: parent.width - Style.space(98)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.forumCanPost(root.postForumDraft)
                    ? "发帖需要洛谷验证码（点击图片可换一张）；版面默认学术版。"
                    : "你在「" + root.forumLabel(root.postForumDraft) + "」没有发帖权限，换个版面再发。"
                  color: root.forumCanPost(root.postForumDraft) ? Qt.darker(root.contentForeground, 1.55) : Color.urgent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }
            }
            Repeater {
              visible: !root.postEditorOpen
              model: root.postItems
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: Style.space(62)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
                Column {
                  anchors.fill: parent
                  anchors.margins: Style.space(10)
                  spacing: Style.space(4)
                  Text { text: modelData.title; width: parent.width; elide: Text.ElideRight; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Text { text: modelData.forum + " · " + modelData.author + " · 回复 " + modelData.replyCount; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPost(modelData.id) }
              }
            }
            Text { visible: !root.postEditorOpen && root.postItems.length === 0; text: "暂无帖子或正在读取…"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
          }

          // 详情态：正文和回复都在插件里排版（MarkdownView），不再跳浏览器。
          Column {
            visible: root.postDetail !== null
            width: parent.width
            spacing: Style.space(12)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(92)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: backMouse.containsMouse
                  ? Style.hoverFillFor(root.contentForeground, Color.accent)
                  : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: "← 返回列表"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closePost() }
              }
              Item { width: Math.max(1, parent.width - Style.space(92) - Style.space(120) - Style.space(20)); height: 1 }
              Rectangle {
                width: Style.space(120)
                height: Style.space(28)
                color: "transparent"
                Text { anchors.centerIn: parent; text: "在洛谷打开"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://www.luogu.com.cn/discuss/" + root.postDetailId) }
              }
            }

            Text {
              width: parent.width
              text: root.postDetail ? root.postDetail.title : ""
              wrapMode: Text.WordWrap
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              width: parent.width
              text: root.postDetail
                ? (root.postDetail.forum + " · " + root.postDetail.author + " · " + Model.formatChatStamp(root.postDetail.time) + " · " + root.postDetail.replyTotal + " 条回复")
                : ""
              wrapMode: Text.WordWrap
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: root.postDetailLoading
              text: "正在读取帖子…"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MarkdownView {
              visible: !root.postDetailLoading
              width: parent.width
              blockLimit: root.markdownBlockLimit
              markdown: root.postDetail ? root.postDetail.content : ""
              foreground: root.contentForeground
              accentColor: Color.accent
              fontFamily: root.contentFontFamily
              basePixelSize: Style.font.bodySmall
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.16)
            }

            Row {
              width: parent.width
              Text {
                width: parent.width - Style.space(96)
                text: root.postDetail ? "回复 " + root.postDetail.replyTotal : "回复"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
              Text {
                width: Style.space(96)
                horizontalAlignment: Text.AlignRight
                text: "已显示 " + root.postReplies.length
                color: Qt.darker(root.contentForeground, 1.55)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            // 每条回复的正文也是 Markdown，用同一个渲染器；高度跟着内容走，
            // 不能固定，否则长回复会画到下一个卡片上。
            Repeater {
              model: root.postReplies
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: replyBody.implicitHeight + Style.space(20)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                Column {
                  id: replyBody
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(10)
                  spacing: Style.space(6)
                  Text {
                    width: parent.width
                    text: modelData.author + " · " + Model.formatChatStamp(modelData.time)
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                  MarkdownView {
                    width: parent.width
                    blockLimit: root.markdownBlockLimit
                    markdown: modelData.content
                    foreground: root.contentForeground
                    accentColor: Color.accent
                    fontFamily: root.contentFontFamily
                    basePixelSize: Style.font.bodySmall
                  }
                }
              }
            }

            Rectangle {
              visible: root.postDetail !== null && root.postReplies.length < root.postDetail.replyTotal
              width: parent.width
              height: Style.space(30)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.07)
              Text {
                anchors.centerIn: parent
                text: postDetailProc.running ? "读取中…" : "加载更多回复"
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadMoreReplies() }
            }

            Column {
              width: parent.width
              spacing: Style.space(8)
              Text { text: "回复帖子"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1.2 }
              TextField {
                width: Style.space(140)
                placeholderText: "帖子 ID"
                text: root.replyPostId
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                onTextChanged: root.replyPostId = text
              }
              QQC.TextArea {
                id: replyContentArea
                width: parent.width
                height: Style.space(90)
                placeholderText: "回复内容（支持洛谷 Markdown）"
                wrapMode: QQC.TextArea.Wrap
                selectByMouse: true
                text: root.replyDraft
                color: root.contentForeground
                placeholderTextColor: Qt.darker(root.contentForeground, 1.6)
                selectionColor: Style.selectionFillFor(root.contentForeground, Color.accent)
                selectedTextColor: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                readonly property var borderSpec: Border.controlSpec(replyContentArea.activeFocus ? "focus" : "normal", root.contentForeground, Color.accent)
                leftPadding: Style.spacing.controlPaddingX + Border.left(borderSpec)
                rightPadding: Style.spacing.controlPaddingX + Border.right(borderSpec)
                topPadding: Style.spacing.inputPaddingY + Border.top(borderSpec)
                bottomPadding: Style.spacing.inputPaddingY + Border.bottom(borderSpec)
                background: BorderSurface {
                  color: Style.controlFill(replyContentArea.activeFocus, false, root.contentForeground, Color.accent)
                  borderSpec: replyContentArea.borderSpec
                  radius: Style.cornerRadius
                }
                onTextChanged: root.replyDraft = text
              }
              Row {
                width: parent.width
                spacing: Style.space(8)
                Text {
                  text: "验证码"
                  anchors.verticalCenter: parent.verticalCenter
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
                Rectangle {
                  width: Style.space(120)
                  height: Style.space(42)
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
                  Image {
                    anchors.fill: parent
                    anchors.margins: Style.space(3)
                    fillMode: Image.PreserveAspectFit
                    source: root.replyCaptchaImage
                    cache: false
                  }
                  Text {
                    anchors.centerIn: parent
                    visible: root.replyCaptchaImage === ""
                    text: replyCaptchaProc.running ? "读取中…" : "点此获取"
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.requestReplyCaptcha() }
                }
                TextField {
                  width: Style.space(140)
                  placeholderText: "验证码"
                  text: root.replyCaptcha
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  onTextChanged: root.replyCaptcha = text
                }
                Rectangle {
                  width: Style.space(88)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: replyCaptchaMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"
                  Text { anchors.centerIn: parent; text: "换一张"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                  MouseArea { id: replyCaptchaMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.requestReplyCaptcha() }
                }
                Rectangle {
                  width: Style.space(88)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: Color.accent
                  Text { anchors.centerIn: parent; text: "回复"; color: Color.background; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.replyPost() }
                }
              }
            }

          }
        }

          // ---------------- 云剪贴板 ----------------
          // 只能读：列出自己的剪贴板、看内容、复制链接。创建接口探不到
          // （/paste 只接受 GET，PUT/PATCH/POST/DELETE 全 405，35 个候选路径全
          // 404），需要从浏览器 devtools 抓一次真实请求才能接上。
          Column {
            visible: root.detailPage === "paste"
            width: parent.width
            spacing: Style.space(10)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Text {
                width: parent.width - Style.space(300)
                text: "云剪贴板" + (root.pasteCount > 0 ? "  " + root.pasteItems.length + " / " + root.pasteCount : "")
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.iconLarge
                font.bold: true
              }
              Rectangle {
                width: Style.space(96)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: root.pasteComposerOpen ? "取消新建" : "新建剪贴板"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.pasteComposerOpen) root.closePasteComposer(); else root.openPasteComposer() }
              }
              Rectangle {
                width: Style.space(64)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                Text { anchors.centerIn: parent; text: "刷新"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadPastes(false) }
              }
              Rectangle {
                width: Style.space(120)
                height: Style.space(28)
                color: "transparent"
                Text { anchors.centerIn: parent; text: "打开洛谷剪贴板"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://www.luogu.com.cn/paste") }
              }
            }

            // ---------------- 新建 / 编辑表单 ----------------
            Rectangle {
              visible: root.pasteComposerOpen
              width: parent.width
              height: composerBody.implicitHeight + Style.space(20)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)

              Column {
                id: composerBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Text {
                  text: root.pasteComposerMode === "edit" ? ("编辑 /paste/" + root.pasteDetailId) : "新建云剪贴板"
                  color: Color.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1.2
                }

                QQC.TextArea {
                  id: pasteDraftArea
                  width: parent.width
                  height: Style.space(150)
                  wrapMode: QQC.TextArea.WrapAnywhere
                  selectByMouse: true
                  text: root.pasteDraftData
                  color: root.contentForeground
                  placeholderText: "要放进剪贴板的内容（Markdown 也行）"
                  placeholderTextColor: Qt.darker(root.contentForeground, 1.6)
                  selectionColor: Style.selectionFillFor(root.contentForeground, Color.accent)
                  selectedTextColor: root.contentForeground
                  font.family: "monospace"
                  font.pixelSize: Style.font.bodySmall
                  readonly property var borderSpec: Border.controlSpec(pasteDraftArea.activeFocus ? "focus" : "normal", root.contentForeground, Color.accent)
                  leftPadding: Style.spacing.controlPaddingX + Border.left(borderSpec)
                  rightPadding: Style.spacing.controlPaddingX + Border.right(borderSpec)
                  topPadding: Style.spacing.inputPaddingY + Border.top(borderSpec)
                  bottomPadding: Style.spacing.inputPaddingY + Border.bottom(borderSpec)
                  background: BorderSurface {
                    color: Style.controlFill(pasteDraftArea.activeFocus, false, root.contentForeground, Color.accent)
                    borderSpec: pasteDraftArea.borderSpec
                    radius: Style.cornerRadius
                  }
                  onTextChanged: root.pasteDraftData = text
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Rectangle {
                    width: Style.space(96)
                    height: Style.space(28)
                    radius: Style.cornerRadius
                    color: root.pasteDraftPublic ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
                    Text { anchors.centerIn: parent; text: root.pasteDraftPublic ? "公开" : "私密"; color: root.pasteDraftPublic ? Color.background : root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pasteDraftPublic = !root.pasteDraftPublic }
                  }
                  Rectangle {
                    width: Style.space(120)
                    height: Style.space(42)
                    radius: Style.cornerRadius
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
                    Image { anchors.fill: parent; anchors.margins: Style.space(3); fillMode: Image.PreserveAspectFit; source: root.pasteCaptchaImage; cache: false }
                    Text { anchors.centerIn: parent; visible: root.pasteCaptchaImage === ""; text: pasteCaptchaProc.running ? "读取中…" : "点此获取验证码"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 2; visible: root.pasteComposerMode === "edit" && root.pasteCaptchaImage !== ""; text: "编辑可不填"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshPasteCaptcha() }
                  }
                  TextField {
                    width: Style.space(130)
                    placeholderText: "验证码"
                    text: root.pasteCaptchaCode
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    onTextChanged: root.pasteCaptchaCode = text
                  }
                  Rectangle {
                    readonly property bool ready: !root.pasteSaving && root.pasteCaptchaReady
                    width: Style.space(88)
                    height: Style.space(34)
                    radius: Style.cornerRadius
                    color: ready ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                    Text { anchors.centerIn: parent; text: root.pasteSaving ? "处理中…" : (root.pasteComposerMode === "edit" ? "保存" : "创建"); color: parent.ready ? Color.background : Qt.darker(root.contentForeground, 1.3); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.submitPasteWrite() }
                  }
                  Text {
                    width: Math.max(Style.space(60), parent.width - Style.space(96) - Style.space(120) - Style.space(130) - Style.space(88) - Style.space(40))
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.pasteWriteStatus
                    color: root.pasteWriteStatus.indexOf("失败") >= 0 ? Color.urgent : Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            // ---------------- 详情态 ----------------
            Column {
              visible: root.pasteDetailId !== ""
              width: parent.width
              spacing: Style.space(8)

              Row {
                width: parent.width
                spacing: Style.space(10)
                Rectangle {
                  width: Style.space(92)
                  height: Style.space(28)
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                  Text { anchors.centerIn: parent; text: "← 返回列表"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closePasteDetail() }
                }
                Text {
                  width: parent.width - Style.space(102)
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  text: "/paste/" + root.pasteDetailId
                    + (root.pasteDetail ? ("   " + (root.pasteDetail.isPublic ? "公开" : "私密") + "   " + Model.formatChatTime(root.pasteDetail.time) + "   " + root.pasteDetail.data.length + " 字") : "")
                  color: Qt.darker(root.contentForeground, 1.45)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                visible: root.pasteDetailLoading
                text: "正在读取…"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                visible: root.pasteDetail !== null
                width: parent.width
                height: Style.space(320)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                clip: true
                Flickable {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  clip: true
                  contentWidth: width
                  contentHeight: pasteBody.contentHeight
                  boundsBehavior: Flickable.StopAtBounds
                  QQC.TextArea {
                    id: pasteBody
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: QQC.TextArea.WrapAnywhere
                    text: root.pasteDetail ? root.pasteDetail.data : ""
                    color: root.contentForeground
                    selectionColor: Style.selectionFillFor(root.contentForeground, Color.accent)
                    selectedTextColor: root.contentForeground
                    font.family: "monospace"
                    font.pixelSize: Style.font.bodySmall
                    background: null
                  }
                }
              }

              Row {
                visible: root.pasteDetail !== null
                width: parent.width
                spacing: Style.space(8)
                Rectangle {
                  width: Style.space(92); height: Style.space(28); radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                  Text { anchors.centerIn: parent; text: "复制内容"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.pasteDetail) root.copyToClipboard(root.pasteDetail.data) }
                }
                Rectangle {
                  width: Style.space(92); height: Style.space(28); radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                  Text { anchors.centerIn: parent; text: "复制链接"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyToClipboard("https://www.luogu.com.cn/paste/" + root.pasteDetailId) }
                }
                Rectangle {
                  width: Style.space(64); height: Style.space(28); radius: Style.cornerRadius
                  visible: root.pasteDetail !== null && root.pasteDetail.canEdit
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                  Text { anchors.centerIn: parent; text: "编辑"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.startPasteEdit() }
                }
                Rectangle {
                  readonly property bool canDelete: root.pasteDetail !== null && root.pasteDetail.canEdit
                  width: root.pasteDeleteConfirm ? Style.space(112) : Style.space(64)
                  height: Style.space(28)
                  radius: Style.cornerRadius
                  visible: canDelete
                  color: root.pasteDeleteConfirm ? Color.urgent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                  Text {
                    anchors.centerIn: parent
                    text: root.pasteDeleteConfirm ? "确认删除？" : "删除"
                    color: root.pasteDeleteConfirm ? Color.background : Qt.darker(root.contentForeground, 1.15)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.pasteDeleteConfirm) root.deletePaste(root.pasteDetailId)
                      else root.pasteDeleteConfirm = true
                    }
                  }
                }
                Text {
                  width: Math.max(Style.space(40), parent.width - Style.space(92) * 2 - Style.space(64) - Style.space(112) - Style.space(176) - Style.space(48))
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  text: root.pasteWriteStatus
                  color: root.pasteWriteStatus.indexOf("失败") >= 0 ? Color.urgent : Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
                Rectangle {
                  width: Style.space(120); height: Style.space(28)
                  color: "transparent"
                  Text { anchors.centerIn: parent; text: "在浏览器打开"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://www.luogu.com.cn/paste/" + root.pasteDetailId) }
                }
              }
            }

            // ---------------- 列表态 ----------------
            Column {
              visible: root.pasteDetailId === ""
              width: parent.width
              spacing: Style.space(6)

              Text {
                visible: root.pasteItems.length === 0 && !root.pasteLoading
                text: "暂无云剪贴板"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Repeater {
                model: root.pasteItems
                delegate: Rectangle {
                  required property var modelData
                  width: parent.width
                  height: Style.space(46)
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                  Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(2)
                    Row {
                      width: parent.width
                      spacing: Style.space(8)
                      Text { width: Style.space(96); text: "/" + modelData.id; color: Color.accent; font.family: "monospace"; font.pixelSize: Style.font.caption }
                      Text { width: Style.space(44); text: modelData.isPublic ? "公开" : "私密"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                      Text {
                        width: parent.width - Style.space(96) - Style.space(44) - Style.space(20)
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: Model.formatChatTime(modelData.updateAt > modelData.time ? modelData.updateAt : modelData.time) + "   " + modelData.data.length + " 字"
                        color: Qt.darker(root.contentForeground, 1.55)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                    Text {
                      width: parent.width
                      elide: Text.ElideRight
                      text: root.pastePreview(modelData)
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPasteDetail(modelData.id) }
                }
              }

              Rectangle {
                readonly property bool hasItems: root.pasteItems.length > 0
                visible: hasItems && (root.pasteHasMore || root.pasteLoading)
                width: parent.width
                height: Style.space(30)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.07)
                Text { anchors.centerIn: parent; text: root.pasteLoading ? "读取中…" : "加载更多"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadPastes(true) }
              }
            }
          }

          // ---------------- 洛谷账号设置（只读）----------------
          // 奖项认证 / 账号安全 / 第三方绑定，三段都来自 /user/setting* 的 JSON。
          // 「改」的接口在这台机器上探不到：设置页 HTML 对非浏览器客户端是 302
          // 自我循环，读不到前端 JS，所以这里只展示，修改走「打开洛谷设置」。
          Column {
            visible: root.detailPage === "account"
            width: parent.width
            spacing: Style.space(12)

            Row {
              width: parent.width
              Text { width: parent.width - Style.space(140); text: "洛谷设置"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.iconLarge; font.bold: true }
              Rectangle {
                width: Style.space(140)
                height: Style.space(28)
                color: "transparent"
                Text { anchors.centerIn: parent; text: "打开洛谷设置"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://www.luogu.com.cn/user/setting") }
              }
            }

            Text {
              visible: root.accountLoading
              text: "正在读取账号设置…"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            // ---- 个人信息 ----
            Text { text: "个人信息"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
            Rectangle {
              width: parent.width
              height: infoBody.implicitHeight + Style.space(20)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
              Column {
                id: infoBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(4)
                Text {
                  width: parent.width
                  text: (root.profile.name || "未登录") + "   UID " + root.profile.uid
                    + (root.accountPrizes ? (root.accountPrizes.hasRealName ? "   已实名" : "   未实名") : "")
                  color: Model.userColor({ color: root.profile.color }, root.contentForeground)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: (root.accountPrizes && root.accountPrizes.oiLevel > 0 ? "OI 认证等级 " + root.accountPrizes.oiLevel + " 级" : "")
                    + (root.accountPrizes && root.accountPrizes.xcpcLevel > 0 ? "   XCPC " + root.accountPrizes.xcpcLevel + " 级" : "")
                    + (root.profile.ccfLevel > 0 ? "   CCF " + root.profile.ccfLevel + " 级" : "")
                  visible: text !== ""
                  color: Qt.darker(root.contentForeground, 1.45)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
                Text {
                  width: parent.width
                  visible: root.profile.introduction !== "" || root.profile.slogan !== ""
                  text: root.profile.introduction !== "" ? root.profile.introduction : root.profile.slogan
                  wrapMode: Text.WordWrap
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            // ---- 编辑个人信息（写回洛谷）----
            Rectangle {
              width: parent.width
              height: editBody.implicitHeight + Style.space(20)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)

              Column {
                id: editBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Text { text: "编辑个人信息"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1.2 }

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Text { width: Style.space(48); anchors.verticalCenter: parent.verticalCenter; text: "签名"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  TextField {
                    width: parent.width - Style.space(56)
                    placeholderText: "个人签名"
                    text: root.userSpaceSlogan
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    onTextChanged: root.userSpaceSlogan = text
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Text { width: Style.space(48); anchors.verticalCenter: parent.verticalCenter; text: "简介"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  TextField {
                    width: parent.width - Style.space(56)
                    placeholderText: "个人简介"
                    text: root.userSpaceIntro
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    onTextChanged: root.userSpaceIntro = text
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Text { width: Style.space(48); anchors.verticalCenter: parent.verticalCenter; text: "背景图"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  TextField {
                    width: parent.width - Style.space(56)
                    placeholderText: "背景图链接（新图仍需在网页上传）"
                    text: root.userSpaceBackground
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    onTextChanged: root.userSpaceBackground = text
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Rectangle {
                    readonly property bool ready: !root.userSpaceSaving && csrfToken !== ""
                    width: Style.space(88)
                    height: Style.space(32)
                    radius: Style.cornerRadius
                    color: ready ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                    Text { anchors.centerIn: parent; text: root.userSpaceSaving ? "保存中…" : "保存"; color: parent.ready ? Color.background : Qt.darker(root.contentForeground, 1.3); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveUserSpace() }
                  }
                  Text {
                    width: parent.width - Style.space(96)
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.userSpaceStatus !== "" ? root.userSpaceStatus : "只提交改动过的字段；保存后立即同步到洛谷"
                    color: root.userSpaceStatus.indexOf("失败") >= 0 ? Color.urgent : Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            // ---- 奖项认证 ----
            Text { text: "奖项认证"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
            Text {
              width: parent.width
              visible: root.accountPrizes !== null && (root.accountPrizes.realName !== "" || root.accountPrizes.affiliation !== "")
              wrapMode: Text.WordWrap
              text: root.accountPrizes
                ? ("实名 " + (root.accountPrizes.realName !== "" ? root.accountPrizes.realName : "—")
                   + (root.accountPrizes.affiliation !== "" ? "   " + root.accountPrizes.affiliation : ""))
                : ""
              color: Qt.darker(root.contentForeground, 1.45)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
            Repeater {
              model: root.accountPrizes ? root.accountPrizes.prizes : []
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: Style.space(38)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
                Row {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(8)
                  Text { width: Style.space(38); text: modelData.year > 0 ? String(modelData.year) : ""; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  Text { width: Style.space(80); elide: Text.ElideRight; text: modelData.contest + (modelData.event !== "" ? " " + modelData.event : ""); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Text { width: Style.space(80); text: modelData.prize; color: Model.userColor({ color: root.profile.color }, Color.accent); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                  Text { width: Style.space(56); text: modelData.type; color: Qt.darker(root.contentForeground, 1.55); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  Text {
                    width: parent.width - Style.space(38) - Style.space(80) - Style.space(80) - Style.space(56) - Style.space(40)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: (modelData.score > 0 ? modelData.score + " 分" : "") + (modelData.rank > 0 ? "   #" + modelData.rank : "")
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
            Text {
              visible: root.accountPrizes !== null && root.accountPrizes.prizes.length === 0
              text: "暂无已认证的奖项"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            // ---- 账号安全 ----
            Text { text: "账号安全"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
            Rectangle {
              width: parent.width
              visible: root.accountSecurity !== null
              height: safeBody.implicitHeight + Style.space(20)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
              Column {
                id: safeBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(4)
                Text { width: parent.width; text: root.accountSecurity ? ("邮箱 " + (root.accountSecurity.email !== "" ? root.accountSecurity.email : "未绑定")) : ""; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                Text { width: parent.width; text: root.accountSecurity ? ("手机 " + (root.accountSecurity.phone !== "" ? root.accountSecurity.phone : "未绑定") + "   实名 " + (root.accountSecurity.realName !== "" ? root.accountSecurity.realName : "未实名")) : ""; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                Text { width: parent.width; text: root.accountSecurity ? ("两步验证 " + (root.accountSecurity.totpSet ? "已开启" : "未开启")) : ""; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              }
            }

            // ---- 第三方绑定 ----
            Text { text: "第三方绑定"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
            Repeater {
              model: {
                var out = []
                var bindings = root.accountBindings
                if (!bindings) return out
                for (var i = 0; i < bindings.vjudge.length; i++) out.push({ label: "VJudge", value: bindings.vjudge[i].username + "（" + bindings.vjudge[i].oj + "）" })
                for (var j = 0; j < bindings.openid.length; j++) out.push({ label: "OpenID", value: bindings.openid[j].username + "（平台 " + bindings.openid[j].platform + "）" })
                return out
              }
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: Style.space(34)
                radius: Style.cornerRadius
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
                Row {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(10)
                  Text { width: Style.space(70); text: modelData.label; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Text { width: parent.width - Style.space(80); elide: Text.ElideRight; text: modelData.value; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                }
              }
            }
            Text {
              visible: root.accountBindings !== null && root.accountBindings.vjudge.length === 0 && root.accountBindings.openid.length === 0
              text: "暂无第三方绑定"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

      }
      }
    }
  }
  }

  // ---- 「洛谷题目」独立窗口 -------------------------------------------------
  // 从比赛里点进来的题目在这里看/交，和「洛谷中心」「洛谷比赛」互不干扰。
  Timer {
    id: problemPlacementTimer
    interval: 250
    repeat: true
    property int attempts: 0
    onTriggered: {
      if (!root.problemWindowOpen) { stop(); return }
      attempts++
      var selector = 'title:^(洛谷题目)$'
      if (attempts === 1 && root.detailTargetWorkspace !== "")
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + root.detailTargetWorkspace + '", window = "' + selector + '", follow = false })')
      Hyprland.dispatch('hl.dsp.window.float({ action = "on", window = "' + selector + '" })')
      Hyprland.dispatch('hl.dsp.window.resize({ x = 1420, y = 900, relative = false, window = "' + selector + '" })')
      if (attempts >= 2) {
        Hyprland.dispatch('hl.dsp.window.center({ window = "' + selector + '" })')
        if (attempts === 2) Hyprland.dispatch('hl.dsp.focus({ window = "' + selector + '" })')
      }
      if (attempts >= 6) stop()
    }
  }

  Loader {
    id: problemLoader
    active: root.problemWindowOpen
    sourceComponent: problemWindowComponent
  }

  Component {
    id: problemWindowComponent

    FloatingWindow {
      id: problemWindow
      title: "洛谷题目"
      visible: true
      color: Color.background
      implicitWidth: 1420
      implicitHeight: 900
      minimumSize: Qt.size(680, 520)

      onVisibleChanged: {
        if (!visible) {
          // 先把草稿落盘再销毁：防抖计时器可能还差几百毫秒
          problemPanel.flushDraft()
          root.closeProblemWindow()
        }
      }
      Flickable {
        id: problemFlick
        anchors.fill: parent
        anchors.margins: Style.space(20)
        clip: true
        contentWidth: width
        contentHeight: problemBody.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        property int wheelStep: 220
        property real wheelPixelFactor: 5.0
        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            var step = wheelStepFor(event, problemFlick.wheelPixelFactor, problemFlick.wheelStep)
            if (step !== 0) event.accepted = true
            applyWheel(problemFlick, step)
          }
        }

        // Flickable 不是布局器：它里面的直属子项都停在 y=0。原来标题 Row 和
        // ProblemPanel 是并排的两个子项，于是题目内容直接叠在标题上（文字重叠）。
        // 用 Column 包一层，并让内容高度跟着这个 Column 走。
        Column {
          id: problemBody
          width: parent.width
          spacing: Style.space(12)

          Row {
            width: parent.width
            spacing: Style.space(10)
            Text {
              width: parent.width - Style.space(120)
              text: "题目  " + root.problemWindowPid
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Rectangle {
              width: Style.space(110)
              height: Style.space(28)
              color: "transparent"
              Text { anchors.centerIn: parent; text: "在洛谷打开"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://www.luogu.com.cn/problem/" + root.problemWindowPid) }
            }
          }

          ProblemPanel {
            id: problemPanel
            width: parent.width
            pid: root.problemWindowPid
            defaultLanguageId: root.defaultLanguageId
            markdownBlockLimit: root.markdownBlockLimit
            uid: root.uid
            clientId: root.clientId
            csrfToken: root.csrfToken
            tagTable: root.tagTable
            draftHost: root
            foreground: root.contentForeground
            accentColor: Color.accent
            fontFamily: root.contentFontFamily
            onRequestTagTable: root.loadTagTable()
          }
        }
      }
    }
  }

  // ---- 「洛谷比赛」独立窗口 -------------------------------------------------
  // 比赛详情以前是内嵌在比赛列表页里的一个子视图；现在点列表里任意一场（包括
  // 已结束的）都会开这个独立窗口，和「洛谷中心」一样由 Hyprland 摆位。
  Timer {
    id: contestPlacementTimer
    interval: 250
    repeat: true
    property int attempts: 0
    onTriggered: {
      if (!root.contestDetailOpen) { stop(); return }
      attempts++
      var selector = 'title:^(洛谷比赛)$'
      if (attempts === 1 && root.detailTargetWorkspace !== "")
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + root.detailTargetWorkspace + '", window = "' + selector + '", follow = false })')
      Hyprland.dispatch('hl.dsp.window.float({ action = "on", window = "' + selector + '" })')
      Hyprland.dispatch('hl.dsp.window.resize({ x = 860, y = 700, relative = false, window = "' + selector + '" })')
      if (attempts >= 2) {
        Hyprland.dispatch('hl.dsp.window.center({ window = "' + selector + '" })')
        if (attempts === 2) Hyprland.dispatch('hl.dsp.focus({ window = "' + selector + '" })')
      }
      if (attempts >= 6) stop()
    }
  }

  Loader {
    id: contestLoader
    active: root.contestDetailOpen
    sourceComponent: contestWindowComponent
  }

  Component {
    id: contestWindowComponent

    FloatingWindow {
      id: contestWindow
      title: "洛谷比赛"
      visible: true
      color: Color.background
      implicitWidth: 860
      implicitHeight: 700
      minimumSize: Qt.size(640, 460)

      // 合成器那边关掉（SUPER+Q）也会走这里，于是标志位落下、对象被销毁。
      onVisibleChanged: {
        if (!visible) root.closeContestDetail()
      }

      Flickable {
        id: contestFlick
        anchors.fill: parent
        anchors.margins: Style.space(20)
        clip: true
        contentWidth: width
        contentHeight: contestBody.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        property int wheelStep: 220
        property real wheelPixelFactor: 5.0
        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            var step = wheelStepFor(event, contestFlick.wheelPixelFactor, contestFlick.wheelStep)
            if (step !== 0) event.accepted = true
            applyWheel(contestFlick, step)
          }
        }

        Column {
          id: contestBody
          width: parent.width
          spacing: Style.space(12)

          Row {
            width: parent.width
            spacing: Style.space(10)
            Text {
              // 110(按钮) + 10(spacing)：原来漏了间距，标题行比容器宽 10px
              width: parent.width - Style.space(120)
              text: root.contestDetail ? root.contestDetail.name : "比赛详情"
              wrapMode: Text.WordWrap
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }
            Rectangle {
              width: Style.space(110)
              height: Style.space(28)
              color: "transparent"
              Text { anchors.centerIn: parent; text: "在洛谷打开"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.contestDetail) Qt.openUrlExternally("https://www.luogu.com.cn/contest/" + root.contestDetail.id) }
            }
          }

          Text {
            visible: root.contestDetailLoading
            text: "正在读取比赛详情…"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            width: parent.width
            visible: root.contestDetail !== null
            text: root.contestDetail
              ? (Model.formatContestTime(root.contestDetail.startTime) + " - " + Model.formatContestTime(root.contestDetail.endTime)
                 + "   " + Model.contestStatus(root.contestDetail)
                 + (root.contestDetail.host !== "" ? "   " + root.contestDetail.host : "")
                 + (root.contestDetail.squad ? "   组队赛" : ""))
              : ""
            wrapMode: Text.WordWrap
            color: Qt.darker(root.contentForeground, 1.45)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            width: parent.width
            visible: root.contestDetail !== null && root.contestDetail.problems.length > 0
            // 注意：visible 有保护不代表 text 也有——QML 会求值所有绑定，
            // 所以 text 自己也要判空（漏了就会抛 Cannot read property of null）。
            text: root.contestDetail ? ("题目 " + root.contestDetail.problems.length + " 题") : ""
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Repeater {
            model: root.contestDetail ? root.contestDetail.problems : []
            delegate: Rectangle {
              required property var modelData
              width: parent.width
              height: Style.space(44)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.055)
              Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)
                Text { width: Style.space(26); text: modelData.no; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                Rectangle {
                  // 这里原来把名字截成 4 个字（「普及+/提高」变成「普及+/」），改成跟着文字宽度
                  id: contestProblemDifficultyChip
                  width: Math.max(Style.space(38), contestProblemDifficultyLabel.implicitWidth + Style.space(10))
                  height: Style.space(18)
                  radius: Style.space(3)
                  color: Model.difficultyColor(modelData.difficulty)
                  Text {
                    id: contestProblemDifficultyLabel
                    anchors.centerIn: parent
                    text: Model.difficultyName(modelData.difficulty)
                    color: Color.background
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
                Text { width: parent.width - Style.space(26) - contestProblemDifficultyChip.width - Style.space(60) - Style.space(24); elide: Text.ElideRight; text: modelData.pid + "  " + modelData.name; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                Text { width: Style.space(60); horizontalAlignment: Text.AlignRight; text: modelData.accepted ? "已通过" : (modelData.submitted ? "尝试过" : (modelData.score > 0 ? modelData.score + " 分" : "")); color: modelData.accepted ? Color.accent : Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openProblemWindow(modelData.pid)
              }
            }
          }

          Rectangle {
            visible: root.contestDetail !== null && root.contestDetail.problems.length > 0
            width: parent.width
            height: 1
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.16)
          }

          MarkdownView {
            visible: root.contestDetail !== null && root.contestDetail.description !== ""
            width: parent.width
            blockLimit: root.markdownBlockLimit
            markdown: root.contestDetail ? root.contestDetail.description : ""
            foreground: root.contentForeground
            accentColor: Color.accent
            fontFamily: root.contentFontFamily
            basePixelSize: Style.font.bodySmall
          }
        }
      }
    }
  }

}
