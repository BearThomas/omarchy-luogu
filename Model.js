function numberOr(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : fallback
}

function textOr(value, fallback) {
  var text = value === undefined || value === null ? "" : String(value)
  return text === "" ? fallback : text
}

function parseDailyCounts(value) {
  var result = []
  if (Array.isArray(value)) return value
  if (!value || typeof value !== "object") return result
  Object.keys(value).sort().forEach(function(date) {
    var raw = value[date]
    var passed = Array.isArray(raw) ? numberOr(raw[0], 0) : 0
    var submitted = Array.isArray(raw) ? numberOr(raw[1], passed) : numberOr(raw, 0)
    result.push({ date: date, passed: passed, count: submitted })
  })
  return result
}

function parseProfile(raw) {
  var empty = {
    name: "",
    uid: 0,
    ccfLevel: 0,
    xcpcLevel: 0,
    ranking: 0,
    guzhi: 0,
    passedProblems: 0,
    submittedProblems: 0,
    guScores: { basic: 0, practice: 0, social: 0, contest: 0, prize: 0 },
    elo: 0,
    eloDelta: 0,
    eloContest: "",
    eloHistory: [],
    dailyCounts: [],
    avatar: "",
    slogan: "",
    introduction: "",
    background: "",
    color: "",
    verified: false,
    followerCount: 0,
    followingCount: 0,
    registerTime: 0,
    prizes: []
  }

  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : raw
    var data = root && root.data ? root.data : {}
    var user = data.user || root.user || {}
    var gu = data.gu || {}
    var scores = gu.scores || {}
    var history = Array.isArray(data.elo) ? data.elo : []
    var latest = history.length > 0 ? history[0] : {}
    var daily = parseDailyCounts(data.dailyCounts)

    return {
      name: textOr(user.name, ""),
      uid: numberOr(user.uid, 0),
      ccfLevel: numberOr(user.ccfLevel, 0),
      ranking: numberOr(user.ranking, 0),
      guzhi: numberOr(gu.rating, 0),
      passedProblems: numberOr(user.passedProblemCount, 0),
      submittedProblems: numberOr(user.submittedProblemCount, 0),
      guScores: {
        basic: numberOr(scores.basic, 0),
        practice: numberOr(scores.practice, 0),
        social: numberOr(scores.social, 0),
        contest: numberOr(scores.contest, 0),
        prize: numberOr(scores.prize, 0)
      },
      elo: numberOr(latest.rating, 0),
      // 最新一场的分数变化：prevDiff 是上一场结束时的分（null 表示首场）
      eloDelta: latest.prevDiff === null || latest.prevDiff === undefined ? 0 : numberOr(latest.rating, 0) - numberOr(latest.prevDiff, 0),
      eloContest: textOr(latest.contest && latest.contest.name, ""),
      eloHistory: history,
      dailyCounts: daily,
      avatar: textOr(user.avatar, ""),
      slogan: textOr(user.slogan, ""),
      introduction: textOr(user.introduction, ""),
      background: textOr(user.background, ""),
      color: textOr(user.color, ""),
      verified: user.verified === true,
      followerCount: numberOr(user.followerCount, 0),
      followingCount: numberOr(user.followingCount, 0),
      registerTime: numberOr(user.registerTime, 0),
      xcpcLevel: numberOr(user.xcpcLevel, 0),
      prizes: Array.isArray(data.prizes) ? data.prizes.map(function(item) {
        var prize = item.prize || item
        return {
          year: numberOr(prize.year, 0),
          contest: textOr(prize.contest, ""),
          event: textOr(prize.event, ""),
          prize: textOr(prize.prize, ""),
          score: numberOr(prize.score, 0),
          rank: numberOr(prize.rank, 0)
        }
      }).filter(function(item) { return item.prize !== "" || item.contest !== "" }) : []
    }
  } catch (error) {
    return empty
  }
}

function parseActivity(raw) {
  var result = { notifications: [], messages: [], unreadNotifications: 0, unreadMessages: 0 }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var notice = root.notice || {}
    var chat = root.chat || {}
    var noticeData = notice.data || notice.currentData || {}
    var chatData = chat.data || chat.currentData || {}
    var noticeBox = noticeData.notifications || {}
    var notices = Array.isArray(noticeBox) ? noticeBox : (noticeBox.result || noticeData.result || noticeData.list || [])
    var chats = chatData.latestChats || chatData.chats || chatData.users || chatData.result || chatData.list || []
    if (!Array.isArray(notices)) notices = []
    if (!Array.isArray(chats)) chats = []
    result.notifications = notices.slice(0, 12).map(function(item) {
      return {
        title: textOr(item.title || item.name || item.type, "洛谷通知"),
        content: textOr(item.content || item.message || item.description, "有一条新通知"),
        time: numberOr(item.time || item.createdAt || item.createTime, 0),
        unread: item.read === false || item.isRead === false || item.unread === true
      }
    })
    result.messages = chats.slice(0, 12).map(function(item) {
      var user = item.target || item.user || item.sender || item.from || {}
      return {
        uid: numberOr(user.uid || item.uid, 0),
        name: textOr(user.name || item.name || item.username, "洛谷用户"),
        content: textOr(item.content || item.message || item.lastMessage, "私信会话"),
        time: numberOr(item.time || item.updatedAt || item.updateTime, 0),
        unread: numberOr(item.unread || item.unreadCount, 0) > 0 || item.read === false
      }
    })
    result.unreadNotifications = result.notifications.filter(function(item) { return item.unread }).length
    var unreadCount = chatData.unreadCount
    if (Array.isArray(unreadCount)) unreadCount = unreadCount.reduce(function(total, value) { return total + numberOr(value, 0) }, 0)
    result.unreadMessages = numberOr(unreadCount, 0) || result.messages.filter(function(item) { return item.unread }).length
  } catch (error) {}
  return result
}

function parseFeed(raw) {
  var source = String(raw === undefined || raw === null ? "" : raw)
  if (/^\s*</.test(source)) return parseFeedHtml(source)
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var items = Array.isArray(root) ? root : (root.data || root.feeds || [])
    if (!Array.isArray(items)) return []
    return items.slice(0, 30).map(function(item) {
      var time = item.time && item.time.date ? item.time.date : item.time
      var author = item.user || item.author || {}
      return { uid: numberOr(item.uid, numberOr(author.uid, 0)), name: textOr(author.name || item.username, ""), color: textOr(author.color || item.color, ""), content: textOr(item.comment || item.content, ""), time: textOr(time, "") }
    }).filter(function(item) { return item.content !== "" })
  } catch (error) { return [] }
}

function feedInlineHtml(content, mentionColor) {
  var color = mentionColor || "#3498db"
  return escapeHtml(content).replace(/(^|\s)@([^\s@，。！？、:：]+)/g, function(match, lead, name) {
    return lead + '<font color="' + color + '">@' + name + '</font>'
  }).replace(/\n/g, "<br/>")
}

function parseFeedHtml(html) {
  function plain(value) {
    return String(value || "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/gi, " ").replace(/&amp;/gi, "&").replace(/&lt;/gi, "<").replace(/&gt;/gi, ">").replace(/\s+/g, " ").trim()
  }
  var chunks = String(html || "").split(/<li\b[^>]*\bfeed-li\b[^>]*>/i)
  var result = []
  for (var i = 1; i < chunks.length; i++) {
    var chunk = chunks[i]
    var id = (chunk.match(/data-feed-id="(\d+)"/) || [])[1]
    var uid = (chunk.match(/href="\/user\/(\d+)"/) || [])[1]
    var nameMatch = chunk.match(/feed-username[\s\S]*?<a[^>]*class=['"]([^'"]*)['"][^>]*>([\s\S]*?)<\/a>/i)
    var body = (chunk.match(/<div class="am-comment-bd">([\s\S]*?)<\/div>\s*<\/div>\s*<\/li>/i) || [])[1]
    var time = (chunk.match(/\b20\d{2}-\d\d-\d\d\s+\d\d:\d\d:\d\d/) || [])[0]
    var content = plain(body)
    if (content !== "") result.push({ id: numberOr(id, 0), uid: numberOr(uid, 0), name: plain(nameMatch ? nameMatch[2] : ""), color: nameMatch ? textOr(nameMatch[1], "") : "", content: content, time: textOr(time, "") })
  }
  return result
}

// Board list with each board's posting permission. `canPost` is per board:
// querying GET /discuss?forum=<slug> reports whether THIS account may post
// there (verified live: academics/problem true, siteaffairs false for
// BearThomas). Shapes accepted: [{slug, name, canPost}] from the permission
// probe, or the raw {data:{publicForums:[...]}} response.
function parseForumPermissions(raw) {
  var fallback = [
    { value: "academics", name: "学术版", label: "学术版", canPost: true },
    { value: "problem", name: "题目总版", label: "题目总版", canPost: true },
    { value: "siteaffairs", name: "站务版", label: "站务版", canPost: true }
  ]
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var list = Array.isArray(root) ? root : (root.data && root.data.publicForums)
    if (!Array.isArray(list)) return fallback
    var academics = null
    var others = []
    for (var i = 0; i < list.length; i++) {
      var forum = list[i] || {}
      var slug = textOr(forum.slug, "")
      if (slug === "") continue
      var name = textOr(forum.name, slug)
      var canPost = forum.canPost === undefined ? true : forum.canPost === true
      var entry = {
        value: slug,
        name: name,
        label: canPost ? name : name + "（无发帖权限）",
        canPost: canPost
      }
      if (slug === "academics") academics = entry
      else others.push(entry)
    }
    if (academics === null && others.length === 0) return fallback
    return academics === null ? others : [academics].concat(others)
  } catch (error) {
    return fallback
  }
}

