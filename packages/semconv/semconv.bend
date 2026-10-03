# bend-telemetry-semconv: the OpenTelemetry semantic conventions v1.44.0 for Bend. Source: https://github.com/LucasGois1/bend-telemetry
import Base

# The semantic conventions package
# ================================
#
# Generated code: do not edit. weaver 0.26.1 rendered this module
# from the OpenTelemetry semantic conventions registry at v1.44.0 through
# the Bend target templates/registry/bend; `./scripts/semconv-generate.sh`
# regenerates it, and CI fails when the committed module differs from the
# registry (#33).
#
# Every definition is a constant: a def with no parameters that answers a
# String. The attribute `http.request.method` is `Http.Request.method()`,
# which answers the attribute's name, and each enumeration member of an
# attribute is a def under the attribute's capitalized name, such as
# `Http.Request.Method.get()`, which answers the member's value. The
# namespaces covered and the full name mapping are in
# packages/semconv/README.md. Deprecated attributes and members are kept,
# with their deprecation note in the comment.

# The package's BendHub name.
def Package.name() -> String:
  "bend-telemetry-semconv"

# The schema URL of the conventions version these constants come from, for
# resources and instrumentation scopes.
def Schema.url() -> String:
  "https://opentelemetry.io/schemas/1.44.0"

# Namespace: client
# =================

# Client address - domain name if available without reverse DNS lookup;
# otherwise, IP address or UNIX domain socket name.
#
# Type: string. Stability: stable.
# Examples: "client.example.com", "10.1.2.80", "/tmp/my.sock"
def Client.address() -> String:
  "client.address"

# Client port number.
#
# Type: int. Stability: stable.
# Examples: 65123
def Client.port() -> String:
  "client.port"

# Namespace: container
# ====================

# The command used to run the container (i.e. the command name).
#
# Type: string. Stability: development.
# Examples: "otelcontribcol"
def Container.command() -> String:
  "container.command"

# All the command arguments (including the command/executable itself) run by
# the container.
#
# Type: string[]. Stability: development.
# Examples: ["otelcontribcol", "--config", "config.yaml"]
def Container.command_args() -> String:
  "container.command_args"

# The full command run by the container as a single string representing the
# full command.
#
# Type: string. Stability: development.
# Examples: "otelcontribcol --config config.yaml"
def Container.command_line() -> String:
  "container.command_line"

# Deprecated, use `cpu.mode` instead.
#
# Type: enum. Stability: development.
# Examples: "user", "kernel"
#
# Deprecated (renamed): Replaced by `cpu.mode`.
def Container.Cpu.state() -> String:
  "container.cpu.state"

# A value of container.cpu.state: When tasks of the cgroup are in user mode
# (Linux). When all container processes are in user mode (Windows).
#
# Stability: development.
def Container.Cpu.State.user() -> String:
  "user"

# A value of container.cpu.state: When CPU is used by the system (host OS)
#
# Stability: development.
def Container.Cpu.State.system() -> String:
  "system"

# A value of container.cpu.state: When tasks of the cgroup are in kernel mode
# (Linux). When all container processes are in kernel mode (Windows).
#
# Stability: development.
def Container.Cpu.State.kernel() -> String:
  "kernel"

# The name of the CSI ([Container Storage Interface]) plugin used by the
# volume.
#
# Type: string. Stability: development.
# Examples: "pd.csi.storage.gke.io"
#
# [Container Storage Interface]: https://github.com/container-storage-interface/spec
def Container.Csi.Plugin.name() -> String:
  "container.csi.plugin.name"

# The unique volume ID returned by the CSI ([Container Storage Interface])
# plugin.
#
# Type: string. Stability: development.
# Examples: "projects/my-gcp-project/zones/my-gcp-zone/disks/my-gcp-disk"
#
# [Container Storage Interface]: https://github.com/container-storage-interface/spec
def Container.Csi.Volume.id() -> String:
  "container.csi.volume.id"

# Container ID. Usually a UUID, as for example used to
# [identify Docker containers]. The UUID might be abbreviated.
#
# Type: string. Stability: stable.
# Examples: "a3bf90e006b2"
#
# [identify Docker containers]: https://docs.docker.com/engine/containers/run/#container-identification
def Container.id() -> String:
  "container.id"

# Runtime specific image identifier. Usually a hash algorithm followed by a
# UUID.
#
# Type: string. Stability: development.
# Examples:
# "sha256:19c92d0a00d1b66d897bceaa7319bee0dd38a10a851c60bcec9474aa3f01e50f"
def Container.Image.id() -> String:
  "container.image.id"

# Name of the image the container was built on.
#
# Type: string. Stability: stable.
# Examples: "gcr.io/opentelemetry/operator"
def Container.Image.name() -> String:
  "container.image.name"

# Repository digests of the container image as provided by the container
# runtime.
#
# Type: string[]. Stability: stable.
# Examples:
# ["example@sha256:afcc7f1ac1b49db317a7196c902e61c6c3c4607d63599ee1a82d702d249a0ccb",
# "internal.registry.example.com:5000/example@sha256:b69959407d21e8a062e0416bf13405bb2b71ed7a84dde4158ebafacfa06f5578"]
def Container.Image.repo_digests() -> String:
  "container.image.repo_digests"

# Container image tags. An example can be found in [Docker Image Inspect].
# Should be only the `<tag>` section of the full name for example from
# `registry.example.com/my-org/my-image:<tag>`.
#
# Type: string[]. Stability: stable.
# Examples: ["v1.27.1", "3.5.7-0"]
#
# [Docker Image Inspect]: https://docs.docker.com/reference/api/engine/version/v1.52/#tag/Image/operation/ImageInspect
def Container.Image.tags() -> String:
  "container.image.tags"

# Container labels, `<key>` being the label name, the value being the label
# value.
#
# Type: template[string]. Stability: development.
# Examples: "nginx"
def Container.label() -> String:
  "container.label"

# Deprecated, use `container.label` instead.
#
# Type: template[string]. Stability: development.
# Examples: "nginx"
#
# Deprecated (renamed): Replaced by `container.label`.
def Container.labels() -> String:
  "container.labels"

# Container name used by container runtime.
#
# Type: string. Stability: development.
# Examples: "opentelemetry-autoconf"
def Container.name() -> String:
  "container.name"

# The container runtime managing this container.
#
# Type: string. Stability: development.
# Examples: "docker", "containerd", "rkt"
#
# Deprecated (renamed): Replaced by `container.runtime.name`.
def Container.runtime() -> String:
  "container.runtime"

# A description about the runtime which could include, for example details
# about the CRI/API version being used or other customizations.
#
# Type: string. Stability: development.
# Examples: "docker://19.3.1 - CRI: 1.22.0"
def Container.Runtime.description() -> String:
  "container.runtime.description"

# The container runtime managing this container.
#
# Type: string. Stability: development.
# Examples: "docker", "containerd", "rkt"
def Container.Runtime.name() -> String:
  "container.runtime.name"

# The version of the runtime of this process, as returned by the runtime
# without modification.
#
# Type: string. Stability: development.
# Examples: "1.0.0"
def Container.Runtime.version() -> String:
  "container.runtime.version"

# Namespace: error
# ================

# A message providing more detail about an error in human-readable form.
#
# Type: string. Stability: development.
# Examples: "Unexpected input type: string", "The user has exceeded their
# storage quota"
#
# Deprecated (obsoleted): Use domain-specific error message attribute. For
# example, use `feature_flag.error.message` for feature flag errors.
def Error.message() -> String:
  "error.message"

