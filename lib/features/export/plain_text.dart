import 'package:meribiodata/domain/render/rendered_document.dart';

/// The biodata as plain text, for pasting into a chat (#35).
///
/// Built from the [RenderedDocument] rather than from the profile, which is the
/// whole point: that document has already had Shareable masking applied, units
/// converted, digits localised and bidi isolates inserted. Assembling text from
/// the raw profile instead would quietly reintroduce the one mistake this app
/// exists to prevent — a phone number and home address in a WhatsApp group,
/// because the text path forgot the masking the PDF path remembers.
String documentAsPlainText(RenderedDocument document) {
  final buffer = StringBuffer();

  if (document.headerText case final String header when header.isNotEmpty) {
    buffer
      ..writeln(header)
      ..writeln();
  }

  buffer.writeln(document.title);

  for (final section in document.nonEmptySections) {
    buffer
      ..writeln()
      ..writeln(section.title);
    for (final field in section.fields) {
      buffer.writeln('${field.label}: ${field.value}');
    }
  }

  // Follows the watermark exactly: present on a free export, absent once
  // Premium has removed it. A text share that carried the credit when the PDF
  // did not would be an inconsistency the user paid to not have.
  if (document.watermark case final String mark when mark.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(mark);
  }

  return buffer.toString().trimRight();
}
