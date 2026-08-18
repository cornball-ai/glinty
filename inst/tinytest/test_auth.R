# The auth seam and the jwt_auth() batteries.

authenticate_hello <- glinty:::authenticate_hello
b64url_decode <- glinty:::b64url_decode
const_time_eq <- glinty:::const_time_eq

b64url <- function(raw) {
    # base64_enc line-wraps long input; a JWT segment never does
    x <- gsub("[\r\n]", "", jsonlite::base64_enc(raw))
    x <- chartr("+/", "-_", x)
    gsub("=", "", x, fixed = TRUE)
}
make_jwt <- function(claims, secret, header = list(alg = "HS256",
                                                   typ = "JWT")) {
    h <- b64url(charToRaw(jsonlite::toJSON(header, auto_unbox = TRUE)))
    p <- b64url(charToRaw(jsonlite::toJSON(claims, auto_unbox = TRUE)))
    signed <- paste(h, p, sep = ".")
    sig <- digest::hmac(key = secret, object = charToRaw(signed),
                        algo = "sha256", raw = TRUE)
    paste(signed, b64url(sig), sep = ".")
}

# --- the seam ---
# no verifier: everything in, no principal
gate <- authenticate_hello(NULL, list(type = "hello"))
expect_true(gate$ok)
expect_null(gate$principal)

# a verifier gets the token and its return becomes the principal
ver <- function(token) if (identical(token, "letmein")) list(id = "u1")
expect_true(authenticate_hello(ver, list(token = "letmein"))$ok)
expect_equal(authenticate_hello(ver, list(token = "letmein"))$principal$id,
             "u1")
expect_false(authenticate_hello(ver, list(token = "wrong"))$ok)
expect_false(authenticate_hello(ver, list())$ok)
# a verifier that errors refuses; failing open would make a bug in
# the verifier a bypass of it
boom <- function(token) stop("verifier crashed")
expect_false(authenticate_hello(boom, list(token = "x"))$ok)

# --- helpers ---
expect_identical(b64url_decode(b64url(as.raw(0:255))), as.raw(0:255))
expect_null(b64url_decode("not base64!!"))
expect_true(const_time_eq(as.raw(1:4), as.raw(1:4)))
expect_false(const_time_eq(as.raw(1:4), as.raw(c(1:3, 9))))
expect_false(const_time_eq(as.raw(1:4), as.raw(1:3)))

# --- jwt_auth: HS256 ---
secret <- "test-secret-please-ignore"
now <- as.numeric(Sys.time())
verify <- jwt_auth(secret = secret)

good <- make_jwt(list(sub = "u_123", email = "t@example.com",
                      exp = now + 600), secret)
claims <- verify(good)
expect_equal(claims$id, "u_123")
expect_equal(claims$sub, "u_123")
expect_equal(claims$email, "t@example.com")

# tampering with the payload kills the signature
parts <- strsplit(good, ".", fixed = TRUE)[[1L]]
evil <- b64url(charToRaw(jsonlite::toJSON(list(sub = "u_666",
                                               exp = now + 600),
                                          auto_unbox = TRUE)))
expect_null(verify(paste(parts[[1L]], evil, parts[[3L]], sep = ".")))

# wrong secret, malformed, wrong shape
expect_null(jwt_auth(secret = "other")(good))
expect_null(verify("not.a.jwt.at.all"))
expect_null(verify("onlytwoparts.here"))
expect_null(verify(""))
expect_null(verify(NULL))

# exp is required and enforced (with leeway)
expect_null(verify(make_jwt(list(sub = "u"), secret)))
expect_null(verify(make_jwt(list(sub = "u", exp = now - 120), secret)))
expect_equal(verify(make_jwt(list(sub = "u", exp = now - 10),
                             secret))$id, "u")

# nbf is enforced when present
expect_null(verify(make_jwt(list(sub = "u", exp = now + 600,
                                 nbf = now + 300), secret)))
expect_equal(verify(make_jwt(list(sub = "u", exp = now + 600,
                                  nbf = now - 5), secret))$id, "u")

# aud: checked when configured, string or array claim
aud_verify <- jwt_auth(secret = secret, aud = "glinty-app")
expect_equal(aud_verify(make_jwt(list(sub = "u", exp = now + 600,
                                      aud = "glinty-app"),
                                 secret))$id, "u")
expect_equal(aud_verify(make_jwt(list(sub = "u", exp = now + 600,
                                      aud = c("other", "glinty-app")),
                                 secret))$id, "u")
expect_null(aud_verify(make_jwt(list(sub = "u", exp = now + 600,
                                     aud = "someone-else"), secret)))
expect_null(aud_verify(make_jwt(list(sub = "u", exp = now + 600),
                                secret)))

# --- the configured algorithm is the law ---
# an alg:none token is refused without inspection
none <- paste(
    b64url(charToRaw('{"alg":"none","typ":"JWT"}')),
    b64url(charToRaw(jsonlite::toJSON(list(sub = "u", exp = now + 600),
                                      auto_unbox = TRUE))),
    "", sep = ".")
