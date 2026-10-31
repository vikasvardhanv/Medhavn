import Foundation
import HealthKit

/// One value read from Apple Health. Apple Watch data reaches the iPhone through the Health app,
/// so this is the only way for the app to "sync" with a watch.
struct WatchReading {
    let type: HealthMetricType
    let value: String
    let unit: String
    let date: Date
}

/// Read-only access to Apple Health. The app never writes to Health.
final class HealthKitManager {
    private let store = HKHealthStore()

    /// False on iPad and on devices without Health.
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        let quantities: [HKQuantityTypeIdentifier] = [.heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .oxygenSaturation, .stepCount]
        for id in quantities { if let t = HKObjectType.quantityType(forIdentifier: id) { types.insert(t) } }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        return types
    }

    /// Shows the system permission sheet. iOS does not say which types were allowed (privacy),
    /// so the caller learns that only from whether data comes back.
    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Latest readings for each supported type. Types with no data are left out.
    func latestReadings(now: Date = Date()) async -> [WatchReading] {
        let day = 86_400.0
        let bpm = HKUnit.count().unitDivided(by: .minute())
        var out: [WatchReading] = []

        if let r = await latest(.heartRate, unit: bpm, since: now.addingTimeInterval(-day)) {
            out.append(WatchReading(type: .pulse, value: String(Int(r.0.rounded())), unit: "bpm", date: r.1))
        }
        if let r = await latest(.restingHeartRate, unit: bpm, since: now.addingTimeInterval(-3 * day)) {
            out.append(WatchReading(type: .restingPulse, value: String(Int(r.0.rounded())), unit: "bpm", date: r.1))
        }
        if let r = await latest(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), since: now.addingTimeInterval(-3 * day)) {
            out.append(WatchReading(type: .hrv, value: String(Int(r.0.rounded())), unit: "ms", date: r.1))
        }
        if let r = await latest(.oxygenSaturation, unit: .percent(), since: now.addingTimeInterval(-3 * day)) {
            out.append(WatchReading(type: .spO2, value: String(Int((r.0 * 100).rounded())), unit: "%", date: r.1))
        }
        if let steps = await stepsToday(now: now) {
            out.append(WatchReading(type: .steps, value: String(Int(steps)), unit: "steps", date: Calendar.current.startOfDay(for: now)))
        }
        if let sleep = await sleepHours(now: now) {
            out.append(WatchReading(type: .sleep, value: String(format: "%.1f", sleep.hours), unit: "hr", date: sleep.end))
        }
        return out
    }

    // MARK: - Queries

    private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async -> (Double, Date)? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else { return continuation.resume(returning: nil) }
                continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
            }
            store.execute(query)
        }
    }

    private func stepsToday(now: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: now), end: now)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .count()))
            }
            store.execute(query)
        }
    }

    /// Time asleep in the last 24 hours, and when the last sleep segment ended.
    private func sleepHours(now: Date) async -> (hours: Double, end: Date)? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-86_400), end: now)
        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let segments = (samples as? [HKCategorySample])?.filter { asleep.contains($0.value) } ?? []
                guard let end = segments.map(\.endDate).max() else { return continuation.resume(returning: nil) }
                let seconds = segments.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: (seconds / 3600, end))
            }
            store.execute(query)
        }
    }
}
