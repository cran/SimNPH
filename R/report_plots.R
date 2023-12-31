#' Functions for Plotting and Reporting Results
#'
#' @describeIn results_pivot_longer pivot simulation results into long format
#'
#' @param data for results_pivot_longer: simulation result as retured by SimDesign
#' @param exclude_from_methods "methods" that should not be pivoted into long format
#'
#' @return dataset in long format with one row per method and scenario and one
#'   column per metric
#'
#' @details With `exclude_from_methods` descriptive statistics or results of
#'   reference methods can be kept as own columns and used like the columns of
#'   the simulation parameters.
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("combination_tests_delayed")
#'
#' combination_tests_delayed |>
#'   results_pivot_longer() |>
#'   head()
#' }
results_pivot_longer <- function(data, exclude_from_methods=c("descriptive")){
  # delete potentially huge attributes that are not needed for plots
  attr(data, "ERROR_msg")    <- NULL
  attr(data, "WARNING_msg")  <- NULL
  attr(data, "extra_info")   <- NULL

  methods <- attr(data, "design_names") |>
    getElement("sim") |>
    stringr::str_extract(".*(?=\\.[^\\d])")

  summaries <- attr(data, "design_names") |>
    getElement("sim") |>
    stringr::str_remove(stringr::str_c(methods, "."))

  include <- !(methods %in% exclude_from_methods)

  pivot_spec <- tibble::tibble(
    .name=attr(data, "design_names")$sim[include],
    .value=summaries[include],
    method=methods[include]
    )

  result <- data |>
    dplyr::rename_with(
      .fn = \(name){rep("n_pat_design", length(name))},
      .cols=dplyr::any_of("n_pat")
    ) |>
    tidyr::pivot_longer_spec(pivot_spec)
}

order_combine_xvars <- function(data, xvars, facet_vars=c(), height_x_axis=0.8, grid_level=2){

  result <- data |>
    dplyr::arrange(!!!xvars) |>
    tidyr::unite(x, !!!xvars, remove=FALSE) |>
    dplyr::mutate(
      x = factor(x, levels=unique(x))
    )

  x_axis <- result |>
    dplyr::select(x, !!!xvars, !!!facet_vars) |>
    unique() |>
    tidyr::pivot_longer(cols=c(-x, -dplyr::any_of(facet_vars))) |>
    dplyr::group_by(name) |>
    dplyr::mutate(
      y=(as.integer(as.factor(value))-1) / (length(unique(value))-1)
    ) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      level = match(name, xvars),
      y = level - (y*height_x_axis) - (0.5 * (1-height_x_axis))
    )

  x_axis_labels <- x_axis |>
    dplyr::group_by(name) |>
    dplyr::summarise(
      level=dplyr::first(level),
      label=stringr::str_c(dplyr::first(name), ": ", stringr::str_c(unique(value), collapse=", "))
    )

  x_axis_breaks <- result |>
    dplyr::select(!!!xvars[1:grid_level], x) |>
    dplyr::group_by(!!!xvars[1:grid_level]) |>
    dplyr::filter(1:dplyr::n() == 1) |>
    dplyr::pull(x)

  attr(result, "x_axis") <- x_axis
  attr(result, "x_labels") <- x_axis_labels
  attr(result, "x_axis_breaks") <- x_axis_breaks
  result
}

