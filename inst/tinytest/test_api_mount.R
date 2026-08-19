# The api mount (#72): one process serving the glinty app and an
# application JSON API from the same origin, same auth.

route_http <- glinty:::route_http
route_api <- glinty:::route_api
api_body <- glinty:::api_body
api_principal <- glinty:::api_principal

page <- "<html>the page</html>"
pkg_www <- system.file("www", package = "glinty")

req <- function(method, path, query = "", headers = character(0L),
                body = NULL) {
    list(method = method, path = path, query = query, headers = headers,
         body = body)
}

# split a raw response into head text and raw body (media-safe, same
# shape as test_http.R's helper)
split_resp <- function(resp) {
    pat <- charToRaw("\r\n\r\n")
    for (i in seq_len(length(resp) - 3L)) {
        if (all(resp[i:(i + 3L)] == pat)) {
            return(list(head = rawToChar(resp[seq_len(i - 1L)]),
                        body = if (i + 4L <= length(resp)) {
                    resp[(i + 4L):length(resp)]
                } else {
                    raw(0L)
                }))
        }
    }
    NULL
}
resp_json <- function(resp) {
    jsonlite::fromJSON(rawToChar(split_resp(resp)$body),
                       simplifyVector = TRUE)
}

demo_api <- function(method, path, body, query, principal) {
    if (path == "/echo") {
        return(list(status = 200L,
                    body = list(method = method, body = body, query = query,
                                principal = principal)))
    }
    if (path == "/made" && method == "POST") {
        return(list(status = 201L, body = list(id = 7L)))
    }
    if (path == "/gone") {
        return(list(status = 302L, body = NULL,
                    headers = c(Location = "/elsewhere")))
    }
    if (path == "/boom") {
        stop("secret internal detail")
    }
    NULL
}

# --- built-ins still win with an api mounted ---
resp <- route_http(req("GET", "/"), page, pkg_www, NULL, api = demo_api)
expect_true(grepl("the page", rawToChar(resp), fixed = TRUE))
resp <- route_http(req("GET", "/healthz"), page, pkg_www, NULL,
                   api = demo_api)
expect_true(grepl('"status":"ok"', rawToChar(resp), fixed = TRUE))

# --- every method reaches the api; the router's answer comes back ---
resp <- route_http(req("GET", "/echo", query = "a=1&b=two%20words"),
                   page, pkg_www, NULL, api = demo_api)
got <- resp_json(resp)
expect_equal(got$method, "GET")
expect_equal(got$query$a, "1")
expect_equal(got$query$b, "two words")

resp <- route_http(req("POST", "/echo",
                       body = charToRaw('{"minutes": 30, "notes": "ok"}')),
                   page, pkg_www, NULL, api = demo_api)
got <- resp_json(resp)
expect_equal(got$method, "POST")
expect_equal(got$body$minutes, 30L)
expect_equal(got$body$notes, "ok")

for (m in c("PATCH", "DELETE")) {
    got <- resp_json(route_http(req(m, "/echo"), page, pkg_www, NULL,
                                api = demo_api))
    expect_equal(got$method, m)
}

# --- status reasons and bodies ---
head201 <- split_resp(route_http(req("POST", "/made"), page, pkg_www, NULL,
                                 api = demo_api))$head
expect_true(startsWith(head201, "HTTP/1.1 201 Created"))

r302 <- split_resp(route_http(req("GET", "/gone"), page, pkg_www, NULL,
                              api = demo_api))
expect_true(startsWith(r302$head, "HTTP/1.1 302 Found"))
expect_true(grepl("Location: /elsewhere\r\n", r302$head, fixed = TRUE))
expect_equal(length(r302$body), 0L)

# --- NULL from the router falls through to 404, mounted or not ---
resp <- route_http(req("GET", "/nowhere"), page, pkg_www, NULL,
                   api = demo_api)
