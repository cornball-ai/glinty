# The Origin policy on a WebSocket upgrade (#48). Browsers exempt
# WebSockets from the same-origin policy, so a page this server did
# not serve must be refused before the handshake. CivetWeb performs
# the handshake; glinty decides on the ws_connect event, from Origin
# against Host, never against a hardcoded localhost.

allowed <- function(origin = NULL, host = "localhost:8080", origins = NULL) {
    glinty:::ws_origin_allowed(origin, host, origins)
}

# --- same-host default ---
# absent Origin: a non-browser client, allowed
expect_true(allowed())
# the page this server served
expect_true(allowed("http://localhost:8080"))
# hosts compare case-insensitively
expect_true(allowed("http://LOCALHOST:8080"))
# implied ports match a portless Host, either scheme
expect_true(allowed("http://myapp.example", host = "myapp.example"))
expect_true(allowed("https://myapp.example", host = "myapp.example"))
# a tailnet name matches itself
expect_true(allowed("http://troy-g5.tail.ts.net:8080",
                    host = "troy-g5.tail.ts.net:8080"))
# bracketed IPv6
expect_true(allowed("http://[::1]:8080", host = "[::1]:8080"))

# a different site is refused
expect_false(allowed("https://evil.example"))
# a different port on the same host is a different origin
expect_false(allowed("http://localhost:9999"))
# implied origin ports (80, 443) against an explicit 8080
expect_false(allowed("http://localhost"))
expect_false(allowed("https://localhost"))
# nonstandard origin port against a portless Host
expect_false(allowed("http://myapp.example:8080", host = "myapp.example"))
# opaque origins ("null": sandboxed iframe, file://) refuse
expect_false(allowed("null"))
# an Origin with no Host to compare against refuses
expect_false(allowed("http://localhost:8080", host = NULL))

# --- allowlist and "*" ---
allow <- "https://app.example.com"
expect_true(allowed("https://app.example.com", origins = allow))
# default port stripped on both sides of the comparison
expect_true(allowed("https://app.example.com:443", origins = allow))
expect_true(allowed("https://APP.example.com",
                    origins = "https://app.example.com:443"))
# same-host stays allowed alongside an allowlist
expect_true(allowed("http://localhost:8080", origins = allow))
expect_false(allowed("https://other.example.com", origins = allow))
# "null" can be allowlisted, but only literally
expect_true(allowed("null", origins = "null"))
expect_false(allowed("null", origins = allow))
# "*" disables the check
expect_true(allowed("https://evil.example", origins = "*"))

# --- parsing helpers stay strict ---
split_host_port <- glinty:::split_host_port
normalize_origin <- glinty:::normalize_origin
expect_equal(split_host_port("Example.COM:8080"),
             list(host = "example.com", port = 8080L))
expect_equal(split_host_port("example.com")$port, NA_integer_)
expect_null(split_host_port("exa mple.com"))
expect_null(split_host_port("example.com/path"))
expect_equal(normalize_origin("HTTPS://App.Example.com:443"),
             "https://app.example.com")
expect_equal(normalize_origin("http://app.example.com:8080"),
             "http://app.example.com:8080")
expect_null(normalize_origin("null"))
