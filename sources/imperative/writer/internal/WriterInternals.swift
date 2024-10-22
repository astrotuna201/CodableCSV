extension CSVWriter: Failable {
  /// The type of error raised by the CSV writer.
    public enum Error: Int, Sendable {
    /// Some of the configuration values provided are invalid.
    case invalidConfiguration = 1
    /// The CSV data is invalid.
    case invalidInput = 2
    /// The output stream failed.
    case streamFailure = 4
    /// The operation couldn't be carried or failed midway.
    case invalidOperation = 5
  }

  public static var errorDomain: String {
    "Writer"
  }

  public static func errorDescription(for failure: Error) -> String {
    switch failure {
    case .invalidConfiguration: return "Invalid configuration"
    case .invalidInput: return "Invalid input"
    case .streamFailure: return "Stream failure"
    case .invalidOperation: return "Invalid operation"
    }
  }
}

extension CSVWriter {
  /// Private configuration variables for the CSV writer.
  struct Settings {
    /// The unicode scalar delimiters for fields and rows.
    let delimiters: Delimiters
    /// The unicode scalar used as encapsulator and escaping character (when printed two times).
    let escapingScalar: Unicode.Scalar?
    /// Boolean indicating whether the received CSV contains a header row or not.
    let headers: [String]
    /// The encoding used to identify the underlying data.
    let encoding: String.Encoding

    /// Designated initializer taking generic CSV configuration (with possible unknown data) and making it specific to a CSV writer instance.
    /// - parameter configuration: The public CSV writer configuration variables.
    /// - throws: `CSVError<CSVWriter>` exclusively.
    init(configuration: CSVWriter.Configuration, encoding: String.Encoding) throws {
      // 1. The field and row delimiters must be defined and one cannot appear as the prefix of another.
      let delimiters = configuration.delimiters
      guard
        !delimiters.field.starts(with: delimiters.row),
        !delimiters.row.starts(with: delimiters.field)
      else { throw Error._invalidDelimiters() }

      self.delimiters = (field: delimiters.field.scalars, row: delimiters.row.scalars)
      // 2. Copy all other values.
      self.escapingScalar = configuration.escapingStrategy.scalar
      self.headers = configuration.headers
      self.encoding = encoding
    }

    typealias Delimiters = (field: [Unicode.Scalar], row: [Unicode.Scalar])
  }
}

// MARK: -

fileprivate extension CSVWriter.Error {
  /// Error raised when the field or/and row delimiters are invalid.
  static func _invalidDelimiters() -> CSVError<CSVWriter> {
    CSVError(.invalidConfiguration,
             reason: "The field and/or row delimiters are invalid.",
             help: "Both delimiters must contain at least a unicode scalar/character and they must be different to each other.")
  }
}