// Boards for the post form. The read API returns data.publicForums as
// [{name, slug, ...}] and the write endpoint wants the slug — "academics" is
// 学术版, whereas a bare "P" matches no board at all. 学术版 is put first
// because it is the default. The known public boards are the fallback so the
// form still works when the fetch fails.
function parseForums(raw) {
  var fallback = [
    { value: "academics", label: "学术版" },
    { value: "problem", label: "题目总版" },
    { value: "siteaffairs", label: "站务版" }
  ]
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root && root.data ? root.data : root
    var list = data ? data.publicForums : null
    if (!Array.isArray(list)) return fallback
    var academics = null
    var others = []
    for (var i = 0; i < list.length; i++) {
      var forum = list[i] || {}
      var slug = textOr(forum.slug, "")
      if (slug === "") continue
      var entry = { value: slug, label: textOr(forum.name, slug) }
      if (slug === "academics") academics = entry
      else others.push(entry)
    }
    if (academics === null && others.length === 0) return fallback
    return academics === null ? others : [academics].concat(others)
  } catch (error) {
    return fallback
  }
}

function parsePosts(raw) {
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var posts = root && root.data && root.data.posts ? root.data.posts.result : (root.posts || [])
    if (!Array.isArray(posts)) return []
    return posts.slice(0, 30).map(function(item) {
      var author = item.author || {}
      var time = item.time && item.time.date ? item.time.date : item.time
      return {
        id: numberOr(item.id, 0),
        title: textOr(item.title, "无标题帖子"),
        author: textOr(author.name, "未知用户"),
        authorUid: numberOr(author.uid, 0),
        authorCcfLevel: numberOr(author.ccfLevel, 0),
        authorColor: textOr(author.color, ""),
        replyCount: numberOr(item.replyCount, 0),
        time: textOr(time, ""),
        forum: textOr(item.forum && (item.forum.name || item.forum.slug), "讨论区")
      }
    }).filter(function(item) { return item.id > 0 })
  } catch (error) { return [] }
}

function compactNumber(value) {
  var number = numberOr(value, 0)
  if (number >= 1000000) return (number / 1000000).toFixed(1) + "m"
  if (number >= 1000) return (number / 1000).toFixed(1) + "k"
  return String(Math.round(number))
}

function rankingLabel(value) {
  return numberOr(value, 0) > 0 ? "#" + compactNumber(value) : "—"
}

function parseContests(raw) {
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : raw
    var result = Array.isArray(root)
      ? root
      : (root && root.data && root.data.contests ? root.data.contests.result : [])
    if (!Array.isArray(result)) return []
    return result.map(function(item) {
      return {
        id: numberOr(item.id, 0),
        name: textOr(item.name, "未命名比赛"),
        startTime: numberOr(item.startTime, 0),
        endTime: numberOr(item.endTime, 0),
        joined: item.joined === null || item.joined === undefined ? null : numberOr(item.joined, 0) > 0,
        squad: item.squad === true,
        rated: item.rated === true || numberOr(item.rated, 0) > 0,
        problemCount: numberOr(item.problemCount, 0)
      }
    }).filter(function(item) { return item.id > 0 })
  } catch (error) {
    return []
  }
}

// 洛谷的用户名配色。同一个概念有两种下发形态，都必须认：
//   · 私信 / 用户搜索接口给的是裸名 —— "Red"、"Orange"、"Gray"
//   · 犇犇的 HTML 片段给的是类名 —— "lg-fg-red"、"color-purple"
// 早先只匹配带前缀的类名，于是私信里所有人的名字都退回了默认色。
var USER_COLOR_NAMES = {
  gray: "#bfbfbf", grey: "#bfbfbf", blue: "#3498db", green: "#52c41a", yellow: "#ffc116",
  orange: "#f39c11", red: "#fe4c61", purple: "#9d3dcf", brown: "#8b5a2b", black: "#4c4c4c",
  cheater: "#8b5a2b", admin: "#fe4c61"
}

function userColor(user, fallback) {
  var raw = user && user.color ? String(user.color).trim() : ""
  if (raw === "") return fallback || "#bfbfbf"
  if (/^#[0-9a-f]{3,8}$/i.test(raw)) return raw
  var key = raw.toLowerCase()
  var className = key.match(/(?:lg-fg-|color-|lg-)([a-z]+)/)
  if (className) key = className[1]
  return USER_COLOR_NAMES[key] !== undefined ? USER_COLOR_NAMES[key] : (fallback || "#bfbfbf")
}

function contestStatus(item) {
  var now = Math.floor(Date.now() / 1000)
  if (now < item.startTime) return "未开始"
  if (now < item.endTime) return "进行中"
  return "已结束"
}

function contestStatusColor(item) {
  var status = contestStatus(item)
  if (status === "进行中") return "accent"
  if (status === "未开始") return "normal"
  return "muted"
}

function formatContestTime(timestamp) {
  var date = new Date(numberOr(timestamp, 0) * 1000)
  if (isNaN(date.getTime())) return "时间未知"
  function pad(value) { return value < 10 ? "0" + value : String(value) }
  return (date.getMonth() + 1) + "月" + date.getDate() + "日 " + pad(date.getHours()) + ":" + pad(date.getMinutes())
}

function contestSignupLabel(item) {
  if (item.joined === true) return "已报名"
  if (item.joined === false) return item.squad ? "需组队" : "未报名"
  return "未知"
}

function parseContestDetail(raw) {
  var empty = { id: 0, name: "", startTime: 0, endTime: 0, joined: null, rated: false, squad: false, problemCount: 0, description: "", host: "", problems: [] }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var contest = data.contest || {}
    // 题目列表在 data.contestProblems 里（不是 contest.problems）；每项形如
    // {no:"A", score:100, problem:{pid,name,difficulty,submitted,accepted}}。
    var list = Array.isArray(data.contestProblems) ? data.contestProblems
      : (Array.isArray(data.problems) ? data.problems : ((data.problems && data.problems.result) || []))
    return {
      id: numberOr(contest.id, 0), name: textOr(contest.name, "未命名比赛"), startTime: numberOr(contest.startTime, 0), endTime: numberOr(contest.endTime, 0),
      joined: data.joined === null || data.joined === undefined ? null : numberOr(data.joined, 0) > 0,
      rated: contest.rated === true || numberOr(contest.rated, 0) > 0, squad: contest.squad === true,
      problemCount: numberOr(contest.problemCount, Array.isArray(list) ? list.length : 0), description: textOr(contest.description, ""),
      host: textOr(contest.host && contest.host.name, ""),
      problems: Array.isArray(list) ? list.map(function(item) {
        var problem = item.problem || item
        return {
          pid: textOr(problem.pid, ""),
          name: textOr(problem.name, "未命名题目"),
          no: textOr(item.no, ""),
          score: numberOr(item.score, numberOr(problem.fullScore, 0)),
          difficulty: numberOr(problem.difficulty, 0),
          submitted: problem.submitted === true,
          accepted: problem.accepted === true
        }
      }).filter(function(item) { return item.pid !== "" }) : []
    }
  } catch (error) { return empty }
}

// curl is invoked with `-w '|%{http_code}'` on every write request, so the HTTP
// status is appended after the body and has to be peeled off again.
function splitHttpCode(output) {
  var raw = output === undefined || output === null ? "" : String(output)
  var match = raw.match(/\|(\d{3})\s*$/)
  if (!match) return { code: "", body: raw }
  return { code: match[1], body: raw.slice(0, match.index) }
}

// A rejected write (bad CSRF token, wrong captcha, rate limit) comes back as an
// HTTP 4xx whose JSON body carries the actual reason. `body` is the payload with
// the trailing status code already removed, `httpCode` the code curl reported.
// The status still matters for an empty or non-JSON body: because the write
// commands do not use curl -f, a 4xx with no body would otherwise look like a
// write that completed.
function writeResponseSucceeded(body, httpCode) {
  var raw = String(body === undefined || body === null ? "" : body).trim()
  var code = String(httpCode === undefined || httpCode === null ? "" : httpCode).trim()
  // A write is only successful on positive evidence. The old version defaulted
  // to success when it could not make sense of the response (empty body, HTML
  // instead of JSON, or a JSON object with no status field), which is how a
  // refusal nobody parsed — e.g. 站务版, where this account has no posting
  // permission — got reported as "帖子已发布" while nothing was published.
  if (raw === "") return false
  try {
    var payload = JSON.parse(raw)
    if (payload.status !== undefined) return numberOr(payload.status, -1) === 0 || numberOr(payload.status, -1) === 200
    if (payload.code !== undefined) return numberOr(payload.code, -1) === 0 || numberOr(payload.code, -1) === 200
    if (payload.errorCode !== undefined) return numberOr(payload.errorCode, -1) === 0 || numberOr(payload.errorCode, -1) === 200
    // Explicit refusal shape: a bare false/null payload is not a success.
    if (payload.data === false || payload.data === null) return false
    return !payload.error && !payload.errorType && !payload.errorMessage && !payload.message
  } catch (error) {
    // Not JSON at all: a redirect/login/permission HTML page proves nothing.
    return false
  }
}

// Returns "" when the payload holds no human-readable reason, so the caller can
// fall back to a generic hint instead of printing raw JSON at the user.
function writeResponseMessage(body) {
  var raw = String(body === undefined || body === null ? "" : body).trim()
  if (raw === "") return ""
  try {
    var payload = JSON.parse(raw)
    var message = payload.errorMessage || payload.message || payload.error
    if (!message && typeof payload.data === "string") message = payload.data
    if (!message && payload.data) message = payload.data.message || payload.data.errorMessage
    return message ? String(message).slice(0, 160) : ""
  } catch (error) {
    return raw.slice(0, 160)
  }
}

function writeFailureMessage(httpCode, body) {
  var code = String(httpCode === undefined || httpCode === null ? "" : httpCode).trim()
  var raw = String(body === undefined || body === null ? "" : body).trim()
  var detail = writeResponseMessage(body)
  if (code === "000") return "无法连接洛谷，请检查网络" + (detail === "" ? "" : "（" + detail + "）")
  if (detail !== "") return code === "" ? detail : detail + "（HTTP " + code + "）"
  if (raw === "") {
    // No evidence either way: never claim success, but do not claim failure
    // either — tell the caller to look at the site.
    var suffix = code === "" ? "" : "（HTTP " + code + "）"
    return "洛谷" + suffix + "没有返回内容，无法确认是否成功，请刷新列表或到洛谷页面确认"
  }
  // Something unclassifiable came back. Show a short excerpt so the real reason
  // (a permission page, a redirect stub, ...) is visible instead of hidden.
  if (raw.length <= 120) return (code === "" ? "洛谷返回：" : "洛谷返回 HTTP " + code + "：" ) + raw
  return code === "" ? "洛谷没有返回可识别的结果" : "洛谷返回 HTTP " + code + "，但没有可读的错误信息"
}

