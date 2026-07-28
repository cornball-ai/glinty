% tinyrox says don't edit this manually, but it can't stop you!
\name{send_custom_message}
\alias{send_custom_message}
\title{Send a message to app JavaScript}
\usage{
send_custom_message(session, handler, value = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{handler}{character handler name registered on the client}

\item{value}{the payload; anything jsonlite can serialize. Scalars
arrive unboxed, so TRUE becomes true rather than [true].}
}
\value{
invisible(NULL)
}
\description{
The server-to-browser escape hatch, and the counterpart of
Glinty.setInputValue(). The client looks up handler among those
registered with Glinty.addCustomMessageHandler() and calls it with
value; an unregistered name logs a console warning rather than
failing, since handlers register asynchronously.
}
\details{
The message is queued like any other and goes out on the next
flush. Registration order does not matter as long as the handler
exists by the time the message arrives -- register during the
glinty:connected event, which fires once per page load.

Browser-only: the handler is JavaScript, so a frontend that runs no
JavaScript has nothing to register.

}
\examples{
\dontrun{
# server
observe_event(input$stream_mode, {
    send_custom_message(session, "set_stream_mode", input$stream_mode())
})

# app JavaScript
# document.addEventListener("glinty:connected", function () {
#     Glinty.addCustomMessageHandler("set_stream_mode", function (on) {
#         streamMode = on;
#     });
# });
}
}
