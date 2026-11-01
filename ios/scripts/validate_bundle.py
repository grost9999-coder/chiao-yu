"""Fail before publishing if the actual IPA contains invalid orientation metadata."""
import argparse
import pathlib
import plistlib
import zipfile

ALL = {
    'UIInterfaceOrientationPortrait',
    'UIInterfaceOrientationPortraitUpsideDown',
    'UIInterfaceOrientationLandscapeLeft',
    'UIInterfaceOrientationLandscapeRight',
}

def validate(info):
    if info.get('CFBundleIdentifier') != 'com.qiaoyu.vendorbookpro':
        raise ValueError('Unexpected bundle identifier')
    if info.get('UIDeviceFamily') != [1]:
        raise ValueError('This release must retain iPhone-only device family [1]')
    for key in ('UISupportedInterfaceOrientations', 'UISupportedInterfaceOrientations~ipad'):
        values = info.get(key)
        if not isinstance(values, list) or set(values) != ALL:
            raise ValueError(f'{key} must be an array with all four orientations (90474)')
    if info.get('UISupportedInterfaceOrientations~iphone') != ['UIInterfaceOrientationPortrait']:
        raise ValueError('The iPhone-specific orientation must remain portrait')
    print('Bundle validated: iPhone family, portrait on iPhone, all orientations for iPad compatibility')

def read_ipa(path):
    with zipfile.ZipFile(path) as archive:
        matches = [name for name in archive.namelist()
                   if name.startswith('Payload/') and name.count('/') == 2 and name.endswith('.app/Info.plist')]
        if len(matches) != 1:
            raise ValueError('Expected exactly one main app Info.plist in IPA')
        return plistlib.loads(archive.read(matches[0]))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('plist', nargs='?')
    parser.add_argument('--ipa-dir')
    args = parser.parse_args()
    if args.ipa_dir:
        files = list(pathlib.Path(args.ipa_dir).glob('*.ipa'))
        if len(files) != 1:
            raise ValueError('Expected exactly one exported IPA')
        validate(read_ipa(files[0]))
    elif args.plist:
        validate(plistlib.loads(pathlib.Path(args.plist).read_bytes()))
    else:
        parser.error('Pass the built app Info.plist or --ipa-dir')

if __name__ == '__main__':
    main()
