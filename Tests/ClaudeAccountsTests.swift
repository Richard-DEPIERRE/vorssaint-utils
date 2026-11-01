// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum ClaudeAccountsTests {
    static func run(_ suite: TestSuite) {
        let manager = FileManager.default
        let home = manager.temporaryDirectory.appending(path: "vorssaint-claude-accounts-\(UUID())")
        defer { try? manager.removeItem(at: home) }
        do {
            try manager.createDirectory(at: home, withIntermediateDirectories: true)
            try saveAccount("personal", to: home.appending(path: ".claude.json"))
            let profiles = try ["agency", "agency_two", "unlinked"].map { name -> ClaudeAccountProfile in
                let profile = ClaudeAccountProfile(directory: home.appending(path: ".claude-" + name).path)
                try manager.createDirectory(at: profile.configurationURL(home: home), withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
                try saveAccount(name, to: profile.profileURL(home: home))
                return profile
            }
            // The Claude app's usual data folder, and the copies started with
            // a data folder named after their profile.
            for folder in ["Claude", "Claude-agency", "Claude-Agency_two"] {
                let url = home.appending(path: "Library/Application Support/" + folder)
                try manager.createDirectory(at: url, withIntermediateDirectories: true)
                try Data(#"{"version":2,"samples":[]}"#.utf8).write(to: AgentClaudeAppUsage.historyURL(appData: url))
            }
            discovery(suite, home: home, profiles: profiles)
            try fallback(suite, home: home, profile: profiles[0])
            roots(suite, home: home, profiles: profiles)
        } catch { suite.expect(false, "Claude accounts: \(error)") }
        tiles(suite)
        lifecycle(suite)
        let payload: [String: Any] = [SettingsBackupSupport.formatVersionKey: SettingsBackupSupport.formatVersion,
            SettingsBackupSupport.settingsKey: [DefaultsKey.notchAgentsClaudeProfiles: "[]"]]
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchAgentsClaudeProfiles] as? String == ""
                        && !SettingsBackupSupport.exportKeys().contains(DefaultsKey.notchAgentsClaudeProfiles)
                        && SettingsBackupSupport.sanitizedSettings(from: payload)?[DefaultsKey.notchAgentsClaudeProfiles] == nil,
                     "added Claude account folders never travel in settings backups")
        for language in AppLanguage.allCases {
            let text = FeatureStrings.claudeAccounts(language)
            suite.expect([text.title, text.explanation, text.fallback, text.noAppData].allSatisfy { !$0.isEmpty }
                            && text.appData("Claude-work").contains("Claude-work"),
                         "Claude accounts are localized in \(language.rawValue)")
        }
    }

    private static func saveAccount(_ name: String, to url: URL) throws {
        try JSONSerialization.data(withJSONObject: ["oauthAccount": ["accountUuid": name, "emailAddress": "\(name)@example.invalid",
            "organizationUuid": "same-organization", "organizationType": "claude_team"]]).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func discovery(_ suite: TestSuite, home: URL, profiles: [ClaudeAccountProfile]) {
        let support = home.appending(path: "Library/Application Support")
        let found = ClaudeAccountEntry.discover(home: home, defaultName: "Default")
        suite.expect(found.map(\.directory) == [""] + profiles.map(\.directory)
                        && found.map(\.name) == ["Default", "Agency", "Agency_Two", "Unlinked"],
                     "discovery adds the usual login and each ~/.claude-<name> profile: \(found.map(\.name))")
        suite.expect(found.map { $0.appData.map { URL(fileURLWithPath: $0).lastPathComponent } }
                        == ["Claude", "Claude-agency", "Claude-Agency_two", nil]
                        && found.compactMap(\.appData).allSatisfy { $0.hasPrefix(support.path) },
                     "each profile is linked to the Claude app data folder named after it, whatever its case")
        let encoded = ClaudeAccountEntry.encode(found)
        suite.expect(ClaudeAccountEntry.decode(encoded) == found, "the saved account list reads back as written")
        let duplicate = ClaudeAccountEntry(id: UUID().uuidString, name: "Again", directory: profiles[0].directory)
        let invalid = [ClaudeAccountEntry(id: "not-a-uuid", name: "Bad", directory: "/tmp/a"),
                       ClaudeAccountEntry(id: UUID().uuidString, name: " ", directory: "/tmp/b"),
                       ClaudeAccountEntry(id: UUID().uuidString, name: "Relative", directory: "relative"),
                       ClaudeAccountEntry(id: UUID().uuidString, name: "App", directory: "/tmp/c", appData: "relative")]
        suite.expect(ClaudeAccountEntry.decode(ClaudeAccountEntry.encode(found + [duplicate] + invalid)) == found,
                     "a folder listed twice, a bad id, an empty name or a relative path is left out")
    }

    /// Claude Code cannot be reached in a test, so a check falls back on the
    /// linked app's saved limits, and without them reports why it failed.
    private static func fallback(_ suite: TestSuite, home: URL, profile: ClaudeAccountProfile) throws {
        let now = Date()
        let appData = home.appending(path: "Library/Application Support/Claude-agency")
        let sample: [String: Any] = ["t": (now.timeIntervalSince1970 - 60) * 1_000, "org": "same-organization",
                                     "u": ["fh": 72, "sd": 15]]
        try JSONSerialization.data(withJSONObject: ["version": 2, "samples": [sample]])
            .write(to: AgentClaudeAppUsage.historyURL(appData: appData))
        let linked = ClaudeAccountEntry(id: UUID().uuidString, name: "Agency", directory: profile.directory, appData: appData.path)
        let request = AgentClaudeServer.Request()
        request.cancel()
        let reading = try? ClaudeAccountUsageReader.read(linked, request: request, home: home, now: { now }).get()
        suite.expect(reading?.limits.source == .claudeApp && reading?.email == "agency@example.invalid"
                        && reading?.limits.windows.first { $0.kind == .session }?.usedPercent == 72,
                     "an account Claude Code cannot check shows what its own Claude app saved")
        var unlinked = linked
        unlinked.appData = nil
        let failure = ClaudeAccountUsageReader.read(unlinked, request: request, home: home, now: { now })
        suite.expect((try? failure.get()) == nil, "without a linked app, a failed check stays a failure")
        let gone = ClaudeAccountEntry(id: UUID().uuidString, name: "Gone", directory: home.appending(path: ".claude-gone").path)
        if case .failure(.needsSignIn) = ClaudeAccountUsageReader.read(gone, request: request, home: home) {} else {
            suite.expect(false, "a profile folder that is gone asks to sign in again")
        }
    }

    private static func roots(_ suite: TestSuite, home: URL, profiles: [ClaudeAccountProfile]) {
        let claude = AgentLogRoot.all(home: home, claudeProfile: profiles[0], claudeProfiles: profiles + [profiles[0]])
            .filter { $0.provider == .claude }.map(\.url)
        suite.expect(claude == profiles.flatMap { $0.logURLs(home: home) }.map(AgentLogRoot.canonical),
                     "every added account's logs are read once, the chosen profile's first")
        let other = AgentLogRoot.all(home: home, claudeProfile: ClaudeAccountProfile(), claudeProfiles: profiles)
        suite.expect(other.filter { $0.provider != .claude } == AgentLogRoot.all(home: home).filter { $0.provider != .claude },
                     "added Claude accounts leave the other agents' logs alone")
    }

    private static func tiles(_ suite: TestSuite) {
        let tiles = NotchAgentSupport.tiles(cards: [.limits], providers: [.claude, .codex], claudeAccount: "chosen",
                                            claudeAccounts: ["a", "b"])
        suite.expect(tiles.map(\.accountID) == ["a", "b", nil] && tiles.prefix(2).allSatisfy { $0.provider == .claude }
                        && Set(tiles.map(\.id)).count == tiles.count,
                     "each added Claude account takes a card in place of the single Claude card")
        let single = NotchAgentSupport.tiles(cards: [.limits], providers: [.claude], claudeAccount: "chosen")
        suite.expect(single.map(\.accountID) == ["chosen"], "with no account added, the chosen profile keeps its card")
    }

    private final class Probe {
        private let lock = NSLock()
        private var asked: [String] = []
        var calls: [String] { lock.withLock { asked } }

        func read(_ entry: ClaudeAccountEntry, _ request: AgentClaudeServer.Request)
            -> Result<ClaudeAccountReading, AgentClaudeServer.Failure> {
            lock.withLock { asked.append(entry.id) }
            let limits = AgentLimits(provider: .claude, windows: [AgentLimitWindow(
                id: "claude.fh", kind: .session, minutes: 300, scope: nil, usedPercent: 40,
                resetsAt: Date().addingTimeInterval(3_600))], observedAt: Date(), source: .account)
            return entry.name == "Signed out" ? .failure(.needsSignIn)
                : .success(ClaudeAccountReading(limits: limits, plan: "Team", email: entry.name + "@example.invalid"))
        }
    }

    private static func lifecycle(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.claude-accounts." + UUID().uuidString
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for (key, value) in Defaults.registeredDefaults where key.hasPrefix("notch") { defaults.set(value, forKey: key) }
        for feature in AppFeature.allCases { defaults.set(true, forKey: feature.availabilityKey) }
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.notchAgentsEnabled)
        let entries = [ClaudeAccountEntry(id: UUID().uuidString, name: "Default", directory: ""),
                       ClaudeAccountEntry(id: UUID().uuidString, name: "Signed out", directory: "/tmp/claude-out")]
        defaults.set(ClaudeAccountEntry.encode(entries), forKey: DefaultsKey.notchAgentsClaudeProfiles)
        let probe = Probe()
        let service = ClaudeProfileLimitsService(defaults: defaults, reader: probe.read)
        defer { service.pause() }
        func settled() {
            let end = Date().addingTimeInterval(3)
            while service.states.contains(where: \.checking) && Date() < end {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
        }
        service.synchronize(); service.refresh()
        suite.expect(probe.calls.isEmpty && service.states.count == 2 && service.timer == nil,
                     "adding Claude accounts checks none until the page shows them")
        service.pageDidAppear(preview: true)
        suite.expect(probe.calls.isEmpty, "the Settings preview shows Claude account cards without checking them")
        service.refresh(force: true); service.refresh(force: true)
        settled()
        let first = service.states[0], second = service.states[1]
        suite.expect(probe.calls == entries.map(\.id) && first.limits != nil && first.email == "Default@example.invalid"
                        && first.plan == "Team" && second.limits == nil && second.failure == .needsSignIn,
                     "Claude account checks run one at a time, each keeping its own reading or failure")
        service.pageDidAppear()
        suite.expect(probe.calls.count == 2 && service.timer != nil,
                     "opening the page reuses fresh readings and keeps checking while it shows")
        defaults.set(true, forKey: DefaultsKey.notchAgentsCodex)
        defaults.set(NotchAgentCard.limits.rawValue, forKey: DefaultsKey.notchAgentsHiddenCards)
        service.synchronize()
        suite.expect(!service.isEnabled && service.timer == nil,
                     "hiding the Limits card stops Claude account checks")
        defaults.set("", forKey: DefaultsKey.notchAgentsHiddenCards)
        defaults.set(ClaudeAccountEntry.encode([entries[0]]), forKey: DefaultsKey.notchAgentsClaudeProfiles)
        service.synchronize()
        suite.expect(service.states.map(\.id) == [entries[0].id] && service.states[0].limits != nil,
                     "removing an account drops its card and keeps the others' readings")
    }
}
