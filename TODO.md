# TODO

Highlight Key Federation:

First: - Use "home" in vouch statement (default to export.one-of-us.net when "home" is not specified)
- Support "federated key homing" checkbox in advanced - (not yet supported by older app versions)
- Show "home" in QR code
For the demo, I'll turn that on.



Nope:
- Show a bogus display with the new "home" parameter?
- Show bogus vouch.html only?
- Use future phone app version in the demo?


## Bugs

- **`flutter_secure_storage` + Android Auto Backup**: On uninstall → reinstall, Android Auto Backup restores the encrypted SharedPreferences blobs but not the Keystore keys (which are intentionally non-backupable), causing a `BadPaddingException` / IDENTITY ERROR on startup. Two fixes needed:
  1. Exclude `flutter_secure_storage` files from Auto Backup in `AndroidManifest.xml`
  2. Handle decryption failure gracefully (treat as no identity stored, rather than showing raw error)
