import SwiftUI

import Foundation

struct CountdownEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var icon: String
    var colorHex: String
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        icon: String = "⏳",
        colorHex: String = "#4F46E5",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

import Foundation

protocol CountdownStoreProtocol {
    func load() -> [CountdownEvent]
    func save(_ items: [CountdownEvent])
}

final class CountdownUserDefaultsStore: CountdownStoreProtocol {
    private let key = "countdown_events_v1"
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func load() -> [CountdownEvent] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([CountdownEvent].self, from: data)
        } catch {
           
            return []
        }
    }
    
    func save(_ items: [CountdownEvent]) {
        do {
            let data = try JSONEncoder().encode(items)
            defaults.set(data, forKey: key)
        } catch {
        
        }
    }
}

import Foundation

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var theme: AppTheme = .system
}

protocol SettingsStoreProtocol {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

final class SettingsUserDefaultsStore: SettingsStoreProtocol {
    private let key = "app_settings_v1"
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else { return AppSettings() }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }
    
    func save(_ settings: AppSettings) {
        let data = (try? JSONEncoder().encode(settings))
        defaults.set(data, forKey: key)
    }
}

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 80, 80, 80)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

struct CountdownParts: Equatable {
    var days: Int
    var hours: Int
    var minutes: Int
    var isPast: Bool
}

func countdownParts(to target: Date, now: Date = Date()) -> CountdownParts {
    if target <= now {
        return .init(days: 0, hours: 0, minutes: 0, isPast: true)
    }
    let comps = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: target)
    return .init(
        days: max(0, comps.day ?? 0),
        hours: max(0, comps.hour ?? 0),
        minutes: max(0, comps.minute ?? 0),
        isPast: false
    )
}

import Foundation

final class CountdownListViewModel: ObservableObject {
    @Published private(set) var events: [CountdownEvent] = []
    
    private let store: CountdownStoreProtocol
    
    init(store: CountdownStoreProtocol = CountdownUserDefaultsStore()) {
        self.store = store
        self.events = store.load().sorted { $0.date < $1.date }
    }
    
    func add(_ event: CountdownEvent) {
        events.append(event)
        events.sort { $0.date < $1.date }
        store.save(events)
    }
    
    func update(_ event: CountdownEvent) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[idx] = event
        events.sort { $0.date < $1.date }
        store.save(events)
    }
    
    func delete(_ event: CountdownEvent) {
        events.removeAll { $0.id == event.id }
        store.save(events)
    }
    
    func delete(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
        store.save(events)
    }
}

import Foundation

final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings
    
    private let store: SettingsStoreProtocol
    
    init(store: SettingsStoreProtocol = SettingsUserDefaultsStore()) {
        self.store = store
        self.settings = store.load()
    }
    
    func setTheme(_ theme: AppTheme) {
        settings.theme = theme
        store.save(settings)
    }
}



import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            CountdownListView()
                .tabItem { Label("Countdowns", systemImage: "hourglass") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }

    }
}

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var vm: CountdownListViewModel
    
    enum Segment: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case past = "Past"
        var id: String { rawValue }
    }
    
    @State private var segment: Segment = .upcoming
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Filter", selection: $segment) {
                    ForEach(Segment.allCases) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                List {
                    ForEach(groupedEvents.keys.sorted(by: monthSort), id: \.self) { month in
                        Section(monthTitle(month)) {
                            ForEach(groupedEvents[month] ?? []) { event in
                                NavigationLink {
                                    CountdownDetailView(event: event)
                                } label: {
                                    CalendarRow(event: event)
                                }
                            }
                        }
                    }
                    
                    if filteredEvents.isEmpty {
                        Section {
                            Text(segment == .upcoming ? "No upcoming events." : "No past events.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Calendar")
        }
    }
    
    private var filteredEvents: [CountdownEvent] {
        let now = Date()
        let items = vm.events.sorted { $0.date < $1.date }
        switch segment {
        case .upcoming:
            return items.filter { $0.date >= now }
        case .past:
            return items.filter { $0.date < now }.reversed()
        }
    }
    
    private var groupedEvents: [DateComponents: [CountdownEvent]] {
        Dictionary(grouping: filteredEvents) { event in
            Calendar.current.dateComponents([.year, .month], from: event.date)
        }
    }
    
    private func monthSort(_ a: DateComponents, _ b: DateComponents) -> Bool {
        let ay = a.year ?? 0, by = b.year ?? 0
        if ay != by { return ay < by }
        return (a.month ?? 0) < (b.month ?? 0)
    }
    
    private func monthTitle(_ comps: DateComponents) -> String {
        let cal = Calendar.current
        guard let date = cal.date(from: comps) else { return "Unknown" }
        return date.formatted(.dateTime.year().month(.wide))
    }
}

import SwiftUI

struct CalendarRow: View {
    let event: CountdownEvent
    
    var body: some View {
        let parts = countdownParts(to: event.date)
        
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: event.colorHex).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(event.icon).font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if parts.isPast {
                Text("Done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(parts.days)d \(parts.hours)h \(parts.minutes)m")
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }
}


