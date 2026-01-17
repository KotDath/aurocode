/// LSP Message types for JSON-RPC 2.0 communication with language servers.
library;

import 'dart:convert';

/// Base class for all LSP messages.
sealed class LspMessage {
  const LspMessage();

  Map<String, dynamic> toJson();

  String encode() {
    final json = jsonEncode(toJson());
    final bytes = utf8.encode(json);
    return 'Content-Length: ${bytes.length}\r\n\r\n$json';
  }
}

/// A request message from client to server.
final class LspRequest extends LspMessage {
  final int id;
  final String method;
  final dynamic params;

  const LspRequest({required this.id, required this.method, this.params});

  @override
  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        if (params != null) 'params': params,
      };
}

/// A response message from server to client.
final class LspResponse extends LspMessage {
  final int id;
  final dynamic result;
  final LspError? error;

  const LspResponse({required this.id, this.result, this.error});

  bool get isSuccess => error == null;
  bool get isError => error != null;

  factory LspResponse.fromJson(Map<String, dynamic> json) {
    return LspResponse(
      id: json['id'] as int,
      result: json['result'],
      error: json['error'] != null
          ? LspError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'id': id,
        if (result != null) 'result': result,
        if (error != null) 'error': error!.toJson(),
      };
}

/// A notification message (no response expected).
final class LspNotification extends LspMessage {
  final String method;
  final dynamic params;

  const LspNotification({required this.method, this.params});

  factory LspNotification.fromJson(Map<String, dynamic> json) {
    return LspNotification(
      method: json['method'] as String,
      params: json['params'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'method': method,
        if (params != null) 'params': params,
      };
}

/// An error object returned in LspResponse.
final class LspError {
  final int code;
  final String message;
  final dynamic data;

  const LspError({required this.code, required this.message, this.data});

  factory LspError.fromJson(Map<String, dynamic> json) {
    return LspError(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };

  @override
  String toString() => 'LspError($code): $message';
}

/// Standard LSP error codes.
abstract final class LspErrorCodes {
  static const parseError = -32700;
  static const invalidRequest = -32600;
  static const methodNotFound = -32601;
  static const invalidParams = -32602;
  static const internalError = -32603;
  static const requestCancelled = -32800;
}

/// Parses incoming JSON into the appropriate LspMessage type.
LspMessage parseLspMessage(Map<String, dynamic> json) {
  if (json.containsKey('id')) {
    if (json.containsKey('method')) {
      return LspRequest(
        id: json['id'] as int,
        method: json['method'] as String,
        params: json['params'],
      );
    } else {
      return LspResponse.fromJson(json);
    }
  } else {
    return LspNotification.fromJson(json);
  }
}
