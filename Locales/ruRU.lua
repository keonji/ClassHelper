-- Locales/ruRU.lua: Russian overrides for visible MVP keys. Item and spell names
-- are never stored here. Test-only keys are intentionally absent so the enUS
-- fallback is exercised.

local addonName, ns = ...

local L = ns.L
L.catalog = L.catalog or {}

local ruRU = {
    ITEM_STATE_LOADING = "Загрузка",
    ITEM_STATE_FAILED = "Данные недоступны или время ожидания истекло",

    BATCH_PROGRESS = "Загружено %d / %d",
    BATCH_PROGRESS_FAILED = "Загружено %d / %d, с ошибкой %d",
    BATCH_TOO_LARGE = "Слишком много предметов; запросите их по одному",
    BATCH_REQUEST = "Запросить данные с сервера для всех предметов",

    TAB_GUIDE = "Руководство",
    TAB_ENCHANTMENTS = "Чары и камни",
    TAB_CONSUMABLES = "Расходники",
    TAB_TRINKETS = "Тринкеты",
    TAB_GEAR = "Лучшая экипировка",

    SECTION_OVERVIEW = "Обзор",
    SECTION_STAT_PRIORITY = "Приоритет характеристик",
    SECTION_TALENTS = "Таланты",
    SECTION_ROTATION = "Ротация",

    RACE_HUMAN = "Человек",
    SPEC_RETRIBUTION = "Воздаяние",
    SPEC_HOLY = "Свет",
    SPEC_PROTECTION = "Защита",

    STAGE_CLASSIC_PRE_RAID = "До рейдовых подземелий",
    STAGE_CLASSIC_MOLTEN_CORE = "Огненные Недры",
    STAGE_CLASSIC_ONYXIA = "Логово Ониксии",
    STAGE_CLASSIC_BWL = "Чёрная Гора",
    STAGE_CLASSIC_ZG = "Зул'Гуруб",
    STAGE_CLASSIC_AQ20 = "Руины Ан'Киража",
    STAGE_CLASSIC_AQ40 = "Храм Ан'Киража",

    STAGE_TBC_PRE_RAID = "Подземелья 70 уровня",
    STAGE_TBC_GRUUL_MAGTHERIDON = "Груул и Магтеридон",
    STAGE_TBC_KARAZHAN = "Каражан",
    STAGE_TBC_OGRILA = "Огри'ла",
    STAGE_TBC_SERPENTSHRINE = "Змеиное Святилище",
    STAGE_TBC_TEMPEST_KEEP = "Цитадель Бурь и Стражи Небесного Затынка",
    STAGE_TBC_HYJAL = "Битва за гору Хьязал и Крыло Бездны",
    STAGE_TBC_BLACK_TEMPLE = "Чёрный Храм",
    STAGE_TBC_ZULAMAN = "Зул'Аман",
    STAGE_TBC_ISLE = "Остров Кел'Данас и Терраса Магистров",
    STAGE_TBC_SUNWELL = "Плато Солнечного Колодца",

    STAGE_WRATH_NORMAL_DUNGEONS = "Обычные подземелья 80 уровня",
    STAGE_WRATH_HEROIC_DUNGEONS = "Героические подземелья 80 уровня",
    STAGE_WRATH_TIER_7 = "Наксрамас, Око Вечности, Обсидиановое Свидалище",
    STAGE_WRATH_ULDUAR = "Ульдуар",
    STAGE_WRATH_CRUSADERS_COLISEUM = "Ониксия и Колизей Испытателей",
    STAGE_WRATH_ICECROWN = "Цитадель Ледяной Короны и Залы Ледяных Пустот",
    STAGE_WRATH_RUBY_SANCTUM = "Рубиновое Святилище",
}
L.catalog.ruRU = ruRU
