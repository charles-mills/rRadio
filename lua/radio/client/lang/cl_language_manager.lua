/*
Adding a new Language?

1) Add your language code to the languages table below. The key should be the language code (e.g., "fr" for French), and the value should be the display name of the language (e.g., "Français").
2) Create a new Lua file in the 'radio/client/lang/' directory with the name of your language code (e.g., 'fr.lua' for French).
3) Add translations for each key in the 'radio/client/lang/en.lua' file to your new language file.
4) Complete country translations by accessing country_translations.lua and adding translations for each country name (optional).
4) Submit a pull request and your language will be added to the official addon :)
*/

local LanguageManager = {}

LanguageManager.languages = {
    de = "Deutsch",
    en = "English",
    es = "Español",
    fr = "Français",
    it = "Italiano",
    ja = "日本語",
    ko = "한국어",
    pt_br = "Português (Brasil)",
    ru = "Русский",
    zh_cn = "简体中文",
    tr = "Türkçe",
}

-- Merge translations directly into the language manager
LanguageManager.translations = {
    de = {
        ["SelectCountry"] = "Land auswählen",
        ["StopRadio"] = "STOP",
        ["SearchPlaceholder"] = "Suche...",
        ["PressKeyToOpen"] = "Drücken Sie {key}, um eine Station auszuwählen",
        ["NoStations"] = "Warnung: Keine Stationen gefunden für {country}",
        ["Interact"] = "Drücken Sie E zur Interaktion",
        ["PAUSED"] = "PAUSIERT",
        ["Settings"] = "Einstellungen",
        ["LanguageSelection"] = "Sprachauswahl",
        ["ThemeSelection"] = "Themenauswahl",
        ["SelectTheme"] = "Thema auswählen",
        ["SelectLanguage"] = "Sprache auswählen",
        ["SelectKey"] = "Taste für Auto-Radio-Menü wählen",
        ["GeneralOptions"] = "Allgemeine Optionen",
        ["ShowCarMessages"] = "Animation beim Einsteigen im Fahrzeug anzeigen",
        ["ShowBoomboxHUD"] = "Tragbares-Radio-Bildschirmanzeige anzeigen",
        ["Contribute"] = "Möchten Sie mitwirken?",
        ["SubmitPullRequest"] = "Einen Änderungsvorschlag einreichen :)",
        ["SuperadminSettings"] = "Hauptadministrator-Einstellungen",
        ["MakeBoomboxPermanent"] = "Tragbares Radio als permanent markieren",
        ["Enabled"] = "Aktiviert",
        ["Disabled"] = "Deaktiviert"
    },
    en = {
        ["SelectCountry"] = "Select a Country",
        ["StopRadio"] = "STOP",
        ["SearchPlaceholder"] = "Search...",
        ["PressKeyToOpen"] = "Press {key} to pick a station",
        ["NoStations"] = "Warning: No stations found for {country}",
        ["Interact"] = "Press E to Interact",
        ["PAUSED"] = "PAUSED",
        ["Settings"] = "Settings",
        ["LanguageSelection"] = "Language Selection",
        ["ThemeSelection"] = "Theme Selection",
        ["SelectTheme"] = "Select Theme",
        ["SelectLanguage"] = "Select Language",
        ["SelectKey"] = "Select Key to Open Car Radio Menu",
        ["GeneralOptions"] = "General Options",
        ["ShowCarMessages"] = "Show Animation When Entering Vehicle",
        ["ShowBoomboxHUD"] = "Show the Boombox HUD",
        ["Contribute"] = "Want to contribute?",
        ["SubmitPullRequest"] = "Submit a Pull Request :)",
        ["SuperadminSettings"] = "Superadmin Settings",
        ["MakeBoomboxPermanent"] = "Make Boombox Permanent",
        ["Enabled"] = "Enabled",
        ["Disabled"] = "Disabled"
    },
    es = {
        ["SelectCountry"] = "Seleccionar país",
        ["StopRadio"] = "PARAR",
        ["SearchPlaceholder"] = "Buscar...",
        ["PressKeyToOpen"] = "Presione {key} para elegir una estación",
        ["NoStations"] = "Advertencia: No se encontraron estaciones para {country}",
        ["Interact"] = "Presiona E para interactuar",
        ["PAUSED"] = "PAUSADO",
        ["Settings"] = "Ajustes",
        ["LanguageSelection"] = "Selección de idioma",
        ["ThemeSelection"] = "Selección de tema",
        ["SelectTheme"] = "Seleccionar tema",
        ["SelectLanguage"] = "Seleccionar idioma",
        ["SelectKey"] = "Selecciona la tecla para abrir el menú de radio del auto",
        ["GeneralOptions"] = "Opciones generales",
        ["ShowCarMessages"] = "Mostrar animación al entrar en el vehículo",
        ["ShowBoomboxHUD"] = "Mostrar la interfaz del radio portátil",
        ["Contribute"] = "¿Quieres contribuir?",
        ["SubmitPullRequest"] = "Enviar una solicitud de cambios :)",
        ["SuperadminSettings"] = "Configuraciones de Administrador Principal",
        ["MakeBoomboxPermanent"] = "Marcar radio portátil como permanente",
        ["Enabled"] = "Activado",
        ["Disabled"] = "Desactivado"
    },
    fr = {
        ["SelectCountry"] = "Sélectionnez un pays",
        ["StopRadio"] = "ARRÊT",
        ["SearchPlaceholder"] = "Recherche...",
        ["PressKeyToOpen"] = "Appuyez sur {key} pour choisir une station",
        ["NoStations"] = "Attention : Aucune station trouvée pour {country}",
        ["Interact"] = "Appuyez sur E pour interagir",
        ["PAUSED"] = "EN PAUSE",
        ["Settings"] = "Paramètres",
        ["LanguageSelection"] = "Sélection de la langue",
        ["ThemeSelection"] = "Sélection du thème",
        ["SelectTheme"] = "Sélectionner un thème",
        ["SelectLanguage"] = "Sélectionner une langue",
        ["SelectKey"] = "Sélectionner la touche pour ouvrir le menu de radio du véhicule",
        ["GeneralOptions"] = "Options générales",
        ["ShowCarMessages"] = "Afficher l'animation lors de l'entrée dans le véhicule",
        ["ShowBoomboxHUD"] = "Afficher l'interface de la radio portable",
        ["Contribute"] = "Voulez-vous contribuer?",
        ["SubmitPullRequest"] = "Envoyez une demande de fusion :)",
        ["SuperadminSettings"] = "Paramètres d'Administrateur Principal",
        ["MakeBoomboxPermanent"] = "Marquer la radio portable comme permanente",
        ["Enabled"] = "Activé",
        ["Disabled"] = "Désactivé"
    },
    it = {
        ["SelectCountry"] = "Seleziona paese",
        ["StopRadio"] = "FERMARE",
        ["SearchPlaceholder"] = "Cerca...",
        ["PressKeyToOpen"] = "Premi {key} per scegliere una stazione",
        ["NoStations"] = "Avviso: Nessuna stazione trovata per {country}",
        ["Interact"] = "Premi E per interagire",
        ["PAUSED"] = "IN PAUSA",
        ["Settings"] = "Impostazioni",
        ["LanguageSelection"] = "Selezione della lingua",
        ["ThemeSelection"] = "Selezione del tema",
        ["SelectTheme"] = "Seleziona tema",
        ["SelectLanguage"] = "Seleziona lingua",
        ["SelectKey"] = "Tasto per aprire menu radio auto",
        ["GeneralOptions"] = "Opzioni generali",
        ["ShowCarMessages"] = "Mostra animazione all'entrata nel veicolo",
        ["ShowBoomboxHUD"] = "Mostra l'interfaccia della radio portatile",
        ["Contribute"] = "Vuoi contribuire?",
        ["SubmitPullRequest"] = "Invia una richiesta di unione :)",
        ["SuperadminSettings"] = "Configurazioni dell'Amministratore Principale",
        ["MakeBoomboxPermanent"] = "Rendi la radio portatile permanente",
        ["Enabled"] = "Attivo",
        ["Disabled"] = "Disattivato"
    },
    ja = {
        ["SelectCountry"] = "国を選択",
        ["StopRadio"] = "停止",
        ["SearchPlaceholder"] = "検索...",
        ["PressKeyToOpen"] = "{key}を押して局を選択",
        ["NoStations"] = "警告: {country}の局が見つかりません",
        ["Interact"] = "私とやり取りして！",
        ["PAUSED"] = "一時停止",
        ["Settings"] = "設定",
        ["LanguageSelection"] = "言語選択",
        ["ThemeSelection"] = "テーマ選択",
        ["SelectTheme"] = "テーマを選択",
        ["SelectLanguage"] = "言語を選択",
        ["SelectKey"] = "車内ラジオメニューのキーを選択",
        ["GeneralOptions"] = "一般オプション",
        ["ShowCarMessages"] = "車内に入るとアニメーションを表示",
        ["ShowBoomboxHUD"] = "ポータブルラジオの画面表示を表示",
        ["Contribute"] = "貢献したいですか？",
        ["SubmitPullRequest"] = "変更リクエストを送信 :)",
        ["SuperadminSettings"] = "最高管理者の設定",
        ["MakeBoomboxPermanent"] = "ポータブルラジオを永久にする",
        ["Enabled"] = "有効",
        ["Disabled"] = "無効"
    },
    ko = {
        ["SelectCountry"] = "국가 선택",
        ["StopRadio"] = "정지",
        ["SearchPlaceholder"] = "검색...",
        ["PressKeyToOpen"] = "{key}을 눌러 방송국을 선택하십시오",
        ["NoStations"] = "경고: {country}에 대한 송국을 찾을 수 없습니다",
        ["Interact"] = "나와 상호작용하세요!",
        ["PAUSED"] = "일시정지",
        ["Settings"] = "설정",
        ["LanguageSelection"] = "언어 선택",
        ["ThemeSelection"] = "테마 선택",
        ["SelectTheme"] = "테마 선택",
        ["SelectLanguage"] = "언어 선택",
        ["SelectKey"] = "차량 라디오 메뉴 키 선택",
        ["GeneralOptions"] = "일반 옵션",
        ["ShowCarMessages"] = "차량 진입 시 애니메이션 표시",
        ["ShowBoomboxHUD"] = "휴대용 라디오의 화면 표시",
        ["Contribute"] = "기여하고 싶습니까?",
        ["SubmitPullRequest"] = "변경 요청을 제출 :)",
        ["SuperadminSettings"] = "최고 관리자 설정",
        ["MakeBoomboxPermanent"] = "휴대용 라디오를 영구적으로 만들기",
        ["Enabled"] = "활성화",
        ["Disabled"] = "비활성화"
    },
    pt_br = {
        ["SelectCountry"] = "Selecionar país",
        ["StopRadio"] = "PARAR",
        ["SearchPlaceholder"] = "Buscar...",
        ["PressKeyToOpen"] = "Pressione {key} para escolher uma estação",
        ["NoStations"] = "Aviso: Nenhuma estação encontrada para {country}",
        ["Interact"] = "Pressione E para interagir",
        ["PAUSED"] = "PAUSADO",
        ["Settings"] = "Configurações",
        ["LanguageSelection"] = "Seleção de idioma",
        ["ThemeSelection"] = "Seleção de tema",
        ["SelectTheme"] = "Selecionar tema",
        ["SelectLanguage"] = "Selecionar idioma",
        ["SelectKey"] = "Tecla para abrir menu de rádio",
        ["GeneralOptions"] = "Opções gerais",
        ["ShowCarMessages"] = "Mostrar animação ao entrar no veículo",
        ["ShowBoomboxHUD"] = "Mostrar a interface do rádio portátil",
        ["Contribute"] = "Quer contribuir?",
        ["SubmitPullRequest"] = "Enviar uma solicitação de mudança :)",
        ["SuperadminSettings"] = "Configurações de Administrador Principal",
        ["MakeBoomboxPermanent"] = "Marcar rádio portátil como permanente",
        ["Enabled"] = "Ativado",
        ["Disabled"] = "Desativado"
    },
    ru = {
        ["SelectCountry"] = "Выберите страну",
        ["StopRadio"] = "СТОП",
        ["SearchPlaceholder"] = "Поиск...",
        ["PressKeyToOpen"] = "Нажмите {key}, чтобы выбрать станцию",
        ["NoStations"] = "Предупреждение: Станции не найдены для {country}",
        ["Interact"] = "Взаимодействуй со мной!",
        ["PAUSED"] = "ПАУЗА",
        ["Settings"] = "Настройки",
        ["LanguageSelection"] = "Выбор языка",
        ["ThemeSelection"] = "Выбор темы",
        ["SelectTheme"] = "Выберите тему",
        ["SelectLanguage"] = "Выберите язык",
        ["SelectKey"] = "Клавиша для меню радио в машине",
        ["GeneralOptions"] = "Общие параметры",
        ["ShowCarMessages"] = "Показывать анимацию при входе в машину",
        ["ShowBoomboxHUD"] = "Показывать интерфейс портативного радио",
        ["Contribute"] = "Хотите внести свой вклад?",
        ["SubmitPullRequest"] = "Отправить запрос на внесение изменений :)",
        ["SuperadminSettings"] = "Настройки Главного Администратора",
        ["MakeBoomboxPermanent"] = "Сделать портативное радио постоянным",
        ["Enabled"] = "Включено",
        ["Disabled"] = "Выключено"
    },
    tr = {
        ["SelectCountry"] = "Ülke seç",
        ["StopRadio"] = "DURDUR",
        ["SearchPlaceholder"] = "Ara...",
        ["PressKeyToOpen"] = "Radyo kanalı seçmek için {key} tuşuna bas",
        ["NoStations"] = "Uyarı: {country} kanalı bulunamadı.",
        ["Interact"] = "Benimle Etkileşimde Bulun!",
        ["PAUSED"] = "DURAKLATILDI",
        ["Settings"] = "Ayarlar",
        ["LanguageSelection"] = "Dil Seçimi",
        ["ThemeSelection"] = "Tema Seçimi",
        ["SelectTheme"] = "Tema Seç",
        ["SelectLanguage"] = "Dil Seç",
        ["SelectKey"] = "Araç radyo menüsü tuşunu seç",
        ["GeneralOptions"] = "Genel Seçenekler",
        ["ShowCarMessages"] = "Araçta giriş yapıldığında animasyon göster",
        ["ShowBoomboxHUD"] = "Taşınabilir radyo arayüzünü göster",
        ["Contribute"] = "Katkıda bulunmak ister misiniz?",
        ["SubmitPullRequest"] = "Değişiklik isteği gönder :)",
        ["SuperadminSettings"] = "Baş Yönetici ayarları",
        ["MakeBoomboxPermanent"] = "Taşınabilir radyoyu sabit yap",
        ["Enabled"] = "Aktif",
        ["Disabled"] = "Pasif"
    },
    zh_cn = {
        ["SelectCountry"] = "选择国家",
        ["StopRadio"] = "停止",
        ["SearchPlaceholder"] = "搜索...",
        ["PressKeyToOpen"] = "按 {key} 选择电台",
        ["NoStations"] = "警告: 未找到 {country} 的电台",
        ["Interact"] = "与我互动！",
        ["PAUSED"] = "暂停",
        ["Settings"] = "设置",
        ["LanguageSelection"] = "语言选择",
        ["ThemeSelection"] = "主题选择",
        ["SelectTheme"] = "选择主题",
        ["SelectLanguage"] = "选择语言",
        ["SelectKey"] = "选择车载电台菜单按键",
        ["GeneralOptions"] = "常规选项",
        ["ShowCarMessages"] = "进入车内时显示动画",
        ["ShowBoomboxHUD"] = "显示便携式收音机界面",
        ["Contribute"] = "想要贡献吗？",
        ["SubmitPullRequest"] = "提交合并请求 :)",
        ["SuperadminSettings"] = "超级管理员设置",
        ["MakeBoomboxPermanent"] = "将便携式收音机设为永久",
        ["Enabled"] = "启用",
        ["Disabled"] = "禁用"
    }
}

