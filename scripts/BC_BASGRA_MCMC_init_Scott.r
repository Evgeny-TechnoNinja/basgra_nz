## BC_BASGRA_MCMC_init_Saerheim_00_early_Gri.R ##

## MCMC chain length
   nChain        <- as.integer(1000)
   # note: nBurnin       <- as.integer(nChain/10)
   

## FILE FOR PRIOR PARAMETER DISTRIBUTION
   shape <- 4 # shape parameter (0=noninformative, 4=previous method)
   file_prior    <- "model_inputs/parameters_BC_Scott.txt"
   # 5 columns
   # name  minimum  mode  maximum  (beta distribution)  unknown
   # require
   # .	DLMXGE > DAYLB 
   # .	TOPTGE > TBASE 
   # .	FSMAX has a theoretical upper limit < 1. 
   # .	HAGERE <= 1 
   # .	SHAPE <= 1 
   # .	SLAMAX > SLAMIN 
   # .	TRANCO may have physical limits [a,b] where a>0 and b<infinity. 
   # .	YG < 1 because it is the Growth Yield, the fraction of C allocated to growth that 
   #      actually ends up in new biomass, with the remainder being lost to growth respiration. 
   
## LIKELIHOOD FUNCTION ##
   source('scripts/fLogL_Sivia.R')
   source('scripts/fLogL_mm_Beta.R')
   
## SETTINGS FOR THE DIFFERENT CALIBRATION SITES (at least one site)
   sitesettings_filenames <- c("scripts/initialise_BASGRA_Scott.r")
   sitedata_filenames     <- c("model_inputs/data_calibration_Scott.txt")
   nSites                 <- length(sitedata_filenames)
   sitelist               <- list() ; length(sitelist) <- nSites

   cv_default    <- rep( 0.5 , nSites )
   cv_DM         <- rep( 0.05, nSites ) ; sd_DM_min     <- rep(   0, nSites )
   cv_LAI        <- rep( 0.1 , nSites ) ; sd_LAI_min    <- rep(   0, nSites )
   cv_TILTOT     <- rep( 0.2 , nSites ) ; sd_TILTOT_min <- rep(   0, nSites )
   cv_YIELD      <- rep( 0.05, nSites ) ; sd_YIELD_min  <- rep(   0, nSites )
   sd_LT50       <- rep( 5   , nSites )
   cv_mm_default <- rep( 0.2 , nSites )
   cv_mm_FRTILG  <- rep( 0.2 , nSites )
   
## PROPOSAL TUNING FACTOR  
   fPropTuning   <- 0.05 # This factor is used to modify Gelman's suggested average step length
                         # (2.38^2 / np_BC) which seems too big

## GENERAL INITIALISATION FOR MCMC
   source('scripts/BC_BASGRA_MCMC_init_general.R')
