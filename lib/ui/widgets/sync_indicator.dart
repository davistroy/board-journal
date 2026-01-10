import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sync_providers.dart';
import '../../services/sync/sync.dart';

/// Sync indicator widget for app bar or status area.
///
/// Per requirements:
/// - Cloud check: synced
/// - Cloud upload: uploading
/// - Cloud download: downloading
/// - Cloud off: offline
/// - Cloud warning: error
/// - Tap to see sync details / retry
class SyncIndicator extends ConsumerWidget {
  /// Size of the icon.
  final double iconSize;

  /// Color override for the icon.
  final Color? iconColor;

  /// Whether to show the pending count badge.
  final bool showBadge;

  /// Whether tapping shows sync details.
  final bool showDetailsOnTap;

  const SyncIndicator({
    super.key,
    this.iconSize = 24.0,
    this.iconColor,
    this.showBadge = true,
    this.showDetailsOnTap = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncNotifierProvider);
    final pendingCount = ref.watch(pendingChangesCountProvider);

    return GestureDetector(
      onTap: showDetailsOnTap
          ? () => _showSyncDetails(context, ref, syncStatus)
          : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildIcon(context, syncStatus),
          if (showBadge && pendingCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: _buildBadge(context, pendingCount),
            ),
        ],
      ),
    );
  }

  /// Builds the sync status icon.
  Widget _buildIcon(BuildContext context, SyncStatus status) {
    final theme = Theme.of(context);
    final defaultColor = iconColor ?? theme.iconTheme.color ?? Colors.grey;

    IconData icon;
    Color color;
    bool animate = false;

    switch (status.state) {
      case SyncState.idle:
        icon = Icons.cloud_done_outlined;
        color = Colors.green;
        break;
      case SyncState.syncing:
        icon = status.pendingCount > 0
            ? Icons.cloud_upload_outlined
            : Icons.cloud_download_outlined;
        color = theme.colorScheme.primary;
        animate = true;
        break;
      case SyncState.error:
        icon = Icons.cloud_off;
        color = theme.colorScheme.error;
        break;
      case SyncState.offline:
        icon = Icons.cloud_off_outlined;
        color = Colors.grey;
        break;
      case SyncState.pendingChanges:
        icon = Icons.cloud_upload_outlined;
        color = Colors.orange;
        break;
    }

    final iconWidget = Icon(
      icon,
      size: iconSize,
      color: color,
    );

    if (animate) {
      return _AnimatedSyncIcon(
        icon: icon,
        size: iconSize,
        color: color,
      );
    }

    return iconWidget;
  }

  /// Builds the pending count badge.
  Widget _buildBadge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Shows sync details dialog.
  void _showSyncDetails(
    BuildContext context,
    WidgetRef ref,
    SyncStatus status,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SyncDetailsSheet(status: status),
    );
  }
}

/// Animated sync icon for syncing state.
class _AnimatedSyncIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;

  const _AnimatedSyncIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

  @override
  State<_AnimatedSyncIcon> createState() => _AnimatedSyncIconState();
}

class _AnimatedSyncIconState extends State<_AnimatedSyncIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + (0.5 * (1 - _controller.value)),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color,
          ),
        );
      },
    );
  }
}

/// Bottom sheet showing sync details.
class SyncDetailsSheet extends ConsumerWidget {
  final SyncStatus status;

  const SyncDetailsSheet({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIcon(status.state, theme),
              const SizedBox(width: 12),
              Text(
                _getStatusTitle(status.state),
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getStatusDescription(status),
            style: theme.textTheme.bodyMedium,
          ),
          if (lastSyncTime != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last synced: ${_formatLastSync(lastSyncTime)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
          if (status.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (!isOffline)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: status.isSyncing
                    ? null
                    : () {
                        ref.read(syncNotifierProvider.notifier).syncAll();
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.sync),
                label: Text(status.isSyncing ? 'Syncing...' : 'Sync Now'),
              ),
            ),
          if (isOffline)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are offline. Changes will sync when you reconnect.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(SyncState state, ThemeData theme) {
    IconData icon;
    Color color;

    switch (state) {
      case SyncState.idle:
        icon = Icons.cloud_done;
        color = Colors.green;
        break;
      case SyncState.syncing:
        icon = Icons.sync;
        color = theme.colorScheme.primary;
        break;
      case SyncState.error:
        icon = Icons.cloud_off;
        color = theme.colorScheme.error;
        break;
      case SyncState.offline:
        icon = Icons.wifi_off;
        color = Colors.grey;
        break;
      case SyncState.pendingChanges:
        icon = Icons.cloud_upload;
        color = Colors.orange;
        break;
    }

    return Icon(icon, color: color, size: 32);
  }

  String _getStatusTitle(SyncState state) {
    switch (state) {
      case SyncState.idle:
        return 'All Synced';
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.error:
        return 'Sync Error';
      case SyncState.offline:
        return 'Offline';
      case SyncState.pendingChanges:
        return 'Changes Pending';
    }
  }

  String _getStatusDescription(SyncStatus status) {
    switch (status.state) {
      case SyncState.idle:
        return 'Your data is up to date across all devices.';
      case SyncState.syncing:
        return 'Syncing your changes with the server...';
      case SyncState.error:
        return 'There was a problem syncing your data. Please try again.';
      case SyncState.offline:
        return 'You are currently offline. Your changes are saved locally and will sync when you reconnect.';
      case SyncState.pendingChanges:
        return '${status.pendingCount} change${status.pendingCount == 1 ? '' : 's'} waiting to sync.';
    }
  }

  String _formatLastSync(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
  }
}

/// Offline banner widget to show at the top of the screen.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    if (!isOffline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[800],
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'You are offline',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Entry-level sync status badge.
///
/// Shows a small indicator on entries to show their sync status.
class EntrySyncBadge extends StatelessWidget {
  /// The sync status of the entry.
  final String syncStatus;

  /// Size of the badge.
  final double size;

  const EntrySyncBadge({
    super.key,
    required this.syncStatus,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (syncStatus) {
      case 'synced':
        icon = Icons.cloud_done;
        color = Colors.green;
        break;
      case 'pending':
        icon = Icons.cloud_upload;
        color = Colors.orange;
        break;
      case 'conflict':
        icon = Icons.warning;
        color = Colors.red;
        break;
      default:
        icon = Icons.cloud_off;
        color = Colors.grey;
    }

    return Tooltip(
      message: _getTooltipMessage(syncStatus),
      child: Icon(icon, size: size, color: color),
    );
  }

  String _getTooltipMessage(String status) {
    switch (status) {
      case 'synced':
        return 'Synced';
      case 'pending':
        return 'Pending sync';
      case 'conflict':
        return 'Sync conflict';
      default:
        return 'Unknown status';
    }
  }
}

/// Conflict notification widget.
///
/// Shows when a conflict was resolved.
class ConflictNotification extends StatelessWidget {
  /// The entity type that had a conflict.
  final String entityType;

  /// Callback when dismissed.
  final VoidCallback? onDismiss;

  const ConflictNotification({
    super.key,
    required this.entityType,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This $entityType was also edited on another device. Showing most recent version.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                iconSize: 20,
              ),
          ],
        ),
      ),
    );
  }
}
