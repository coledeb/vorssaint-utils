// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct AudioDeviceIconStrings {
    let devices: String
    let icons: String
    let caption: String
    let input: String
    let automatic: String
    let change: String
    let reset: String
    let search: String
    let noMatches: String
    let shared: String
    let showAllSymbols: String
    let done: String

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS: return Self(
            devices: "Audio devices",
            icons: "Device icons",
            caption: "Choose the icons used for your devices throughout Vorssaint.",
            input: "Input",
            automatic: "Automatic",
            change: "Change",
            reset: "Reset to default",
            search: "Search macOS symbols",
            noMatches: "No matching symbols",
            shared: "Changes apply everywhere this device appears.",
            showAllSymbols: "Show all symbols",
            done: "Done")
        case .ptBR: return Self(
            devices: "Dispositivos de áudio",
            icons: "Ícones dos dispositivos",
            caption: "Escolha os ícones dos dispositivos em todo o Vorssaint.",
            input: "Entrada",
            automatic: "Automático",
            change: "Alterar",
            reset: "Restaurar padrão",
            search: "Buscar símbolos do macOS",
            noMatches: "Nenhum símbolo encontrado",
            shared: "As alterações se aplicam onde este dispositivo aparecer.",
            showAllSymbols: "Mostrar todos os símbolos",
            done: "Concluído")
        case .es: return Self(
            devices: "Dispositivos de audio",
            icons: "Iconos de dispositivos",
            caption: "Elige los iconos de tus dispositivos en Vorssaint.",
            input: "Entrada",
            automatic: "Automático",
            change: "Cambiar",
            reset: "Restablecer valores predeterminados",
            search: "Buscar símbolos de macOS",
            noMatches: "No hay símbolos coincidentes",
            shared: "Los cambios se aplican donde aparezca este dispositivo.",
            showAllSymbols: "Mostrar todos los símbolos",
            done: "Listo")
        case .fr: return Self(
            devices: "Périphériques audio",
            icons: "Icônes des périphériques",
            caption: "Choisissez les icônes de vos périphériques dans Vorssaint.",
            input: "Entrée",
            automatic: "Automatique",
            change: "Modifier",
            reset: "Rétablir par défaut",
            search: "Rechercher des symboles macOS",
            noMatches: "Aucun symbole correspondant",
            shared: "Les modifications s’appliquent partout où ce périphérique apparaît.",
            showAllSymbols: "Afficher tous les symboles",
            done: "Terminé")
        case .de: return Self(
            devices: "Audiogeräte",
            icons: "Gerätesymbole",
            caption: "Wähle die Symbole deiner Geräte in Vorssaint.",
            input: "Eingabe",
            automatic: "Automatisch",
            change: "Ändern",
            reset: "Auf Standard zurücksetzen",
            search: "macOS-Symbole suchen",
            noMatches: "Keine passenden Symbole",
            shared: "Änderungen gelten überall, wo dieses Gerät erscheint.",
            showAllSymbols: "Alle Symbole anzeigen",
            done: "Fertig")
        case .it: return Self(
            devices: "Dispositivi audio",
            icons: "Icone dei dispositivi",
            caption: "Scegli le icone dei dispositivi in Vorssaint.",
            input: "Ingresso",
            automatic: "Automatico",
            change: "Modifica",
            reset: "Ripristina predefinito",
            search: "Cerca simboli macOS",
            noMatches: "Nessun simbolo corrispondente",
            shared: "Le modifiche si applicano ovunque appaia questo dispositivo.",
            showAllSymbols: "Mostra tutti i simboli",
            done: "Fine")
        case .uk: return Self(
            devices: "Аудіопристрої",
            icons: "Значки пристроїв",
            caption: "Виберіть значки пристроїв у Vorssaint.",
            input: "Вхід",
            automatic: "Автоматично",
            change: "Змінити",
            reset: "Відновити стандартний",
            search: "Пошук символів macOS",
            noMatches: "Символів не знайдено",
            shared: "Зміни застосовуються всюди, де з’являється цей пристрій.",
            showAllSymbols: "Показати всі символи",
            done: "Готово")
        case .ru: return Self(
            devices: "Аудиоустройства",
            icons: "Значки устройств",
            caption: "Выберите значки устройств в Vorssaint.",
            input: "Вход",
            automatic: "Автоматически",
            change: "Изменить",
            reset: "Сбросить по умолчанию",
            search: "Поиск символов macOS",
            noMatches: "Символы не найдены",
            shared: "Изменения применяются везде, где появляется это устройство.",
            showAllSymbols: "Показать все символы",
            done: "Готово")
        case .ja: return Self(
            devices: "オーディオデバイス",
            icons: "デバイスのアイコン",
            caption: "Vorssaint 全体で使うデバイスのアイコンを選択します。",
            input: "入力",
            automatic: "自動",
            change: "変更",
            reset: "デフォルトに戻す",
            search: "macOS のシンボルを検索",
            noMatches: "一致するシンボルがありません",
            shared: "このデバイスが表示されるすべての場所に適用されます。",
            showAllSymbols: "すべてのシンボルを表示",
            done: "完了")
        case .ko: return Self(
            devices: "오디오 기기",
            icons: "기기 아이콘",
            caption: "Vorssaint에서 사용할 기기 아이콘을 선택하세요.",
            input: "입력",
            automatic: "자동",
            change: "변경",
            reset: "기본값으로 재설정",
            search: "macOS 기호 검색",
            noMatches: "일치하는 기호 없음",
            shared: "이 기기가 표시되는 모든 곳에 적용됩니다.",
            showAllSymbols: "모든 기호 표시",
            done: "완료")
        case .zhHans: return Self(
            devices: "音频设备",
            icons: "设备图标",
            caption: "选择在 Vorssaint 中使用的设备图标。",
            input: "输入",
            automatic: "自动",
            change: "更改",
            reset: "恢复默认",
            search: "搜索 macOS 符号",
            noMatches: "没有匹配的符号",
            shared: "更改将应用于显示此设备的所有位置。",
            showAllSymbols: "显示所有符号",
            done: "完成")
        case .zhTW: return Self(
            devices: "音訊裝置",
            icons: "裝置圖示",
            caption: "選擇在 Vorssaint 中使用的裝置圖示。",
            input: "輸入",
            automatic: "自動",
            change: "更改",
            reset: "回復預設",
            search: "搜尋 macOS 符號",
            noMatches: "沒有符合的符號",
            shared: "更改將套用至顯示此裝置的所有位置。",
            showAllSymbols: "顯示所有符號",
            done: "完成")
        case .zhHK: return Self(
            devices: "音訊裝置",
            icons: "裝置圖示",
            caption: "選擇在 Vorssaint 中使用的裝置圖示。",
            input: "輸入",
            automatic: "自動",
            change: "更改",
            reset: "回復預設",
            search: "搜尋 macOS 符號",
            noMatches: "沒有符合的符號",
            shared: "更改將套用至顯示此裝置的所有位置。",
            showAllSymbols: "顯示所有符號",
            done: "完成")
        case .sk: return Self(
            devices: "Zvukové zariadenia",
            icons: "Ikony zariadení",
            caption: "Vyberte ikony zariadení vo Vorssaint.",
            input: "Vstup",
            automatic: "Automaticky",
            change: "Zmeniť",
            reset: "Obnoviť predvolené",
            search: "Hľadať symboly macOS",
            noMatches: "Žiadne zodpovedajúce symboly",
            shared: "Zmeny platia všade, kde sa toto zariadenie zobrazuje.",
            showAllSymbols: "Zobraziť všetky symboly",
            done: "Hotovo")
        case .tr: return Self(
            devices: "Ses aygıtları",
            icons: "Aygıt simgeleri",
            caption: "Vorssaint genelinde kullanılacak aygıt simgelerini seçin.",
            input: "Giriş",
            automatic: "Otomatik",
            change: "Değiştir",
            reset: "Varsayılana sıfırla",
            search: "macOS simgelerinde ara",
            noMatches: "Eşleşen simge yok",
            shared: "Değişiklikler bu aygıtın göründüğü her yerde geçerlidir.",
            showAllSymbols: "Tüm simgeleri göster",
            done: "Bitti")
        }
    }
}