# Describes a class of error the operation ended with.
#
# Type: enum. Stability: stable.
# Examples: "timeout", "java.net.UnknownHostException",
# "server_certificate_invalid", "500"
def Error.type() -> String:
  "error.type"

# A value of error.type: A fallback error value to be used when the
# instrumentation doesn't define a custom value.
#
# Stability: stable.
def Error.Type.other() -> String:
  "_OTHER"

# Namespace: exception
# ====================

# Indicates that the exception is escaping the scope of the span.
#
# Type: boolean. Stability: stable.
#
# Deprecated (obsoleted): It's no longer recommended to record exceptions that
# are handled and do not escape the scope of a span.
def Exception.escaped() -> String:
  "exception.escaped"

# The exception message.
#
# Type: string. Stability: stable.
# Examples: "Division by zero", "Can't convert 'int' object to str implicitly"
def Exception.message() -> String:
  "exception.message"

# A stacktrace as a string in the natural representation for the language
# runtime. The representation is to be determined and documented by each
# language SIG.
#
# Type: string. Stability: stable.
# Examples: "Exception in thread "main" java.lang.RuntimeException: Test
# exception\n at com.example.GenerateTrace.methodB(GenerateTrace.java:13)\n at
# com.example.GenerateTrace.methodA(GenerateTrace.java:9)\n at
# com.example.GenerateTrace.main(GenerateTrace.java:5)\n"
def Exception.stacktrace() -> String:
  "exception.stacktrace"

# The type of the exception (its fully-qualified class name, if applicable).
# The dynamic type of the exception should be preferred over the static type in
# languages that support it.
#
# Type: string. Stability: stable.
# Examples: "java.net.ConnectException", "OSError"
def Exception.type() -> String:
  "exception.type"

# Namespace: host
# ===============

# The CPU architecture the host system is running on.
#
# Type: enum. Stability: development.
def Host.arch() -> String:
  "host.arch"

# A value of host.arch: AMD64
#
# Stability: development.
def Host.Arch.amd64() -> String:
  "amd64"

# A value of host.arch: ARM32
#
# Stability: development.
def Host.Arch.arm32() -> String:
  "arm32"

# A value of host.arch: ARM64
#
# Stability: development.
def Host.Arch.arm64() -> String:
  "arm64"

# A value of host.arch: Itanium
#
# Stability: development.
def Host.Arch.ia64() -> String:
  "ia64"

# A value of host.arch: 32-bit PowerPC
#
# Stability: development.
def Host.Arch.ppc32() -> String:
  "ppc32"

# A value of host.arch: 64-bit PowerPC
#
# Stability: development.
def Host.Arch.ppc64() -> String:
  "ppc64"

# A value of host.arch: IBM z/Architecture
#
# Stability: development.
def Host.Arch.s390x() -> String:
  "s390x"

# A value of host.arch: 32-bit x86
#
# Stability: development.
def Host.Arch.x86() -> String:
  "x86"

# The amount of level 2 memory cache available to the processor (in Bytes).
#
# Type: int. Stability: development.
# Examples: 12288000
def Host.Cpu.Cache.L2.size() -> String:
  "host.cpu.cache.l2.size"

# Family or generation of the CPU.
#
# Type: string. Stability: development.
# Examples: "6", "PA-RISC 1.1e"
def Host.Cpu.family() -> String:
  "host.cpu.family"

# Model identifier. It provides more granular information about the CPU,
# distinguishing it from other CPUs within the same family.
#
# Type: string. Stability: development.
# Examples: "6", "9000/778/B180L"
def Host.Cpu.Model.id() -> String:
  "host.cpu.model.id"

# Model designation of the processor.
#
# Type: string. Stability: development.
# Examples: "11th Gen Intel(R) Core(TM) i7-1185G7 @ 3.00GHz"
def Host.Cpu.Model.name() -> String:
  "host.cpu.model.name"

# Stepping or core revisions.
#
# Type: string. Stability: development.
# Examples: "1", "r1p1"
def Host.Cpu.stepping() -> String:
  "host.cpu.stepping"

# Processor manufacturer identifier. A maximum 12-character string.
#
# Type: string. Stability: development.
# Examples: "GenuineIntel"
def Host.Cpu.Vendor.id() -> String:
  "host.cpu.vendor.id"

# Unique host ID. For Cloud, this must be the instance_id assigned by the cloud
# provider. For non-containerized systems, this should be the `machine-id`. See
# the table below for the sources to use to determine the `machine-id` based on
# operating system.
#
# Type: string. Stability: development.
# Examples: "fdbf79e8af94cb7f9e8df36789187052"
def Host.id() -> String:
  "host.id"

# VM image ID or host OS image ID. For Cloud, this value is from the provider.
#
# Type: string. Stability: development.
# Examples: "ami-07b06b442921831e5"
def Host.Image.id() -> String:
  "host.image.id"

# Name of the VM image or OS install the host was instantiated from.
#
# Type: string. Stability: development.
# Examples: "infra-ami-eks-worker-node-7d4ec78312", "CentOS-8-x86_64-1905"
def Host.Image.name() -> String:
  "host.image.name"

# The version string of the VM image or host OS as defined in
# [Version Attributes].
#
# Type: string. Stability: development.
# Examples: "0.1"
#
# [Version Attributes]: /docs/resource/README.md#version-attributes
def Host.Image.version() -> String:
  "host.image.version"

# Available IP addresses of the host, excluding loopback interfaces.
#
# Type: string[]. Stability: development.
# Examples: ["192.168.1.140", "fe80::abc2:4a28:737a:609e"]
def Host.ip() -> String:
  "host.ip"

# Available MAC addresses of the host, excluding loopback interfaces.
#
# Type: string[]. Stability: development.
# Examples: ["AC-DE-48-23-45-67", "AC-DE-48-23-45-67-01-9F"]
def Host.mac() -> String:
  "host.mac"

# Name of the host. On UNIX systems, it may contain what the hostname command
# returns, or the fully qualified hostname, or another name specified by the
# user.
#
# Type: string. Stability: development.
# Examples: "opentelemetry-test"
def Host.name() -> String:
  "host.name"

# Type of host. For Cloud, this must be the machine type.
#
# Type: string. Stability: development.
# Examples: "n1-standard-1"
def Host.type() -> String:
  "host.type"

# Namespace: http
# ===============

# Deprecated, use `client.address` instead.
#
# Type: string. Stability: development.
# Examples: "83.164.160.102"
#
# Deprecated (renamed): Replaced by `client.address`.
def Http.client_ip() -> String:
  "http.client_ip"

# State of the HTTP connection in the HTTP connection pool.
#
# Type: enum. Stability: development.
# Examples: "active", "idle"
def Http.Connection.state() -> String:
  "http.connection.state"

# A value of http.connection.state: active state.
#
# Stability: development.
def Http.Connection.State.active() -> String:
  "active"

# A value of http.connection.state: idle state.
#
# Stability: development.
def Http.Connection.State.idle() -> String:
  "idle"

# Deprecated, use `network.protocol.name` and `network.protocol.version`
# instead.
#
# Type: enum. Stability: development.
#
# Deprecated (uncategorized): Split into `network.protocol.name` and
# `network.protocol.version`
def Http.flavor() -> String:
  "http.flavor"

# A value of http.flavor: HTTP/1.0
#
# Stability: development.
def Http.Flavor.http_1_0() -> String:
  "1.0"

