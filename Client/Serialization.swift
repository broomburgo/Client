import Functional
import JSONObject

//: ------------------------

public struct Serialize {
	public static var toJSON: (Any) -> Result<Data> {
		return { object in
			do {
				return try .success(JSONSerialization.data(with: JSONObject.with(object)))
			}
			catch let error as NSError {
				return .failure(ClientError.serialization(.toJSON(error)))
			}
		}
	}

	public static var fromJSONObject: (JSONObject) -> Result<Data> {
		return { object in
			do {
				return try .success(JSONSerialization.data(with: object))
			}
			catch let error as NSError {
				return .failure(ClientError.serialization(.toJSON(error)))
			}
		}
	}

	public static var toFormURLEncoded: (Any) -> Result<Data> {
		return { object in
			guard let dict = object as? AnyDict else { return .failure(ClientError.serialization(.toFormURLEncoded)) }
			if let data = wsBodyDataURLEncodedString(dict: dict, rootKey: nil).data(using: String.Encoding.utf8) {
				return .success(data)
			} else {
				return .failure(ClientError.serialization(.toFormURLEncoded))
			}
		}
	}

	fileprivate typealias PlistStringReducer = (String, (String, Any)) -> String

	fileprivate static func wsBodyDataURLEncodedString(dict: AnyDict, rootKey: String?) -> String {
		let rawDataString = dict.reduce("", wsBodyDataURLEncodedReducerWithRootKey(rootKey))
		var characters = rawDataString.characters
		characters.removeFirst()
		return String(characters)
	}

	fileprivate static func wsBodyDataURLEncodedReducerWithRootKey(_ rootKey: String?) -> PlistStringReducer {
		return {
			let accumulation = $0
			let key = $1.0
			let value = $1.1
			let stringKey = rootKey.map { "\($0)[\(key)]" } ?? key
			let newString: String
			switch value {
			case let subPlist as [String:Any]:
				newString = wsBodyDataURLEncodedString(dict: subPlist, rootKey: key)
			default:
				newString = "\(stringKey)=\(value)"
			}
			return accumulation + "&" + newString
		}
	}
}

//: ------------------------

public struct Deserialize {
	public static var ignored: (Data) -> Result<()> { return { _ in .success() } }

	public static var toAnyJSON: (Data) -> Result<Any> {
		return { data in
			do {
				return try .success(JSONSerialization.jsonObject(with: data, options: .allowFragments))
			}
			catch let error as NSError {
				return .failure(ClientError.deserialization(.toAny(error)))
			}
		}
	}

	public static var toAnyDictJSON: (Data) -> Result<AnyDict> {
		return { data in
			do {
				if let plist = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
					return .success(plist)
				} else {
					return .failure(ClientError.deserialization(.toAnyDict(nil)))
				}
			}
			catch let error as NSError {
				return .failure(ClientError.deserialization(.toAnyDict(error)))
			}
		}
	}

	public static var toAnyArrayJSON: (Data) -> Result<[Any]> {
		return { data in
			do {
				if let array = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [Any] {
					return .success(array)
				} else {
					return .failure(ClientError.deserialization(.toArray(nil)))
				}
			}
			catch let error as NSError {
				return .failure(ClientError.deserialization(.toArray(error)))
			}
		}
	}

	public static var toAnyDictArrayJSON: (Data) -> Result<[AnyDict]> {
		return { data in
			do {
				if let array = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String:Any]] {
					return .success(array)
				} else {
					return .failure(ClientError.deserialization(.toArray(nil)))
				}
			}
			catch let error as NSError {
				return .failure(ClientError.deserialization(.toArray(error)))
			}
		}
	}

	public static var toString: (Data) -> Result<String> {
		return { data in
			if let string = String(data: data, encoding: String.Encoding.utf8) {
				return .success(string)
			} else {
				return .failure(ClientError.deserialization(.toString))
			}
		}
	}
}
