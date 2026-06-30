-- {"id":962041,"ver":"1.0.13","libVer":"1.0.0","author":"MysterioCrypto","dep":[]}
local baseURL="https://ranobes.com"
local imageURL="https://github.com/bigrand/shosetsu-extensions/raw/master/icons/ranobes.png"
local MAX_CHAPTER_PAGES=8

local function trim(s) if not s then return "" end return tostring(s):match("^%s*(.-)%s*$") or "" end
local function textOf(n) if not n then return "" end return trim(n:text()) end
local function attrOf(n,a) if not n then return "" end return trim(n:attr(a)) end
local function first(root, selectors) if not root then return nil end for _,s in ipairs(selectors) do local n=root:selectFirst(s); if n then return n end end return nil end
local function normalizeURL(u) u=trim(u); if u=="" then return baseURL end; u=u:gsub("&amp;","&"):gsub("&#58;",":"):gsub("^['\"]",""):gsub("['\"]$",""); if u:find("^https?://") then return u end; if u:sub(1,2)=="//" then return "https:"..u end; if u:sub(1,1)~="/" then u="/"..u end; return baseURL..u end
local function shrinkURL(u) u=normalizeURL(u); if u:sub(1,#baseURL)==baseURL then return u:sub(#baseURL+1) end return u end
local function expandURL(u) return normalizeURL(u) end
local function pageFromData(data) if data and PAGE and data[PAGE] then return tonumber(data[PAGE]) or 1 end; return 1 end
local function waitReq(search) if search then delay(math.random(900,1800)) else delay(math.random(1300,2800)) end end
local function safeFetch(u,soft) local ok,doc=pcall(GETDocument,expandURL(u)); if not ok then if soft then return nil end error(tostring(doc)) end; local title=textOf(doc:selectFirst("title")); local body=textOf(doc); if title=="Error" or title=="Ranobes Flood Guard" or title=="Just a moment..." or title:find("Антибот") or body:find("Ranobes Flood Guard") or body:find("подозрительную активность") then if soft then return nil end error("Site verification page") end; return doc end
local function isNovelHref(h) h=shrinkURL(h); return h~="/ranobe" and h~="/ranobe/" and h:find("^/ranobe/%d+%-")~=nil and h:find("%.html")~=nil end
local function cleanTitle(t) t=trim(t):gsub("&quot;","\""); t=t:gsub("%s+Более%s+[%d%s]+%s+просмотров.*$",""); t=t:gsub("%s+Китайский;.*$",""):gsub("%s+Корейский;.*$",""):gsub("%s+Японский;.*$",""):gsub("%s+Английский;.*$",""):gsub("%s+Русский;.*$",""); return trim(t) end
local function imageFromStyle(st) local u=trim(st):match("url%((.-)%)"); if not u or u=="" then return "" end; u=trim(u):gsub("^['\"]",""):gsub("['\"]$",""); if u=="" then return "" end; return normalizeURL(u) end
local function cardImage(c) local fig=first(c,{"figure.cover",".cover","figure"}); local u=imageFromStyle(attrOf(fig,"style")); if u~="" then return u end; local img=first(c,{"img"}); local src=attrOf(img,"data-src"); if src=="" then src=attrOf(img,"src") end; if src~="" then return normalizeURL(src) end; return imageURL end
local function titleLink(c) local a=first(c,{"h2.title a",".title a","h2 a","h3 a"}); if a and isNovelHref(attrOf(a,"href")) and textOf(a)~="" then return a end; local links=c:select("a"); for i=1,links:size() do local l=links:get(i-1); if isNovelHref(attrOf(l,"href")) and textOf(l)~="" then return l end end return nil end
local function addNovel(out,seen,title,href,img) title=cleanTitle(title); if title=="" or title=="Читать" or title=="Закладка" or title=="Ранобэ" or title=="Ранобэс" then return end; if not isNovelHref(href) then return end; local link=shrinkURL(href); if seen[link] then return end; seen[link]=true; table.insert(out,Novel({title=title,link=link,imageURL=img or imageURL})) end
local function parseCards(root) local out,seen={},{}; if not root then return out end; local cards=root:select("article"); if cards:size()==0 then cards=root:select(".shortstory") end; if cards:size()==0 then cards=root:select(".story") end; for i=1,cards:size() do local c=cards:get(i-1); local a=titleLink(c); addNovel(out,seen,textOf(a),attrOf(a,"href"),cardImage(c)) end; return out end
local function parseRanking(u) waitReq(false); local doc=safeFetch(u,true); if not doc then return {} end; local root=doc:selectFirst("#dle-content") or doc:selectFirst("main") or doc; local cards=root:select(".rank-story"); if cards:size()==0 then return parseCards(root) end; local out,seen={},{}; for i=1,cards:size() do local c=cards:get(i-1); local a=titleLink(c); addNovel(out,seen,textOf(a),attrOf(a,"href"),cardImage(c)) end; return out end
local function catalogURL(data) local p=pageFromData(data); if p<=1 then return baseURL.."/ranobe/" end; return baseURL.."/ranobe/page/"..p.."/" end
local function parseListingURL(u) waitReq(false); local doc=safeFetch(u,true); if not doc then return {} end; local root=doc:selectFirst("#dle-content") or doc:selectFirst("main") or doc; return parseCards(root) end
local function search(data) return {} end

local function cleanChapterTitle(t) t=trim(t):gsub("&quot;","\""); t=t:gsub("%s+%d%d?%s+%S+%s+20%d%d.*$",""); t=t:gsub("%s+%d%d?%.%d%d%.20%d%d.*$",""); return trim(t) end
local function htmlToString(n) if not n then return "" end; local h=tostring(n):gsub(">%s+<","><"):gsub("&nbsp;"," "):gsub(" "," "); h=h:gsub("%s*<[Bb][Rr]%s*/?%s*>%s*","\n"):gsub("</[Pp]>","\n\n"):gsub("<[^>]+>",""); local lines={}; for line in (h.."\n"):gmatch("(.-)\n") do table.insert(lines,trim(line)) end; return trim(table.concat(lines,"\n")) end
local function mapStatus(s) s=trim(s); return ({["Активен"]=NovelStatus.PUBLISHING,["Активно"]=NovelStatus.PUBLISHING,["В процессе"]=NovelStatus.PUBLISHING,["Продолжается"]=NovelStatus.PUBLISHING,["Онгоинг"]=NovelStatus.PUBLISHING,["Ongoing"]=NovelStatus.PUBLISHING,["Active"]=NovelStatus.PUBLISHING,["Завершено"]=NovelStatus.COMPLETED,["Завершён"]=NovelStatus.COMPLETED,["Завершена"]=NovelStatus.COMPLETED,["Закончен"]=NovelStatus.COMPLETED,["Закончено"]=NovelStatus.COMPLETED,["Completed"]=NovelStatus.COMPLETED,["Приостановлено"]=NovelStatus.PAUSED,["Заморожено"]=NovelStatus.PAUSED,["Пауза"]=NovelStatus.PAUSED,["Break"]=NovelStatus.PAUSED,["Hiatus"]=NovelStatus.PAUSED})[s] or NovelStatus.UNKNOWN end
local function extractNumber(t) local n=tostring(t or ""):gsub("%s+",""):match("(%d+)"); return n and tonumber(n) or nil end
local function findSpecValue(doc,labels) local nodes=doc:select(".r-fullstory-spec li"); for i=1,nodes:size() do local li=nodes:get(i-1); local txt=textOf(li); for _,lab in ipairs(labels) do if txt:find(lab) then local v=textOf(first(li,{"span a","span"})); if v~="" then return v end; return trim(txt:gsub(lab.."%s*: ?","")) end end end; return "" end
local function getNumberFromSpec(doc,labels) return extractNumber(findSpecValue(doc,labels)) or 0 end
local function collectLinks(root,selectors) local res,seen={},{}; if not root then return res end; for _,s in ipairs(selectors) do local nodes=root:select(s); for i=1,nodes:size() do local t=textOf(nodes:get(i-1)); if t~="" and not seen[t] then seen[t]=true; table.insert(res,t) end end end; return res end
local function findChapterIndexUrl(doc,novelURL) local links=doc:select("a"); for i=1,links:size() do local href=attrOf(links:get(i-1),"href"); if href:find("/chapters/") and not href:find("%.html") then return normalizeURL(href) end end; local slug=shrinkURL(novelURL):match("/ranobe/%d+%-([^/%.]+)%.html"); if slug and slug~="" then return baseURL.."/chapters/"..slug.."/" end; error("Chapter index URL not found.") end
local function getLastPage(doc) local max=1; local links=doc:select("a"); for i=1,links:size() do local p=tonumber(attrOf(links:get(i-1),"href"):match("/page/(%d+)/?")); if p and p>max then max=p end end; return max end
local function chapterOrder(title,href,fallback) local n=title:match("[Гг]лава%s*([%d%.]+)") or title:match("[Чч]асть%s*([%d%.]+)") or title:match("[Cc]hapter%s*([%d%.]+)") or href:match("/(%d+)%-"); return tonumber(n) or fallback end
local function parseChapters(doc) local root=doc:selectFirst("#dle-content") or doc; local links=root:select("a"); local out,seen={},{}; for i=links:size(),1,-1 do local a=links:get(i-1); local href=attrOf(a,"href"); local title=cleanChapterTitle(textOf(a)); if href:find("/chapters/") and href:find("%.html") and title~="" and not seen[href] then seen[href]=true; table.insert(out,NovelChapter({order=chapterOrder(title,href,#out+1),title=title,link=shrinkURL(href)})) end end; return out end

local function parseNovel(novelURL,loadChapters)
    local fullURL=expandURL(novelURL); local doc=safeFetch(fullURL)
    local titleNode=first(doc,{ 'meta[property="og:title"]',"h1.title","h1" }); local title=attrOf(titleNode,"content"); if title=="" then title=textOf(titleNode) end
    local altTitle=textOf(first(doc,{"h1.title span.subtitle",".subtitle"}))
    local imgURL=attrOf(first(doc,{"a.highslide",'meta[property="og:image"]'}),"href"); if imgURL=="" then imgURL=attrOf(first(doc,{ 'meta[property="og:image"]' }),"content") end; if imgURL=="" then imgURL=imageURL end
    local desc=htmlToString(first(doc,{".moreless.cont-text.showcont-h",".cont-text.showcont-h",".full-text","#dle-content .text"}))
    local genres=collectLinks(doc,{"#mc-fs-genre div.links a","#mc-fs-genre a","a[href*='/genres/']","a[href*='/genre/']"})
    local authors=collectLinks(doc,{".tag_list a","a[href*='/authors/']","a[href*='/author/']"})
    local tags=collectLinks(doc,{"#mc-fs-tags a",".tags a","a[href*='/tags/']","a[href*='/tag/']",".cont-in .cont-text.showcont-h a"})
    local info=NovelInfo({title=title,alternativeTitles={altTitle},link=shrinkURL(fullURL),imageURL=normalizeURL(imgURL),language="rus",description=desc,status=mapStatus(findSpecValue(doc,{"Произведение","Статус","Перевод"})),tags=tags,genres=genres,authors=authors,viewCount=getNumberFromSpec(doc,{"Просмотров","Просмотры"}),commentCount=getNumberFromSpec(doc,{"Комментариев","Комментарии"})})
    if loadChapters then
        local chapters={}; local indexURL=findChapterIndexUrl(doc,fullURL); if indexURL:sub(-1)~="/" then indexURL=indexURL.."/" end
        local firstDoc=safeFetch(indexURL,true)
        if firstDoc then
            local total=getLastPage(firstDoc); local fromPage=1; local pages={}
            if total<=MAX_CHAPTER_PAGES then pages[1]=firstDoc else fromPage=total-MAX_CHAPTER_PAGES+1 end
            for p=fromPage,total do if not pages[p] then waitReq(false); local pd=safeFetch(indexURL.."page/"..p.."/",true); if pd then pages[p]=pd end end end
            for p=total,fromPage,-1 do if pages[p] then local parsed=parseChapters(pages[p]); for i=1,#parsed do table.insert(chapters,parsed[i]) end end end
        end
        info:setChapters(AsList(chapters))
    end
    return info
end

local function getPassage(chapterURL) local doc=safeFetch(chapterURL); local title=textOf(first(doc,{"#dle-speedbar span","h1.title","h1"})); local chapter=first(doc,{"#arrticle.text","#article.text","div.text",".chapter-text",".reader-area"}); if not chapter then error("Chapter text not found.") end; if title~="" then chapter:prepend("# "..title.."\n\n") end; return pageOfElem(chapter,false) end
return {id=962041,name="Ranobes.com RU",baseURL=baseURL,imageURL=imageURL,hasCloudFlare=true,hasSearch=false,chapterType=ChapterType.HTML,listings={Listing("Ранобэ",true,function(data) return parseListingURL(catalogURL(data)) end),Listing("Популярное",false,function() return parseRanking(baseURL.."/ranking/") end)},shrinkURL=shrinkURL,expandURL=expandURL,getPassage=getPassage,parseNovel=parseNovel,search=search}
