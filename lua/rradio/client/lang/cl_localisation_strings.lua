local LANG = {}

local LANGUAGE_INFO = {
    en = { name = "English", rtl = false },
    en_pt = { name = "Pirate English", rtl = false },
    de = { name = "Deutsch", rtl = false },
    es_es = { name = "Español", rtl = false },
    fr = { name = "Français", rtl = false },
    it = { name = "Italiano", rtl = false },
    ja = { name = "日本語", rtl = false },
    ko = { name = "한국어", rtl = false },
    pt_br = { name = "Português (Brasil)", rtl = false },
    ru = { name = "Русский", rtl = false },
    tr = { name = "Türkçe", rtl = false },
    zh_cn = { name = "简体中文", rtl = false },
    bg = { name = "Български", rtl = false },
    el = { name = "Ελληνικά", rtl = false },
    hr = { name = "Hrvatski", rtl = false },
    he = { name = "עברית", rtl = true },
    sk = { name = "Slovenčina", rtl = false },
    pl = { name = "Polski", rtl = false },
    da = { name = "Dansk", rtl = false },
    nl = { name = "Nederlands", rtl = false },
    th = { name = "ไทย", rtl = false },
    vi = { name = "Tiếng Việt", rtl = false },
    hu = { name = "Magyar", rtl = false },
    lt = { name = "Lietuvių", rtl = false },
    uk = { name = "Українська", rtl = false }
}

local THEME_TRANSLATIONS = {
    en = { 
        dark = "Dark", sleek = "Sleek", cyberpunk = "Cyberpunk",
        sunset = "Sunset", emerald = "Emerald", synthwave = "Synthwave",
        forest = "Forest", ocean = "Ocean", volcanic = "Volcanic",
        royale = "Royale", platinum = "Platinum", carbon = "Carbon",
        obsidian = "Obsidian", imperial = "Imperial", gold = "Gold" 
    },
    en_pt = { 
        dark = "Blackened", sleek = "Shipshape", cyberpunk = "Future-cursed",
        sunset = "Horizon's Fire", emerald = "Sea Jewel", synthwave = "Siren's Melody",
        forest = "Timber Woods", ocean = "Seven Seas", volcanic = "Devil's Furnace",
        royale = "King's Guard", platinum = "Silvered Steel", carbon = "Sootstorm",
        obsidian = "Nightglass", imperial = "Crown's Veil", gold = "Gilded" 
    },
    de = { 
        dark = "Dunkel", sleek = "Elegant", cyberpunk = "Cyberpunk",
        sunset = "Sonnenuntergang", emerald = "Smaragd", synthwave = "Synthwave",
        forest = "Wald", ocean = "Ozean", volcanic = "Vulkanisch",
        royale = "Königlich", platinum = "Platin", carbon = "Karbon",
        obsidian = "Obsidian", imperial = "Imperial", gold = "Gold" 
    },
    es_es = { 
        dark = "Oscuro", sleek = "Elegante", cyberpunk = "Cyberpunk",
        sunset = "Atardecer", emerald = "Esmeralda", synthwave = "Synthwave",
        forest = "Bosque", ocean = "Océano", volcanic = "Volcánico",
        royale = "Real", platinum = "Platino", carbon = "Carbono",
        obsidian = "Obsidiana", imperial = "Imperial", gold = "Oro" 
    },
    fr = { 
        dark = "Sombre", sleek = "Élégant", cyberpunk = "Cyberpunk",
        sunset = "Coucher de soleil", emerald = "Émeraude", synthwave = "Synthwave",
        forest = "Forêt", ocean = "Océan", volcanic = "Volcanique",
        royale = "Royale", platinum = "Platine", carbon = "Carbone",
        obsidian = "Obsidienne", imperial = "Impérial", gold = "Or" 
    },
    it = { 
        dark = "Scuro", sleek = "Elegante", cyberpunk = "Cyberpunk",
        sunset = "Tramonto", emerald = "Smeraldo", synthwave = "Synthwave",
        forest = "Foresta", ocean = "Oceano", volcanic = "Vulcanico",
        royale = "Reale", platinum = "Platino", carbon = "Carbonio",
        obsidian = "Ossidiana", imperial = "Imperiale", gold = "Oro" 
    },
    ja = { 
        dark = "ダーク", sleek = "スリーク", cyberpunk = "サイバーパンク",
        sunset = "サンセット", emerald = "エメラルド", synthwave = "シンセウェーブ",
        forest = "フォレスト", ocean = "オーシャン", volcanic = "ボルカニック",
        royale = "ロイヤル", platinum = "プラチナ", carbon = "カーボン",
        obsidian = "黒曜石", imperial = "インペリアル", gold = "ゴールド" 
    },
    ko = { 
        dark = "다크", sleek = "슬릭", cyberpunk = "사이버펑크",
        sunset = "선셋", emerald = "에메랄드", synthwave = "신스웨이브",
        forest = "포레스트", ocean = "오션", volcanic = "볼케이닉",
        royale = "로얄", platinum = "플래티넘", carbon = "카본",
        obsidian = "흑요석", imperial = "제국", gold = "골드" 
    },
    pt_br = { 
        dark = "Escuro", sleek = "Elegante", cyberpunk = "Cyberpunk",
        sunset = "Pôr do sol", emerald = "Esmeralda", synthwave = "Synthwave",
        forest = "Floresta", ocean = "Oceano", volcanic = "Vulcânico",
        royale = "Real", platinum = "Platina", carbon = "Carbono",
        obsidian = "Obsidiana", imperial = "Imperial", gold = "Ouro" 
    },
    ru = { 
        dark = "Тёмный", sleek = "Стильный", cyberpunk = "Киберпанк",
        sunset = "Закат", emerald = "Изумруд", synthwave = "Синтвейв",
        forest = "Лес", ocean = "Океан", volcanic = "Вулканический",
        royale = "Королевский", platinum = "Платиновый", carbon = "Углерод",
        obsidian = "Обсидиан", imperial = "Имперский", gold = "Золото" 
    },
    tr = { 
        dark = "Koyu", sleek = "Şık", cyberpunk = "Siberpunk",
        sunset = "Günbatımı", emerald = "Zümrüt", synthwave = "Synthwave",
        forest = "Orman", ocean = "Okyanus", volcanic = "Volkanik",
        royale = "Kraliyet", platinum = "Platin", carbon = "Karbon",
        obsidian = "Obsidyen", imperial = "İmparatorluk", gold = "Altın" 
    },
    zh_cn = { 
        dark = "暗黑", sleek = "简洁", cyberpunk = "赛博朋克",
        sunset = "日落", emerald = "翡翠", synthwave = "合成波",
        forest = "森林", ocean = "海洋", volcanic = "火山",
        royale = "皇家", platinum = "铂金", carbon = "碳素",
        obsidian = "黑曜石", imperial = "帝国", gold = "黄金" 
    },
    bg = { 
        dark = "Тъмна", sleek = "Изтънчен", cyberpunk = "Киберпънк",
        sunset = "Залез", emerald = "Изумруд", synthwave = "Синтувейв",
        forest = "Гора", ocean = "Океан", volcanic = "Вулканичен",
        royale = "Кралска", platinum = "Платина", carbon = "Въглерод",
        obsidian = "Обсидиан", imperial = "Имперски", gold = "Злато" 
    },
    el = { 
        dark = "Σκοτεινό", sleek = "Κομψό", cyberpunk = "Σάιμπερπανκ",
        sunset = "Ηλιοβασίλεμα", emerald = "Σμάραγδο", synthwave = "Συνθετικό κύμα",
        forest = "Δάσος", ocean = "Ωκεανός", volcanic = "Ηφαιστειακό",
        royale = "Βασιλικό", platinum = "Πλατινένιο", carbon = "Άνθρακας",
        obsidian = "Οψιδιανός", imperial = "Αυτοκρατορικό", gold = "Χρυσό" 
    },
    hr = { 
        dark = "Tamno", sleek = "Elegantno", cyberpunk = "Cyberpunk",
        sunset = "Zalazak sunca", emerald = "Smaragd", synthwave = "Synthwave",
        forest = "Šuma", ocean = "Ocean", volcanic = "Vulkanski",
        royale = "Kraljevski", platinum = "Platina", carbon = "Ugljik",
        obsidian = "Opsidijan", imperial = "Carski", gold = "Zlato" 
    },
    he = { 
        dark = "כהה", sleek = "חלק", cyberpunk = "סייברפאנק",
        sunset = "שקיעה", emerald = "אזמרגד", synthwave = "סינתוויב",
        forest = "יער", ocean = "אוקיינוס", volcanic = "געשי",
        royale = "מלכותי", platinum = "פלטינה", carbon = "פחמן",
        obsidian = "אובסידיאן", imperial = "אימפריאלי", gold = "זהב" 
    },
    sk = { 
        dark = "Tmavá", sleek = "Elegantná", cyberpunk = "Kyberpunk",
        sunset = "Západ slnka", emerald = "Smaragd", synthwave = "Synthwave",
        forest = "Les", ocean = "Oceán", volcanic = "Sopečný",
        royale = "Kráľovský", platinum = "Platina", carbon = "Uhlík",
        obsidian = "Obsidian", imperial = "Imperiálny", gold = "Zlato" 
    },
    pl = { 
        dark = "Ciemny", sleek = "Elegancki", cyberpunk = "Cyberpunk",
        sunset = "Zachód słońca", emerald = "Szmaragd", synthwave = "Synthwave",
        forest = "Las", ocean = "Ocean", volcanic = "Wulkaniczny",
        royale = "Królewski", platinum = "Platynowy", carbon = "Węglowy",
        obsidian = "Obsydian", imperial = "Imperialny", gold = "Złoto" 
    },
    da = { 
        dark = "Mørk", sleek = "Elegant", cyberpunk = "Cyberpunk",
        sunset = "Solnedgang", emerald = "Smaragd", synthwave = "Synthwave",
        forest = "Skov", ocean = "Hav", volcanic = "Vulkanisk",
        royale = "Kongelig", platinum = "Platin", carbon = "Kulstof",
        obsidian = "Obsidian", imperial = "Imperial", gold = "Guld" 
    },
    nl = { 
        dark = "Donker", sleek = "Strak", cyberpunk = "Cyberpunk",
        sunset = "Zonsondergang", emerald = "Smaragd", synthwave = "Synthwave",
        forest = "Bos", ocean = "Oceaan", volcanic = "Vulkanisch",
        royale = "Koninklijk", platinum = "Platina", carbon = "Koolstof",
        obsidian = "Obsidiaan", imperial = "Imperiaal", gold = "Goud" 
    },
    th = { 
        dark = "มืด", sleek = "เพรียว", cyberpunk = "ไซเบอร์พังค์",
        sunset = "พระอาทิตย์ตก", emerald = "มรกต", synthwave = "ซินธ์เวฟ",
        forest = "ป่า", ocean = "มหาสมุทร", volcanic = "ภูเขาไฟ",
        royale = "รอยัล", platinum = "แพลตตินัม", carbon = "คาร์บอน",
        obsidian = "ออบซิเดียน", imperial = "จักรวรรดิ", gold = "ทอง" 
    },
    vi = { 
        dark = "Tối", sleek = "Bóng bẩy", cyberpunk = "Cyberpunk",
        sunset = "Hoàng hôn", emerald = "Ngọc lục bảo", synthwave = "Synthwave",
        forest = "Rừng", ocean = "Đại dương", volcanic = "Núi lửa",
        royale = "Hoàng gia", platinum = "Bạch kim", carbon = "Cacbon",
        obsidian = "Obsidian", imperial = "Đế chế", gold = "Vàng" 
    },
    hu = { 
        dark = "Sötét", sleek = "Elegáns", cyberpunk = "Cyberpunk",
        sunset = "Naplemente", emerald = "Smaragd", synthwave = "Synthwave",
        forest = "Erdő", ocean = "Óceán", volcanic = "Vulkáni",
        royale = "Királyi", platinum = "Platina", carbon = "Szén",
        obsidian = "Obszidián", imperial = "Császári", gold = "Arany" 
    },
    lt = { 
        dark = "Tamsus", sleek = "Elegantiškas", cyberpunk = "Cyberpunk",
        sunset = "Saulėlydis", emerald = "Smaragdas", synthwave = "Synthwave",
        forest = "Miškas", ocean = "Vandenynas", volcanic = "Vulkaninis",
        royale = "Karališkas", platinum = "Platina", carbon = "Anglis",
        obsidian = "Obsidiantas", imperial = "Imperinis", gold = "Auksas" 
    },
    uk = { 
        dark = "Темна", sleek = "Елегантна", cyberpunk = "Кіберпанк",
        sunset = "Сонячний захід", emerald = "Смарагд", synthwave = "Синтвейв",
        forest = "Ліс", ocean = "Океан", volcanic = "Вулканічний",
        royale = "Королівський", platinum = "Платина", carbon = "Вуглець",
        obsidian = "Обсидіан", imperial = "Імперський", gold = "Золото" 
    }
}

