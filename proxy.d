import std.exception;
import std.string;

import ae.net.asockets;
import ae.sys.log;

enum targetHost = "nntp.digitalmars.com";
enum targetPort =  119;
enum listenPort = 4119;

Data serverTranscoder(Data data)
{
	return data;
}

Data clientTranscoder(Data data)
{
	auto contents = cast(string)data.contents;
	enum replaceFrom = "\nContent-Type: text/plain;";
	enum replaceTo = replaceFrom ~ " markup=markdown;";
	auto p = contents.indexOf(replaceFrom);
	if (p < 0)
		return data;
	return Data(contents.replace(replaceFrom, replaceTo));
}

void main()
{
	auto log = createLogger("NNTPProxy");

	auto server = new TcpServer();
	server.handleAccept = (TcpConnection serverTcp) {
		log("Accepted connection from " ~ serverTcp.remoteAddressStr);
		auto clientTcp = new TcpConnection();
		IConnection clientConn, serverConn;
		serverConn = serverTcp;
		clientConn = clientTcp;
		clientConn.handleConnect = {
			log("Connected to " ~ clientTcp.remoteAddressStr);
			serverConn.handleReadData = (Data data) { clientConn.send(serverTranscoder(data)); };
			clientConn.handleReadData = (Data data) { serverConn.send(clientTranscoder(data)); };
		};
		clientConn.handleDisconnect = (string reason, DisconnectType) { log("Client disconnected: " ~ reason); if (serverConn.state == ConnectionState.connected) serverConn.disconnect(reason); };
		serverConn.handleDisconnect = (string reason, DisconnectType) { log("Server disconnected: " ~ reason); if (clientConn.state == ConnectionState.connected) clientConn.disconnect(reason); };
		clientTcp.connect(targetHost, targetPort);
	};
	server.listen(listenPort);
	log("Proxy started");

	socketManager.loop();
}
