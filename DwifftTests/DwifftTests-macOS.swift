//
//  DwifftTests-macOS.swift
//  DwifftTests
//
//  Created by Rik Chilvers on 27/09/2017.
//  Copyright © 2017 jflinter. All rights reserved.
//

import Cocoa
import XCTest
import SwiftCheck

struct SectionedValuesWrapper: Arbitrary {
  let values: SectionedValues<Int, Int>

  public static var arbitrary: Gen<SectionedValuesWrapper> {
    let arrayOfNumbers = Gen<Int>.fromElements(in: 0...10).proliferate.suchThat({ $0.count <= 100 })
    return arrayOfNumbers.map { array in
      return array.map { i in
        return (i, arrayOfNumbers.generate)
      }
      }.map { val in
        return SectionedValuesWrapper(values: SectionedValues<Int, Int>(val))
    }
  }
}

class DwifftSwiftCheckTests: XCTestCase {

  func testDiff() {
    property("Diffing two arrays, then applying the diff to the first, yields the second") <- forAll { (a1 : ArrayOf<Int>, a2 : ArrayOf<Int>) in
      let diff = Dwifft.diff(a1.getArray, a2.getArray)
      return (Dwifft.apply(diff: diff, toArray: a1.getArray) == a2.getArray) <?> "diff applies"
    }
  }

  func test2DDiff() {
    property("Diffing two 2D arrays, then applying the diff to the first, yields the second") <- forAll { (lhs : SectionedValuesWrapper, rhs: SectionedValuesWrapper) in
      let diff = Dwifft.diff(lhs: lhs.values, rhs: rhs.values)
      return (Dwifft.apply(diff: diff, toSectionedValues: lhs.values) == rhs.values) <?> "2d diff applies"
    }
  }

  func testAppKit2D() {

    class DataSource: NSObject, NSTableViewDataSource {
      let diffCalculator: TableViewDiffCalculator<Int>

      init(_ diffCalculator: TableViewDiffCalculator<Int>) {
        self.diffCalculator = diffCalculator
      }

      func numberOfRows(in tableView: NSTableView) -> Int {
        return self.diffCalculator.rows.count
      }

      func tableView(_ tableView: NSTableView, cellForRowAt indexPath: IndexPath) -> NSTableCellView {
        return NSTableCellView()
      }
    }

    property("Updating a TableViewDiffCalculator never raises an exception") <- forAll { (lhs : SectionedValuesWrapper, rhs: SectionedValuesWrapper) in
      let tableView = NSTableView()
      let diffCalculator = TableViewDiffCalculator(tableView: tableView,
                                                   initialRows: lhs.values.sectionsAndValues.first?.1 ?? [])
      let dataSource = DataSource(diffCalculator)
      tableView.dataSource = dataSource
      tableView.reloadData()
      diffCalculator.rows = rhs.values.sectionsAndValues.first?.1 ?? []

      return true <?> "no exception was raised"
    }
  }
}

class DwifftTests: XCTestCase {

  struct TestCase {
    let array1: [Character]
    let array2: [Character]
    let expectedDiff: String
    init(_ a: String, _ b: String, _ expectedDiff: String) {
      self.array1 = a.map { $0 }
      self.array2 = b.map { $0 }
      self.expectedDiff = expectedDiff
    }
  }

  func testDiff() {
    let tests: [TestCase] = [
      TestCase("1234", "23", "-4@3-1@0"),
      TestCase("0125890", "4598310", "-8@4-2@2-1@1-0@0+4@0+8@3+3@4+1@5"),
      TestCase("BANANA", "KATANA", "-N@2-B@0+K@0+T@2"),
      TestCase("1234", "1224533324", "+2@2+4@3+5@4+3@6+3@7+2@8"),
      TestCase("thisisatest", "testing123testing", "-a@6-s@5-i@2-h@1+e@1+t@3+n@5+g@6+1@7+2@8+3@9+i@14+n@15+g@16"),
      TestCase("HUMAN", "CHIMPANZEE", "-U@1+C@0+I@2+P@4+Z@7+E@8+E@9"),
      ]

    for test in tests {
      let diff = Dwifft.diff(test.array1, test.array2)
      let printableDiff = diff.map({ $0.debugDescription }).joined(separator: "")
      XCTAssertEqual(printableDiff, test.expectedDiff, "incorrect diff")
    }
  }

