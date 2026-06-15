import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/rpc_request.dart';
import '../models/rpc_response.dart';
import '../models/api_exception.dart';

class RpcClient {
  final String baseUrl;
  final http.Client _client;

  RpcClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  int _idCounter = 1;

  Future<T> call<T>({
    required String method,
    Map<String, dynamic>? params,
    required T Function(dynamic) parser,
  }) async {
    final request = RpcRequest(id: _idCounter++, method: method, params: params);
    final response = await _client.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rpcResponse = RpcResponse<T>.fromJson(decoded, parser);
    if (rpcResponse.error != null) {
      throw ApiException(
        code: rpcResponse.id,
        message: rpcResponse.error!,
        statusCode: response.statusCode,
      );
    }
    return rpcResponse.result as T;
  }

  void dispose() => _client.close();
}
