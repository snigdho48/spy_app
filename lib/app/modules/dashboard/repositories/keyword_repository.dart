import 'package:spy_love/app/core/constants/api_constants.dart';
import 'package:spy_love/app/core/network/api_service.dart';
import 'package:spy_love/app/core/network/http_method.dart';
import 'package:spy_love/app/core/types/either.dart';
import 'package:spy_love/app/modules/dashboard/models/keyword_model.dart';

class KeywordRepository {
  KeywordRepository(this._api);

  final ApiService _api;

  Future<Either<List<KeywordModel>, String>> list() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.keywords,
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) {
      final results = result.left['results'] as List<dynamic>? ?? const [];
      return Left(
        results
            .map((e) => KeywordModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return Right(result.right);
  }

  Future<Either<KeywordModel, String>> create(String word) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.keywords,
      method: HttpMethod.post,
      body: {'word': word},
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) {
      return Left(KeywordModel.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<void, String>> delete(String id) async {
    final result = await _api.send<void>(
      url: ApiConstants.keywordDetail(id),
      method: HttpMethod.delete,
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return const Left(null);
    return Right(result.right);
  }
}
