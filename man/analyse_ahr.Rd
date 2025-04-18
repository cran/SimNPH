% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/analyse_ahr.R
\name{analyse_ahr}
\alias{analyse_ahr}
\title{Analyse the dataset using extimators for the the average hazard ratio}
\usage{
analyse_ahr(
  max_time = NA,
  type = "AHR",
  level = 0.95,
  alternative = "two.sided"
)
}
\arguments{
\item{max_time}{time for which the AHR is calculated}

\item{type}{"AHR" for average hazard ratio "gAHR" for geometric average hazard ratio}

\item{level}{confidence level for CI computation}

\item{alternative}{alternative hypothesis for the tests "two.sided" or "one.sieded"}
}
\value{
Returns an analysis function, that can be used in runSimulations
}
\description{
Analyse the dataset using extimators for the the average hazard ratio
}
\details{
The implementation from the nph package is used, see the documentation there
for details.

\code{alternative} can be "two.sided" for a two sided test of equality of the
summary statistic or "one.sided" for a one sided test testing H0: treatment
has equal or shorter survival than control vs. H1 treatment has longer
survival than control.

The data.frame returned by the created function includes the follwing
columns:
\itemize{
\item \code{p} p value of the test, see Details
\item \code{alternative} the alternative used
\item \code{AHR}/\code{gAHR} estimated (geometric) average hazard ratio
\item \code{AHR_lower}/\code{gAHR_lower} unadjusted lower bound of the confidence interval for the (geometric) average hazard ratio
\item \code{AHR_upper}/\code{gAHR_upper} unadjusted upper bound of the confidence interval for the (geometric) average hazard ratio
\item \code{CI_level} the CI level used
\item \code{N_pat} number of patients
\item \code{N_evt} number of events
}
}
\examples{
condition <- merge(
  assumptions_delayed_effect(),
  design_fixed_followup(),
  by = NULL
) |>
  head(1)
dat <- generate_delayed_effect(condition)
analyse_ahr()(condition, dat)
analyse_ahr(type = "gAHR")(condition, dat)
analyse_ahr(max_time = 50, type = "AHR")(condition, dat)
analyse_ahr(max_time = 50, type = "gAHR")(condition, dat)
}
\seealso{
\link[nph:nphparams]{nph::nphparams}
}