// --- 私信 (chat) -------------------------------------------------------------
// /chat?user=<uid>&_contentOnly=1 returns the same envelope as /chat, with
// data.latestChats holding one entry per conversation. Both that payload and the
// {notice, chat} wrapper built by activityProc are accepted.
function chatPayload(raw) {
  var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
  if (root.chat) root = root.chat
  if (root.data) root = root.data
  return root || {}
}

function parseChatSessions(raw) {
  try {
    var payload = chatPayload(raw)
    var chats = payload.latestChats
    if (!Array.isArray(chats)) return []
    return chats.map(function(item) {
      var target = item.target || {}
      return {
        uid: numberOr(target.uid, numberOr(item.uid, 0)),
        name: textOr(target.name, "洛谷用户"),
        ccfLevel: numberOr(target.ccfLevel, 0),
        color: textOr(target.color, ""),
        content: textOr(item.content, ""),
        time: numberOr(item.time, 0)
      }
    }).filter(function(item) { return item.uid > 0 })
      .sort(function(a, b) { return b.time - a.time })
  } catch (error) {
    return []
  }
}

// GET /api/chat/record?user=<uid> -> {messages: {count, perPage, result: [...]}}
// Each entry is {id, sender, receiver, time, status, content} and the list comes
// back oldest first. `mine` is what the bubble alignment keys off, so it has to
// be decided here rather than by comparing names in QML.
function parseChatRecord(raw, myUid) {
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var box = root.messages !== undefined ? root.messages : root
    var list = Array.isArray(box) ? box : (box.result || box.messages || [])
    if (!Array.isArray(list)) return []
    var me = numberOr(myUid, -1)
    return list.map(function(item) {
      var sender = item.sender || {}
      return {
        id: numberOr(item.id, 0),
        uid: numberOr(sender.uid, 0),
        name: textOr(sender.name, ""),
        color: textOr(sender.color, ""),
        mine: numberOr(sender.uid, -1) === me,
        time: numberOr(item.time, 0),
        content: textOr(item.content, "")
      }
    }).filter(function(item) { return item.id > 0 })
      .sort(function(a, b) { return a.time - b.time || a.id - b.id })
  } catch (error) {
    return []
  }
}

// GET /api/user/search?keyword=<name-or-uid> -> {users: [...]}. A numeric keyword
// matches that exact uid, so one box covers both "search a name" and "type a uid".
function parseUserSearch(raw) {
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var users = root.users || (root.data && root.data.users) || []
    if (!Array.isArray(users)) return []
    return users.map(function(item) {
      return {
        uid: numberOr(item.uid, 0),
        name: textOr(item.name, "洛谷用户"),
        ccfLevel: numberOr(item.ccfLevel, 0),
        color: textOr(item.color, "")
      }
    }).filter(function(item) { return item.uid > 0 })
  } catch (error) {
    return []
  }
}

// Conversation list wants "14:32" for today and "9月22日" for this year; bubbles
// want a full timestamp. Seconds, not milliseconds.
function formatChatTime(timestamp) {
  var seconds = numberOr(timestamp, 0)
  if (seconds <= 0) return ""
  var date = new Date(seconds * 1000)
  if (isNaN(date.getTime())) return ""
  var now = new Date()
  function pad(value) { return value < 10 ? "0" + value : String(value) }
  var sameYear = date.getFullYear() === now.getFullYear()
  var sameDay = sameYear && date.getMonth() === now.getMonth() && date.getDate() === now.getDate()
  if (sameDay) return pad(date.getHours()) + ":" + pad(date.getMinutes())
  if (sameYear) return (date.getMonth() + 1) + "月" + date.getDate() + "日"
  return date.getFullYear() + "/" + (date.getMonth() + 1) + "/" + date.getDate()
}

function formatChatStamp(timestamp) {
  var seconds = numberOr(timestamp, 0)
  if (seconds <= 0) return ""
  var date = new Date(seconds * 1000)
  if (isNaN(date.getTime())) return ""
  var now = new Date()
  // A year-old conversation still has messages worth dating, and "10月3日" alone
  // reads as the current year.
  var year = date.getFullYear() === now.getFullYear() ? "" : date.getFullYear() + "年"
  function pad(value) { return value < 10 ? "0" + value : String(value) }
  return year + (date.getMonth() + 1) + "月" + date.getDate() + "日 " + pad(date.getHours()) + ":" + pad(date.getMinutes())
}

// --- Markdown ---------------------------------------------------------------
// Luogu post/reply bodies are raw Markdown (verified: `### heading`,
// `[text](url)`, `$inline$`, ```cpp fences, `|---|` tables, `> quotes`). There is
// no LaTeX engine here, so math is shown as tinted monospace rather than
// typeset, and that is the one deliberate gap in the renderer.

