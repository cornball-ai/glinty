# The never-stomp contract extends to tree swaps (#79): a ui frame
# replacing a slot spares the focused field's draft. The rule is
# client behaviour -- nothing on the wire changes -- so the R side
# asserts the browser's capture/restore pair the way the keyboard and
# builder harnesses do: sliced out of the shipped glinty.js and driven
# under node. Skipped where node is absent; a development check, not
# an R CMD check requirement. The Flutter side of the same contract
# lives in dart/glinty_flutter/test/swap_draft_test.dart.

node <- Sys.which("node")
js_path <- system.file("www", "glinty.js", package = "glinty")
harness <- system.file("tinytest", "swap_client.js", package = "glinty")
if (nzchar(node) && nzchar(harness) && file.exists(harness)) {
    out <- suppressWarnings(system2(node, c(harness, js_path),
                                    stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status")
    expect_true(is.null(status) || identical(status, 0L),
                info = paste(out, collapse = "\n"))
    expect_true(any(grepl("^ok [0-9]+$", out)),
                info = paste(out, collapse = "\n"))
} else {
    exit_file("node not available")
}