struct CountdownListView: View {
    @EnvironmentObject private var vm: CountdownListViewModel
    @State private var showAdd = false
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.events.isEmpty {
                    EmptyStateView(
                        title: "No countdowns yet",
                        subtitle: "Create your first event and never miss an important moment.",
                        buttonTitle: "Add Countdown",
                        action: { showAdd = true }
                    )
                } else {
                    List {
                        ForEach(vm.events) { event in
                            NavigationLink {
                                CountdownDetailView(event: event)
                            } label: {
                                CountdownRow(event: event)
                            }
                        }
                        .onDelete(perform: vm.delete)
                    }
                }
            }
            .navigationTitle("Countdowns")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Countdown")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditCountdownView(mode: .add)
            }
        }
    }
}

struct CountdownRow: View {
    let event: CountdownEvent
    
    var body: some View {
        let parts = countdownParts(to: event.date)
        
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: event.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Text(event.icon)
                    .font(.system(size: 22))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if parts.isPast {
                Text("Done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Text("\(parts.days)d")
                    Text("\(parts.hours)h")
                    Text("\(parts.minutes)m")
                }
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 6)
    }
}


import SwiftUI

enum AddEditMode {
    case add
    case edit(CountdownEvent)
}

struct AddEditCountdownView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: CountdownListViewModel
    
    let mode: AddEditMode
    
    @State private var title: String = ""
    @State private var date: Date = Date().addingTimeInterval(3600)
    @State private var icon: String = "⏳"
    @State private var colorHex: String = "#4F46E5"
    
    private let icons = ["🎉","✈️","❤️","🎂","🎯","🏁","📅","⏳","⭐️","💍","🎓","🏖️"]
    private let colors = ["#4F46E5","#06B6D4","#10B981","#F59E0B","#EF4444","#EC4899","#8B5CF6","#64748B"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Style") {
                    Picker("Icon", selection: $icon) {
                        ForEach(icons, id: \.self) { Text($0).tag($0) }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(colors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle()
                                            .stroke(colorHex == hex ? Color.primary : .clear, lineWidth: 2)
                                    )
                                    .onTapGesture { colorHex = hex }
                                    .accessibilityLabel("Color")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(modeActionTitle) { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { loadIfNeeded() }
        }
    }
    
    private var modeTitle: String {
        switch mode {
        case .add: return "Add Countdown"
        case .edit: return "Edit Countdown"
        }
    }
    
    private var modeActionTitle: String {
        switch mode {
        case .add: return "Save"
        case .edit: return "Save"
        }
    }
    
    private func loadIfNeeded() {
        guard case let .edit(event) = mode else { return }
        title = event.title
        date = event.date
        icon = event.icon
        colorHex = event.colorHex
    }
    
    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch mode {
        case .add:
            vm.add(CountdownEvent(title: cleanTitle, date: date, icon: icon, colorHex: colorHex))
        case .edit(let existing):
            var updated = existing
            updated.title = cleanTitle
            updated.date = date
            updated.icon = icon
            updated.colorHex = colorHex
            vm.update(updated)
        }
        
        dismiss()
    }
}

import SwiftUI

struct CountdownDetailView: View {
    @EnvironmentObject private var vm: CountdownListViewModel
    @Environment(\.dismiss) private var dismiss
    
    let event: CountdownEvent
    @State private var showEdit = false
    @State private var showDelete = false
    
    var body: some View {
        let parts = countdownParts(to: event.date)
        
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color(hex: event.colorHex).opacity(0.15))
                    .frame(width: 88, height: 88)
                Text(event.icon).font(.system(size: 40))
            }
            .padding(.top, 20)
            
            Text(event.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(event.date.formatted(date: .long, time: .shortened))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 14) {
                StatBox(title: "Days", value: "\(parts.days)")
                StatBox(title: "Hours", value: "\(parts.hours)")
                StatBox(title: "Minutes", value: "\(parts.minutes)")
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") { showEdit = true }
                    Button("Delete", role: .destructive) { showDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditCountdownView(mode: .edit(event))
        }
        .alert("Delete countdown?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                vm.delete(event)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
        )
    }
}


import SwiftUI

struct SettingsView: View {
    @State private var showMailUnavailable = false
    
    private let privacyURL = URL(string: "https://www.freeprivacypolicy.com/live/c14a7eb6-c666-4aff-b3a3-1e9e284690b4")!
    private let termsURL = URL(string: "https://docs.google.com/document/d/1OYP4gk_e2g34lMdoLWrd0YjT9wqchBWoXxeh8l37DFA/edit?tab=t.0")!
    
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id6758344924")!
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Support") {
                    Button {
                        rateApp()
                    } label: {
                        Label("Rate the App", systemImage: "star")
                    }
                    
                    ShareLink(item: appStoreURL) {
                        Label("Share App", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section("Legal") {
                    Link(destination: privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    Link(destination: termsURL) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Mail is not available", isPresented: $showMailUnavailable) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please configure a mail account on this device or contact us via the website.")
            }
        }
    }
    
    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }
    
    private func contactSupport() {
        let subject = "Countdown Support"
        let body = "Hi! I need help with:\n\n"
        
        guard
            let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "mailto:support@yourdomain.com?subject=\(subjectEncoded)&body=\(bodyEncoded)")
        else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showMailUnavailable = true
        }
    }
    
    private func rateApp() {
        UIApplication.shared.open(appStoreURL)
    }
}


struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 44))
                .padding(.bottom, 6)
            
            Text(title)
                .font(.title3.weight(.semibold))
            
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
            
            Button(buttonTitle) { action() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
        }
        .padding()
    }
}


struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    RootView()
        .environmentObject(CountdownListViewModel())
        .environmentObject(SettingsViewModel())
}
