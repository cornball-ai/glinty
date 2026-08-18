# The loop's current app always serves on 8490; the Flutter web
# viewer on 8492 connects to it. One app at a time owns the port.
a <- source("app.R")$value
viewer_hosts <- c("localhost", "127.0.0.1", "troy-ai", "100.124.216.121")
glinty::run_app(a, port = 8490L,
    origins = paste0("http://", viewer_hosts, ":8492"))
