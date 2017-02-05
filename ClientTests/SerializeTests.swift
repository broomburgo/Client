import XCTest
import SwiftCheck
import Client
import JSONObject
import Functional

class SerializeTests: XCTestCase {
    
	func testJSON() {
		property("'toJSON' is invertible for dict") <- forAll { (ao: DictionaryOf<String,String>) in
			let object = ao.getDictionary
			let data = try! Serialize.toJSON(object).get()
			let gotObject = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! Dictionary<String,String>
			return gotObject == object
		}

		property("'toJSON' is invertible for array") <- forAll { (ao: ArrayOf<String>) in
			let object = ao.getArray
			let data = try! Serialize.toJSON(object).get()
			let gotObject = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! Array<String>
			return gotObject == object
		}

		
		property("'fromJSONObject' is invertible", arguments: .with(1414064714,2119139763,98)) <- forAll { (ao: JSONObject) in
			let object = JSONObject.with(ao.getTopLevel)
			let data = try! Serialize.fromJSONObject(object).get()
			let gotObject = (try! JSONSerialization.jsonObject(with: data, options: .allowFragments)) |> JSONObject.with
			return gotObject.isEqual(to: object, numberPrecision: 0.1)
		}
	}
}
