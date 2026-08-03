import 'package:flutter/material.dart';
import 'package:meribiodata/core/widgets/milestone_placeholder.dart';

class EditorScreen extends StatelessWidget {
  const EditorScreen({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context) => const MilestonePlaceholder(
    title: 'Form Editor',
    milestone: 'M2',
    summary:
        'Schema-driven sectioned form with autosave, a progress indicator, and '
        'a per-field menu to rename, hide, mark sensitive, reorder or delete.',
  );
}
