/// Represents a CSV delimiter, like a field or row delimiter.
/// The delimiter is guaranteed to never be empty.
public struct Delimiter: Hashable, ExpressibleByStringLiteral, CustomStringConvertible, Sendable {
  let scalars: [Unicode.Scalar]

  /// Creates a delimiter from the given scalars.
  /// - parameter scalars: An array of Unicode scalars representing the delimiter. Must not be empty.
  init(scalars: [Unicode.Scalar]) {
    precondition(!scalars.isEmpty, "A delimiter must consist of at least one Unicode scalar.")
    self.scalars = scalars
  }

  /// Creates a delimiter from the given string literal.
  /// - parameter value: The string literal representing the delimiter. Must not be empty.
  public init(stringLiteral value: String) {
    self.init(scalars: Array(value.unicodeScalars))
  }

  /// Creates a delimiter from the given Unicode scalar literal.
  /// - parameter value: The Unicode scalar literal representing the delimiter.
  public init(unicodeScalarLiteral value: Unicode.Scalar) {
    self.scalars = [value]
  }

  /// Creates a delimiter from the given `String` or `Substring`. Returns `nil` if the supplied delimiter is empty.
  /// - parameter delimiter: The `String` or `Substring` representing the delimiter.
  public init?<S:StringProtocol>(_ delimiter: S) {
    guard !delimiter.isEmpty else { return nil }
    self.scalars = Array(delimiter.unicodeScalars)
  }

  /// The textual representation of the delimiter.
  public var description: String {
    String(String.UnicodeScalarView(self.scalars))
  }
}

// MARK: Conformance to Collection

extension Delimiter: Collection {
  public typealias Element = Unicode.Scalar
  public typealias Index = Array<Element>.Index

  public subscript(position: Index) -> Element {
    self.scalars[position]
  }

  public var startIndex: Index {
    self.scalars.startIndex
  }

  public var endIndex: Index {
    self.scalars.endIndex
  }

  public func index(after i: Index) -> Index {
    self.scalars.index(after: i)
  }
}

// MARK: - Inferrable

public protocol Inferrable: ExpressibleByNilLiteral {
  /// The type of the inference options.
  associatedtype Option

  /// A default list of possible inference options.
  static var defaultInferenceOptions: [Option] { get }

  /// Pick the right configuration value from a list of possible options by inferring it from the CSV data.
  /// - parameter options: A list of the possible options. Must not be empty.
  /// - returns: An instance of `Self`, initialized for inference.
  static func infer(options: [Option]) -> Self
}

extension Inferrable {
  /// An instance of `Self`, initialized for inference using the default inference options.
  public static var infer: Self {
    Self.infer(options: Self.defaultInferenceOptions)
  }
}

// MARK: Default conformance to ExpressibleByNilLiteral

extension Inferrable {
  public init(nilLiteral: ()) {
    self = .infer
  }
}

// MARK: - DelimiterProtocol

protocol DelimiterProtocol: ExpressibleByStringLiteral {
  /// Creates an instance from the given delimiter.
  /// - parameter delimiter: The chosen delimiter.
  init(delimiter: Delimiter)
}

// MARK: Default conformance to ExpressibleByStringLiteral

extension DelimiterProtocol {
  public init(unicodeScalarLiteral value: Unicode.Scalar) {
    self.init(delimiter: .init(unicodeScalarLiteral: value))
  }

  public init(stringLiteral value: String) {
    self.init(delimiter: .init(stringLiteral: value))
  }
}
