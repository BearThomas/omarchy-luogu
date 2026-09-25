# Omarchy Luogu

Native Omarchy Shell bar widget for Luogu. The first development version uses
the same direct HTTP request pattern as `vscode-luogu`: `_uid` and
`__client_id` cookies, the Omarchy/VS Code-compatible request headers, and
CSRF-ready request handling.

## Development

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
```

Enable locally with:

```bash
omarchy plugin add "$(pwd)" --enable --yes
```

The widget stores the two login values in the desktop Secret Service through
`secret-tool`; they are not written to `shell.json` or this repository.

## Traps when touching the plugin

1. **Never add `X-Requested-With: XMLHttpRequest` to the homepage request that
   scrapes the CSRF token.** With that header Luogu answers `/` with a 37-byte
   stub, `<meta name="csrf-token" content=":)">`, so the widget would send `:)`
   as the token and every write would fail with `InvalidCSRFTokenException`
   (HTTP 400). The read endpoints under `?_contentOnly=1` do want that header;
   the homepage does not.
2. **Never add `curl -f` to a write request.** A rejected write comes back as an
   HTTP 4xx whose JSON body carries the real reason (`验证码错误`,
   `会话超时，请刷新页面后重试`). `-f` throws that body away, leaving an empty
   stdout, which is why failures used to surface as the useless
   "洛谷没有返回可解析的结果". The write commands therefore use `-sS` plus
   `-w '|%{http_code}'`, and parse the pair in `Model.js`.
3. **Never keep one `FloatingWindow` alive and toggle its `visible`.** Quickshell
   does not re-map a window the compositor has closed: setting `visible = true`
   afterwards succeeds silently and nothing appears. The details window has no
   decorations and no close button, so dismissing it with SUPER+Q *is* the normal
   path — a persistent instance therefore opened exactly once per shell session
   and then looked dead ("详细信息 点不开"). It is now declared inside a
   `Component` and created by a `Loader` with `active: detailOpen`, so every open
   is a fresh window and a compositor close just destroys the old one.

4. **`hl.dsp.window.float({ action = ... })`: use `"on"`, never `"set"`.** In this
   Lua dispatch API `"set"` is a **toggle**, and an unrecognised action (or none
   at all) also returns `ok` and toggles. So a repeating placement timer that
   sends `"set"` flips the window between floating and tiled on every tick and
   usually leaves it tiled. Omarchy's own binding uses the explicit
   `action = "toggle"`; `"on"`/`"enable"` are the idempotent force-float forms.

   The placement timer also cannot be a single shot. A new toplevel is not mapped
   yet at the first tick and Hyprland tiles it before it settles, measured as:
   tiled at ~300 ms → floating 980×740 by ~400 ms → **centered only from
   ~500 ms**. Two consequences:

   - `center` is resent on every tick, because it is computed from the width the
     compositor knows at that instant; calling it once early centres a 482-wide
     (tiled) window and parks it at x=518 instead of x=260.
   - `move` and `focus` stay single-shot: repeating `focus` would yank keyboard
     focus back for a second if the user clicks elsewhere right after opening.

   Quickshell 0.3.1 has no `Hyprland.clients`, so the compositor's own geometry
   cannot be polled from QML — hence convergence instead of a read-back. `float`,
   `move` and `resize` log nothing even when the selector matches nothing;
   `center`/`focus` do, which is why those wait for the second tick so a normal
   open leaves the journal warning-free.

5. **No QML edit is picked up by the shell's hot reload — restart the shell.**
   Omarchy does log `Local plugin changed, reloading: bearthomas.luogu`
   when a file under the plugin dir changes, but that notification does not
   re-read the QML: a probe in `Panel.qml`'s `Component.onCompleted` never ran
   after the reload notice, and a newly added `IpcHandler` function stayed
   `Function not found` until `omarchy-restart-shell`. The shell runs with
   `QS_DISABLE_FILE_WATCHER=1`, so the component cache keeps serving the old
   compilation. Deploy with a plain `cp` and restart — ~9 s, and it keeps
   `shell.json`.

6. **Feed rows must not hard-code their height.** A 犇犇 body is markdown and
   often long (a reply chain arrives as one string joined with `||`), so a fixed
   `height` makes the wrapped text spill out of its rounded box and paint over
   the entry below — which reads as doubled/garbled text ("有些犇犇容易重").
   Measured on real data: 8 of 19 entries needed more than the old 66 px, by up
   to 68 px. The delegate now derives its height from the content
   (`height: feedBody.implicitHeight + Style.space(20)`) with the inner `Column`
   anchored `left`/`right`/`top` only, plus `maximumLineCount: 6` with
   `elide: Text.ElideRight` so one long 犇犇 cannot swallow the page. The same
   trap applies to any list added later: either elide on a single line, or let
   the row size follow its content.

7. **A `Loader` whose height comes from `item.implicitHeight` must bind that
   height in `onLoaded`, not declaratively.** `height: item ? item.implicitHeight : 0`
   is evaluated while the item is still being built — before an inner `Repeater`
   has produced its delegates — so it reads 0, and the later real value looks like
   a re-entrant write. QML logs `Binding loop detected for property "height"` on
   the Loader. Measured on the block renderer: a `list` block reported
   `implicitHeight = 0` at `onLoaded` and the loop disappeared once the binding
   moved into `onLoaded: { item.block = …; height = Qt.binding(…) }`.

8. **A `Rectangle` (or bare `Item`) has `implicitHeight == 0`.** Anything the
   `Loader` measures by `implicitHeight` therefore collapses. Set
   `implicitHeight:` explicitly (and `height: implicitHeight`) for every
   non-`Text` block, or the block is laid out at zero height and paints over the
   block below it. A `Column`/`Row`, by contrast, sizes from its children's
   *actual* heights (verified: a `Rectangle { height: 40 }` alone in a Column
   gives `implicitHeight == 40`), so wrapping content in a positioner is enough.

9. **Do not read a parent's height inside a `Loader` item.** `anchors.verticalCenter:
   parent.verticalCenter` (or anything else deriving from `parent.height`) pulls in
   the Loader's height, which is itself derived from the item — a genuine height
   binding loop. Use a fixed offset computed from the component's own constants
   instead. Related: `childrenRect.height + N` bound to the height of an ancestor
   that this same height feeds is a loop too (reproduced in isolation), so size
   row backgrounds from an inner `Row`'s `childrenRect.height`, never from the
   enclosing `Item`'s own children.

10. **The details window's sidebar must stay outside the `Flickable`.** It used to
   sit inside it as the first child of a `Row`, so it scrolled away with the
   content — which is wrong for navigation. Now the `Row` holds the fixed
   sidebar plus a `Flickable` whose only child is the content `Column`.
   Verified by probe: with `contentY` moved from 0 to 1500 the sidebar's window
   position stayed at y=24.

11. **Qt's default wheel step is small for a 6000 px post, and this machine's
   touchpad is slower still.** `hyprctl getoption input:touchpad:scroll_factor`
   reports `0.4, set: true` (Omarchy's default in
   `/usr/share/omarchy/default/hypr/input.lua`), so two-finger scrolling arrives
   in the shell already at 40 % speed; `input:scroll_factor` (the mouse wheel) is
   1.0. The content `Flickable` therefore owns a `WheelHandler` that scrolls
   `Style.space(96)` per notch, or `pixelDelta * 2.5` for touchpad deltas (0.4 ×
   2.5 ≈ 1.0, i.e. back to a normal feel), and
   clamps `contentY` itself. Tune those two numbers (`wheelStep`,
   `wheelPixelFactor`) rather than fighting the global setting. Wheel events over
   the chat page's inner `ListView`s are consumed by them first, so only the page
   itself is affected.

12. **`qmllint` does not catch a stray `;` between QML object declarations —
   `qmlformat` does, and the QML runtime will not.** Writing
   `Text { … }; MouseArea { … }` (a JS habit) is a *parse* error for the QML
   engine but `qmllint` reports 0 errors on the same file, so `omarchy plugin
   validate` + `qmllint` both pass. The failure then looks completely silent:
   `BarWidget.qml` still loads (its `IpcHandler` answers), but
   `Loader { source: "Panel.qml" }` lands on `status === Loader.Error` with
   `item === null`, and since every BarWidget entry point is guarded with
   `if (panelLoader.item)`, **clicking the bar icon does nothing at all** and
   nothing is written to the journal.

   Two defences, both cheap:

   ```bash
   qmlformat BarWidget.qml > /dev/null   # exit code is the real syntax gate
   qmllint -I "$OMARCHY_PATH/shell" *.qml
   ```

   and when a widget "does nothing", read the Quickshell log rather than the
   journal — the parser error *is* recorded there, in the form
   `Panel.qml[2661:357]: Unexpected token ';'`:

   ```bash
   ls -l /proc/$(pgrep -f 'quickshell -n -p /usr/share/omarchy/shell')/fd | grep qslog
   ```

   A `Loader` status probe is the fastest way to confirm it: log `status` in
   `onStatusChanged` (0 Null, 1 Ready, 2 Loading, 3 Error).

### Contest problems open in their own window

A problem reached from the 洛谷比赛 window used to be opened by driving the
洛谷中心 window to its 题库 page (`openDetails(); openDetailPage("problems");
openProblem(pid)`). That hijacked the other window's navigation — its back button
then returned to the 题库 list rather than to the contest — and left two windows
fighting over one copy of the problem state. Now there is a third window,
**洛谷题目** (900×760), hosting `ProblemPanel.qml`.

`ProblemPanel.qml` is self-contained: it fetches its own statement, owns the
submit/verdict state and its own `Process`es, and is instantiated per window. It
takes `pid`, `uid`, `clientId`, `csrfToken`, a shared `tagTable` (it asks for one
through `requestTagTable()` if the 题库 page has not loaded it yet) and the usual
colour/font properties. The 题库 page inside 洛谷中心 still has its own copy of the
detail/submit UI — unifying the two onto `ProblemPanel` is the obvious next
cleanup.

### Every submission needs a captcha

Measured with a **valid** language and a deliberately too-short code (so nothing is
created): P1909, P1001 *and* the contest problem P17466 all answer
**`验证码错误` (403, `InvalidCaptchaException`)**. The earlier reading — "only
contest problems need one" — came from probing with an *invalid* language, which
is rejected earlier: the real order is **language → captcha → code length**. So a
submit UI without a captcha field can never succeed, and the JSON body carries
`{code, lang, enableO2, captcha}`.

Two things follow from that:

- **The captcha row is mandatory UI**, not a contest-only extra: `ProblemPanel`
  refuses to send without it (`请填写验证码`), fetches the image from `GET
  /api/verify/captcha` with the **same `Referer` as the submission** (the problem
  page — a session- and origin-bound captcha fetched from the homepage and used
  from the problem page is a plausible source of spurious `验证码错误`), and
  refreshes it automatically after any failure mentioning 验证码, because a captcha
  is single-use.
- **There is only one submit implementation.** The 题库 page used to have its own
  copy of the statement/submit/verdict UI *without* a captcha field, which is
  exactly why submitting from there always failed; it now renders `ProblemPanel`
  with `fetchDetail: false` and hands over the detail it already loaded. That
  deleted ~320 lines of duplicated state, processes and markup from `Panel.qml`
  (`prepareSubmission`, `submitSolution`, `pollRecord`, `setSubmitLanguage`,
  `submitProc`, `recordProc`, `recordTimer` and the `submit*` / `record*`
  properties).

### Contests

`GET /contest/list?_contentOnly=1&page=N` returns **20 per page including
already-finished contests** (`count` 1379), so the most recent past rounds are on
page 1 — they used to be invisible because the fetch sliced `[0:8]` and the
finished ones sit at positions 17-20. The list now keeps the whole page and pages
with 上一页/下一页.

List entries carry no sign-up field, so `joined` has to be probed per contest
(`GET /contest/<id>` → `data.joined`) — the fetch now does that **only for
contests that have not ended** (capped at 8), because a sign-up state is
meaningless once a round is over and each probe is another request.

`GET /contest/<id>?_contentOnly=1` holds the problem list at
**`data.contestProblems`** (each entry `{no:"A", score, problem:{pid,name,
difficulty,submitted,accepted}}`), *not* `contest.problems` — reading the wrong
path silently yields an empty problem list. `data.joined` is available here too.

The contest detail opens in its own `FloatingWindow` titled **洛谷比赛**
(860×700), built by `Loader { active: contestDetailOpen }` and placed by its own
`contestPlacementTimer` — the same pattern (and the same reasons) as 洛谷中心. A
problem row in it jumps to that problem in the 题库 page.

13. **A guarded `visible:` does not guard a sibling `text:`.** QML evaluates every
   binding on an object whether or not it is visible, so
   `visible: root.contestDetail !== null && root.contestDetail.problems.length > 0`
   next to `text: "题目 " + root.contestDetail.problems.length + " 题"` still
   throws `Cannot read property 'problems' of null` while the data is loading. Guard
   the expression itself (`root.contestDetail ? (…) : ""`). The quick audit that
   finds these: list every `root.<nullable>.<prop>` access whose line has no
   preceding `? `/`!== null`/`&&` — then check the multi-line ternaries by hand,
   since a guard on an earlier line does cover them.

14. **A page that fills the viewport cannot rely on the outer `Column`'s
   `implicitHeight`.** 私信 is the one page with an application layout (fixed
   height, its own inner scrolling) instead of a document layout, and it was
   measured broken like this: the chat row was 654 px tall at y=38 (so the page
   really occupied 692 px), yet `detailColumn.implicitHeight` reported **543** —
   the `Flickable` therefore sized its content to 543 and **clipped the bottom
   ~150 px, which is where the message composer lives**. Neither the `Math.max(520, …)`
   floor nor setting `height: detailFlick.height` on the page fixed the reported
   implicit height. What works is to stop asking and state it:

   ```qml
   contentHeight: root.detailPage === "chat" ? height : detailColumn.implicitHeight
   ```

   measured after the change: `flickH=692 contentH=692 contentY=0` for 私信
   (nothing to scroll, nothing clipped) while a long post still reports
   `contentH=7050`. Any future fixed-height page needs the same treatment — and a
   wheel event on the page background then does nothing, which is correct, while
   the inner lists keep scrolling by themselves.

15. **`Row` widths are hand-arithmetic, and the gap count is the easy part to get
   wrong.** Two rows in the contest UI were wider than their container: the page
   header was `(w-196) + 96 + 44 + 44 + 3×8` = **w+12** (so 下一页 poked past the
   edge) and the contest window's title row used `w-110` next to a 110 px button
   with `spacing: 10`, i.e. **w+10**. Prefer a flexible spacer over guessing:

   ```qml
   Text { id: heading; … }                        // no width — takes what it needs
   Item {                                          // absorbs the slack
     width: Math.max(1, row.width - heading.width - count.width - prev.width - next.width - row.spacing * 4)
     height: 1
   }
   ```

   Note `spacing * 4`: five children have **four** gaps, and the first attempt
   there subtracted three, which left the row 8 px too wide again — measured with
   a probe (`childrenRect` 772 vs `row.width` 764), not by eye. The audit that
   finds this class of bug statically is worth repeating after any layout edit:
   for every `Row` with `width: parent.width`, sum the fixed-width children, add
   `spacing × (children-1)`, subtract the amount the flexible child subtracts, and
   report rows where the result is positive. After the fix the same check reports
   0 and the measured `childrenRect.width == row.width == 764`.

16. **A `Flickable` is not a layout container.** Its direct children all sit at
   `y = 0`; only a positioner (`Column`/`Row`) inside it stacks them. The 洛谷题目
   window had a header `Row` and the `ProblemPanel` as two siblings inside one
   `Flickable`, so the problem text was drawn **on top of** the header ("文字重叠").
   Wrapping both in a `Column` fixed it, and the measured proof is the point:
   `kids=[y0/h28, y40/h1114]` — before the fix both were at `y0`. The
   `contentHeight` must also point at that wrapper (`problemBody.implicitHeight`),
   not at one of the children, or the header's height is missing from the scroll
   range. The same audit is worth re-running after any window edit: for every
   `Flickable`, list its direct children — more than one visual item (excluding
   `WheelHandler`s, which do not lay out) means overlapping content.

## User name colours

Luogu colours a user's name by reputation, and `Model.userColor()` is the single
place that turns the API's value into a hex colour. The value arrives in **two
different forms** and both must be accepted:

| source | value |
|---|---|
| 私信 (`/chat`, `/api/chat/record`) and 用户搜索 (`/api/user/search`) | a bare name — `"Red"`, `"Orange"`, `"Gray"` |
| 犇犇's HTML fragment | a CSS class — `"lg-fg-red"`, `"color-purple"` |

Matching only the class form (as it did) meant every name in 私信 fell back to the
default colour — the data was there, the matcher wasn't. The helper now strips a
`lg-fg-`/`color-`/`lg-` prefix when present and otherwise looks the bare name up
directly, covering gray/grey/blue/green/yellow/orange/red/purple/brown/black plus
`cheater`. It also passes through `#rrggbb` values unchanged.