# A value of http.flavor: HTTP/1.1
#
# Stability: development.
def Http.Flavor.http_1_1() -> String:
  "1.1"

# A value of http.flavor: HTTP/2
#
# Stability: development.
def Http.Flavor.http_2_0() -> String:
  "2.0"

# A value of http.flavor: HTTP/3
#
# Stability: development.
def Http.Flavor.http_3_0() -> String:
  "3.0"

# A value of http.flavor: SPDY protocol.
#
# Stability: development.
def Http.Flavor.spdy() -> String:
  "SPDY"

# A value of http.flavor: QUIC protocol.
#
# Stability: development.
def Http.Flavor.quic() -> String:
  "QUIC"

# Deprecated, use one of `server.address`, `client.address` or
# `http.request.header.host` instead, depending on the usage.
#
# Type: string. Stability: development.
# Examples: "www.example.org"
#
# Deprecated (uncategorized): Replaced by one of `server.address`,
# `client.address` or `http.request.header.host`, depending on the usage.
def Http.host() -> String:
  "http.host"

# Deprecated, use `http.request.method` instead.
#
# Type: string. Stability: development.
# Examples: "GET", "POST", "HEAD"
#
# Deprecated (renamed): Replaced by `http.request.method`.
def Http.method() -> String:
  "http.method"

# The size of the request payload body in bytes. This is the number of bytes
# transferred excluding headers and is often, but not always, present as the
# [Content-Length] header. For requests using transport encoding, this should
# be the compressed size.
#
# Type: int. Stability: development.
# Examples: 3495
#
# [Content-Length]: https://www.rfc-editor.org/rfc/rfc9110.html#field.content-length
def Http.Request.Body.size() -> String:
  "http.request.body.size"

# HTTP request headers, `<key>` being the normalized HTTP Header name
# (lowercase), the value being the header values.
#
# Type: template[string[]]. Stability: stable.
# Examples: ["application/json"], ["1.2.3.4", "1.2.3.5"]
def Http.Request.header() -> String:
  "http.request.header"

# HTTP request method.
#
# Type: enum. Stability: stable.
# Examples: "GET", "POST", "HEAD"
def Http.Request.method() -> String:
  "http.request.method"

# A value of http.request.method: CONNECT method.
#
# Stability: stable.
def Http.Request.Method.connect() -> String:
  "CONNECT"

# A value of http.request.method: DELETE method.
#
# Stability: stable.
def Http.Request.Method.delete() -> String:
  "DELETE"

# A value of http.request.method: GET method.
#
# Stability: stable.
def Http.Request.Method.get() -> String:
  "GET"

# A value of http.request.method: HEAD method.
#
# Stability: stable.
def Http.Request.Method.head() -> String:
  "HEAD"

# A value of http.request.method: OPTIONS method.
#
# Stability: stable.
def Http.Request.Method.options() -> String:
  "OPTIONS"

# A value of http.request.method: PATCH method.
#
# Stability: stable.
def Http.Request.Method.patch() -> String:
  "PATCH"

# A value of http.request.method: POST method.
#
# Stability: stable.
def Http.Request.Method.post() -> String:
  "POST"

# A value of http.request.method: PUT method.
#
# Stability: stable.
def Http.Request.Method.put() -> String:
  "PUT"

# A value of http.request.method: TRACE method.
#
# Stability: stable.
def Http.Request.Method.trace() -> String:
  "TRACE"

# A value of http.request.method: QUERY method.
#
# Stability: development.
def Http.Request.Method.query() -> String:
  "QUERY"

# A value of http.request.method: Any HTTP method that the instrumentation has
# no prior knowledge of.
#
# Stability: stable.
def Http.Request.Method.other() -> String:
  "_OTHER"

# Original HTTP method sent by the client in the request line.
#
# Type: string. Stability: stable.
# Examples: "GeT", "ACL", "foo"
def Http.Request.method_original() -> String:
  "http.request.method_original"

# The ordinal number of request resending attempt (for any reason, including
# redirects).
#
# Type: int. Stability: stable.
# Examples: 3
def Http.Request.resend_count() -> String:
  "http.request.resend_count"

# The total size of the request in bytes. This should be the total number of
# bytes sent over the wire, including the request line (HTTP/1.1), framing
# (HTTP/2 and HTTP/3), headers, and request body if any.
#
# Type: int. Stability: development.
# Examples: 1437
def Http.Request.size() -> String:
  "http.request.size"

# Deprecated, use `http.request.header.content-length` instead.
#
# Type: int. Stability: development.
# Examples: 3495
#
# Deprecated (uncategorized): Replaced by `http.request.header.content-length`
# .
def Http.request_content_length() -> String:
  "http.request_content_length"

# Deprecated, use `http.request.body.size` instead.
#
# Type: int. Stability: development.
# Examples: 5493
#
# Deprecated (renamed): Replaced by `http.request.body.size`.
def Http.request_content_length_uncompressed() -> String:
  "http.request_content_length_uncompressed"

# The size of the response payload body in bytes. This is the number of bytes
# transferred excluding headers and is often, but not always, present as the
# [Content-Length] header. For requests using transport encoding, this should
# be the compressed size.
#
# Type: int. Stability: development.
# Examples: 3495
#
# [Content-Length]: https://www.rfc-editor.org/rfc/rfc9110.html#field.content-length
def Http.Response.Body.size() -> String:
  "http.response.body.size"

# HTTP response headers, `<key>` being the normalized HTTP Header name
# (lowercase), the value being the header values.
#
# Type: template[string[]]. Stability: stable.
# Examples: ["application/json"], ["abc", "def"]
def Http.Response.header() -> String:
  "http.response.header"

# The total size of the response in bytes. This should be the total number of
# bytes sent over the wire, including the status line (HTTP/1.1), framing
# (HTTP/2 and HTTP/3), headers, and response body and trailers if any.
#
# Type: int. Stability: development.
# Examples: 1437
def Http.Response.size() -> String:
  "http.response.size"

# [HTTP response status code].
#
# Type: int. Stability: stable.
# Examples: 200
#
# [HTTP response status code]: https://tools.ietf.org/html/rfc7231#section-6
def Http.Response.status_code() -> String:
  "http.response.status_code"

# Deprecated, use `http.response.header.content-length` instead.
#
# Type: int. Stability: development.
# Examples: 3495
#
# Deprecated (uncategorized): Replaced by `http.response.header.content-length`
# .
def Http.response_content_length() -> String:
  "http.response_content_length"

# Deprecated, use `http.response.body.size` instead.
#
# Type: int. Stability: development.
# Examples: 5493
#
# Deprecated (renamed): Replaced by `http.response.body.size`.
def Http.response_content_length_uncompressed() -> String:
  "http.response_content_length_uncompressed"

# The matched route template for the request. This MUST be low-cardinality and
# include all static path segments, with dynamic path segments represented with
# placeholders.
#
# Type: string. Stability: stable.
# Examples: "/users/:userID?", "my-controller/my-action/{id?}"
def Http.route() -> String:
  "http.route"

# Deprecated, use `url.scheme` instead.
#
# Type: string. Stability: development.
# Examples: "http", "https"
#
# Deprecated (renamed): Replaced by `url.scheme`.
def Http.scheme() -> String:
  "http.scheme"

# Deprecated, use `server.address` instead.
#
# Type: string. Stability: development.
# Examples: "example.com"
#
# Deprecated (renamed): Replaced by `server.address`.
def Http.server_name() -> String:
  "http.server_name"

