import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/config/legal_links.dart';

void main() {
  // This replaces a placeholder guard that failed until a real URL landed.
  // Now the risk is different: Play requires the policy link in the store
  // listing to match the one in the app, and the two are edited in different
  // places months apart. This at least fails loudly if the app's copy is
  // emptied or left as a stub.
  test('the privacy policy URL is a real, absolute https URL', () {
    final uri = Uri.tryParse(LegalLinks.privacyPolicy);

    expect(uri, isNotNull);
    expect(uri!.isAbsolute, isTrue);
    expect(uri.scheme, 'https');
    expect(uri.host, isNotEmpty);
    expect(
      LegalLinks.privacyPolicy,
      isNot(anyOf(contains('placeholder'), contains('example'))),
      reason: 'The app would link users to a page that does not exist.',
    );
  });
}