#' @describeIn results_pivot_longer Nested Loop Plot with optional Facets
#'
#' @param data for combined_plto simulation results in long format, as returned by `results_pivot_longer`.
#' @param methods methods to include in the plot
#' @param xvars orderd vector of variable names to display on the x axis
#' @param yvar variable name of the variable to be displayed on the y axis (metric)
#' @param facet_x_vars vector of variable names to create columns of facets
#' @param facet_y_vars vector of variable names to create rows of facets
#' @param split_var index of xvars along groups of which the plot should be split
#' @param heights_plots relative heights of the main plot and the stairs on the bottom
#' @param scale_stairs height of the stairs for each variable between 0 and 1
#' @param grid_level depth of loops for which the grid-lines are drawn
#' @param scales passed on to facet_grid
#' @param hlines position of horizontal lines, passed as `yintercept` to
#'   `geom_hline`
#' @param use_colours optional named vector of colours used in `scale_colour_manual`
#' @param use_shapes optional named vector of shapes used in `scale_shape_manual`
#'
#' @return a ggplot/patchwork object containing the plots
#' @export
#'
#' @details `use_colours` and `use_shapes` both use the `method` variable in their respective aesthetics.
#'
#' @examples
#' \donttest{
#' library("ggplot2")
#' library("patchwork")
#' data("combination_tests_delayed")
#'
#' results_long <- results_pivot_longer(combination_tests_delayed)
#'
#' # plot the rejection rate of two methods
#' combined_plot(
#'   results_long,
#'   c("logrank", "mwlrt", "maxcombo"),
#'   c("hr", "n_pat_design", "delay", "hazard_ctrl", "recruitment"),
#'   "rejection_0.025",
#'   grid_level=2
#' )
#'
#' # use custom colour and shape scales
#' # this can be used to group methods by shape or colour
#' # this is also helpful if methods should have the same aesthetics across plots
#' my_colours <- c(
#'   logrank="black",
#'   mwlrt="blue",
#'   maxcombo="green"
#' )
#'
#' my_shapes <- c(
#'   logrank=1,
#'   mwlrt=2,
#'   maxcombo=2
#' )
#'
#' combined_plot(
#'   results_long,
#'   c("logrank", "mwlrt", "maxcombo"),
#'   c("hr", "n_pat_design", "delay", "hazard_ctrl", "recruitment"),
#'   "rejection_0.025",
#'   grid_level=2,
#'   use_colours = my_colours,
#'   use_shapes = my_shapes
#' )
#'
#' # if one has a dataset of metadata with categories of methods
#' # one could uses those two definitions
#' # colours for methods, same shapes for methods of same category
#' metadata <- data.frame(
#'   method = c("logrank", "mwlrt", "maxcombo"),
#'   method_name = c("logrank test", "modestly weighed logrank test", "maxcombo test"),
#'   category = c("logrank test", "combination test", "combination test")
#' )
#'
#' my_colours <- ggplot2::scale_colour_discrete()$palette(n=nrow(metadata)) |>
#'   sample() |>
#'   setNames(metadata$method)
#'
#' my_shapes <- metadata$category |>
#'   as.factor() |>
#'   as.integer() |>
#'   setNames(metadata$method)
#'
#' combined_plot(
#'   results_long,
#'   c("logrank", "mwlrt", "maxcombo"),
#'   c("hr", "n_pat_design", "delay", "hazard_ctrl", "recruitment"),
#'   "rejection_0.025",
#'   grid_level=2,
#'   use_colours = my_colours,
#'   use_shapes = my_shapes
#' )
#' }
combined_plot <- function(
    data,
    methods,
    xvars,
    yvar,
    facet_x_vars=c(),
    facet_y_vars=c(),
    split_var = 1,
    heights_plots = c(3,1),
    scale_stairs = 0.75,
    grid_level = 2,
    scales = "fixed",
    hlines = numeric(0),
    use_colours = NULL,
    use_shapes  = NULL
    ){

  if( !(requireNamespace("ggplot2", quietly = TRUE) & requireNamespace("patchwork", quietly = TRUE)) ){
    message("Packages ggplot2 and patchwork required for plotting functionality.")
    return(invisible(NULL))
  }

  facet_vars_y_sym <- rlang::syms(facet_y_vars)
  facet_vars_x_sym <- rlang::syms(facet_x_vars)
  xvars <- rlang::syms(xvars)
  yvar  <- rlang::sym(yvar)

  data <- data |>
    dplyr::filter(method %in% methods)

  # remove facets in which all y values are empty
  # dont remove empty y-values in facets where there are some y-values
  # (so gaps in lines remain gaps in each facet and only completely facets are
  # dropped)
  data <- data |>
    dplyr::arrange(!!!xvars) |>
    dplyr::ungroup() |>
    dplyr::group_by(!!!facet_vars_x_sym) |>
    dplyr::filter(!all(is.na(!!yvar))) |>
    dplyr::ungroup() |>
    dplyr::group_by(!!!facet_vars_y_sym) |>
    dplyr::filter(!all(is.na(!!yvar))) |>
    dplyr::ungroup()

  ## split lines

  len_x <- length(xvars)
  if(len_x > 1){
    lastvar <- xvars[[len_x]]
    splitvar <- xvars[[split_var]]
    data <- data |>
      dplyr::group_by(method,!!!facet_vars_y_sym,!!!facet_vars_x_sym,!!splitvar) |>
      dplyr::group_modify(~tibble::add_row(.x,.before = 1)) |>
      #    mutate(!!lastvar := ifelse(is.na(!!yvar),!!lastvar + .0,!!lastvar)) |>
      tidyr::fill(!!!xvars[-split_var],.direction='up') |>
      dplyr::ungroup()
  }


  data <- data |>
    order_combine_xvars(xvars, facet_vars=facet_x_vars, height_x_axis=scale_stairs, grid_level=grid_level)

  plot_2 <- lapply(xvars, \(xx){
    ggplot2::ggplot(data, ggplot2::aes(x=x, y=factor(format(!!xx, digits=3)), group=method)) +
      ggplot2::geom_step(linewidth=0.25) +
      ggplot2::theme_void(
        base_size = 9
      ) +
      ggplot2::theme(
        axis.text.y = ggplot2::element_text(),
        axis.title.y = ggplot2::element_text(angle=75),
        strip.background = ggplot2::element_blank(),
        strip.text = ggplot2::element_blank(),
        panel.grid.major.y = ggplot2::element_line(
          linewidth = 0.125,
          colour="lightgray"
        )
      ) +
      ggplot2::ylab(as.character(xx))  +
      ggplot2::facet_grid(
        cols = dplyr::vars(!!!facet_vars_x_sym)
      )
  })

  plot_2 <- patchwork::wrap_plots(plot_2, ncol=1)

  plot_1 <- ggplot2::ggplot(data, ggplot2::aes(x=x, y=!!yvar, group=method, colour=method, shape=method)) +
    ggplot2::geom_line() +
    ggplot2::geom_point(size=4) +
    ggplot2::scale_x_discrete(breaks = attr(data, "x_axis_breaks")) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_blank(),
      axis.title.x = ggplot2::element_blank()
    )  +
    ggplot2::facet_grid(
      cols = dplyr::vars(!!!facet_vars_x_sym),
      rows = dplyr::vars(!!!facet_vars_y_sym),
      labeller = ggplot2::label_both,
      scales = scales
    ) +
    ggplot2::geom_hline(yintercept=hlines)

  if(!is.null(use_colours)){
    plot_1 <- plot_1 +
      ggplot2::scale_colour_manual(values=use_colours)
  }

  if(!is.null(use_shapes)){
    plot_1 <- plot_1 +
      ggplot2::scale_shape_manual(values=use_shapes)
  }
  (plot_1 / plot_2) + patchwork::plot_layout(heights=heights_plots)
}


#' Add ggplot axis labels from labels attribute
#'
#' @param gg a ggplot object
#'
#' @return a ggplot object
#' @export
#'
#' @examples
#' \donttest{
#' library("ggplot2")
#' test <- mtcars
#' # add a label attribute
#' attr(test$cyl, "label") <- "cylinders"
#'
#' # plot witht the variable names as axis titles
#' gg1 <- ggplot(test, aes(x=wt, y=cyl)) +
#'   geom_point()
#' gg1
#'
#' # add labels where defined in the attribute
#' gg2 <- ggplot(test, aes(x=wt, y=cyl)) +
#'   geom_point()
#'
#' gg2 <- labs_from_labels(gg2)
#' gg2
#' }
labs_from_labels <- function(gg){
  new_labels <- gg$mapping |>
    purrr::map(rlang::as_name) |>
    purrr::map(\(i){
      attr(gg$data[[i]], "label")
    }) |>
    unlist()

  gg + ggplot2::labs(!!!new_labels)
}
