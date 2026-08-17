# Serve for the Flutter web viewer on :8492 (see 01-hello/serve.R).
a <- source("app.R")$value
viewer_hosts <- c("localhost", "127.0.0.1", "troy-ai", "100.124.216.121")
glinty::run_app(a, port = 8496L,
    origins = paste0("http://", viewer_hosts, ":8492"))
