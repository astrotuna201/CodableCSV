import Foundation

extension CSVReader: Failable {
  /// Reader status indicating whether there are remaning lines to read, the CSV has been completely parsed, or an error occurred and no further operation shall be performed.
  public enum Status {
    /// The CSV file hasn't been completely parsed.
    case active
    /// There are no more rows to read. The EOF has been reached.
    case finished
    /// An error has occurred and no further operations shall be performed with the reader instance.
    case failed(CSVError<CSVReader>)
  }

  /// The type of error raised by the CSV reader.
    public enum Error: Int, Sendable {
    /// Some of the configuration values provided are invalid.
    case invalidConfiguration = 1
    /// The CSV data is invalid.
    case invalidInput = 2
    /// The inferral process to figure out delimiters or header row status was unsuccessful.
    case inferenceFailure = 3
    /// The input stream failed.
    case streamFailure = 4
  }

  public static var errorDomain: String {
    "Reader"
  }

  public static func errorDescription(for failure: Error) -> String {
    switch failure {
    case .invalidConfiguration: return "Invalid configuration"
    case .inferenceFailure: return "Inference failure"
    case .invalidInput: return "Invalid input"
    case .streamFailure: return "Stream failure"
    }
  }
}

extension CSVReader {
  /// Private configuration variables for the CSV reader.
  struct Settings {
    /// The unicode scalar delimiters for fields and rows.
    let delimiters: Self.Delimiters
    /// The unicode scalar used as encapsulator and escaping character (when printed two times).
    let escapingScalar: Unicode.Scalar?
    /// The characters set to be trimmed at the beginning and ending of each field.
    let trimCharacters: CharacterSet
    /// Optimization constant used to overcome ObjC overhead.
    let isTrimNeeded: Bool

    /// Creates the inmutable reader settings from the user provided configuration values.
    /// - parameter configuration: The configuration values provided by the API user.
    /// - parameter decoder: The instance providing the input `Unicode.Scalar`s.
    /// - parameter buffer: Small buffer use to store `Unicode.Scalar` values that have been read from the input, but haven't yet been processed.
    /// - throws: `CSVError<CSVReader>` exclusively.
      @available(macOS 13.0, *)
      init(configuration: Configuration, decoder: @escaping ScalarDecoder, buffer: ScalarBuffer) throws {
      // 1. Figure out the field and row delimiters.
      self.delimiters = try Self.Delimiters.infer(from: configuration, decoder: decoder, buffer: buffer)
      // 2. Set the escaping scalar.
      self.escapingScalar = configuration.escapingStrategy.scalar
      // 3. Set the trim characters set.
      self.trimCharacters = configuration.trimStrategy
      // 4. Optimize the trim characters check (to avoid ObjC overhead).
      self.isTrimNeeded = !self.trimCharacters.isEmpty

      // 5. Validate the escaping scalar.
      if let escapingScalar = self.escapingScalar {
        // Ensure the field delimiter does not include the escaping scalar.
        guard !self.delimiters.field.contains(escapingScalar)
        else { throw Error._invalidFieldDelimiter(self.delimiters.field, escapingScalar: escapingScalar) }
        // Ensure the row delimiter does not include the escaping scalar.
        guard self.delimiters.row.allSatisfy({ !$0.contains(escapingScalar) })
        else { throw Error._invalidRowDelimiter(self.delimiters.row, escapingScalar: escapingScalar) }
      }

      // 6. If there are trim characters, ensure they are not delimiters or the escaping scalar.
      guard self.isTrimNeeded else { return }
      // 7. Ensure trim character set doesn't contain the field delimiter.
      guard self.delimiters.field.allSatisfy({ !self.trimCharacters.contains($0) }) else {
        throw Error._invalidTrimCharacters(self.trimCharacters, field: self.delimiters.field)
      }
      // 8. Ensure trim character set doesn't contain the row delimiter.
      guard self.delimiters.row.allSatisfy({ $0.allSatisfy { !self.trimCharacters.contains($0) } }) else {
        throw Error._invalidTrimCharacters(self.trimCharacters, row: self.delimiters.row)
      }
      // 9. Ensure trim character set does not include escaping scalar
      if let escapingScalar = self.escapingScalar, self.trimCharacters.contains(escapingScalar) {
        throw Error._invalidTrimCharacters(self.trimCharacters, escapingScalar: escapingScalar)
      }
    }
  }
}

extension CSVReader.Settings {
  /// Contains the exact composition of a CSV field and row delimiter.
  public struct Delimiters {
    /// The exact composition of unicode scalars identifying a field delimiter.
    /// - invariant: The array always contains at least one element.
    let field: Delimiter
    /// All possile row delimiters specifying its exact compositon of unicode scalars.
    /// - invariant: The set always contains at least one element and all set elements always contain at least on scalar.
    let row: Set<Delimiter>

