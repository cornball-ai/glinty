# Client-sized plots: responsive plot_output + clientdata-driven
# render_plot sizing.

tag_to_html <- getFromNamespace("tag_to_html", "glinty")

# --- plot_output shapes ---
po <- plot_output("p1")
html <- tag_to_html(po)
expect_true(grepl("width:100%", html, fixed = TRUE))
expect_true(grepl("aspect-ratio", html))
expect_false(grepl(' width="', html))
expect_false(grepl(' height="', html))

po2 <- plot_output("p2", width = 300L, height = 200L)
html2 <- tag_to_html(po2)
expect_true(grepl('width="300"', html2))
expect_true(grepl('height="200"', html2))
expect_false(grepl("style=", html2))

if (capabilities("png")) {
    .g <- getFromNamespace(".globals", "glinty")
    .g$current_context <- NULL
    .g$pending_flush <- list()
    .g$current_session <- NULL

    png_dims <- function(uri) {
        b64 <- sub("^data:image/png;base64,", "", uri)
        bytes <- jsonlite::base64_dec(b64)
        c(
            sum(as.integer(bytes[17:20]) * c(16777216, 65536, 256, 1)),
            sum(as.integer(bytes[21:24]) * c(16777216, 65536, 256, 1))
        )
    }
    last_uri <- function(s) {
        m <- jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])
        expect_equal(m$property, "src")
        m$value
    }

    s <- glinty:::new_session("cp1")

    # --- NULL dims fall back to 480x360 before the client reports ---
    glinty:::with_session(s, {
        s$output$plt <- render_plot(function() plot(1:5))
    })
    flush_reactions()
    expect_equal(png_dims(last_uri(s)), c(480, 360))

    # --- clientdata inputs drive the size, and resizing re-renders ---
    glinty:::handle_input(s, "..clientdata_output_plt_width", 640)
    glinty:::handle_input(s, "..clientdata_output_plt_height", 480)
    flush_reactions()
    expect_equal(png_dims(last_uri(s)), c(640, 480))

    n_before <- length(s$outgoing)
    glinty:::handle_input(s, "..clientdata_output_plt_width", 320)
    flush_reactions()
    expect_true(length(s$outgoing) > n_before)
    expect_equal(png_dims(last_uri(s)), c(320, 480))

    # --- explicit dims ignore clientdata ---
    glinty:::with_session(s, {
        s$output$fixed <- render_plot(function() plot(1:5),
            width = 400, height = 300)
    })
    flush_reactions()
    expect_equal(png_dims(last_uri(s)), c(400, 300))
    glinty:::handle_input(s, "..clientdata_output_fixed_width", 999)
    flush_reactions()
    expect_equal(png_dims(last_uri(s)), c(400, 300))

    # --- junk clientdata falls back rather than erroring ---
    s2 <- glinty:::new_session("cp2")
    glinty:::handle_input(s2, "..clientdata_output_j_width", "garbage")
    glinty:::with_session(s2, {
        s2$output$j <- render_plot(function() plot(1))
    })
    flush_reactions()
    expect_equal(png_dims(last_uri(s2)), c(480, 360))

    glinty:::session_end(s)
    glinty:::session_end(s2)
}