# Deprecated, use `http.response.status_code` instead.
#
# Type: int. Stability: development.
# Examples: 200
#
# Deprecated (renamed): Replaced by `http.response.status_code`.
def Http.status_code() -> String:
  "http.status_code"

# Deprecated, use `url.path` and `url.query` instead.
#
# Type: string. Stability: development.
# Examples: "/search?q=OpenTelemetry#SemConv"
#
# Deprecated (obsoleted): Split to `url.path` and `url.query`.
def Http.target() -> String:
  "http.target"

# Deprecated, use `url.full` instead.
#
# Type: string. Stability: development.
# Examples: "https://www.foo.bar/search?q=OpenTelemetry#SemConv"
#
# Deprecated (renamed): Replaced by `url.full`.
def Http.url() -> String:
  "http.url"

# Deprecated, use `user_agent.original` instead.
#
# Type: string. Stability: development.
# Examples: "CERN-LineMode/2.15 libwww/2.17b3", "Mozilla/5.0 (iPhone; CPU
# iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)
# Version/14.1.2 Mobile/15E148 Safari/604.1"
#
# Deprecated (renamed): Replaced by `user_agent.original`.
def Http.user_agent() -> String:
  "http.user_agent"

# Namespace: network
# ==================

# The ISO 3166-1 alpha-2 2-character country code associated with the mobile
# carrier network.
#
# Type: string. Stability: development.
# Examples: "DE"
def Network.Carrier.icc() -> String:
  "network.carrier.icc"

# The mobile carrier country code.
#
# Type: string. Stability: development.
# Examples: "310"
def Network.Carrier.mcc() -> String:
  "network.carrier.mcc"

# The mobile carrier network code.
#
# Type: string. Stability: development.
# Examples: "001"
def Network.Carrier.mnc() -> String:
  "network.carrier.mnc"

# The name of the mobile carrier.
#
# Type: string. Stability: development.
# Examples: "sprint"
def Network.Carrier.name() -> String:
  "network.carrier.name"

# The state of network connection
#
# Type: enum. Stability: development.
# Examples: "close_wait"
def Network.Connection.state() -> String:
  "network.connection.state"

# A value of network.connection.state: closed
#
# Stability: development.
def Network.Connection.State.closed() -> String:
  "closed"

# A value of network.connection.state: close_wait
#
# Stability: development.
def Network.Connection.State.close_wait() -> String:
  "close_wait"

# A value of network.connection.state: closing
#
# Stability: development.
def Network.Connection.State.closing() -> String:
  "closing"

# A value of network.connection.state: established
#
# Stability: development.
def Network.Connection.State.established() -> String:
  "established"

# A value of network.connection.state: fin_wait_1
#
# Stability: development.
def Network.Connection.State.fin_wait_1() -> String:
  "fin_wait_1"

# A value of network.connection.state: fin_wait_2
#
# Stability: development.
def Network.Connection.State.fin_wait_2() -> String:
  "fin_wait_2"

# A value of network.connection.state: last_ack
#
# Stability: development.
def Network.Connection.State.last_ack() -> String:
  "last_ack"

# A value of network.connection.state: listen
#
# Stability: development.
def Network.Connection.State.listen() -> String:
  "listen"

# A value of network.connection.state: syn_received
#
# Stability: development.
def Network.Connection.State.syn_received() -> String:
  "syn_received"

# A value of network.connection.state: syn_sent
#
# Stability: development.
def Network.Connection.State.syn_sent() -> String:
  "syn_sent"

# A value of network.connection.state: time_wait
#
# Stability: development.
def Network.Connection.State.time_wait() -> String:
  "time_wait"

# This describes more details regarding the connection.type. It may be the type
# of cell technology connection, but it could be used for describing details
# about a Wi-Fi connection.
#
# Type: enum. Stability: development.
# Examples: "LTE"
def Network.Connection.subtype() -> String:
  "network.connection.subtype"

# A value of network.connection.subtype: GPRS
#
# Stability: development.
def Network.Connection.Subtype.gprs() -> String:
  "gprs"

# A value of network.connection.subtype: EDGE
#
# Stability: development.
def Network.Connection.Subtype.edge() -> String:
  "edge"

# A value of network.connection.subtype: UMTS
#
# Stability: development.
def Network.Connection.Subtype.umts() -> String:
  "umts"

# A value of network.connection.subtype: CDMA
#
# Stability: development.
def Network.Connection.Subtype.cdma() -> String:
  "cdma"

# A value of network.connection.subtype: EVDO Rel. 0
#
# Stability: development.
def Network.Connection.Subtype.evdo_0() -> String:
  "evdo_0"

# A value of network.connection.subtype: EVDO Rev. A
#
# Stability: development.
def Network.Connection.Subtype.evdo_a() -> String:
  "evdo_a"

# A value of network.connection.subtype: CDMA2000 1XRTT
#
# Stability: development.
def Network.Connection.Subtype.cdma2000_1xrtt() -> String:
  "cdma2000_1xrtt"

# A value of network.connection.subtype: HSDPA
#
# Stability: development.
def Network.Connection.Subtype.hsdpa() -> String:
  "hsdpa"

# A value of network.connection.subtype: HSUPA
#
# Stability: development.
def Network.Connection.Subtype.hsupa() -> String:
  "hsupa"

# A value of network.connection.subtype: HSPA
#
# Stability: development.
def Network.Connection.Subtype.hspa() -> String:
  "hspa"

# A value of network.connection.subtype: IDEN
#
# Stability: development.
def Network.Connection.Subtype.iden() -> String:
  "iden"

# A value of network.connection.subtype: EVDO Rev. B
#
# Stability: development.
def Network.Connection.Subtype.evdo_b() -> String:
  "evdo_b"

# A value of network.connection.subtype: LTE
#
# Stability: development.
def Network.Connection.Subtype.lte() -> String:
  "lte"

# A value of network.connection.subtype: EHRPD
#
# Stability: development.
def Network.Connection.Subtype.ehrpd() -> String:
  "ehrpd"

# A value of network.connection.subtype: HSPAP
#
# Stability: development.
def Network.Connection.Subtype.hspap() -> String:
  "hspap"

# A value of network.connection.subtype: GSM
#
# Stability: development.
def Network.Connection.Subtype.gsm() -> String:
  "gsm"

# A value of network.connection.subtype: TD-SCDMA
#
# Stability: development.
def Network.Connection.Subtype.td_scdma() -> String:
  "td_scdma"

# A value of network.connection.subtype: IWLAN
#
# Stability: development.
def Network.Connection.Subtype.iwlan() -> String:
  "iwlan"

# A value of network.connection.subtype: 5G NR (New Radio)
#
# Stability: development.
def Network.Connection.Subtype.nr() -> String:
  "nr"

# A value of network.connection.subtype: 5G NRNSA (New Radio Non-Standalone)
#
# Stability: development.
def Network.Connection.Subtype.nrnsa() -> String:
  "nrnsa"

# A value of network.connection.subtype: LTE CA
#
# Stability: development.
def Network.Connection.Subtype.lte_ca() -> String:
  "lte_ca"

# The internet connection type.
#
# Type: enum. Stability: development.
# Examples: "wifi"
def Network.Connection.type() -> String:
  "network.connection.type"

# A value of network.connection.type: Wi-Fi
#
# Stability: development.
def Network.Connection.Type.wifi() -> String:
  "wifi"

# A value of network.connection.type: wired
#
# Stability: development.
def Network.Connection.Type.wired() -> String:
  "wired"

