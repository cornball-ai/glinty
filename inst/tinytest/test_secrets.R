check_page_secrets <- glinty:::check_page_secrets

# Env vars are process-global; restore whatever was there.
old <- Sys.getenv(c("GLINTY_TEST_API_KEY", "GLINTY_TEST_PLAIN",
                    "GLINTY_TEST_SHORT_TOKEN"), unset = NA)
Sys.setenv(GLINTY_TEST_API_KEY = "sk-abcdefghijklmnop1234")
Sys.setenv(GLINTY_TEST_PLAIN = "just-a-normal-setting-value")
Sys.setenv(GLINTY_TEST_SHORT_TOKEN = "abc")

# --- a secret in the page is found, by name only ---
page <- '<input type="password" value="sk-abcdefghijklmnop1234">'
hits <- env_secrets_in(page)
expect_true("GLINTY_TEST_API_KEY" %in% hits)
# the value itself is never returned, so the result is safe to print
expect_false(any(grepl("sk-abcdefghijklmnop1234", hits, fixed = TRUE)))

# --- a clean page reports nothing ---
expect_equal(length(env_secrets_in("<p>nothing to see here</p>")), 0L)
expect_equal(length(env_secrets_in("")), 0L)
expect_equal(length(env_secrets_in(character(0))), 0L)

# --- only secret-looking names are checked ---
# a variable whose value appears but whose name is unremarkable is not
# a finding: config values legitimately show up in pages
expect_false("GLINTY_TEST_PLAIN" %in%
             env_secrets_in("<p>just-a-normal-setting-value</p>"))

# --- short values are skipped, so trivial settings cannot false-alarm
expect_false("GLINTY_TEST_SHORT_TOKEN" %in% env_secrets_in("<p>abc</p>"))
# unless the caller asks for a lower floor
expect_true("GLINTY_TEST_SHORT_TOKEN" %in%
            env_secrets_in("<p>abc</p>", min_chars = 1L))

# --- the value is matched literally, not as a regex ---
Sys.setenv(GLINTY_TEST_REGEX_KEY = "abc.def[ghi]+xyz")
expect_true("GLINTY_TEST_REGEX_KEY" %in%
            env_secrets_in("<p>abc.def[ghi]+xyz</p>"))
# a string the value would match *as a pattern* is not a hit
expect_false("GLINTY_TEST_REGEX_KEY" %in%
             env_secrets_in("<p>abcXdefgggxyz</p>"))
Sys.unsetenv("GLINTY_TEST_REGEX_KEY")

# --- the page check stops rather than warning ---
# a warning at startup scrolls past and the app keeps serving
expect_error(check_page_secrets(page), "GLINTY_TEST_API_KEY")
expect_error(check_page_secrets(page), "readable by anyone")
# and never puts the secret in the message
err <- tryCatch(check_page_secrets(page), error = conditionMessage)
expect_false(grepl("sk-abcdefghijklmnop1234", err, fixed = TRUE))

expect_warning(check_page_secrets(page, strict = FALSE),
               "GLINTY_TEST_API_KEY")
expect_silent(check_page_secrets("<p>clean</p>"))

# --- password_input takes no value, so it cannot carry a secret ---
expect_false("value" %in% names(formals(password_input)))
pw <- password_input("api_key", "API Key:", placeholder = "using OPENAI_API_KEY")

expect_equal(pw$component, "password_input")
expect_false("value" %in% names(pw))
expect_equal(pw$placeholder, "using OPENAI_API_KEY")

# a page built with it is clean even while the secret is in the env
clean_page <- glinty:::component_to_html(page(password_input("k", "Key:")))
expect_equal(length(env_secrets_in(clean_page)), 0L)

# restore
for (nm in names(old)) {
    if (is.na(old[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv,
        stats::setNames(list(old[[nm]]), nm))
}
