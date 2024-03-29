#' Create an empty assumtions data.frame for generate_progression
#'
#' @param print print code to generate parameter set?
#'
#' @return For generate_progression: a design tibble with default values invisibly
#'
#' @details assumptions_progression generates a default design `data.frame` for
#'   use with generate_progression If print is `TRUE` code to produce the
#'   template is also printed for copying, pasting and editing by the user.
#'   (This is the default when run in an interactive session.)
#'
#' @export
#' @describeIn generate_progression generate default assumptions `data.frame`
#'
#' @examples
#' Design <- assumptions_progression()
#' Design
assumptions_progression <- function(print=interactive()){
  skel <- "expand.grid(
  hazard_ctrl= m2r(24),              # med. survival ctrl 24 months
  hazard_trt= m2r(36),               # med. survival trt 36 months
  hazard_after_prog=m2r(6),          # med. survival after prorg. 6 months
  prog_rate_ctrl=m2r(12),            # med. time to prog. ctrl 12 months
  prog_rate_trt= m2r(c(12, 16, 18)), # med. time to prog. trt 12, 16, 18 months
  random_withdrawal=m2r(120)         # median time to random withdrawal 10 years
)
"

  if(print){
    cat(skel)
  }

  invisible(
    skel |>
      str2expression() |>
      eval()
  )
}

#' Generate Dataset with changing hazards after disease progression
#'
#' @param condition condition row of Design dataset
#' @param fixed_objects fixed objects of Design dataset
#'
#' @details
#' Condidtion has to contain the following columns:
#'
#'   * n_trt number of paitents in treatment arm
#'   * n_ctrl number of patients in control arm
#'   * hazard_ctrl hazard in the control arm
#'   * hazard_trt hazard in the treatment arm for not cured patients
#'   * hazard_after_prog hazard after disease progression
#'   * prog_rate_ctrl hazard rate for disease progression unter control
#'   * prog_rate_trt hazard rate for disease progression unter treatment
#'
#' @return
#' For generate_progression: A dataset with the columns t (time) and trt
#' (1=treatment, 0=control), evt (event, currently TRUE for all observations),
#' t_ice (time of intercurrent event), ice (intercurrent event)
#'
#' @export
#' @describeIn generate_progression simulates a dataset with changing hazards after disease progression
#'
#' @examples
#' one_simulation <- merge(
#'     assumptions_progression(),
#'     design_fixed_followup(),
#'     by=NULL
#'   ) |>
#'   tail(1) |>
#'   generate_progression()
#' head(one_simulation)
#' tail(one_simulation)
generate_progression <- function(condition, fixed_objects=NULL){

  t_evt_ctrl <- miniPCH::rpch_fun(
      c(0),
      c(condition$hazard_ctrl),
      discrete = TRUE
    )(condition$n_ctrl)

  t_evt_trt <- miniPCH::rpch_fun(
      c(0),
      c(condition$hazard_trt),
      discrete = TRUE
    )(condition$n_trt)

  t_prog_ctrl <- miniPCH::rpch_fun(
      c(0),
      c(condition$prog_rate_ctrl),
      discrete = TRUE
    )(condition$n_ctrl)

  t_prog_trt <- miniPCH::rpch_fun(
      c(0),
      c(condition$prog_rate_trt),
      discrete = TRUE
    )(condition$n_trt)

  t_evt_after_prog_ctrl <- miniPCH::rpch_fun(
      c(0),
      c(condition$hazard_after_prog),
      discrete = TRUE
    )(condition$n_ctrl)

  t_evt_after_prog_ctrl <- t_prog_ctrl + t_evt_after_prog_ctrl

  t_evt_after_prog_trt <- miniPCH::rpch_fun(
      c(0),
      c(condition$hazard_after_prog),
      discrete = TRUE
    )(condition$n_ctrl)

  t_evt_after_prog_trt <- t_prog_trt + t_evt_after_prog_trt

  data_trt <- data.frame(
    t = ifelse(t_prog_trt < t_evt_trt, t_evt_after_prog_trt, t_evt_trt),
    trt = 1L,
    evt = TRUE,
    t_ice = ifelse(t_prog_trt < t_evt_trt, t_prog_trt, Inf),
    ice   = (t_prog_trt < t_evt_trt)
  )

  data_ctrl <- data.frame(
    t = ifelse(t_prog_ctrl < t_evt_ctrl, t_evt_after_prog_ctrl, t_evt_ctrl),
    trt = 0L,
    evt = TRUE,
    t_ice = ifelse(t_prog_ctrl < t_evt_ctrl, t_prog_ctrl, Inf),
    ice   = (t_prog_ctrl < t_evt_ctrl)
  )

  rbind(data_trt, data_ctrl)
}