expect_null(verify(none))
# and a token claiming RS256 does not reach the HMAC path
rs_header <- make_jwt(list(sub = "u", exp = now + 600), secret,
                      header = list(alg = "RS256", typ = "JWT"))
expect_null(verify(rs_header))

# --- construction errors ---
expect_error(jwt_auth(), "secret")
expect_error(jwt_auth(secret = ""), "secret")
if (!requireNamespace("openssl", quietly = TRUE)) {
    expect_error(jwt_auth(algorithm = "RS256", pubkey = "x"), "openssl")
} else {
    expect_error(jwt_auth(algorithm = "RS256"), "pubkey")
    # a real RS256 round trip when openssl is here to do it
    key <- openssl::rsa_keygen(2048L)
    pub <- openssl::write_pem(key$pubkey)
    h <- b64url(charToRaw('{"alg":"RS256","typ":"JWT"}'))
    p <- b64url(charToRaw(jsonlite::toJSON(list(sub = "u_rs",
                                                exp = now + 600),
                                           auto_unbox = TRUE)))
    signed <- paste(h, p, sep = ".")
    sig <- openssl::signature_create(charToRaw(signed),
                                     hash = openssl::sha256, key = key)
    rs_token <- paste(signed, b64url(sig), sep = ".")
    rs_verify <- jwt_auth(pubkey = pub, algorithm = "RS256")
    expect_equal(rs_verify(rs_token)$id, "u_rs")
    # a different key refuses
    other <- openssl::write_pem(openssl::rsa_keygen(2048L)$pubkey)
    expect_null(jwt_auth(pubkey = other, algorithm = "RS256")(rs_token))
    # and an HS256 token signed with the PEM as its HMAC secret is
    # refused by alg pinning: the classic confusion attack
    hs_as_rs <- make_jwt(list(sub = "u", exp = now + 600), pub)
    expect_null(rs_verify(hs_as_rs))
}

# --- resolve_port ---
resolve_port <- glinty:::resolve_port
expect_equal(resolve_port(9999L), 9999L)
expect_error(resolve_port(0L), "port")
expect_error(resolve_port("nope"), "port")
old <- Sys.getenv(c("GLINTY_PORT", "PORT"), unset = NA)
Sys.setenv(GLINTY_PORT = "7777", PORT = "6666")
expect_equal(resolve_port(NULL), 7777L)
Sys.unsetenv("GLINTY_PORT")
expect_equal(resolve_port(NULL), 6666L)
Sys.setenv(PORT = "junk")
expect_error(resolve_port(NULL), "PORT")
Sys.unsetenv("PORT")
expect_equal(resolve_port(NULL), 8080L)
for (nm in names(old)) {
    if (!is.na(old[[nm]])) {
        do.call(Sys.setenv, as.list(stats::setNames(old[[nm]], nm)))
    }
}

# --- the first frame must be a well-formed hello ---
well_formed_hello <- glinty:::well_formed_hello
expect_true(well_formed_hello(list(type = "hello", protocol = 3L)))
expect_true(well_formed_hello(list(type = "hello", protocol = 3,
                                   token = "x", resume = "y")))
expect_false(well_formed_hello(NULL))
expect_false(well_formed_hello(list(type = "init", inputs = list())))
expect_false(well_formed_hello(list(type = "hello")))
expect_false(well_formed_hello(list(type = "hello", protocol = "three")))
expect_false(well_formed_hello("hello"))

# --- resume is principal-bound under auth ---
resume_allowed <- glinty:::resume_allowed
old <- new.env()
old$principal <- list(id = "u_1", email = "a@x")
same <- list(id = "u_1", exp = 999)
other <- list(id = "u_2")
anon <- list(email = "no-id@x")
verifier <- function(token) NULL
# without auth there is no identity to bind: session id remains the
# (documented, weak) resume credential
expect_true(resume_allowed(old, NULL, NULL))
# with auth, only the same identity resumes -- a valid token for
# user B plus user A's session id must not replay A's outputs
expect_true(resume_allowed(old, same, verifier))
expect_false(resume_allowed(old, other, verifier))
# principals without ids give resume nothing to bind to: refuse
expect_false(resume_allowed(old, anon, verifier))
anon_old <- new.env()
anon_old$principal <- list(email = "no-id@x")
expect_false(resume_allowed(anon_old, same, verifier))

# a verifier may return anything non-NULL, and glinty keeps it --
# so resume_allowed() must answer for scalars and vectors rather
# than erroring on them. No comparable id means no resume.
scalar_old <- new.env()
scalar_old$principal <- "u_1"
expect_false(resume_allowed(scalar_old, "u_1", verifier))
expect_false(resume_allowed(old, "u_1", verifier))
expect_false(resume_allowed(scalar_old, same, verifier))
expect_false(resume_allowed(old, c(id = "u_1"), verifier))
expect_false(resume_allowed(old, list(id = NULL), verifier))
expect_false(resume_allowed(old, list(id = c("u_1", "u_2")), verifier))
expect_false(resume_allowed(old, list(id = NA), verifier))
# an id that is numeric still compares, as its own string
num_old <- new.env()
num_old$principal <- list(id = 42L)
expect_true(resume_allowed(num_old, list(id = 42L), verifier))
expect_false(resume_allowed(num_old, list(id = 43L), verifier))