function escapeHtml(text) {
  return String(text === undefined || text === null ? "" : text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

// Inline Markdown -> the slice of HTML Qt's rich text engine actually renders
// (<b> <i> <s> <font> <a> <br/>). Link colour comes from Text.linkColor, not
// from the markup. `colors` is {fg, accent, muted} as "#rrggbb" strings.
function inlineHtml(text, colors) {
  var palette = colors || {}
  var accent = palette.accent || palette.fg || "#000000"
  var muted = palette.muted || palette.fg || "#000000"
  var vault = []

  function stash(html) {
    vault.push(html)
    return "\u0001" + (vault.length - 1) + "\u0001"
  }

  var out = escapeHtml(text)

  // Code spans and math are stashed first so their contents are never treated as
  // markup (a code span full of `**` must survive verbatim).
  out = out.replace(/`([^`\n]+)`/g, function(match, code) {
    return stash('<font face="monospace" color="' + muted + '">' + code + "</font>")
  })
  out = out.replace(/\$([^$\n]+)\$/g, function(match, math) {
    return stash(latexToHtml(math))
  })
  // Inline images cannot become an <img> inside a paragraph, so they degrade to a
  // labelled link; block-level images are handled by markdownBlocks instead.
  out = out.replace(/!\[([^\]]*)\]\(([^)\s]+)[^)]*\)/g, function(match, alt, url) {
    return stash('[图片: <a href="' + url + '">' + (alt === "" ? url : alt) + "</a>]")
  })
  out = out.replace(/\[([^\]]*)\]\(([^)\s]+)[^)]*\)/g, function(match, label, url) {
    return stash('<a href="' + url + '">' + (label === "" ? url : label) + "</a>")
  })
  out = out.replace(/&lt;(https?:\/\/[^&>\s]+)&gt;/g, function(match, url) {
    return stash('<a href="' + url + '">' + url + "</a>")
  })
  out = out.replace(/(^|\s)(https?:\/\/[^\s<]+)/g, function(match, lead, url) {
    return lead + stash('<a href="' + url + '">' + url + "</a>")
  })

  out = out.replace(/\*\*\*([^*]+)\*\*\*/g, "<b><i>$1</i></b>")
  out = out.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
  out = out.replace(/__([^_]+)__/g, "<b>$1</b>")
  out = out.replace(/\*([^*\n]+)\*/g, "<i>$1</i>")
  out = out.replace(/(^|[^\w_])_([^_\n]+)_(?![\w_])/g, "$1<i>$2</i>")
  out = out.replace(/~~([^~]+)~~/g, "<s>$1</s>")
  out = out.replace(/==([^=]+)==/g, "<b>$1</b>")
  out = out.replace(/\n/g, "<br/>")

  return out.replace(/\u0001(\d+)\u0001/g, function(match, i) { return vault[Number(i)] })
}

function splitTableRow(line) {
  var trimmed = String(line).trim().replace(/^\|/, "").replace(/\|$/, "")
  return trimmed.split("|").map(function(cell) { return cell.trim() })
}

// Block-level Markdown -> an array of plain objects the QML side renders one by
// one: {type: heading|paragraph|code|list|quote|table|image|math|hr, ...}.
function markdownBlocks(markdown) {
  var lines = String(markdown === undefined || markdown === null ? "" : markdown)
    .replace(/\r\n?/g, "\n")
    .split("\n")
  var blocks = []
  var index = 0

  function isBlank(line) { return String(line).trim() === "" }
  function fenceAt(line) { return String(line).match(/^\s*(`{3,}|~{3,})\s*([A-Za-z0-9#+.-]*)\s*$/) }

  // A line that starts a new block and therefore ends the paragraph above it.
  function startsBlock(line) {
    if (fenceAt(line)) return true
    if (/^\s*#{1,6}\s+/.test(line)) return true
    if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) return true
    if (/^\s*([-*+]|\d+[.)])\s+/.test(line)) return true
    if (/^\s*>/.test(line)) return true
    if (/^\s*\$\$/.test(line)) return true
    if (/^\s*\\\[/.test(line)) return true
    if (/^\s*\|.*\|/.test(line)) return true
    if (/^ {4}\S/.test(line)) return true
    return false
  }

  while (index < lines.length) {
    var line = lines[index]
    if (isBlank(line)) { index++; continue }

    var fence = fenceAt(line)
    if (fence) {
      var markerChar = fence[1].charAt(0)
      var markerLength = fence[1].length
      var body = []
      index++
      while (index < lines.length) {
        var closing = fenceAt(lines[index])
        if (closing && closing[1].charAt(0) === markerChar && closing[1].length >= markerLength) { index++; break }
        body.push(lines[index])
        index++
      }
      blocks.push({ type: "code", lang: fence[2] || "", text: body.join("\n") })
      continue
    }

    var heading = line.match(/^\s*(#{1,6})\s+(.*?)\s*#*\s*$/)
    if (heading) {
      blocks.push({ type: "heading", level: heading[1].length, text: heading[2] })
      index++
      continue
    }

    if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) { blocks.push({ type: "hr" }); index++; continue }

    // Display math: $$…$$ or \[…\]
    if (/^\s*(\$\$|\\\[)/.test(line)) {
      var mathBody = []
      var mathLine = line.replace(/^\s*(\$\$|\\\[)\s?/, "")
      var sameLine = mathLine.match(/^(.*?)(\$\$|\\\])\s*$/)
      if (sameLine) {
        blocks.push({ type: "math", text: sameLine[1].trim() })
        index++
        continue
      }
      mathBody.push(mathLine)
      index++
      while (index < lines.length) {
        var mathEnd = lines[index].match(/^(.*?)(\$\$|\\\])\s*$/)
        if (mathEnd) { mathBody.push(mathEnd[1]); index++; break }
        mathBody.push(lines[index])
        index++
      }
      blocks.push({ type: "math", text: mathBody.join("\n").trim() })
      continue
    }

    // Table: a |-row whose next line is the ---|--- separator.
    if (/^\s*\|/.test(line) && index + 1 < lines.length && /^[\s|:-]*-[\s|:-]*$/.test(lines[index + 1]) && lines[index + 1].indexOf("|") >= 0) {
      var header = splitTableRow(line)
      var aligns = splitTableRow(lines[index + 1]).map(function(cell) {
        var left = cell.charAt(0) === ":"
        var right = cell.charAt(cell.length - 1) === ":"
        return left && right ? "center" : right ? "right" : "left"
      })
      var rows = []
      index += 2
      while (index < lines.length && /^\s*\|/.test(lines[index])) {
        rows.push(splitTableRow(lines[index]))
        index++
      }
      blocks.push({ type: "table", header: header, aligns: aligns, rows: rows })
      continue
    }

    if (/^\s*>/.test(line)) {
      var quoted = []
      while (index < lines.length) {
        if (/^\s*>/.test(lines[index])) {
          quoted.push(lines[index].replace(/^\s*>\s?/, ""))
          index++
        } else if (isBlank(lines[index]) && index + 1 < lines.length && /^\s*>/.test(lines[index + 1])) {
          quoted.push("")
          index++
        } else break
      }
      blocks.push({ type: "quote", text: quoted.join("\n") })
      continue
    }

    if (/^\s*([-*+]|\d+[.)])\s+/.test(line)) {
      var items = []
      var baseIndent = -1
      while (index < lines.length) {
        var item = lines[index].match(/^(\s*)([-*+]|\d+[.)])\s+(.*)$/)
        if (!item) break
        var indent = item[1].length
        if (baseIndent < 0 || indent < baseIndent) baseIndent = indent
        var ordered = /^\d/.test(item[2])
        var itemText = item[3]
        index++
        // Continuation lines belong to the item while they stay indented and are
        // not themselves a new marker.
        while (index < lines.length && !isBlank(lines[index]) && !/^\s*([-*+]|\d+[.)])\s+/.test(lines[index]) && /^\s{2,}\S/.test(lines[index])) {
          itemText += "\n" + lines[index].trim()
          index++
        }
        items.push({
          indent: indent,
          depth: Math.max(0, Math.floor((indent - baseIndent) / 2)),
          ordered: ordered,
          number: ordered ? numberOr(item[2].replace(/[.)]$/, ""), 1) : 0,
          text: itemText
        })
      }
      if (items.length > 0) blocks.push({ type: "list", items: items })
      continue
    }

    // 4-space indented code (Luogu posts use it for snippets as well as fences).
    if (/^ {4}\S/.test(line) || /^ {4} /.test(line)) {
      var indented = []
      while (index < lines.length) {
        if (isBlank(lines[index])) {
          if (index + 1 < lines.length && /^ {4}/.test(lines[index + 1])) { indented.push(""); index++; continue }
          break
        }
        if (!/^ {4}/.test(lines[index])) break
        indented.push(lines[index].replace(/^ {4}/, ""))
        index++
      }
      blocks.push({ type: "code", lang: "", text: indented.join("\n") })
      continue
    }

    var paragraph = [line]
    index++
    while (index < lines.length && !isBlank(lines[index]) && !startsBlock(lines[index])) {
      paragraph.push(lines[index])
      index++
    }
    var joined = paragraph.join("\n").trim()
    // Bilibili embeds are HTML in the original Luogu statement. We do not feed
    // iframe markup to Qt rich text; turn it into a safe, clickable video block.
    var iframeVideo = joined.match(/<iframe[^>]+src=["']([^"']*(?:bilibili\.com|b23\.tv)[^"']*)["'][^>]*>/i)
    var bilibiliUrl = joined.match(/((?:https?:)?\/\/(?:www\.|player\.)?bilibili\.com\/[^\s<>"']+|https?:\/\/b23\.tv\/[^\s<>"']+)/i)
    var videoUrl = iframeVideo ? iframeVideo[1] : (bilibiliUrl ? bilibiliUrl[1] : "")
    if (videoUrl !== "") {
      if (videoUrl.indexOf("//") === 0) videoUrl = "https:" + videoUrl
      var bvid = videoUrl.match(/(?:bvid=|\/video\/)(BV[0-9A-Za-z]+)/i)
      blocks.push({ type: "video", url: videoUrl, bvid: bvid ? bvid[1] : "" })
      continue
    }

    // A line that is nothing but an image (Luogu posts put them on their own
    // line) becomes a real image block so QML can load and scale it, instead of
    // the degraded inline "[图片: …]" link.
    var imageOnly = joined.match(/^!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)$/) ||
                    joined.match(/^\[!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)\]\([^)]*\)$/)
    if (imageOnly) {
      blocks.push({ type: "image", alt: imageOnly[1] || "", url: imageOnly[2] })
      continue
    }
    blocks.push({ type: "paragraph", text: paragraph.join("\n") })
  }

  return blocks
}

// --- 讨论区帖子 --------------------------------------------------------------

function parseReplies(raw) {
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || root
    var box = data.replies !== undefined ? data.replies : data
    var list = Array.isArray(box) ? box : (box.result || [])
    if (!Array.isArray(list)) return []
    return list.map(function(item) {
      var author = item.author || {}
      return {
        id: numberOr(item.id, 0),
        author: textOr(author.name, "未知用户"),
        authorUid: numberOr(author.uid, 0),
        authorCcfLevel: numberOr(author.ccfLevel, 0),
        authorColor: textOr(author.color, ""),
        time: numberOr(item.time, 0),
        content: textOr(item.content, "")
      }
    }).filter(function(item) { return item.id > 0 })
  } catch (error) {
    return []
  }
}

function parsePostDetail(raw) {
  var empty = {
    id: 0, title: "", author: "", authorUid: 0, time: 0, forum: "",
    replyCount: 0, content: "", replies: [], replyTotal: 0, repliesPerPage: 10,
    locked: false, cannotReply: false
  }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var post = data.post || {}
    if (numberOr(post.id, 0) <= 0) return empty
    var replyBox = data.replies || {}
    return {
      id: numberOr(post.id, 0),
      title: textOr(post.title, "无标题帖子"),
      author: textOr(post.author && post.author.name, "未知用户"),
      authorUid: numberOr(post.author && post.author.uid, 0),
      time: numberOr(post.time, 0),
      forum: textOr(post.forum && (post.forum.name || post.forum.slug), "讨论区"),
      replyCount: numberOr(post.replyCount, 0),
      content: textOr(post.content, ""),
      replies: parseReplies(root),
      replyTotal: numberOr(replyBox.count, 0),
      repliesPerPage: numberOr(replyBox.perPage, 10),
      locked: post.locked === true,
      cannotReply: data.cannotReply === true
    }
  } catch (error) {
    return empty
  }
}

// --- 题库 -------------------------------------------------------------------
// 洛谷前端自己的枚举表（从本机 vscode-luogu 打包产物里抽出来的官方表，不是猜的）：
// 难度、评测状态、语言都要用它们把数字翻译成人能看的字。

var PROBLEM_DIFFICULTIES = ["暂无评定", "入门", "普及-", "普及", "普及+/提高-", "提高", "提高+/省选-", "省选/NOI-", "NOI/NOI+/CTS"]
var PROBLEM_DIFFICULTY_COLORS = ["#BFBFBF", "#FE4C61", "#F39C11", "#FFC116", "#52C41A", "#13C2C2", "#3498DB", "#9D3DCF", "#0E1D69"]

var JUDGE_LANGUAGES = {
  1: "Pascal", 2: "C", 3: "C++98", 4: "C++11", 5: "提交答案", 6: "Python 2", 7: "Python 3",
  8: "Java 8", 9: "Node.js LTS", 10: "Shell", 11: "C++14", 12: "C++17", 13: "Ruby", 14: "Go",
  15: "Rust", 16: "PHP", 17: "C# Mono", 18: "Visual Basic Mono", 19: "Haskell", 20: "Kotlin/Native",
  21: "Kotlin/JVM", 22: "Scala", 23: "Perl", 24: "PyPy 2", 25: "PyPy 3", 26: "文言", 27: "C++20",
  28: "C++14 (GCC 9)", 29: "F#.NET", 30: "OCaml", 31: "Julia", 32: "Lua", 33: "Java 21", 34: "C++23"
}

var JUDGE_STATUS = {
  0: { name: "Waiting", short: "Waiting" },
  1: { name: "Judging", short: "Judging" },
  2: { name: "Compile Error", short: "CE" },
  3: { name: "Output Limit Exceeded", short: "OLE" },
  4: { name: "Memory Limit Exceeded", short: "MLE" },
  5: { name: "Time Limit Exceeded", short: "TLE" },
  6: { name: "Wrong Answer", short: "WA" },
  7: { name: "Runtime Error", short: "RE" },
  11: { name: "Unknown Error", short: "UKE" },
  12: { name: "Accepted", short: "AC" },
  14: { name: "Unaccepted", short: "Unaccepted" },
  21: { name: "Hack Success", short: "Hack Success" },
  22: { name: "Hack Failure", short: "Hack Failure" },
  23: { name: "Hack Skipped", short: "Hack Skipped" }
}

