% tinyrox says don't edit this manually, but it can't stop you!
\name{tag}
\alias{tag}
\title{Generic tag constructor}
\usage{
tag(name, children = list(), text = NULL, attrs = list(), bind = NULL)
}
\arguments{
\item{name}{character tag name (e.g. "div", "button")}

\item{children}{list of child tags}

\item{text}{character text content (takes precedence over children)}

\item{attrs}{named list of HTML attributes}

\item{bind}{list with event and target fields for JS event
binding, plus an optional value field. A click bind with a value
sets the input to that value instead of bumping an
action-button counter, which is how one delegated handler
serves a list of rows: every row targets the same input and
reports which one was clicked.}
}
\value{
A tag list with class "glinty_tag"
}
\description{
The extensibility contract: any element with an id, a
data-g-event, and a data-g-target (via bind) is a glinty input;
any element with an id can be an output target. Custom widgets are
plain R functions returning tag() trees.
}
\examples{
tag("input",
    attrs = list(id = "col", type = "color"),
    bind = list(event = "input", target = "col"))

# a clickable row reporting its own id
tag("div", text = "Entry 3",
    bind = list(event = "click", target = "row_click", value = "id-3"))
}
