# SimNPH

<!-- badges: start -->
[![Codecov test coverage](https://codecov.io/gh/SimNPH/SimNPH/branch/master/graph/badge.svg)](https://app.codecov.io/gh/SimNPH/SimNPH?branch=master)
[![CRAN status](https://www.r-pkg.org/badges/version/SimNPH)](https://CRAN.R-project.org/package=SimNPH)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
<!-- badges: end -->

**Sim**ulate **N**on **P**roportional **H**azards

This package provides several functions to simulate survival data with non
proportional hazards using the general purpose simulation package
[SimDesign](https://cran.r-project.org/package=SimDesign).

This package follows the structure of SimDesing and provides functions that
can readily be used as `generate`, `analyse` and `summarise` arguments in 
`SimDesign`'s `runSimulation` function. 

## Usage

### Installation

The current development version can be installed with:

```
remotes::install_git("https://github.com/SimNPH/SimNPH.git")
```

### Getting Started

Documentation for all functions can be found in the respective help topics in
the package after installation or
[here](https://simnph.github.io/SimNPH/reference/index.html)

Some examples of data generation, testing and estimation can be found in this
[vignette](https://simnph.github.io/SimNPH/articles/vignettes_prebuild/simple_example.html).

## Results of the Simulation Study

The results of the simulation study done by the CONFIRMS consortium in the
course of the EMA tender will be published in an upcoming paper 
([preprint on arXiv](https://arxiv.org/abs/2310.05622)) and are presented in a 
[shinylive App](https://simnph.github.io/SimResultsShinylive/about.html). 
