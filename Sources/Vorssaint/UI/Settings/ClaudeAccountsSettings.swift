// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The Claude Code profiles that get limits cards of their own on the AI page.
struct ClaudeAccountsSettings: View {
    @AppStorage(DefaultsKey.notchAgentsClaudeProfiles) private var saved = ""
    @ObservedObject private var service = ClaudeProfileLimitsService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var invalidFolder = false
    private var entries: [ClaudeAccountEntry] { ClaudeAccountEntry.decode(saved) }
    private var text: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(l10n.language) }
    private var shared: CodexAccountStrings { FeatureStrings.codexAccounts(l10n.language) }
    private var account: ClaudeAccountStrings { FeatureStrings.claudeAccount(l10n.language) }
    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.title).font(.subheadline.weight(.medium))
            Text(text.explanation)
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        TextField(shared.accountName, text: Binding(
                            get: { entries.first { $0.id == entry.id }?.name ?? entry.name },
                            set: { value in
                                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                var updated = entries
                                if let index = updated.firstIndex(where: { $0.id == entry.id }) {
                                    updated[index].name = String(value.prefix(40))
                                    save(updated)
                                }
                            }))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Claude · " + shared.accountName + ": " + entry.name)
                        let folder = entry.directory.isEmpty ? account.defaultAccount : entry.directory
                        Text(folder).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            .truncationMode(.middle).help(folder)
                        let app = entry.appData.map { text.appData(URL(fileURLWithPath: $0).lastPathComponent) } ?? text.noAppData
                        Text(app).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                            .truncationMode(.middle).help(entry.appData ?? app)
                    }
                    Button { save(entries.filter { $0.id != entry.id }) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain).help(shared.remove).accessibilityLabel(shared.remove)
                }
            }
            HStack {
                Button(shared.find) {
                    var updated = entries
                    for entry in ClaudeAccountEntry.discover(home: home, defaultName: shared.defaultName)
                    where !updated.contains(where: { same($0.directory, entry.directory) }) { updated.append(entry) }
                    save(Array(updated.prefix(ClaudeAccountEntry.maximum)))
                }
                .disabled(entries.count >= ClaudeAccountEntry.maximum)
                Button(shared.add) { addFolder() }
                    .disabled(entries.count >= ClaudeAccountEntry.maximum)
                if !entries.isEmpty {
                    Button(shared.check) { service.refresh(force: true) }
                        .disabled(!service.isEnabled || service.states.allSatisfy(\.checking))
                }
            }
            if entries.isEmpty {
                Text(text.fallback)
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { service.synchronize() }
        .alert(account.chooseFolder, isPresented: $invalidFolder) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(account.invalidFolder)
        }
    }

    private func same(_ first: String, _ second: String) -> Bool {
        guard !first.isEmpty, !second.isEmpty else { return first == second }
        return URL(fileURLWithPath: first).resolvingSymlinksInPath() == URL(fileURLWithPath: second).resolvingSymlinksInPath()
    }

    /// The island follows the saved list, and reads the logs it names, once
    /// the preference change reaches it.
    private func save(_ value: [ClaudeAccountEntry]) {
        saved = ClaudeAccountEntry.encode(value)
        service.synchronize()
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = home
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        // The ordinary ~/.claude folder is the usual login, unless it holds
        // a .claude.json of its own as an explicitly chosen profile does.
        var profile = ClaudeAccountProfile(directory: folder.path)
        if folder.standardizedFileURL == home.appending(path: ".claude", directoryHint: .isDirectory).standardizedFileURL,
           !FileManager.default.fileExists(atPath: profile.profileURL(home: home).path) {
            profile = ClaudeAccountProfile()
        }
        guard profile.isAvailable(home: home) else { invalidFolder = true; return }
        guard !entries.contains(where: { same($0.directory, profile.directory) }) else { return }
        let entry = ClaudeAccountEntry(id: UUID().uuidString,
                                       name: ClaudeAccountEntry.name(for: profile, defaultName: shared.defaultName),
                                       directory: profile.directory,
                                       appData: ClaudeAccountEntry.appData(for: profile, home: home)?.path)
        save(entries + [entry])
    }
}
