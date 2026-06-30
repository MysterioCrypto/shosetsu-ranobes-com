-- {"id":962041,"ver":"1.0.2","libVer":"1.0.0","author":"MysterioCrypto","dep":[]}

local baseURL = "https://ranobes.com"
local imageURL = "https://github.com/bigrand/shosetsu-extensions/raw/master/icons/ranobes.png"

local consecutiveTriggers = 0

local function trim(s)
    if not s then return "" end
    return tostring(s):match("^%s*(.-)%s*$") or ""
end

local function startsWith(str, prefix)
    return str ~= nil and str:sub(1, #prefix) == prefix
end

local function normalizeURL(url)
    url = trim(url)
    if url == "" then return baseURL end
    url = url:gsub("^['\"]", ""):gsub("['\"]$", "")
    if url:find("^https?://") then return url end
    if url:sub(1, 2) == "//" then return "https:" .. url end
    if url:sub(1, 1) ~= "/" then url = "/" .. url end
    return baseURL .. url
end

local function shrinkURL(url)
    url = normalizeURL(url)
    if startsWith(url, baseURL) then
        return url:sub(#baseURL + 1)
    end
    return url
end

local function expandURL(url)
    return normalizeURL(url)
end

local function ensureTrailingSlash(url)
    url = trim(url)
    if url ~= "" and url:sub(-1) ~= "/" then return url .. "/" end
    return url
end

local function randomizedDelay(isSearch)
    local delayTime
    if isSearch then
        consecutiveTriggers = consecutiveTriggers + 1
        if consecutiveTriggers <= 2 then
            delayTime = math.random(1000, 2000)
        else
            delayTime = math.random(3000, 4500)
        end
    else
        delayTime = math.random(1800, 3500)
    end
    delay(delayTime)
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

local function nodesToList(nodes, fn)
    local result = {}
    if not nodes then return result end
    for i = 1, nodes:size() do
        local item = fn(nodes:get(i - 1), i)
        if item then table.insert(result, item) end
    end
    return result
end

local function concatLists(list1, list2)
    for i = 1, #list2 do table.insert(list1, list2[i]) end
    return list1
end

local function makeDebugNovel(title, details)
    local text = "DEBUG: " .. tostring(title or "unknown")
    if details and details ~= "" then text = text .. " — " .. tostring(details) end
    return {
        Novel({
            title = text,
            link = "/",
            imageURL = imageURL
        })
    }
end

local function htmlToString(text)
    text = tostring(text or "")
    text = text:gsub(">%s+<", "><")
    text = text:gsub("&nbsp;", " ")
    text = text:gsub(" ", " ")

    local brTag = "%s*<[Bb][Rr]%s*(/?)%s*>%s*"
    local paragraphBreak = brTag .. brTag .. "(" .. brTag .. ")*"
    text = text:gsub(paragraphBreak, "[[BRBR]]")
    text = text:gsub(brTag, "\n")
    text = text:gsub("</[Pp]>", "\n\n")
    text = text:gsub("<[^>]+>", "")
    text = text:gsub("%[%[BRBR%]%]", "\n\n")

    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, trim(line))
    end
    return trim(table.concat(lines, "\n"))
end

local function safeFetch(url, soft)
    local ok, document = pcall(GETDocument, expandURL(url))
    if not ok then
        local errMsg = tostring(document)
        local code = errMsg:match("(%d%d%d)")
        if soft then return false, code or "unknown", errMsg end
        if code == "429" then
            error("Rate limit reached. Try again later or open the source in WebView/browser.")
        else
            error("HTTP error: " .. (code or errMsg))
        end
    end

    local title = textOf(document:selectFirst("title"))
    local bodyText = textOf(document)

    if title == "Error"
        or title == "Ranobes Flood Guard"
        or title == "Just a moment..."
        or title:find("Антибот")
        or bodyText:find("Я не робот")
        or bodyText:find("подозрительную активность")
        or bodyText:find("Ranobes Flood Guard")
    then
        if soft then return false, "captcha", "CAPTCHA detected. title=" .. title end
        error("CAPTCHA detected. Use WebView to bypass. (or a Browser)")
    end

    return document
end

local function styleImageURL(node)
    if not node then return "" end
    local style = attrOf(node, "style")
    local url = style:match("url%(['\"]?(.-)['\"]?%)")
    return normalizeURL(url or "")
end

local function cardImage(card)
    local styleNode = first(card, { ".cover", "figure" })
    local imgFromStyle = styleImageURL(styleNode)
    if imgFromStyle ~= baseURL then return imgFromStyle end

    local img = first(card, { "img[data-src]", "img[src]" })
    local src = attrOf(img, "data-src")
    if src == "" then src = attrOf(img, "src") end
    if src ~= "" then return normalizeURL(src) end

    return imageURL
end

local function urlEncode(str)
    str = tostring(str or "")
    str = str:gsub("\n", " ")
    str = str:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end

local function buildFilterURL(data, isSearch)
    local page = 1
    if data and data[PAGE] then page = tonumber(data[PAGE]) or 1 end

    if isSearch then
        local queryContent = ""
        if data and data[QUERY] then queryContent = urlEncode(data[QUERY]) end
        return baseURL .. "/f/l.title=" .. queryContent .. "/sort=date/order=desc/page/" .. page
    end

    return baseURL .. "/f/sort=date/order=desc/page/" .. page
end

local function parseListingURL(url)
    randomizedDelay(true)
    local document, errType, errMsg = safeFetch(url, true)

    if not document then
        return makeDebugNovel("fetch failed", "url=" .. tostring(url) .. "; type=" .. tostring(errType) .. "; msg=" .. tostring(errMsg))
    end

    local cards = document:select("article.block.story.shortstory.mod-poster, article.shortstory, .shortstory, .rank-story")

    local novels = nodesToList(cards, function(card)
        local titleNode = first(card, {
            "h2 > a[href*='/ranobe/']",
            "h2 a[href*='/ranobe/']",
            ".title > a[href*='/ranobe/']",
            ".title a[href*='/ranobe/']",
            "a[href*='/ranobe/']"
        })

        local title = textOf(titleNode)
        local href = attrOf(titleNode, "href")
        if title == "" or href == "" then return nil end

        return Novel({
            title = title,
            link = shrinkURL(href),
            imageURL = cardImage(card)
        })
    end)

    if #novels > 0 then return novels end

    -- Fallback: parse any direct novel links. This is intentionally broad because Ranobes changes card markup.
    local anchors = document:select("a[href*='/ranobe/']")
    local seen = {}
    novels = nodesToList(anchors, function(a)
        local href = attrOf(a, "href")
        local title = textOf(a)
        if href == "" or title == "" or seen[href] then return nil end
        if title == "Читать" or title == "Закладка" then return nil end
        seen[href] = true
        return Novel({
            title = title,
            link = shrinkURL(href),
            imageURL = imageURL
        })
    end)

    if #novels > 0 then return novels end

    local pageTitle = textOf(document:selectFirst("title"))
    return makeDebugNovel("no novels parsed", "url=" .. tostring(url) .. "; title=" .. pageTitle)
end

local function search(data)
    return parseListingURL(buildFilterURL(data, true))
end

local function mapStatus(status)
    status = trim(status)
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
    })[status] or NovelStatus.UNKNOWN