function difficultyName(level) {
  var index = numberOr(level, 0)
  return PROBLEM_DIFFICULTIES[index] === undefined ? "暂无评定" : PROBLEM_DIFFICULTIES[index]
}

function difficultyColor(level) {
  var index = numberOr(level, 0)
  return PROBLEM_DIFFICULTY_COLORS[index] === undefined ? PROBLEM_DIFFICULTY_COLORS[0] : PROBLEM_DIFFICULTY_COLORS[index]
}

function languageName(id) {
  var key = numberOr(id, 0)
  return JUDGE_LANGUAGES[key] === undefined ? ("语言 #" + key) : JUDGE_LANGUAGES[key]
}

function verdictName(status) {
  var entry = JUDGE_STATUS[numberOr(status, -1)]
  return entry === undefined ? ("状态 #" + numberOr(status, 0)) : entry.name
}

function verdictShort(status) {
  var entry = JUDGE_STATUS[numberOr(status, -1)]
  return entry === undefined ? "?" : entry.short
}

// 提交/通过数：题库里都是六位数，列表里占地方
function compactCount(value) {
  var number = numberOr(value, 0)
  if (number >= 10000) return (number / 10000).toFixed(1) + "w"
  if (number >= 1000) return (number / 1000).toFixed(1) + "k"
  return String(number)
}

// GET /_lfe/tags/zh-CN -> {tags:[{id,name,type,parent}]}，505 条，type 2 是算法标签。
// parent 为空的 type 2 只有 22 个，正好当筛选项。
function parseTagTable(raw) {
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var tags = root.tags
    if (!Array.isArray(tags)) return { byId: {}, groups: [], algorithms: [] }
    var byId = {}
    var groups = []
    tags.forEach(function(item) {
      var id = numberOr(item.id, 0)
      byId[id] = textOr(item.name, "")
      if (numberOr(item.type, 0) === 2 && (item.parent === null || item.parent === undefined)) {
        groups.push({ id: id, name: textOr(item.name, "") })
      }
    })
    groups.sort(function(a, b) { return a.id - b.id })
    return { byId: byId, groups: groups, algorithms: groups }
  } catch (error) {
    return { byId: {}, groups: [], algorithms: [] }
  }
}

function tagNames(ids, table) {
  if (!Array.isArray(ids)) return []
  var byId = table && table.byId ? table.byId : {}
  var names = []
  ids.forEach(function(id) {
    var name = byId[numberOr(id, 0)]
    if (name !== undefined && name !== "" && names.indexOf(name) < 0) names.push(name)
  })
  return names
}

function parseProblemList(raw) {
  var empty = { count: 0, perPage: 50, page: 1, problems: [] }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || root
    var box = data.problems || {}
    var list = Array.isArray(box) ? box : (box.result || [])
    if (!Array.isArray(list)) return empty
    return {
      count: numberOr(box.count, 0),
      perPage: numberOr(box.perPage, 50),
      page: numberOr(data.filter && data.filter.page, 1),
      problems: list.map(function(item) {
        return {
          pid: textOr(item.pid, ""),
          name: textOr(item.name, textOr(item.title, "未命名题目")),
          difficulty: numberOr(item.difficulty, 0),
          tags: Array.isArray(item.tags) ? item.tags : [],
          submitted: item.submitted === true,
          accepted: item.accepted === true,
          totalSubmit: numberOr(item.totalSubmit, 0),
          totalAccepted: numberOr(item.totalAccepted, 0)
        }
      }).filter(function(item) { return item.pid !== "" })
    }
  } catch (error) {
    return empty
  }
}

// GET /problem/<pid>?_contentOnly=1 —— 题面本身是 Markdown，samples 是
// [输入, 输出] 成对出现的数组（一组或多组）。
function parseProblemDetail(raw) {
  var empty = {
    pid: "", name: "", difficulty: 0, tags: [], submitted: false, accepted: false,
    totalSubmit: 0, totalAccepted: 0, background: "", description: "", formatI: "",
    formatO: "", hint: "", samples: [], timeLimit: 0, memoryLimit: 0,
    lastLanguage: 0, lastCode: "", discussions: [], limitCount: 1,
    acceptLanguages: []
  }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var problem = data.problem || {}
    if (textOr(problem.pid, "") === "") return empty
    var content = problem.content || {}
    var samples = []
    if (Array.isArray(problem.samples)) {
      problem.samples.forEach(function(pair) {
        if (Array.isArray(pair) && pair.length >= 2) samples.push({ input: textOr(pair[0], ""), output: textOr(pair[1], "") })
      })
    }
    var limits = problem.limits || {}
    var times = Array.isArray(limits.time) ? limits.time : []
    var memories = Array.isArray(limits.memory) ? limits.memory : []
    var discussions = []
    if (Array.isArray(data.discussions)) {
      data.discussions.forEach(function(item) {
        discussions.push({
          id: numberOr(item.id, 0),
          title: textOr(item.title, "无标题"),
          author: textOr(item.author && item.author.name, "未知用户"),
          time: numberOr(item.time, 0)
        })
      })
    }
    return {
      pid: textOr(problem.pid, ""),
      name: textOr(problem.name, textOr(content.name, "未命名题目")),
      difficulty: numberOr(problem.difficulty, 0),
      tags: Array.isArray(problem.tags) ? problem.tags : [],
      submitted: problem.submitted === true,
      accepted: problem.accepted === true,
      totalSubmit: numberOr(problem.totalSubmit, 0),
      totalAccepted: numberOr(problem.totalAccepted, 0),
      background: textOr(content.background, ""),
      description: textOr(content.description, ""),
      formatI: textOr(content.formatI, ""),
      formatO: textOr(content.formatO, ""),
      hint: textOr(content.hint, ""),
      samples: samples,
      timeLimit: numberOr(times[0], 0),
      memoryLimit: numberOr(memories[0], 0),
      limitCount: Math.max(1, times.length),
      acceptLanguages: Array.isArray(problem.acceptLanguages) ? problem.acceptLanguages : [],
      lastLanguage: numberOr(data.lastLanguage, 0),
      lastCode: textOr(data.lastCode, ""),
      discussions: discussions
    }
  } catch (error) {
    return empty
  }
}

// 把题面各段拼成一份 Markdown 交给 MarkdownView，样例用代码块包起来，
// 免得样例里的空格被折叠掉——样例的空格是题目的一部分。
function problemStatementMarkdown(detail) {
  if (!detail || detail.pid === "") return ""
  var parts = []
  function section(title, body) {
    if (String(body || "").trim() === "") return
    parts.push("## " + title + "\n\n" + String(body).trim())
  }
  if (String(detail.background || "").trim() !== "") parts.push(String(detail.background).trim())
  section("题目描述", detail.description)
  section("输入格式", detail.formatI)
  section("输出格式", detail.formatO)
  var samples = detail.samples || []
  for (var i = 0; i < samples.length; i++) {
    var label = samples.length > 1 ? ("## 样例 #" + (i + 1)) : "## 样例"
    parts.push(label + "\n\n**输入**\n\n```text\n" + samples[i].input.replace(/\s+$/, "") + "\n```\n\n**输出**\n\n```text\n" + samples[i].output.replace(/\s+$/, "") + "\n```")
  }
  section("提示", detail.hint)
  return parts.join("\n\n")
}

function parseSolutions(raw) {
  var empty = { count: 0, perPage: 10, solutions: [] }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var box = data.solutions || {}
    var list = Array.isArray(box) ? box : (box.result || [])
    if (!Array.isArray(list)) return empty
    return {
      count: numberOr(box.count, 0),
      perPage: numberOr(box.perPage, 10),
      solutions: list.map(function(item) {
        return {
          lid: textOr(item.lid, ""),
          title: textOr(item.title, "无标题题解"),
          author: textOr(item.author && item.author.name, "未知用户"),
          authorUid: numberOr(item.author && item.author.uid, 0),
          time: numberOr(item.time, 0),
          upvote: numberOr(item.upvote, 0),
          replyCount: numberOr(item.replyCount, 0),
          content: textOr(item.content, ""),
          contentFull: item.contentFull !== false
        }
      }).filter(function(item) { return item.lid !== "" })
    }
  } catch (error) {
    return empty
  }
}

// 题解本质是「文章」，/article/<lid> 才有全文（列表里长文会被截断）
function parseArticle(raw) {
  var empty = { lid: "", title: "", content: "", author: "", authorUid: 0, time: 0, upvote: 0, replyCount: 0, contentFull: true }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var article = (root.data || {}).article || {}
    if (textOr(article.lid, "") === "") return empty
    return {
      lid: textOr(article.lid, ""),
      title: textOr(article.title, "无标题题解"),
      content: textOr(article.content, ""),
      author: textOr(article.author && article.author.name, "未知用户"),
      authorUid: numberOr(article.author && article.author.uid, 0),
      time: numberOr(article.time, 0),
      upvote: numberOr(article.upvote, 0),
      replyCount: numberOr(article.replyCount, 0),
      contentFull: article.contentFull !== false
    }
  } catch (error) {
    return empty
  }
}

// 评测状态配色：洛谷自己的表在暗色下偏深（TLE 是 #001277），这里换成同色系
// 但能在深色背景上读的取值。
function verdictColor(status) {
  switch (numberOr(status, -1)) {
    case 12: return "#52C41A"   // Accepted
    case 6: return "#FB6340"    // Wrong Answer
    case 2: return "#FADB14"    // Compile Error
    case 5: case 4: case 3: return "#3498DB"  // TLE / MLE / OLE
    case 7: return "#9D3DCF"    // Runtime Error
    case 0: case 1: return "#3498DB"
    default: return "#BFBFBF"
  }
}

function isPendingVerdict(status) {
  var code = numberOr(status, -1)
  return code === 0 || code === 1
}

