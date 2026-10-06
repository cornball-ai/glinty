# Outputs behind a hidden tab panel wait, and render once when the
# panel opens. Driven in-process: a session with the panel map
# run_app() would give it, the tabset input seeded as the tree says.

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL
.g$timers <- list()

new_session <- glinty:::new_session
session_end <- glinty:::session_end
with_session <- glinty:::with_session
handle_input <- glinty:::handle_input
seed_session_inputs <- glinty:::seed_session_inputs
output_panels <- glinty:::output_panels
panel_env <- glinty:::panel_env
run_due_timers <- glinty:::run_due_timers

ids_sent <- function(s) {
    vapply(s$outgoing, function(m) {
        j <- jsonlite::fromJSON(m)
        if (identical(j$type, "output")) j$id else ""
    }, character(1L))
}

ui <- page(
    text_output("top"),
    tabset(
        tab_panel("A", text_output("a"), ui_output("dyn_a")),
        tab_panel("B",
                  text_output("b"),
                  ui_output("dyn"),
                  tabset(tab_panel("C", text_output("c")),
                         tab_panel("D", text_output("d")),
                         id = "inner", selected = "D")),
        id = "tabs"
    )
)

# --- the map: which panels enclose each id ---
m <- output_panels(ui)
expect_null(m$top)
expect_equal(m$a, list(list(tabset = "tabs", panel = "A")))
expect_equal(m$b, list(list(tabset = "tabs", panel = "B")))
expect_equal(m$c, list(list(tabset = "tabs", panel = "B"),
                       list(tabset = "inner", panel = "C")))
expect_equal(m$d[[2L]]$panel, "D")
# the inner tabset itself sits in panel B
expect_equal(m$inner, list(list(tabset = "tabs", panel = "B")))
expect_equal(output_panels(txt("x")), list())
# the unclassed wire form maps the same
expect_equal(output_panels(glinty:::unclass_recursive(ui)), m)
# a base is inherited, the way a dynamic subtree inherits its slot's
expect_equal(output_panels(text_output("z"), base = m$b)$z, m$b)

# --- a session: only the open panels' outputs render ---
s <- new_session("sp1")
seed_session_inputs(s, ui)
s$panel_of <- panel_env(ui)
expect_equal(s$input$tabs(), "A")
expect_equal(s$input$inner(), "D")

n <- new.env()
for (k in c("top", "a", "b", "c", "d", "dyn", "dyn_a", "inner_out")) n[[k]] <- 0L
rv <- reactive_val(0)
counting <- function(k, fn) {
    render_text(function() {
        n[[k]] <- n[[k]] + 1L
        fn()
    })
}
with_session(s, {
    s$output$top <- counting("top", function() "top")
    s$output$a <- counting("a", function() paste("a", rv()))
    s$output$b <- counting("b", function() {
        invalidate_later(50)
        "b"
    })
    s$output$c <- counting("c", function() "c")
    s$output$d <- counting("d", function() "d")
    s$output$dyn <- render_ui(function() {
        n$dyn <- n$dyn + 1L
        column(text_output("inner_out"))
    })
    s$output$dyn_a <- render_ui(function() {
        n$dyn_a <- n$dyn_a + 1L
        NULL
    })
    s$output$inner_out <- counting("inner_out", function() paste("in", rv()))
})
flush_reactions()
expect_equal(n$top, 1L)
expect_equal(n$a, 1L)
expect_equal(n$dyn_a, 1L)
expect_equal(n$b, 0L)
expect_equal(n$c, 0L)
expect_equal(n$d, 0L)
expect_equal(n$dyn, 0L)
# inner_out is not in the static tree, so nothing hides it yet
expect_equal(n$inner_out, 1L)
expect_true(all(c("top", "a", "inner_out") %in% ids_sent(s)))
expect_false("b" %in% ids_sent(s))
# b's timer was never armed, because b never ran
expect_equal(length(.g$timers), 0L)

# a hidden output's inputs changing costs nothing
s$outgoing <- list()
rv(1)
flush_reactions()
expect_equal(n$a, 2L)
expect_equal(n$b, 0L)

# open B: b renders once, d (inner's open panel) renders, c waits
s$outgoing <- list()
handle_input(s, "tabs", "B")
flush_reactions()
expect_equal(n$b, 1L)
expect_equal(n$d, 1L)
expect_equal(n$c, 0L)
expect_equal(n$dyn, 1L)
# a's observer re-ran on the tabset change, saw it was hidden, and
# did not render
expect_equal(n$a, 2L)
expect_true(all(c("b", "d", "dyn") %in% ids_sent(s)))
expect_false("a" %in% ids_sent(s))
# b armed its timer now that it rendered
expect_equal(length(.g$timers), 1L)

# the inner tabset: open C
handle_input(s, "inner", "C")
flush_reactions()
expect_equal(n$c, 1L)
expect_equal(n$d, 1L)

# back to A: a re-renders once, with the value it missed; b's timer
# fires once more and is not re-armed while hidden
s$outgoing <- list()
handle_input(s, "tabs", "A")
flush_reactions()
expect_equal(n$a, 3L)
expect_true(grepl('"a 1"', s$outgoing[[tail(which(ids_sent(s) == "a"), 1L)]],
                  fixed = TRUE))
expect_equal(n$b, 1L)
expect_equal(length(.g$timers), 1L)
run_due_timers(now = glinty:::timer_now() + 10)
flush_reactions()
expect_equal(n$b, 1L)
expect_equal(length(.g$timers), 0L)

# the dynamic subtree's output now lives in panel B. It rendered
# twice while nothing hid it (the first flush, then rv(1)); now its
# input changing while A is open costs nothing, and it renders when
# B opens
expect_equal(n$inner_out, 2L)
rv(2)
flush_reactions()
expect_equal(n$a, 4L)
expect_equal(n$inner_out, 2L)
s$outgoing <- list()
handle_input(s, "tabs", "B")
flush_reactions()
expect_equal(n$inner_out, 3L)
# the slot's re-render replays inner_out's last state and the fresh
# render follows (or precedes it, in which case the replay carries
# the fresh value): either way the client ends current
expect_true(grepl('"in 2"',
                  s$outgoing[[tail(which(ids_sent(s) == "inner_out"), 1L)]],
                  fixed = TRUE))
expect_equal(n$b, 2L)

# a dynamic render that drops an output stops gating it
with_session(s, {
    s$output$dyn <- render_ui(function() {
        n$dyn <- n$dyn + 1L
        column(text_output("other"))
    })
})
flush_reactions()
expect_null(s$panel_of[["inner_out"]])
expect_equal(s$panel_of[["other"]], list(list(tabset = "tabs", panel = "B")))
session_end(s)

# --- a session with no map renders everything, as before ---
s2 <- new_session("sp2")
seed_session_inputs(s2, ui)
k <- 0L
with_session(s2, {
    s2$output$b <- render_text(function() {
        k <<- k + 1L
        "b"
    })
})
flush_reactions()
expect_equal(k, 1L)
session_end(s2)

# --- a tabset whose selection is unknown hides nothing ---
s3 <- new_session("sp3")
s3$panel_of <- panel_env(ui)
k3 <- 0L
with_session(s3, {
    s3$output$c <- render_text(function() {
        k3 <<- k3 + 1L
        "c"
    })
})
flush_reactions()
expect_equal(k3, 1L)
session_end(s3)
.g$timers <- list()
