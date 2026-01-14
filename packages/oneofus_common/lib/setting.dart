import 'package:oneofus_common/setting_type.dart';

// A minimal Setting class to support dependency injection.
// It holds a value but has no persistence or query param logic.
class Setting<T> {
  T value;
  
  Setting(this.value);

  // A factory to create a setting with its default value.
  factory Setting.fromType(SettingType type) {
    return Setting(type.defaultValue as T);
  }
}
