extension __Queue where S: ~Copyable {

    public enum Error: Swift.Error, Sendable, Equatable {

        case full
    }
}
