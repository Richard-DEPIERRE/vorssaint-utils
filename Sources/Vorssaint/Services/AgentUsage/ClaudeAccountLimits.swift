// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

/// A Claude Code profile of its own, a `CLAUDE_CONFIG_DIR`, whose account
/// gets a limits card beside the others. An empty directory is Claude's
/// usual login. `appData` is the data folder of a Claude app signed in to
/// the same account, whose saved limits stand in when Claude Code cannot
/// check, as for a second app started with its own data folder.
struct ClaudeAccountEntry: Codable, Equatable, Identifiable {
    static let maximum = 8

    let id: String
    var name: String
    let directory: String
    var appData: String?

    var profile: ClaudeAccountProfile { ClaudeAccountProfile(directory: directory) }

    static func decode(_ value: String) -> [Self] {
        guard value.utf8.count <= 64 * 1024,
              let decoded = try? JSONDecoder().decode([Self].self, from: Data(value.utf8)) else { return [] }
        var ids = Set<String>(), paths = Set<String>()
        return decoded.prefix(maximum).filter {
            UUID(uuidString: $0.id) != nil && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.name.count <= 40 && ($0.directory.isEmpty || $0.directory.hasPrefix("/"))
                && ($0.appData.map { $0.hasPrefix("/") } ?? true)
                && ids.insert($0.id).inserted
                && paths.insert($0.directory.isEmpty ? "" : URL(fileURLWithPath: $0.directory).resolvingSymlinksInPath().path)
                    .inserted
        }
    }

    static func encode(_ entries: [Self]) -> String {
        (try? JSONEncoder().encode(entries)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    static func saved(in defaults: UserDefaults = .standard) -> [Self] {
        decode(defaults.string(forKey: DefaultsKey.notchAgentsClaudeProfiles) ?? "")
    }

    /// The usual login and the `~/.claude-<name>` profiles beside it, each
    /// with the Claude app data folder named after it when there is one.
    /// `~/.claude` set explicitly is another sign-in than the usual one, so
    /// only a folder chosen by hand adds it.
    static func discover(home: URL = FileManager.default.homeDirectoryForCurrentUser, defaultName: String) -> [Self] {
        let usual = Self(id: UUID().uuidString, name: defaultName, directory: "",
                         appData: appData(for: ClaudeAccountProfile(), home: home)?.path)
        let others = ClaudeAccountProfile.discover(home: home).filter {
            URL(fileURLWithPath: $0.directory).lastPathComponent.hasPrefix(".claude-")
        }.map { profile in
            Self(id: UUID().uuidString, name: name(for: profile, defaultName: defaultName), directory: profile.directory,
                 appData: appData(for: profile, home: home)?.path)
        }
        return [usual] + others
    }

    /// `.claude-work` is Work; the usual login takes `defaultName`.
    static func name(for profile: ClaudeAccountProfile, defaultName: String) -> String {
        let name = profile.name(defaultName: defaultName)
        return profile.isDefault || name.isEmpty ? defaultName : String(name.capitalized.prefix(40))
    }

    /// The Claude app keeps its data in `Application Support/Claude`; another
    /// copy started with its own data folder, as `Claude-work` for the
    /// `.claude-work` profile, keeps its own limits there.
    static func appData(for profile: ClaudeAccountProfile, home: URL) -> URL? {
        let support = home.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        let suffix = profile.isDefault ? nil : URL(fileURLWithPath: profile.directory).lastPathComponent
            .dropFirst(".claude".count)
        guard profile.isDefault || suffix?.first == "-" else { return nil }
        let wanted = ("Claude" + (suffix ?? "")).lowercased()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: support.path)) ?? []
        guard let name = names.first(where: { $0.lowercased() == wanted }) else { return nil }
        let folder = support.appending(path: name, directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: AgentClaudeAppUsage.historyURL(appData: folder).path) ? folder : nil
    }
}

struct ClaudeAccountReading: Equatable {
    let limits: AgentLimits
    let plan: String?
    let email: String?
}

/// Asks the account behind one Claude Code profile for its limits, through
/// the same check as the default Limits card, and falls back on what the
/// Claude app linked to it saved.
enum ClaudeAccountUsageReader {
    /// How long after the last check the account is asked again.
    static func interval(after failure: AgentClaudeServer.Failure?, repeated: Int = 1) -> TimeInterval {
        AgentClaudeServer.interval(after: failure, repeated: repeated, pageVisible: false)
    }

    static func read(_ entry: ClaudeAccountEntry, request: AgentClaudeServer.Request,
                     home: URL = FileManager.default.homeDirectoryForCurrentUser,
                     now: () -> Date = Date.init) -> Result<ClaudeAccountReading, AgentClaudeServer.Failure> {
        let profile = entry.profile
        guard profile.isAvailable(home: home) else { return .failure(.needsSignIn) }
        let saved = profile.read(home: home)
        let result: Result<AgentClaudeServer.Summary, AgentClaudeServer.Failure>
        if let executable = AgentClaudeServer.executable(home: home, searchPath: ProcessInfo.processInfo.environment["PATH"]) {
            var environment = AgentCodexServer.environment(for: executable, searchPath: nil)
            environment["PATH"] = AgentClaudeServer.searchPath(after: environment["PATH"] ?? "", home: home)
            result = request.run(executable, home: home, environment: environment, profile: profile)
        } else {
            result = .failure(.missing)
        }
        let plan = saved.plan?.name, email = saved.identity?.email
        switch result {
        case .success(let summary):
            return .success(ClaudeAccountReading(limits: summary.limits, plan: plan, email: email))
        case .failure(let failure):
            guard let appData = entry.appData,
                  let data = try? Data(contentsOf: AgentClaudeAppUsage.historyURL(appData: URL(fileURLWithPath: appData))),
                  let samples = AgentClaudeAppUsage.samples(from: data),
                  let limits = AgentClaudeAppUsage.limits(from: samples, now: now(),
                                                          organization: saved.identity?.organization)
            else { return .failure(failure) }
            return .success(ClaudeAccountReading(limits: limits, plan: plan, email: email))
        }
    }
}