expect_true(grepl("404", rawToChar(resp)))
# and without an api, non-GET is a 404 exactly as before
resp <- route_http(req("POST", "/echo"), page, pkg_www, NULL)
expect_true(grepl("404", rawToChar(resp)))

# --- a router error answers 500 and never leaks the message ---
resp <- rawToChar(route_http(req("GET", "/boom"), page, pkg_www, NULL,
                             api = demo_api))
expect_true(grepl("500 Internal Server Error", resp, fixed = TRUE))
expect_true(grepl("internal error", resp, fixed = TRUE))
expect_false(grepl("secret internal detail", resp, fixed = TRUE))

# --- body decoding: absent, malformed, and non-JSON all read NULL ---
expect_null(api_body(req("POST", "/x")))
expect_null(api_body(req("POST", "/x", body = raw(0L))))
expect_null(api_body(req("POST", "/x", body = charToRaw("not json"))))
expect_equal(api_body(req("POST", "/x", body = charToRaw('{"a":1}')))$a, 1L)

# --- principals: the same verifier, per request ---
ver1 <- function(token) if (identical(token, "tok")) list(id = "u1")
p <- api_principal(req("GET", "/x",
                       headers = c(authorization = "Bearer tok")), ver1)
expect_equal(p$id, "u1")
expect_null(api_principal(req("GET", "/x"), ver1))
expect_null(api_principal(req("GET", "/x",
                              headers = c(authorization = "Bearer bad")),
                          ver1))
# no auth configured: NULL principal, the request still routes
expect_null(api_principal(req("GET", "/x"), NULL))
# a two-argument verifier sees the request itself (cookie sessions)
ver2 <- function(token, r) {
    if (identical(unname(r$headers[["cookie"]]), "session=abc")) {
        list(id = "cookie-user")
    }
}
p <- api_principal(req("GET", "/x", headers = c(cookie = "session=abc")),
                   ver2)
expect_equal(p$id, "cookie-user")
# a verifier that errors yields NULL, not a 500
boom <- function(token) stop("verifier bug")
expect_null(api_principal(req("GET", "/x",
                              headers = c(authorization = "Bearer t")),
                          boom))
# and the principal reaches the router
resp <- route_http(req("GET", "/echo",
                       headers = c(authorization = "Bearer tok")),
                   page, pkg_www, NULL, api = demo_api, auth = ver1)
expect_equal(resp_json(resp)$principal$id, "u1")

# --- binary file responses ---
f <- tempfile(fileext = ".png")
writeBin(as.raw(c(137L, 80L, 78L, 71L, 0L, 1L, 2L, 3L)), f)
file_api <- function(method, path, body, query, principal) {
    if (path == "/pic") {
        return(list(status = 200L, file = f))
    }
    if (path == "/pic-typed") {
        return(list(status = 200L, file = f,
                    content_type = "application/octet-stream"))
    }
    if (path == "/pic-missing") {
        return(list(status = 200L, file = file.path(tempdir(), "no.png")))
    }
    NULL
}
r <- split_resp(route_http(req("GET", "/pic"), page, pkg_www, NULL,
                           api = file_api))
expect_true(grepl("Content-Type: image/png", r$head, fixed = TRUE))
expect_identical(r$body, readBin(f, "raw", 8L))
r <- split_resp(route_http(req("GET", "/pic-typed"), page, pkg_www, NULL,
                           api = file_api))
expect_true(grepl("application/octet-stream", r$head, fixed = TRUE))
resp <- rawToChar(route_http(req("GET", "/pic-missing"), page, pkg_www,
                             NULL, api = file_api))
expect_true(grepl("404", resp))
unlink(f)

# --- run_app validates api ---
a <- app(ui = page(txt("x"), title = "T"),
         server = function(input, output) NULL)
expect_error(run_app(a, api = "not a function"), "api must be")

# --- body decoding never simplifies: shape and null survive the wire ---
got <- api_body(req("POST", "/x", body = charToRaw(paste0(
    '{"revision":3,"ops":[{"verb":"move","args":{"x":1.5,"at":null}},',
    '{"verb":"del"}]}'))))
