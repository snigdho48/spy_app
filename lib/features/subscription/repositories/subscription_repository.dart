import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/features/subscription/models/subscription_models.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._api);

  final ApiService _api;

  Future<Either<List<SubscriptionPlan>, String>> listPlans() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.subscriptionPlans,
      method: HttpMethod.get,
      loader: true,
      resultOverlay: false,
    );

    if (result.isLeft) {
      final plans = (result.left['plans'] as List<dynamic>)
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      return Left(plans);
    }
    return Right(result.right);
  }

  Future<Either<Map<String, dynamic>, String>> getCurrent() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.subscriptionCurrent,
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );

    if (result.isLeft) return Left(result.left);
    return Right(result.right);
  }

  Future<Either<SubscriptionInfo, String>> subscribe(String planCode) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.subscriptionSubscribe,
      method: HttpMethod.post,
      body: {'plan_code': planCode},
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(
        SubscriptionInfo.fromJson(
          result.left['subscription'] as Map<String, dynamic>,
        ),
      );
    }
    return Right(result.right);
  }

  Future<Either<Map<String, dynamic>, String>> createWorkspace(
    String name,
  ) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.workspaceCreate,
      method: HttpMethod.post,
      body: {'name': name},
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) return Left(result.left);
    return Right(result.right);
  }
}
