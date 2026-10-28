import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/team/models/team_models.dart';
import 'package:spy_love/features/team/repositories/team_repository.dart';

class TeamController extends ChangeNotifier {
  TeamController(this._repo, this._auth);

  final TeamRepository _repo;
  final AuthController _auth;

  List<TeamMember> members = [];
  List<PendingInvite> invites = [];
  bool isLoading = false;
  String errorMessage = '';
  PendingInvite? lastCreatedInvite;

  bool get canManage => canManageTeam(_auth.user?.role);

  Future<void> load() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final membersResult = await _repo.listMembers();
    membersResult.fold(
      (value) => members = value,
      (error) => errorMessage = error,
    );

    if (canManage) {
      final invitesResult = await _repo.listInvites();
      invitesResult.fold(
        (value) => invites = value,
        (error) {
          // 403 for non-managers is expected; ignore soft failures here.
          if (!error.toLowerCase().contains('forbidden') &&
              !error.contains('403')) {
            errorMessage = errorMessage.isEmpty ? error : errorMessage;
          }
        },
      );
    } else {
      invites = [];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<PendingInvite?> invite(String email, String role) async {
    final result = await _repo.invite(email: email, role: role);
    return result.fold((invite) {
      lastCreatedInvite = invite;
      AppNavigator.snackbar('Invite created', 'Share the link with $email');
      load();
      return invite;
    }, (error) {
      errorMessage = error;
      notifyListeners();
      AppNavigator.snackbar('Invite failed', error);
      return null;
    });
  }

  Future<void> changeRole(TeamMember member, String role) async {
    final result = await _repo.changeRole(
      membershipId: member.id,
      role: role,
    );
    result.fold((_) {
      AppNavigator.snackbar('Role updated', '${member.email} is now $role');
      load();
    }, (error) {
      errorMessage = error;
      notifyListeners();
      AppNavigator.snackbar('Could not change role', error);
    });
  }

  Future<void> removeMember(TeamMember member) async {
    final result = await _repo.removeMember(member.id);
    result.fold((_) {
      AppNavigator.snackbar('Member removed', member.email);
      load();
    }, (error) {
      errorMessage = error;
      notifyListeners();
      AppNavigator.snackbar('Could not remove member', error);
    });
  }

  Future<void> revokeInvite(PendingInvite invite) async {
    final result = await _repo.revokeInvite(invite.id);
    result.fold((_) {
      AppNavigator.snackbar('Invite revoked', invite.email);
      load();
    }, (error) => AppNavigator.snackbar('Could not revoke', error));
  }

  Future<bool> acceptInvite(String token) async {
    final result = await _repo.acceptInvite(token);
    if (result.isRight) {
      AppNavigator.snackbar('Invite not accepted', result.right);
      return false;
    }
    await _auth.refreshUser();
    AppNavigator.snackbar('Welcome', 'You joined the workspace');
    return true;
  }

  Future<void> declineInvite(String token) async {
    final result = await _repo.declineInvite(token);
    result.fold(
      (_) => AppNavigator.snackbar('Invite declined', ''),
      (error) => AppNavigator.snackbar('Could not decline', error),
    );
  }

  Future<void> copyInviteLink(PendingInvite invite) async {
    final link = invite.inviteLink ?? invite.token ?? '';
    if (link.isEmpty) {
      AppNavigator.snackbar('No link', 'Create a new invite to get a share link');
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    AppNavigator.snackbar('Copied', 'Invite link copied to clipboard');
  }
}
