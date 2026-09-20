# Adversarial Review Standards

## Verdict: REJECT

## Findings

### Critical
1. **SASLAuthenticator.authenticate**: DBus spec requires the UID to be sent as a hex string of the ASCII representation of the UID. `uid.to_s(16)` just hex-encodes the integer value (e.g. `1000` -> `"3e8"`). It should be `"1000".bytes.map { |b| b.to_s(16) }.join` or similar. If you pass UID `1000`, the server expects `"31303030"`, not `"3e8"`. This will cause authentication failures in the wild.
2. **SignatureValidator.validate**:
   - `a` (array) requires a complete type immediately following it. The validator just does `when 'a'` and moves on. A signature of just `"a"` will pass validation, which is invalid.
   - `{` (dict entry) is only valid when immediately following an array `a`. The validator allows `{` anywhere.
   - A dict entry `{}` MUST contain exactly two complete types (key and value), and the key must be a basic type. The validator only pushes/pops `{}` on the stack and doesn't count elements.
   - There's no check for `a` followed by another `a` exceeding MAX_DEPTH.
   - It raises generic `Exception.new("...")`. You must use specific typed exceptions like `DBus::SignatureError`.

### Major
1. **DBusMessage.parse**:
   - Endianness check is `endian_char == 'l'`. If a malicious client sends `'z'`, it defaults to BigEndian. DBus spec dictates `'l'` (little) or `'B'` (big). Anything else is malformed and MUST be rejected immediately.
   - `max_size` is `Int32` and it checks `body_length > max_size - 12`. While technically safe in Crystal due to unsigned vs signed comparison semantics, it is unidiomatic and fragile. `max_size` should be `UInt32`.
   - The method catches `IO::EOFError` and raises a generic `Exception`. It should raise a specific `ConnectionClosedError`.
2. **SecureFDPasser**:
   - `cmsg.value.cmsg_len` might be `UInt32` or `LibC::SizeT` depending on platform.

### Minor / Pedantic
1. **Generic Exceptions**: Stop using `Exception.new`. Define specific exceptions (`DBusError`, `AuthError`, `SignatureError`, `MessageError`).
2. **DBusConnection**: Unused `timeout` in `close(timeout)`. Either use it or remove the parameter. `start` is empty.
3. **Typing**: `endian` property should be an enum `Endianness`, not a `Symbol`.
