import Base
import ./semconv.bend as Semconv

# The laws of bend-telemetry-semconv
# ==================================
#
# Each `law` below pins a constant of the generated module against literal
# text taken from the semantic conventions registry at v1.44.0 itself, never
# from the generator: a handful of attribute names, enumeration values and
# the schema URL, across the namespaces the package covers. PROOF.bend proves
# each one with a `def Laws.<name>`; the proof gate is
#
#   ./bend packages/semconv/PROOF.bend --check-only
#
# which prints "ALL PROOFS CHECK" only when every law holds and nothing the
# proofs import relies on `@unsafe` or foreign code.

# The package answers its own BendHub name.
law package_name:
  {Semconv.Package.name() == "bend-telemetry-semconv" : String}

# The schema URL names the conventions version the constants come from.
law schema_url:
  {Semconv.Schema.url() == "https://opentelemetry.io/schemas/1.44.0" : String}

# Attribute names: dots become capitalized segments, the last segment stays
# as written, and `_` inside a namespace segment joins its words.
law http_request_method:
  {Semconv.Http.Request.method() == "http.request.method" : String}

law http_request_method_original:
  {Semconv.Http.Request.method_original() == "http.request.method_original" : String}

law http_response_status_code:
  {Semconv.Http.Response.status_code() == "http.response.status_code" : String}

law http_route:
  {Semconv.Http.route() == "http.route" : String}

law url_full:
  {Semconv.Url.full() == "url.full" : String}

law server_address:
  {Semconv.Server.address() == "server.address" : String}

law client_address:
  {Semconv.Client.address() == "client.address" : String}

law network_protocol_version:
  {Semconv.Network.Protocol.version() == "network.protocol.version" : String}

law user_agent_original:
  {Semconv.UserAgent.original() == "user_agent.original" : String}

law error_type:
  {Semconv.Error.type() == "error.type" : String}

law exception_type:
  {Semconv.Exception.type() == "exception.type" : String}

law service_name:
  {Semconv.Service.name() == "service.name" : String}

law telemetry_sdk_language:
  {Semconv.Telemetry.Sdk.language() == "telemetry.sdk.language" : String}

law telemetry_distro_name:
  {Semconv.Telemetry.Distro.name() == "telemetry.distro.name" : String}

law process_pid:
  {Semconv.Process.pid() == "process.pid" : String}

law process_executable_build_id_gnu:
  {Semconv.Process.Executable.BuildId.gnu() == "process.executable.build_id.gnu" : String}

law host_name:
  {Semconv.Host.name() == "host.name" : String}

law os_type:
  {Semconv.Os.type() == "os.type" : String}

law container_id:
  {Semconv.Container.id() == "container.id" : String}

# Enumeration values: a def under the attribute's name, with every segment
# capitalized, named after the member's id and answering the member's value.
law http_request_method_get:
  {Semconv.Http.Request.Method.get() == "GET" : String}

law http_request_method_other:
  {Semconv.Http.Request.Method.other() == "_OTHER" : String}

law error_type_other:
  {Semconv.Error.Type.other() == "_OTHER" : String}

law network_transport_tcp:
  {Semconv.Network.Transport.tcp() == "tcp" : String}

law os_type_linux:
  {Semconv.Os.Type.linux() == "linux" : String}

law host_arch_arm64:
  {Semconv.Host.Arch.arm64() == "arm64" : String}

law telemetry_sdk_language_go:
  {Semconv.Telemetry.Sdk.Language.go() == "go" : String}

# Deprecated attributes and members are generated too, with their note.
law http_method_deprecated:
  {Semconv.Http.method() == "http.method" : String}

law http_flavor_http_1_1_deprecated:
  {Semconv.Http.Flavor.http_1_1() == "1.1" : String}

# The project's own value for telemetry.sdk.language, which the registry does
# not list at v1.44.0 (packages/semconv/README.md).
law telemetry_sdk_language_bend:
  {Semconv.Telemetry.Sdk.Language.bend() == "bend" : String}
