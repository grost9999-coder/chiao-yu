import importlib.util
import pathlib
import plistlib
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('validate_bundle', ROOT / 'scripts/validate_bundle.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class BundleTests(unittest.TestCase):
    def setUp(self):
        self.info = plistlib.loads((ROOT / 'VendorLedger/Info.plist').read_bytes())
        self.info.update(CFBundleIdentifier='com.qiaoyu.vendorbookpro', UIDeviceFamily=[1])

    def test_source_and_valid_archive(self):
        module.validate(self.info)
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / 'app.ipa'
            with zipfile.ZipFile(path, 'w') as z:
                z.writestr('Payload/VendorLedger.app/Info.plist', plistlib.dumps(self.info, fmt=plistlib.FMT_BINARY))
            module.validate(module.read_ipa(path))

    def test_reject_original_90474_and_invalid_type(self):
        for key in ['UISupportedInterfaceOrientations','UISupportedInterfaceOrientations~ipad']:
            for value in [['UIInterfaceOrientationPortrait'], 'UIInterfaceOrientationPortrait', None]:
                info = {**self.info, key: value}
                with self.assertRaises(ValueError): module.validate(info)

    def test_reject_device_family_change(self):
        with self.assertRaises(ValueError): module.validate({**self.info, 'UIDeviceFamily':[1,2]})

    def test_build_uses_explicit_plist_and_validates_ipa(self):
        project = (ROOT / 'project.yml').read_text()
        self.assertIn('GENERATE_INFOPLIST_FILE: NO', project)
        self.assertIn('INFOPLIST_FILE: VendorLedger/Info.plist', project)
        self.assertNotIn('INFOPLIST_KEY_UISupportedInterfaceOrientations:', project)
        self.assertIn('validate_bundle.py', (ROOT.parent / 'codemagic.yaml').read_text())

if __name__ == '__main__': unittest.main()
