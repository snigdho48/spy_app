import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/team/models/team_models.dart';

class TeamRepository {
  TeamRepository(this._api);

  final ApiService _api;

  Future<Either<List<TeamMember>, String>> listMembers() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.tenantMembers,
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) {
      final raw = result.left['members'] as List<dynamic>? ?? const [];
      return Left(
        raw
            .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return Right(result.right);
  }

  Future<Either<List<PendingInvite>, String>> listInvites() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.tenantInvites,
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) {
      final raw = result.left['invites'] as List<dynamic>? ?? const [];
      return Left(
        raw
            .map((e) => PendingInvite.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return Right(result.right);
  }

  Future<Either<PendingInvite, String>> invite({
    required String email,
    required String role,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.tenantInvites,
      method: HttpMethod.post,
      body: {'email': email.trim(), 'role': role},
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) {
      final invite = result.left['invite'] as Map<String, dynamic>? ?? result.left;
      return Left(PendingInvite.fromJson(invite));
    }
    return Right(result.right);
  }

  Future<Either<bool, String>> revokeInvite(String id) async {
    final result = await _api.send<dynamic>(
      url: ApiConstants.tenantInviteDetail(id),
      method: HttpMethod.delete,
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return const Left(true);
    return Right(result.right);
  }

  Future<Either<TeamMember, String>> changeRole({
    required String membershipId,
    required String role,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.tenantMemberDetail(membershipId),
      method: HttpMethod.patch,
      body: {'role': role},
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) {
      final member =
          result.left['member'] as Map<String, dynamic>? ?? result.left;
      return Left(TeamMember.fromJson(member));
    }
    return Right(result.right);
  }

  Future<Either<bool, String>> removeMember(String membershipId) async {
    final result = await _api.send<dynamic>(
      url: ApiConstants.tenantMemberDetail(membershipId),
      method: HttpMethod.delete,
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return const Left(true);
    return Right(result.right);
  }

  Future<Either<Map<String, dynamic>, String>> acceptInvite(String token) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.tenantInviteAccept,
      method: HttpMethod.post,
      body: {'token': token.trim()},
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return Left(result.left);
    return Right(result.right);
  }

  Future<Either<bool, String>> declineInvite(String token) async {
    final result = await _api.send<dynamic>(
      url: ApiConstants.tenantInviteDecline,
      method: HttpMethod.post,
      body: {'token': token.trim()},
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return const Left(true);
    return Right(result.right);
  }
}
