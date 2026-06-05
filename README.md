# crystal-dbus-native

A pure, native, and memory-safe DBus implementation for Crystal.

## Features
- Secure SASL Authentication handling.
- Complete Signature Validation with strict structural boundary checks.
- Endianness-aware message parsing and secure File Descriptor passing.

## Usage
Add this to your application's `shard.yml`:
```yaml
dependencies:
  crystal-dbus-native:
    github: renich/crystal-dbus-native
```

## Documentation
Full architectural and API documentation is available in the `docs/` directory. Use `make docs` to generate the HTML.

## Credits
- **Co-developed-by**: Gemini AI <renich+gemini@woralelandia.com>
- **Signed-off-by**: Rénich Bon Ćirić <renich@woralelandia.com>

## Code of Honor
This project strictly adheres to the [Code of Honor](docs/technical/CODE_OF_HONOR.rst) drafted by Rénich Bon Ćirić.