  func testDiffBenchmark() {
    let a: [Int] = (0...1000).map({ _ in Int(arc4random_uniform(100)) }).filter({ _ in arc4random_uniform(2) == 0})
    let b: [Int] = (0...1000).map({ _ in Int(arc4random_uniform(100)) }).filter({ _ in arc4random_uniform(2) == 0})
    measure {
      let _ = Dwifft.diff(a, b)
    }
  }

  func test2D() {
    let testCases: [([(String, [Int])], [(String, [Int])], String)] = [
      (
        [("a", [0, 1]), ("b", [2, 3, 4])],
        [("b", [2])],
        "[d(1 2), d(1 1), ds(0)]"
      ),
      (
        [("a", []), ("b", [])],
        [],
        "[ds(1), ds(0)]"
      ),
      (
        [],
        [("a", []), ("b", [])],
        "[is(0), is(1)]"
      ),
      (
        [],
        [("a", [1, 2]), ("b", [3, 4, 5])],
        "[is(0), is(1), i(0 0), i(0 1), i(1 0), i(1 1), i(1 2)]"
      ),
      (
        [],
        [],
        "[]"
      ),
      (
        [("a", [1]), ("b", []), ("c", [])],
        [("a", [1])],
        "[ds(2), ds(1)]"
      ),
      (
        [("a", []), ("b", [1]), ("c", [])],
        [("a", []), ("b", [2]), ("c", [])],
        "[d(1 0), i(1 0)]"
      ),
      (
        [("a", [1]), ("b", []), ("c", [])],
        [("a", []), ("b", [1]), ("c", [])],
        "[d(0 0), i(1 0)]"
      ),
      (
        [("a", [1]), ("b", []), ("c", [])],
        [("q", []), ("a", [1])],
        "[ds(2), ds(1), is(0)]"
      ),
      (
        [("a", [1]), ("b", []), ("c", [])],
        [("q", []), ("a", [1, 2])],
        "[ds(2), ds(1), is(0), i(1 1)]"
      ),
      (
        [("a", [1])],
        [("q", []), ("a", [1])],
        "[is(0)]"
      ),
      (
        [("a", [1, 2]), ("b", [3, 4])],
        [("a", [1, 2, 3, 4])],
        "[ds(1), i(0 2), i(0 3)]"
      ),
      (
        [("a", [1, 2, 3]), ("b", [4, 5]), ("c", [])],
        [("q", []), ("a", [1, 2]), ("b", [3, 4])],
        "[d(0 2), d(1 1), ds(2), is(0), i(2 0)]"
      ),
      ]
    for (lhs, rhs, expected) in testCases {
      let mappedLhs = SectionedValues(lhs.map { ($0, $1) })
      let mappedRhs = SectionedValues(rhs.map { ($0, $1) })
      XCTAssertEqual(Dwifft.diff(lhs: mappedLhs, rhs: mappedRhs).debugDescription, expected)
    }
  }

  func test2DBenchmark() {
    let n: Int = 70
    let a: [(Int, [Int])] = (0...n).flatMap { (i: Int) -> (Int, [Int])? in
      guard arc4random_uniform(2) == 0 else { return nil }
      let value: [Int] = (0...arc4random_uniform(UInt32(n))).map { _ in Int(arc4random_uniform(100)) }
      return (i, value)
    }
    let b: [(Int, [Int])] = (0...n).flatMap { (i: Int) -> (Int, [Int])? in
      guard arc4random_uniform(2) == 0 else { return nil }
      let value: [Int] = (0...arc4random_uniform(UInt32(n))).map { _ in Int(arc4random_uniform(100)) }
      return (i, value)
    }
    let lhs = SectionedValues(a)
    let rhs = SectionedValues(b)
    measure {
      let _ = Dwifft.diff(lhs: lhs, rhs: rhs)
    }
  }

