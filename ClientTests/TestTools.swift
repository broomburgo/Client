import Foundation
import SwiftCheck
import Client
import Functional
import JSONObject

struct URLStringGenerator {
	static var get: Gen<String> {

		func glue(_ parts: Gen<String>...) -> Gen<String> {
			return sequence(parts).map { $0.reduce("", +) }
		}

		return glue(
			Gen.pure("http://"),
			String.arbitrary,
			Gen.pure("."),
			String.arbitrary.resize(3),
			Gen.pure("/"),
			String.arbitrary)
	}
}

extension ConnectionInfo {
	func isEqual(to other: ConnectionInfo) -> Bool {
		return connectionName == other.connectionName &&
			urlComponents == other.urlComponents &&
			originalRequest == other.originalRequest &&
			serverResponse == other.serverResponse &&
			serverOutput == other.serverOutput
	}
}

extension Gen where A: OptionalType, A.ElementType: Arbitrary {
	var flip: Gen<OptionalOf<A.ElementType>> {
		return map { $0.run(
			ifSome: { OptionalOf($0) },
			ifNone: { OptionalOf(nil) })
        }
	}
}

extension ConnectionInfo: Arbitrary {
	public static var arbitrary: Gen<ConnectionInfo> {
		return Gen<ConnectionInfo>.zip(
			OptionalOf<String>.arbitrary,
			URLStringGenerator.get.map(URLComponents.init),
			URLStringGenerator.get.map { URL(string: $0).map { URLRequest(url: $0) } },
			URLStringGenerator.get.map { URL(string: $0).map { HTTPURLResponse(url: $0, mimeType: nil, expectedContentLength: 0, textEncodingName: nil) } },
			OptionalOf<String>.arbitrary.map { $0.getOptional.flatMap { $0.data(using: .utf8, allowLossyConversion: true) }})
			.map { (oos, ouc, oureq, oures, od) in
				let os = oos.getOptional
				var info = ConnectionInfo.zero
				info.connectionName = os
				info.urlComponents = ouc
				info.originalRequest = oureq
				info.serverResponse = oures
				info.serverOutput = od
				return info
		}
	}
}

struct ArbitraryJSONNumber: Arbitrary {

	let get: JSONNumber
	init(value: JSONNumber) {
		self.get = value
	}

	static var arbitrary: Gen<ArbitraryJSONNumber> {
		return Gen.one(of: [Int.arbitrary.map(ArbitraryJSONNumber.init),
		                    UInt.arbitrary.map(ArbitraryJSONNumber.init),
		                    Float.arbitrary.map(ArbitraryJSONNumber.init),
		                    Double.arbitrary.map(ArbitraryJSONNumber.init)])
	}
}
extension JSONObject: Arbitrary {
	public static var arbitrary: Gen<JSONObject> {
		let null = Gen<JSONObject>.pure(.null)
		let number = ArbitraryJSONNumber.arbitrary.map { JSONObject.number($0.get) }
		let bool = Bool.arbitrary.map(JSONObject.bool)
		let string = String.arbitrary.map(JSONObject.string)
		let array = ArrayOf<Int>.arbitrary
			.map { $0.getArray.map(JSONObject.number) }
			.map(JSONObject.array)
		let dictionary = DictionaryOf<String,Int>.arbitrary
			.map { $0.getDictionary
				.reduce([String:JSONObject]()) { accumulation, tuple in
					var m_accumulation = accumulation
					m_accumulation[tuple.key] = JSONObject.number(tuple.value)
					return m_accumulation
				}
			}
			.map(JSONObject.dict)
		return Gen<JSONObject>.one(of: [null,number,bool,string,array,dictionary])
	}
}

extension CheckerArguments {
	static func with(_ left: Int, _ right: Int, _ size: Int) -> CheckerArguments {
		return CheckerArguments(
			replay: .some(StdGen(left,right),size))
	}
}

