# -*- coding: utf-8 -*-
"""Refuses a release bundle that is not fit to upload to Google Play.

    python tool/verify_release.py build/app/outputs/bundle/release/app-release.aab

Exists because of one silent failure that nothing else catches. Ad unit IDs are
compile-time constants (`String.fromEnvironment`), so a bundle built without
`--dart-define-from-file=admob.json` ships Google's *test* units. That build
runs perfectly, shows every real user an ad labelled "Test Ad", and earns
nothing. Play does not warn you. AdMob does not warn you. It is identical to a
correct build in every way a human would check.

`AdConfig.isUsingTestUnits` cannot help: a Dart test runs with no dart-defines,
so it always reports test units. The only place the truth exists is the built
artefact, so this reads the artefact.

Also accepts an .apk, which is useful for proving the check actually works: the
APK used for device testing is deliberately built without the defines, so it
must fail.
"""

import argparse
import re
import sys
import zipfile

# Google's sample publisher. Any unit under it can never earn money.
TEST_PUBLISHER = '3940256099942544'

UNIT_RE = re.compile(rb'ca-app-pub-[0-9]+/[0-9]+')
APP_ID_RE = re.compile(rb'ca-app-pub-[0-9]+~[0-9]+')

EXPECTED_TEMPLATES = 13


class Layout:
    """Where things live, which differs between a bundle and an apk."""

    def __init__(self, is_bundle):
        self.is_bundle = is_bundle
        self.prefix = 'base/' if is_bundle else ''

    @property
    def manifest(self):
        return self.prefix + ('manifest/' if self.is_bundle else '') \
            + 'AndroidManifest.xml'

    def libs(self, names):
        return [n for n in names if n.endswith('libapp.so')]

    def templates(self, names):
        return [n for n in names
                if '/assets/templates/' in n and n.endswith('.jpg')]


def check(results, ok, label, detail):
    results.append((ok, label, detail))
    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artefact', help='path to the .aab (or .apk) to check')
    parser.add_argument(
        '--min-version-code', type=int, default=None,
        help='fail if pubspec declares a version code below this. Play rejects '
             'a version code that has already been uploaded.')
    args = parser.parse_args()

    try:
        archive = zipfile.ZipFile(args.artefact)
    except (OSError, zipfile.BadZipFile) as error:
        print('cannot open %s: %s' % (args.artefact, error))
        return 2

    names = archive.namelist()
    layout = Layout(args.artefact.endswith('.aab'))
    results = []

    # --- ad unit IDs -------------------------------------------------------
    units = set()
    for lib in layout.libs(names):
        for match in UNIT_RE.findall(archive.read(lib)):
            units.add(match.decode())

    test_units = sorted(u for u in units if TEST_PUBLISHER in u)
    real_units = sorted(u for u in units if TEST_PUBLISHER not in u)

    if not units:
        check(results, False, 'ad unit IDs',
              'none found at all - the ads SDK may have been stripped')
    elif test_units:
        check(results, False, 'ad unit IDs',
              'TEST units present, this build earns nothing: %s'
              % ', '.join(test_units))
    else:
        check(results, True, 'ad unit IDs',
              '%d real: %s' % (len(real_units), ', '.join(real_units)))

    # --- manifest ----------------------------------------------------------
    try:
        manifest = archive.read(layout.manifest)
    except KeyError:
        manifest = b''
        check(results, False, 'manifest', 'not found at ' + layout.manifest)

    if manifest:
        app_ids = [m.decode() for m in APP_ID_RE.findall(manifest)]
        # An .apk stores its manifest as binary XML, where the string may not
        # appear literally. Absence there is inconclusive rather than a failure
        # of the build, so it is only fatal for a bundle.
        if app_ids:
            check(results, TEST_PUBLISHER not in app_ids[0], 'AdMob App ID',
                  app_ids[0] + (' - TEST' if TEST_PUBLISHER in app_ids[0]
                                else ''))
        elif layout.is_bundle:
            check(results, False, 'AdMob App ID',
                  'missing - the app crashes on launch without it')
        else:
            check(results, True, 'AdMob App ID',
                  'not readable from a binary apk manifest (not checked)')

        billing = b'com.android.vending.BILLING' in manifest
        if billing:
            check(results, True, 'Play Billing permission', 'present')
        elif layout.is_bundle:
            check(results, False, 'Play Billing permission',
                  'missing - Premium would be unbuyable')
        else:
            # Same caveat as the App ID: an apk manifest is binary XML and the
            # permission name is not guaranteed to appear literally.
            check(results, True, 'Play Billing permission',
                  'not readable from a binary apk manifest (not checked)')

    # --- signing -----------------------------------------------------------
    signatures = [n for n in names
                  if n.startswith('META-INF/') and n.endswith(('.RSA', '.EC'))]
    if layout.is_bundle:
        upload_signed = any('UPLOAD' in n.upper() for n in signatures)
        check(results, upload_signed, 'signing',
              ', '.join(signatures) if signatures
              else 'unsigned - Play will reject the upload')
    else:
        # An apk is signed with the v2/v3 scheme, which lives in a signing block
        # outside the zip entries. Absence of META-INF proves nothing.
        check(results, True, 'signing',
              'v2/v3 block, not visible in the zip (not checked)')

    # --- bundled assets ----------------------------------------------------
    templates = layout.templates(names)
    check(results, len(templates) == EXPECTED_TEMPLATES, 'template artwork',
          '%d of %d bundled' % (len(templates), EXPECTED_TEMPLATES))

    # --- version code ------------------------------------------------------
    # Read from pubspec rather than the artefact: a bundle stores its manifest
    # as protobuf, and decoding an int out of it is far more fragile than
    # reading the value the build was given.
    version_code = None
    try:
        with open('pubspec.yaml', encoding='utf-8') as handle:
            for line in handle:
                if line.startswith('version:') and '+' in line:
                    version_code = int(line.split('+')[1].strip())
                    break
    except OSError:
        pass

    if version_code is None:
        check(results, False, 'version code',
              'could not read it from pubspec.yaml')
    elif args.min_version_code is not None:
        check(results, version_code >= args.min_version_code, 'version code',
              '%d (needs >= %d; bump the +N in pubspec.yaml)'
              % (version_code, args.min_version_code))
    else:
        check(results, True, 'version code',
              '%d - must be higher than any previously uploaded' % version_code)

    # --- report ------------------------------------------------------------
    print('\n%s\n' % args.artefact)
    for ok, label, detail in results:
        print('  %s  %-24s %s' % ('PASS' if ok else 'FAIL', label, detail))

    failed = [label for ok, label, _ in results if not ok]
    if failed:
        print('\nNOT FIT TO UPLOAD - %s\n' % ', '.join(failed))
        print('A correct release bundle is built with:')
        print('  flutter build appbundle --release \\')
        print('    --dart-define-from-file=admob.json \\')
        print('    -PadmobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY\n')
        return 1

    print('\nOK to upload.\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
