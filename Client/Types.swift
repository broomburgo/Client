import Functional
import JSONObject

public typealias Resource<T> = Deferred<Writer<Result<T>,ConnectionInfo>>
public typealias Response = (optData: Data?, optResponse: URLResponse?, optError: Error?)
public typealias Connection = (URLRequest) -> Resource<Response>

public func failed<T>(with error: Error) -> Resource<T> {
	return Deferred(Writer(Result<T>.failure(error)))
}

public func failable<T>(from closure: () throws -> Resource<T>) -> Resource<T> {
	do {
		return try closure()
	}
	catch let error {
		return failed(with: error)
	}
}

//: ------------------------

public struct ConnectionInfo: Monoid, Equatable {
	public var connectionName: String?
	public var urlComponents: URLComponents?
	public var originalRequest: URLRequest?
	public var bodyStringRepresentation: String?
	public var connectionError: NSError?
	public var serverResponse: HTTPURLResponse?
	public var serverOutput: Data?

	public func with(transform: (inout ConnectionInfo) -> ()) -> ConnectionInfo {
		var m_self = self
		transform(&m_self)
		return m_self
	}

	public static var zero: ConnectionInfo {
		return ConnectionInfo(
			connectionName: nil,
			urlComponents: nil,
			originalRequest: nil,
			bodyStringRepresentation: nil,
			connectionError: nil,
			serverResponse: nil,
			serverOutput: nil)
	}

	public func compose (_ other: ConnectionInfo) -> ConnectionInfo {
		return ConnectionInfo(
			connectionName: other.connectionName ?? connectionName,
			urlComponents: other.urlComponents ?? urlComponents,
			originalRequest: other.originalRequest ?? originalRequest,
			bodyStringRepresentation: other.bodyStringRepresentation ?? bodyStringRepresentation,
			connectionError: other.connectionError ?? connectionError,
			serverResponse: other.serverResponse ?? serverResponse,
			serverOutput: other.serverOutput ?? serverOutput)
	}

	public static func == (left: ConnectionInfo, right: ConnectionInfo) -> Bool {
		return left.connectionName == right.connectionName
			&& left.urlComponents == right.urlComponents
			&& left.originalRequest == right.originalRequest
			&& left.bodyStringRepresentation == right.bodyStringRepresentation
			&& left.serverResponse == right.serverResponse
			&& left.serverOutput == right.serverOutput
	}

	public var getJSONObject: JSONObject {
		let connName: JSONObject? = connectionName.map(JSONObject.string)
		let requestURLScheme: JSONObject? = urlComponents?.scheme.map(JSONObject.string)
		let requestURLHost: JSONObject? = urlComponents?.host.map(JSONObject.string)
		let requestURLPort: JSONObject? = urlComponents?.port.map(JSONObject.number)
		let requestURLPath: JSONObject? = (urlComponents?.path).map(JSONObject.string)
		let requestURLQueryString: JSONObject? = urlComponents?.query.map(JSONObject.string)
		let requestURLFullString: JSONObject? = (originalRequest?.url?.absoluteString.removingPercentEncoding).map(JSONObject.string)
		let requestHTTPMethod: JSONObject? = originalRequest?.httpMethod.map(JSONObject.string)
		let requestHTTPHeaders = originalRequest?.allHTTPHeaderFields?.map { JSONObject.dict([$0 : .string($1)]) }.composeAll()
		let requestBodyStringRepresentation: JSONObject? = bodyStringRepresentation.map(JSONObject.string)
			?? (originalRequest?.httpBody).flatMap { (try? JSONSerialization.jsonObject(with: $0, options: .allowFragments)).map(JSONObject.with) }
			?? (originalRequest?.httpBody).flatMap { String(data: $0, encoding: String.Encoding.utf8).map(JSONObject.string) }
		let requestBodyByteLength: JSONObject? = originalRequest?.httpBody.map { $0.count }.map(JSONObject.number)
		let connError: JSONObject? = connectionError.map { JSONObject.dict([
			"Code" : .number($0.code),
			"Domain" : .string($0.domain),
			"UserInfo" : .with($0.userInfo)])
		}
		let responseStatusCode: JSONObject? = (serverResponse?.statusCode).map(JSONObject.number)
		let responseHTTPHeaders: JSONObject? = serverResponse?.allHeaderFields
			.map { (key: AnyHashable, value: Any) -> JSONObject in
				guard let key = key.base as? String else { return JSONObject.null }
				return JSONObject.dict([key : .with(value)])
			}
			.composeAll()
		let responseBody: JSONObject? = serverOutput
			.flatMap { (try? JSONSerialization.jsonObject(with: $0, options: .allowFragments)).map(JSONObject.with)
				?? String(data: $0, encoding: String.Encoding.utf8).map(JSONObject.string)
		}

		return JSONObject.array([
			.dict(["Connection Name" : connName.get(or: .null)]),
			.dict(["Request URL Scheme" : requestURLScheme.get(or: .null)]),
			.dict(["Request URL Host" : requestURLHost.get(or: .null)]),
			.dict(["Request URL Port" : requestURLPort.get(or: .null)]),
			.dict(["Request URL Path" : requestURLPath.get(or: .null)]),
			.dict(["Request URL Query String" : requestURLQueryString.get(or: .null)]),
			.dict(["Request URL Full String" : requestURLFullString.get(or: .null)]),
			.dict(["Request HTTP Method" : requestHTTPMethod.get(or: .null)]),
			.dict(["Request HTTP Headers" : requestHTTPHeaders.get(or: .null)]),
			.dict(["Request Body String Representation" : requestBodyStringRepresentation.get(or: .null)]),
			.dict(["Request Body Byte Length" : requestBodyByteLength.get(or: .null)]),
			.dict(["Connection Error" : connError.get(or: .null)]),
			.dict(["Response Status Code" : responseStatusCode.get(or: .null)]),
			.dict(["Response HTTP Headers" : responseHTTPHeaders.get(or: .null)]),
			.dict(["Response Body" : responseBody.get(or: .null)])])
	}
}

