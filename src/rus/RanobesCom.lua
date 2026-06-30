-- {"id":962041,"ver":"1.0.11","libVer":"1.0.0","author":"MysterioCrypto","dep":[]}

local baseURL = "https://ranobes.com"
local imageURL = "https://github.com/bigrand/shosetsu-extensions/raw/master/icons/ranobes.png"

local function trim(s)
    if not s then return "" end
    return tostring(s):match("^%s*(.-)%s*$") or ""
end

local function textOf(node)
    if not node then return "" end
    return trim(node:text())
end

local function attrOf(node, attr)
    if not node then return "" end
    return trim(node:attr(attr))
end

local function first(root, selectors)
    if not root then return nil end
    for _, selector in ipairs(selectors) do
        local node = root:selectFirst(selector)
        if node then return node end
    end
    return nil
end

local function normalizeURL(url)
    url = trim(url)
    if url == "" then return baseURL end
    url = url:gsub("&amp;", "&"):gsub("&#58;", ":")
    url = url:gsub("^['\"]", ""):gsub("['\"]$", "")
    if url:find("^https?://") then return url end
    if url:sub(1, 2) == "//" then return "https:" .. url end
    if url:sub(1, 1) ~= "/" then url = "/" .. url end
    return baseURL .. url
end

local function shrinkURL(url)
    url = normalizeURL(url)
    if url:sub(1, #baseURL) == baseURL then return url:sub(#baseURL + 1) end
    return url
end

local function expandURL(url)
    return normalizeURL(url)
end

local function urlEncode(str)
    str = tostring(str or ""):gsub("\n", " ")
    return str:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

local function urlDecode(str)
    str = tostring(str or "")
    return str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

local function pageFromData(data)
    if not data then return 1 end
    if PAGE and data[PAGE] then return tonumber(data[PAGE]) or 1 end
    if data["page"] then return tonumber(data["page"]) or 1 end
    if data["PAGE"] then return tonumber(data["PAGE"]) or 1 end
    if data["p"] then return tonumber(data["p"]) or 1 end
    return 1
end

local function queryFromData(data)
    if not data then return "" end
    local q = ""
    if QUERY and data[QUERY] then q = data[QUERY] end
    if q == "" and data["query"] then q = data["query"] end
    if q == "" and data["QUERY"] then q = data["QUERY"] end
    if q == "" and data["q"] then q = data["q"] end
    return trim(urlDecode(q))
end

local function waitBeforeRequest(isSearch)
    if isSearch then delay(math.random(900, 1800)) else delay(math.random(1300, 2800)) end
end

local function safeFetch(url, soft)
    local ok, doc = pcall(GETDocument, expandURL(url))
    if not ok then
        if soft then return nil, tostring(doc) end
        error(tostring(doc))
    end
    local title = textOf(doc:selectFirst("title"))
    local body = textOf(doc)
    if title == "Error" or title == "Ranobes Flood Guard" or title == "Just a moment..." or title:find("Антибот") or body:find("подозрительную активность") or body:find("Ranobes Flood Guard") then
        if soft then return nil, "verification page: " .. title end
        error("Verification page detected. Open WebView/browser and retry.")
    end
    return doc, nil
end

local function isNovelHref(href)
    href = shrinkURL(href)
    if href == "/ranobe" or href == "/ranobe/" then return false end
    return href:find("^/ranobe/%d+%-") ~= nil and href:find("%.html") ~= nil
end

local function ruLower(s)
    s = tostring(s or ""):lower()
    local map = {{"А","а"},{"Б","б"},{"В","в"},{"Г","г"},{"Д","д"},{"Е","е"},{"Ё","ё"},{"Ж","ж"},{"З","з"},{"И","и"},{"Й","й"},{"К","к"},{"Л","л"},{"М","м"},{"Н","н"},{"О","о"},{"П","п"},{"Р","р"},{"С","с"},{"Т","т"},{"У","у"},{"Ф","ф"},{"Х","х"},{"Ц","ц"},{"Ч","ч"},{"Ш","ш"},{"Щ","щ"},{"Ъ","ъ"},{"Ы","ы"},{"Ь","ь"},{"Э","э"},{"Ю","ю"},{"Я","я"}}
    for _, p in ipairs(map) do s = s:gsub(p[1], p[2]) end
    return s
end

local function queryMatches(title, link, query)
    query = trim(query)
    if query == "" then return true end
    local q = ruLower(query)
    return ruLower(title):find(q, 1, true) ~= nil or ruLower(link):find(q, 1, true) ~= nil
end

local function cleanTitle(title)
    title = trim(title)
    title = title:gsub("&quot;", "\"")
    title = title:gsub("%s+Более%s+[%d%s]+%s+просмотров.*$", "")
    title = title:gsub("%s+Китайский;.*$", "")
    title = title:gsub("%s+Корейский;.*$", "")
    title = title:gsub("%s+Японский;.*$", "")
    title = title:gsub("%s+Английский;.*$", "")
    title = title:gsub("%s+Русский;.*$", "")
    return trim(title)
end

local function imageFromStyle(style)
    local u = trim(style):match("url%((.-)%)")
    if not u or u == "" then return "" end
    u = trim(u):gsub("^['\"]", ""):gsub("['\"]$", "")
    if u == "" then return "" end
    return normalizeURL(u)
end

local function cardImage(card)
    local fig = first(card, { "figure.cover", ".cover" })
    local u = imageFromStyle(attrOf(fig, "style"))
    if u ~= "" then return u end
    local img = first(card, { "img" })
    local src = attrOf(img, "data-src")
    if src == "" then src = attrOf(img, "src") end
    if src ~= "" then return normalizeURL(src) end
    return imageURL
end

local function findCardTitleLink(card)
    local a = first(card, { "h2.title a", ".title a", "h2 a", "h3 a" })
    if a and isNovelHref(attrOf(a, "href")) and textOf(a) ~= "" then return a end
    local links = card:select("a")
    for i = 1, links:size() do
        local link = links:get(i - 1)
        if isNovelHref(attrOf(link, "href")) and textOf(link) ~= "" then return link end
    end
    return nil
end

local function addNovel(out, seen, title, href, img, query)
    title = cleanTitle(title)
    href = trim(href)
    if title == "" or href == "" then return end
    if title == "Читать" or title == "Закладка" or title == "Ранобэ" or title == "Ранобэс" then return end
    if not isNovelHref(href) then return end
    if query ~= nil and query ~= "" and not queryMatches(title, href, query) then return end
    local link = shrinkURL(href)
    if seen[link] then return end
    seen[link] = true
    table.insert(out, Novel({ title = title, link = link, imageURL = img or imageURL }))
end

local function parseCards(root, query)
    local out = {}
    local seen = {}
    if not root then return out end
    local cards = root:select("article")
    if cards:size() == 0 then cards = root:select(".shortstory") end
    if cards:size() == 0 then cards = root:select(".story") end
    for i = 1, cards:size() do
        local card = cards:get(i - 1)
        local a = findCardTitleLink(card)
        addNovel(out, seen, textOf(a), attrOf(a, "href"), cardImage(card), query or "")
    end
    return out
end

local function catalogURL(data)
    local page = pageFromData(data)
    if page <= 1 then return baseURL .. "/ranobe/" end
    return baseURL .. "/ranobe/page/" .. page .. "/"
end

local function searchURLs(query, page)
    local enc = urlEncode(query)
    local urls = {}
    if page and page > 1 then
        table.insert(urls, baseURL .. "/search/" .. enc .. "/page/" .. page)
        table.insert(urls, baseURL .. "/search/" .. query .. "/page/" .. page)
        table.insert(urls, baseURL .. "/f/cat=1/l.title=" .. enc .. "/sort=date/order=desc/page/" .. page .. "/")
    else
        table.insert(urls, baseURL .. "/search/" .. enc .. "/page/1")
        table.insert(urls, baseURL .. "/search/" .. query .. "/page/1")
        table.insert(urls, baseURL .. "/f/cat=1/l.title=" .. enc .. "/sort=date/order=desc/")
    end
    return urls
end

local function parseListingURL(url)
    waitBeforeRequest(false)
    local doc = safeFetch(url, true)
    if not doc then return {} end
    local root = doc:selectFirst("#dle-content") or doc:selectFirst("main") or doc
    return parseCards(root, "")
end

local function search(data)
    local q = queryFromData(data)
    if q == "" then return {} end
    local urls = searchURLs(q, pageFromData(data))
    for _, url in ipairs(urls) do
        waitBeforeRequest(true)
        local doc = safeFetch(url, true)
        if doc then
            local root = doc:selectFirst("#dle-content") or doc:selectFirst("main") or doc
            local out = parseCards(root, q)
            if #out > 0 then return out end
        end
    end
    return {}
end

local function cleanChapterTitle(title)
    title = trim(title)
    title = title:gsub("&quot;", "\"")
    title = title:gsub("%s+%d%d?%s+%S+%s+20%d%d.*$", "")
    title = title:gsub("%s+%d%d?%.%d%d%.20%d%d.*$", "")
    return trim(title)
end

local function htmlToString(node)
    if not node then return "" end
    local html = tostring(node)
    html = html:gsub(">%s+<", "><"):gsub("&nbsp;", " "):gsub(" ", " ")
    html = html:gsub("%s*<[Bb][Rr]%s*/?%s*>%s*", "\n")
    html = html:gsub("</[Pp]>", "\n\n")
    html = html:gsub("<[^>]+>", "")
    local lines = {}
    for line in (html .. "\n"):gmatch("(.-)\n") do table.insert(lines, trim(line)) end
    return trim(table.concat(lines, "\n"))
end

local function mapStatus(s)
    s = trim(s)
    return ({
        ["Активен"] = NovelStatus.PUBLISHING,
        ["Активно"] = NovelStatus.PUBLISHING,
        ["В процессе"] = NovelStatus.PUBLISHING,
        ["Продолжается"] = NovelStatus.PUBLISHING,
        ["Онгоинг"] = NovelStatus.PUBLISHING,
        ["Ongoing"] = NovelStatus.PUBLISHING,
        ["Active"] = NovelStatus.PUBLISHING,
        ["Завершено"] = NovelStatus.COMPLETED,
        ["Завершён"] = NovelStatus.COMPLETED,
        ["Завершена"] = NovelStatus.COMPLETED,
        ["Закончен"] = NovelStatus.COMPLETED,
        ["Закончено"] = NovelStatus.COMPLETED,
        ["Completed"] = NovelStatus.COMPLETED,
        ["Приостановлено"] = NovelStatus.PAUSED,
        ["Заморожено"] = NovelStatus.PAUSED,
        ["Пауза"] = NovelStatus.PAUSED,
        ["Break"] = NovelStatus.PAUSED,
        ["Hiatus"] = NovelStatus.PAUSED
    })[s] or NovelStatus.UNKNOWN
end

local function extractNumber(text)
    local n = tostring(text or ""):gsub("%s+", ""):match("(%d+)")
    return n and tonumber(n) or nil
end

local function findSpecValue(doc, labels)
    local nodes = doc:select(".r-fullstory-spec li")
    for i = 1, nodes:size() do
        local li = nodes:get(i - 1)
        local txt = textOf(li)
        for _, label in ipairs(labels) do
            if txt:find(label) then
                local v = textOf(first(li, { "span a", "span" }))
                if v ~= "" then return v end
                return trim(txt:gsub(label .. "%s*: ?", ""))
            end
        end
    end
    return ""
end

local function getNumberFromSpec(doc, labels)
    return extractNumber(findSpecValue(doc, labels)) or 0
end

local function findChapterIndexUrl(doc, novelURL)
    local links = doc:select("a")
    for i = 1, links:size() do
        local href = attrOf(links:get(i - 1), "href")
        if href:find("/chapters/") and not href:find("%.html") then return normalizeURL(href) end
    end
    local slug = shrinkURL(novelURL):match("/ranobe/%d+%-([^/%.]+)%.html")
    if slug and slug ~= "" then return baseURL .. "/chapters/" .. slug .. "/" end
    error("Chapter index URL not found.")
end

local function getLastPage(doc)
    local max = 1
    local links = doc:select("a")
    for i = 1, links:size() do
        local p = tonumber(attrOf(links:get(i - 1), "href"):match("/page/(%d+)/?"))
        if p and p > max then max = p end
    end
    return max
end

local function chapterOrder(title, href, fallback)
    local n = title:match("[Гг]лава%s*([%d%.]+)") or title:match("[Чч]асть%s*([%d%.]+)") or title:match("[Cc]hapter%s*([%d%.]+)") or href:match("/(%d+)%-")
    return tonumber(n) or fallback
end

local function parseChapters(doc)
    local root = doc:selectFirst("#dle-content") or doc
    local links = root:select("a")
    local out = {}
    local seen = {}
    for i = links:size(), 1, -1 do
        local a = links:get(i - 1)
        local href = attrOf(a, "href")
        local title = cleanChapterTitle(textOf(a))
        if href:find("/chapters/") and href:find("%.html") and title ~= "" and not seen[href] then
            seen[href] = true
            table.insert(out, NovelChapter({ order = chapterOrder(title, href, #out + 1), title = title, link = shrinkURL(href) }))
        end
    end
    return out
end

local function parseNovel(novelURL, loadChapters)
    local fullURL = expandURL(novelURL)
    local doc = safeFetch(fullURL)
    local titleNode = first(doc, { 'meta[property="og:title"]', "h1.title", "h1" })
    local title = attrOf(titleNode, "content")
    if title == "" then title = textOf(titleNode) end
    local altTitle = textOf(first(doc, { "h1.title span.subtitle", ".subtitle" }))
    local imgURL = attrOf(first(doc, { "a.highslide", 'meta[property="og:image"]' }), "href")
    if imgURL == "" then imgURL = attrOf(first(doc, { 'meta[property="og:image"]' }), "content") end
    if imgURL == "" then imgURL = imageURL end
    local desc = htmlToString(first(doc, { ".moreless.cont-text.showcont-h", ".cont-text.showcont-h", ".full-text", "#dle-content .text" }))

    local genres = {}
    local g = doc:select("a[href*='/genres/']")
    for i = 1, g:size() do local t = textOf(g:get(i - 1)); if t ~= "" then table.insert(genres, t) end end

    local authors = {}
    local an = doc:select("a[href*='/authors/']")
    if an:size() == 0 then an = doc:select("a[href*='/author/']") end
    for i = 1, an:size() do local t = textOf(an:get(i - 1)); if t ~= "" then table.insert(authors, t) end end

    local tags = {}
    local tn = doc:select("a[href*='/tags/']")
    for i = 1, tn:size() do local t = textOf(tn:get(i - 1)); if t ~= "" then table.insert(tags, t) end end

    local info = NovelInfo({
        title = title,
        alternativeTitles = { altTitle },
        link = shrinkURL(fullURL),
        imageURL = normalizeURL(imgURL),
        language = "rus",
        description = desc,
        status = mapStatus(findSpecValue(doc, { "Произведение", "Статус", "Перевод" })),
        tags = tags,
        genres = genres,
        authors = authors,
        viewCount = getNumberFromSpec(doc, { "Просмотров", "Просмотры" }),
        commentCount = getNumberFromSpec(doc, { "Комментариев", "Комментарии" })
    })

    if loadChapters then
        local chapters = {}
        local indexURL = findChapterIndexUrl(doc, fullURL)
        if indexURL:sub(-1) ~= "/" then indexURL = indexURL .. "/" end
        local firstDoc = safeFetch(indexURL, true)
        if firstDoc then
            local total = getLastPage(firstDoc)
            local pages = { firstDoc }
            for p = 2, total do
                waitBeforeRequest(false)
                local pd = safeFetch(indexURL .. "page/" .. p .. "/", true)
                if pd then pages[p] = pd end
            end
            for p = total, 1, -1 do
                if pages[p] then
                    local parsed = parseChapters(pages[p])
                    for i = 1, #parsed do table.insert(chapters, parsed[i]) end
                end
            end
        end
        info:setChapters(AsList(chapters))
    end
    return info
end

local function getPassage(chapterURL)
    local doc = safeFetch(chapterURL)
    local title = textOf(first(doc, { "#dle-speedbar span", "h1.title", "h1" }))
    local chapter = first(doc, { "#arrticle.text", "#article.text", "div.text", ".chapter-text", ".reader-area" })
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
        Listing("Ранобэ", true, function(data)
            local q = queryFromData(data)
            if q ~= "" then return search(data) end
            return parseListingURL(catalogURL(data))
        end),
        Listing("Главная", false, function() return parseListingURL(baseURL .. "/") end),
        Listing("Популярное", false, function() return parseListingURL(baseURL .. "/popular.html") end),
    },
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    getPassage = getPassage,
    parseNovel = parseNovel,
    search = search,
}
