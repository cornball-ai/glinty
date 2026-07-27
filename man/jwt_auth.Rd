% tinyrox says don't edit this manually, but it can't stop you!
\name{jwt_auth}
\alias{jwt_auth}
\title{Verify JSON Web Tokens in run_app(auth = )}
\usage{
jwt_auth(secret = NULL, pubkey = NULL, algorithm = c("HS256", "RS256"),
         aud = NULL, leeway = 30)
}
\arguments{
\item{secret}{character HMAC secret, for HS256}

\item{pubkey}{an RSA public key for RS256: a PEM string, a file
path, or an openssl key object}

\item{algorithm}{"HS256" or "RS256"}

\item{aud}{character expected audience, or NULL to skip the check}

\item{leeway}{numeric seconds of clock slack for exp/nbf}
}
\value{
a function(token) suitable for run_app(auth = )
}
\description{
Returns a verifier for `run_app(auth = )` that checks a JWT's
signature, `exp` (required), `nbf` (when present) and `aud` (when
`aud` is configured), then returns the claims with `sub` copied to
`id`. A token that fails any check refuses the connection.
}
\details{
The configured algorithm is the law: a token whose header claims a
different `alg` is refused without further inspection, which is
what closes the classic algorithm-confusion hole.

HS256 uses digest's HMAC, RS256 uses openssl; both are Imports, so
neither costs an install. Fetching and caching a JWKS is the app's
job; hand the chosen key in as `pubkey`.

}
\examples{
\dontrun{
run_app(app_obj,
        auth = jwt_auth(secret = Sys.getenv("SUPABASE_JWT_SECRET")))
}
}