  func testSectionedValues() {
    XCTAssertEqual(SectionedValues(values: [1,2,3,11,12,13,21,22,23], valueToSection: { i in
      return i % 10
    }, sortSections: {a, b in
      return a < b
    }, sortValues: {a, b in
      return a < b
    }), SectionedValues([(1, [1, 11, 21]), (2, [2, 12, 22]), (3, [3, 13, 23])]))

    XCTAssertEqual(SectionedValues(values: [1,2,3,11,12,13,21,22,23], valueToSection: { i in
      return i % 10
    }, sortSections: {a, b in
      return b < a
    }, sortValues: {a, b in
      return a < b
    }), SectionedValues([(3, [3, 13, 23]), (2, [2, 12, 22]), (1, [1, 11, 21])]))

    XCTAssertEqual(SectionedValues(values: [1,2,3,11,12,13,21,22,23], valueToSection: { i in
      return i % 10
    }, sortSections: {a, b in
      return a < b
    }, sortValues: {a, b in
      return b < a
    }), SectionedValues([(1, [21, 11, 1]), (2, [22, 12, 2]), (3, [23, 13, 3])]))

    XCTAssertEqual(SectionedValues(values: [1,2,3,11,12,13,21,22,23], valueToSection: { i in
      return i % 10
    }, sortSections: {a, b in
      return b < a
    }, sortValues: {a, b in
      return b < a
    }), SectionedValues([(3, [23, 13, 3]), (2, [22, 12, 2]), (1, [21, 11, 1])]))
  }

  func testTableViewDiffCalculator() {

    class TestTableView: NSTableView {

      let insertionExpectations: [Int: XCTestExpectation]
      let deletionExpectations: [Int: XCTestExpectation]

      init(insertionExpectations: [Int: XCTestExpectation], deletionExpectations: [Int: XCTestExpectation]) {
        self.insertionExpectations = insertionExpectations
        self.deletionExpectations = deletionExpectations
        super.init(frame: CGRect.zero)
      }

      required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
      }

      override func insertRows(at indexes: IndexSet, withAnimation animation: NSTableView.AnimationOptions) {
        XCTAssertEqual(animation, NSTableView.AnimationOptions.slideLeft, "incorrect insertion animation")
        for index in indexes {
          self.insertionExpectations[index]!.fulfill()
        }
      }

      override func removeRows(at indexes: IndexSet, withAnimation animation: NSTableView.AnimationOptions) {
        XCTAssertEqual(animation, NSTableView.AnimationOptions.slideRight, "incorrect insertion animation")
        for index in indexes {
          self.deletionExpectations[index]!.fulfill()
        }
      }

    }

    class TestViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

      let tableView: TestTableView
      let diffCalculator: TableViewDiffCalculator<Int>
      var rows: [Int] {
        didSet {
          self.diffCalculator.rows = rows
        }
      }

      init(tableView: TestTableView, rows: [Int]) {
        self.tableView = tableView
        self.diffCalculator = TableViewDiffCalculator<Int>(tableView: tableView, initialRows: rows)
        self.diffCalculator.insertionAnimation = .slideLeft
        self.diffCalculator.deletionAnimation = .slideRight
        self.rows = rows
        super.init(nibName: nil, bundle: nil)
        self.tableView.dataSource = self
        self.tableView.delegate = self
      }

