# crystal-dbus-native

[![CI](https://gitlab.com/renich/crystal-dbus-native/badges/master/pipeline.svg)](https://gitlab.com/renich/crystal-dbus-native/-/pipelines)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

A lightweight, zero-dependency, native [Crystal](https://crystal-lang.org/) implementation of the **D-Bus wire protocol**, SASL authentication, and UNIX domain socket file descriptor passing (`SCM_RIGHTS`).

## Features

- **Zero C-Library Dependencies**: Interacts directly with UNIX domain sockets (`/var/run/dbus/system_bus_socket`).
- **SASL `EXTERNAL` Authentication**: Native authentication handshake using host UID.
- **Secure File Descriptor Passing**: Encapsulates `sendmsg`/`recvmsg` and `SCM_RIGHTS` ancillary data with guaranteed descriptor cleanup on error paths.
- **Strict Signature Validation**: Validates complex and nested D-Bus type signatures (`ay`, `a{sv}`, `(is)`, etc.) with depth limits.
- **Clean Transport Lifecycle**: Explicit socket timeouts and memory-safe message marshalling.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crystal-dbus-native:
    github: renich/crystal-dbus-native
    version: ~> 0.1.1
```

Then run:

```bash
shards install
```

## Usage

```crystal
require "crystal-dbus-native"
require "socket"

# Connect to system or session bus
socket = UNIXSocket.new("/var/run/dbus/system_bus_socket")

# Authenticate via SASL EXTERNAL
uid = LibC.getuid
guid = Crystal::Dbus::Native::SASLAuthenticator.authenticate(socket, uid)
puts "Authenticated with D-Bus daemon (GUID: #{guid})"

# Initialize native D-Bus connection
connection = Crystal::Dbus::Native::DBusConnection.new(socket)
connection.start

# Validate D-Bus type signature
Crystal::Dbus::Native::SignatureValidator.validate("a{sv}")
puts "Signature valid!"

connection.close
```

## Development & Verification

Build targets and test suites are managed via GNU Make:

```bash
make all      # Runs linting (Ameba & Flaw) and the full test suite
make test     # Executes crystal spec
make lint     # Executes Ameba static analysis and Flaw scanner
make docs     # Generates API documentation into docs/technical/api
```

## Documentation

- **API Documentation**: Generated HTML docs located at [`docs/technical/api/`](docs/technical/api/index.html).
- **Technical Specification**: [`docs/technical/spec.rst`](docs/technical/spec.rst)
- **Project Roadmap**: [`docs/project/roadmap.rst`](docs/project/roadmap.rst)
- **Changelog**: [`CHANGELOG.rst`](CHANGELOG.rst)
- **Code of Honor**: [`docs/technical/CODE_OF_HONOR.rst`](docs/technical/CODE_OF_HONOR.rst)

## License

This project is licensed under the **GNU Affero General Public License v3.0 or later** ([AGPL-3.0-or-later](LICENSE)).