Name colours are applied to: the 私信 conversation/search rows, the conversation
header (via `chatSelectedColor`, threaded through `openChatWith(uid, name, color)`)
and the 犇犇 rows. Chat *messages* now carry the sender's colour too
(`parseChatRecord` reads `sender.color`), even though the bubble itself renders
only the body.

## 犇犇 (feed)

Two different endpoints, and only one of them carries usernames:

| what | endpoint | shape |
|---|---|---|
| 关注动态 | `GET /feed/watching?page=N` | **HTML fragment** (`<li class="… feed-li">`), one block per post with `feed-username`, `/user/<uid>` and a timestamp |
| 关注动态 (JSON) | `GET /api/feed/watching?page=N` | `{status, data:[…]}` where each item is only `{uid, time, type, comment, _instance}` — **no name field at all** |
| 我的犇犇 | `GET /feed/my?page=N&_contentOnly=1` | HTML fragment, same shape as above (`_contentOnly=1` does *not* make this one JSON) |

The feed used to read the JSON API, so `Model.parseFeed` had no name to read and
every row fell back to 「洛谷用户」 (measured: **0 of 19** items had a name). The
fix is to read the HTML fragment and parse it — `Model.parseFeed` already routed
on a leading `<` to `parseFeedHtml`, which extracts uid, name, colour, time and
body. After the change: **10 of 10** items named for both 关注动态 and 我的犇犇.

