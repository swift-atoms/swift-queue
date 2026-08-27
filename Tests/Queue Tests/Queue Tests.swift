import Queue
import Testing

@Suite("Queue")
struct QueueTests {

    @Test("Queue wraps and releases its store")
    func storeRoundTrip() {
        let queue = __Queue<Int>(store: 7)
        #expect(queue.take() == 7)
    }
}
