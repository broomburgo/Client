import Functional

public struct Parse {

	public struct Response {
		public static func acceptOnly(httpCodes accepted: [Int], parseErrorsWith errorStrategy: @escaping ([String:Any]) -> Result<[String:Any]> = { .success($0) }) -> (HTTPResponse) -> Result<HTTPResponse> {
			return { response in
				let code = response.URLResponse.statusCode
				guard accepted.contains(code) else {
					let invalidHTTPCodeError = Result<HTTPResponse>.failure(ClientError.invalidHTTPCode(code))
					return Result(response.output)
						.flatMap(Deserialize.toAnyDictJSON)
						.run(
							ifSuccess: { errorStrategy($0)
								.map { _ in response }
								.flatMap { _ in invalidHTTPCodeError }
						},
							ifFailure: { _ in invalidHTTPCodeError })
				}
				return .success(response)
			}
		}

		public static func checkUnauthorized(withHTTPCodes codes: [Int] = [401]) -> (HTTPResponse) -> Result<HTTPResponse> {
			return { response in
				if codes.contains(response.URLResponse.statusCode) {
					return .failure(ClientError.unauthorized)
				} else {
					return .success(response)
				}
			}
		}

		public static func getHeader(at key: String) -> (HTTPResponse) -> Result<String> {
			return { response in
				guard let
					header = response.URLResponse.allHeaderFields[key] as? String
					else { return Result<String>.failure(ClientError.invalidHeader(key)) }
				return .success(header)
			}
		}
	}

	public struct Output {
		public static func check<OutputType>(errorStrategy: @escaping (OutputType) -> Result<OutputType>) -> (OutputType) -> Result<OutputType> {
			return { output in
				switch errorStrategy(output) {
				case let .failure(error):
					return .failure(error)
				case .success:
					return .success(output)
				}
			}
		}

		public static func getElement<T>(type: T.Type, at path: KeyPath) -> (AnyDict) -> Result<T> {
			return { dict in
				PathTo<T>(in: dict).get(path).run(
					ifSuccess: { Result.success($0) },
					ifFailure: {
						guard let error = $0 as? PathError else { return Result.failure(ClientError.undefined($0)) }
						return Result.failure(ClientError.noValueAtPath(error))
				})
			}
		}

		public static func getElement<T>(at index: Int) -> ([T]) -> Result<T> {
			return { array in
				if array.indices.contains(index) {
					return .success(array[index])
				} else {
					return .failure(ClientError.noValueInArray(index: index))
				}
			}
		}
	}

	public struct Error {
		public static func noResults<T>() -> ([T]) -> Result<[T]> {
			return { results in
				if results.count > 0 {
					return .success(results)
				} else {
					return .failure(ClientError.noResults)
				}
			}
		}

		public static func message(_ expectedText: String) -> (String) ->  Result<String> {
			return { text in
				if text == expectedText {
					return .failure(ClientError.errorMessage(text))
				} else {
					return .success(text)
				}
			}
		}

		public static func messageForKey(_ errorKey: String) -> ([String:Any]) -> Result<[String:Any]> {
			return { plist in
				guard let errorMessage = plist[errorKey] as? String else { return .success(plist) }
				return .failure(ClientError.errorMessage(errorMessage))
			}
		}

		public static func messageForKeyPath(_ errorKeyPath: KeyPath) -> ([String:Any]) -> Result<[String:Any]> {
			return { plist in
				guard let errorMessage = PathTo<String>(in: plist).get(errorKeyPath).toOptional else { return .success(plist) }
				return .failure(ClientError.errorMessage(errorMessage))
			}
		}

		public static func multipleMessagesArray(errorsKey: String, messageKey: String) -> ([String:Any]) -> Result<[String:Any]> {
			return { plist in
				guard let errorsArray = plist[errorsKey] as? [[String:Any]] else { return .success(plist) }
				let messages = errorsArray
					.mapSome { (dict: [String:Any]) -> String? in dict[messageKey] as? String }
				guard messages.count > 0 else { return .success(plist) }
				return .failure(ClientError.errorMessages(messages))
			}
		}

		public static func multipleMessagesDictionary(errorsKey: String, messageKey: String) -> ([String:Any]) -> Result<[String:Any]> {
			return { plist in
				guard let errorsDict = plist[errorsKey] as? [String:[String:Any]] else { return .success(plist) }
				let messages = errorsDict
					.map { (key: String, value: [String:Any]) -> [String:Any] in value  }
					.mapSome { (dict: [String:Any]) -> String? in dict[messageKey] as? String }
				guard messages.count > 0 else { return .success(plist) }
				return .failure(ClientError.errorMessages(messages))
			}
		}

		public static func multipleMessagesArrayOfDictionary(errorsKey: String, messageKey: String) -> ([String:Any]) -> Result<[String:Any]> {
			return { plist in
				guard let errorsArray = plist[errorsKey] as? [[String:Any]] else { return .success(plist) }
				let messages = errorsArray
					.mapSome { (dict: [String:Any]) -> String? in
						dict.values.first
							.flatMap { (value: Any) -> [String:Any]? in value as? [String:Any] }
							.flatMap { (dict: [String:Any]) -> String? in dict[messageKey] as? String }
				}
				guard messages.count > 0 else { return .success(plist) }
				return .failure(ClientError.errorMessages(messages))
			}
		}

		public static func multipleMessagesDictionaryOfDictionary(errorsKey: String, messageKey: String) -> ([String:Any]) -> Result<[String:Any]> {
			return { plist in
				guard let errorsDict = plist[errorsKey] as? [String:Any] else { return .success(plist) }
				let messages = errorsDict
					.map { (key: String, value: Any) -> Any in value }
					.mapSome { (value: Any) -> [String:Any]? in value as? [String:Any] }
					.mapSome { (dict: [String:Any]) -> String? in dict[messageKey] as? String }
				guard messages.count > 0 else { return .success(plist) }
				return .failure(ClientError.errorMessages(messages))
			}
		}

		public static func arrayForKey(_ errorKey: String) -> ([String:Any]) -> Result<[String:Any]> {
			return { plist in
				guard let errorArray = plist[errorKey] as? [String] else { return .success(plist) }
				return .failure(ClientError.errorMessages(errorArray))
			}
		}

		public static func plistForKey(_ errorKey: String) -> ([String:Any]) -> Result<[String:Any]> {
			return { plist in
				guard let errorPlist = plist[errorKey] as? [String:Any] else { return .success(plist) }
				return .failure(ClientError.errorPlist(errorPlist))
			}
		}
	}
}