**Paging.** Both feeds accept `page=N` and return 10 entries per page, oldest
page last, with **no overlap** between consecutive pages (measured: page 1/2/3 =
10/10/9 items, 0 shared). There is no "last page" signal — even `page=200` returns
a full fragment — so the widget appends the next page, de-duplicates by
`uid|time|content` (or by `data-feed-id` when the HTML carries one) through
`Model.mergeFeedItems()`, and hides 加载更多 once a page adds nothing new.
`refresh()` resets back to page 1.

Also worth knowing: `/feed` (no path suffix) answers with an error page, and
`profile.uid` is a **string** while feed `uid`s are **numbers**, so
`modelData.uid === root.profile.uid` is never true — compare with `String(…)`.

## Reading posts inside the panel (Markdown)

`GET /discuss/<id>?_contentOnly=1` returns `data.post.content` as **raw
Markdown** plus one page of `data.replies` (`perPage` 10, `&page=N` for the
rest). The plugin renders it itself instead of sending the reader to the site:
`Model.markdownBlocks()` turns the Markdown into block objects and
`MarkdownView.qml` lays them out, while `Model.inlineHtml()` converts inline
formatting to the slice of HTML Qt's rich text actually renders.

Blocks are laid out in QML rather than by feeding one HTML string to a single
`Text`, because QML rich text cannot fetch remote `<img>` sources at all, while a
plain `Image` can — and does: a 3200×1800 post screenshot loads
(`status == Ready`) with no `Referer`, decoded at 2× the display width and capped
at 1400 px.

