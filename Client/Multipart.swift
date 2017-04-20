import Foundation

public struct Multipart {

	public static let errorDomain = "Client.Multipart"
	let newLineData = "\n".data(using: .utf8)!

	var boundary: String
	var boundaryData: Data
	var parts: [Part]
	private init(boundary: String, boundaryData: Data, parts: [Part]) {
		self.boundary = boundary
		self.boundaryData = boundaryData
		self.parts = parts
	}

	public init(boundary: String, parts: [Part] = []) throws {
		guard let boundaryData = boundary.data(using: .utf8) else {
			throw NSError(
				domain: Multipart.errorDomain,
				code: 0,
				userInfo: [NSLocalizedDescriptionKey : "Cannot generate boundary data from \(boundary)"])
		}
		self.init(
			boundary: boundary,
			boundaryData: boundaryData,
			parts: parts)
	}

	public func adding(part: Part) -> Multipart {
		return Multipart(
			boundary: boundary,
			boundaryData: boundaryData,
			parts: parts + [part])
	}

	public var headers: [String:String] {
		return ["Content-Type" : "multipart/form-data; boundary=\(boundary)"]
	}

	public func getData() throws -> Data {
		guard parts.count > 0 else { return Data() }

		let elements = [boundaryData] + (try parts.map { newLineData + (try $0.getData()) + newLineData + boundaryData })
		return elements.reduce(Data()) { var m_data = $0; m_data.append($1); return m_data }
	}

	public enum Part {

		case text(Text)
		case file(File)

		public func getData() throws -> Data {
			switch self {
			case .text(let value):
				return try value.getData()
			case .file(let value):
				return try value.getData()
			}
		}

		public struct Text {
			public var name: String
			public var content: String

			public init(name: String, content: String) {
				self.name = name
				self.content = content
			}

			public func getData() throws -> Data {
				let fullDataString = "Content-Disposition: form-data; name=\"\(name)\"\n\n\(content)"
				guard let fullData = fullDataString.data(using: .utf8) else {
					throw NSError(
						domain: Multipart.errorDomain,
						code: 1,
						userInfo: [NSLocalizedDescriptionKey : "Cannot generate Text full data from \(self)"])
				}
				return fullData
			}
		}

		public struct File {
			public var name: String
			public var contentType: String
			public var data: Data

			public init(name: String, contentType: String, data: Data) {
				self.name = name
				self.contentType = contentType
				self.data = data
			}

			public func getData() throws -> Data {
				let headerDataString = "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\"\nContent-Type: \(contentType)\n\n"
				guard
					let headerData = headerDataString.data(using: .utf8) else {
					throw NSError(
						domain: Multipart.errorDomain,
						code: 2,
						userInfo: [NSLocalizedDescriptionKey : "Cannot generate File header data from \(self)"])
				}
				var fullData = headerData
				fullData.append(data)
				return fullData
			}
		}
	}
}