LanguageManager.countryTranslations = include("cl_country_translations.lua")
LanguageManager.GetCountryName = LanguageManager.countryTranslations.GetCountryName

-- Function to get a country translation
function LanguageManager:GetCountryTranslation(lang, country_key)
    -- Reformat the country name (e.g., "the_united_kingdom" -> "The United Kingdom")
    local formattedName = country_key:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. string.lower(b) end)
    
    -- Get the translated name if it exists and is not empty; otherwise, use the formatted name
    local translatedName = self.countryTranslations[lang] and self.countryTranslations[lang][formattedName]
    if translatedName == nil or translatedName == "" then
        translatedName = formattedName
    end
    
    return translatedName
end

-- Function to set the current language (default to English)
LanguageManager.currentLanguage = "en"

function LanguageManager:SetLanguage(code)
    if self.translations[code] then
        self.currentLanguage = code
    else
        print("[LanguageManager] Language not found! Falling back to English.")
        self.currentLanguage = "en"
    end
end

-- Function to get the current language's translation
function LanguageManager:Translate(key)
    return self:GetTranslation(self.currentLanguage, key)
end

-- Function to get the display name of a language
function LanguageManager:GetLanguageName(code)
    return self.languages[code] or code
end

-- Function to get all available languages
function LanguageManager:GetAvailableLanguages()
    return self.languages
end

-- Function to get a translation for a specific language
function LanguageManager:GetTranslation(lang, key)
    if self.translations[lang] and self.translations[lang][key] then
        return self.translations[lang][key]
    end
    return key -- Return the key if translation is not found
end

return LanguageManager
