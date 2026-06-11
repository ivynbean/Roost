import EventKit
import Foundation
import OSLog

struct DayEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
}

/// Optional, read-only bridge to the system calendar. Roost stays fully
/// local: nothing is written to calendars and nothing leaves the machine.
/// Access is only requested when the user explicitly connects.
@MainActor
final class CalendarService: ObservableObject {
    enum AccessState {
        case notDetermined
        case authorized
        case denied
    }

    @Published var accessState: AccessState = .notDetermined
    @Published var todayEvents: [DayEvent] = []

    private let store = EKEventStore()
    private let logger = Logger(subsystem: "com.ivynbean.Roost", category: "calendar")

    init() {
        refreshAuthorization()
        if accessState == .authorized {
            loadTodayEvents()
        }
    }

    func refreshAuthorization() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            accessState = .notDetermined
        case .fullAccess, .authorized:
            accessState = .authorized
        default:
            accessState = .denied
        }
    }

    func connect() {
        store.requestFullAccessToEvents { [weak self] granted, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.logger.error("Calendar access failed: \(error.localizedDescription, privacy: .public)")
                }
                self.accessState = granted ? .authorized : .denied
                if granted {
                    self.loadTodayEvents()
                }
            }
        }
    }

    func loadTodayEvents() {
        guard accessState == .authorized else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        todayEvents = store.events(matching: predicate)
            .map { event in
                DayEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled event",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar?.title ?? ""
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }
}