for langCode, _ in pairs( LANGUAGE_INFO ) do
    LANG[langCode] = {}
end


local function defineTranslations()
    -- English (Base language)
    LANG.en["SelectCountry"] = "Select a Country"
    LANG.en["StopRadio"] = "STOP"
    LANG.en["SearchPlaceholder"] = "Search..."
    LANG.en["PressKeyToOpen"] = "Press {key} to pick a station"
    LANG.en["NoStations"] = "Warning: No stations found for {country}"
    LANG.en["Interact"] = "Press E to Interact"
    LANG.en["PAUSED"] = "PAUSED"
    LANG.en["Settings"] = "Settings"
    LANG.en["LanguageSelection"] = "Language Selection"
    LANG.en["ThemeSelection"] = "Theme Selection"
    LANG.en["SelectTheme"] = "Select Theme"
    LANG.en["SelectLanguage"] = "Select Language"
    LANG.en["SelectKey"] = "Open Car Radio Menu"
    LANG.en["GeneralOptions"] = "General Options"
    LANG.en["ShowCarMessages"] = "Show Animation When Entering Vehicle"
    LANG.en["ShowBoomboxHUD"] = "Show the Boombox HUD"
    LANG.en["BasicBoomboxHUD"] = "Basic Boombox HUD"
    LANG.en["Contribute"] = "Want to contribute?"
    LANG.en["SubmitPullRequest"] = "Submit a Pull Request :)"
    LANG.en["SuperadminSettings"] = "Superadmin Settings"
    LANG.en["MakeBoomboxPermanent"] = "Make Boombox Permanent"
    LANG.en["Enabled"] = "Enabled"
    LANG.en["Disabled"] = "Disabled"
    LANG.en["FavoriteStations"] = "Favorite Stations"
    LANG.en["TuningIn"] = "Tuning in"
    LANG.en["KeyBinds"] = "Key Binds"
    LANG.en["ToOpenRadio"] = "to open radio"
    LANG.en["Global"] = "Global"
    LANG.en["Custom"] = "Custom Radio Stations"
    
    -- Pirate English
    LANG.en_pt["SelectCountry"] = "Be Choosin' a Land"
    LANG.en_pt["StopRadio"] = "AVAST!"
    LANG.en_pt["SearchPlaceholder"] = "Hunt fer treasure..."
    LANG.en_pt["PressKeyToOpen"] = "Press {key} to tune into a shanty"
    LANG.en_pt["NoStations"] = "Yarr! No shanties found in {country}"
    LANG.en_pt["Interact"] = "Press E to Parley"
    LANG.en_pt["PAUSED"] = "TAKIN' A BREATHER"
    LANG.en_pt["Settings"] = "Ship's Riggin's"
    LANG.en_pt["LanguageSelection"] = "Choose Yer Tongue"
    LANG.en_pt["ThemeSelection"] = "Pick Yer Colors"
    LANG.en_pt["SelectTheme"] = "Choose a Look fer the Ship"
    LANG.en_pt["SelectLanguage"] = "Be Choosin' Yer Tongue"
    LANG.en_pt["SelectKey"] = "Hoist the Car Radio Menu"
    LANG.en_pt["GeneralOptions"] = "Cap'n's Options"
    LANG.en_pt["ShowCarMessages"] = "Show the Enterin' Animation"
    LANG.en_pt["ShowBoomboxHUD"] = "Show the Music Box Treasure Map"
    LANG.en_pt["BasicBoomboxHUD"] = "Basic Music Box Map"
    LANG.en_pt["Contribute"] = "Wanna lend a hook?"
    LANG.en_pt["SubmitPullRequest"] = "Send a Message in a Bottle :)"
    LANG.en_pt["SuperadminSettings"] = "Cap'n o' Cap'ns Settings"
    LANG.en_pt["MakeBoomboxPermanent"] = "Nail Down the Music Box Forever"
    LANG.en_pt["Enabled"] = "Aye, It Be On"
    LANG.en_pt["Disabled"] = "Nay, It Be Off"
    LANG.en_pt["FavoriteStations"] = "Ye Favorite Shanties"
    LANG.en_pt["TuningIn"] = "Tunin' the Sails"
    LANG.en_pt["KeyBinds"] = "Key Binds"
    LANG.en_pt["ToOpenRadio"] = "to set sail"
    LANG.en_pt["Global"] = "Global"
    LANG.en_pt["Custom"] = "Me Own Toons"
    
    -- German
    LANG.de["SelectCountry"] = "Land auswählen"
    LANG.de["StopRadio"] = "STOP"
    LANG.de["SearchPlaceholder"] = "Suche..."
    LANG.de["PressKeyToOpen"] = "Drücken Sie {key}, um eine Station auszuwählen"
    LANG.de["NoStations"] = "Warnung: Keine Stationen gefunden für {country}"
    LANG.de["Interact"] = "Drücken Sie E zur Interaktion"
    LANG.de["PAUSED"] = "PAUSIERT"
    LANG.de["Settings"] = "Einstellungen"
    LANG.de["LanguageSelection"] = "Sprachauswahl"
    LANG.de["ThemeSelection"] = "Themenauswahl"
    LANG.de["SelectTheme"] = "Thema auswählen"
    LANG.de["SelectLanguage"] = "Sprache auswählen"
    LANG.de["SelectKey"] = "Taste für Auto-Radio-Menü wählen"
    LANG.de["GeneralOptions"] = "Allgemeine Optionen"
    LANG.de["ShowCarMessages"] = "Animation beim Einsteigen im Fahrzeug anzeigen"
    LANG.de["ShowBoomboxHUD"] = "Tragbares-Radio-Bildschirmanzeige anzeigen"
    LANG.de["BasicBoomboxHUD"] = "Einfaches HUD für Tragbares Radio"
    LANG.de["Contribute"] = "Möchten Sie mitwirken?"
    LANG.de["SubmitPullRequest"] = "Einen Änderungsvorschlag einreichen :)"
    LANG.de["SuperadminSettings"] = "Hauptadministrator-Einstellungen"
    LANG.de["MakeBoomboxPermanent"] = "Tragbares Radio als permanent markieren"
    LANG.de["Enabled"] = "Aktiviert"
    LANG.de["Disabled"] = "Deaktiviert"
    LANG.de["FavoriteStations"] = "Favorit-Stationen"
    LANG.de["TuningIn"] = "Einstellen"
    LANG.de["KeyBinds"] = "Tastenbelegungen"
    LANG.de["ToOpenRadio"] = "um das Radio zu öffnen"
    LANG.de["Global"] = "Weltweit"
    LANG.de["Custom"] = "Benutzerdefinierte Radiostationen"
    
    -- Polish
    LANG.pl["SelectCountry"] = "Wybierz kraj"
    LANG.pl["StopRadio"] = "STOP"
    LANG.pl["SearchPlaceholder"] = "Szukaj..."
    LANG.pl["PressKeyToOpen"] = "Naciśnij {key}, aby wybrać stację"
    LANG.pl["NoStations"] = "Ostrzeżenie: Nie znaleziono stacji dla {country}"
    LANG.pl["Interact"] = "Naciśnij E, aby wejść w interakcję"
    LANG.pl["PAUSED"] = "WSTRZYMANE"
    LANG.pl["Settings"] = "Ustawienia"
    LANG.pl["LanguageSelection"] = "Wybór języka"
    LANG.pl["ThemeSelection"] = "Wybór motywu"
    LANG.pl["SelectTheme"] = "Wybierz motyw"
    LANG.pl["SelectLanguage"] = "Wybierz język"
    LANG.pl["SelectKey"] = "Wybierz klawisz dla menu radia samochodowego"
    LANG.pl["GeneralOptions"] = "Opcje ogólne"
    LANG.pl["ShowCarMessages"] = "Pokaż animację podczas wsiadania do pojazdu"
    LANG.pl["ShowBoomboxHUD"] = "Pokaż HUD przenośnego radia"
    LANG.pl["BasicBoomboxHUD"] = "Podstawowy HUD radia"
    LANG.pl["Contribute"] = "Chcesz współtworzyć?"
    LANG.pl["SubmitPullRequest"] = "Złóż pull request :)"
    LANG.pl["SuperadminSettings"] = "Ustawienia superadministratora"
    LANG.pl["MakeBoomboxPermanent"] = "Oznacz przenośne radio jako trwałe"
    LANG.pl["Enabled"] = "Włączone"
    LANG.pl["Disabled"] = "Wyłączone"
    LANG.pl["FavoriteStations"] = "Ulubione stacje"
    LANG.pl["TuningIn"] = "Strojenie"
    LANG.pl["KeyBinds"] = "Przypisania klawiszy"
    LANG.pl["ToOpenRadio"] = "aby otworzyć radio"
    LANG.pl["Global"] = "Globalny"
    LANG.pl["Custom"] = "Stacje radiowe niestandardowe"
    
    -- Spanish
    LANG.es_es["SelectCountry"] = "Seleccionar país"
    LANG.es_es["StopRadio"] = "PARAR"
    LANG.es_es["SearchPlaceholder"] = "Buscar..."
    LANG.es_es["PressKeyToOpen"] = "Presione {key} para elegir una estación"
    LANG.es_es["NoStations"] = "Advertencia: No se encontraron estaciones para {country}"
    LANG.es_es["Interact"] = "Presiona E para interactuar"
    LANG.es_es["PAUSED"] = "PAUSADO"
    LANG.es_es["Settings"] = "Ajustes"
    LANG.es_es["LanguageSelection"] = "Selección de idioma"
    LANG.es_es["ThemeSelection"] = "Selección de tema"
    LANG.es_es["SelectTheme"] = "Seleccionar tema"
    LANG.es_es["SelectLanguage"] = "Seleccionar idioma"
    LANG.es_es["SelectKey"] = "Selecciona la tecla para abrir el menú de radio del auto"
    LANG.es_es["GeneralOptions"] = "Opciones generales"
    LANG.es_es["ShowCarMessages"] = "Mostrar animación al entrar en el vehículo"
    LANG.es_es["ShowBoomboxHUD"] = "Mostrar la interfaz del radio portátil"
    LANG.es_es["BasicBoomboxHUD"] = "HUD básico del radio"
    LANG.es_es["Contribute"] = "¿Quieres contribuir?"
    LANG.es_es["SubmitPullRequest"] = "Enviar una solicitud de cambios :)"
    LANG.es_es["SuperadminSettings"] = "Configuraciones de Administrador Principal"
    LANG.es_es["MakeBoomboxPermanent"] = "Marcar radio portátil como permanente"
    LANG.es_es["Enabled"] = "Activado"
    LANG.es_es["Disabled"] = "Desactivado"
    LANG.es_es["FavoriteStations"] = "Estaciones favoritas"
    LANG.es_es["TuningIn"] = "Sintonizando"
    LANG.es_es["KeyBinds"] = "Asignación de teclas"
    LANG.es_es["ToOpenRadio"] = "para abrir la radio"
    LANG.es_es["Global"] = "Mundial"
    LANG.es_es["Custom"] = "Estaciones de radio personalizadas"
    
    -- French
    LANG.fr["SelectCountry"] = "Sélectionnez un pays"
    LANG.fr["StopRadio"] = "ARRÊT"
    LANG.fr["SearchPlaceholder"] = "Recherche..."
    LANG.fr["PressKeyToOpen"] = "Appuyez sur {key} pour choisir une station"
    LANG.fr["NoStations"] = "Attention : Aucune station trouvée pour {country}"
    LANG.fr["Interact"] = "Appuyez sur E pour interagir"
    LANG.fr["PAUSED"] = "EN PAUSE"
    LANG.fr["Settings"] = "Paramètres"
    LANG.fr["LanguageSelection"] = "Sélection de la langue"
    LANG.fr["ThemeSelection"] = "Sélection du thème"
    LANG.fr["SelectTheme"] = "Sélectionner un thème"
    LANG.fr["SelectLanguage"] = "Sélectionner une langue"
    LANG.fr["SelectKey"] = "Sélectionner la touche pour ouvrir le menu de radio du véhicule"
    LANG.fr["GeneralOptions"] = "Options généralisées"
    LANG.fr["ShowCarMessages"] = "Afficher l'animation lors de l'entrée dans le véhicule"
    LANG.fr["ShowBoomboxHUD"] = "Afficher l'interface de la radio portable"
    LANG.fr["BasicBoomboxHUD"] = "HUD basique de la radio"
    LANG.fr["Contribute"] = "Voulez-vous contribuer ?"
    LANG.fr["SubmitPullRequest"] = "Envoyez une demande de fusion :)"
    LANG.fr["SuperadminSettings"] = "Paramètres d'Administrateur Principal"
    LANG.fr["MakeBoomboxPermanent"] = "Marquer la radio portable comme permanente"
    LANG.fr["Enabled"] = "Activé"
    LANG.fr["Disabled"] = "Désactivé"
    LANG.fr["FavoriteStations"] = "Stations favorites"
    LANG.fr["TuningIn"] = "Syntonisation"
    LANG.fr["KeyBinds"] = "Raccourcis clavier"
    LANG.fr["ToOpenRadio"] = "pour ouvrir la radio"
    LANG.fr["Global"] = "Mondial"
    LANG.fr["Custom"] = "Stations de radio personnalisées"
    
    -- Italian
    LANG.it["SelectCountry"] = "Seleziona paese"
    LANG.it["StopRadio"] = "FERMARE"
    LANG.it["SearchPlaceholder"] = "Cerca..."
    LANG.it["PressKeyToOpen"] = "Premi {key} per scegliere una stazione"
    LANG.it["NoStations"] = "Avviso: Nessuna stazione trovata per {country}"
    LANG.it["Interact"] = "Premi E per interagire"
    LANG.it["PAUSED"] = "IN PAUSA"
    LANG.it["Settings"] = "Impostazioni"
    LANG.it["LanguageSelection"] = "Selezione della lingua"
    LANG.it["ThemeSelection"] = "Selezione del tema"
    LANG.it["SelectTheme"] = "Seleziona tema"
    LANG.it["SelectLanguage"] = "Seleziona lingua"
    LANG.it["SelectKey"] = "Tasto per aprire menu radio auto"
    LANG.it["GeneralOptions"] = "Opzioni generali"
    LANG.it["ShowCarMessages"] = "Mostra animazione all'entrata nel veicolo"
    LANG.it["ShowBoomboxHUD"] = "Mostra l'interfaccia della radio portatile"
    LANG.it["BasicBoomboxHUD"] = "HUD radio semplice"
    LANG.it["Contribute"] = "Vuoi contribuire?"
    LANG.it["SubmitPullRequest"] = "Invia una richiesta di unione :)"
    LANG.it["SuperadminSettings"] = "Configurazioni dell'Amministratore Principale"
    LANG.it["MakeBoomboxPermanent"] = "Rendi la radio portatile permanente"
    LANG.it["Enabled"] = "Attivo"
    LANG.it["Disabled"] = "Disattivato"
    LANG.it["FavoriteStations"] = "Stazioni favorite"
    LANG.it["TuningIn"] = "Sintonizzazione"
    LANG.it["KeyBinds"] = "Assegnazione tasti"
    LANG.it["ToOpenRadio"] = "per aprire la radio"
    LANG.it["Global"] = "Mondiale"
    LANG.it["Custom"] = "Stazioni radio personalizzate"
    
    -- Japanese
    LANG.ja["SelectCountry"] = "国を選択"
    LANG.ja["StopRadio"] = "停止"
    LANG.ja["SearchPlaceholder"] = "検索..."
    LANG.ja["PressKeyToOpen"] = "{key}を押して局を選択"
    LANG.ja["NoStations"] = "警告: {country}の局が見つかりません"
    LANG.ja["Interact"] = "Eを押して操作"
    LANG.ja["PAUSED"] = "一時停止"
    LANG.ja["Settings"] = "設定"
    LANG.ja["LanguageSelection"] = "言語選択"
    LANG.ja["ThemeSelection"] = "テーマ選択"
    LANG.ja["SelectTheme"] = "テーマを選択"
    LANG.ja["SelectLanguage"] = "言語を選択"
    LANG.ja["SelectKey"] = "車内ラジオメニューのキーを選択"
    LANG.ja["GeneralOptions"] = "一般オプション"
    LANG.ja["ShowCarMessages"] = "車両に乗り込むときにアニメーションを表示"
    LANG.ja["ShowBoomboxHUD"] = "ポータブルラジオのHUDを表示"
    LANG.ja["BasicBoomboxHUD"] = "簡易HUDを使用"
    LANG.ja["Contribute"] = "貢献したいですか？"
    LANG.ja["SubmitPullRequest"] = "変更リクエストを送信 :)"
    LANG.ja["SuperadminSettings"] = "最高管理者の設定"
    LANG.ja["MakeBoomboxPermanent"] = "ポータブルラジオを永久にする"
    LANG.ja["Enabled"] = "有効"
    LANG.ja["Disabled"] = "無効"
    LANG.ja["FavoriteStations"] = "お気に入りの局"
    LANG.ja["TuningIn"] = "調整中"
    LANG.ja["KeyBinds"] = "キー割り当て"
    LANG.ja["ToOpenRadio"] = "ラジオを開くには"
    LANG.ja["Global"] = "全世界"
    LANG.ja["Custom"] = "カスタムラジオステーション"
    
    -- Korean
    LANG.ko["SelectCountry"] = "국가 선택"
    LANG.ko["StopRadio"] = "정지"
    LANG.ko["SearchPlaceholder"] = "검색..."
    LANG.ko["PressKeyToOpen"] = "{key}을 눌러 방송국을 선택하십시오"
    LANG.ko["NoStations"] = "경고: {country}에 대한 방송국을 찾을 수 없습니다"
    LANG.ko["Interact"] = "E를 눌러 상호작용하세요"
    LANG.ko["PAUSED"] = "일시정지"
    LANG.ko["Settings"] = "설정"
    LANG.ko["LanguageSelection"] = "언어 선택"
    LANG.ko["ThemeSelection"] = "테마 선택"
    LANG.ko["SelectTheme"] = "테마 선택"
    LANG.ko["SelectLanguage"] = "언어 선택"
    LANG.ko["SelectKey"] = "차량 라디오 메뉴 키 선택"
    LANG.ko["GeneralOptions"] = "일반 옵션"
    LANG.ko["ShowCarMessages"] = "차량 진입 시 애니메이션 표시"
    LANG.ko["ShowBoomboxHUD"] = "휴대용 라디오 HUD를 표시"
    LANG.ko["BasicBoomboxHUD"] = "기본 HUD 사용"
    LANG.ko["Contribute"] = "기여하고 싶습니까?"
    LANG.ko["SubmitPullRequest"] = "변경 요청을 제출 :)"
    LANG.ko["SuperadminSettings"] = "최고 관리자 설정"
    LANG.ko["MakeBoomboxPermanent"] = "휴대용 라디오를 영구적으로 만들기"
    LANG.ko["Enabled"] = "활성화"
    LANG.ko["Disabled"] = "비활성화"
    LANG.ko["FavoriteStations"] = "즐겨찾기 방송국"
    LANG.ko["TuningIn"] = "조정 중"
    LANG.ko["KeyBinds"] = "키 바인딩"
    LANG.ko["ToOpenRadio"] = "라디오를 열려면"
    LANG.ko["Global"] = "전 세계"
    LANG.ko["Custom"] = "사용자 정의 라디오 스테이션"
    
    -- Brazilian Portuguese
    LANG.pt_br["SelectCountry"] = "Selecionar país"
    LANG.pt_br["StopRadio"] = "PARAR"
    LANG.pt_br["SearchPlaceholder"] = "Buscar..."
    LANG.pt_br["PressKeyToOpen"] = "Pressione {key} para escolher uma estação"
    LANG.pt_br["NoStations"] = "Aviso: Nenhuma estação encontrada para {country}"
    LANG.pt_br["Interact"] = "Pressione E para interagir"
    LANG.pt_br["PAUSED"] = "PAUSADO"
    LANG.pt_br["Settings"] = "Configurações"
    LANG.pt_br["LanguageSelection"] = "Seleção de idioma"
    LANG.pt_br["ThemeSelection"] = "Seleção de tema"
    LANG.pt_br["SelectTheme"] = "Selecionar tema"
    LANG.pt_br["SelectLanguage"] = "Selecionar idioma"
    LANG.pt_br["SelectKey"] = "Tecla para abrir menu de rádio"
    LANG.pt_br["GeneralOptions"] = "Opções gerais"
    LANG.pt_br["ShowCarMessages"] = "Mostrar animação ao entrar no veículo"
    LANG.pt_br["ShowBoomboxHUD"] = "Mostrar a interface do rádio portátil"
    LANG.pt_br["BasicBoomboxHUD"] = "HUD básico do rádio"
    LANG.pt_br["Contribute"] = "Quer contribuir?"
    LANG.pt_br["SubmitPullRequest"] = "Enviar uma solicitação de mudança :)"
    LANG.pt_br["SuperadminSettings"] = "Configurações de Administrador Principal"
    LANG.pt_br["MakeBoomboxPermanent"] = "Marcar rádio portátil como permanente"
    LANG.pt_br["Enabled"] = "Ativado"
    LANG.pt_br["Disabled"] = "Desativado"
    LANG.pt_br["FavoriteStations"] = "Estações favoritas"
    LANG.pt_br["TuningIn"] = "Sintonização"
    LANG.pt_br["KeyBinds"] = "Atribuições de teclas"
    LANG.pt_br["ToOpenRadio"] = "para abrir o rádio"
    LANG.pt_br["Global"] = "Mundial"
    LANG.pt_br["Custom"] = "Estações de rádio personalizadas"
    
    -- Russian
    LANG.ru["SelectCountry"] = "Выберите страну"
    LANG.ru["StopRadio"] = "СТОП"
    LANG.ru["SearchPlaceholder"] = "Поиск..."
    LANG.ru["PressKeyToOpen"] = "Нажмите {key}, чтобы выбрать станцию"
    LANG.ru["NoStations"] = "Предупреждение: Станции не найдены для {country}"
    LANG.ru["Interact"] = "Нажмите E для взаимодействия"
    LANG.ru["PAUSED"] = "ПАУЗА"
    LANG.ru["Settings"] = "Настройки"
    LANG.ru["LanguageSelection"] = "Выбор языка"
    LANG.ru["ThemeSelection"] = "Выбор темы"
    LANG.ru["SelectTheme"] = "Выберите тему"
    LANG.ru["SelectLanguage"] = "Выберите язык"
    LANG.ru["SelectKey"] = "Клавиша для меню радио в машине"
    LANG.ru["GeneralOptions"] = "Общие параметры"
    LANG.ru["ShowCarMessages"] = "Показывать анимацию при входе в машину"
    LANG.ru["ShowBoomboxHUD"] = "Показывать интерфейс портативного радио"
    LANG.ru["BasicBoomboxHUD"] = "Простой HUD радио"
    LANG.ru["Contribute"] = "Хотите внести свой вклад?"
    LANG.ru["SubmitPullRequest"] = "Отправить запрос на внесение изменений :)"
    LANG.ru["SuperadminSettings"] = "Настройки главного администратора"
    LANG.ru["MakeBoomboxPermanent"] = "Сделать портативное радио постоянным"
    LANG.ru["Enabled"] = "Включено"
    LANG.ru["Disabled"] = "Выключено"
    LANG.ru["FavoriteStations"] = "Избранные станции"
    LANG.ru["TuningIn"] = "Настройка"
    LANG.ru["KeyBinds"] = "Назначение клавиш"
    LANG.ru["ToOpenRadio"] = "чтобы открыть радио"
    LANG.ru["Global"] = "Глобальный"
    LANG.ru["Custom"] = "Пользовательские радиостанции"
    
    -- Turkish
    LANG.tr["SelectCountry"] = "Ülke seç"
    LANG.tr["StopRadio"] = "DURDUR"
    LANG.tr["SearchPlaceholder"] = "Ara..."
    LANG.tr["PressKeyToOpen"] = "Radyo kanalı seçmek için {key} tuşuna bas"
    LANG.tr["NoStations"] = "Uyarı: {country} kanalı bulunamadı."
    LANG.tr["Interact"] = "Etkileşim için E'ye basın"
    LANG.tr["PAUSED"] = "DURAKLATILDI"
    LANG.tr["Settings"] = "Ayarlar"
    LANG.tr["LanguageSelection"] = "Dil seçimi"
    LANG.tr["ThemeSelection"] = "Tema seçimi"
    LANG.tr["SelectTheme"] = "Temayı seç"
    LANG.tr["SelectLanguage"] = "Dili seç"
    LANG.tr["SelectKey"] = "Araç radyo menüsü tuşunu seç"
    LANG.tr["GeneralOptions"] = "Genel seçenekler"
    LANG.tr["ShowCarMessages"] = "Araç girişi animasyonu göster"
    LANG.tr["ShowBoomboxHUD"] = "Taşınabilir radyo arayüzünü göster"
    LANG.tr["BasicBoomboxHUD"] = "Temel HUD kullan"
    LANG.tr["Contribute"] = "Katkıda bulunmak ister misiniz?"
    LANG.tr["SubmitPullRequest"] = "Değişiklik isteği gönder :)"
    LANG.tr["SuperadminSettings"] = "Baş yönetici ayarları"
    LANG.tr["MakeBoomboxPermanent"] = "Taşınabilir radyoyu kalıcı yap"
    LANG.tr["Enabled"] = "Etkin"
    LANG.tr["Disabled"] = "Devre dışı"
    LANG.tr["FavoriteStations"] = "Favori radyo kanalları"
    LANG.tr["TuningIn"] = "Ayarlanıyor"
    LANG.tr["KeyBinds"] = "Tuş atamaları"
    LANG.tr["ToOpenRadio"] = "radyo için aç"
    LANG.tr["Global"] = "Küresel"
    LANG.tr["Custom"] = "Özel radyo istasyonları"
    
    -- Chinese (Simplified)
    LANG.zh_cn["SelectCountry"] = "选择国家"
    LANG.zh_cn["StopRadio"] = "停止"
    LANG.zh_cn["SearchPlaceholder"] = "搜索..."
    LANG.zh_cn["PressKeyToOpen"] = "按 {key} 选择电台"
    LANG.zh_cn["NoStations"] = "警告: 未找到 {country} 的电台"
    LANG.zh_cn["Interact"] = "按 E 互动"
    LANG.zh_cn["PAUSED"] = "暂停"
    LANG.zh_cn["Settings"] = "设置"
    LANG.zh_cn["LanguageSelection"] = "语言选择"
    LANG.zh_cn["ThemeSelection"] = "主题选择"
    LANG.zh_cn["SelectTheme"] = "选择主题"
    LANG.zh_cn["SelectLanguage"] = "选择语言"
    LANG.zh_cn["SelectKey"] = "选择车载电台按键"
    LANG.zh_cn["GeneralOptions"] = "常规选项"
    LANG.zh_cn["ShowCarMessages"] = "进入时显示动画"
    LANG.zh_cn["ShowBoomboxHUD"] = "显示便携收音机界面"
    LANG.zh_cn["BasicBoomboxHUD"] = "简单HUD"
    LANG.zh_cn["Contribute"] = "想要贡献吗？"
    LANG.zh_cn["SubmitPullRequest"] = "提交合并请求 :)"
    LANG.zh_cn["SuperadminSettings"] = "超级管理员设置"
    LANG.zh_cn["MakeBoomboxPermanent"] = "将便携收音机设为永久"
    LANG.zh_cn["Enabled"] = "启用"
    LANG.zh_cn["Disabled"] = "禁用"
    LANG.zh_cn["FavoriteStations"] = "收藏电台"
    LANG.zh_cn["TuningIn"] = "调谐中"
    LANG.zh_cn["KeyBinds"] = "按键绑定"
    LANG.zh_cn["ToOpenRadio"] = "打开收音机"
    LANG.zh_cn["Global"] = "全球"
    LANG.zh_cn["Custom"] = "自定义电台"
    
    -- Bulgarian
    LANG.bg["SelectCountry"] = "Изберете държава"
    LANG.bg["StopRadio"] = "СТОП"
    LANG.bg["SearchPlaceholder"] = "Търсене..."
    LANG.bg["PressKeyToOpen"] = "Натиснете {key}, за да изберете станция"
    LANG.bg["NoStations"] = "Предупреждение: Няма намерени станции за {country}"
    LANG.bg["Interact"] = "Натиснете E за взаимодействие"
    LANG.bg["PAUSED"] = "ПАУЗА"
    LANG.bg["Settings"] = "Настройки"
    LANG.bg["LanguageSelection"] = "Избор на език"
    LANG.bg["ThemeSelection"] = "Избор на тема"
    LANG.bg["SelectTheme"] = "Изберете тема"
    LANG.bg["SelectLanguage"] = "Изберете език"
    LANG.bg["SelectKey"] = "Изберете клавиш за менюто"
    LANG.bg["GeneralOptions"] = "Общи настройки"
    LANG.bg["ShowCarMessages"] = "Покажи анимация при влизане"
    LANG.bg["ShowBoomboxHUD"] = "Покажи интерфейс на Boombox"
    LANG.bg["BasicBoomboxHUD"] = "Опростен HUD"
    LANG.bg["Contribute"] = "Искате ли да допринесете?"
    LANG.bg["SubmitPullRequest"] = "Изпратете заявка за промяна :)"
    LANG.bg["SuperadminSettings"] = "Супер администратор"
    LANG.bg["MakeBoomboxPermanent"] = "Направете Boombox постоянен"
    LANG.bg["Enabled"] = "Активирано"
    LANG.bg["Disabled"] = "Деактивирано"
    LANG.bg["FavoriteStations"] = "Любими станции"
    LANG.bg["TuningIn"] = "Настройване"
    LANG.bg["KeyBinds"] = "Клавишни връзки"
    LANG.bg["ToOpenRadio"] = "за да отворите радиото"
    LANG.bg["Global"] = "Глобално"
    LANG.bg["Custom"] = "Потребителски радиостанции"
    
    -- Greek
    LANG.el["SelectCountry"] = "Επιλέξτε χώρα"
    LANG.el["StopRadio"] = "ΣΤΟΠ"
    LANG.el["SearchPlaceholder"] = "Αναζήτηση..."
    LANG.el["PressKeyToOpen"] = "Πατήστε {key} για να επιλέξετε σταθμό"
    LANG.el["NoStations"] = "Προειδοποίηση: Δεν βρέθηκαν σταθμοί για {country}"
    LANG.el["Interact"] = "Πατήστε E για αλληλεπίδραση"
    LANG.el["PAUSED"] = "ΠΑΥΣΗ"
    LANG.el["Settings"] = "Ρυθμίσεις"
    LANG.el["LanguageSelection"] = "Επιλογή γλώσσας"
    LANG.el["ThemeSelection"] = "Επιλογή θέματος"
    LANG.el["SelectTheme"] = "Επιλέξτε θέμα"
    LANG.el["SelectLanguage"] = "Επιλέξτε γλώσσα"
    LANG.el["SelectKey"] = "Επιλέξτε πλήκτρο για μενού"
    LANG.el["GeneralOptions"] = "Γενικές επιλογές"
    LANG.el["ShowCarMessages"] = "Εμφάνιση animation εισόδου"
    LANG.el["ShowBoomboxHUD"] = "Εμφάνιση Boombox HUD"
    LANG.el["BasicBoomboxHUD"] = "Απλή HUD"
    LANG.el["Contribute"] = "Θέλετε να συνεισφέρετε;"
    LANG.el["SubmitPullRequest"] = "Υποβάλετε Pull Request :)"
    LANG.el["SuperadminSettings"] = "Υπερδιαχειριστής"
    LANG.el["MakeBoomboxPermanent"] = "Κάντε Boombox μόνιμο"
    LANG.el["Enabled"] = "Ενεργό"
    LANG.el["Disabled"] = "Απενεργό"
    LANG.el["FavoriteStations"] = "Αγαπημένοι σταθμοί"
    LANG.el["TuningIn"] = "Συντονισμός"
    LANG.el["KeyBinds"] = "Πλήκτρα"
    LANG.el["ToOpenRadio"] = "για άνοιγμα ραδιοφώνου"
    LANG.el["Global"] = "Παγκόσμιο"
    LANG.el["Custom"] = "Προσαρμοσμένες ραδιοφωνικές σταθμοί"
    
    -- Croatian
    LANG.hr["SelectCountry"] = "Odaberite državu"
    LANG.hr["StopRadio"] = "STOP"
    LANG.hr["SearchPlaceholder"] = "Pretraži..."
    LANG.hr["PressKeyToOpen"] = "Pritisnite {key} za odabir stanice"
    LANG.hr["NoStations"] = "Upozorenje: Nema stanica za {country}"
    LANG.hr["Interact"] = "Pritisnite E za interakciju"
    LANG.hr["PAUSED"] = "PAUZA"
    LANG.hr["Settings"] = "Postavke"
    LANG.hr["LanguageSelection"] = "Odabir jezika"
    LANG.hr["ThemeSelection"] = "Odabir teme"
    LANG.hr["SelectTheme"] = "Odaberite temu"
    LANG.hr["SelectLanguage"] = "Odaberite jezik"
    LANG.hr["SelectKey"] = "Odaberite tipku za meni"
    LANG.hr["GeneralOptions"] = "Opšte opcije"
    LANG.hr["ShowCarMessages"] = "Prikaži animaciju pri ulasku"
    LANG.hr["ShowBoomboxHUD"] = "Prikaži Boombox HUD"
    LANG.hr["BasicBoomboxHUD"] = "Osnovni HUD"
    LANG.hr["Contribute"] = "Želite li pomoći?"
    LANG.hr["SubmitPullRequest"] = "Pošaljite Pull Request :)"
    LANG.hr["SuperadminSettings"] = "Superadmin"
    LANG.hr["MakeBoomboxPermanent"] = "Učinite Boombox trajnim"
    LANG.hr["Enabled"] = "Omogućeno"
    LANG.hr["Disabled"] = "Onemogućeno"
    LANG.hr["FavoriteStations"] = "Omiljene stanice"
    LANG.hr["TuningIn"] = "Usklađivanje"
    LANG.hr["KeyBinds"] = "Dodjela tipki"
    LANG.hr["ToOpenRadio"] = "za otvaranje"
    LANG.hr["Global"] = "Globalno"
    LANG.hr["Custom"] = "Prilagođene radio stanice"
    
    -- Hebrew
    LANG.he["SelectCountry"] = "בחר מדינה"
    LANG.he["StopRadio"] = "עצור"
    LANG.he["SearchPlaceholder"] = "חיפוש..."
    LANG.he["PressKeyToOpen"] = "לחץ על {key} כדי לבחור תחנה"
    LANG.he["NoStations"] = "אזהרה: לא נמצאו תחנות עבור {country}"
    LANG.he["Interact"] = "לחץ E לאינטראקציה"
    LANG.he["PAUSED"] = "מושהה"
    LANG.he["Settings"] = "הגדרות"
    LANG.he["LanguageSelection"] = "בחירת שפה"
    LANG.he["ThemeSelection"] = "בחירת ערכת נושא"
    LANG.he["SelectTheme"] = "בחר ערכת נושא"
    LANG.he["SelectLanguage"] = "בחר שפה"
    LANG.he["SelectKey"] = "בחר מקש לתפריט הרדיו"
    LANG.he["GeneralOptions"] = "אפשרויות כלליות"
    LANG.he["ShowCarMessages"] = "הצג אנימציה בכניסה לרכב"
    LANG.he["ShowBoomboxHUD"] = "הצג ממשק רדיו נייד"
    LANG.he["BasicBoomboxHUD"] = "ממשק בסיסי"
    LANG.he["Contribute"] = "רוצה לתרום?"
    LANG.he["SubmitPullRequest"] = "שלח Pull Request :)"
    LANG.he["SuperadminSettings"] = "הגדרות מנהל ראשי"
    LANG.he["MakeBoomboxPermanent"] = "הפוך רדיו נייד לקבוע"
    LANG.he["Enabled"] = "מופעל"
    LANG.he["Disabled"] = "מושבת"
    LANG.he["FavoriteStations"] = "תחנות מועדפות"
    LANG.he["TuningIn"] = "מכוון"
    LANG.he["KeyBinds"] = "הגדרות מקשים"
    LANG.he["ToOpenRadio"] = "לפתיחת הרדיו"
    LANG.he["Global"] = "גלובלי"
    LANG.he["Custom"] = "תחנות רדיו מותאמות אישית"
    
    -- Slovak
    LANG.sk["SelectCountry"] = "Vyberte krajinu"
    LANG.sk["StopRadio"] = "STOP"
    LANG.sk["SearchPlaceholder"] = "Hľadať..."
    LANG.sk["PressKeyToOpen"] = "Stlačte {key} pre výber stanice"
    LANG.sk["NoStations"] = "Upozornenie: Žiadne stanice pre {country}"
    LANG.sk["Interact"] = "Stlačte E na interakciu"
    LANG.sk["PAUSED"] = "POZASTAVENÉ"
    LANG.sk["Settings"] = "Nastavenia"
    LANG.sk["LanguageSelection"] = "Výber jazyka"
    LANG.sk["ThemeSelection"] = "Výber témy"
    LANG.sk["SelectTheme"] = "Vyberte tému"
    LANG.sk["SelectLanguage"] = "Vyberte jazyk"
    LANG.sk["SelectKey"] = "Vyberte kláves pre menu"
    LANG.sk["GeneralOptions"] = "Všeobecné možnosti"
    LANG.sk["ShowCarMessages"] = "Zobraziť animáciu pri vstupe"
    LANG.sk["ShowBoomboxHUD"] = "Zobraziť Boombox rozhranie"
    LANG.sk["BasicBoomboxHUD"] = "Základný HUD"
    LANG.sk["Contribute"] = "Chcete prispieť?"
    LANG.sk["SubmitPullRequest"] = "Odošlite Pull Request :)"
    LANG.sk["SuperadminSettings"] = "Superadmin"
    LANG.sk["MakeBoomboxPermanent"] = "Urobiť Boombox trvalým"
    LANG.sk["Enabled"] = "Povolené"
    LANG.sk["Disabled"] = "Zakázané"
    LANG.sk["FavoriteStations"] = "Obľúbené stanice"
    LANG.sk["TuningIn"] = "Ladenie"
    LANG.sk["KeyBinds"] = "Klávesové väzby"
    LANG.sk["ToOpenRadio"] = "na otvorenie"
    LANG.sk["Global"] = "Globálne"
    LANG.sk["Custom"] = "Používateľské rádio stanice"
    
    -- Danish
    LANG.da["SelectCountry"] = "Vælg et land"
    LANG.da["StopRadio"] = "STOP"
    LANG.da["SearchPlaceholder"] = "Søg..."
    LANG.da["PressKeyToOpen"] = "Tryk på {key} for at vælge en station"
    LANG.da["NoStations"] = "Advarsel: Ingen stationer for {country}"
    LANG.da["Interact"] = "Tryk på E for at interagere"
    LANG.da["PAUSED"] = "PAUSE"
    LANG.da["Settings"] = "Indstillinger"
    LANG.da["LanguageSelection"] = "Sprogvalg"
    LANG.da["ThemeSelection"] = "Temavalg"
    LANG.da["SelectTheme"] = "Vælg tema"
    LANG.da["SelectLanguage"] = "Vælg sprog"
    LANG.da["SelectKey"] = "Vælg tast til menu"
    LANG.da["GeneralOptions"] = "Generelle indstillinger"
    LANG.da["ShowCarMessages"] = "Vis anim ved indstigning"
    LANG.da["ShowBoomboxHUD"] = "Vis Boombox HUD"
    LANG.da["BasicBoomboxHUD"] = "Grundlæggende HUD"
    LANG.da["Contribute"] = "Vil du bidrage?"
    LANG.da["SubmitPullRequest"] = "Indsend Pull Request :)"
    LANG.da["SuperadminSettings"] = "Superadmin"
    LANG.da["MakeBoomboxPermanent"] = "Gør Boombox permanent"
    LANG.da["Enabled"] = "Aktiveret"
    LANG.da["Disabled"] = "Deaktiveret"
    LANG.da["FavoriteStations"] = "Favoritstationer"
    LANG.da["TuningIn"] = "Tuner ind"
    LANG.da["KeyBinds"] = "Tastbindinger"
    LANG.da["ToOpenRadio"] = "for at åbne"
    LANG.da["Global"] = "Globalt"
    LANG.da["Custom"] = "Tilpassede radiostationer"
    
    -- Dutch
    LANG.nl["SelectCountry"] = "Selecteer een land"
    LANG.nl["StopRadio"] = "STOP"
    LANG.nl["SearchPlaceholder"] = "Zoeken..."
    LANG.nl["PressKeyToOpen"] = "Druk op {key} om te kiezen"
    LANG.nl["NoStations"] = "Waarschuwing: Geen zenders voor {country}"
    LANG.nl["Interact"] = "Druk op E om te interageren"
    LANG.nl["PAUSED"] = "GEPAUZEERD"
    LANG.nl["Settings"] = "Instellingen"
    LANG.nl["LanguageSelection"] = "Taalkeuze"
    LANG.nl["ThemeSelection"] = "Themakeuze"
    LANG.nl["SelectTheme"] = "Selecteer thema"
    LANG.nl["SelectLanguage"] = "Selecteer taal"
    LANG.nl["SelectKey"] = "Selecteer toets for menu"
    LANG.nl["GeneralOptions"] = "Algemene opties"
    LANG.nl["ShowCarMessages"] = "Toon anim bij instappen"
    LANG.nl["ShowBoomboxHUD"] = "Toon Boombox interface"
    LANG.nl["BasicBoomboxHUD"] = "Eenvoudige HUD"
    LANG.nl["Contribute"] = "Wil je bijdragen?"
    LANG.nl["SubmitPullRequest"] = "Dien Pull Request in :)"
    LANG.nl["SuperadminSettings"] = "Superadmin"
    LANG.nl["MakeBoomboxPermanent"] = "Maak Boombox permanent"
    LANG.nl["Enabled"] = "Ingeschakeld"
    LANG.nl["Disabled"] = "Uitgeschakeld"
    LANG.nl["FavoriteStations"] = "Favoriete zenders"
    LANG.nl["TuningIn"] = "Afstemmen"
    LANG.nl["KeyBinds"] = "Toetsbindingen"
    LANG.nl["ToOpenRadio"] = "om te openen"
    LANG.nl["Global"] = "Wereldwijd"
    LANG.nl["Custom"] = "Aangepaste radiostations"
    
    -- Thai
    LANG.th["SelectCountry"] = "เลือกประเทศ"
    LANG.th["StopRadio"] = "หยุด"
    LANG.th["SearchPlaceholder"] = "ค้นหา..."
    LANG.th["PressKeyToOpen"] = "กด {key} เพื่อเลือก"
    LANG.th["NoStations"] = "คำเตือน: ไม่มีสถานีของ {country}"
    LANG.th["Interact"] = "กด E เพื่อโต้ตอบ"
    LANG.th["PAUSED"] = "หยุดชั่วคราว"
    LANG.th["Settings"] = "การตั้งค่า"
    LANG.th["LanguageSelection"] = "เลือกภาษา"
    LANG.th["ThemeSelection"] = "เลือกธีม"
    LANG.th["SelectTheme"] = "เลือกธีม"
    LANG.th["SelectLanguage"] = "เลือกภาษา"
    LANG.th["SelectKey"] = "เลือกปุ่มเมนู"
    LANG.th["GeneralOptions"] = "ตัวเลือกทั่วไป"
    LANG.th["ShowCarMessages"] = "แสดงแอนิเมชันเมื่อเข้า"
    LANG.th["ShowBoomboxHUD"] = "แสดง Boombox UI"
    LANG.th["BasicBoomboxHUD"] = "HUD พื้นฐาน"
    LANG.th["Contribute"] = "ต้องการช่วยไหม?"
    LANG.th["SubmitPullRequest"] = "ส่ง Pull Request :)"
    LANG.th["SuperadminSettings"] = "ซูเปอร์แอดมิน"
    LANG.th["MakeBoomboxPermanent"] = "ทำให้ถาวร"
    LANG.th["Enabled"] = "เปิด"
    LANG.th["Disabled"] = "ปิด"
    LANG.th["FavoriteStations"] = "สถานีโปรด"
    LANG.th["TuningIn"] = "ปรับจูน"
    LANG.th["KeyBinds"] = "ผูกคีย์"
    LANG.th["ToOpenRadio"] = "เพื่อเปิด"
    LANG.th["Global"] = "ทั่วโลก"
    LANG.th["Custom"] = "สถานีวิทยุแบบกำหนดเอง"
    
    -- Vietnamese
    LANG.vi["SelectCountry"] = "Chọn quốc gia"
    LANG.vi["StopRadio"] = "DỪNG"
    LANG.vi["SearchPlaceholder"] = "Tìm kiếm..."
    LANG.vi["PressKeyToOpen"] = "Nhấn {key} để chọn"
    LANG.vi["NoStations"] = "Cảnh báo: Không có đài của {country}"
    LANG.vi["Interact"] = "Nhấn E để tương tác"
    LANG.vi["PAUSED"] = "TẠM DỪNG"
    LANG.vi["Settings"] = "Cài đặt"
    LANG.vi["LanguageSelection"] = "Chọn ngôn ngữ"
    LANG.vi["ThemeSelection"] = "Chọn chủ đề"
    LANG.vi["SelectTheme"] = "Chọn giao diện"
    LANG.vi["SelectLanguage"] = "Chọn ngôn ngữ"
    LANG.vi["SelectKey"] = "Chọn phím"
    LANG.vi["GeneralOptions"] = "Tùy chọn chung"
    LANG.vi["ShowCarMessages"] = "Hiển thị hoạt ảnh khi vào"
    LANG.vi["ShowBoomboxHUD"] = "Hiển thị Boombox UI"
    LANG.vi["BasicBoomboxHUD"] = "HUD cơ bản"
    LANG.vi["Contribute"] = "Muốn đóng góp?"
    LANG.vi["SubmitPullRequest"] = "Gửi Pull Request :)"
    LANG.vi["SuperadminSettings"] = "Siêu quản trị"
    LANG.vi["MakeBoomboxPermanent"] = "Giữ vĩnh viễn"
    LANG.vi["Enabled"] = "Bật"
    LANG.vi["Disabled"] = "Tắt"
    LANG.vi["FavoriteStations"] = "Đài yêu thích"
    LANG.vi["TuningIn"] = "Đang dò"
    LANG.vi["KeyBinds"] = "Phím tắt"
    LANG.vi["ToOpenRadio"] = "để mở"
    LANG.vi["Global"] = "Toàn cầu"
    LANG.vi["Custom"] = "Trạm phát thanh tùy chỉnh"
    
    -- Hungarian
    LANG.hu["SelectCountry"] = "Válassz országot"
    LANG.hu["StopRadio"] = "MEGÁLLÍTÁS"
    LANG.hu["SearchPlaceholder"] = "Keresés..."
    LANG.hu["PressKeyToOpen"] = "Nyomd meg a(z) {key} gombot"
    LANG.hu["NoStations"] = "Figyelem: Nincsenek állomások {country}"
    LANG.hu["Interact"] = "Nyomj E-t a művelethez"
    LANG.hu["PAUSED"] = "SZÜNETELTETVE"
    LANG.hu["Settings"] = "Beállítások"
    LANG.hu["LanguageSelection"] = "Nyelvválasztás"
    LANG.hu["ThemeSelection"] = "Téma kiválasztása"
    LANG.hu["SelectTheme"] = "Téma kiválasztása"
    LANG.hu["SelectLanguage"] = "Nyelv kiválasztása"
    LANG.hu["SelectKey"] = "Válassz gombot"
    LANG.hu["GeneralOptions"] = "Általános beállítások"
    LANG.hu["ShowCarMessages"] = "Animáció beszálláskor"
    LANG.hu["ShowBoomboxHUD"] = "Boombox felület mutatása"
    LANG.hu["BasicBoomboxHUD"] = "Egyszerű HUD"
    LANG.hu["Contribute"] = "Szeretnél segíteni?"
    LANG.hu["SubmitPullRequest"] = "Küldj Pull Requestet :)"
    LANG.hu["SuperadminSettings"] = "Szuperadmin"
    LANG.hu["MakeBoomboxPermanent"] = "Állandóvá tesz"
    LANG.hu["Enabled"] = "Engedélyezve"
    LANG.hu["Disabled"] = "Letiltva"
    LANG.hu["FavoriteStations"] = "Kedvenc állomások"
    LANG.hu["TuningIn"] = "Hangolás"
    LANG.hu["KeyBinds"] = "Billentyűkiosztás"
    LANG.hu["ToOpenRadio"] = "megnyitáshoz"
    LANG.hu["Global"] = "Globális"
    LANG.hu["Custom"] = "Egyéni rádióállomások"
    
    -- Lithuanian
    LANG.lt["SelectCountry"] = "Pasirinkite šalį"
    LANG.lt["StopRadio"] = "SUSTABDYTI"
    LANG.lt["SearchPlaceholder"] = "Paieška..."
    LANG.lt["PressKeyToOpen"] = "Paspauskite {key}"
    LANG.lt["NoStations"] = "Įspėjimas: Nėra stočių {country}"
    LANG.lt["Interact"] = "Paspauskite E"
    LANG.lt["PAUSED"] = "PRISTABDYTA"
    LANG.lt["Settings"] = "Nustatymai"
    LANG.lt["LanguageSelection"] = "Kalbos pasirinkimas"
    LANG.lt["ThemeSelection"] = "Temos pasirinkimas"
    LANG.lt["SelectTheme"] = "Pasirinkti temą"
    LANG.lt["SelectLanguage"] = "Pasirinkti kalbą"
    LANG.lt["SelectKey"] = "Pasirinkite klavišą"
    LANG.lt["GeneralOptions"] = "Bendros parinktys"
    LANG.lt["ShowCarMessages"] = "Rodyti animaciją įlipant"
    LANG.lt["ShowBoomboxHUD"] = "Rodyti Boombox sąsają"
    LANG.lt["BasicBoomboxHUD"] = "Paprastas HUD"
    LANG.lt["Contribute"] = "Norite prisidėti?"
    LANG.lt["SubmitPullRequest"] = "Pateikite Pull Request :)"
    LANG.lt["SuperadminSettings"] = "Super administratoriaus"
    LANG.lt["MakeBoomboxPermanent"] = "Padaryti nuolatiniu"
    LANG.lt["Enabled"] = "Įjungta"
    LANG.lt["Disabled"] = "Išjungta"
    LANG.lt["FavoriteStations"] = "Mėgstamos stotys"
    LANG.lt["TuningIn"] = "Derinimas"
    LANG.lt["KeyBinds"] = "Raktų priskyrimai"
    LANG.lt["ToOpenRadio"] = "atidaryti"
    LANG.lt["Global"] = "Visuotinis"
    LANG.lt["Custom"] = "Savitaip pasirinktos radijo stotys"
    
    -- Ukrainian
    LANG.uk["SelectCountry"] = "Оберіть країну"
    LANG.uk["StopRadio"] = "СТОП"
    LANG.uk["SearchPlaceholder"] = "Пошук..."
    LANG.uk["PressKeyToOpen"] = "Натисніть {key}"
    LANG.uk["NoStations"] = "Попередження: Нема станцій {country}"
    LANG.uk["Interact"] = "Натисніть E"
    LANG.uk["PAUSED"] = "ПРИЗУПИНЕНО"
    LANG.uk["Settings"] = "Налаштування"
    LANG.uk["LanguageSelection"] = "Вибір мови"
    LANG.uk["ThemeSelection"] = "Вибір теми"
    LANG.uk["SelectTheme"] = "Оберіть тему"
    LANG.uk["SelectLanguage"] = "Оберіть мову"
    LANG.uk["SelectKey"] = "Оберіть клавішу"
    LANG.uk["GeneralOptions"] = "Загальні параметри"
    LANG.uk["ShowCarMessages"] = "Показати анімацію входу"
    LANG.uk["ShowBoomboxHUD"] = "Показати Boombox"
    LANG.uk["BasicBoomboxHUD"] = "Простий HUD"
    LANG.uk["Contribute"] = "Хочете допомогти?"
    LANG.uk["SubmitPullRequest"] = "Надішліть Pull Request :)"
    LANG.uk["SuperadminSettings"] = "Суперадмін"
    LANG.uk["MakeBoomboxPermanent"] = "Зробити постійним"
    LANG.uk["Enabled"] = "Увімкнено"
    LANG.uk["Disabled"] = "Вимкнено"
    LANG.uk["FavoriteStations"] = "Улюблені станції"
    LANG.uk["TuningIn"] = "Налаштування"
    LANG.uk["KeyBinds"] = "Клавіші"
    LANG.uk["ToOpenRadio"] = "щоб відкрити"
    LANG.uk["Global"] = "Глобальний"
    LANG.uk["Custom"] = "Власні радіостанції"
