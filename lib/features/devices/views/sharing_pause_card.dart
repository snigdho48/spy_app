import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/features/monitoring/monitored_device_storage.dart';
import 'package:spy_love/features/monitoring/monitoring_service.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';

const _pauseDurations = <int>[15, 30, 60, 120, 240];

/// Owner-only pause/resume controls for the device this phone is monitoring as.
class SharingPauseCard extends StatefulWidget {
  const SharingPauseCard({super.key});

  @override
  State<SharingPauseCard> createState() => _SharingPauseCardState();
}

class _SharingPauseCardState extends State<SharingPauseCard> {
  String? _deviceId;
  SharingState _sharing = SharingState.inactive;
  bool _loading = true;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final id = await MonitoredDeviceStorage.getDeviceId();
    if (!mounted) return;
    if (id == null || id.isEmpty) {
      setState(() {
        _deviceId = null;
        _loading = false;
      });
      return;
    }
    _deviceId = id;
    await _refresh();
  }

  Future<void> _refresh() async {
    final id = _deviceId;
    if (id == null) return;
    final repo = context.read<DeviceRepository>();
    final result = await repo.getOwnedDeviceStatus(id);
    if (!mounted) return;
    result.fold(
      (status) {
        final monitoring = context.read<MonitoringService>();
        monitoring.applySharingState(status.sharing);
        setState(() {
          _sharing = status.sharing;
          _loading = false;
        });
        _armCountdown();
      },
      (_) => setState(() => _loading = false),
    );
  }

  void _armCountdown() {
    _tick?.cancel();
    if (!_sharing.paused || _sharing.pausedUntil == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final until = _sharing.pausedUntil;
      if (until == null) return;
      final remaining =
          until.toUtc().difference(DateTime.now().toUtc()).inSeconds;
      if (!mounted) return;
      if (remaining <= 0) {
        setState(() => _sharing = SharingState.inactive);
        _tick?.cancel();
        unawaited(_refresh());
      } else {
        setState(() {
          _sharing = SharingState(
            paused: true,
            pausedUntil: until,
            resumesInSeconds: remaining,
          );
        });
      }
    });
  }

  Future<void> _pause(int minutes) async {
    setState(() => _busy = true);
    final monitoring = context.read<MonitoringService>();
    final state = await monitoring.pauseSharing(minutes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (state != null) _sharing = state;
    });
    _armCountdown();
  }

  Future<void> _resume() async {
    setState(() => _busy = true);
    final monitoring = context.read<MonitoringService>();
    final state = await monitoring.resumeSharing();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (state != null) _sharing = state;
    });
    _tick?.cancel();
  }

  String _formatCountdown() {
    final seconds = _sharing.resumesInSeconds ??
        (_sharing.pausedUntil == null
            ? 0
            : _sharing.pausedUntil!
                .toUtc()
                .difference(DateTime.now().toUtc())
                .inSeconds);
    final safe = seconds < 0 ? 0 : seconds;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _labelFor(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    return '${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_deviceId == null) return const SizedBox.shrink();

    final tokens = context.tokens;
    final theme = Theme.of(context);
    final paused = _sharing.paused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pause sharing', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          color: paused ? tokens.warningSoft : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paused ? 'Sharing is paused' : 'Temporarily stop telemetry',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                paused
                    ? 'Uploads are dropped until the pause ends. Consent stays active. Resumes in ${_formatCountdown()}.'
                    : 'Only you (the monitored person) can pause. Monitors see the pause state but cannot change it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (paused)
                AppButton(
                  label: 'Resume sharing now',
                  icon: Icons.play_circle_outline,
                  onPressed: _busy ? null : _resume,
                )
              else
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _pauseDurations.map((minutes) {
                    return ActionChip(
                      label: Text('Pause ${_labelFor(minutes)}'),
                      onPressed: _busy ? null : () => _pause(minutes),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
