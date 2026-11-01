#!/usr/bin/env python3
"""Run actual macOS media registrations in the release Flutter engine/native asset."""
import argparse
import datetime
import json
from pathlib import Path
import re
import shutil
import subprocess

EXAMPLE = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--allow-unavailable-global', action='store_true',
                        help='CI only: require app-scope checks but report denied global tap separately')
    parser.add_argument('--output-dir', type=Path, default=EXAMPLE / 'build/compatibility_audit/macos-media')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / 'report.json').unlink(missing_ok=True)
    flutter = shutil.which('flutter')
    if not flutter:
        raise RuntimeError('flutter must be on PATH')

    def run(command, name, timeout=1200):
        print(f'Running {name}', flush=True)
        result = subprocess.run(command, cwd=EXAMPLE, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        (output / f'{name}.log').write_text(result.stdout)
        if result.returncode:
            print(result.stdout[-12000:])
        return result

    if not args.skip_build:
        run([flutter, 'build', 'macos', '--release', '-t', 'test_support/macos_media_probe.dart'],
            'release-build').check_returncode()
    app = EXAMPLE / 'build/macos/Build/Products/Release/hotkey_manager_example.app'
    frameworks = app / 'Contents/Frameworks'
    sdk = Path(flutter).resolve().parents[1]
    variants = list((sdk / 'bin/cache/artifacts/engine').glob(
        'darwin*-release/FlutterMacOS.xcframework/macos-*/FlutterMacOS.framework/Headers/FlutterMacOS.h'))
    if not variants:
        raise RuntimeError('Release Flutter framework headers not found')
    framework_headers = variants[0].parents[2]
    host = output / 'macos_media_host'
    run(['clang++', '-std=c++17', '-fobjc-arc', str(EXAMPLE / 'test_support/macos_media_host.mm'),
         '-F' + str(framework_headers), '-framework', 'FlutterMacOS', '-framework', 'Cocoa',
         '-Wl,-rpath,' + str(frameworks), '-o', str(host)], 'host-build').check_returncode()
    command = [str(host), str(frameworks / 'App.framework')]
    if args.allow_unavailable_global:
        command.append('--allow-unavailable-global')
    result = run(command, 'runtime', timeout=45)
    matches = re.findall(r'HOTKEY_MACOS_MEDIA_PROBE (\{[^\n]+\})', result.stdout)
    if not matches:
        raise RuntimeError('No structured result from AOT media probe')
    report = json.loads(matches[-1])
    report.update({'verifiedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   'localDependencyOverrides': (EXAMPLE / 'pubspec_overrides.yaml').exists()})
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    result.check_returncode()
    if not report['passed'] or (not args.allow_unavailable_global and not report['globalMediaVerified']):
        raise RuntimeError('Required media checks did not pass')


if __name__ == '__main__':
    main()