//: ------------------------

public enum HTTPMethod {
	case get
	case post
	case put
	case patch
	case delete

	public var stringValue: String {
		switch self {
		case .get:
			return "GET"
		case .post:
			return "POST"
		case .put:
			return "PUT"
		case .patch:
			return "PATCH"
		case .delete:
			return "DELETE"
		}
	}
}

//: ------------------------

public struct ClientConfiguration {
	public let scheme: String
	public let host: String
	public let port: Int?
	public let rootPath: String?
	public let defaultHeaders: [String:String]?

	public init(scheme: String, host: String, port: Int?, rootPath: String?, defaultHeaders: [String:String]?) {
		self.scheme = scheme
		self.host = host
		self.port = port
		self.rootPath = rootPath
		self.defaultHeaders = defaultHeaders
	}
}

//: ------------------------

public struct Request {
	public var identifier: String
	public var urlComponents: URLComponents
	public var method: HTTPMethod
	public var headers: [String:String]
	public var body: Data?

	public init(identifier: String, urlComponents: URLComponents, method: HTTPMethod, headers: [String:String], body: Data?) {
		self.identifier = identifier
		self.urlComponents = urlComponents
		self.method = method
		self.headers = headers
		self.body = body
	}

	public init(identifier: String, configuration: ClientConfiguration, method: HTTPMethod, additionalHeaders: [String:String]?, path: String?, queryStringParameters: AnyDict?, body: Data?) {
		self.init(
			identifier: identifier,
			urlComponents: URLComponents()
				.resetTo(
					scheme: configuration.scheme,
					host: configuration.host,
					port: configuration.port,
					rootPath: configuration.rootPath)
				.append(path: path.get(or: ""))
				.setQueryString(parameters: queryStringParameters ?? [:]),
			method: method,
			headers: configuration.defaultHeaders.get(or: [:])
				.compose(additionalHeaders.get(or: [:])),
			body: body)
	}

	public func getURLRequestWriter(cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, timeoutInterval: TimeInterval = 20) -> Writer<Result<URLRequest>,ConnectionInfo> {

		let baseWriter = Writer<(),ConnectionInfo>((), ConnectionInfo.zero.with { $0.connectionName = self.identifier}
			.compose(ConnectionInfo.zero.with { $0.urlComponents = self.urlComponents}))

		guard let url = urlComponents.url else {
			return baseWriter.map { Result.failure(ClientError.request(self.urlComponents))}
		}

		let m_request = NSMutableURLRequest(
			url: url,
			cachePolicy: cachePolicy,
			timeoutInterval: timeoutInterval)
		m_request.httpMethod = method.stringValue
		m_request.allHTTPHeaderFields = headers
		m_request.httpBody = body

		let request = m_request.copy() as! URLRequest
		return baseWriter
			.tell(ConnectionInfo.zero.with { $0.originalRequest = request })
			.map { Result.success(request) }
	}
}