end

local function extractNumber(text)
    text = tostring(text or ""):gsub("%s+", "")
    local number = text:match("(%d+)")
    return number and tonumber(number) or nil
end

local function findSpecValue(document, labels)
    local nodes = document:select("div.r-fullstory-spec li, .r-fullstory-spec li")
    for i = 1, nodes:size() do
        local li = nodes:get(i - 1)
        local text = textOf(li)
        for _, label in ipairs(labels) do
            if text:find(label) then
                local value = textOf(first(li, { "span a", "span" }))
                if value ~= "" then return value end
                return trim(text:gsub(label .. "%s*: ?", ""))
            end
        end
    end
    return ""
end

local function getChapterCount(document)
    local nodes = document:select("div.r-fullstory-spec li, .r-fullstory-spec li")
    local fallback = nil

    for i = 1, nodes:size() do
        local text = textOf(nodes:get(i - 1))
        if text:find("Переведено") or text:find("Выложено") then
            return extractNumber(text) or 0
        end
        if text:find("Всего написано") or text:find("Глав") or text:find("глав") then
            fallback = extractNumber(text) or fallback
        end
    end

    return fallback or 0
end

local function getNumberFromSpec(document, labels)
    local value = findSpecValue(document, labels)
    return extractNumber(value) or 0
end

local function findChapterIndexUrl(document, novelURL)
    local links = document:select("a[href*='/chapters/']")
    for i = 1, links:size() do
        local href = attrOf(links:get(i - 1), "href")
        if href:find("/chapters/") and not href:find("%.html") then
            return normalizeURL(href)
        end
    end

    local short = shrinkURL(novelURL)
    local slug = short:match("/ranobe/%d+%-([^/%.]+)%.html")
    if slug and slug ~= "" then
        return baseURL .. "/chapters/" .. slug .. "/"
    end

    error("Chapter index URL not found.")
end

local function getLastPage(indexDocument)
    local maxPage = 1
    local links = indexDocument:select("a[href*='/page/']")
    for i = 1, links:size() do
        local href = attrOf(links:get(i - 1), "href")
        local page = tonumber(href:match("/page/(%d+)/?"))
        if page and page > maxPage then maxPage = page end
    end
    return maxPage
end