end

local function applyThemeTranslations()
    for langCode, translations in pairs( THEME_TRANSLATIONS ) do
        local langTable = LANG[langCode]
        if langTable then
            for themeName, label in pairs( translations ) do
                langTable[themeName] = label
            end
        end
    end
end

-- Initialize all translations
defineTranslations()
applyThemeTranslations()

-- Utility functions for the localization system
LANG.GetLanguageInfo = function( langCode )
    return LANGUAGE_INFO[langCode]
end

LANG.GetAvailableLanguages = function()
    local languages = {}
    
    for code, info in pairs( LANGUAGE_INFO ) do
        languages[code] = info.name
    end
    
    return languages
end

LANG.IsRTL = function( langCode )
    local info = LANGUAGE_INFO[langCode]
    return info and info.rtl or false
end

LANG.GetTranslation = function( langCode, key, fallbackLang )
    fallbackLang = fallbackLang or "en"
    
    -- Try to get translation from requested language
    if LANG[langCode] and LANG[langCode][key] then
        return LANG[langCode][key]
    end
    
    -- Fallback to English
    if LANG[fallbackLang] and LANG[fallbackLang][key] then
        return LANG[fallbackLang][key]
    end
    
    -- Return key if no translation found
    return key
end

LANG.FormatTranslation = function( langCode, key, replacements, fallbackLang )
    local translation = LANG.GetTranslation( langCode, key, fallbackLang )
    
    -- Replace placeholders
    if replacements then
        for placeholder, value in pairs( replacements ) do
            translation = string.gsub( translation, "{" .. placeholder .. "}", tostring( value ) )
        end
    end
    
    return translation
end

return LANG