//: ------------------------

public struct HTTPResponse {
	public var URLResponse: HTTPURLResponse
	public var output: Data

	public init(URLResponse: HTTPURLResponse, output: Data) {
		self.URLResponse = URLResponse
		self.output = output
	}

	public var toWriter: Writer<HTTPResponse,ConnectionInfo> {
		return Writer(self)
			.tell(ConnectionInfo.zero
				.with { $0.serverResponse = self.URLResponse})
			.tell(ConnectionInfo.zero
				.with { $0.serverOutput = self.output})
	}
}

//: ------------------------
//MARK: - Errors
//: ------------------------

public enum SerializationError: CustomStringConvertible, NSErrorConvertible {
	case toJSON(NSError)
	case toFormURLEncoded

	public var description: String {
		switch self {
		case .toJSON:
			return "SerializationError: JSON"
		case .toFormURLEncoded:
			return "SerializationError: form-url-encoded"
		}
	}

	public static let errorDomain = "Serialization"

	public var getNSError: NSError {
		switch self {
		case .toJSON(let error):
			return error
		case .toFormURLEncoded:
			return NSError(
				domain: SerializationError.errorDomain,
				code: 0,
				userInfo: [NSLocalizedDescriptionKey :  "Cannot serialize into form-url-encoded"])
		}
	}
}

//: ------------------------

public enum DeserializationError: CustomStringConvertible, NSErrorConvertible {
	case toAny(NSError?)
	case toAnyDict(NSError?)
	case toArray(NSError?)
	case toString

	public var description: String {
		switch self {
		case .toAny:
			return "DeserializationError: toAny"
		case .toAnyDict:
			return "DeserializationError: toAnyDict"
		case .toArray:
			return "DeserializationError: toArray"
		case .toString:
			return "DeserializationError: toString"
		}
	}

	public static let errorDomain = "Deserialization"

	public var getNSError: NSError {
		switch self {
		case .toAny(let optionalError):
			return optionalError ?? NSError(
				domain: DeserializationError.errorDomain,
				code: 0,
				userInfo: [NSLocalizedDescriptionKey : "Cannot deserialize into 'Any'"])
		case .toAnyDict(let optionalError):
			return optionalError ?? NSError(
				domain: DeserializationError.errorDomain,
				code: 1,
				userInfo: [NSLocalizedDescriptionKey : "Cannot deserialize into 'AnyDict'"])
		case .toArray(let optionalError):
			return optionalError ?? NSError(
				domain: DeserializationError.errorDomain,
				code: 2,
				userInfo: [NSLocalizedDescriptionKey : "Cannot deserialize into 'Array'"])
		case .toString:
			return NSError(
				domain: DeserializationError.errorDomain,
				code: 3,
				userInfo: [NSLocalizedDescriptionKey : "Cannot deserialize into 'String'"])
		}
	}
}

//: ------------------------

public enum ClientError: Error, CustomStringConvertible, NSErrorConvertible {
	case generic(NSError)
	case connection(NSError)
	case request(URLComponents)
	case noData
	case noResponse
	case invalidHTTPCode(Int)
	case invalidHeader(String)
	case noValueAtPath(PathError)
	case noValueInArray(index: Int)
	case noResults
	case invalidData(String)
	case errorMessage(String)
	case errorMessages([String])
	case errorPlist([String:Any])
	case unauthorized
	case serialization(SerializationError)
	case deserialization(DeserializationError)
	case undefined(Error)