Supported: headings, paragraphs, bold/italic/strikethrough/inline code, links and
bare URLs (`<https://…>`), ordered/unordered lists with one level of nesting,
fenced code with a language label, 4-space indented code, blockquotes, `|---|`
tables with per-column alignment, `![alt](url)` images on their own line, `---`
rules, `$$…$$` display math, and `$inline$` math.

**Math is converted, not typeset.** Quickshell has no WebEngine, so KaTeX is not
an option; `Model.latexToHtml()` instead translates a LaTeX subset into Unicode
plus the `<sup>`/`<sub>` that Qt's rich text does render. The subset was chosen
from data, not guesswork: across 283 math snippets in 29 real statements and
posts the commands actually used were `\le` (58), `\times` (18), `\leq` (9),
`\Theta`, `\cdots`, `\ldots`, `\ge`, `\sim`, `\sum`, `\frac`, `\approx`,
`\bm`, `\gcd`, `\bmod`, `\log`, `\ne`, `\max`, `\limits`, `\in`, with 28
superscripts and 48 subscripts. Covered: Greek letters, relations/operators
(`≤ ≥ ≠ ≈ ∈ × ÷ ± ∑ ∫ ∞ ⋯`), `^`/`_` (with braces), `\frac`, `\sqrt[n]{}`,
`\text`/`\mathrm`/`\operatorname`, `\bm`/`\mathbf`, `\left`/`\right`,
spacing commands, `\bmod`/`\pmod`, accents, and `\begin{}`/`&`/`\\` for
matrices (flattened). Two details that make it read like typeset math instead of
a token stream: a control word swallows **one following space** (LaTeX semantics,
so `1\le n` is `1 ≤ n` and not `1≤ n`), and relations/operators get **padding on
both sides** the way TeX's math spacing does — while letter-like symbols (`α`,
`⋯`, `∞`) stay tight. Regression on the same 283 snippets: **0 leftover `\command`,
0 unbalanced `<sup>`/`<sub>`, 0 doubled spaces**. What cannot be converted
(matrices, `cases`, alignment) degrades to readable flattened text rather than
being dropped. A blockquote's inner Markdown is flattened to
inline formatting (a fence or table *inside* a quote stays literal text). A post
is capped at 120 rendered blocks behind a "展开其余 N 段" button, because
everything lives in an un-virtualised `Column` inside the details window's
`Flickable` — the largest post sampled (22 KB) is 294 blocks.