    /// Designated initializer checking that the delimiters aren't empty and the field delimiter is not included in the row delimiter.
    /// - parameter field: The exact composition of the field delimiter. If empty, `nil` is returned.
    /// - parameter row: The exact composition of all possible row delimiters. If it is empty or any of its elements is an empty array, `nil` is returned.
    public init(field: Delimiter, row: Set<Delimiter>) throws {
      // The field delimiter cannot appear as the prefix of any of the row delimiters and vice-versa.
      guard
        row.allSatisfy({ !field.starts(with: $0) }),
        row.allSatisfy({ !$0.starts(with: field) })
      else { throw CSVReader.Error._invalidDelimiters() }

      self.field = field
      self.row = row
    }

    public init(field: Delimiter, row: Delimiter) throws {
      try self.init(field: field, row: [row])
    }
  }
}

extension CSVReader.Settings.Delimiters: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.field == rhs.field && lhs.row == rhs.row
  }
}

extension CSVReader.Settings.Delimiters: Hashable {
  func hash(into hasher: inout Hasher) {
    self.field.hash(into: &hasher)
    self.row.hash(into: &hasher)
  }
}

fileprivate extension CSVReader.Error {
  /// Error raised when the escaping scalar is contained in the field delimiter.
  static func _invalidFieldDelimiter(_ fieldDelimiter: Delimiter, escapingScalar: Unicode.Scalar) -> CSVError<CSVReader> {
    CSVError(.invalidConfiguration,
             reason: "The field delimiter contains the escaping scalar.",
             help: "Remove the escaping scalar from the field delimiter.",
             userInfo: ["Escaping scalar": escapingScalar, "Field delimiter": fieldDelimiter])
  }
  /// Error raised when the escaping scalar is contained in the row delimiter.
  static func _invalidRowDelimiter(_ rowDelimiter: Set<Delimiter>, escapingScalar: Unicode.Scalar) -> CSVError<CSVReader> {
    CSVError(.invalidConfiguration,
             reason: "The row delimiter contains the escaping scalar.",
             help: "Remove the escaping scalar from the row delimiter.",
             userInfo: ["Escaping scalar": escapingScalar, "Row delimiter": rowDelimiter])
  }
  /// Error raised when the field or/and row delimiters are invalid.
  static func _invalidDelimiters() -> CSVError<CSVReader> {
    CSVError(.invalidConfiguration,
             reason: "The field and/or row delimiters are invalid.",
             help: "Both delimiters must contain at least a unicode scalar/character and they must be different to each other.")
  }
  /// Error raised when a delimiter (whether row or field) is included in the trim character set.
  /// - parameter trimCharacters: The character set selected from trimming.
  /// - parameter field: The delimiter contained within the trim characters.
    @available(macOS 13.0, *)
    static func _invalidTrimCharacters(_ trimCharacters: CharacterSet, field: Delimiter) -> CSVError<CSVReader> {
    CSVError(.invalidConfiguration,
             reason: "The trim character set includes the field delimiter.",
             help: "Remove the delimiter scalars from the trim character set.",
             userInfo: ["Field delimiter": field, "Trim characters": trimCharacters])
  }
  /// Error raised when a delimiter (whether row or field) is included in the trim character set.
  /// - parameter trimCharacters: The character set selected from trimming.
  /// - parameter row: The delimiter contained within the trim characters.
    @available(macOS 13.0, *)
    static func _invalidTrimCharacters(_ trimCharacters: CharacterSet, row: Set<Delimiter>) -> CSVError<CSVReader> {
    CSVError(.invalidConfiguration,
             reason: "The trim character set includes the field delimiter.",
             help: "Remove the delimiter scalars from the trim character set.",
             userInfo: ["Row delimiter": row, "Trim characters": trimCharacters])
  }
  /// Error raised when the escaping scalar has been included in the trim character set.
  /// - parameter trimCharacters: The character set selected for trimming.
  /// - parameter escapingScalar: The selected escaping scalar.
    @available(macOS 13.0, *)
    static func _invalidTrimCharacters(_ trimCharacters: CharacterSet, escapingScalar: Unicode.Scalar) -> CSVError<CSVReader> {
    CSVError(.invalidConfiguration,
             reason: "The trim characters set includes the escaping scalar.",
             help: "Remove the escaping scalar from the trim characters set.",
             userInfo: ["Escaping scalar": escapingScalar, "Trim characters": trimCharacters])
  }
}