# A value of network.connection.type: cell
#
# Stability: development.
def Network.Connection.Type.cell() -> String:
  "cell"

# A value of network.connection.type: unavailable
#
# Stability: development.
def Network.Connection.Type.unavailable() -> String:
  "unavailable"

# A value of network.connection.type: unknown
#
# Stability: development.
def Network.Connection.Type.unknown() -> String:
  "unknown"

# The network interface name.
#
# Type: string. Stability: release_candidate.
# Examples: "lo", "eth0"
def Network.Interface.name() -> String:
  "network.interface.name"

# The direction of traffic from the perspective of the observing host's
# physical or virtual network interface. It should not be used to represent the
# logical direction of a stateful connection or network flow.
#
# Type: enum. Stability: release_candidate.
# Examples: "transmit"
def Network.Io.direction() -> String:
  "network.io.direction"

# A value of network.io.direction: transmit
#
# Stability: release_candidate.
def Network.Io.Direction.transmit() -> String:
  "transmit"

# A value of network.io.direction: receive
#
# Stability: release_candidate.
def Network.Io.Direction.receive() -> String:
  "receive"

# Local address of the network connection - IP address or UNIX domain socket
# name.
#
# Type: string. Stability: stable.
# Examples: "10.1.2.80", "/tmp/my.sock"
def Network.Local.address() -> String:
  "network.local.address"

# Local port number of the network connection.
#
# Type: int. Stability: stable.
# Examples: 65123
def Network.Local.port() -> String:
  "network.local.port"

# Peer address of the network connection - IP address or UNIX domain socket
# name.
#
# Type: string. Stability: stable.
# Examples: "10.1.2.80", "/tmp/my.sock"
def Network.Peer.address() -> String:
  "network.peer.address"

# Peer port number of the network connection.
#
# Type: int. Stability: stable.
# Examples: 65123
def Network.Peer.port() -> String:
  "network.peer.port"

# [OSI application layer] or non-OSI equivalent.
#
# Type: string. Stability: stable.
# Examples: "amqp", "http", "mqtt"
#
# [OSI application layer]: https://wikipedia.org/wiki/Application_layer
def Network.Protocol.name() -> String:
  "network.protocol.name"

# The actual version of the protocol used for network communication.
#
# Type: string. Stability: stable.
# Examples: "1.1", "2"
def Network.Protocol.version() -> String:
  "network.protocol.version"

# [OSI transport layer] or [inter-process communication method].
#
# Type: enum. Stability: stable.
# Examples: "tcp", "udp"
#
# [OSI transport layer]: https://wikipedia.org/wiki/Transport_layer
# [inter-process communication method]: https://wikipedia.org/wiki/Inter-process_communication
def Network.transport() -> String:
  "network.transport"

# A value of network.transport: TCP
#
# Stability: stable.
def Network.Transport.tcp() -> String:
  "tcp"

# A value of network.transport: UDP
#
# Stability: stable.
def Network.Transport.udp() -> String:
  "udp"

# A value of network.transport: Named or anonymous pipe.
#
# Stability: stable.
def Network.Transport.pipe() -> String:
  "pipe"

# A value of network.transport: UNIX domain socket
#
# Stability: stable.
def Network.Transport.unix() -> String:
  "unix"

# A value of network.transport: QUIC
#
# Stability: stable.
def Network.Transport.quic() -> String:
  "quic"

# [OSI network layer] or non-OSI equivalent.
#
# Type: enum. Stability: stable.
# Examples: "ipv4", "ipv6"
#
# [OSI network layer]: https://wikipedia.org/wiki/Network_layer
def Network.type() -> String:
  "network.type"

# A value of network.type: IPv4
#
# Stability: stable.
def Network.Type.ipv4() -> String:
  "ipv4"

# A value of network.type: IPv6
#
# Stability: stable.
def Network.Type.ipv6() -> String:
  "ipv6"

# Namespace: os
# =============

# Unique identifier for a particular build or compilation of the operating
# system.
#
# Type: string. Stability: development.
# Examples: "TQ3C.230805.001.B2", "20E247", "22621"
def Os.build_id() -> String:
  "os.build_id"

# Human readable (not intended to be parsed) OS version information, like e.g.
# reported by `ver` or `lsb_release -a` commands.
#
# Type: string. Stability: development.
# Examples: "Microsoft Windows [Version 10.0.18363.778]", "Ubuntu 18.04.1 LTS"
def Os.description() -> String:
  "os.description"

# Human readable operating system name.
#
# Type: string. Stability: development.
# Examples: "iOS", "Android", "Ubuntu"
def Os.name() -> String:
  "os.name"

# The operating system type.
#
# Type: enum. Stability: development.
def Os.type() -> String:
  "os.type"

# A value of os.type: Microsoft Windows
#
# Stability: development.
def Os.Type.windows() -> String:
  "windows"

# A value of os.type: Linux
#
# Stability: development.
def Os.Type.linux() -> String:
  "linux"

# A value of os.type: Apple Darwin
#
# Stability: development.
def Os.Type.darwin() -> String:
  "darwin"

# A value of os.type: FreeBSD
#
# Stability: development.
def Os.Type.freebsd() -> String:
  "freebsd"

# A value of os.type: NetBSD
#
# Stability: development.
def Os.Type.netbsd() -> String:
  "netbsd"

# A value of os.type: OpenBSD
#
# Stability: development.
def Os.Type.openbsd() -> String:
  "openbsd"

# A value of os.type: DragonFly BSD
#
# Stability: development.
def Os.Type.dragonflybsd() -> String:
  "dragonflybsd"

# A value of os.type: HP-UX (Hewlett Packard UNIX)
#
# Stability: development.
def Os.Type.hpux() -> String:
  "hpux"

# A value of os.type: AIX (Advanced Interactive eXecutive)
#
# Stability: development.
def Os.Type.aix() -> String:
  "aix"

# A value of os.type: SunOS, Oracle Solaris
#
# Stability: development.
def Os.Type.solaris() -> String:
  "solaris"

# A value of os.type: Deprecated. Use `zos` instead.
#
# Stability: development.
#
# Deprecated (renamed): Replaced by `zos`.
def Os.Type.z_os() -> String:
  "z_os"

# A value of os.type: IBM z/OS
#
# Stability: development.
def Os.Type.zos() -> String:
  "zos"

# The version string of the operating system as defined in [Version Attributes]
# .
#
# Type: string. Stability: development.
# Examples: "14.2.1", "18.04.1"
#
# [Version Attributes]: /docs/resource/README.md#version-attributes
def Os.version() -> String:
  "os.version"

# Namespace: process
# ==================

# Length of the process.command_args array
#
# Type: int. Stability: release_candidate.
# Examples: 4
def Process.args_count() -> String:
  "process.args_count"

# The command used to launch the process (i.e. the command name). On Linux
# based systems, can be set to the zeroth string in `proc/[pid]/cmdline`. On
# Windows, can be set to the first parameter extracted from `GetCommandLineW`.
#
# Type: string. Stability: release_candidate.
# Examples: "cmd/otelcol"
def Process.command() -> String:
  "process.command"

# All the command arguments (including the command/executable itself) as
# received by the process. On Linux-based systems (and some other Unixoid
# systems supporting procfs), can be set according to the list of
# null-delimited strings extracted from `proc/[pid]/cmdline`. For libc-based
# executables, this would be the full argv vector passed to `main`. SHOULD NOT
# be collected by default unless there is sanitization that excludes sensitive
# data.
#
# Type: string[]. Stability: release_candidate.
# Examples: ["cmd/otecol", "--config=config.yaml"]
def Process.command_args() -> String:
  "process.command_args"