#' @param Design Design data.frame for subgroup
#' @param what True summary statistics for which estimand
#' @param cutoff_stats (optionally named) cutoff time, see details
#' @param milestones (optionally named) vector of times at which milestone survival should be calculated
#' @param fixed_objects additional settings, see details
#'
#' @return For true_summary_statistics_subgroup: the design data.frame
#'   passed as argument with the additional columns
#'
#' @details
#'
#' `what` can be `"os"` for overall survival and `"pfs"` for progression free
#' survival.
#'
#' The if `fixed_objects` contains `t_max` then this value is used as the
#' maximum time to calculate function like survival, hazard, ... of the data
#' generating models. If this is not given `t_max` is choosen as the minimum of
#' the `1-(1/10000)` quantile of all survival distributions in the model.
#'
#' `cutoff_stats` are the times used to calculate the statistics like average
#' hazard ratios and RMST, that are only calculated up to a certain point.
#'
#' @export
#'
#' @describeIn generate_progression calculate true summary statistics for scenarios with disease progression
#'
#' @examples
#'
#' my_design <- merge(
#'   assumptions_progression(),
#'   design_fixed_followup(),
#'   by=NULL
#' )
#'
#' my_design_os  <- true_summary_statistics_progression(my_design, "os")
#' my_design_pfs <- true_summary_statistics_progression(my_design, "pfs")
#' my_design_os
#' my_design_pfs
true_summary_statistics_progression <- function(Design, what="os", cutoff_stats=NULL, fixed_objects=NULL, milestones=NULL){

  true_summary_statistics_progression_rowwise_pfs <- function(condition, cutoff_stats, milestones){

    real_stats <- fast_real_statistics_pchaz(
      Tint_trt =  0, lambda_trt  = condition$hazard_trt  + condition$prog_rate_trt,
      Tint_ctrl = 0, lambda_ctrl = condition$hazard_ctrl + condition$prog_rate_ctrl,
      cutoff = cutoff_stats, N_trt = condition$n_trt, N_ctrl = condition$n_ctrl, milestones=milestones
    )

    res <- cbind(
      condition,
      real_stats
    )

    row.names(res) <- NULL
    res
  }

  true_summary_statistics_progression_rowwise_os <- function(condition, cutoff_stats, milestones){

    real_stats <- fast_real_statistics(
      haz_trt   = progression_haz_fun  (condition$hazard_trt , condition$prog_rate_trt , condition$hazard_after_prog),
      pdf_trt   = progression_pdf_fun  (condition$hazard_trt , condition$prog_rate_trt , condition$hazard_after_prog),
      surv_trt  = progression_surv_fun (condition$hazard_trt , condition$prog_rate_trt , condition$hazard_after_prog),
      quant_trt = progression_quant_fun(condition$hazard_trt , condition$prog_rate_trt , condition$hazard_after_prog),
      haz_ctrl  = progression_haz_fun  (condition$hazard_ctrl, condition$prog_rate_ctrl, condition$hazard_after_prog),
      pdf_ctrl  = progression_pdf_fun  (condition$hazard_ctrl, condition$prog_rate_ctrl, condition$hazard_after_prog),
      surv_ctrl = progression_surv_fun (condition$hazard_ctrl, condition$prog_rate_ctrl, condition$hazard_after_prog),
      quant_ctrl= progression_quant_fun(condition$hazard_ctrl, condition$prog_rate_ctrl, condition$hazard_after_prog),
      N_trt=condition$n_trt,
      N_ctrl=condition$n_ctrl,
      cutoff = cutoff_stats,
      milestones = milestones
    )

    res <- cbind(
      condition,
      real_stats
    )

    row.names(res) <- NULL
    res
  }


  true_summary_statistics_progression_rowwise <- switch(what,
                                                        "os"  = true_summary_statistics_progression_rowwise_os,
                                                        "pfs" = true_summary_statistics_progression_rowwise_pfs,
                                                        {stop(paste0(gettext("Invalid value for"), " what: ", what, " ", gettext('use "os" for overall survival or "pfs" for progression free survival.')))}
  )

  Design <- Design |>
    split(1:nrow(Design)) |>
    purrr::map(true_summary_statistics_progression_rowwise, cutoff_stats = cutoff_stats, milestones=milestones, .progress = TRUE) |>
    do.call(what=rbind)

  Design
}



