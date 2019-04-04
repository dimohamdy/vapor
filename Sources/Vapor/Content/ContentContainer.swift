extension HTTPMessage {
    public var content: ContentContainer<Self> {
        get { return .init(message: self) }
        set { self = newValue.message }
    }
}

public struct ContentContainer<Message> where Message: HTTPMessage {
    internal var message: Message
    
    internal init(message: Message) {
        self.message = message
    }
    
    // MARK: Encode
    
    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    /// - throws: Errors during serialization.
    public mutating func encode<C>(_ encodable: C) throws
        where C: Content
    {
        try self.encode(encodable, as: C.defaultContentType)
    }
    
    
    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    ///     - encoder: Specific `HTTPMessageEncoder` to use.
    /// - throws: Errors during serialization.
    public mutating func encode<E>(_ encodable: E, as contentType: HTTPMediaType) throws
        where E: Encodable
    {
        try self.encode(encodable, using: self.requireEncoder(for: contentType))
    }
    
    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    ///     - encoder: Specific `HTTPMessageEncoder` to use.
    /// - throws: Errors during serialization.
    public mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E: Encodable {
        try encoder.encode(encodable, to: &self.message)
    }
    
    // MARK: Private
    
    /// Looks up a `HTTPMessageEncoder` for the supplied `MediaType`.
    private func requireEncoder(for mediaType: HTTPMediaType) throws -> ContentEncoder {
        return try ContentConfiguration.global.requireEncoder(for: mediaType)
    }
    
    // MARK: Decode
    
    /// Parses a `Decodable` type from this HTTP message. This method supports streaming HTTP bodies (chunked) and can run asynchronously.
    /// See `syncDecode(_:)` for the non-streaming, synchronous version.
    ///
    ///     let user = req.content.decode(json: User.self, using: JSONDecoder())
    ///     print(user) // Future<User>
    ///
    /// This method accepts a custom `HTTPMessageDecoder`.
    ///
    /// - parameters:
    ///     - content: `Decodable` type to decode from this HTTP message.
    ///     - maxSize: Maximum streaming body size to support (does not apply to static bodies).
    ///     - decoder: Custom `HTTPMessageDecoder` to use.
    /// - returns: Future instance of the `Decodable` type.
    /// - throws: Any errors making the decoder for this media type or parsing the message.
    public func decode<D>(_ content: D.Type) throws -> D where D: Decodable {
        return try self.decode(D.self, using: self.requireDecoder())
    }
    
    /// Parses a `Decodable` type from this HTTP message. This method supports streaming HTTP bodies (chunked) and can run asynchronously.
    /// See `syncDecode(_:)` for the non-streaming, synchronous version.
    ///
    ///     let user = req.content.decode(json: User.self, using: JSONDecoder())
    ///     print(user) // Future<User>
    ///
    /// This method accepts a custom `HTTPMessageDecoder`.
    ///
    /// - parameters:
    ///     - content: `Decodable` type to decode from this HTTP message.
    ///     - maxSize: Maximum streaming body size to support (does not apply to static bodies).
    ///     - decoder: Custom `HTTPMessageDecoder` to use.
    /// - returns: Future instance of the `Decodable` type.
    /// - throws: Any errors making the decoder for this media type or parsing the message.
    public func decode<D>(_ content: D.Type, using decoder: ContentDecoder) throws -> D where D: Decodable {
        return try decoder.decode(D.self, from: self.message)
    }
    
    // MARK: Single Value
    
    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    ///     let name = try req.content.get(String.self, at: "user", "name")
    ///     print(name) // Future<String>
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    ///     - maxSize: Maximum streaming body size to support (does not apply to non-streaming bodies).
    /// - returns: Future decoded `Decodable` value.
    public func decode<D>(_ type: D.Type = D.self, at keyPath: HTTPCodingKeyRepresentable...) throws -> D
        where D: Decodable
    {
        return try self.decode(D.self, at: keyPath)
    }
    
    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    /// Note: This is the non-variadic version.
    ///
    ///     let name = try req.content.get(String.self, at: "user", "name")
    ///     print(name) // Future<String>
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Future decoded `Decodable` value.
    public func decode<D>(_ type: D.Type = D.self, at keyPath: [HTTPCodingKeyRepresentable]) throws -> D
        where D: Decodable
    {
        return try self.requireDecoder().get(
            at: keyPath.map { $0.makeHTTPCodingKey() },
            from: self.message
        )
    }
    
    // MARK: Private
    
    /// Looks up a `HTTPMessageDecoder` for the supplied `MediaType`.
    private func requireDecoder() throws -> ContentDecoder {
        guard let count = self.message.body.count, count > 0 else {
            throw HTTPError(.noContent)
        }
        
        guard let contentType = self.message.contentType else {
            throw HTTPError(.noContentType)
        }
        
        return try ContentConfiguration.global.requireDecoder(for: contentType)
    }
}