# The full command used to launch the process as a single string representing
# the full command. On Windows, can be set to the result of `GetCommandLineW`.
# Do not set this if you have to assemble it just for monitoring; use
# `process.command_args` instead. SHOULD NOT be collected by default unless
# there is sanitization that excludes sensitive data.
#
# Type: string. Stability: release_candidate.
# Examples: "C:\cmd\otecol --config="my directory\config.yaml""
def Process.command_line() -> String:
  "process.command_line"

# Specifies whether the context switches for this data point were voluntary or
# involuntary.
#
# Type: enum. Stability: release_candidate.
def Process.ContextSwitch.type() -> String:
  "process.context_switch.type"

# A value of process.context_switch.type: voluntary
#
# Stability: release_candidate.
def Process.ContextSwitch.Type.voluntary() -> String:
  "voluntary"

# A value of process.context_switch.type: involuntary
#
# Stability: release_candidate.
def Process.ContextSwitch.Type.involuntary() -> String:
  "involuntary"

# Deprecated, use `cpu.mode` instead.
#
# Type: enum. Stability: development.
#
# Deprecated (renamed): Replaced by `cpu.mode`.
def Process.Cpu.state() -> String:
  "process.cpu.state"

# A value of process.cpu.state: system
#
# Stability: development.
def Process.Cpu.State.system() -> String:
  "system"

# A value of process.cpu.state: user
#
# Stability: development.
def Process.Cpu.State.user() -> String:
  "user"

# A value of process.cpu.state: wait
#
# Stability: development.
def Process.Cpu.State.wait() -> String:
  "wait"

# The date and time the process was created, in ISO 8601 format.
#
# Type: string. Stability: release_candidate.
# Examples: "2023-11-21T09:25:34.853Z"
def Process.Creation.time() -> String:
  "process.creation.time"

# Process environment variables, `<key>` being the environment variable name,
# the value being the environment variable value.
#
# Type: template[string]. Stability: release_candidate.
# Examples: "ubuntu", "/usr/local/bin:/usr/bin"
def Process.environment_variable() -> String:
  "process.environment_variable"

# The GNU build ID as found in the `.note.gnu.build-id` ELF section (hex
# string).
#
# Type: string. Stability: release_candidate.
# Examples: "c89b11207f6479603b0d49bf291c092c2b719293"
def Process.Executable.BuildId.gnu() -> String:
  "process.executable.build_id.gnu"

# The Go build ID as retrieved by `go tool buildid <go executable>`.
#
# Type: string. Stability: release_candidate.
# Examples:
# "foh3mEXu7BLZjsN9pOwG/kATcXlYVCDEFouRMQed_/WwRFB1hPo9LBkekthSPG/x8hMC8emW2cCjXD0_1aY"
def Process.Executable.BuildId.go() -> String:
  "process.executable.build_id.go"

# Deterministic build ID for executables.
#
# Type: string. Stability: release_candidate.
# Examples: "600DCAFE4A110000F2BF38C493F5FB92"
def Process.Executable.BuildId.htlhash() -> String:
  "process.executable.build_id.htlhash"

# "Deprecated, use `process.executable.build_id.htlhash` instead."
#
# Type: string. Stability: development.
# Examples: "600DCAFE4A110000F2BF38C493F5FB92"
#
# Deprecated (renamed): Replaced by `process.executable.build_id.htlhash`.
def Process.Executable.BuildId.profiling() -> String:
  "process.executable.build_id.profiling"

# The name of the process executable. On Linux based systems, this SHOULD be
# set to the base name of the target of `/proc/[pid]/exe`. On Windows, this
# SHOULD be set to the base name of `GetProcessImageFileNameW`.
#
# Type: string. Stability: release_candidate.
# Examples: "otelcol"
def Process.Executable.name() -> String:
  "process.executable.name"

# The full path to the process executable. On Linux based systems, can be set
# to the target of `proc/[pid]/exe`. On Windows, can be set to the result of
# `GetProcessImageFileNameW`.
#
# Type: string. Stability: release_candidate.
# Examples: "/usr/bin/cmd/otelcol"
def Process.Executable.path() -> String:
  "process.executable.path"

# The exit code of the process.
#
# Type: int. Stability: release_candidate.
# Examples: 127
def Process.Exit.code() -> String:
  "process.exit.code"

# The date and time the process exited, in ISO 8601 format.
#
# Type: string. Stability: release_candidate.
# Examples: "2023-11-21T09:26:12.315Z"
def Process.Exit.time() -> String:
  "process.exit.time"

# The PID of the process's group leader. This is also the process group ID
# (PGID) of the process.
#
# Type: int. Stability: release_candidate.
# Examples: 23
def Process.GroupLeader.pid() -> String:
  "process.group_leader.pid"

# Whether the process is connected to an interactive shell.
#
# Type: boolean. Stability: release_candidate.
def Process.interactive() -> String:
  "process.interactive"

# The control group associated with the process.
#
# Type: string. Stability: release_candidate.
# Examples: "1:name=systemd:/user.slice/user-1000.slice/session-3.scope",
# "0::/user.slice/user-1000.slice/user@1000.service/tmux-spawn-0267755b-4639-4a27-90ed-f19f88e53748.scope"
def Process.Linux.cgroup() -> String:
  "process.linux.cgroup"

# The username of the user that owns the process.
#
# Type: string. Stability: release_candidate.
# Examples: "root"
def Process.owner() -> String:
  "process.owner"

# Deprecated, use `system.paging.fault.type` instead.
#
# Type: enum. Stability: development.
#
# Deprecated (renamed): Replaced by `system.paging.fault.type`.
def Process.Paging.fault_type() -> String:
  "process.paging.fault_type"

# A value of process.paging.fault_type: major
#
# Stability: development.
def Process.Paging.FaultType.major() -> String:
  "major"

# A value of process.paging.fault_type: minor
#
# Stability: development.
def Process.Paging.FaultType.minor() -> String:
  "minor"

# Parent Process identifier (PPID).
#
# Type: int. Stability: release_candidate.
# Examples: 111
def Process.parent_pid() -> String:
  "process.parent_pid"

# Process identifier (PID).
#
# Type: int. Stability: release_candidate.
# Examples: 1234
def Process.pid() -> String:
  "process.pid"

# The real user ID (RUID) of the process.
#
# Type: int. Stability: release_candidate.
# Examples: 1000
def Process.RealUser.id() -> String:
  "process.real_user.id"

# The username of the real user of the process.
#
# Type: string. Stability: release_candidate.
# Examples: "operator"
def Process.RealUser.name() -> String:
  "process.real_user.name"

# An additional description about the runtime of the process, for example a
# specific vendor customization of the runtime environment.
#
# Type: string. Stability: release_candidate.
# Examples: "Eclipse OpenJ9 Eclipse OpenJ9 VM openj9-0.21.0"
def Process.Runtime.description() -> String:
  "process.runtime.description"

# The name of the runtime of this process.
#
# Type: string. Stability: release_candidate.
# Examples: "OpenJDK Runtime Environment"
def Process.Runtime.name() -> String:
  "process.runtime.name"

# The version of the runtime of this process, as returned by the runtime
# without modification.
#
# Type: string. Stability: release_candidate.
# Examples: "14.0.2"
def Process.Runtime.version() -> String:
  "process.runtime.version"

