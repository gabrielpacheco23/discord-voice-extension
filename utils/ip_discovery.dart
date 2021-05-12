import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

Future<InternetAddress?> ipDiscovery({
  required int ssrc,
  required InternetAddress address,
  required int port,
}) async {
  const ipReqLength = 74;

  var udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
  var byteData = ByteData(ipReqLength);
  byteData.setUint16(0, 1); // type (request)
  byteData.setUint16(2, 70); // size - type and length (74 - 4 = 70)
  byteData.setUint32(4, ssrc); // ssrc

  for (var i = 0; i < address.rawAddress.length; i++) {
    byteData.setUint8(8 + i, address.rawAddress[i]);
  }
  byteData.setUint16(ipReqLength - 2, port); // port

  var buffer = byteData.buffer.asUint8List();
  var bytesSent = udpSocket.send(buffer, address, port);
  if (bytesSent <= 0) {
    print('Error on UDP Socket: bytes sent = $bytesSent');
    return null;
  }

  Datagram? datagram;
  await for (final event in udpSocket) {
    if (event == RawSocketEvent.read) {
      datagram = udpSocket.receive();
      break;
    }
  }

  if (datagram == null) {
    return null;
  }

  final ipData = datagram.data.sublist(8, datagram.data.indexOf(0, 8));
  return InternetAddress.tryParse(utf8.decode(ipData));
}
