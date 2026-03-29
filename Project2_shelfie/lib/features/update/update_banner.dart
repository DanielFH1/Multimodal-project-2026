import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/update_service.dart';

/// A sleek bottom banner that notifies the user when an app update is available.
///
/// It adapts its content depending on the current [UpdateStatus]:
///  • **updateAvailable** — "Update available" with an UPDATE button.
///  • **downloading**     — Progress-style message while downloading.
///  • **readyToInstall**  — "Restart to update" with a RESTART button.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);

    // Don't render anything when idle.
    if (updateState.status == UpdateStatus.idle) {
      return const SizedBox.shrink();
    }

    return AnimatedSlide(
      offset: updateState.status == UpdateStatus.idle
          ? const Offset(0, 1)
          : Offset.zero,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: updateState.status == UpdateStatus.idle ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF1A1F2E)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildContent(context, ref, updateState),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    UpdateState updateState,
  ) {
    final notifier = ref.read(updateProvider.notifier);

    switch (updateState.status) {
      case UpdateStatus.updateAvailable:
        return Row(
          children: [
            const _PulsingIcon(
              icon: Icons.system_update_rounded,
              color: Color(0xFFA29BFE),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Update Available',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'A new version is ready for you',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _ActionButton(
              label: 'UPDATE',
              onTap: () => notifier.startFlexibleUpdate(),
            ),
            const SizedBox(width: 4),
            _DismissButton(onTap: () => notifier.dismiss()),
          ],
        );

      case UpdateStatus.downloading:
        return const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA29BFE)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Downloading update…',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case UpdateStatus.readyToInstall:
        return Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF00C853),
              size: 22,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update ready — restart to apply',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _ActionButton(
              label: 'RESTART',
              onTap: () => notifier.completeUpdate(),
            ),
          ],
        );

      case UpdateStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

/// A small gradient action button used in the banner.
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// An X button to dismiss the banner.
class _DismissButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DismissButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(
            Icons.close_rounded,
            color: Colors.white38,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// A gently pulsing icon to draw attention to the update banner.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
          opacity: 0.6 + (_controller.value * 0.4),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 22,
          ),
        );
      },
    );
  }
}