      required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
      }

      func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return NSTableCellView()
      }

      func numberOfRows(in tableView: NSTableView) -> Int {
        return self.diffCalculator.rows.count
      }

    }

    var insertionExpectations: [Int: XCTestExpectation] = [:]
    for i in [0, 3, 4, 5] {
      let x: XCTestExpectation = expectation(description: "+\(i)")
      insertionExpectations[i] = x
    }

    var deletionExpectations: [Int: XCTestExpectation] = [:]
    for i in [0, 1, 2, 4] {
      let x: XCTestExpectation = expectation(description: "+\(i)")
      deletionExpectations[i] = x
    }

    let tableView = TestTableView(insertionExpectations: insertionExpectations, deletionExpectations: deletionExpectations)
    let viewController = TestViewController(tableView: tableView, rows: [0, 1, 2, 5, 8, 9, 0])
    viewController.rows = [4, 5, 9, 8, 3, 1, 0]
    waitForExpectations(timeout: 1.0, handler: nil)
  }

  func testCollectionViewDiffCalculator() {

    class TestCollectionViewItem: NSCollectionViewItem {
        override func loadView() {
            self.view = NSView()
        }
    }

    class TestCollectionView: NSCollectionView {

      let insertionExpectations: [Int: XCTestExpectation]
      let deletionExpectations: [Int: XCTestExpectation]

      init(insertionExpectations: [Int: XCTestExpectation], deletionExpectations: [Int: XCTestExpectation]) {
        self.insertionExpectations = insertionExpectations
        self.deletionExpectations = deletionExpectations
        super.init(frame: CGRect.zero)
        self.collectionViewLayout = NSCollectionViewFlowLayout()
      }

      required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
      }

      override func insertItems(at indexPaths: Set<IndexPath>) {
        super.insertItems(at: indexPaths)
        for indexPath in indexPaths {
          self.insertionExpectations[(indexPath as NSIndexPath).item]!.fulfill()
        }
      }

      override func deleteItems(at indexPaths: Set<IndexPath>) {
        super.deleteItems(at: indexPaths)
        for indexPath in indexPaths {
          self.deletionExpectations[(indexPath as NSIndexPath).item]!.fulfill()
        }
      }

    }

    class TestViewController: NSViewController, NSCollectionViewDataSource {
      let itemIdentifier = NSUserInterfaceItemIdentifier("TestItem")
      let testCollectionView: TestCollectionView
      let diffCalculator: CollectionViewDiffCalculator<Int, Int>
      var rows: [Int] {
        didSet {
          self.diffCalculator.sectionedValues = SectionedValues([(0, rows)])
        }
      }

      init(collectionView: TestCollectionView, rows: [Int]) {
        self.testCollectionView = collectionView
        self.diffCalculator = CollectionViewDiffCalculator<Int, Int>(collectionView: self.testCollectionView, initialSectionedValues: SectionedValues([(0, rows)]))
        self.rows = rows
        super.init(nibName: nil, bundle: nil)

        collectionView.register(TestCollectionViewItem.self, forItemWithIdentifier: self.itemIdentifier)
        collectionView.dataSource = self
      }

      required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
      }

      func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return diffCalculator.numberOfSections()
      }

      func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return diffCalculator.numberOfObjects(inSection: section)
      }

      func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        return collectionView.makeItem(withIdentifier: self.itemIdentifier, for: indexPath)
      }
    }

    var insertionExpectations: [Int: XCTestExpectation] = [:]
    for i in [0, 3, 4, 5] {
      let x: XCTestExpectation = expectation(description: "+\(i)")
      insertionExpectations[i] = x
    }

    var deletionExpectations: [Int: XCTestExpectation] = [:]
    for i in [0, 1, 2, 4] {
      let x: XCTestExpectation = expectation(description: "+\(i)")
      deletionExpectations[i] = x
    }

    let collectionView = TestCollectionView(insertionExpectations: insertionExpectations, deletionExpectations: deletionExpectations)
    let viewController = TestViewController(collectionView: collectionView, rows: [0, 1, 2, 5, 8, 9, 0])
    viewController.rows = [4, 5, 9, 8, 3, 1, 0]
    waitForExpectations(timeout: 1.0, handler: nil)
  }
}
