"""Restore private signing material temporarily, build and verify the release."""
import base64
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NAMES = ('SIGNING_KEYSTORE_BASE64', 'SIGNING_STORE_PASSWORD', 'SIGNING_KEY_ALIAS', 'SIGNING_KEY_PASSWORD')

def run(args, capture=False):
    env = os.environ.copy()
    for name in NAMES:
        env.pop(name, None)
    return subprocess.run(args, cwd=ROOT, env=env, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None)

def prop(value):
    return (value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r')
            .replace('=', '\\=').replace(':', '\\:').replace(' ', '\\ '))

def main():
    missing = [name for name in (*NAMES, 'SIGNING_CERT_SHA256') if not os.environ.get(name)]
    if missing:
        raise SystemExit('Missing signing configuration: ' + ', '.join(missing))
    expected = os.environ['SIGNING_CERT_SHA256'].strip().lower()
    if not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise SystemExit('Invalid SIGNING_CERT_SHA256 variable')
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
    tools = sdk / 'build-tools/36.0.0'
    build_number = 1000 + int(os.environ.get('GITHUB_RUN_NUMBER', '1'))
    key_properties = ROOT / 'android/key.properties'
    if key_properties.exists():
        raise SystemExit('Refusing to overwrite existing android/key.properties')
    created_properties = False
    os.umask(0o077)
    try:
        with tempfile.TemporaryDirectory(prefix='perfmtk-signing-', dir=os.environ.get('RUNNER_TEMP')) as directory:
            private = Path(directory).resolve()
            keystore = private / 'release.jks'
            store_password = private / 'store-password'
            certificate = private / 'certificate.der'
            keystore.write_bytes(base64.b64decode(''.join(os.environ[NAMES[0]].split()), validate=True))
            store_password.write_text(os.environ[NAMES[1]] + '\n')
            run(['keytool', '-exportcert', '-keystore', str(keystore), '-alias', os.environ[NAMES[2]],
                 '-storepass:file', str(store_password), '-file', str(certificate)], capture=True)
            if hashlib.sha256(certificate.read_bytes()).hexdigest() != expected:
                raise SystemExit('Keystore certificate differs from fixed signing fingerprint')
            values = {'storeFile': str(keystore), 'storePassword': os.environ[NAMES[1]],
                      'keyAlias': os.environ[NAMES[2]], 'keyPassword': os.environ[NAMES[3]]}
            key_properties.write_text(''.join(key + '=' + prop(value) + '\n' for key, value in values.items()))
            created_properties = True
            run(['flutter', 'build', 'apk', '--release', '--no-pub',
                 '--target-platform', 'android-arm,android-arm64,android-x64',
                 '--build-number', str(build_number)])
            apk = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
            verified = run([str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(apk)], capture=True).stdout
            fingerprints = re.findall(r'Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F]+)', verified)
            if len(fingerprints) != 1 or fingerprints[0].lower() != expected:
                raise SystemExit('APK does not have the expected single signing certificate')
            badging = run([str(tools / 'aapt'), 'dump', 'badging', str(apk)], capture=True).stdout
            package = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
            if not package or package.group(1) != 'com.perfmtk.manager' or package.group(2) != str(build_number):
                raise SystemExit('APK package name or versionCode differs from expected values')
            if 'application-debuggable' in badging:
                raise SystemExit('Release APK is unexpectedly debuggable')
            with zipfile.ZipFile(apk) as archive:
                entries = set(archive.namelist())
                assert {'lib/arm64-v8a/libapp.so', 'lib/arm64-v8a/libflutter.so'} <= entries, 'Missing ARM64 runtime'
            dist = ROOT / 'dist'
            dist.mkdir(exist_ok=True)
            output = dist / 'PerfMTK-Manager-8.9.0-zh.apk'
            shutil.copyfile(apk, output)
            output.chmod(0o644)
            digest = hashlib.sha256(output.read_bytes()).hexdigest()
            (dist / 'SHA256SUMS.txt').write_text(digest + '  ' + output.name + '\n')
            info = ('Package: ' + package.group(1) + '\nVersion: ' + package.group(3)
                    + '\nVersion code: ' + str(build_number) + '\nSize bytes: ' + str(output.stat().st_size)
                    + '\nAPK SHA-256: ' + digest + '\nCertificate SHA-256: ' + expected
                    + '\nCommit: ' + os.environ.get('GITHUB_SHA', 'local')
                    + '\nChecks: Flutter analyze, all Flutter tests, native locale parity, Release build, '
                      'apksigner verify, fixed certificate, package/version, ARM64, non-debuggable\n')
            (dist / 'BUILD-INFO.txt').write_text(info)
            print(info)
            summary = os.environ.get('GITHUB_STEP_SUMMARY')
            if summary:
                with open(summary, 'a') as handle:
                    handle.write('## Signed Chinese APK verified\n\n' + '\n'.join('    ' + line for line in info.splitlines()) + '\n')
    finally:
        if created_properties:
            # Delete only the exact property file created by this invocation.
            assert key_properties.resolve() == ROOT / 'android/key.properties'
            key_properties.unlink(missing_ok=True)

if __name__ == '__main__':
    main()