	public var description: String {
		switch  self {
		case .generic(let error):
			return error.localizedDescription
		case .connection(let error):
			return error.localizedDescription
		case .request:
			return "URLComponents non validi"
		case .noData:
			return "Ricevuti dati vuoti"
		case .noResponse:
			return "Nessuna risposta"
		case .invalidHTTPCode(let statusCode):
			return "Codice HTTP non valido: \(statusCode)"
		case .invalidHeader(let headerKey):
			return "Header non valido alla chiave: \(headerKey)"
		case .noValueAtPath(let error):
			return error.description
		case .noValueInArray(let index):
			return "Nessun valore trovato all'indice: \(index)"
		case .noResults:
			return "Nessun risultato"
		case .invalidData:
			return "Dati non validi"
		case .errorMessage(let message):
			return message
		case .errorMessages(let messages):
			return messages.composeAll(separator: "\n")
		case .errorPlist:
			return "Errore generico"
		case .unauthorized:
			return "Autorizzazione negata"
		case .serialization(let error):
			return error.description
		case .deserialization(let error):
			return error.description
		case .undefined(let error):
			return error.localizedDescription
		}
	}

	public static let errorDomain = "Client"
	public static let errorInfoKey = "ErrorInfo"

	public var getNSError: NSError {
		switch self {

		case .generic(let error):
			return error

		case .connection(let error):
			return error

		case .request(let components):
			return NSError(
				domain: ClientError.errorDomain,
				code: 0,
				userInfo: [
					ClientError.errorInfoKey : JSONString.from(["URLComponents" : components.debugDescription]),
					NSLocalizedDescriptionKey : description])

		case .noData:
			return NSError(
				domain: ClientError.errorDomain,
				code: 1,
				userInfo: [NSLocalizedDescriptionKey : description])

		case .noResponse:
			return NSError(
				domain: ClientError.errorDomain,
				code: 2,
				userInfo: [NSLocalizedDescriptionKey : description])

		case .invalidHTTPCode(let statusCode):
			return NSError(
				domain: ClientError.errorDomain,
				code: 3,
				userInfo: [
					ClientError.errorInfoKey : JSONString.from(["ReceivedStatusCode" : statusCode]),
					NSLocalizedDescriptionKey : description])

		case .invalidHeader(let headerKey):
			return NSError(
				domain: ClientError.errorDomain,
				code: 4,
				userInfo: [
					ClientError.errorInfoKey : JSONString.from(["InvalidHeaderKey" : headerKey]),
					NSLocalizedDescriptionKey : description])

		case .noValueAtPath(let error):
			return error.getNSError

		case .noValueInArray(let index):
			return NSError(
				domain: ClientError.errorDomain,
				code: 8,
				userInfo: [
					ClientError.errorInfoKey : JSONString.from(["ExpectedIndex" : index]),
					NSLocalizedDescriptionKey : description])

		case .noResults:
			return NSError(
				domain: ClientError.errorDomain,
				code: 9,
				userInfo: [NSLocalizedDescriptionKey : description])

		case .invalidData(let dataString):
			return NSError(
				domain: ClientError.errorDomain,
				code: 10,
				userInfo: [
					ClientError.errorInfoKey : JSONString.from(["DataMessage" : dataString]),
					NSLocalizedDescriptionKey : description])

		case .errorMessage(let message):
			return NSError(
				domain: ClientError.errorDomain,
				code: 11,
				userInfo: [
					ClientError.errorInfoKey : JSONString.from(["ErrorMessage" : message]),
					NSLocalizedDescriptionKey : description])

		case .errorMessages(let messages):
			return NSError(
				domain: ClientError.errorDomain,
				code: 12,
				userInfo: [
					ClientError.errorInfoKey : JSONString.from(["ErrorMessages" : messages]),
					NSLocalizedDescriptionKey : description])

		case .errorPlist(let plist):
			return NSError(
				domain: ClientError.errorDomain,
				code: 13,
				userInfo: [
					ClientError.errorInfoKey : JSONString.from(["ErrorPlist" : plist]),
					NSLocalizedDescriptionKey : description])

		case .unauthorized:
			return NSError(
				domain: ClientError.errorDomain,
				code: 14,
				userInfo: [NSLocalizedDescriptionKey : description])

		case .serialization(let error):
			return error.getNSError

		case .deserialization(let error):
			return error.getNSError

		case .undefined(let error):
			return NSError(domain: "Undefined", code: 0, userInfo: [NSLocalizedDescriptionKey : error.localizedDescription])
		}
	}
}

//: ------------------------
