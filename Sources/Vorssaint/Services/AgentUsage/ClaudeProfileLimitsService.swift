// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

struct ClaudeProfileLimitsState: Equatable, Identifiable {
    var entry: ClaudeAccountEntry
    var limits: AgentLimits?
    var plan: String?
    var email: String?
    /// Waiting for its turn or being checked.
    var checking = false
    var failure: AgentClaudeServer.Failure?
    /// Checks in a row that Claude Code did not answer.
    var unreachable = 0
    /// When the last check began; nil until one has.
    var attempted: Date?
    var id: String { entry.id }

    /// An expired window is unknown, not a freshly replenished allowance.
    func currentLimits(at now: Date) -> AgentLimits? {
        AgentClaudeServer.current(limits, now: now)
    }

    func isDue(at now: Date) -> Bool {
        guard let attempted else { return true }
        return now.timeIntervalSince(attempted) >= ClaudeAccountUsageReader.interval(after: failure, repeated: unreachable)
    }
}

/// The limits of each Claude Code profile the person added, kept apart from
/// the provider-wide reading and in memory only. One profile is checked at a
/// time: when the AI page shows them and they are due, or when a card or
/// Settings asks, and never while the island is away or Claude is off.
final class ClaudeProfileLimitsService: ObservableObject {
    typealias Reader = (ClaudeAccountEntry, AgentClaudeServer.Request) -> Result<ClaudeAccountReading, AgentClaudeServer.Failure>
    static let shared = ClaudeProfileLimitsService()

    @Published private(set) var states: [ClaudeProfileLimitsState] = []
    /// Asks the due profiles again while the page shows any; nil otherwise.
    private(set) var timer: Timer?

    private let queue = DispatchQueue(label: "com.vorssaint.claude-profile-limits", qos: .utility)
    private let defaults: UserDefaults
    private let reader: Reader
    private var running: (id: String, request: AgentClaudeServer.Request)?
    /// Checks waiting their turn. Those the person asked for still run after
    /// the page closes; the page's own wait for it to show again.
    private var waiting: [(id: String, asked: Bool)] = []
    private var visible = false

    init(defaults: UserDefaults = .standard,
         reader: @escaping Reader = { entry, request in ClaudeAccountUsageReader.read(entry, request: request) }) {
        self.defaults = defaults
        self.reader = reader
    }

    /// Only while an account card can show: a hidden Limits card asks nothing.
    var isEnabled: Bool {
        NotchAgentSupport.isEnabled(in: defaults) && NotchAgentSupport.showsClaudeAccounts(in: defaults)
    }

    /// Follows the saved profiles and whether Claude is on. Asks only what
    /// is due, and only while the page shows.
    func synchronize() {
        if !isEnabled { cancelChecks() }
        let wanted = ClaudeAccountEntry.saved(in: defaults)
        if states.map(\.entry) != wanted {
            let previous = states
            states = wanted.map { entry in
                // A renamed profile keeps its reading and its check.
                guard var state = previous.first(where: { $0.id == entry.id && $0.entry.directory == entry.directory
                    && $0.entry.appData == entry.appData })
                else { return ClaudeProfileLimitsState(entry: entry) }
                state.entry = entry
                return state
            }
            let kept = Set(states.filter(\.checking).map(\.id))
            waiting.removeAll { !kept.contains($0.id) }
            if let running, !kept.contains(running.id) {
                running.request.cancel()
                self.running = nil
                startNext()
            }
        }
        syncTimer()
        if visible { refresh() }
    }

    /// A Settings preview shows what is known without asking.
    func pageDidAppear(preview: Bool = false) {
        if !preview { visible = true }
        synchronize()
    }

    /// A check under way finishes and keeps its time, so looking at the page
    /// again does not start it over.
    func pageDidDisappear() {
        visible = false
        syncTimer()
        let dropped = Set(waiting.filter { !$0.asked }.map(\.id))
        guard !dropped.isEmpty else { return }
        waiting.removeAll { !$0.asked }
        for index in states.indices where dropped.contains(states[index].id) { states[index].checking = false }
    }

    /// The island is away, the section stops or Claude is off: nothing runs.
    func pause() {
        visible = false
        cancelChecks()
        syncTimer()
    }

    /// Queues the profiles that are due, or, when the person asks, `id` or
    /// every profile. One already waiting or under way is not asked twice.
    func refresh(id: String? = nil, force: Bool = false, now: Date = Date()) {
        guard isEnabled, visible || force else { return }
        for index in states.indices where id == nil || states[index].id == id {
            let state = states[index]
            if state.checking {
                if force, let place = waiting.firstIndex(where: { $0.id == state.id }) { waiting[place].asked = true }
                continue
            }
            guard force || state.isDue(at: now) else { continue }
            states[index].checking = true
            waiting.append((state.id, force))
        }
        startNext()
    }

    private func startNext() {
        guard running == nil, !waiting.isEmpty else { return }
        let next = waiting.removeFirst()
        guard let index = states.firstIndex(where: { $0.id == next.id }) else { return startNext() }
        let entry = states[index].entry
        states[index].attempted = Date()
        let request = AgentClaudeServer.Request()
        running = (next.id, request)
        let read = reader
        queue.async { [weak self] in
            let result = read(entry, request)
            DispatchQueue.main.async {
                guard let self, self.running?.request === request else { return }
                self.running = nil
                self.finish(entry, result)
                self.startNext()
            }
        }
    }

    private func finish(_ entry: ClaudeAccountEntry, _ result: Result<ClaudeAccountReading, AgentClaudeServer.Failure>) {
        guard let index = states.firstIndex(where: { $0.id == entry.id && $0.entry.directory == entry.directory })
        else { return }
        var state = states[index]
        state.checking = false
        switch result {
        case .success(let reading):
            state.limits = reading.limits
            state.plan = reading.plan
            state.email = reading.email
            state.failure = nil
            state.unreachable = 0
        case .failure(let failure):
            // Another sign-in may be behind the profile now. A check that
            // could not finish leaves the last reading standing.
            if failure == .needsSignIn {
                state.limits = nil
                state.plan = nil
            }
            state.failure = failure
            state.unreachable = failure == .unreachable ? state.unreachable + 1 : 0
        }
        states[index] = state
    }

    private func cancelChecks() {
        guard running != nil || !waiting.isEmpty else { return }
        if let running {
            running.request.cancel()
            // Asked again once checks can run.
            if let index = states.firstIndex(where: { $0.id == running.id }) { states[index].attempted = nil }
        }
        running = nil
        waiting.removeAll()
        for index in states.indices where states[index].checking { states[index].checking = false }
    }

    private func syncTimer() {
        guard visible, isEnabled, !states.isEmpty else {
            timer?.invalidate()
            timer = nil
            return
        }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
