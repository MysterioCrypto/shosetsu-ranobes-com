-- {"id":962041,"ver":"1.0.4","libVer":"1.0.0","author":"MysterioCrypto","dep":[]}

local baseURL = "https://ranobes.com"
local imageURL = "https://github.com/bigrand/shosetsu-extensions/raw/master/icons/ranobes.png"
local consecutiveTriggers = 0

local function trim(s) if not s then return "" end return tostring(s):match("^%s*(.-)%s*$") or "" end
local function startsWith(str, prefix) return str ~= nil and str:sub(1, #prefix) == prefix end
local function normalizeURL(url)
    url = trim(url)
    if url == "" then return baseURL end
    url = url:gsub("^['\"]", ""):gsub("['\"]$", "")
    if url:find("^https?://") then return url end
    if url:sub(1, 2) == "//" then return "https:" .. url end
    if url:sub(1, 1) ~= "/" then url = "/" .. url end
    return baseURL .. url
end
local function shrinkURL(url) url = normalizeURL(url); if startsWith(url, baseURL) then return url:sub(#baseURL + 1) end; return url end
local function expandURL(url) return normalizeURL(url) end
local function ensureTrailingSlash(url) url = trim(url); if url ~= "" and url:sub(-1) ~= "/" then return url .. "/" end; return url end
local function textOf(node) if not node then return "" end return trim(node:text()) end
local function attrOf(node, attr) if not node then return "" end return trim(node:attr(attr)) end
local function first(root, selectors) if not root then return nil end; for _, selector in ipairs(selectors) do local n = root:selectFirst(selector); if n then return n end end; return nil end
local function concatLists(a, b) for i = 1, #b do table.insert(a, b[i]) end return a end

local function randomizedDelay(isSearch)
    local delayTime
    if isSearch then
        consecutiveTriggers = consecutiveTriggers + 1
        if consecutiveTriggers <= 2 then delayTime = math.random(900, 1700) else delayTime = math.random(2500, 4200) end
    else delayTime = math.random(1500, 3000) end
    delay(delayTime)
end

local function makeDebugNovel(title, details)
    local text = "DEBUG: " .. tostring(title or "unknown")
    if details and details ~= "" then text = text .. " — " .. tostring(details) end
    return { Novel({ title = text, link = "/ranobe/", imageURL = imageURL }) }
end

local function ruLower(s)
    s = tostring(s or ""):lower()
    local map = {{"А","а"},{"Б","б"},{"В","в"},{"Г","г"},{"Д","д"},{"Е","е"},{"Ё","ё"},{"Ж","ж"},{"З","з"},{"И","и"},{"Й","й"},{"К","к"},{"Л","л"},{"М","м"},{"Н","н"},{"О","о"},{"П","п"},{"Р","р"},{"С","с"},{"Т","т"},{"У","у"},{"Ф","ф"},{"Х","х"},{"Ц","ц"},{"Ч","ч"},{"Ш","ш"},{"Щ","щ"},{"Ъ","ъ"},{"Ы","ы"},{"Ь","ь"},{"Э","э"},{"Ю","ю"},{"Я","я"}}
    for _, pair in ipairs(map) do s = s:gsub(pair[1], pair[2]) end
    return s
end
local function queryMatches(title, link, query)
    query = trim(query)
    if query == "" then return true end
    local q = ruLower(query)
    return ruLower(title):find(q, 1, true) ~= nil or ruLower(link):find(q, 1, true) ~= nil
end

local function htmlToString(text)
    text = tostring(text or ""):gsub(">%s+<", "><"):gsub("&nbsp;", " "):gsub(" ", " ")
    local br = "%s*<[Bb][Rr]%s*(/?)%s*>%s*"
    text = text:gsub(br .. br .. "(" .. br .. ")*", "[[BRBR]]"):gsub(br, "\n"):gsub("</[Pp]>", "\n\n"):gsub("<[^>]+>", ""):gsub("%[%[BRBR%]%]", "\n\n")
    local lines = {}; for line in (text .. "\n"):gmatch("(.-)\n") do table.insert(lines, trim(line)) end
    return trim(table.concat(lines, "\n"))
end

local function safeFetch(url, soft)
    local ok, document = pcall(GETDocument, expandURL(url))
    if not ok then
        local err = tostring(document); local code = err:match("(%d%d%d)")
        if soft then return false, code or "unknown", err end
        error("HTTP error: " .. (code or err))
    end
    local title = textOf(document:selectFirst("title")); local body = textOf(document)
    if title == "Error" or title == "Ranobes Flood Guard" or title == "Just a moment..." or title:find("Антибот") or body:find("подозрительную активность") or body:find("Ranobes Flood Guard") then
        if soft then return false, "captcha", "verification page: " .. title end
        error("Verification page detected. Open WebView/browser and retry.")
    end
    return document
end

local function styleImageURL(node)
    if not node then return "" end
    local u = attrOf(node, "style"):match("url%(['\"]?(.-)['\"]?%)")
    if not u or u == "" then return "" end
    return normalizeURL(u)
end
local function cardImage(card)
    local u = styleImageURL(first(card, { ".cover", "figure", ".poster", ".poster-img" }))
    if u ~= "" then return u end
    local img = first(card, { "img[data-src]", "img[src]" })
    local src = attrOf(img, "data-src"); if src == "" then src = attrOf(img, "src") end
    if src ~= "" then return normalizeURL(src) end
    return imageURL
end

local function urlEncode(str)
    str = tostring(str or ""):gsub("\n", " ")
    return str:gsub("([^%w%-_%.~])", function(c) return string.format("%%%02X", string.byte(c)) end)
end
local function pageFromData(data) if data and data[PAGE] then return tonumber(data[PAGE]) or 1 end return 1 end
local function buildCatalogURL(data) local p = pageFromData(data); if p <= 1 then return baseURL .. "/ranobe/" end; return baseURL .. "/ranobe/page/" .. p .. "/" end
local function buildSearchURLs(data)
    local p = pageFromData(data); local raw = ""; if data and data[QUERY] then raw = trim(data[QUERY]) end
    if raw == "" then return { buildCatalogURL(data) } end
    local enc = urlEncode(raw)
    return {
        baseURL .. "/search/" .. raw .. "/page/" .. p,
        baseURL .. "/search/" .. enc .. "/page/" .. p,
        baseURL .. "/ranobe/l.title=" .. raw .. "/sort=date/order=desc/page/" .. p .. "/",
        baseURL .. "/ranobe/l.title=" .. enc .. "/sort=date/order=desc/page/" .. p .. "/",
        baseURL .. "/f/l.title=" .. raw .. "/sort=date/order=desc/page/" .. p,
        baseURL .. "/f/l.title=" .. enc .. "/sort=date/order=desc/page/" .. p
    }
end

local function isNovelHref(href)
    href = shrinkURL(href)
    return href:find("^/ranobe/%d+%-") ~= nil and href:find("%.html") ~= nil
end
local function addNovel(out, seen, title, href, img, query)
    title = trim(title); href = trim(href)
    if title == "" or href == "" or title == "Читать" or title == "Закладка" then return end
    if not isNovelHref(href) or not queryMatches(title, href, query or "") then return end
    local link = shrinkURL(href); if seen[link] then return end; seen[link] = true
    table.insert(out, Novel({ title = title, link = link, imageURL = img or imageURL }))
end

local function parseListingURLInternal(url, withDebug, query)
    randomizedDelay(true)
    local doc, et, em = safeFetch(url, true)
    if not doc then
        if withDebug then return makeDebugNovel("fetch failed", "url=" .. tostring(url) .. "; type=" .. tostring(et) .. "; msg=" .. tostring(em)) end
        return {}, "fetch failed: " .. tostring(et) .. ": " .. tostring(em)
    end
    local root = doc:selectFirst("#dle-content") or doc:selectFirst("main") or doc
    local out = {}; local seen = {}
    local cards = root:select("article, .shortstory, .rank-story, .block.story")
    for i = 1, cards:size() do
        local card = cards:get(i - 1)
        local a = first(card, { "h2 > a[href*='/ranobe/']", "h2 a[href*='/ranobe/']", ".title > a[href*='/ranobe/']", ".title a[href*='/ranobe/']" })
        addNovel(out, seen, textOf(a), attrOf(a, "href"), cardImage(card), query)
    end
    local links = root:select("h2 > a[href*='/ranobe/'], h2 a[href*='/ranobe/'], .title > a[href*='/ranobe/'], .title a[href*='/ranobe/']")
    for i = 1, links:size() do local a = links:get(i - 1); addNovel(out, seen, textOf(a), attrOf(a, "href"), imageURL, query) end
    if #out > 0 then return out, nil end
    local reason = "no novels parsed: url=" .. tostring(url) .. "; title=" .. textOf(doc:selectFirst("title"))
    if withDebug then return makeDebugNovel("no novels parsed", reason) end
    return {}, reason
end
local function parseListingURL(url) return parseListingURLInternal(url, true, "") end
local function search(data)
    local raw = ""; if data and data[QUERY] then raw = trim(data[QUERY]) end
    local last = ""
    for _, url in ipairs(buildSearchURLs(data)) do
        local novels, reason = parseListingURLInternal(url, false, raw)
        if #novels > 0 then return novels end
        last = last .. " | " .. tostring(reason)
    end
    return makeDebugNovel("search failed", last)
end

local function mapStatus(s)
    s = trim(s)
    return ({["Активен"] = NovelStatus.PUBLISHING,["Активно"] = NovelStatus.PUBLISHING,["В процессе"] = NovelStatus.PUBLISHING,["Продолжается"] = NovelStatus.PUBLISHING,["Онгоинг"] = NovelStatus.PUBLISHING,["Ongoing"] = NovelStatus.PUBLISHING,["Active"] = NovelStatus.PUBLISHING,["Завершено"] = NovelStatus.COMPLETED,["Завершён"] = NovelStatus.COMPLETED,["Завершена"] = NovelStatus.COMPLETED,["Закончен"] = NovelStatus.COMPLETED,["Закончено"] = NovelStatus.COMPLETED,["Completed"] = NovelStatus.COMPLETED,["Приостановлено"] = NovelStatus.PAUSED,["Заморожено"] = NovelStatus.PAUSED,["Пауза"] = NovelStatus.PAUSED,["Break"] = NovelStatus.PAUSED,["Hiatus"] = NovelStatus.PAUSED})[s] or NovelStatus.UNKNOWN
end
local function extractNumber(text) local n = tostring(text or ""):gsub("%s+", ""):match("(%d+)"); return n and tonumber(n) or nil end
local function findSpecValue(doc, labels)
    local nodes = doc:select("div.r-fullstory-spec li, .r-fullstory-spec li")
    for i = 1, nodes:size() do
        local li = nodes:get(i - 1); local txt = textOf(li)
        for _, label in ipairs(labels) do
            if txt:find(label) then local v = textOf(first(li, { "span a", "span" })); if v ~= "" then return v end; return trim(txt:gsub(label .. "%s*: ?", "")) end
        end
    end
    return ""
end
local function getNumberFromSpec(doc, labels) return extractNumber(findSpecValue(doc, labels)) or 0 end

local function findChapterIndexUrl(doc, novelURL)
    local links = doc:select("a[href*='/chapters/']")
    for i = 1, links:size() do local href = attrOf(links:get(i - 1), "href"); if href:find("/chapters/") and not href:find("%.html") then return normalizeURL(href) end end
    local slug = shrinkURL(novelURL):match("/ranobe/%d+%-([^/%.]+)%.html")
    if slug and slug ~= "" then return baseURL .. "/chapters/" .. slug .. "/" end
    error("Chapter index URL not found.")
end
local function getLastPage(doc)
    local max = 1; local links = doc:select("a[href*='/page/']")
    for i = 1, links:size() do local p = tonumber(attrOf(links:get(i - 1), "href"):match("/page/(%d+)/?")); if p and p > max then max = p end end
    return max
end
local function chapterOrder(title, href, fallback)
    local n = title:match("[Гг]лава%s*([%d%.]+)") or title:match("[Чч]асть%s*([%d%.]+)") or title:match("[Cc]hapter%s*([%d%.]+)") or href:match("/(%d+)%-")
    return tonumber(n) or fallback
end
local function parseChapters(doc)
    local root = doc:selectFirst("#dle-content") or doc; local links = root:select("a[href*='/chapters/']"); local out = {}; local seen = {}
    for i = links:size(), 1, -1 do
        local a = links:get(i - 1); local href = attrOf(a, "href"); local title = textOf(a)
        if href:find("/chapters/") and href:find("%.html") and title ~= "" and not seen[href] then
            seen[href] = true; table.insert(out, NovelChapter({ order = chapterOrder(title, href, #out + 1), title = title, link = shrinkURL(href) }))
        end
    end
    return out
end

local function parseNovel(novelURL, loadChapters)
    local fullURL = expandURL(novelURL); local doc = safeFetch(fullURL)
    local titleNode = first(doc, { 'meta[property="og:title"]', "h1.title", "h1" })
    local title = attrOf(titleNode, "content"); if title == "" then title = textOf(titleNode) end
    local altTitle = textOf(first(doc, { "h1.title > span.subtitle", ".subtitle" }))
    local imgURL = attrOf(first(doc, { "a.highslide", 'meta[property="og:image"]' }), "href"); if imgURL == "" then imgURL = attrOf(first(doc, { 'meta[property="og:image"]' }), "content") end; if imgURL == "" then imgURL = imageURL end
    local desc = htmlToString(first(doc, { ".moreless.cont-text.showcont-h", ".cont-text.showcont-h", ".full-text", "#dle-content .text" }))
    local genres = {}; local g = doc:select("#mc-fs-genre div.links a, #mc-fs-genre a, a[href*='/genres/']"); for i = 1, g:size() do local t = textOf(g:get(i - 1)); if t ~= "" then table.insert(genres, t) end end
    local authors = {}; local an = doc:select(".tag_list a, a[href*='/authors/'], a[href*='/author/']"); for i = 1, an:size() do local t = textOf(an:get(i - 1)); if t ~= "" then table.insert(authors, t) end end
    local tags = {}; local tn = doc:select(".cont-in .cont-text.showcont-h a, .tags a, a[href*='/tags/']"); for i = 1, tn:size() do local t = textOf(tn:get(i - 1)); if t ~= "" then table.insert(tags, t) end end
    local info = NovelInfo({ title = title, alternativeTitles = { altTitle }, link = shrinkURL(fullURL), imageURL = normalizeURL(imgURL), language = "rus", description = desc, status = mapStatus(findSpecValue(doc, { "Произведение", "Статус", "Перевод" })), tags = tags, genres = genres, authors = authors, viewCount = getNumberFromSpec(doc, { "Просмотров", "Просмотры" }), commentCount = getNumberFromSpec(doc, { "Комментариев", "Комментарии" }) })
    if loadChapters then
        local chapters = {}; local indexURL = ensureTrailingSlash(findChapterIndexUrl(doc, fullURL)); local firstDoc = safeFetch(indexURL, true)
        if firstDoc then local total = getLastPage(firstDoc); local pages = { firstDoc }; for p = 2, total do randomizedDelay(false); local pd = safeFetch(indexURL .. "page/" .. p .. "/", true); if pd then pages[p] = pd end end; for p = total, 1, -1 do if pages[p] then chapters = concatLists(chapters, parseChapters(pages[p])) end end end
        info:setChapters(AsList(chapters))
    end
    return info
end

local function getPassage(chapterURL)
    local doc = safeFetch(chapterURL); local title = textOf(first(doc, { "#dle-speedbar > span", "h1.title", "h1" })); local chapter = first(doc, { "#arrticle.text", "#article.text", "div.text", ".chapter-text", ".reader-area" })
    if not chapter then error("Chapter text not found.") end
    if title ~= "" then chapter:prepend("# " .. title .. "\n\n") end
    return pageOfElem(chapter, false)
end

return {
    id = 962041,
    name = "Ranobes.com RU",
    baseURL = baseURL,
    imageURL = imageURL,
    hasCloudFlare = true,
    hasSearch = true,
    chapterType = ChapterType.HTML,
    listings = {
        Listing("Ранобэ", true, function(data) return parseListingURL(buildCatalogURL(data)) end),
        Listing("Главная", false, function() return parseListingURL(baseURL .. "/") end),
        Listing("Популярное", false, function() return parseListingURL(baseURL .. "/popular.html") end),
    },
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    getPassage = getPassage,
    parseNovel = parseNovel,
    search = search,
}
