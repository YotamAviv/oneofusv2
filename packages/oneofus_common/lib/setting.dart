// A minimal Setting class to support dependency injection.
// It holds a value but has no persistence or query param logic.
class Setting<T> {
  T value;
  
  Setting(this.value);
}
