% tinyrox says don't edit this manually, but it can't stop you!
\name{conditional_panel}
\alias{conditional_panel}
\title{Show a panel only when a condition holds}
\usage{
conditional_panel(..., condition)
}
\arguments{
\item{...}{child elements}

\item{condition}{a condition from input_is() and friends}
}
\value{
A UI element
}
\description{
The client evaluates the condition against the inputs it already
tracks and toggles the panel's visibility. Nothing is destroyed or
rebuilt, so inputs inside a hidden panel keep their values and
still report to the server; only the display changes.
}
\details{
That is the difference from render_ui(), which rebuilds its
subtree on every change and resets any inputs inside it. Use
conditional_panel() to show and hide fixed content, and render_ui()
when the content itself is computed.

Conditions are built from input_is() and combined with cond_and(),
cond_or() and cond_not(). There is no JavaScript expression to
write and nothing is eval()ed.

Condition evaluation is a client capability. A frontend that does
not implement it renders the children always visible.

}
\examples{
conditional_panel(
    text_input("api_base", "API URL:"),
    condition = input_is("backend", "openai")
)

# show unless we are in qwen3 voice-design mode
conditional_panel(
    select_input("voice", "Voice:", c("a", "b")),
    condition = cond_not(cond_and(
        input_is("backend", "qwen3"),
        input_is("use_voice_design", TRUE)
    ))
)
}
