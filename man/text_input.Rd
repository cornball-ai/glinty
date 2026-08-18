% tinyrox says don't edit this manually, but it can't stop you!
\name{text_input}
\alias{text_input}
\title{Create a text input}
\usage{
text_input(
  id,
  label = "",
  value = "",
  placeholder = NULL,
  emit = "live",
  clear_on = NULL
)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{character initial value}

\item{placeholder}{character placeholder text}

\item{emit}{character "live" to report while typing, "settle" to
report when the field is committed}

\item{clear_on}{character event id; when the client emits that
event it empties this field and reports "", after the event
frame, so the event's handler still reads the full draft. The
composer pattern: pair with a button or shortcut carrying the
named id. Requires emit = "live".}
}
\value{
A UI component
}
\description{
Create a text input
}
\examples{
text_input("name", "Name:")
}