#' Calculate progression rate from proportion of patients who progress
#'
#' @param design design data.frame
#'
#' @describeIn generate_progression Calculate progression rate from proportion of patients who progress
#'
#' @return For progression_rate_from_progression_prop: the design data.frame passed as
#'   argument with the additional columns prog_rate_trt, prog_rate_ctrl
#'
#' @details For progression_rate_from_progression_prop, the design data.frame,
#'   has to contain the columns `prog_prop_trt` and `prog_prop_ctrl` with the
#'   proportions of patients, who progress in the respective arms.
#'
#' @export
#'
#' @examples
#' my_design <- merge(
#'     assumptions_progression(),
#'     design_fixed_followup(),
#'     by=NULL
#'   )
#' my_design$prog_rate_ctrl <- NA_real_
#' my_design$prog_rate_trt <- NA_real_
#' my_design$prog_prop_trt <- 0.2
#' my_design$prog_prop_ctrl <- 0.3
#' my_design <- progression_rate_from_progression_prop(my_design)
#' my_design
progression_rate_from_progression_prop <- function(design){

  rowwise_fun <- function(condition){
    # set t_max to 1-1/1000 quantile of control or treatment survival function
    # whichever is later
    t_max <- max(
      log(1000) / condition$hazard_ctrl,
      log(1000) / condition$hazard_trt
    )

    cumhaz_trt <- miniPCH::chpch_fun(
      c(                   0),
      c(condition$hazard_trt)
    )(t_max)

    cumhaz_ctrl <- miniPCH::chpch_fun(
      c(                    0),
      c(condition$hazard_ctrl)
    )(t_max)

    condition$prog_rate_trt  <- cumhaz_trt  / ((1/condition$prog_prop_trt  - 1)*t_max)
    condition$prog_rate_ctrl <- cumhaz_ctrl / ((1/condition$prog_prop_ctrl - 1)*t_max)

    condition
  }

  result <- design |>
    split(1:nrow(design)) |>
    purrr::map(rowwise_fun, .progress = TRUE) |>
    do.call(what=rbind)

  result
}