expect_equal(got$revision, 3)
expect_true(is.list(got$ops))
expect_false(is.data.frame(got$ops))
expect_equal(length(got$ops), 2L)
expect_equal(got$ops[[1]]$verb, "move")
expect_equal(got$ops[[1]]$args$x, 1.5)
# a field sent as null is present-and-NULL; one not sent is absent
expect_true("at" %in% names(got$ops[[1]]$args))
expect_null(got$ops[[1]]$args$at)
expect_false("args" %in% names(got$ops[[2]]))
# arrays stay lists even when they would simplify to a vector
got <- api_body(req("POST", "/x", body = charToRaw('{"ids":["a","b"]}')))
expect_true(is.list(got$ids))
expect_equal(length(got$ids), 2L)

# --- json =: a pre-serialized document passes through verbatim ---
doc <- '{"OTIO_SCHEMA":"Timeline.1","tracks":[1,2],"note":null}'
json_api <- function(method, path, body, query, principal) {
    if (path == "/doc") {
        return(list(status = 200L, json = doc,
                    headers = c(ETag = "\"7\"")))
    }
    NULL
}
r <- split_resp(route_http(req("GET", "/doc"), page, pkg_www, NULL,
                           api = json_api))
expect_true(grepl("Content-Type: application/json", r$head, fixed = TRUE))
expect_true(grepl("ETag: \"7\"\r\n", r$head, fixed = TRUE))
expect_identical(rawToChar(r$body), doc)

# --- json = respects a given content type ---
r <- split_resp(route_http(req("GET", "/x"), page, pkg_www, NULL,
                           api = function(method, path, body, query,
                                          principal) {
    list(status = 200L, json = "{\"a\":1}",
         content_type = "application/problem+json")
}))
expect_true(grepl("Content-Type: application/problem+json", r$head,
                  fixed = TRUE))

# --- every malformed return answers the same sanitized 500 as a
#     throw: nothing degraded, nothing leaked ---
sanitized_500 <- function(res) {
    a <- function(method, path, body, query, principal) res
    txt <- rawToChar(route_http(req("GET", "/x"), page, pkg_www, NULL,
                                api = a))
    grepl("500 Internal Server Error", txt, fixed = TRUE) &&
        grepl("{\"error\":\"internal error\"}", txt, fixed = TRUE)
}
# json = the wrong type, and json = "" (a 200 whose body a JSON
# parser rejects at EOF)
expect_true(sanitized_500(list(status = 200L, json = list(no = "str"))))
expect_true(sanitized_500(list(status = 200L, json = "")))
# not a response list at all
expect_true(sanitized_500(42))
# unknown fields refuse: `$` would partial-match json_api_version as
# json = and hijack the response, and a typo'd shape would otherwise
# answer 200-empty
expect_true(sanitized_500(list(status = 200L, body = list(ok = TRUE),
                               json_api_version = "1.0")))
expect_true(sanitized_500(list(stat = 500L, mesage = "db down")))
# a status that is not a number never reaches the status line (NA
# there is a malformed response every client drops)
expect_true(sanitized_500(list(status = "oops", body = list(a = 1))))
# headers: all named, single-line values (an unnamed one is a
# malformed head line, a CR/LF one is response splitting)
expect_true(sanitized_500(list(status = 200L, body = list(a = 1),
                               headers = c("no-cache"))))
expect_true(sanitized_500(list(
    status = 200L, body = list(a = 1),
    headers = c(Location = "/x\r\nSet-Cookie: sid=1"))))

# --- body decode edges: invalid UTF-8 reads NULL, a scalar top level
#     arrives as itself ---
expect_null(api_body(req("POST", "/x",
                         body = as.raw(c(0xff, 0xfe, 0x22)))))
expect_equal(api_body(req("POST", "/x", body = charToRaw("5"))), 5)
