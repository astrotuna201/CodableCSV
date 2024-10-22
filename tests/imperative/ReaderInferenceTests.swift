@testable import CodableCSV
import XCTest

final class ReaderInferenceTests: XCTestCase {
  private enum _TestData {
    /// A CSV row representing a header row (4 fields).
    static let headers   =  ["seq", "Name", "Country", "Number Pair"]
    /// Small amount of regular CSV rows (4 fields per row).
    static let content  =  [["1", "Marcos", "Spain", "99"],
                            ["2", "Kina", "Papua New Guinea", "88"],
                            ["3", "Alex", "Germany", "77"],
                            ["4", "Marine-Anaïs", "France", "66"]]

    /// Some longer CSV rows
    static let longContent = [
      ["ff60766c-08e7-4db4-bfd3-dcc60c15251f", "foofoofoo", "barbarbar", "bazbazbaz"],
      ["f9165d00-03fc-4d8d-838c-1fba1d26d92d", "foofoofoo", "barbarbar", "bazbazbaz"],
    ]

    /// Encodes the test data into a Swift `String`.
    /// - parameter sample:
    /// - parameter delimiters: Unicode scalars to use to mark fields and rows.
    /// - returns: Swift String representing the CSV file.
    static func toCSV(_ sample: [[String]], delimiters: (field: Delimiter, row: Delimiter)) -> String {
      let (f, r) = (delimiters.field.description, delimiters.row.description)
      return sample.map { $0.joined(separator: f) }.joined(separator: r).appending(r)
    }

    static func bufferAndDecoder(from string: String) -> (CSVReader.ScalarBuffer, CSVReader.ScalarDecoder) {
      let scalars = Array(string.unicodeScalars)
      let iter = scalars.makeIterator()
      let buffer = CSVReader.ScalarBuffer(reservingCapacity: 110)
      let decoder = CSVReader.makeDecoder(from: iter)
      return (buffer, decoder)
    }
  }
}

extension ReaderInferenceTests {
  func testReaderInference() throws {
    let fieldDelimiters: [Delimiter] = [",", ";", "\t"]
    let rowDelimiters: [Delimiter] = ["\n", "\r\n"]

    for fieldDelimiter in fieldDelimiters {
      for rowDelimiter in rowDelimiters {
        let testString = _TestData.toCSV(_TestData.content, delimiters: (fieldDelimiter, rowDelimiter))
        let result = try CSVReader.decode(input: testString) {
          $0.delimiters = (field: .infer, row: .infer)
        }
        XCTAssertEqual(result.rows, _TestData.content, "Field: \(fieldDelimiter), Row: \(rowDelimiter)".debugDescription)
      }
    }
  }

  func test_Settings_Delimiters_infer() throws {
//    let fieldDelimiters: [Delimiter] = ["-", "--"]
    let fieldDelimiters: [Delimiter] = ["-", "*-"]
    let rowDelimiters: [Delimiter] = ["\n"]

    var configuration = CSVReader.Configuration()
    configuration.delimiters = (field: .infer(options: fieldDelimiters), row: .infer(options: rowDelimiters))

    let veryLongContent = Array(repeating: _TestData.longContent, count: 1).flatMap { $0 }

    for fieldDelimiter in fieldDelimiters {
      for rowDelimiter in rowDelimiters {
        let testString = _TestData.toCSV(veryLongContent, delimiters: (fieldDelimiter, rowDelimiter))
        let (buffer, decoder) = Self._TestData.bufferAndDecoder(from: testString)
        let delimiters = try CSVReader.Settings.Delimiters.infer(from: configuration, decoder: decoder, buffer: buffer)
        XCTAssertEqual(delimiters, try! CSVReader.Settings.Delimiters(field: fieldDelimiter, row: rowDelimiter))
      }
    }
  }
}

extension ReaderInferenceTests {
  func test_Delimiter_init() {
    XCTAssertEqual(Delimiter(scalars: ["~", "~"]).scalars, ["~", "~"])
    // Delimiter(scalars: []) -> preconditionFailure
    XCTAssertEqual(Delimiter(unicodeScalarLiteral: ",").scalars, [","])
    XCTAssertEqual(Delimiter(stringLiteral: "~~").scalars, ["~", "~"])
    // Delimiter(stringLiteral: "") -> preconditionFailure
    XCTAssertEqual(Delimiter(Substring("~~"))?.scalars, ["~", "~"])
    XCTAssertEqual(Delimiter(Substring("")), nil)
  }
}