// GET /record/<rid>?_contentOnly=1 —— data.record 是概览，逐测试点在
// data.record.detail.judgeResult.subtasks[].testCases[] 里。
function parseRecord(raw) {
  var empty = {
    rid: 0, status: -1, score: 0, time: 0, memory: 0, language: 0, enableO2: false,
    pid: "", submitTime: 0, sourceCode: "", compileSuccess: false, compileMessage: "",
    subtasks: [], testcaseCount: 0, finishedCaseCount: 0
  }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var record = data.record || {}
    if (numberOr(record.id, 0) <= 0) return empty
    var detail = record.detail || {}
    var compile = detail.compileResult || {}
    var judge = detail.judgeResult || {}
    var subtasks = []
    if (Array.isArray(judge.subtasks)) {
      judge.subtasks.forEach(function(subtask) {
        var cases = []
        if (Array.isArray(subtask.testCases)) {
          subtask.testCases.forEach(function(item) {
            cases.push({
              id: numberOr(item.id, 0),
              status: numberOr(item.status, -1),
              time: numberOr(item.time, 0),
              memory: numberOr(item.memory, 0),
              score: numberOr(item.score, 0),
              description: textOr(item.description, "")
            })
          })
        }
        subtasks.push({
          id: numberOr(subtask.id, 0),
          status: numberOr(subtask.status, -1),
          score: numberOr(subtask.score, 0),
          time: numberOr(subtask.time, 0),
          memory: numberOr(subtask.memory, 0),
          testCases: cases
        })
      })
    }
    var testcaseCount = 0
    subtasks.forEach(function(subtask) { testcaseCount += subtask.testCases.length })
    return {
      rid: numberOr(record.id, 0),
      status: numberOr(record.status, -1),
      score: numberOr(record.score, 0),
      time: numberOr(record.time, 0),
      memory: numberOr(record.memory, 0),
      language: numberOr(record.language, 0),
      enableO2: record.enableO2 === true,
      pid: textOr(record.problem && record.problem.pid, ""),
      submitTime: numberOr(record.submitTime, 0),
      sourceCode: textOr(record.sourceCode, ""),
      compileSuccess: compile.success === true,
      compileMessage: textOr(compile.message, ""),
      finishedCaseCount: numberOr(judge.finishedCaseCount, 0),
      subtasks: subtasks,
      testcaseCount: testcaseCount
    }
  } catch (error) {
    return empty
  }
}

// POST /fe/api/problem/submit/<pid> 成功时的响应体没有公开文档，所以这里
// 把所有可能有 rid 的位置都找一遍，找不到就退回原始文本给用户看。
function parseSubmitResult(raw) {
  var text = String(raw === undefined || raw === null ? "" : raw)
  try {
    var payload = JSON.parse(text)
    var candidates = [payload.rid, payload.recordId, payload.id,
                      payload.data && (payload.data.rid || payload.data.recordId || payload.data.id),
                      payload.record && payload.record.id]
    for (var i = 0; i < candidates.length; i++) {
      var rid = numberOr(candidates[i], 0)
      if (rid > 0) return { rid: rid, message: textOr(payload.message, "") }
    }
  } catch (error) {}
  return { rid: 0, message: text.slice(0, 160) }
}

// 自己编码 base64，而不是用 Qt.btoa：Qt.btoa(string) 在 6.x 已标记弃用且与 Web
// 行为不同，而提交的代码里几乎一定有中文注释——这里明确按 UTF-8 处理，结果可预测。
function utf8Base64(text) {
  var input = String(text === undefined || text === null ? "" : text)
  var bytes = []
  for (var i = 0; i < input.length; i++) {
    var code = input.charCodeAt(i)
    if (code < 0x80) {
      bytes.push(code)
    } else if (code < 0x800) {
      bytes.push(0xC0 | (code >> 6), 0x80 | (code & 63))
    } else if (code >= 0xD800 && code <= 0xDBFF && i + 1 < input.length) {
      var low = input.charCodeAt(i + 1)
      var point = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
      bytes.push(0xF0 | (point >> 18), 0x80 | ((point >> 12) & 63), 0x80 | ((point >> 6) & 63), 0x80 | (point & 63))
      i++
    } else {
      bytes.push(0xE0 | (code >> 12), 0x80 | ((code >> 6) & 63), 0x80 | (code & 63))
    }
  }
  var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  var result = ""
  for (var j = 0; j < bytes.length; j += 3) {
    var first = bytes[j]
    var second = j + 1 < bytes.length ? bytes[j + 1] : undefined
    var third = j + 2 < bytes.length ? bytes[j + 2] : undefined
    result += alphabet.charAt(first >> 2)
    result += alphabet.charAt(((first & 3) << 4) | (second === undefined ? 0 : second >> 4))
    result += second === undefined ? "=" : alphabet.charAt(((second & 15) << 2) | (third === undefined ? 0 : third >> 6))
    result += third === undefined ? "=" : alphabet.charAt(third & 63)
  }
  return result
}

// --- LaTeX 子集 -------------------------------------------------------------
// 题面里的公式是 LaTeX，而 Quickshell 没有 WebEngine（塞不进 KaTeX），所以这里把
// 常见写法翻成 Unicode + 富文本的 <sup>/<sub>。覆盖范围是按真实题面统计定的：
// 283 个片段里 \le 58、\times 18、上标 28、下标 48——比较符和上下标是主力。
// 翻不了的（矩阵、分段函数、\begin{cases}）会退化成可读文本，不会丢内容。

var LATEX_SYMBOLS = {
  alpha: "α", beta: "β", gamma: "γ", Gamma: "Γ", delta: "δ", Delta: "Δ",
  epsilon: "ε", varepsilon: "ε", zeta: "ζ", eta: "η", theta: "θ", Theta: "Θ",
  iota: "ι", kappa: "κ", lambda: "λ", Lambda: "Λ", mu: "μ", nu: "ν", xi: "ξ", Xi: "Ξ",
  pi: "π", Pi: "Π", rho: "ρ", sigma: "σ", Sigma: "Σ", tau: "τ", upsilon: "υ",
  phi: "φ", varphi: "φ", Phi: "Φ", chi: "χ", psi: "ψ", Psi: "Ψ", omega: "ω", Omega: "Ω",
  le: "≤", leq: "≤", ge: "≥", geq: "≥", ne: "≠", neq: "≠", equiv: "≡", approx: "≈",
  sim: "∼", simeq: "≃", cong: "≅", propto: "∝", ll: "≪", gg: "≫",
  in: "∈", notin: "∉", ni: "∋", subset: "⊂", subseteq: "⊆", supset: "⊃", supseteq: "⊇",
  cup: "∪", cap: "∩", setminus: "∖", emptyset: "∅", varnothing: "∅",
  forall: "∀", exists: "∃", nexists: "∄", neg: "¬", lnot: "¬", land: "∧", lor: "∨",
  to: "→", rightarrow: "→", leftarrow: "←", leftrightarrow: "↔",
  Rightarrow: "⇒", Leftarrow: "⇐", Leftrightarrow: "⇔", mapsto: "↦",
  uparrow: "↑", downarrow: "↓", updownarrow: "↕",
  times: "×", div: "÷", cdot: "·", pm: "±", mp: "∓", ast: "∗", star: "⋆",
  circ: "∘", bullet: "•", oplus: "⊕", ominus: "⊖", otimes: "⊗", oslash: "⊘",
  perp: "⊥", parallel: "∥", angle: "∠", triangle: "△", square: "□", because: "∵", therefore: "∴",
  sum: "∑", prod: "∏", coprod: "∐", int: "∫", iint: "∬", oint: "∮",
  infty: "∞", partial: "∂", nabla: "∇", surd: "√",
  cdots: "⋯", ldots: "…", dots: "…", vdots: "⋮", ddots: "⋱",
  prime: "′", backslash: "\\", quad: "\u2003", qquad: "\u2003\u2003",
  lbrace: "{", rbrace: "}", langle: "⟨", rangle: "⟩", lfloor: "⌊", rfloor: "⌋",
  lceil: "⌈", rceil: "⌉", vert: "|", Vert: "‖", ell: "ℓ", hbar: "ℏ", Re: "ℜ", Im: "ℑ",
  checkmark: "✓", varnothing2: "∅", colon: ":", textbackslash: "\\"
}

// 正体排版的函数名（LaTeX 里本来就是直立的）
var LATEX_FUNCTIONS = ["sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan",
  "sinh", "cosh", "tanh", "coth", "log", "ln", "lg", "exp", "gcd", "lcm", "max", "min",
  "sup", "inf", "lim", "det", "dim", "ker", "deg", "arg", "hom", "mod", "bmod", "pmod"]

// 只影响排版的命令：直接丢掉
var LATEX_DROP = ["left", "right", "big", "Big", "bigg", "Bigg", "bigl", "bigr", "Bigl", "Bigr",
  "biggl", "biggr", "Biggl", "Biggr", "limits", "nolimits", "displaystyle", "textstyle",
  "scriptstyle", "mathrm", "mathnormal", "mathit", "mathsf", "mathtt", "mbox", "hbox", "text",
  "operatorname", "bm", "boldsymbol", "mathbf", "bf", "it", "rm", "tt", "sf", "cal", "Bbb", "frak"]

// 关系符/运算符：TeX 会在两侧自动加数学间距（`1\le n` 排出来是「1 ≤ n」），
// 所以这里主动补空格；希腊字母、⋯、∞ 这类字母性符号紧排。
var LATEX_SPACED = ["le", "leq", "ge", "geq", "ne", "neq", "equiv", "approx", "sim", "simeq",
  "cong", "propto", "ll", "gg", "in", "notin", "ni", "subset", "subseteq", "supset", "supseteq",
  "cup", "cap", "setminus", "times", "div", "cdot", "pm", "mp", "ast", "star", "circ", "bullet",
  "oplus", "ominus", "otimes", "perp", "parallel", "to", "rightarrow", "leftarrow", "leftrightarrow",
  "Rightarrow", "Leftarrow", "Leftrightarrow", "mapsto", "land", "lor", "forall", "exists"]

var LATEX_SPACING = [" ", ",", ";", ":", "!", "thinspace", "medspace", "thickspace", "enspace", "negthinspace"]

function latexReadGroup(input, start) {
  if (input.charAt(start) !== "{") return null
  var depth = 0
  for (var i = start; i < input.length; i++) {
    var c = input.charAt(i)
    if (c === "\\") { i++; continue }
    if (c === "{") depth++
    else if (c === "}") {
      depth--
      if (depth === 0) return { content: input.slice(start + 1, i), next: i + 1 }
    }
  }
  return { content: input.slice(start + 1), next: input.length }
}

