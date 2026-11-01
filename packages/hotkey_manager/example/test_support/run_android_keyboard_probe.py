#!/usr/bin/env python3
"""Build/run the Android AOT probe using native events targeted to its Activity."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

EXAMPLE = Path(__file__).resolve().parents[1]
PACKAGE = 'com.example.hotkey_manager_example'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True, help='Explicit adb device serial')
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--output-dir', type=Path, default=EXAMPLE / 'build/compatibility_audit/android')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / 'report.json').unlink(missing_ok=True)
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or Path.home() / 'Library/Android/sdk')
    adb = shutil.which('adb') or str(sdk / 'platform-tools' / ('adb.exe' if os.name == 'nt' else 'adb'))
    adb_args = [adb, '-s', args.serial]

    def run(command, name, cwd=EXAMPLE, timeout=1800, env=None):
        print(f'Running {name}', flush=True)
        result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout, env=env)
        (output / f'{name}.log').write_text(result.stdout)
        if result.returncode:
            print(result.stdout[-12000:])
            raise RuntimeError(f'{name}: exit {result.returncode}')
        return result.stdout

    def prop(name):
        return run([*adb_args, 'shell', 'getprop', name], name).strip()

    abi = prop('ro.product.cpu.abi')
    target = {'arm64-v8a': 'android-arm64', 'x86_64': 'android-x64', 'armeabi-v7a': 'android-arm'}[abi]
    release = prop('ro.build.version.release')
    if not args.skip_build:
        flutter = shutil.which('flutter')
        if not flutter:
            raise RuntimeError('flutter must be available on PATH')
        run([flutter, 'build', 'apk', '--release', '--target-platform', target,
             '-t', 'test_support/android_keyboard_probe.dart'], 'release-build')
        # Flutter can select Android Studio's bundled JDK even when the shell's
        # java/JAVA_HOME points elsewhere. Use the same toolchain for the direct
        # instrumentation task; a newer shell JDK may be unsupported by Gradle.
        doctor = subprocess.run([flutter, 'doctor', '-v'], cwd=EXAMPLE, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        (output / 'flutter-toolchain.log').write_text(doctor.stdout)
        java = re.search(r'Java binary at:\s*(.+)', doctor.stdout)
        gradle_env = dict(os.environ)
        if java:
            gradle_env['JAVA_HOME'] = str(Path(java[1].strip()).parent.parent)
        gradle = ['cmd', '/c', 'gradlew.bat'] if os.name == 'nt' else ['./gradlew']
        run([*gradle, ':app:assembleReleaseAndroidTest',
             f'-Ptarget={EXAMPLE / "test_support/android_keyboard_probe.dart"}', f'-Ptarget-platform={target}'],
            'instrumentation-build', EXAMPLE / 'android', env=gradle_env)
    run([*adb_args, 'install', '-r', str(EXAMPLE / 'build/app/outputs/apk/release/app-release.apk')], 'install-release')
    run([*adb_args, 'install', '-r', '-t',
         str(EXAMPLE / 'build/app/outputs/apk/androidTest/release/app-release-androidTest.apk')], 'install-instrumentation')
    try:
        raw = run([*adb_args, 'shell', 'am', 'instrument', '-w', '-r',
                   f'{PACKAGE}.test/{PACKAGE}.KeyboardProbeRunner'], 'instrumentation', timeout=180)
        matches = re.findall(r'HOTKEY_ANDROID_PROBE (\{[^\n]+\})', raw)
        if not matches:
            raise RuntimeError(f'No structured probe result: {raw[-12000:]}')
        report = json.loads(matches[-1])
        report.update({'verifiedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                       'serial': args.serial, 'androidVersion': release, 'abi': abi,
                       'physicalChromebookTested': False,
                       'localDependencyOverrides': (EXAMPLE / 'pubspec_overrides.yaml').exists()})
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2))
        if not report['passed'] or not report['releaseMode']:
            raise RuntimeError('Android AOT probe failed')
    finally:
        run([*adb_args, 'shell', 'am', 'force-stop', PACKAGE], 'stop-own-example')


if __name__ == '__main__':
    main()
