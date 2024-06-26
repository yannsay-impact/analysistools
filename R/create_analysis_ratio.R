#' Calculate a ratio from a survey
#'
#' @description The function will calculate the ratio between 2 variables, the numerator and
#' denominator.
#' The numerator : By default, it will change all NAs to 0. If numerator_NA_to_0 is set to FALSE,
#' rows with missing values will be filtered out.
#'
#' The denominator : All rows with missing value will be filtered out (cannot be changed). In
#' addition, by default, all rows with a value equal to 0 will be filtered out, if
#' filter_denominator_0 is set to TRUE, they will be kept.
#'
#' @param design design survey
#' @param group_var dependent variable(s), variable to group by. If no dependent
#' variable, it should be NA or empty string. If more than one variable, it
#' should be one string with each variable separated by comma, e.g. "groupa, groupb"
#' to group for groupa and groupb.
#' NA is default for no grouping.
#' @param level the confidence level. 0.95 is default
#' @param analysis_var_numerator character string with the numerator column name.
#' @param analysis_var_denominator character string with the denominator column name.
#' @param numerator_NA_to_0 Will turn all NA of the numerator into 0's, default TRUE.
#' @param filter_denominator_0 Will remove all rows with 0's in the denominator, default TRUE.
#'
#' @return a data frame with the ratio for each group
#' @export
#'
#'
#' @examples
#' school_ex <- data.frame(
#'   hh = c("hh1", "hh2", "hh3", "hh4"),
#'   num_children = c(3, 0, 2, NA),
#'   num_enrolled = c(3, NA, 0, NA),
#'   num_attending = c(1, NA, NA, NA),
#'   group = c("a", "a", "b", "b")
#' )
#' me_design <- srvyr::as_survey(school_ex)
#' # Default value will give a ratio of 0.2 as there are 1 child out of 5 attending school.
#' # numerator: 1 child from hh1 and 0 from hh3. denominator: 3 from hh1 and 2 from hh3. In the
#' # hh3, the num_attending is NA because there is a skip logic, there cannot be a child attending as
#' # none are enrolled. By default, the function has the argument numerator_NA_to_0 set to TRUE to
#' # turn that NA into a 0.
#' # n and n_total are 2 as 2 households were included in the calculation. hh2 was not included in
#' # the calculation of totals. The argument filter_denominator_0 set to TRUE removes that row.
#' create_analysis_ratio(me_design,
#'                       analysis_var_numerator = "num_attending",
#'                       analysis_var_denominator = "num_children"
#' )
#' # If numerator_NA_to_0 is set to FALSE, ratio will be 1/3, as hh3 with 2 children and NA for
#' # attending will be removed with the na.rm = T inside the survey_ratio calculation.
#' # n and n_total is 1 as only 1 household was used.
#' create_analysis_ratio(me_design,
#'                       analysis_var_numerator = "num_attending",
#'                       analysis_var_denominator = "num_children",
#'                       numerator_NA_to_0 = FALSE
#' )
#' # If filter_denominator_0 is set to FALSE, ratio will be 0.2 as there are 1 child out of 5
#' # attending school.
#' # The number of household counted, n and n_total, is equal to 3 instead 2. The household with 0
#' # child is counted in the totals.
#' # (01 + 0 + 0) / (3 + 0 + 2)
#' create_analysis_ratio(me_design,
#'                       analysis_var_numerator = "num_attending",
#'                       analysis_var_denominator = "num_children",
#'                       filter_denominator_0 = FALSE
#' )
#' # For weights and group:
#' set.seed(8988)
#' somedata <- data.frame(
#'   groups = rep(c("a", "b"), 50),
#'   children_518 = sample(0:5, 100, replace = TRUE),
#'   children_enrolled = sample(0:5, 100, replace = TRUE)
#' ) %>%
#'   dplyr::mutate(children_enrolled = ifelse(children_enrolled > children_518,
#'                                            children_518,
#'                                            children_enrolled
#'   ))
#' somedata[["weights"]] <- ifelse(somedata$groups == "a", 1.33, .67)
#' create_analysis_ratio(srvyr::as_survey(somedata, weights = weights, strata = groups),
#'                       group_var = NA,
#'                       analysis_var_numerator = "children_enrolled",
#'                       analysis_var_denominator = "children_518",
#'                       level = 0.95
#' )
#' create_analysis_ratio(srvyr::as_survey(somedata, weights = weights, strata = groups),
#'                       group_var = "groups",
#'                       analysis_var_numerator = "children_enrolled",
#'                       analysis_var_denominator = "children_518",
#'                       level = 0.95
#' )
#'
create_analysis_ratio <- function(design,
                                  group_var = NA,
                                  analysis_var_numerator,
                                  analysis_var_denominator,
                                  numerator_NA_to_0 = TRUE,
                                  filter_denominator_0 = TRUE,
                                  level = .95) {
  # check if variables exists
  if (!analysis_var_numerator %in% names(design$variables)) {
    msg <- glue::glue(analysis_var_numerator, " is in the names of the dataset.")
    stop(msg)
  }

  if (!analysis_var_denominator %in% names(design$variables)) {
    msg <- glue::glue(analysis_var_denominator, " is in the names of the dataset.")
    stop(msg)
  }

  # check the grouping variable
  if (is.na(group_var)) {
    across_by <- c()
  } else {
    across_by <- group_var %>%
      char_to_vector()
  }

  if (numerator_NA_to_0) {
    design <- design %>%
      dplyr::mutate(!!rlang::sym(analysis_var_numerator) := dplyr::if_else(
        is.na(!!rlang::sym(analysis_var_numerator)),
        0,
        !!rlang::sym(analysis_var_numerator)
      ))
  }

  # filtering
  ## denominator
  if (filter_denominator_0) {
    results <- design %>%
      dplyr::group_by(dplyr::across(dplyr::any_of(across_by))) %>%
      dplyr::filter(!is.na(!!rlang::sym(analysis_var_denominator)),
        !!rlang::sym(analysis_var_denominator) != 0,
        .preserve = T
      )
  } else {
    results <- design %>%
      dplyr::group_by(dplyr::across(dplyr::any_of(across_by))) %>%
      dplyr::filter(!is.na(!!rlang::sym(analysis_var_denominator)), .preserve = T)
  }

  ## numerator
  if (!numerator_NA_to_0) {
    results <- design %>%
      dplyr::group_by(dplyr::across(dplyr::any_of(across_by))) %>%
      dplyr::filter(!is.na(!!rlang::sym(analysis_var_numerator)),
        .preserve = T
      )
  }

  # calculate
  results <- results %>%
    srvyr::summarise(
      srvyr::survey_ratio(
        numerator = !!rlang::sym(analysis_var_numerator),
        denominator = !!rlang::sym(analysis_var_denominator),
        vartype = "ci",
        level = as.numeric(level),
        na.rm = T
      ),
      n = dplyr::n(),
      n_w = srvyr::survey_total(
        vartype = "ci",
        level = as.numeric(level),
        na.rm = T
      )
    ) %>%
    dplyr::mutate(
      group_var = create_group_var(group_var),
      analysis_var = paste(analysis_var_numerator, "%/%", analysis_var_denominator),
      analysis_var_value = "NA %/% NA",
      analysis_type = "ratio",
      n_total = n,
      n_w_total = n_w
    ) %>%
    dplyr::rename(
      stat = coef,
      stat_low = `_low`,
      stat_upp = `_upp`
    ) %>%
    correct_nan_total_is_0()


  # adding group_var_value
  results <- adding_group_var_value(results = results, group_var = group_var, grouping_vector = across_by)
  # adding analysis key
  results <- adding_analysis_key_ratio(results = results)
  # re-arranging the columns
  results %>%
    arranging_results_columns()
}