## 题库 (problem bank)

Everything the judge flow needs is reachable over the same direct-HTTP pattern;
the only things that had to be *found* rather than guessed are the enum tables
and the submission body.

| what | endpoint | notes |
|---|---|---|
| 搜题 | `GET /problem/list?_contentOnly=1&page=&keyword=&difficulty=&tag=&type=` | `data.problems{count,perPage:50,result[]}`; verified `difficulty=2&tag=1` narrows 17523 → 479 |
| 排序 | `&orderBy=difficulty&order=asc\|desc`, `&orderBy=pid&order=desc` | only these accepted; anything else falls through to an HTML error page |
| 标签表 | `GET /_lfe/tags/zh-CN` | `{tags:[{id,name,type,parent}]}`, 505 entries; **type 2 + `parent: null` = the 22 algorithm categories** that make a usable dropdown |
| 看题 | `GET /problem/<pid>?_contentOnly=1` | `data.problem.content{background,description,formatI,formatO,hint}` (all Markdown), `samples` = array of `[input, output]` pairs, `limits`, `tags` (ids), `submitted`/`accepted`, plus `data.lastLanguage` / `data.lastCode` (the solver's previous submission) and `data.discussions` |
| 题解列表 | `GET /problem/solution/<pid>?_contentOnly=1` | `data.solutions{count,perPage:10,result[]}`; long entries arrive truncated |
| 题解全文 | `GET /article/<lid>?_contentOnly=1` | a solution *is* an article; `data.article.content` is the full Markdown |
| 题目讨论 | `GET /discuss?forum=<pid>&_contentOnly=1` | each problem has its own board whose slug **is the pid** (`data.forum.slug`), independent of the 30-post default list |
| 交题 | `POST /fe/api/problem/submit/<pid>` | JSON `{code, lang}` + `X-CSRF-Token`; a bad `lang` answers `record.invalid_language_type`, and code shorter than the minimum answers `代码过短` — both *before* a record exists, which is what makes it safe to probe |
| 评测结果 | `GET /record/<rid>?_contentOnly=1` | `data.record{status,score,time,memory,sourceCode,…}` + `data.testcaseGroup`; list at `/record/list?_contentOnly=1` |

The numeric enums (difficulty, language, verdict) are Luogu's own frontend tables,
recovered from the locally installed `vscode-luogu` bundle rather than guessed:
difficulties 0-8 (`暂无评定` … `NOI/NOI+/CTS`, each with its official colour),
languages 1-34 (`C++14 (GCC 9)`=28, `C++23`=34, …), verdicts 0-23
(`12`=Accepted, `6`=Wrong Answer, `5`=TLE, `2`=Compile Error, …). They live in
`Model.js` as `PROBLEM_DIFFICULTIES`, `JUDGE_LANGUAGES`, `JUDGE_STATUS`.

The statement is reassembled into one Markdown document by
`Model.problemStatementMarkdown()` — sections in the order a solver reads them,
with each sample wrapped in a `text` fence so its whitespace survives. That goes
straight into `MarkdownView`.

### Submitting

`POST /fe/api/problem/submit/<pid>` takes JSON `{code, lang, enableO2}` plus
`X-CSRF-Token`. Two things about it are worth keeping in mind:

- **The payload goes through stdin as one line of base64.** Quickshell's `Process`
  exposes `write()` but **no way to close stdin**, and `curl --data-binary @-`
  waits for EOF — so that combination hangs the request until `--max-time` kills
  it (observed). Passing the code as an argv instead would be asking for quoting
  trouble, and `Qt.btoa(string)` is deprecated *and* differs from the web
  behaviour on non-ASCII input, which matters because submitted code is full of
  Chinese comments. So `Model.utf8Base64()` (hand-written, UTF-8, verified
  byte-for-byte against Node's `Buffer.toString("base64")`) encodes the JSON, the
  shell script reads exactly one line (no EOF needed), decodes it to a `mktemp`
  file and hands that to curl with `--data-binary @file`.
- **Failure is free.** Language and code length are validated *before* a record is
  created, so a probe with a bogus `lang` answers `record.invalid_language_type`
  with zero side effects — the whole submit → poll path was built and checked that
  way, and the account's 1179 submissions were untouched.

The verdict is polled from `GET /record/<rid>?_contentOnly=1` every 1.5 s while
the status is 0/1 (Waiting/Judging). Per-testcase results come from
`data.record.detail.judgeResult.subtasks[].testCases[]`, compile failures from
`detail.compileResult`, and both are rendered as a verdict card.

Also supported on the problem page: the per-problem discussion list
(`/discuss?forum=<pid>`, 30 per page) and a thread view with Markdown-rendered
replies, paginated the same way as the 帖子 page.

## 洛谷账号设置 (read-only)

Three GET endpoints back the 设置 page in the sidebar:

| section | endpoint | payload |
|---|---|---|
| 奖项认证 | `GET /user/setting/prize?_contentOnly=1` | `{hasRealName, prizeLevel:{oi:{level},xcpc:{level}}, prizes:[{prize:{year,contest,event,prize,score,rank,name,affiliation,type}, showLevel}]}` — `name`/`affiliation` are the **verified real name and school** |
| 账号安全 | `GET /user/setting/security?_contentOnly=1` | `{email, phone, realName, totpSet, usernameUpdateTime, adminLogs}` — phone and realName come **masked** (`86134*****652`, `熊**`) |
| 第三方绑定 | `GET /user/setting?_contentOnly=1` | `{qqGroupToken, vjudgeAccounts:[{username,oj}], openidAccounts:[{username,platform}]}` |

`/user/setting/<name>` only answers for `prize` and `security`; `profile`, `info`,
`account`, `bind`, `privacy`, `notification`, `email`, `phone`… all 404.

**Editing is not implemented, and that is not an oversight.** The write endpoints
are not discoverable from here: the settings *page* HTML answers a 302 loop back to
itself for anything that is not a real browser (`ws-action: cc` from Luogu's CDN),
so its front-end bundle — which would name the update routes — cannot be read, and
plain guesses (`/api/user/update`, `/api/user/setting/update`, `/api/user/profile/
update`, …) all 404 while a genuine write route is distinguishable by its
`403 InvalidCaptchaException`/`400` answer. To add editing, capture the request in
the browser's devtools (change a field, copy the URL, headers and body) and it can
be wired up the same way as the submission flow.

## Discussion writes: captcha and boards

Both discussion writes (`POST /api/discuss/post`, `POST /api/discuss/reply/:id`) are
captcha-gated, and the server checks the captcha **before** title, content or
board — an empty content probe still answers `InvalidCaptchaException`
(`验证码错误`, 403). Two different captcha endpoints exist:

| endpoint | used for | look |
|---|---|---|
| `/lg4/captcha` | login | dark background |
| `/api/verify/captcha` | discussion writes | random background |

The image is bound to the session cookies, so it is fetched with the widget's
own `_uid`/`__client_id` and the typed code is sent as `captcha`. Its mime type
is carried through from `%{content_type}` (`image/jpeg`) rather than assumed —
the login form's hard-coded `data:image/png;base64,` prefix is wrong for the
JPEG it actually receives. A captcha is single-use: after any failed attempt the
widget immediately fetches a fresh image, and each form (post / reply) keeps its
own, because sharing one image makes the second form fail.

Boards are slugs, not letters: `data.publicForums` (also returned by
`GET /discuss`) lists `academics` = 学术版, `problem` = 题目总版,
`siteaffairs` = 站务版. The old default `P` matches no board — the read API
returns an empty forum name for it. `Model.parseForums` reads the list and puts
学术版 first as the default, falling back to the three known boards.

**Posting permission is per board, not per account.** `GET /discuss?forum=<slug>`
reports `canPost` for that board alone; with no `forum` parameter it is the
aggregate and reads `false`. Verified live: `academics` and `problem` are `true`,
`siteaffairs` is `false`. `forumPermProc` asks each board once per details-window
session, `Model.parseForumPermissions` turns the answers into the dropdown
options, boards that refuse are labelled `（无发帖权限）`, and `publishPost()`
refuses before spending the captcha.

**A write is only successful on positive evidence.** `writeResponseSucceeded`
used to default to success when it could not parse the answer — an empty body,
an HTML page, or a JSON object with no `status` field. That is how posting to
站务版 (no permission) reported "帖子已发布" while nothing was published. Now it
requires an explicit `status`/`code`/`errorCode` of 0 or 200 (or, for a JSON body
without one, a payload that is neither `false` nor `null` and carries no error
field), and an empty or non-JSON body is never a success. `writeFailureMessage`
also returns an excerpt of an unclassifiable body, or says the result cannot be
confirmed, instead of a vague "洛谷没有返回可解析的结果".

The write endpoint is rate limited: a burst of attempts answers
`FrequentRequestException` (`请求频繁，请稍候再试`, 403), which the UI now shows
verbatim instead of a generic failure.

## Settings

The widget declares five user settings in `manifest.json` under
`barWidget.schema` (`integer` / `boolean` / `string` / `enum` are the types the
shell's settings UI understands):

| key | type | default | effect |
|---|---|---|---|
| `refreshIntervalSec` | integer 30–3600 | 300 | the bar refresh timer (`BarWidget.qml`) |
| `iconText` | string | `洛` | the glyph in the bar slot |
| `showUnreadBadge` | boolean | true | the unread count badge |
| `markdownBlockLimit` | integer 20–600 | 120 | blocks rendered before 展开 collapses the rest (all 6 `MarkdownView` uses) |
| `defaultLanguage` | enum | `C++14 (GCC 9)` | submission language when a problem has no history (`Model.languageIdByName` converts the name to the numeric id the API wants) |

**Where the values live is the trap.** They are **direct keys on the widget's
`bar` layout entry** in `~/.config/omarchy/shell.json`, *not* nested under a
`settings` object — `BarModel.entrySettings()` simply copies the entry and drops
`id`, and the bar assigns that copy to the widget's `settings` property. So it is

```json
{ "id": "bearthomas.luogu", "iconText": "洛谷", "refreshIntervalSec": 120 }
```

exactly like the first-party `omarchy.clock` entry and its `format` key. Writing
`{"id": "...", "settings": {…}}` instead silently nests everything one level too
deep and every `setting()` call falls back to its default.

**How to set them.** There is no GUI editor for a plugin's schema in this
Omarchy version — even first-party plugins (`omarchy.agents`, `omarchy.clock`)
report `schema: []` through `omarchy-shell shell listPlugins`, because the shell
reads a top-level `meta.schema` that nobody populates; `barWidget.schema` is
declarative metadata. The working path is the CLI, which also **does not validate
key names** (a typo is written happily and silently does nothing):

```bash
omarchy bar set bearthomas.luogu iconText 洛谷
omarchy bar set bearthomas.luogu refreshIntervalSec 120
omarchy bar set bearthomas.luogu markdownBlockLimit 40
omarchy bar set bearthomas.luogu defaultLanguage "C++20"
omarchy bar set bearthomas.luogu showUnreadBadge false
```

Without `--json` every value is written as a **string**, which is why the reads
coerce: integers go through `Number(...)`, and the boolean is compared as
`String(value) !== "false"` — the string `"false"` is truthy in JS, so a plain
`setting("showUnreadBadge", true)` would have left the badge on.

Verified live by seeding those keys and restarting: `icon=洛谷`,
`timerIntervalMs=120000` (was 300000), `mdLimit=40`, `defaultLangId=27` for
`C++20`. The test values were then removed so the shipped defaults apply; the
editor in Omarchy's bar settings writes the same shape.

## Current scope

- Circle bar icon matching the native Omarchy icon slot, with an unread badge
  (private messages + notifications, capped at `99+`) and a 5-minute refresh.
- Optional Cookie login and identity validation.
- Password login with Luogu captcha, following the direct-request flow used by
  `vscode-luogu`; passwords are passed through stdin and never stored.
- User profile, Guzhi breakdown, ranking, level-score trend and a 26-week
  solving heatmap.
- 概览 identity card: avatar, name in the user's Luogu colour, 认证 mark,
  签名/简介, UID/排名/关注/粉丝, 入坑天数 and CCF/XCPC levels, plus the latest
  等级分 with its delta and contest name, and the 获奖 list (`data.prizes`).
- Contests: the latest 20 per page (finished rounds included), each opening a
  standalone 洛谷比赛 window with the time, host, problem list and description;
  notifications, and the 犇犇 feed.
- 私信 as a real conversation UI: conversation list, user search by name or UID,
  per-user message thread, and a composer (Enter sends).
- Discussion posts read inside the panel with Markdown rendering, plus create /
  reply forms using the board captcha.
- 题库: multi-factor search (keyword / difficulty / 22 algorithm categories /
  sort), problem statements rendered from Markdown, 题解 (list + full text),
  per-problem discussions, and submission — language picker (from the problem's
  accepted languages, defaulting to your previous choice), an O2 toggle, a code
  editor prefilled with your last submission for that problem, and a verdict card
  that polls until judging finishes.
- Refresh and logout controls.

Known gaps: the code editor is a plain monospace text area (no syntax
highlighting, no line numbers), and math in statements is shown as tinted
monospace because there is no LaTeX engine. Daily punch, automatic punch and
contest charts remain on the list.
