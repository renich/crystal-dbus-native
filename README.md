# crystal-dbus-native

[![CI](https://gitlab.com/renich/crystal-dbus-native/badges/master/pipeline.svg)](https://gitlab.com/renich/crystal-dbus-native/-/pipelines)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

A lightweight, zero-dependency, native [Crystal](https://crystal-lang.org/) implementation of the **D-Bus wire protocol**, general-purpose body marshaling (`BodyCodec`/`Variant`), SASL authentication, and UNIX domain socket file descriptor passing (`SCM_RIGHTS`).

## Features

- **Zero C-Library Dependencies**: Interacts directly with UNIX domain sockets (`/var/run/dbus/system_bus_socket` and session buses).
- **Complete Body Marshaling (`BodyCodec` & `Variant`)**: Encodes and decodes all basic D-Bus types, nested structs (`StructValue`), dictionaries (`a{sv}`), `Variant`, `ObjectPath`, `Signature`, and `UnixFD` in both little-endian and big-endian formats.
- **SASL `EXTERNAL` Authentication**: Native authentication handshake using host UID and optional `NEGOTIATE_UNIX_FD` negotiation.
- **Secure File Descriptor Passing**: Encapsulates `sendmsg`/`recvmsg` and `SCM_RIGHTS` ancillary data with `MSG_CMSG_CLOEXEC` and guaranteed descriptor cleanup on error and truncation paths.
- **RPC Call Correlation & Signal Queueing**: `DBusConnection#call` correlates method replies while buffering interleaved `Signal` messages for `poll_signal`.
- **Strict Signature Validation**: Validates complex and nested D-Bus type signatures (`ay`, `a{sv}`, `(is)`, etc.) with independent 32-level array and struct depth limits.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crystal-dbus-native:
    gitlab: renich/crystal-dbus-native
    version: ~> 0.3.0
```

Then run:

```bash
shards install
```

## Usage

```crystal
require "crystal-dbus-native"

# Connect to the session or system bus and perform SASL + Hello handshake
connection = Crystal::Dbus::Native::DBusConnection.open_session
unique_name = connection.start(negotiate_unix_fd: true)
puts "Connected to D-Bus (unique name: #{unique_name}, GUID: #{connection.server_guid})"

# Invoke a D-Bus method and decode its reply body
reply = connection.call(
  destination: "org.freedesktop.DBus",
  path: "/org/freedesktop/DBus",
  interface: "org.freedesktop.DBus",
  member: "GetId"
)
puts "Bus ID: #{reply.decode_body.first}"

connection.close
```

## Development & Verification

Build targets and test suites are managed via GNU Make:

```bash
make all        # Runs linting (format check, Ameba --all, Flaw) and the full spec suite
make test       # Executes crystal spec
make lint       # Executes crystal tool format --check, Ameba --all, and Flaw scanner
make doc-check  # Validates all .rst files using crstlint and rstcheck
make docs       # Generates Crystal API docs and Sphinx dirhtml documentation
```

## Documentation

- **Documentation Portal**: [`docs/index.rst`](docs/index.rst)
- **Business Specifications**: [`docs/business/spec.rst`](docs/business/spec.rst)
- **Functional Specifications**: [`docs/functional/spec.rst`](docs/functional/spec.rst)
- **Technical Architecture**: [`docs/technical/spec.rst`](docs/technical/spec.rst)
- **Architecture Decision Records**: [`docs/adrs/index.rst`](docs/adrs/index.rst)
- **Project Roadmap**: [`docs/project/roadmap.rst`](docs/project/roadmap.rst)
- **User Guide**: [`docs/user/index.rst`](docs/user/index.rst)
- **API Documentation**: Generated HTML docs located at [`docs/technical/api/`](docs/technical/api/index.html)
- **Changelog**: [`CHANGELOG.rst`](CHANGELOG.rst)
- **Code of Honor**: [`CODE_OF_HONOR.rst`](CODE_OF_HONOR.rst)

## License

Code is licensed under the **GNU Affero General Public License v3.0 or later** ([AGPL-3.0-or-later](LICENSE)). Documentation is licensed under **CC BY-SA 4.0** ([LICENSE-DOCS](LICENSE-DOCS)).
