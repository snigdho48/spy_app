import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/audit/models/audit_log_model.dart';

class AuditRepository {
  AuditRepository(this._api);

  final ApiService _api;

  Future<Either<List<AuditLogModel>, String>> listLogs({
    int pageSize = 100,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.audit,
      method: HttpMethod.get,
      queryParameters: {'page_size': pageSize},
      loader: false,
      resultOverlay: false,
    );

    if (result.isLeft) {
      final results = result.left['results'] as List<dynamic>? ?? const [];
      return Left(
        results
            .map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return Right(result.right);
  }
}
