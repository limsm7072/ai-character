import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Pure Dart Edge TTS client using WebSocket.
/// Connects to Microsoft Edge's Read Aloud backend (free, no API key).
class EdgeTtsService {
  static const _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _wsBase =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static const _outputFormat = 'audio-24khz-48kbitrate-mono-mp3';
  static const _chromiumVersion = '130.0.2849.68';

  static const _uuid = Uuid();

  /// Synthesize [text] to MP3 bytes using the given [voice].
  ///
  /// [rate] e.g. '+0%', '+20%', '-10%'
  /// [pitch] e.g. '+0Hz', '+10Hz', '-5Hz'
  /// [volume] e.g. '+0%'
  Future<Uint8List> synthesize(
    String text, {
    String voice = 'ko-KR-SunHiNeural',
    String rate = '+0%',
    String pitch = '+0Hz',
    String volume = '+0%',
  }) async {
    if (text.trim().isEmpty) return Uint8List(0);

    final connId = _uuid.v4().replaceAll('-', '');
    final secMsGec = _generateSecMsGec();

    final uri = Uri.parse(
      '$_wsBase'
      '?TrustedClientToken=$_trustedClientToken'
      '&Sec-MS-GEC=$secMsGec'
      '&Sec-MS-GEC-Version=1-$_chromiumVersion'
      '&ConnectionId=$connId',
    );

    final channel = WebSocketChannel.connect(uri);
    await channel.ready;

    final audioChunks = <Uint8List>[];
    final completer = Completer<Uint8List>();

    // 1. Send speech.config
    final timestamp = _rfc1123Timestamp();
    channel.sink.add(
      'X-Timestamp:$timestamp\r\n'
      'Content-Type:application/json; charset=utf-8\r\n'
      'Path:speech.config\r\n\r\n'
      '{"context":{"synthesis":{"audio":{"metadataoptions":'
      '{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"},'
      '"outputFormat":"$_outputFormat"}}}}',
    );

    // 2. Send SSML
    final requestId = _uuid.v4().replaceAll('-', '');
    final escapedText = _escapeXml(text);
    channel.sink.add(
      'X-RequestId:$requestId\r\n'
      'Content-Type:application/ssml+xml\r\n'
      'X-Timestamp:${timestamp}Z\r\n'
      'Path:ssml\r\n\r\n'
      '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ko-KR">'
      '<voice name="$voice">'
      '<prosody pitch="$pitch" rate="$rate" volume="$volume">'
      '$escapedText'
      '</prosody>'
      '</voice>'
      '</speak>',
    );

    // 3. Listen for audio data
    channel.stream.listen(
      (data) {
        if (data is List<int>) {
          // Binary message: [2-byte header length][header text][audio bytes]
          final bytes = Uint8List.fromList(data);
          if (bytes.length > 2) {
            final headerLen = (bytes[0] << 8) | bytes[1];
            final audioStart = 2 + headerLen;
            if (audioStart <= bytes.length) {
              final header = utf8.decode(bytes.sublist(2, audioStart));
              if (header.contains('Path:audio')) {
                audioChunks.add(bytes.sublist(audioStart));
              }
            }
          }
        } else if (data is String) {
          if (data.contains('Path:turn.end')) {
            _completeWith(completer, audioChunks);
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        _completeWith(completer, audioChunks);
      },
    );

    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 15),
      );
      await channel.sink.close();
      return result;
    } catch (e) {
      await channel.sink.close();
      rethrow;
    }
  }

  void _completeWith(Completer<Uint8List> completer, List<Uint8List> chunks) {
    if (completer.isCompleted) return;
    if (chunks.isEmpty) {
      completer.completeError('No audio data received');
      return;
    }
    final totalLen = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final result = Uint8List(totalLen);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    completer.complete(result);
  }

  /// Generate Sec-MS-GEC authentication token.
  String _generateSecMsGec() {
    const winEpoch = 11644473600; // seconds between 1601-01-01 and 1970-01-01
    final nowSec = DateTime.now().millisecondsSinceEpoch / 1000;
    var ticks = ((nowSec + winEpoch) * 10000000).toInt();
    ticks -= ticks % 3000000000; // Round to nearest 5 minutes
    final strToHash = '$ticks$_trustedClientToken';
    return sha256.convert(utf8.encode(strToHash)).toString().toUpperCase();
  }

  String _rfc1123Timestamp() {
    final now = DateTime.now().toUtc();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[now.weekday - 1]}, '
        '${now.day.toString().padLeft(2, '0')} '
        '${months[now.month - 1]} ${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')} GMT';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