// 一个「原子」：{...} 分组，或单个字符
function latexReadAtom(input, start) {
  if (input.charAt(start) === "{") {
    var group = latexReadGroup(input, start)
    return { content: group.content, next: group.next }
  }
  return { content: input.charAt(start), next: start + 1 }
}

function latexIsComplex(text) {
  return /[+\-−=<>±×÷/()\s]/.test(text) && text.length > 1
}

function latexToHtml(tex) {
  var input = String(tex === undefined || tex === null ? "" : tex)
  var html = ""
  var i = 0

  while (i < input.length) {
    var c = input.charAt(i)

    if (c === "\\") {
      var match = /^\\([a-zA-Z]+|.)/.exec(input.slice(i))
      if (!match) { i++; continue }
      var name = match[1]
      var after = i + match[0].length

      if (name === "\\") { html += "<br/>"; i = after; continue }
      if (LATEX_SPACING.indexOf(name) >= 0) { html += " "; i = after; continue }
      if (name === "frac" || name === "dfrac" || name === "tfrac" || name === "cfrac") {
        var numerator = latexReadAtom(input, after)
        var denominator = latexReadAtom(input, numerator.next)
        var top = latexToHtml(numerator.content)
        var bottom = latexToHtml(denominator.content)
        if (latexIsComplex(numerator.content)) top = "(" + top + ")"
        if (latexIsComplex(denominator.content)) bottom = "(" + bottom + ")"
        html += top + "<font color=\"#888888\">/</font>" + bottom
        i = denominator.next
        continue
      }
      if (name === "sqrt") {
        var index = ""
        if (input.charAt(after) === "[") {
          var close = input.indexOf("]", after)
          if (close > 0) { index = input.slice(after + 1, close); after = close + 1 }
        }
        var radicand = latexReadAtom(input, after)
        var body = latexToHtml(radicand.content)
        html += (index === "" ? "√(" : "<sup>" + latexToHtml(index) + "</sup>√(") + body + ")"
        i = radicand.next
        continue
      }
      if (name === "pmod") {
        var modArg = latexReadAtom(input, after)
        html += " (mod " + latexToHtml(modArg.content) + ")"
        i = modArg.next
        continue
      }
      if (name === "overline" || name === "bar" || name === "hat" || name === "vec" || name === "tilde" || name === "underline" || name === "dot") {
        var marked = latexReadAtom(input, after)
        var marks = { overline: "\u0305", bar: "\u0304", hat: "\u0302", vec: "\u20d7", tilde: "\u0303", underline: "\u0332", dot: "\u0307" }
        html += latexToHtml(marked.content) + marks[name]
        i = marked.next
        continue
      }
      if (name === "begin" || name === "end") {
        // 环境（矩阵/分段函数等）：只去掉标记，内容按普通文本排，& 当列分隔
        var envArg = latexReadAtom(input, after)
        i = envArg.next
        continue
      }
      if (name === "bmod") { html += " mod "; i = after; continue }
      if (LATEX_SYMBOLS[name] !== undefined) {
        // LaTeX 会把控制符后面的一个空格吃掉（`1\le n` 排出来是「1≤n」），
        // 函数名不同（`\log n` 要有空格），所以只在符号这里吞。
        html += LATEX_SPACED.indexOf(name) >= 0 ? (" " + LATEX_SYMBOLS[name] + " ") : LATEX_SYMBOLS[name]
        i = after
        if (input.charAt(i) === " ") i++
        continue
      }
      if (LATEX_FUNCTIONS.indexOf(name) >= 0) { html += name; i = after; continue }
      if (LATEX_DROP.indexOf(name) >= 0) { i = after; continue }
      if (name === "%" || name === "&" || name === "_" || name === "#" || name === "$" || name === "{" || name === "}") {
        html += escapeHtml(name); i = after; continue
      }
      // 认不出来的命令：去掉反斜杠保留名字，至少不丢内容（诊断时能一眼看出）
      html += escapeHtml(name)
      i = after
      continue
    }

    if (c === "^" || c === "_") {
      var script = latexReadAtom(input, i + 1)
      var tag = c === "^" ? "sup" : "sub"
      html += "<" + tag + ">" + latexToHtml(script.content) + "</" + tag + ">"
      i = script.next
      continue
    }

    if (c === "{") {
      var group = latexReadGroup(input, i)
      html += latexToHtml(group.content)
      i = group.next
      continue
    }

    if (c === "}") { i++; continue }
    if (c === "&") { html += "  "; i++; continue }

    html += escapeHtml(c)
    i++
  }

  // LaTeX 的 \left( 之类会在括号内侧留下空格，读起来像两个式子
  return html.replace(/\(\s+/g, "(").replace(/\[\s+/g, "[").replace(/\s+\)/g, ")").replace(/\s+\]/g, "]").replace(/ {2,}/g, " ").trim()
}

// 比赛列表：contestProc 现在返回 {count, perPage, page, contests:[…]}，
// 兼容早期直接返回数组的形态。
function parseContestPage(raw) {
  var empty = { count: 0, perPage: 20, page: 1, contests: [] }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    if (Array.isArray(root)) return { count: 0, perPage: 20, page: 1, contests: parseContests(root) }
    return {
      count: numberOr(root.count, 0),
      perPage: numberOr(root.perPage, 20),
      page: numberOr(root.page, 1),
      contests: parseContests(root.contests || root)
    }
  } catch (error) {
    return empty
  }
}

// 犇犇分页时把新一页并进来：HTML 片段里有 data-feed-id，JSON 版没有，
// 所以按「uid|时间|正文」去重，避免翻页时重复显示。
function mergeFeedItems(existing, incoming) {
  var result = []
  var seen = {}
  var all = (Array.isArray(existing) ? existing : []).concat(Array.isArray(incoming) ? incoming : [])
  for (var i = 0; i < all.length; i++) {
    var item = all[i]
    var key = numberOr(item.id, 0) > 0
      ? ("id:" + item.id)
      : (numberOr(item.uid, 0) + "|" + textOr(item.time, "") + "|" + textOr(item.content, "").slice(0, 60))
    if (seen[key] === true) continue
    seen[key] = true
    result.push(item)
  }
  return result
}

// 设置里存的是语言名（enum 只能给字符串），提交要的是数字 id。
function languageIdByName(name) {
  var wanted = String(name === undefined || name === null ? "" : name).trim()
  if (wanted === "") return 0
  var numeric = Number(wanted)
  if (isFinite(numeric) && JUDGE_LANGUAGES[numeric] !== undefined) return numeric
  for (var id in JUDGE_LANGUAGES) {
    if (JUDGE_LANGUAGES[id] === wanted) return Number(id)
  }
  return 0
}

// --- 洛谷账号设置（只读）-------------------------------------------------------
// 三个接口各返回一块：奖项认证 / 账号安全 / 第三方绑定。注意「改」的接口在这台
// 机器上探不到（设置页 HTML 对非浏览器客户端是 302 自我循环，拿不到前端 JS），
// 所以这里只做展示。

// GET /user/setting/prize?_contentOnly=1
function parsePrizeSettings(raw) {
  var empty = { hasRealName: false, oiLevel: 0, xcpcLevel: 0, oiShow: false, xcpcShow: false, realName: "", affiliation: "", prizes: [] }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var levels = data.prizeLevel || {}
    var oi = levels.oi || {}
    var xcpc = levels.xcpc || {}
    var prizes = []
    if (Array.isArray(data.prizes)) {
      data.prizes.forEach(function(item) {
        var prize = item.prize || item
        prizes.push({
          year: numberOr(prize.year, 0),
          contest: textOr(prize.contest, ""),
          event: textOr(prize.event, ""),
          prize: textOr(prize.prize, ""),
          score: numberOr(prize.score, 0),
          rank: numberOr(prize.rank, 0),
          name: textOr(prize.name, ""),
          affiliation: textOr(prize.affiliation, ""),
          type: textOr(prize.type, "")
        })
      })
    }
    var first = prizes.length > 0 ? prizes[0] : {}
    return {
      hasRealName: data.hasRealName === true,
      oiLevel: numberOr(oi.level, 0),
      xcpcLevel: numberOr(xcpc.level, 0),
      oiShow: oi.show !== false,
      xcpcShow: xcpc.show !== false,
      realName: first.name || "",
      affiliation: first.affiliation || "",
      prizes: prizes
    }
  } catch (error) {
    return empty
  }
}

// GET /user/setting/security?_contentOnly=1 —— 手机/实名是打码后的字符串
function parseAccountSecurity(raw) {
  var empty = { email: "", phone: "", realName: "", totpSet: false, usernameUpdateTime: 0, adminLogCount: 0 }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    return {
      email: textOr(data.email, ""),
      phone: textOr(data.phone, ""),
      realName: textOr(data.realName, ""),
      totpSet: data.totpSet === true,
      usernameUpdateTime: numberOr(data.usernameUpdateTime, 0),
      adminLogCount: Array.isArray(data.adminLogs) ? data.adminLogs.length : 0
    }
  } catch (error) {
    return empty
  }
}

// GET /user/setting?_contentOnly=1 —— 第三方账号绑定
function parseAccountBindings(raw) {
  var empty = { vjudge: [], openid: [] }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var vjudge = []
    var openid = []
    if (Array.isArray(data.vjudgeAccounts)) {
      data.vjudgeAccounts.forEach(function(item) {
        vjudge.push({ username: textOr(item.username, ""), oj: textOr(item.oj, "") })
      })
    }
    if (Array.isArray(data.openidAccounts)) {
      data.openidAccounts.forEach(function(item) {
        openid.push({ username: textOr(item.username, ""), platform: numberOr(item.platform, 0) })
      })
    }
    return { vjudge: vjudge, openid: openid }
  } catch (error) {
    return empty
  }
}

