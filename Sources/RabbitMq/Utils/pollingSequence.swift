import AsyncAlgorithms
import Foundation

func pollingSequence(interval: Duration) -> AsyncChain2Sequence<
    AsyncSyncSequence<[ContinuousClock.Instant]>, AsyncBufferSequence<AsyncTimerSequence<ContinuousClock>>
> {
    chain(
        // Emit immediately
        [ContinuousClock().now].async,
        // Always buffer latest event to prevent piling up events
        AsyncTimerSequence(interval: interval, clock: .continuous).buffer(policy: .bufferingLatest(1))
    )
}
