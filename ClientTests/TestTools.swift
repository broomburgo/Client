import Foundation
import SwiftCheck
import Abstract
import JSONObject
@testable import Client
import Monads

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
		return Gen<ConnectionInfo>.compose {
			ConnectionInfo(
				connectionName: $0.generate(),
				urlComponents: $0.generate(using: URLStringGenerator.get.map(URLComponents.init)),
				originalRequest: $0.generate(using: URLStringGenerator.get.map { URL(string: $0).map { URLRequest(url: $0) } }),
				bodyStringRepresentation: $0.generate(),
				connectionError: NSError(domain: $0.generate(), code: $0.generate(), userInfo: nil),
				serverResponse: $0.generate(using: URLStringGenerator.get.map { URL(string: $0).map { HTTPURLResponse(url: $0, mimeType: nil, expectedContentLength: 0, textEncodingName: nil) } }),
				serverOutput: $0.generate(using: OptionalOf<String>.arbitrary.map { $0.getOptional.flatMap { $0.data(using: .utf8, allowLossyConversion: true) }}))
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

extension Multipart.Part.Text: Arbitrary {
	public static var arbitrary: Gen<Multipart.Part.Text> {
		return Gen<Multipart.Part.Text>.compose {
			Multipart.Part.Text(
				name: $0.generate(),
				content: $0.generate())
		}
	}
}

extension Multipart.Part.File: Arbitrary {
	public static var arbitrary: Gen<Multipart.Part.File> {
		return Gen<Multipart.Part.File>.compose {
			Multipart.Part.File(
				contentType: $0.generate(),
				name: $0.generate(),
				filename: $0.generate(),
				data: $0.generate(using: String.arbitrary
					.map { $0.data(using: .utf8)! }))
		}
	}
}

extension Multipart.Part: Arbitrary {
	public static var arbitrary: Gen<Multipart.Part> {
		return Gen<Int>.fromElements(of: [0,1]).flatMap {
			switch $0 {
			case 0:
				return Multipart.Part.Text.arbitrary.map(Multipart.Part.text)
			case 1:
				return Multipart.Part.File.arbitrary.map(Multipart.Part.file)
			default:
				fatalError()
			}
		}
	}
}

extension Multipart: Arbitrary {
	public static var arbitrary: Gen<Multipart> {
		return Gen<Multipart>.compose {
			Multipart(
				boundary: $0.generate(),
				parts: $0.generate(using: ArrayOf<Multipart.Part>.arbitrary.map { $0.getArray }))
		}
	}
}
