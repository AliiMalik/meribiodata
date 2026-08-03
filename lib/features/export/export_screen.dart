import 'package:flutter/material.dart';
import 'package:meribiodata/core/widgets/milestone_placeholder.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context) => const MilestonePlaceholder(
    title: 'Preview & Export',
    milestone: 'M3 / M5',
    summary:
        'Full-fidelity preview of the selected export mode, with Full vs '
        'Shareable, page size, photo toggle, and three co-equal actions: '
        'Export PDF, Save Image, Share on WhatsApp. No ad banner on this '
        'screen, by policy.',
  );
}
