# Ranobes.com RU for Shosetsu

Пользовательский репозиторий Shosetsu с источником `https://ranobes.com`.

## URL для Shosetsu

После загрузки этих файлов в GitHub-репозиторий `MysterioCrypto/shosetsu-ranobes-com` на ветку `main` добавь в Shosetsu:

```text
https://raw.githubusercontent.com/MysterioCrypto/shosetsu-ranobes-com/main/
```

Проверка индекса в браузере:

```text
https://raw.githubusercontent.com/MysterioCrypto/shosetsu-ranobes-com/main/index.json
```

## Структура

```text
index.json
src/rus/RanobesCom.lua
```

## Ограничения

`ranobes.com` использует антибот. Если источник отдаёт CAPTCHA, Shosetsu должен открыть WebView/браузер для ручного прохождения проверки. После прохождения сайт обычно работает до истечения cookie/session.

Первичная версия использует CSS-селекторы, совместимые с DLE/Ranobes-разметкой:

- карточки: `article.block.story.shortstory.mod-poster`, `.shortstory`, `.rank-story`;
- произведение: `meta[property="og:title"]`, `h1.title`, `.r-fullstory-spec`, `.moreless.cont-text.showcont-h`;
- оглавление: ссылки `/chapters/.../`;
- главы: ссылки `/chapters/.../*.html`;
- текст главы: `#arrticle.text`, `#article.text`, `div.text`.
