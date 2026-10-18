# crystal-dbus-native

[![CI](https://gitlab.com/renich/crystal-dbus-native/badges/master/pipeline.svg)](https://gitlab.com/renich/crystal-dbus-native/-/pipelines)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

A lightweight, zero-dependency, native [Crystal](https://crystal-lang.org/) implementation of the **D-Bus wire protocol**, SASL authentication, and UNIX domain socket file descriptor passing (`SCM_RIGHTS`).

## Features

- **Zero C-Library Dependencies**: Interacts directly with UNIX domain sockets (`/var/run/dbus/system_bus_socket`).
- **SASL `EXTERNAL` Authentication**: Native authentication handshake using host UID and optional `NEGOTIATE_UNIX_FD` negotiation.
- **Secure File Descriptor Passing**: Encapsulates `sendmsg`/`recvmsg` and `SCM_RIGHTS` ancillary data with `MSG_CMSG_CLOEXEC` and guaranteed descriptor cleanup on error and truncation paths.
- **Strict Signature Validation**: Validates complex and nested D-Bus type signatures (`ay`, `a{sv}`, `(is)`, etc.) with independent 32-level array and struct depth limits.
- **Clean Transport Lifecycle**: Explicit socket timeouts, thread-safe serial allocation, and memory-safe message framing.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crystal-dbus-native:
    gitlab: renich/crystal-dbus-native
    version: ~> 0.2.0
```

Then run:

```bash
shards install
```

## Usage

```crystal
require "crystal-dbus-native"

# Connect to the system or session bus and perform SASL + Hello handshake
connection = Crystal::Dbus::Native::DBusConnection.open_system
unique_name = connection.start
puts "Connected to D-Bus (unique name: #{unique_name}, GUID: #{connection.server_guid})"

# Validate a D-Bus type signature
Crystal::Dbus::Native::SignatureValidator.validate("a{sv}")
puts "Signature valid!"

connection.close
```

## Development & Verification

Build targets and test suites are managed via GNU Make:

```bash
make all      # Runs linting (format check, Ameba --all, Flaw) and the full spec suite
make test     # Executes crystal spec
make lint     # Executes crystal tool format --check, Ameba --all, and Flaw scanner
make docs     # Generates API documentation into docs/technical/api
```

## Documentation

- **White Paper**: [`docs/whitepaper.rst`](docs/whitepaper.rst)
- **Technical Specification**: [`docs/technical/spec.rst`](docs/technical/spec.rst)
- **Architecture & Design**: [`docs/technical/architecture.rst`](docs/technical/architecture.rst)
- **Security Considerations**: [`docs/technical/security.rst`](docs/technical/security.rst)
- **API Documentation**: Generated HTML docs located at [`docs/technical/api/`](docs/technical/api/index.html)
- **Project Roadmap**: [`docs/project/roadmap.rst`](docs/project/roadmap.rst)
- **Changelog**: [`CHANGELOG.rst`](CHANGELOG.rst)
- **Code of Honor**: [`docs/technical/CODE_OF_HONOR.rst`](docs/technical/CODE_OF_HONOR.rst)

## License

This project is licensed under the **GNU Affero General Public License v3.0 or later** ([AGPL-3.0-or-later](LICENSE)).
