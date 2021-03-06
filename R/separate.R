#' Separate one column into multiple columns.
#'
#' Given either regular expression or a vector of character positions,
#' `separate()` turns a single character column into multiple columns.
#'
#' @inheritParams extract
#' @param into Names of new variables to create as character vector.
#' @param sep Separator between columns.
#'
#'   If character, is interpreted as a regular expression. The default
#'   value is a regular expression that matches any sequence of
#'   non-alphanumeric values.
#'
#'   If numeric, interpreted as positions to split at. Positive values start
#'   at 1 at the far-left of the string; negative value start at -1 at the
#'   far-right of the string. The length of `sep` should be one less than
#'   `into`.
#' @param extra If `sep` is a character vector, this controls what
#'   happens when there are too many pieces. There are three valid options:
#'
#'   * "warn" (the default): emit a warning and drop extra values.
#'   * "drop": drop any extra values without a warning.
#'   * "merge": only splits at most `length(into)` times
#' @param fill If `sep` is a character vector, this controls what
#'   happens when there are not enough pieces. There are three valid options:
#'
#'   * "warn" (the default): emit a warning and fill from the right
#'   * "right": fill with missing values on the right
#'   * "left": fill with missing values on the left
#' @param remove If `TRUE`, remove input column from output data frame.
#' @param convert If `TRUE`, will run [type.convert()] with
#'   `as.is = TRUE` on new columns. This is useful if the component
#'   columns are integer, numeric or logical.
#' @param ... Defunct, will be removed in the next version of the package.
#' @seealso [unite()], the complement.
#' @export
#' @examples
#' library(dplyr)
#' df <- data.frame(x = c(NA, "a.b", "a.d", "b.c"))
#' df %>% separate(x, c("A", "B"))
#'
#' # If every row doesn't split into the same number of pieces, use
#' # the extra and file arguments to control what happens
#' df <- data.frame(x = c("a", "a b", "a b c", NA))
#' df %>% separate(x, c("a", "b"))
#' # The same behaviour but no warnings
#' df %>% separate(x, c("a", "b"), extra = "drop", fill = "right")
#' # Another option:
#' df %>% separate(x, c("a", "b"), extra = "merge", fill = "left")
#'
#' # If only want to split specified number of times use extra = "merge"
#' df <- data.frame(x = c("x: 123", "y: error: 7"))
#' df %>% separate(x, c("key", "value"), ": ", extra = "merge")
separate <- function(data, col, into, sep = "[^[:alnum:]]+", remove = TRUE,
                     convert = FALSE, extra = "warn", fill = "warn", ...) {
  UseMethod("separate")
}
#' @export
separate.default <- function(data, col, into, sep = "[^[:alnum:]]+",
                             remove = TRUE, convert = FALSE,
                             extra = "warn", fill = "warn", ...) {
  col <- compat_as_lazy(enquo(col))
  separate_(data,
    col = col,
    into = into,
    sep = sep,
    remove = remove,
    convert = convert,
    extra = extra,
    fill = fill,
    ...
  )
}
#' @export
separate.data.frame <- function(data, col, into, sep = "[^[:alnum:]]+",
                                remove = TRUE, convert = FALSE,
                                extra = "warn", fill = "warn", ...) {
  orig <- data

  var <- tidyselect::vars_pull(names(data), !! enquo(col))
  value <- as.character(data[[var]])

  if (length(list(...)) != 0) {
    warn("Using ... for passing arguments to `strsplit()` is defunct")
  }

  if (is.numeric(sep)) {
    l <- strsep(value, sep)
  } else if (is_character(sep)) {
    l <- str_split_fixed(value, sep, length(into), extra = extra, fill = fill)
  } else {
    abort("`sep` must be either numeric or character")
  }

  names(l) <- as_utf8_character(into)
  if (convert) {
    l[] <- map(l, type.convert, as.is = TRUE)
  }

  # Insert into existing data frame
  data <- append_df(data, l, match(var, dplyr::tbl_vars(data)))
  if (remove) {
    data[[var]] <- NULL
  }

  reconstruct_tibble(orig, data, if (remove) var else NULL)
}

strsep <- function(x, sep) {
  sep <- c(0, sep, -1)

  nchar <- stringi::stri_length(x)
  pos <- map(sep, function(i) {
    if (i >= 0) return(i)
    nchar + i + 1
  })

  map(1:(length(pos) - 1), function(i) {
    stringi::stri_sub(x, pos[[i]] + 1, pos[[i + 1]])
  })
}
str_split_fixed <- function(value, sep, n, extra = "warn", fill = "warn") {
  if (extra == "error") {
    warn(glue(
      "`extra = \"error\"` is deprecated. \\
       Please use `extra = \"warn\"` instead"
    ))
    extra <- "warn"
  }

  extra <- arg_match(extra, c("warn", "merge", "drop"))
  fill <- arg_match(fill, c("warn", "left", "right"))

  n_max <- if (extra == "merge") n else -1L
  pieces <- stringi::stri_split_regex(value, sep, n_max)

  simp <- simplifyPieces(pieces, n, fill == "left")

  n_big <- length(simp$too_big)
  if (extra == "warn" && n_big > 0) {
    idx <- list_indices(simp$too_big)
    warn(glue("Too many values at {n_big} locations: {idx}"))
  }

  n_sml <- length(simp$too_sml)
  if (fill == "warn" && n_sml > 0) {
    idx <- list_indices(simp$too_sml)
    warn(glue("Too few values at {n_sml} locations: {idx}"))
  }

  simp$strings
}


#' @rdname deprecated-se
#' @inheritParams separate
#' @export
separate_ <- function(data, col, into, sep = "[^[:alnum:]]+", remove = TRUE,
                      convert = FALSE, extra = "warn", fill = "warn", ...) {
  UseMethod("separate_")
}
#' @export
separate_.data.frame <- function(data, col, into, sep = "[^[:alnum:]]+",
                                 remove = TRUE, convert = FALSE,
                                 extra = "warn", fill = "warn", ...) {
  col <- compat_lazy(col, caller_env())
  separate(data,
    col = !! col,
    into = into,
    sep = sep,
    remove = remove,
    convert = convert,
    extra = extra,
    fill = fill,
    ...
  )
}
