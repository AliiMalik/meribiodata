import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/config/legal_links.dart';

void main() {
  // The same trick the waitlist URL uses: this test fails the day a real URL
  // is wired in, which is exactly when someone should be reminded to put it in
  // the Play listing too. A placeholder that nobody notices is how an app ships
  // with a privacy policy link that 404s.
  test('the privacy policy URL is still a placeholder', () {
    expect(
      LegalLinks.isPlaceholder,
      isTrue,
      reason:
          'A real privacy policy URL has landed. Delete this test, and make '
          'sure the same URL is set in the Play Console listing and in the '
          'Data Safety form.',
    );
  });
}
