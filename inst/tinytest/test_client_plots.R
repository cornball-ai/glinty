# Client-sized plots: responsive plot_output + measure-driven
# render_plot sizing, with device pixel ratio.

component_to_html <- getFromNamespace("component_to_html", "glinty")
handle_measure <- glinty:::handle_measure
measured_box <- glinty:::measured_box

# --- plot_output shapes ---
po <- plot_output("p1")
html <- component_to_html(po)
expect_true(grepl("width:100%", html, fixed = TRUE))
expect_true(grepl("aspect-ratio", html))
expect_false(grepl(' width="', html))
expect_false(grepl(' height="', html))

po2 <- plot_output("p2", width = 300L, height = 200L)
html2 <- component_to_html(po2)
expect_true(grepl('width="300"', html2))
expect_true(grepl('height="200"', html2))
expect_false(grepl("style=", html2))

# --- handle_measure validates and stores; last write wins ---
sm <- glinty:::new_session("cpm")
handle_measure(sm, list(id = "plt", width = 640, height = 480))
box <- isolate(measured_box(sm, "plt"))
expect_equal(box$width, 640)
expect_equal(box$height, 480)
expect_equal(box$dpr, 1)

handle_measure(sm, list(id = "plt", width = 800, height = 600, dpr = 2))
box <- isolate(measured_box(sm, "plt"))
expect_equal(box$width, 800)
expect_equal(box$dpr, 2)

# zero is the absence of a size, not a size; junk is junk
handle_measure(sm, list(id = "plt", width = 0, height = 600))
expect_equal(isolate(measured_box(sm, "plt"))$width, 800)
handle_measure(sm, list(id = "plt", width = "soup", height = 600))
expect_equal(isolate(measured_box(sm, "plt"))$width, 800)
handle_measure(sm, list(id = "plt", width = 640, height = 480, dpr = 900))
expect_equal(isolate(measured_box(sm, "plt"))$dpr, 2)

# resource caps: a measurement sizes a raster, so combinations that
# pass per-field checks but explode physically are refused wholesale
handle_measure(sm, list(id = "plt", width = 100000, height = 100000,
                        dpr = 16))
expect_equal(isolate(measured_box(sm, "plt"))$width, 800)
handle_measure(sm, list(id = "plt", width = 8192, height = 8192))
expect_equal(isolate(measured_box(sm, "plt"))$width, 800)
handle_measure(sm, list(id = "plt", width = 4000, height = 4000, dpr = 4))
expect_equal(isolate(measured_box(sm, "plt"))$width, 800)
# while a real dense-display fullscreen passes
handle_measure(sm, list(id = "plt", width = 2560, height = 1440, dpr = 2))
expect_equal(isolate(measured_box(sm, "plt"))$width, 2560)

# a measurement for an id with no renderer is stored and harmless
handle_measure(sm, list(id = "future", width = 100, height = 50))
expect_equal(isolate(measured_box(sm, "future"))$width, 100)

# ...but bounded: invented ids stop accumulating at the cap, while
# ids that already have a slot keep updating
for (i in seq_len(300L)) {
    handle_measure(sm, list(id = paste0("spray", i), width = 10,
                            height = 10))
}
expect_true(length(ls(sm$measures)) <= 256L)
expect_null(isolate(measured_box(sm, "spray300")))
handle_measure(sm, list(id = "plt", width = 640, height = 480))
expect_equal(isolate(measured_box(sm, "plt"))$width, 640)

# measurements are session state, off the input channel entirely
expect_null(isolate(sm$input$plt()))
glinty:::session_end(sm)

# --- the input channel refuses ..-prefixed ids (spoof guard) ---
sg <- glinty:::new_session("cpg")
glinty:::dispatch_client_message(sg,
    '{"type":"input","id":"..clientdata_output_x_width","value":9}')
expect_null(isolate(sg$input[["..clientdata_output_x_width"]]()))
glinty:::session_end(sg)

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
    last_image <- function(s) {
        m <- jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])
        expect_equal(m$type, "output")
        expect_equal(m$kind, "image")
        m$value
    }

    s <- glinty:::new_session("cp1")

    # --- NULL dims fall back to 480x360 before the client reports ---
    glinty:::with_session(s, {
        s$output$plt <- render_plot(function() plot(1:5))
    })
    flush_reactions()
    v <- last_image(s)
    expect_equal(png_dims(v$src), c(480, 360))
    expect_equal(c(v$width, v$height), c(480, 360))

    # --- measure drives the size, and re-measuring re-renders ---
    handle_measure(s, list(id = "plt", width = 640, height = 480))
    flush_reactions()
    expect_equal(png_dims(last_image(s)$src), c(640, 480))

    n_before <- length(s$outgoing)
    handle_measure(s, list(id = "plt", width = 320, height = 480))
    flush_reactions()
    expect_true(length(s$outgoing) > n_before)
    expect_equal(png_dims(last_image(s)$src), c(320, 480))

    # --- dpr scales the raster, never the reported logical size ---
    handle_measure(s, list(id = "plt", width = 320, height = 240, dpr = 2))
    flush_reactions()
    v <- last_image(s)
    expect_equal(png_dims(v$src), c(640, 480))
    expect_equal(c(v$width, v$height), c(320, 240))

    # --- explicit dims win on size, but dpr still applies: a fixed ---
    # --- plot on a dense display must not stay blurry ---
    glinty:::with_session(s, {
        s$output$fixed <- render_plot(function() plot(1:5),
            width = 400, height = 300)
    })
    flush_reactions()
    v <- last_image(s)
    expect_equal(png_dims(v$src), c(400, 300))
    handle_measure(s, list(id = "fixed", width = 999, height = 999,
                           dpr = 2))
    flush_reactions()
    v <- last_image(s)
    # the measured size is ignored, the measured density is not
    expect_equal(png_dims(v$src), c(800, 600))
    expect_equal(c(v$width, v$height), c(400, 300))

    glinty:::session_end(s)
}
