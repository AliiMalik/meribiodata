import 'package:flutter/material.dart';
import 'package:meribiodata/core/widgets/milestone_placeholder.dart';

class TemplatePickerScreen extends StatelessWidget {
  const TemplatePickerScreen({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context) => const MilestonePlaceholder(
    title: 'Choose a template',
    milestone: 'M3',
    summary:
        'Visual thumbnails with a live preview rendered from the real data, '
        'including a monochrome print-shop template.',
  );
}
