import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/team/controllers/team_controller.dart';
import 'package:spy_love/features/team/models/team_models.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/app_text_field.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

class TeamMembersView extends StatefulWidget {
  const TeamMembersView({super.key});

  @override
  State<TeamMembersView> createState() => _TeamMembersViewState();
}

class _TeamMembersViewState extends State<TeamMembersView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeamController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final team = context.watch<TeamController>();
    final auth = context.watch<AuthController>();
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team & invites'),
      ),
      body: AppPage(
        children: [
          const PageIntro(
            title: 'Workspace members',
            subtitle:
                'Everyone here opted in. Owners and admins can invite, change roles, or remove members.',
          ),
          if (team.errorMessage.isNotEmpty) ...[
            Text(
              team.errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (team.isLoading && team.members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (team.members.isEmpty)
            const EmptyState(
              title: 'No members yet',
              message: 'Invite someone by email to share this workspace.',
              icon: Icons.group_outlined,
            )
          else
            ...team.members.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Semantics(
                    label: 'Member ${m.fullName.isNotEmpty ? m.fullName : m.email}, role ${m.role}',
                    child: AppCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            child: Text(
                              ((m.fullName.isNotEmpty ? m.fullName : m.email)
                                      .isNotEmpty
                                  ? (m.fullName.isNotEmpty ? m.fullName : m.email)[0]
                                  : '?')
                                  .toUpperCase(),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.fullName.isNotEmpty ? m.fullName : m.email,
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  m.email,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: tokens.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: m.role.toUpperCase(),
                            tone: m.role == 'owner'
                                ? StatusTone.success
                                : StatusTone.info,
                            pulse: false,
                          ),
                          if (team.canManage && m.userId != auth.user?.id) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              tooltip: 'Manage member',
                              onSelected: (value) async {
                                if (value == 'remove') {
                                  await team.removeMember(m);
                                } else {
                                  await team.changeRole(m, value);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'admin',
                                  child: Text('Make admin'),
                                ),
                                const PopupMenuItem(
                                  value: 'monitor',
                                  child: Text('Make monitor'),
                                ),
                                const PopupMenuItem(
                                  value: 'viewer',
                                  child: Text('Make viewer'),
                                ),
                                if (auth.user?.role == 'owner')
                                  const PopupMenuItem(
                                    value: 'owner',
                                    child: Text('Make owner'),
                                  ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )),
          if (team.canManage) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Invite by email', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _InviteForm(onInvite: team.invite),
            if (team.lastCreatedInvite?.inviteLink != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shareable invite link',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      team.lastCreatedInvite!.inviteLink!,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        AppButton(
                          label: 'Copy',
                          icon: Icons.copy,
                          variant: AppButtonVariant.secondary,
                          expand: false,
                          onPressed: () =>
                              team.copyInviteLink(team.lastCreatedInvite!),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'Share',
                          icon: Icons.share_outlined,
                          expand: false,
                          onPressed: () {
                            final link = team.lastCreatedInvite!.inviteLink!;
                            SharePlus.instance.share(
                              ShareParams(text: link),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (team.invites.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Pending invites', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              ...team.invites.map(
                (inv) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inv.email, style: theme.textTheme.titleMedium),
                              Text(
                                '${inv.role} · expires ${inv.expiresAt ?? 'soon'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: tokens.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Revoke invite',
                          onPressed: () => team.revokeInvite(inv),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Accept an invite', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _AcceptInviteForm(
            onAccept: team.acceptInvite,
            onDecline: team.declineInvite,
          ),
        ],
      ),
    );
  }
}

class _InviteForm extends StatefulWidget {
  const _InviteForm({required this.onInvite});

  final Future<PendingInvite?> Function(String email, String role) onInvite;

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _email = TextEditingController();
  String _role = 'monitor';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'monitor', child: Text('Monitor')),
              DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'monitor'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Send invite',
            icon: Icons.person_add_alt_1,
            loading: _busy,
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await widget.onInvite(_email.text, _role);
                    if (mounted) setState(() => _busy = false);
                  },
          ),
        ],
      ),
    );
  }
}

class _AcceptInviteForm extends StatefulWidget {
  const _AcceptInviteForm({
    required this.onAccept,
    required this.onDecline,
  });

  final Future<bool> Function(String token) onAccept;
  final Future<void> Function(String token) onDecline;

  @override
  State<_AcceptInviteForm> createState() => _AcceptInviteFormState();
}

class _AcceptInviteFormState extends State<_AcceptInviteForm> {
  final _token = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppTextField(
            controller: _token,
            label: 'Invite token or paste link token',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Accept',
                  loading: _busy,
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await widget.onAccept(_token.text);
                          if (mounted) setState(() => _busy = false);
                        },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Decline',
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await widget.onDecline(_token.text);
                          if (mounted) setState(() => _busy = false);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
