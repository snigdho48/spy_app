import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_states.dart';

/// Monitor-side viewer for the remote device address book, sourced from the
/// latest `contact.snapshot` (GET /events/contacts/latest/). Consent scope:
/// `contacts`. Photos are never captured.
class ContactsTab extends StatefulWidget {
  const ContactsTab({
    super.key,
    required this.snapshot,
    required this.isLoading,
  });

  final Map<String, dynamic>? snapshot;
  final bool isLoading;

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  String _query = '';

  List<Map<String, dynamic>> get _contacts {
    final raw = widget.snapshot?['contacts'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    final all = _contacts;
    if (q.isEmpty) return all;
    return all.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phones = (c['phones'] as List?)?.join(' ').toLowerCase() ?? '';
      final emails = (c['emails'] as List?)?.join(' ').toLowerCase() ?? '';
      return name.contains(q) || phones.contains(q) || emails.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    if (widget.isLoading && widget.snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filtered;
    final capturedAt = widget.snapshot?['captured_at']?.toString();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, phone, or email',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (capturedAt != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_contacts.length} contacts · snapshot $capturedAt',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  title: 'No contacts yet',
                  message:
                      'The device has not uploaded an address book snapshot. It '
                      'needs contacts permission granted and the contacts scope '
                      'consented.',
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = items[i];
                    final name = (c['name'] ?? '').toString();
                    final phones =
                        (c['phones'] as List?)
                            ?.map((e) => e.toString())
                            .where((e) => e.isNotEmpty)
                            .toList() ??
                        const [];
                    final emails =
                        (c['emails'] as List?)
                            ?.map((e) => e.toString())
                            .where((e) => e.isNotEmpty)
                            .toList() ??
                        const [];
                    final subtitle = [...phones, ...emails].join(' · ');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: tokens.primarySoft,
                        child: Text(
                          _initials(name),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(name.isEmpty ? 'Unnamed contact' : name),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.secondaryText,
                              ),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
