import XCTest
import Abstract
import JSONObject
import SwiftCheck
import Nimble
import Client

typealias TestedType = ConnectionInfo

class ConnectionInfoTests: XCTestCase {
    
	func testMonoidLaws() {
		property("1•a = a") <- forAll { (object: TestedType) in
			return (.empty <> object) == object
		}

		property("a•1 = a") <- forAll { (object: TestedType) in
			return (object <> .empty) == object
		}

		property("(a•b)•c = a•(b•c)") <- forAll { (object1: TestedType, object2: TestedType, object3: TestedType) in
			return (object1 <> object2 <> object3) == (object1 <> (object2 <> object3))
		}
	}
}
