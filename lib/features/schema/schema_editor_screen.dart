import 'package:flutter/material.dart';
import 'package:meribiodata/core/widgets/milestone_placeholder.dart';

class SchemaEditorScreen extends StatelessWidget {
  const SchemaEditorScreen({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context) => const MilestonePlaceholder(
    title: 'Schema Editor',
    milestone: 'M2',
    summary:
        'Drag to reorder sections and fields, add custom fields and sections, '
        'and reset to the default schema.',
  );
}
