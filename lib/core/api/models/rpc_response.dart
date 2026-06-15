class RpcResponse<T> {
  final int id;
  final T? result;
  final String? error;

  const RpcResponse({required this.id, this.result, this.error});

  factory RpcResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) parser,
  ) {
    return RpcResponse(
      id: json['id'] as int? ?? 0,
      result: json['result'] != null ? parser(json['result']) : null,
      error: json['error'] as String?,
    );
  }
}