# --- the ticket cap answers instead of dropping ---
scap <- glinty:::new_session("capmsg")
for (i in seq_len(64L)) {
    glinty:::issue_ticket(scap, paste0("r", i), "upload")
}
scap$outgoing <- list()
glinty:::dispatch_client_message(scap,
    '{"type":"ticket","id":"dataset","purpose":"upload"}')
expect_equal(length(scap$outgoing), 1L)
capmsg <- jsonlite::fromJSON(scap$outgoing[[1L]])
# A refusal answers on the channel the request was made on, carrying
# `error` where a grant carries `token`. It was an `error` frame
# once, which made that message mean two unrelated things -- a
# renderer failed, and your transfer was refused -- and left the two
# clients disagreeing about which element an id referred to.
expect_equal(capmsg$type, "ticket")
expect_equal(capmsg$id, "dataset")
expect_equal(capmsg$purpose, "upload")
expect_true(grepl("pending transfers", capmsg$error))
# and it is a refusal, not a grant: no credential comes with it
expect_null(capmsg$token)
expect_null(capmsg$expires)
glinty:::session_end(scap)

# --- ticket tokens come from a CSPRNG and never repeat ---
random_bytes <- glinty:::random_bytes
b <- random_bytes(16L)
expect_true(is.raw(b) && length(b) == 16L)
expect_false(identical(random_bytes(16L), random_bytes(16L)))
toks <- replicate(200L, glinty:::new_ticket_token())
expect_equal(anyDuplicated(toks), 0L)
expect_true(all(grepl("^tk_[0-9a-f]{32}$", toks)))

# --- live tickets are capped per session, within the TTL ---
sc <- glinty:::new_session("cap1")
sc2 <- glinty:::new_session("cap2")
issue_ticket <- glinty:::issue_ticket
granted <- 0L
for (i in seq_len(80L)) {
    if (!is.null(issue_ticket(sc, paste0("r", i), "upload"))) {
        granted <- granted + 1L
    }
}
expect_equal(granted, 64L)
# the cap is per session: another session still mints
expect_false(is.null(issue_ticket(sc2, "r", "upload")))
# and redemption frees a slot
tks <- ls(getFromNamespace(".globals", "glinty")$tickets,
          all.names = TRUE)
mine <- Filter(function(tk) {
    identical(getFromNamespace(".globals", "glinty")$tickets[[tk]]$session_id,
              "cap1")
}, tks)
glinty:::redeem_ticket(mine[[1L]], "upload")
expect_false(is.null(issue_ticket(sc, "again", "upload")))
glinty:::session_end(sc)
glinty:::session_end(sc2)

# --- two-argument verifiers see the upgrade request (#73) ---
# The cookie rides the upgrade request's headers; the hello has no
# token at all. This is the HttpOnly-cookie shape: page script never
# held a credential to send.
seen <- NULL
ver2 <- function(token, req) {
    seen <<- req
    if (identical(unname(req$headers[["cookie"]]), "session=abc")) {
        list(id = "cookie-user")
    }
}
upreq <- list(method = "GET", path = "/ws", query = "",
              headers = c(cookie = "session=abc", host = "localhost"))
gate <- authenticate_hello(ver2, list(type = "hello"), upreq)
expect_true(gate$ok)
expect_equal(gate$principal$id, "cookie-user")
expect_equal(unname(seen$headers[["cookie"]]), "session=abc")
# a wrong cookie refuses, same as a wrong token always has
bad <- list(method = "GET", path = "/ws", query = "",
            headers = c(cookie = "session=nope"))
expect_false(authenticate_hello(ver2, list(type = "hello"), bad)$ok)
# a one-argument verifier is untouched by the new context
ver1 <- function(token) if (identical(token, "t")) list(id = "u1")
expect_true(authenticate_hello(ver1, list(token = "t"), upreq)$ok)
# no surviving request (nothing stashed): a two-arg verifier gets NULL
# and can still decide on the token alone
ver_both <- function(token, req) {
    if (is.null(req) && identical(token, "t")) list(id = "n")
}
expect_true(authenticate_hello(ver_both, list(token = "t"), NULL)$ok)

# --- upgrade_request_for: the registry keeps the parsed head ---
upgrade_request_for <- glinty:::upgrade_request_for
glinty:::reg_reset()
entry <- new.env(parent = emptyenv())
entry$upgrade_req <- upreq
reg <- glinty:::REG
reg$conns[["c1"]] <- entry
reg$sessions[["s1"]] <- "c1"
expect_equal(upgrade_request_for("s1")$path, "/ws")
expect_equal(unname(upgrade_request_for("s1")$headers[["cookie"]]),
             "session=abc")
expect_null(upgrade_request_for("no-such-session"))
glinty:::reg_reset()

# --- run_app validates auth ---
a <- app(ui = page(txt("x"), title = "T"),
         server = function(input, output) NULL)
expect_error(run_app(a, auth = "not a function"), "auth must be")