// --- 云剪贴板（paste）---------------------------------------------------------
// GET /paste?_contentOnly=1&page=N —— 内容字段名就叫 data（不是 content）。
function parsePasteList(raw) {
  var empty = { count: 0, perPage: 10, items: [] }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var pastes = data.pastes || {}
    var items = []
    if (Array.isArray(pastes.result)) {
      pastes.result.forEach(function(item) {
        items.push({
          id: textOr(item.id, ""),
          time: numberOr(item.time, 0),
          updateAt: numberOr(item.updateAt, 0),
          isPublic: item.public === true,
          data: textOr(item.data, ""),
          author: textOr(item.user && item.user.name, "")
        })
      })
    }
    return { count: numberOr(pastes.count, 0), perPage: numberOr(pastes.perPage, 10), items: items }
  } catch (error) {
    return empty
  }
}

// GET /paste/<id>?_contentOnly=1
function parsePaste(raw) {
  var empty = { id: "", data: "", time: 0, updateAt: 0, isPublic: false, canEdit: false, author: "" }
  try {
    var root = typeof raw === "string" ? JSON.parse(raw) : (raw || {})
    var data = root.data || {}
    var paste = data.paste || {}
    return {
      id: textOr(paste.id, ""),
      data: textOr(paste.data, ""),
      time: numberOr(paste.time, 0),
      updateAt: numberOr(paste.updateAt, 0),
      isPublic: paste.public === true,
      canEdit: data.canEdit === true,
      author: textOr(paste.user && paste.user.name, "")
    }
  } catch (error) {
    return empty
  }
}

// --- 代码高亮（编辑器用）-----------------------------------------------------
// 自己写的词法扫描：不做完整解析，只够把注释/字符串/数字/关键字/类型/函数名
// 区分出来。返回带 <span> 的 HTML，交给 Text 的 RichText 渲染。换行必须显式
// 变成 <br/>（RichText 引擎按 HTML 规则折叠空白），而且**不能换行折行**，否则
// 高亮层会和可编辑层错位 —— 编辑器那边用 NoWrap + 横向滚动来保证逐行对齐。
var CODE_KEYWORDS = ["alignas","alignof","asm","auto","break","case","catch","class","const","constexpr","continue","decltype","default","delete","do","dynamic_cast","else","enum","explicit","export","extern","false","for","friend","goto","if","inline","mutable","namespace","new","noexcept","nullptr","operator","private","protected","public","register","reinterpret_cast","return","sizeof","static","static_assert","static_cast","struct","switch","template","this","throw","true","try","typedef","typeid","typename","union","using","virtual","volatile","while","and","or","not","xor"]
var CODE_TYPES = ["bool","char","char16_t","char32_t","double","float","int","long","short","signed","unsigned","void","wchar_t","size_t","string","vector","map","set","pair","queue","stack","deque","priority_queue","unordered_map","unordered_set","array","tuple","bitset","complex","function","optional","variant","string_view","int64_t","uint64_t","int32_t","uint32_t","__int128","ll","ull","int","double","long"]
var CODE_PY_KEYWORDS = ["and","as","assert","async","await","break","class","continue","def","del","elif","else","except","False","finally","for","from","global","if","import","in","is","lambda","None","nonlocal","not","or","pass","raise","return","True","try","while","with","yield","match","case","self"]
var CODE_PY_BUILTINS = ["abs","all","any","bin","bool","bytes","chr","dict","divmod","enumerate","eval","filter","float","format","frozenset","getattr","hasattr","hash","hex","id","input","int","isinstance","iter","len","list","map","max","min","next","object","oct","open","ord","pow","print","range","repr","reversed","round","set","setattr","slice","sorted","str","sum","super","tuple","type","zip"]

// VSCode 的暗/亮两套配色，够用即可
function codePalette(dark) {
  return dark
    ? { comment: "#6A9955", string: "#CE9178", number: "#B5CEA8", keyword: "#569CD6", pyKeyword: "#C586C0", type: "#4EC9B0", func: "#DCDCAA", pre: "#C586C0", plain: null }
    : { comment: "#008000", string: "#A31515", number: "#098658", keyword: "#0000FF", pyKeyword: "#AF00DB", type: "#267F99", func: "#795E26", pre: "#AF00DB", plain: null }
}

function escapeHtml(text) {
  return String(text === null || text === undefined ? "" : text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
}

function highlightCode(code, language, dark) {
  var source = String(code === null || code === undefined ? "" : code)
  if (source === "") return ""
  var palette = codePalette(dark !== false)
  var python = /python|pypy/i.test(String(language || ""))
  var keywords = python ? CODE_PY_KEYWORDS : CODE_KEYWORDS
  var types = python ? CODE_PY_BUILTINS : CODE_TYPES
  var out = []
  var i = 0
  var lineStart = true
  while (i < source.length) {
    var rest = source.slice(i)
    var match
    // 注释
    if (python ? rest.charAt(0) === "#" : (match = /^\/\/[^\n]*/.exec(rest)) || (match = /^\/\*[\s\S]*?\*\//.exec(rest)) || (python && false)) {
      var commentText
      if (python && rest.charAt(0) === "#") {
        match = /^#[^\n]*/.exec(rest)
      }
      commentText = match ? match[0] : ""
      if (commentText === "") { out.push(escapeHtml(rest.charAt(0))); i += 1; lineStart = rest.charAt(0) === "\n"; continue }
      out.push(span(palette.comment, commentText))
      i += commentText.length
      lineStart = commentText.charAt(commentText.length - 1) === "\n"
      continue
    }
    // 字符/字符串
    match = /^(?:u8|u|U|L)?(?:R"\([\s\S]*?\)"|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')/.exec(rest)
    if (match) { out.push(span(palette.string, match[0])); i += match[0].length; lineStart = false; continue }
    // 预处理指令（整行）
    if (!python && rest.charAt(0) === "#") {
      match = /^#[^\n]*/.exec(rest)
      out.push(span(palette.pre, match[0]))
      i += match[0].length
      lineStart = false
      continue
    }
    // 数字
    match = /^\d[\w.]*(?:[eE][+-]?\d+)?/.exec(rest)
    if (match) { out.push(span(palette.number, match[0])); i += match[0].length; lineStart = false; continue }
    // 标识符
    match = /^[A-Za-z_]\w*/.exec(rest)
    if (match) {
      var word = match[0]
      var after = source.slice(i + word.length)
      var isCall = /^\s*\(/.test(after)
      var color = palette.plain
      if (keywords.indexOf(word) >= 0) color = python ? palette.pyKeyword : palette.keyword
      else if (types.indexOf(word) >= 0) color = palette.type
      else if (isCall) color = palette.func
      out.push(color ? span(color, word) : escapeHtml(word))
      i += word.length
      lineStart = false
      continue
    }
    // 其它：逐字符，换行转 <br/>
    var ch = source.charAt(i)
    if (ch === "\n") { out.push("<br/>"); lineStart = true; i += 1; continue }
    out.push(escapeHtml(ch))
    i += 1
  }
  return out.join("")

  function span(color, text) {
    // 里面的换行同样要转 <br/>，并保持同样数量的行
    var escaped = escapeHtml(text).replace(/\n/g, "<br/>")
    return '<span style="color:' + color + ';">' + escaped + "</span>"
  }
}

// POST /paste/_new、/paste/_edit、/paste/_batop 成功时返回 {id: "..."}
function parsePasteWrite(body) {
  try {
    var payload = JSON.parse(String(body === undefined || body === null ? "" : body))
    var message = payload.errorMessage || payload.message
    if (!message && typeof payload.data === "string") message = payload.data
    return { id: textOr(payload.id, ""), message: textOr(message, "") }
  } catch (error) {
    return { id: "", message: "" }
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    difficultyName: difficultyName,
    difficultyColor: difficultyColor,
    languageName: languageName,
    languageIdByName: languageIdByName,
    verdictName: verdictName,
    verdictShort: verdictShort,
    compactCount: compactCount,
    parseTagTable: parseTagTable,
    tagNames: tagNames,
    parseProblemList: parseProblemList,
    parseProblemDetail: parseProblemDetail,
    problemStatementMarkdown: problemStatementMarkdown,
    parseSolutions: parseSolutions,
    parseArticle: parseArticle,
    utf8Base64: utf8Base64,
    latexToHtml: latexToHtml,
    highlightCode: highlightCode,
    escapeHtml: escapeHtml,
    parsePasteList: parsePasteList,
    parsePasteWrite: parsePasteWrite,
    parsePaste: parsePaste,
    parsePrizeSettings: parsePrizeSettings,
    parseAccountSecurity: parseAccountSecurity,
    parseAccountBindings: parseAccountBindings,
    parseRecord: parseRecord,
    parseSubmitResult: parseSubmitResult,
    verdictColor: verdictColor,
    isPendingVerdict: isPendingVerdict,
    markdownBlocks: markdownBlocks,
    inlineHtml: inlineHtml,
    escapeHtml: escapeHtml,
    parseReplies: parseReplies,
    parsePostDetail: parsePostDetail,
    parseChatSessions: parseChatSessions,
    parseChatRecord: parseChatRecord,
    parseUserSearch: parseUserSearch,
    formatChatTime: formatChatTime,
    formatChatStamp: formatChatStamp,
    splitHttpCode: splitHttpCode,
    writeResponseSucceeded: writeResponseSucceeded,
    writeResponseMessage: writeResponseMessage,
    writeFailureMessage: writeFailureMessage,
    parseProfile: parseProfile,
    parseDailyCounts: parseDailyCounts,
    parseActivity: parseActivity,
    parseFeed: parseFeed,
    feedInlineHtml: feedInlineHtml,
    parsePosts: parsePosts,
    parseForums: parseForums,
    parseForumPermissions: parseForumPermissions,
    parseContests: parseContests,
    parseContestDetail: parseContestDetail,
    parseContestPage: parseContestPage,
    userColor: userColor,
    mergeFeedItems: mergeFeedItems,
    contestStatus: contestStatus,
    contestStatusColor: contestStatusColor,
    formatContestTime: formatContestTime,
    contestSignupLabel: contestSignupLabel,
    compactNumber: compactNumber,
    rankingLabel: rankingLabel
  }
}
