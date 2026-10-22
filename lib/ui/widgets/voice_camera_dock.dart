import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class VoiceCameraDock extends StatelessWidget {
  final bool isListening;
  final VoidCallback onVoiceTap;
  final VoidCallback onCameraTap;

  const VoiceCameraDock({
    super.key,
    required this.isListening,
    required this.onVoiceTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'camera_fab',
          onPressed: onCameraTap,
          backgroundColor: AppTheme.pureWhite,
          foregroundColor: AppTheme.darkGreen,
          elevation: 4,
          shape: const CircleBorder(
            side: BorderSide(color: AppTheme.softGreen, width: 1.5),
          ),
          child: const Icon(Icons.camera_alt_outlined, size: 24),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.large(
          heroTag: 'voice_fab',
          onPressed: onVoiceTap,
          backgroundColor:
              isListening ? AppTheme.darkGreen : AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(Icons.mic_none_rounded, size: 30),
        ),
      ],
    );
  }
}
