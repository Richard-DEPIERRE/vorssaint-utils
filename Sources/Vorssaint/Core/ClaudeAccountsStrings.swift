// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The Claude accounts the AI page gives limits cards of their own. Buttons
/// and card text shared with Codex accounts come from `CodexAccountStrings`.
struct ClaudeAccountsStrings {
    let title: String
    let explanation: String
    let fallback: String
    /// The Claude app data folder whose saved limits stand in for a profile.
    let appDataFormat: String
    let noAppData: String

    func appData(_ folder: String) -> String { String(format: appDataFormat, folder) }
}

extension FeatureStrings {
    static func claudeAccounts(_ language: AppLanguage) -> ClaudeAccountsStrings {
        switch language {
        case .enUS: return ClaudeAccountsStrings(
            title: "Claude accounts",
            explanation: "Each Claude Code profile you add gets its own limits card, and its sessions count toward spending. While the AI Agents page is open, Claude Code checks each one about every five minutes with that profile’s own sign-in. No prompt is sent.",
            fallback: "With no accounts added, Claude limits follow the account chosen above.",
            appDataFormat: "Claude app: %@",
            noAppData: "No Claude app linked")
        case .ptBR: return ClaudeAccountsStrings(
            title: "Contas do Claude",
            explanation: "Cada perfil do Claude Code adicionado ganha o próprio cartão de limites, e as sessões dele entram nos gastos. Enquanto a página Agentes de IA está aberta, o Claude Code verifica cada um aproximadamente a cada cinco minutos, com o login desse perfil. Nenhum prompt é enviado.",
            fallback: "Sem contas adicionadas, os limites do Claude seguem a conta escolhida acima.",
            appDataFormat: "App Claude: %@",
            noAppData: "Nenhum app Claude vinculado")
        case .tr: return ClaudeAccountsStrings(
            title: "Claude hesapları",
            explanation: "Eklediğiniz her Claude Code profili kendi sınır kartını alır ve oturumları harcamaya dahil edilir. Yapay Zekâ Ajanları sayfası açıkken Claude Code, her birini yaklaşık beş dakikada bir o profilin kendi oturumuyla denetler. Hiçbir istem gönderilmez.",
            fallback: "Hesap eklenmediğinde Claude sınırları yukarıda seçilen hesabı izler.",
            appDataFormat: "Claude uygulaması: %@",
            noAppData: "Bağlı Claude uygulaması yok")
        case .ru: return ClaudeAccountsStrings(
            title: "Аккаунты Claude",
            explanation: "Каждый добавленный профиль Claude Code получает собственную карточку лимитов, а его сеансы учитываются в расходах. Пока открыта страница ИИ-агентов, Claude Code проверяет каждый профиль примерно раз в пять минут с его собственным входом. Запросы не отправляются.",
            fallback: "Если аккаунты не добавлены, лимиты Claude берутся из аккаунта, выбранного выше.",
            appDataFormat: "Приложение Claude: %@",
            noAppData: "Приложение Claude не связано")
        case .es: return ClaudeAccountsStrings(
            title: "Cuentas de Claude",
            explanation: "Cada perfil de Claude Code que añada tiene su propia tarjeta de límites, y sus sesiones cuentan en el gasto. Mientras la página Agentes de IA está abierta, Claude Code comprueba cada uno cada cinco minutos aproximadamente con el inicio de sesión de ese perfil. No se envía ningún prompt.",
            fallback: "Sin cuentas añadidas, los límites de Claude siguen la cuenta elegida arriba.",
            appDataFormat: "App de Claude: %@",
            noAppData: "Ninguna app de Claude vinculada")
        case .sk: return ClaudeAccountsStrings(
            title: "Účty Claude",
            explanation: "Každý pridaný profil Claude Code dostane vlastnú kartu limitov a jeho relácie sa započítajú do výdavkov. Kým je otvorená stránka AI agentov, Claude Code kontroluje každý profil približne každých päť minút jeho vlastným prihlásením. Neodosiela sa žiadna výzva.",
            fallback: "Bez pridaných účtov sa limity Claude riadia účtom vybraným vyššie.",
            appDataFormat: "Aplikácia Claude: %@",
            noAppData: "Žiadna prepojená aplikácia Claude")
        case .de: return ClaudeAccountsStrings(
            title: "Claude-Konten",
            explanation: "Jedes hinzugefügte Claude-Code-Profil erhält eine eigene Limitkarte, und seine Sitzungen zählen zu den Ausgaben. Solange die Seite KI-Agenten geöffnet ist, prüft Claude Code jedes Profil etwa alle fünf Minuten mit dessen eigener Anmeldung. Es wird kein Prompt gesendet.",
            fallback: "Ohne hinzugefügte Konten folgen die Claude-Limits dem oben gewählten Konto.",
            appDataFormat: "Claude-App: %@",
            noAppData: "Keine Claude-App verknüpft")
        case .fr: return ClaudeAccountsStrings(
            title: "Comptes Claude",
            explanation: "Chaque profil Claude Code ajouté obtient sa propre carte de limites, et ses sessions comptent dans les dépenses. Tant que la page Agents IA est ouverte, Claude Code vérifie chacun environ toutes les cinq minutes avec la connexion de ce profil. Aucun prompt n’est envoyé.",
            fallback: "Sans compte ajouté, les limites de Claude suivent le compte choisi ci-dessus.",
            appDataFormat: "App Claude : %@",
            noAppData: "Aucune app Claude associée")
        case .it: return ClaudeAccountsStrings(
            title: "Account Claude",
            explanation: "Ogni profilo di Claude Code aggiunto ha una propria scheda dei limiti e le sue sessioni contano nella spesa. Mentre la pagina Agenti IA è aperta, Claude Code controlla ciascuno circa ogni cinque minuti con l’accesso di quel profilo. Non viene inviato alcun prompt.",
            fallback: "Senza account aggiunti, i limiti di Claude seguono l’account scelto sopra.",
            appDataFormat: "App Claude: %@",
            noAppData: "Nessuna app Claude collegata")
        case .ja: return ClaudeAccountsStrings(
            title: "Claudeアカウント",
            explanation: "追加したClaude Codeプロファイルごとに上限カードが表示され、そのセッションも支出に含まれます。AIエージェントのページが開いているあいだ、Claude Codeが各プロファイル自身のログインで約5分ごとに確認します。プロンプトは送信されません。",
            fallback: "アカウントを追加していない場合、Claudeの上限は上で選んだアカウントに従います。",
            appDataFormat: "Claudeアプリ：%@",
            noAppData: "リンクされたClaudeアプリはありません")
        case .ko: return ClaudeAccountsStrings(
            title: "Claude 계정",
            explanation: "추가한 Claude Code 프로필마다 한도 카드가 따로 생기고, 해당 세션은 지출에 포함됩니다. AI 에이전트 페이지가 열려 있는 동안 Claude Code가 각 프로필의 로그인으로 약 5분마다 확인합니다. 프롬프트는 전송되지 않습니다.",
            fallback: "추가한 계정이 없으면 Claude 한도는 위에서 선택한 계정을 따릅니다.",
            appDataFormat: "Claude 앱: %@",
            noAppData: "연결된 Claude 앱 없음")
        case .uk: return ClaudeAccountsStrings(
            title: "Облікові записи Claude",
            explanation: "Кожен доданий профіль Claude Code отримує власну картку лімітів, а його сеанси враховуються у витратах. Поки відкрита сторінка ШІ-агентів, Claude Code перевіряє кожен профіль приблизно раз на п’ять хвилин із його власним входом. Запити не надсилаються.",
            fallback: "Якщо облікові записи не додано, ліміти Claude беруться з облікового запису, вибраного вище.",
            appDataFormat: "Програма Claude: %@",
            noAppData: "Програму Claude не пов’язано")
        case .zhHans: return ClaudeAccountsStrings(
            title: "Claude 账户",
            explanation: "添加的每个 Claude Code 配置文件都有自己的额度卡片，其会话也计入花费。AI 智能体页面打开时，Claude Code 会使用各配置文件自己的登录信息，大约每五分钟检查一次。不会发送任何提示词。",
            fallback: "未添加账户时，Claude 额度跟随上方选择的账户。",
            appDataFormat: "Claude App：%@",
            noAppData: "未关联 Claude App")
        case .zhTW: return ClaudeAccountsStrings(
            title: "Claude 帳號",
            explanation: "新增的每個 Claude Code 設定檔都有自己的額度卡片，其工作階段也會計入花費。AI 代理程式頁面開啟時，Claude Code 會使用各設定檔自己的登入資訊，大約每五分鐘檢查一次。不會傳送任何提示詞。",
            fallback: "未新增帳號時，Claude 額度會跟隨上方選擇的帳號。",
            appDataFormat: "Claude App：%@",
            noAppData: "未連結 Claude App")
        case .zhHK: return ClaudeAccountsStrings(
            title: "Claude 帳戶",
            explanation: "加入的每個 Claude Code 設定檔都有自己的額度卡片，其工作階段亦會計入花費。AI 代理程式頁面開啟時，Claude Code 會使用各設定檔自己的登入資料，大約每五分鐘檢查一次。不會傳送任何提示。",
            fallback: "未加入帳戶時，Claude 額度會跟隨上方選擇的帳戶。",
            appDataFormat: "Claude App：%@",
            noAppData: "未連結 Claude App")
        }
    }
}
