% tinyrox says don't edit this manually, but it can't stop you!
\name{path_picker}
\alias{path_picker}
\title{A served file browser, from existing vocabulary}
\usage{
path_picker(
  session,
  input,
  id,
  kind = c("dir", "file"),
  root = NULL,
  start = NULL,
  shortcuts = NULL,
  title = NULL,
  pattern = NULL,
  hidden = FALSE,
  limit = 60L
)
}
\arguments{
\item{session}{a glinty_session}

\item{input}{the server function's input proxy}

\item{id}{character stem for the picker's event ids}

\item{kind}{"dir" to choose a directory, "file" to choose a file}

\item{root}{character topmost browsable directory, or NULL for the
whole filesystem}

\item{start}{character directory to open in; defaults to `root`,
else the working directory}

\item{shortcuts}{named character vector of labels to paths shown
above the tree, or a zero-arg function returning one, called at
each show; selecting one resolves the picker}

\item{title}{character dialog title, or NULL for a default named
by kind}

\item{pattern}{character regex shown files must match; directories
always show, or there is no way through them}

\item{hidden}{logical show dotfiles}

\item{limit}{integer most rows shown; the rest are counted in a
note -- step deeper to narrow down}
}
\value{
list(open = function(start = NULL), value = reactive_val)
}
\description{
Picks a directory or file on the machine running the server -- the
job \code{file_input()} cannot do, since a browser dialog browses
the client's disk and uploads contents rather than naming a server
path. The dialog is ordinary components in a modal: breadcrumbs
and one row per entry, every one a \code{button()} carrying its
target path as the value. Two observers serve all of it, split by
meaning: one id navigates (crumbs and directory rows), the other
commits a result (file rows, shortcuts, and the footer's confirm
button, which carries the on-screen directory).
}
\details{
Call once in the server function and keep the handle:
\code{open()} shows the dialog -- always; \code{start} says where
to open, never what to return -- and \code{value} is a
\code{reactive_val()} holding the chosen absolute path, NULL until
the user picks one. An explicit selection in the dialog is the
only writer. (Both halves are deliberate: a typed-path field that
short-circuits the dialog, combined with a picker that writes that
field back, is how a picker quietly disables itself after one
use.)

\code{shortcuts} are the places every real file dialog offers
beside the tree -- GTK calls them Places, macOS Favorites, editors
Recent. A named character vector of labels to paths, or a zero-arg
function returning one, called at each show so a recents list
stays current. Selecting one resolves the picker exactly as
choosing in the tree does: a shortcut names a \emph{result}, not a
place to browse (where to browse is \code{start}). Entries that do
not exist, do not match \code{kind}, or sit outside \code{root}
are left out of the dialog rather than rendered dead. A shortcut
is a visible control naming exactly what it opens; app state may
feed the list, but the picker never writes app state back.

Button values arrive from the client, so navigation trusts none of
them: every step is canonicalized and, when \code{root} is set,
refused if it leaves it -- which also refuses symlinks pointing
out. \code{root} is a browsing boundary, not the app's security
boundary (the input channel is same-origin, and any path input the
app offers elsewhere is as reachable): NULL browses the whole
filesystem, which is what a personal tool usually means, and a
deployment with a real boundary states one.

The picker binds \code{paste0(id, "_go")} and
\code{paste0(id, "_choose")} on the wire; leave those ids to it.

}
\examples{
\dontrun{
server <- function(input, output, session) {
    picker <- path_picker(session, input, "proj", kind = "dir")
    observe_event(input$open_project, function() picker$open())
    observe_event(picker$value, function(path) {
        open_project(path)
    })
}
}
}
