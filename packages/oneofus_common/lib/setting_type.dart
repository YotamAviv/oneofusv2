// A minimal version of the SettingType enum to support dependency injection.
enum SettingType {
  skipVerify(bool, false);

  final Type type;
  final dynamic defaultValue;
  
  const SettingType(this.type, this.defaultValue);
}
