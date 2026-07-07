% tinyrox says don't edit this manually, but it can't stop you!
\name{run_app_native}
\alias{run_app_native}
\title{Run a glinty application in a native window}
\usage{
run_app_native(app_obj, width = 800L, height = 600L, quiet = FALSE)
}
\arguments{
\item{app_obj}{a glinty_app object}

\item{width}{integer window width in logical pixels}

\item{height}{integer window height in logical pixels}

\item{quiet}{logical suppress the startup message}
}
\value{
invisible(NULL); runs until the window closes
}
\description{
Renders the app with flitR (the Flutter Engine) instead of a
browser. The reactive core, sessions, and wire protocol are the
same as run_app(): the native window is simply another client of
the update messages. Requires the flitR package with its engine
installed (flitR::install_engine()), and a display.
}
\details{
Supported UI subset: headings, p/span/a text, text_input, button,
checkbox_input, slider_input (step is ignored), text_output, and
plot_output via flitR's image op. Unsupported widgets fail fast
with a list. update_* label and choices changes are ignored
natively.

}
\examples{
\dontrun{
run_app_native(app_obj)
}
}
