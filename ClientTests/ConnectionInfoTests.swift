import XCTest
import Functional
import JSONObject
import SwiftCheck
import Nimble
import Client

typealias TestedType = ConnectionInfo

class ConnectionInfoTests: XCTestCase {
    
	func testMonoidLaws() {
		property("1•a = a") <- forAll { (object: TestedType) in
			return TestedType.zero.compose(object).isEqual(to: object)
		}

		property("a•1 = a") <- forAll { (object: TestedType) in
			return object.compose(TestedType.zero).isEqual(to: object)
		}

		property("(a•b)•c = a•(b•c)") <- forAll { (object1: TestedType, object2: TestedType, object3: TestedType) in
			return (object1.compose(object2)).compose(object3).isEqual(to: object1.compose(object2.compose(object3)))
		}
	}
}
