class RpcRequest {
  final int id;
  final String method;
  final Map<String, dynamic>? params;

  const RpcRequest({
    required this.id,
    required this.method,
    this.params,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };
  }
}
