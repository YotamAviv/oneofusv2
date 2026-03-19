# TODO

## Bugs

- **`flutter_secure_storage` + Android Auto Backup**: On uninstall → reinstall, Android Auto Backup restores the encrypted SharedPreferences blobs but not the Keystore keys (which are intentionally non-backupable), causing a `BadPaddingException` / IDENTITY ERROR on startup. Two fixes needed:
  1. Exclude `flutter_secure_storage` files from Auto Backup in `AndroidManifest.xml`
  2. Handle decryption failure gracefully (treat as no identity stored, rather than showing raw error)
