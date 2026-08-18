% tinyrox says don't edit this manually, but it can't stop you!
\name{textarea_input}
\alias{textarea_input}
\title{Create a multi-line text input}
\usage{
textarea_input(
  id,
  label = "",
  value = "",
  rows = 4L,
  placeholder = NULL,
  emit = "live",
  clear_on = NULL
)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{character initial value}

\item{rows}{integer visible rows}

\item{placeholder}{character placeholder text}

\item{emit}{character "live" or "settle"}

\item{clear_on}{character event id; when the client emits that
event it empties this field and reports "", after the event
frame, so the event's handler still reads the full draft. The
chat composer: \code{textarea_input("draft", clear_on = "send")}
beside \code{shortcut("send", "enter", typing = TRUE)}. Requires
emit = "live".}
}
\value{
A UI component
}
\description{
Create a multi-line text input
}
\examples{
textarea_input("notes", "Notes:", rows = 6L)
}
