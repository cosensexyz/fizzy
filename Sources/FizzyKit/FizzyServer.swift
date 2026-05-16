import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

public final class FizzyServer: @unchecked Sendable {
    private let port: Int
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?
    private let onNotification: @Sendable (ClaudeCodeNotification) -> Void

    public init(port: Int, onNotification: @escaping @Sendable (ClaudeCodeNotification) -> Void) {
        self.port = port
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.onNotification = onNotification
    }

    public func start() throws {
        let handler = { @Sendable [onNotification] in
            return RequestHandler(onNotification: onNotification)
        }
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(handler())
                }
            }
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)

        channel = try bootstrap.bind(host: "127.0.0.1", port: port).wait()
    }

    public func stop() {
        try? channel?.close().wait()
        try? group.syncShutdownGracefully()
    }
}

private final class RequestHandler: ChannelInboundHandler, RemovableChannelHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let onNotification: @Sendable (ClaudeCodeNotification) -> Void
    private var requestHead: HTTPRequestHead?
    private var body = ByteBuffer()

    init(onNotification: @escaping @Sendable (ClaudeCodeNotification) -> Void) {
        self.onNotification = onNotification
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch Self.unwrapInboundIn(data) {
        case .head(let head):
            requestHead = head
            body.clear()
        case .body(var buf):
            body.writeBuffer(&buf)
        case .end:
            processRequest(context: context)
        }
    }

    private func processRequest(context: ChannelHandlerContext) {
        guard let head = requestHead,
              head.method == .POST,
              head.uri == "/claudecode/notification" else {
            respond(context: context, status: .notFound, json: #"{"error":"not found"}"#)
            return
        }

        guard let bytes = body.readBytes(length: body.readableBytes) else {
            respond(context: context, status: .badRequest, json: #"{"error":"invalid request"}"#)
            return
        }
        let bodyData = Data(bytes)
        guard let notification = try? JSONDecoder().decode(ClaudeCodeNotification.self, from: bodyData) else {
            respond(context: context, status: .badRequest, json: #"{"error":"invalid request"}"#)
            return
        }

        onNotification(notification)
        respond(context: context, status: .ok, json: #"{"continue":true}"#)
    }

    private func respond(context: ChannelHandlerContext, status: HTTPResponseStatus, json: String) {
        respond(context: context, status: status, data: Data(json.utf8))
    }

    private func respond(context: ChannelHandlerContext, status: HTTPResponseStatus, data: Data) {
        var buffer = context.channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)

        let head = HTTPResponseHead(version: .http1_1, status: status, headers: [
            "Content-Type": "application/json",
            "Content-Length": "\(data.count)",
        ])
        context.write(Self.wrapOutboundOut(.head(head)), promise: nil)
        context.write(Self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(Self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}
