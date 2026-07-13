import Foundation
import Combine
import HealthKit

/// Streams live heart-rate samples from HealthKit (Apple Watch).
///
/// Uses an `HKAnchoredObjectQuery` so new samples arrive via its
/// `updateHandler` as the watch records them, plus a one-shot bootstrap query
/// for the most-recent reading so the UI isn't blank on launch. On the
/// simulator — or any device with no heart-rate data — the queries simply
/// return nothing and the provider stays quiet rather than crashing.
final class HealthKitHeartRateProvider: HeartRateProvider {

    let source: HeartRateSample.Source = .healthKit

    private let store = HKHealthStore()
    private let subject = PassthroughSubject<HeartRateSample, Never>()
    var samples: AnyPublisher<HeartRateSample, Never> { subject.eraseToAnyPublisher() }

    private var anchoredQuery: HKAnchoredObjectQuery?
    private var anchor: HKQueryAnchor?
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    // MARK: Types

    static var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var heartRateType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .heartRate)
    }
    private var restingHeartRateType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let heartRateType { types.insert(heartRateType) }
        if let restingHeartRateType { types.insert(restingHeartRateType) }
        return types
    }

    // MARK: Authorization

    /// Authorization status for heart-rate reads.
    func authorizationStatus() -> HKAuthorizationStatus {
        guard let heartRateType else { return .notDetermined }
        return store.authorizationStatus(for: heartRateType)
    }

    /// Request read access. Completion is delivered on the main queue.
    func requestAuthorization(_ completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        store.requestAuthorization(toShare: [], read: readTypes) { granted, error in
            DispatchQueue.main.async { completion(granted, error) }
        }
    }

    // MARK: HeartRateProvider

    func startStreaming() {
        guard HKHealthStore.isHealthDataAvailable(), let heartRateType else { return }
        bootstrapMostRecent(type: heartRateType)
        startAnchoredQuery(type: heartRateType)
    }

    func stopStreaming() {
        if let query = anchoredQuery {
            store.stop(query)
            anchoredQuery = nil
        }
    }

    // MARK: Queries

    private func bootstrapMostRecent(type: HKQuantityType) {
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: sort
        ) { [weak self] _, results, _ in
            guard let self else { return }
            let quantitySamples = (results as? [HKQuantitySample]) ?? []
            self.publish(quantitySamples)
        }
        store.execute(query)
    }

    private func startAnchoredQuery(type: HKQuantityType) {
        // Only interested in samples recorded from now on.
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { [weak self] _, samples, _, newAnchor, _ in
            guard let self else { return }
            if let newAnchor { self.anchor = newAnchor }
            self.publish((samples as? [HKQuantitySample]) ?? [])
        }

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler
        store.execute(query)
        anchoredQuery = query
    }

    private func publish(_ quantitySamples: [HKQuantitySample]) {
        guard !quantitySamples.isEmpty else { return }
        let mapped = quantitySamples
            .map {
                HeartRateSample(
                    bpm: $0.quantity.doubleValue(for: bpmUnit),
                    date: $0.endDate,
                    source: .healthKit
                )
            }
            .sorted { $0.date < $1.date }

        DispatchQueue.main.async {
            for sample in mapped { self.subject.send(sample) }
        }
    }
}