local function chapterOrder(title, href, fallback)
    local n = title:match("[Гг]лава%s*([%d%.]+)")
        or title:match("[Чч]асть%s*([%d%.]+)")
        or title:match("[Cc]hapter%s*([%d%.]+)")
        or href:match("/(%d+)%-")
    return tonumber(n) or fallback
end

local function parseChapters(indexDocument)
    local anchors = indexDocument:select("a[href*='/chapters/']")
    local chapters = {}
    local seen = {}

    for i = anchors:size(), 1, -1 do
        local a = anchors:get(i - 1)
        local href = attrOf(a, "href")
        local title = textOf(a)

        if href:find("/chapters/") and href:find("%.html") and title ~= "" and not seen[href] then
            seen[href] = true
            local link = shrinkURL(href)
            table.insert(chapters, NovelChapter {
                order = chapterOrder(title, href, #chapters + 1),
                title = title,
                link = link
            })
        end
    end

    return chapters
end

local function parseNovel(novelURL, loadChapters)
    local fullURL = expandURL(novelURL)
    local document = safeFetch(fullURL)

    local titleNode = first(document, { 'meta[property="og:title"]', "h1.title" })
    local title = attrOf(titleNode, "content")
    if title == "" then title = textOf(titleNode) end

    local altTitle = textOf(first(document, { "h1.title > span.subtitle", ".subtitle" }))

    local imgURL = attrOf(first(document, { "a.highslide", 'meta[property="og:image"]' }), "href")
    if imgURL == "" then imgURL = attrOf(first(document, { 'meta[property="og:image"]' }), "content") end
    if imgURL == "" then imgURL = imageURL end
    imgURL = normalizeURL(imgURL)

    local descriptionNode = first(document, {
        ".moreless.cont-text.showcont-h",
        ".cont-text.showcont-h",
        ".full-text",
        "#dle-content .text"
    })
    local description = htmlToString(descriptionNode)

    local status = findSpecValue(document, { "Произведение", "Статус", "Перевод" })

    local genres = nodesToList(document:select("#mc-fs-genre div.links a, #mc-fs-genre a, a[href*='/genres/']"), function(v)
        local t = textOf(v)
        if t == "" then return nil end
        return t
    end)

    local authors = nodesToList(document:select(".tag_list a, a[href*='/authors/'], a[href*='/author/']"), function(v)
        local t = textOf(v)
        if t == "" then return nil end
        return t
    end)

    local tags = nodesToList(document:select(".cont-in .cont-text.showcont-h a, .tags a, a[href*='/tags/']"), function(v)
        local t = textOf(v)
        if t == "" then return nil end
        return t
    end)

    local viewCount = getNumberFromSpec(document, { "Просмотров", "Просмотры" })
    local commentCount = getNumberFromSpec(document, { "Комментариев", "Комментарии" })
    local chapterIndexUrl = ensureTrailingSlash(findChapterIndexUrl(document, fullURL))

    local info = NovelInfo {
        title = title,
        alternativeTitles = { altTitle },
        link = shrinkURL(fullURL),
        imageURL = imgURL,
        language = "rus",
        description = description,
        status = mapStatus(status),
        tags = tags,
        genres = genres,
        authors = authors,
        viewCount = viewCount,
        commentCount = commentCount
    }

    if loadChapters then
        local chapters = {}
        local firstIndexDocument, errType, errMsg = safeFetch(chapterIndexUrl, true)

        if firstIndexDocument then
            local totalPages = getLastPage(firstIndexDocument)
            local pages = { firstIndexDocument }

            for page = 2, totalPages do
                randomizedDelay(false)
                local pageURL = ensureTrailingSlash(chapterIndexUrl) .. "page/" .. page .. "/"
                local pageDocument = safeFetch(pageURL, true)
                if pageDocument then pages[page] = pageDocument end
            end

            for page = totalPages, 1, -1 do
                if pages[page] then
                    chapters = concatLists(chapters, parseChapters(pages[page]))
                end
            end
        else
            chapters = {}
        end

        info:setChapters(AsList(chapters))
    end

    return info
end

local function getPassage(chapterURL)
    local document = safeFetch(chapterURL)

    local title = textOf(first(document, { "#dle-speedbar > span", "h1.title", "h1" }))
    local chapter = first(document, { "#arrticle.text", "#article.text", "div.text", ".chapter-text", ".reader-area" })

    if not chapter then
        error("Chapter text not found.")
    end

    if title ~= "" then
        chapter:prepend("# " .. title .. "\n\n")
    end

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
        Listing("Главная", false, function()
            return parseListingURL(baseURL .. "/")
        end),
        Listing("Новое", true, function(data)
            return parseListingURL(buildFilterURL(data, false))
        end),
        Listing("Популярное", false, function()
            return parseListingURL(baseURL .. "/popular.html")
        end),
    },

    shrinkURL = shrinkURL,
    expandURL = expandURL,
    getPassage = getPassage,
    parseNovel = parseNovel,
    search = search,
}