#' @describeIn generate_progression calculate censoring rate from censoring proportion
#'
#' @return for cen_rate_from_cen_prop_progression: design data.frame with the
#'   additional column random_withdrawal
#' @export
#'
#' @details cen_rate_from_cen_prop_progression takes the proportion of
#'   censored patients from the column `censoring_prop`. This column describes
#'   the proportion of patients who are censored randomly before experiencing an
#'   event, without regard to administrative censoring.
#'
#' @examples
#' design <- expand.grid(
#' hazard_ctrl         = m2r(15),          # hazard under control
#' hazard_trt          = m2r(18),          # hazard under treatment
#' hazard_after_prog   = m2r(3),           # hazard after progression
#' prog_rate_ctrl      = m2r(12),          # hazard for disease progression under control
#' prog_rate_trt       = m2r(c(12,16,18)), # hazard for disease progression under treatment
#' censoring_prop      = 0.1,              # rate of random withdrawal
#' followup            = 100,              # follow up time
#' n_trt               = 50,               # patients in treatment arm
#' n_ctrl              = 50                # patients in control arm
#' )
#' cen_rate_from_cen_prop_progression(design)
cen_rate_from_cen_prop_progression <- function(design){

  rowwise_fun <- function(condition){
    if(condition$censoring_prop == 0){
      condition$random_withdrawal <- 0.
      return(condition)
    }

    # set t_max to 1-1/1000 quantile of control or treatment survival function
    # whichever is later
    t_max <- max(
      log(1000) / condition$hazard_ctrl,
      log(1000) / condition$hazard_trt
    )

    a <- condition$n_trt / (condition$n_trt + condition$n_ctrl)
    b <- 1-a

    cumhaz_trt_tmax  <- miniPCH::chmstate(
      t_max,
      t = 0,
      Q = array(matrix(c(
        -condition$prog_rate_trt -condition$hazard_trt,     condition$prog_rate_trt,       condition$hazard_trt,
        0, -condition$hazard_after_prog, condition$hazard_after_prog,
        0,                            0,                           0
      ),3,3,byrow = TRUE), dim=c(3,3,1)),
      pi = c(1,0,0),
      abs = c(0,0,1)
    )

    cumhaz_ctrl_tmax <- miniPCH::chmstate(
      t_max,
      t = 0,
      Q = array(matrix(c(
        -condition$prog_rate_ctrl -condition$hazard_ctrl,     condition$prog_rate_ctrl,       condition$hazard_ctrl,
        0, -condition$hazard_after_prog, condition$hazard_after_prog,
        0,                            0,                           0
      ),3,3,byrow = TRUE), dim=c(3,3,1)),
      pi = c(1,0,0),
      abs = c(0,0,1)
    )

    target_fun <- Vectorize(\(r){
      cumhaz_censoring <- miniPCH::chpch_fun(0, r)
      prob_cen_ctrl <- cumhaz_censoring(t_max)/(cumhaz_censoring(t_max) + cumhaz_ctrl_tmax)
      prob_cen_trt  <- cumhaz_censoring(t_max)/(cumhaz_censoring(t_max) + cumhaz_trt_tmax)
      prob_cen <- a*prob_cen_trt + b*prob_cen_ctrl
      prob_cen-condition$censoring_prop
    })

    condition$random_withdrawal <- uniroot(target_fun, interval=c(0, 1e-6), extendInt = "upX", tol=.Machine$double.eps)$root

    condition
  }

  result <- design |>
    split(1:nrow(design)) |>
    purrr::map(rowwise_fun, .progress = TRUE) |>
    do.call(what=rbind)

  result

}




