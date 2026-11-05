"""Materialize the owner's Firebase app config without logging credentials."""
import base64, os, pathlib, plistlib, re
target = pathlib.Path(__file__).resolve().parents[1] / 'VendorLedger/Resources/GoogleService-Info.plist'
encoded = os.environ.get('FIREBASE_IOS_CONFIG_BASE64')
if encoded:
    data = base64.b64decode(encoded, validate=True)
else:
    if not target.exists():
        raise SystemExit('Account setup required: add FIREBASE_IOS_CONFIG_BASE64 in Codemagic from the Firebase iOS configuration. See ios/ACCOUNTS_SETUP.md. No fake account service will be published.')
    data = target.read_bytes()
info = plistlib.loads(data)
if info.get('BUNDLE_ID') != 'com.qiaoyu.vendorbookpro':
    raise SystemExit('Firebase configuration belongs to a different bundle ID')
if not all(isinstance(info.get(k), str) and info[k] for k in ['PROJECT_ID','GOOGLE_APP_ID','API_KEY','GCM_SENDER_ID']):
    raise SystemExit('Firebase configuration is incomplete')
if not re.fullmatch(r'[a-z][a-z0-9-]{4,61}[a-z0-9]',info['PROJECT_ID']):
    raise SystemExit('Invalid Firebase project identifier')
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(plistlib.dumps(info))
print('Firebase iOS configuration validated for VendorLedger (values not printed).')