# The saved user ID (SUID) of the process.
#
# Type: int. Stability: release_candidate.
# Examples: 1002
def Process.SavedUser.id() -> String:
  "process.saved_user.id"

# The username of the saved user.
#
# Type: string. Stability: release_candidate.
# Examples: "operator"
def Process.SavedUser.name() -> String:
  "process.saved_user.name"

# The PID of the process's session leader. This is also the session ID (SID) of
# the process.
#
# Type: int. Stability: release_candidate.
# Examples: 14
def Process.SessionLeader.pid() -> String:
  "process.session_leader.pid"

# The process state, e.g., [Linux Process State Codes]
#
# Type: enum. Stability: release_candidate.
# Examples: "running"
#
# [Linux Process State Codes]: https://man7.org/linux/man-pages/man1/ps.1.html#PROCESS_STATE_CODES
def Process.state() -> String:
  "process.state"

# A value of process.state: running
#
# Stability: release_candidate.
def Process.State.running() -> String:
  "running"

# A value of process.state: sleeping
#
# Stability: release_candidate.
def Process.State.sleeping() -> String:
  "sleeping"

# A value of process.state: stopped
#
# Stability: release_candidate.
def Process.State.stopped() -> String:
  "stopped"

# A value of process.state: defunct
#
# Stability: release_candidate.
def Process.State.defunct() -> String:
  "defunct"

# Process title (proctitle)
#
# Type: string. Stability: release_candidate.
# Examples: "cat /etc/hostname", "xfce4-session", "bash"
def Process.title() -> String:
  "process.title"

# The effective user ID (EUID) of the process.
#
# Type: int. Stability: release_candidate.
# Examples: 1001
def Process.User.id() -> String:
  "process.user.id"

# The username of the effective user of the process.
#
# Type: string. Stability: release_candidate.
# Examples: "root"
def Process.User.name() -> String:
  "process.user.name"

# Virtual process identifier.
#
# Type: int. Stability: release_candidate.
# Examples: 12
def Process.vpid() -> String:
  "process.vpid"

# The working directory of the process.
#
# Type: string. Stability: release_candidate.
# Examples: "/root"
def Process.working_directory() -> String:
  "process.working_directory"

# Namespace: server
# =================

# Server domain name if available without reverse DNS lookup; otherwise, IP
# address or UNIX domain socket name.
#
# Type: string. Stability: stable.
# Examples: "example.com", "10.1.2.80", "/tmp/my.sock"
def Server.address() -> String:
  "server.address"

# Server port number.
#
# Type: int. Stability: stable.
# Examples: 80, 8080, 443
def Server.port() -> String:
  "server.port"

# Namespace: service
# ==================

# The operational criticality of the service.
#
# Type: enum. Stability: alpha.
# Examples: "critical", "high", "medium", "low"
def Service.criticality() -> String:
  "service.criticality"

# A value of service.criticality: Service is business-critical; downtime
# directly impacts revenue, user experience, or core functionality.
#
# Stability: alpha.
def Service.Criticality.critical() -> String:
  "critical"

# A value of service.criticality: Service is important but has degradation
# tolerance or fallback mechanisms.
#
# Stability: alpha.
def Service.Criticality.high() -> String:
  "high"

# A value of service.criticality: Service provides supplementary functionality;
# degradation has limited user impact.
#
# Stability: alpha.
def Service.Criticality.medium() -> String:
  "medium"

# A value of service.criticality: Service is non-essential to core operations;
# used for background tasks or internal tools.
#
# Stability: alpha.
def Service.Criticality.low() -> String:
  "low"

# The string ID of the service instance.
#
# Type: string. Stability: stable.
# Examples: "627cc493-f310-47de-96bd-71410b7dec09"
def Service.Instance.id() -> String:
  "service.instance.id"

# Logical name of the service.
#
# Type: string. Stability: stable.
# Examples: "shoppingcart"
def Service.name() -> String:
  "service.name"

# A namespace for `service.name`.
#
# Type: string. Stability: stable.
# Examples: "Shop"
def Service.namespace() -> String:
  "service.namespace"

# Logical name of the service on the other side of the connection. SHOULD be
# equal to the actual [`service.name`] resource attribute of the remote service
# if any.
#
# Type: string. Stability: development.
# Examples: "shoppingcart"
#
# [`service.name`]: /docs/resource/README.md#service
def Service.Peer.name() -> String:
  "service.peer.name"

# Logical namespace of the service on the other side of the connection. SHOULD
# be equal to the actual [`service.namespace`] resource attribute of the remote
# service if any.
#
# Type: string. Stability: development.
# Examples: "Shop"
#
# [`service.namespace`]: /docs/resource/README.md#service
def Service.Peer.namespace() -> String:
  "service.peer.namespace"

# The version string of the service component. The format is not defined by
# these conventions.
#
# Type: string. Stability: stable.
# Examples: "2.0.0", "a01dbef8a"
def Service.version() -> String:
  "service.version"

# Namespace: telemetry
# ====================

# The name of the auto instrumentation agent or distribution, if used.
#
# Type: string. Stability: stable.
# Examples: "parts-unlimited-java"
def Telemetry.Distro.name() -> String:
  "telemetry.distro.name"

# The version string of the auto instrumentation agent or distribution, if
# used.
#
# Type: string. Stability: stable.
# Examples: "1.2.3"
def Telemetry.Distro.version() -> String:
  "telemetry.distro.version"

# The language of the telemetry SDK.
#
# Type: enum. Stability: stable.
def Telemetry.Sdk.language() -> String:
  "telemetry.sdk.language"

# A value of telemetry.sdk.language: [C++]
#
# Stability: stable.
#
# [C++]: https://opentelemetry.io/docs/languages/cpp/
def Telemetry.Sdk.Language.cpp() -> String:
  "cpp"

# A value of telemetry.sdk.language: [.NET]
#
# Stability: stable.
#
# [.NET]: https://opentelemetry.io/docs/languages/dotnet/
def Telemetry.Sdk.Language.dotnet() -> String:
  "dotnet"

# A value of telemetry.sdk.language: [Erlang/Elixir]
#
# Stability: stable.
#
# [Erlang/Elixir]: https://opentelemetry.io/docs/languages/erlang/
def Telemetry.Sdk.Language.erlang() -> String:
  "erlang"

# A value of telemetry.sdk.language: [Go]
#
# Stability: stable.
#
# [Go]: https://opentelemetry.io/docs/languages/go/
def Telemetry.Sdk.Language.go() -> String:
  "go"

# A value of telemetry.sdk.language: [Java]
#
# Stability: stable.
#
# [Java]: https://opentelemetry.io/docs/languages/java/
def Telemetry.Sdk.Language.java() -> String:
  "java"

# A value of telemetry.sdk.language: [Kotlin]
#
# Stability: stable.
#
# [Kotlin]: https://opentelemetry.io/docs/languages/kotlin/
def Telemetry.Sdk.Language.kotlin() -> String:
  "kotlin"

# A value of telemetry.sdk.language: [Node.js]
#
# Stability: stable.
#
# [Node.js]: https://opentelemetry.io/docs/languages/js/
def Telemetry.Sdk.Language.nodejs() -> String:
  "nodejs"

# A value of telemetry.sdk.language: [PHP]
#
# Stability: stable.
#
# [PHP]: https://opentelemetry.io/docs/languages/php/
def Telemetry.Sdk.Language.php() -> String:
  "php"