#' Calculate hr after onset of treatment effect
#'
#' @param design design data.frame
#' @param target_power_ph target power under proportional hazards
#' @param final_events target events for inversion of Schönfeld Formula, defaults to `condition$final_events`
#' @param target_alpha target one-sided alpha level for the power calculation
#'
#' @return For hazard_before_progression_from_PH_effect_size: the design
#'   data.frame passed as argument with the additional column hazard_trt.
#' @export
#'
#' @describeIn generate_progression Calculate hazard in the treatment arm before progression from PH effect size
#'
#' @details `hazard_before_progression_from_PH_effect_size` calculates the
#'   hazard ratio after onset of treatment effect as follows: First calculate
#'   the hazard in the control arm that would give the same median survival
#'   under an exponential model. Then calculate the median survival in the
#'   treatment arm that would give the desired power of the logrank test under
#'   exponential models in control and treatment arm. Then callibrate the hazard
#'   before progression in the treatment arm to give the same median survival
#'   time.
#'
#'   This is a heuristic and to some extent arbitrary approach to calculate
#'   hazard ratios that correspond to reasonable and realistic scenarios.
#'
#' @examples
#' \donttest{
#' my_design <- merge(
#'   design_fixed_followup(),
#'   assumptions_progression(),
#'   by=NULL
#' )
#'
#' my_design$hazard_trt <- NULL
#' my_design$final_events <- ceiling(0.75 * (my_design$n_trt + my_design$n_ctrl))
#'
#' my_design <- hazard_before_progression_from_PH_effect_size(my_design, target_power_ph=0.7)
#' my_design
#' }
hazard_before_progression_from_PH_effect_size <- function(design, target_power_ph=NA_real_, final_events=NA_real_, target_alpha=0.025){

  get_hr_after <- function(condition, target_power_ph=NA_real_, final_events=NA_real_){

    if(is.na(final_events)){
      if(hasName(condition, "final_events")){
        final_events <- condition$final_events
      } else {
        stop("final_events not given and not present in condition")
      }
    }

    if(is.na(target_power_ph)){
      if(hasName(condition, "effect_size_ph")){
        target_power_ph <- condition$effect_size_ph
      } else {
        stop(gettext("target_ph_power not given and effect_size_ph not present in design"))
      }
    }

    if(target_power_ph == 0 & condition$prog_rate_ctrl == condition$prog_rate_trt){
      condition$hazard_trt <- condition$hazard_ctrl
      return(condition)
    }

    ph_hr <- hr_required_schoenfeld(
      final_events,
      alpha=target_alpha,
      beta=(1-target_power_ph),
      p=(condition$n_ctrl/(condition$n_ctrl + condition$n_trt))
    )

    p_ctrl <- miniPCH::pmstate_fun(
      t = 0,
      Q=array(matrix(c(
        -condition$prog_rate_ctrl -condition$hazard_ctrl,     condition$prog_rate_ctrl,       condition$hazard_ctrl,
                                                       0, -condition$hazard_after_prog, condition$hazard_after_prog,
                                                       0,                            0,                           0
      ),3,3,byrow = TRUE), dim=c(3,3,1)),
      pi=c(1L,0,0),
      abs=c(0,0,1L)
    )

    t_max <- miniPCH::qpch(0.9, 0, min(condition$hazard_ctrl, condition$prog_rate_ctrl, condition$hazard_after_prog))

    median_ctrl <- uniroot(\(t){
      p_ctrl(t) - 0.5
    }, c(0,t_max))$root

    hazard_ctrl_ph <- m2r(d2m(median_ctrl))

    median_trt_ph  <- miniPCH::qpch(0.5, 0, hazard_ctrl_ph * ph_hr)

    target_fun_hazard_trt <- function(h){
      miniPCH::pmstate(
        median_trt_ph,
        t=0,
        Q=array(matrix(c(
          -condition$prog_rate_trt -h,      condition$prog_rate_trt,                           h,
                                    0, -condition$hazard_after_prog, condition$hazard_after_prog,
                                    0,                            0,                           0
        ),3,3,byrow = TRUE), dim=c(3,3,1)),
        pi=c(1L,0,0),
        abs=c(0,0,1L)
      ) - 0.5
    }

    condition$hazard_trt <- uniroot(target_fun_hazard_trt, interval=c(1e-8, 0.0001), extendInt = "upX", tol=.Machine$double.eps*2)$root
    condition
  }

  result <- design |>
    split(1:nrow(design)) |>
    purrr::map(get_hr_after, target_power_ph=target_power_ph, final_events=final_events, .progress=TRUE) |>
    do.call(what=rbind)

  result

}
