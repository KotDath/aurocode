/// JSON-RPC codec for LSP protocol.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities/lsp_messages.dart';

/// Transforms a byte stream into parsed LSP messages.
class LspMessageDecoder extends StreamTransformerBase<List<int>, LspMessage> {
  const LspMessageDecoder();

  @override
  Stream<LspMessage> bind(Stream<List<int>> stream) {
    return Stream.eventTransformed(stream, (sink) => _LspMessageSink(sink));
  }
}

class _LspMessageSink implements EventSink<List<int>> {
  final EventSink<LspMessage> _outputSink;
  final BytesBuilder _buffer = BytesBuilder();
  int? _expectedLength;

  _LspMessageSink(this._outputSink);

  @override
  void add(List<int> data) {
    _buffer.add(data);
    _processBuffer();
  }

  void _processBuffer() {
    while (true) {
      final bytes = _buffer.toBytes();

      if (_expectedLength == null) {
        final headerEnd = _findHeaderEnd(bytes);
        if (headerEnd == -1) return;

        final headerBytes = bytes.sublist(0, headerEnd);
        final headerString = utf8.decode(headerBytes);

        _expectedLength = _parseContentLength(headerString);
        if (_expectedLength == null) {
          _outputSink.addError(
            const FormatException('Missing Content-Length header'),
          );
          return;
        }

        _buffer.clear();
        _buffer.add(bytes.sublist(headerEnd + 4));
      }

      final currentBytes = _buffer.toBytes();
      if (currentBytes.length < _expectedLength!) return;

      final messageBytes = currentBytes.sublist(0, _expectedLength!);
      final remaining = currentBytes.sublist(_expectedLength!);

      _buffer.clear();
      _buffer.add(remaining);
      _expectedLength = null;

      try {
        final jsonString = utf8.decode(messageBytes);
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final message = parseLspMessage(json);
        _outputSink.add(message);
      } catch (e) {
        _outputSink.addError(e);
      }
    }
  }

  int _findHeaderEnd(Uint8List bytes) {
    for (var i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  int? _parseContentLength(String header) {
    final lines = header.split('\r\n');
    for (final line in lines) {
      if (line.toLowerCase().startsWith('content-length:')) {
        final value = line.substring('content-length:'.length).trim();
        return int.tryParse(value);
      }
    }
    return null;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _outputSink.addError(error, stackTrace);
  }

  @override
  void close() {
    _outputSink.close();
  }
}

/// Encodes an LspMessage to bytes with Content-Length header.
List<int> encodeLspMessage(LspMessage message) {
  return utf8.encode(message.encode());
}
