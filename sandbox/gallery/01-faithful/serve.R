# Serve the faithful port for the Flutter web viewer. The viewer page
# is served from :8492, so its Origin differs from this server's
# host:port and the #49 same-host default would refuse it -- exactly
# what run_app(origins = ) is for.
a <- source("app.R")$value
viewer_hosts <- c("localhost", "127.0.0.1", "troy-ai", "100.124.216.121")
glinty::run_app(a, port = 8490L,
    origins = paste0("http://", viewer_hosts, ":8492"))