# A value of telemetry.sdk.language: [Python]
#
# Stability: stable.
#
# [Python]: https://opentelemetry.io/docs/languages/python/
def Telemetry.Sdk.Language.python() -> String:
  "python"

# A value of telemetry.sdk.language: [Ruby]
#
# Stability: stable.
#
# [Ruby]: https://opentelemetry.io/docs/languages/ruby/
def Telemetry.Sdk.Language.ruby() -> String:
  "ruby"

# A value of telemetry.sdk.language: [Rust]
#
# Stability: stable.
#
# [Rust]: https://opentelemetry.io/docs/languages/rust/
def Telemetry.Sdk.Language.rust() -> String:
  "rust"

# A value of telemetry.sdk.language: [Swift]
#
# Stability: stable.
#
# [Swift]: https://opentelemetry.io/docs/languages/swift/
def Telemetry.Sdk.Language.swift() -> String:
  "swift"

# A value of telemetry.sdk.language: [Browser]
#
# Stability: stable.
#
# [Browser]: https://opentelemetry.io/docs/languages/js/
def Telemetry.Sdk.Language.webjs() -> String:
  "webjs"

# The name of the telemetry SDK as defined above.
#
# Type: string. Stability: stable.
# Examples: "opentelemetry"
def Telemetry.Sdk.name() -> String:
  "telemetry.sdk.name"

# The version string of the telemetry SDK.
#
# Type: string. Stability: stable.
# Examples: "1.2.3"
def Telemetry.Sdk.version() -> String:
  "telemetry.sdk.version"

# Namespace: url
# ==============

# Domain extracted from the `url.full`, such as "opentelemetry.io".
#
# Type: string. Stability: development.
# Examples: "www.foo.bar", "opentelemetry.io", "3.12.167.2",
# "[1080:0:0:0:8:800:200C:417A]"
def Url.domain() -> String:
  "url.domain"

# The file extension extracted from the `url.full`, excluding the leading dot.
#
# Type: string. Stability: development.
# Examples: "png", "gz"
def Url.extension() -> String:
  "url.extension"

# The [URI fragment] component
#
# Type: string. Stability: stable.
# Examples: "SemConv"
#
# [URI fragment]: https://www.rfc-editor.org/rfc/rfc3986#section-3.5
def Url.fragment() -> String:
  "url.fragment"

# Absolute URL describing a network resource according to [RFC3986]
#
# Type: string. Stability: stable.
# Examples: "https://www.foo.bar/search?q=OpenTelemetry#SemConv", "//localhost"
#
# [RFC3986]: https://www.rfc-editor.org/rfc/rfc3986
def Url.full() -> String:
  "url.full"

# Unmodified original URL as seen in the event source.
#
# Type: string. Stability: development.
# Examples: "https://www.foo.bar/search?q=OpenTelemetry#SemConv",
# "search?q=OpenTelemetry"
def Url.original() -> String:
  "url.original"

# The [URI path] component
#
# Type: string. Stability: stable.
# Examples: "/search"
#
# [URI path]: https://www.rfc-editor.org/rfc/rfc3986#section-3.3
def Url.path() -> String:
  "url.path"

# Port extracted from the `url.full`
#
# Type: int. Stability: development.
# Examples: 443
def Url.port() -> String:
  "url.port"

# The [URI query] component
#
# Type: string. Stability: stable.
# Examples: "q=OpenTelemetry"
#
# [URI query]: https://www.rfc-editor.org/rfc/rfc3986#section-3.4
def Url.query() -> String:
  "url.query"

# The highest registered URL domain, stripped of the subdomain.
#
# Type: string. Stability: development.
# Examples: "example.com", "foo.co.uk"
def Url.registered_domain() -> String:
  "url.registered_domain"

# The [URI scheme] component identifying the used protocol.
#
# Type: string. Stability: stable.
# Examples: "https", "ftp", "telnet"
#
# [URI scheme]: https://www.rfc-editor.org/rfc/rfc3986#section-3.1
def Url.scheme() -> String:
  "url.scheme"

# The subdomain portion of a fully qualified domain name includes all of the
# names except the hostname under the registered_domain. In a partially
# qualified domain, or if the qualification level of the full name cannot be
# determined, subdomain contains all of the names below the registered domain.
#
# Type: string. Stability: development.
# Examples: "east", "sub2.sub1"
def Url.subdomain() -> String:
  "url.subdomain"

# The low-cardinality template of an [absolute path reference].
#
# Type: string. Stability: development.
# Examples: "/users/{id}", "/users/:id", "/users?id={id}"
#
# [absolute path reference]: https://www.rfc-editor.org/rfc/rfc3986#section-4.2
def Url.template() -> String:
  "url.template"

# The effective top level domain (eTLD), also known as the domain suffix, is
# the last part of the domain name. For example, the top level domain for
# example.com is `com`.
#
# Type: string. Stability: development.
# Examples: "com", "co.uk"
def Url.top_level_domain() -> String:
  "url.top_level_domain"

# Namespace: user_agent
# =====================

# Name of the user-agent extracted from original. Usually refers to the
# browser's name.
#
# Type: string. Stability: development.
# Examples: "Safari", "YourApp"
def UserAgent.name() -> String:
  "user_agent.name"

# Value of the [HTTP User-Agent] header sent by the client.
#
# Type: string. Stability: stable.
# Examples: "CERN-LineMode/2.15 libwww/2.17b3", "Mozilla/5.0 (iPhone; CPU
# iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)
# Version/14.1.2 Mobile/15E148 Safari/604.1", "YourApp/1.0.0
# grpc-java-okhttp/1.27.2"
#
# [HTTP User-Agent]: https://www.rfc-editor.org/rfc/rfc9110.html#field.user-agent
def UserAgent.original() -> String:
  "user_agent.original"

# Human readable operating system name.
#
# Type: string. Stability: development.
# Examples: "iOS", "Android", "Ubuntu"
def UserAgent.Os.name() -> String:
  "user_agent.os.name"

# The version string of the operating system as defined in [Version Attributes]
# .
#
# Type: string. Stability: development.
# Examples: "14.2.1", "18.04.1"
#
# [Version Attributes]: /docs/resource/README.md#version-attributes
def UserAgent.Os.version() -> String:
  "user_agent.os.version"

# Specifies the category of synthetic traffic, such as tests or bots.
#
# Type: enum. Stability: development.
def UserAgent.Synthetic.type() -> String:
  "user_agent.synthetic.type"

# A value of user_agent.synthetic.type: Bot source.
#
# Stability: development.
def UserAgent.Synthetic.Type.bot() -> String:
  "bot"

# A value of user_agent.synthetic.type: Synthetic test source.
#
# Stability: development.
def UserAgent.Synthetic.Type.test() -> String:
  "test"

# Version of the user-agent extracted from original. Usually refers to the
# browser's version
#
# Type: string. Stability: development.
# Examples: "14.1.2", "1.0.0"
def UserAgent.version() -> String:
  "user_agent.version"

# Values of this project that the registry does not list
# ======================================================
#
# These definitions come from templates/registry/bend/project.bend.j2, not
# from the registry; packages/semconv/README.md explains each one.

# The value of telemetry.sdk.language for a Bend SDK. The registry's members
# of that attribute, above, do not include Bend at v1.44.0; the SDK's
# resource carries this value until the conventions list the language, and
# the generated member replaces this definition when they do.
def Telemetry.Sdk.Language.bend() -> String:
  "bend"
