import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Pure Dart Edge TTS client using WebSocket.
/// Connects to Microsoft Edge's Read Aloud backend (free, no API key).
class EdgeTtsService {
  static const _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _wsBase =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static const _outputFormat = 'audio-24khz-48kbitrate-mono-mp3';
  static const _chromiumVersion = '130.0.2849.68';

  static const _uuid = Uuid();

  /// Last error for debugging.
  String? lastError;

  /// Synthesize [text] to MP3 bytes using the given [voice].
  Future<Uint8List> synthesize(
    String text, {
    String voice = 'ko-KR-SunHiNeural',
    String rate = '+0%',
    String pitch = '+0Hz',
    String volume = '+0%',
  }) async {
    if (text.trim().isEmpty) return Uint8List(0);
    lastError = null;

    final connId = _uuid.v4().replaceAll('-', '');
    final secMsGec = _generateSecMsGec();

    final wsUrl =
        '$_wsBase'
        '?TrustedClientToken=$_trustedClientToken'
        '&Sec-MS-GEC=$secMsGec'
        '&Sec-MS-GEC-Version=1-$_chromiumVersion'
        '&ConnectionId=$connId';

    WebSocket? ws;
    try {
      // Connect with required headers
      ws = await WebSocket.connect(
        wsUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/$_chromiumVersion Safari/537.36 '
              'Edg/$_chromiumVersion',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
        },
      );
    } catch (e) {
      lastError = 'WebSocket connect failed: $e';
      rethrow;
    }

    final audioChunks = <Uint8List>[];
    final completer = Completer<Uint8List>();

    // 1. Send speech.config
    final timestamp = _rfc1123Timestamp();
    ws.add(
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
    ws.add(
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
    ws.listen(
      (data) {
        if (data is List<int>) {
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
        lastError = 'WebSocket stream error: $e';
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
      await ws.close();
      return result;
    } catch (e) {
      lastError = 'Synthesis failed: $e';
      try { await ws.close(); } catch (_) {}
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
    const winEpoch = 11644473600;
    final nowSec = DateTime.now().millisecondsSinceEpoch / 1000;
    var ticks = ((nowSec + winEpoch) * 10000000).toInt();
    ticks -= ticks % 3000000000;
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
