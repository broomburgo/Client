import XCTest
import Abstract
import JSONObject
import SwiftCheck
import Nimble
import Client

class ConnectionInfoTests: XCTestCase {
	func testMonoidLaws() {
		property("ConnectionInfo composition is neutral to empty") <- forAll { (a: ConnectionInfo) in
			Law<ConnectionInfo>.isNeutralToEmpty(a)
		}

		property("ConnectionInfo composition is associative") <- forAll { (a: ConnectionInfo, b: ConnectionInfo, c: ConnectionInfo) in
			Law<ConnectionInfo>.isAssociative(a, b, c)
		}
	}
}
