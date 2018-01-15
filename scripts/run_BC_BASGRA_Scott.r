## 1. INITIALISE MCMC ##
  cat(file=stderr(), 'Starting BC_BASGRA_Scott.r', "\n")

  # unload packages and remove variables
  pkgs = names(sessionInfo()$otherPkgs)
  if (!is.null(pkgs)){
    pkgs = paste('package:', pkgs, sep = "")
    lapply(pkgs, detach, character.only=TRUE, unload=TRUE)
  }
  rm(list=ls()) # kills breakpoints! frees memory.
  
  # initialise BC
  source('scripts/BC_BASGRA_MCMC_init_Scott.r')

## 2. RUNNING THE MCMC ##
  cat(file=stderr(), 'Calling  BC_BASGRA_MCMC.r', "\n")
  source('scripts/BC_BASGRA_MCMC.R')

## 3. PRINTING AND PLOTTING ##
  cat(file=stderr(), 'Calling BC output scripts', "\n")
  source('scripts/BC_export_parModes.R')
  source('scripts/BC_plot_parameters_traceplots.R') # can be slow!
  source('scripts/BC_plot_parameters_priorbeta_histograms.R')
  outputMax[which(outputNames=="CLV")] <- 200 # it's pretty awkward to set these programmatically
  outputMax[which(outputNames=="CST")] <- 100
  outputMax[which(outputNames=="TILTOT")] <- 9000
  outputMax[which(outputNames=="WCL")] <- 60
  source('scripts/BC_plot_outputs_data.R')
  
  # run with MAP parameters
  for (s in 1:nSites){
    cat(file=stderr(), paste('Running BASGRA_Scott with BC MAP parameters, site',s), "\n")
    file_params    <- 'model_outputs/BASGRA_parModes.txt' 
    temp <- read.csv(file_params, sep="\t")
    parcol         <- 2 + 8*(s-1)
    source(sitesettings_filenames[[s]])
    output <- run_model()
    file_table  = paste("model_outputs/basgra_trace_table_",s,".txt", sep="")
    file_plot   = paste("model_outputs/basgra_trace_plots_",s,".png", sep="")
    export_output(file_table=file_table, file_plot=file_plot)
  }
  
  #
  cat(file=stderr(), 'Finished BC_BASGRA_Scott.r', "\n")
  # dyn.unload(BASGRA_DLL) 
  