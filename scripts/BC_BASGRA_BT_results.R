# Show results of Bayesian calibration of BASGRA model using BayesianTools package

# 
cat(file=stderr(), 'Results of calibrating BASGRA using BayesianTools package', "\n")
suppressMessages({
  library(tidyverse)
  library(BayesianTools)
  library(coda)
})

# calibration summary ####
invisible(capture.output(cmatrix <- summary(bt_out), # this gets correlation matrix into cmatrix
                         file=paste("model_outputs/BC_summary_BT.txt",sep=""))) # and export text summary

# correlation matrix ####
if (TRUE){
  cat(file=stderr(), 'Plot largest cells of posterior correlation grid', "\n")
  nmatrix <- dim(cmatrix)[1]
  flat <- tibble(row=rep(1:nmatrix, times=nmatrix),
                     col=rep(1:nmatrix,  each=nmatrix),
                     val=as.vector(cmatrix)) %>%
            filter(row>col) %>%
            mutate(absval=abs(val)) %>%
            arrange(desc(absval))
  whichc <- 1:6 # most correlated parameters
  whichx <- match(c("RUBISC", "SIMAX1T"), parname_BC) # additional params to check
  whichp <- unique(c(flat$row[whichc], flat$col[whichc], whichx))
  png( paste("model_outputs/BC_parameters_correlations_BT.png",sep=""),
       width=11*3, height=8*3, units="in", type="windows", res=300)  
  correlationPlot(bt_out, whichParameters=whichp) # parameter correlation plot, very slow and big!
  dev.off()
}

# traceplots (multiple plots) ####
if (FALSE){
  tracePlot(bt_out) # parameter traces (don't know how to combine onto one sheet)
}

# prior and posterior histograms (old Basgra one is nicer) ####
if (FALSE){
  cat(file=stderr(), 'Plot prior/posterior histograms', "\n")
  png( paste("model_outputs/BC_parameters_histograms_BT.png",sep=""),
       width=11*3, height=8*3, units="in", type="windows", res=300)  
  marginalPlot(bt_out) # prior and posterior histograms (scaled parameters)
  dev.off()
}

# gelman convergence plots (multiple plots) ####
if (FALSE){
  # gelmanDiagnostics(bt_out, plot=TRUE, 
  #                   start=1, 
  #                   end=nChain/(nInternal*nChains)) # Rhat for each parameter
  gelman.plot(getSample(bt_out, coda=TRUE), ylim=c(1.0,1.5))
}

# prediction function ####
# https://github.com/florianhartig/BayesianTools/blob/master/Examples/PlotTimeSeriesResults.Rmd
if (TRUE){
  
  source('scripts/plotResiduals_BT.r') # replacement functions
  
  bt_predict <- function(par){ # needs s and data_col
    # use loop from BC_BASGRA_MCMC.R  
    candidatepValues_BC   <- par * sc
    # for (s in 1:nSites) {
      params         <- list_params        [[s]] # get site parameters initial values (in parameters.txt)
      matrix_weather <- list_matrix_weather[[s]] # get site weather
      days_harvest   <- list_days_harvest  [[s]] # get site harvest
      NDAYS          <- list_NDAYS         [[s]] # get site NDAYS
      # ip_BC_site[[s]] = indicies of model parameters being changed (in parameters.txt)
      # icol_pChain_site[[s]] = indices of calibration parameters being used (in parameters_BC.txt)
      params[ ip_BC_site[[s]] ] <- candidatepValues_BC[ icol_pChain_site[[s]] ]
      output                    <- run_model(params,matrix_weather,days_harvest,NDAYS)
      # list_output[[s]]          <- output
    # }
    this_output                 <- output[,data_col] 
    this_output[is.na(this_output)] <- -999 # catch NA
    return(this_output)
  }

  # error function
  bt_error <- function(mean, par){
    return(rnorm(length(mean), mean=mean, sd=bt_error_constant)) # copied from VSEM vignette, weird
  }
  
  # plot predictive results for each site
  s <- 1
  for (s in 1:nSites){ 

    # predictins against data
    cat(file=stderr(), 'Plot model calibration fits against data, site', s, "\n")
    # pdf( paste('model_outputs/BC_calibration_fits_BT_', s, '.pdf',sep=""),
    #      width=pagew, height=pageh)
    png( paste('model_outputs/BC_calibration_fits_BT_', s, '.png',sep=""),
         width=11, height=8, units="in", type="windows", res=300)

    # set up plot grid
    noutputsMeasured     <- length(unique(data_index[[s]]))
    nrowsPlots           <- ceiling(sqrt(noutputsMeasured+1))
    ncolsPlots           <- ceiling((noutputsMeasured+1)/nrowsPlots)
    oldpar <- par(mfrow=c(nrowsPlots,ncolsPlots),omi=c(0,0,0.5,0), mar=c(2, 2, 2, 1) )
    
    # statistics calculations
    calc_rmse <- function(m,d){
      if (length(m)==0 && length(d)==0){
        NA_real_
      } else {
        sqrt(mean((m-d)^2, na.rm=TRUE))
      }
    }
    calc_rsq <- function(m,d){
      if (length(m)==0 && length(d)==0){
        NA_real_
      } else {
        d[is.na(m)] <- NA
        1-mean((m-d)^2, na.rm=TRUE)/var(d, na.rm=TRUE)
      }
    }

    # loop through calibration variables
    data_col <- 1
    bt_pred_times <- bt_predict(scparMAP_BC)
    data_col <- unique(data_index[[s]])[[1]]
    for (data_col in unique(data_index[[s]])){ 
      p <- data_col
      datap     <- which( data_name[[s]] == as.character(outputNames[p]) ) # which data points are this variable?
      bt_obs_rows <- list_output_calibr_rows[[s]]
      bt_obs_vals <- rep( as.double(NA), list_NDAYS[[s]] )
      bt_obs_vals[bt_obs_rows[datap]] <- data_value[[s]][datap]
      bt_obs_wts <- rep( 0, list_NDAYS[[s]] )
      bt_obs_wts[bt_obs_rows[datap]] <- data_weight[[s]][datap]
      # bt_obs_vals[bt_obs_wts==0] <- NA # remove unweighted data
      bt_obs_errs <- rep( as.double(NA), list_NDAYS[[s]] )
      bt_obs_errs[bt_obs_rows[datap]] <- data_sd[[s]][datap] # note: errors are constant
      bt_error_constant <- data_sd[[s]][datap][1] 
      # bt_obs_times <- data_year[[s]][datap]+(data_doy[[s]][datap]-0.5)/366
      bt_pred_MAP <- bt_predict(scparMAP_BC)
      bt_pred_MAP_obs <- bt_pred_MAP
      bt_pred_MAP_obs[is.na(bt_obs_vals)] <- NA
      keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts>0)
      rmse <- calc_rmse(bt_pred_MAP_obs[keeps], bt_obs_vals[keeps])
      rsq <- calc_rsq(bt_pred_MAP_obs[keeps], bt_obs_vals[keeps])
      keeps2 <- (!is.na(bt_obs_vals)) & (bt_obs_wts==0)
      rmse2 <- calc_rmse(bt_pred_MAP_obs[keeps2], bt_obs_vals[keeps2])
      rsq2 <- calc_rsq(bt_pred_MAP_obs[keeps2], bt_obs_vals[keeps2])
      bt_pred_ML <- bt_predict(scparMaxL_BC)
      scparMode_BC <- parmode_BC / sc
      bt_pred_Mode <- bt_predict(scparMode_BC)
      if (TRUE){
        pred <- getPredictiveIntervals(parMatrix=pChain,
                                       model=bt_predict,
                                       numSamples=1000,
                                       quantiles=c(0.05, 0.5, 0.95),
                                       error=bt_error)
        plotTimeSeries <- function(observed = NULL, predicted = NULL, x = NULL, xlim = NULL,
                                   confidenceBand = NULL, predictionBand = NULL, 
                                   xlab = "Time", ylab = "Observed / predicted values", ...){
          ylim = range(observed, predicted, confidenceBand, predictionBand,na.rm=TRUE)
          # ylim = range(observed, predicted, na.rm=TRUE)
          if (is.null(x)){
            if(!is.null(observed)) x = 1:length(observed)
            else if(!is.null(predicted)) x = 1:length(predicted)
            else stop("either observed or predicted must be supplied")
          }
          len = length(x)
          plot(x, y=rep(0,len), xlim = xlim, ylim = ylim, type = "n", xlab = xlab, ylab = ylab, ...)
          if(!is.null(predictionBand)) 
            polygon(c(x,rev(x)),c(predictionBand[1,],predictionBand[2,len:1]),col="moccasin",border=NA)
          # polygon(c(1:len,len:1),c(predictionBand[1,],predictionBand[2,len:1]),col="moccasin",border=NA)
          if(!is.null(confidenceBand)) 
            polygon(c(x,rev(x)),c(confidenceBand[1,],confidenceBand[2,len:1]),col="#99333380",border=NA)    
          # polygon(c(1:len,len:1),c(confidenceBand[1,],confidenceBand[2,len:1]),col="#99333380",border=NA)    
          if(!is.null(predicted)) lines(x, predicted, col = "red")
          if(!is.null(observed)) points(x, observed, col = "black", pch = 3, cex = 0.6)
        }
        predicted <- pred$posteriorPredictivePredictionInterval[2,]
        confidenceBand <- pred$posteriorPredictiveCredibleInterval[c(1,3),]
        predictionBand <- pred$posteriorPredictivePredictionInterval[c(1,3),]
        plotTimeSeries(       observed = bt_obs_vals, 
                              predicted = predicted,
                              confidenceBand = confidenceBand,
                              predictionBand = predictionBand,
                              x=bt_pred_times,
                              # xlim=c(2012,2015), # show only a subset of time line (else = NULL)
                              main=paste(easyNames[data_col], outputUnits[data_col], 
                                         "RSME_MAP =", signif(rmse,3), "/", signif(rmse2,3),
                                         "RSQ_MAP =", signif(rsq,3), "/", signif(rsq2,3))
        )
        # plot key prediction lines
        lines(x=bt_pred_times, y=bt_pred_Mode, col=NA)
        lines(x=bt_pred_times, y=bt_pred_ML, col="lightblue")
        lines(x=bt_pred_times, y=bt_pred_MAP, col="blue")
        # plot all data
        keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts==0)
        x_obs <- bt_pred_times[keeps]
        suppressWarnings({
          arrows(x0=x_obs, y0=bt_obs_vals[keeps], 
                 x1=x_obs, y1=bt_pred_MAP_obs[keeps], 
                 col="black", lwd=1.5, angle=45, length=0.05) # residual
          arrows(x0=x_obs, y0=bt_obs_vals[keeps]-bt_obs_errs[keeps]*1.96, 
                 x1=x_obs, y1=bt_obs_vals[keeps]+bt_obs_errs[keeps]*1.96, 
                 col="grey", lwd=1.5, angle=90, code=3, length=0.05) # error bars
        })
        points( x=x_obs, y=bt_obs_vals[keeps], 
                pch=16, col="grey", cex=1.5)
        # plot weighted data
        keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts>0)
        x_obs <- bt_pred_times[keeps]
        suppressWarnings({
          arrows(x0=x_obs, y0=bt_obs_vals[keeps], 
                 x1=x_obs, y1=bt_pred_MAP_obs[keeps], 
                 col="black", lwd=1.5, angle=45, length=0.05) # residual
          arrows(x0=x_obs, y0=bt_obs_vals[keeps]-bt_obs_errs[keeps]*1.96, 
                 x1=x_obs, y1=bt_obs_vals[keeps]+bt_obs_errs[keeps]*1.96, 
                 col="darkblue", lwd=1.5, angle=90, code=3, length=0.05) # error bars
        })  
        points( x=x_obs, y=bt_obs_vals[keeps], 
                pch=16, col="darkblue", cex=1.5)
      }

    } # next data_col
    
    # legend and title
    plot(1, type='n', axes=FALSE, xlab="", ylab="") # empty plot with legend
    legend( "bottomright", title="Predictions", 
            legend=c("Prior Mode", "Median", "Max L",      "MAP",      "Calib Data", "Other Data", "Residuals"),
            # col   =c(NA,  "red",    "lightblue",  "blue",     "darkblue",   "grey",       "black"), 
            col   =c(NA,  "red",    "lightblue",  "blue",     "darkblue",   "grey",       "black"), 
            lty=1, lwd=1)
    sitenames <- gsub( ".R", "", sub(".*BASGRA_","",sitesettings_filenames) )
    mtext( paste("SITE ",s," (",sitenames[s],")",sep=""),
           side=3, line=1, outer=TRUE, cex=1, font=2)   
    
    # close figure
    dev.off() 
    par(oldpar)

    # residual analysis
    if (FALSE){
      cat(file=stderr(), 'Plot residual analysis, site', s, "\n")
      data_col <- unique(data_index[[s]])[[1]]
      for (data_col in unique(data_index[[s]])){ 
        p <- data_col
        datap     <- which( data_name[[s]] == as.character(outputNames[p]) ) # which data points are this variable?
        bt_obs_rows <- list_output_calibr_rows[[s]]
        bt_obs_vals <- rep( as.double(NA), list_NDAYS[[s]] )
        bt_obs_vals[bt_obs_rows[datap]] <- data_value[[s]][datap]
        bt_obs_wts <- rep( 0, list_NDAYS[[s]] )
        bt_obs_wts[bt_obs_rows[datap]] <- data_weight[[s]][datap]
        bt_obs_vals[bt_obs_wts==0] <- NA # remove unweighted data
        bt_obs_errs <- rep( as.double(NA), list_NDAYS[[s]] )
        bt_obs_errs[bt_obs_rows[datap]] <- data_sd[[s]][datap] # note: errors are constant
        bt_error_constant <- data_sd[[s]][datap][1] 
        # bt_obs_times <- data_year[[s]][datap]+(data_doy[[s]][datap]-0.5)/366
        bt_pred_MAP <- bt_predict(scparMAP_BC)
        bt_pred_MAP_obs <- bt_pred_MAP
        bt_pred_MAP_obs[is.na(bt_obs_vals)] <- NA
        bt_pred_ML <- bt_predict(scparMaxL_BC)
        scparMode_BC <- parmode_BC / sc
        bt_pred_Mode <- bt_predict(scparMode_BC)
        if (TRUE){ # this doesn't work with par(mfrow) but gives analysis of residuals
          # try({ # ignore errors thrown some subplots
          # debug(plotTimeSeriesResults)
          suppressMessages({
            plotTimeSeriesResults(sampler=pChain,
                                  model=bt_predict,
                                  observed=bt_obs_vals,
                                  error=bt_error,
                                  main=paste("Site", s, easyNames[data_col]," ",outputUnits[data_col])
                                  )
          })
          # }, silent=TRUE)
          # save
          dev.copy(png, paste("model_outputs/Residuals_Site_", s, "_", easyNames[data_col], ".png", sep=""), 
                   width = 480*2, height = 480*2)
          dev.off()
        }
      } # next data_col
    }
    
    # plot other model outputs
    if (TRUE){
      cat(file=stderr(), 'Plot model calibration other outputs, site', s, "\n")
      png( paste('model_outputs/BC_calibration_other_BT_', s, '.png',sep=""),
           width=11, height=8, units="in", type="windows", res=300)
      
      # set up plot grid
      data_cols <- match(extraOutputs, outputNames)
      noutputsMeasured     <- length(data_cols)
      nrowsPlots           <- ceiling(sqrt(noutputsMeasured+1))
      ncolsPlots           <- ceiling((noutputsMeasured+1)/nrowsPlots)
      oldpar <- par(mfrow=c(nrowsPlots,ncolsPlots),omi=c(0,0,0.5,0), mar=c(2, 2, 2, 1) )
      
      # loop through other selected variables
      for (data_col in data_cols){ 
        p <- data_col
        # datap     <- which( data_name[[s]] == as.character(outputNames[p]) ) # which data points are this variable?
        # bt_obs_rows <- list_output_calibr_rows[[s]]
        # bt_obs_vals <- rep( as.double(NA), list_NDAYS[[s]] )
        # bt_obs_vals[bt_obs_rows[datap]] <- data_value[[s]][datap]
        # bt_obs_wts <- rep( 0, list_NDAYS[[s]] )
        # bt_obs_wts[bt_obs_rows[datap]] <- data_weight[[s]][datap]
        # # bt_obs_vals[bt_obs_wts==0] <- NA # remove unweighted data
        # bt_obs_errs <- rep( as.double(NA), list_NDAYS[[s]] )
        # bt_obs_errs[bt_obs_rows[datap]] <- data_sd[[s]][datap] # note: errors are constant
        bt_error_constant <- 0 
        # bt_obs_times <- data_year[[s]][datap]+(data_doy[[s]][datap]-0.5)/366
        bt_pred_MAP <- bt_predict(scparMAP_BC)
        bt_pred_MAP_obs <- bt_pred_MAP
        bt_pred_MAP_obs[is.na(bt_obs_vals)] <- NA
        bt_pred_ML <- bt_predict(scparMaxL_BC)
        scparMode_BC <- parmode_BC / sc
        bt_pred_Mode <- bt_predict(scparMode_BC)
        if (TRUE){
          pred <- getPredictiveIntervals(parMatrix=pChain,
                                         model=bt_predict,
                                         numSamples=1000,
                                         quantiles=c(0.05, 0.5, 0.95),
                                         error=bt_error)
          plotTimeSeries <- function(observed = NULL, predicted = NULL, x = NULL, xlim = NULL,
                                     confidenceBand = NULL, predictionBand = NULL, 
                                     xlab = "Time", ylab = "Observed / predicted values", ...){
            ylim = range(observed, predicted, confidenceBand, predictionBand,na.rm=TRUE)
            # ylim = range(observed, predicted, na.rm=TRUE)
            if (is.null(x)){
              if(!is.null(observed)) x = 1:length(observed)
              else if(!is.null(predicted)) x = 1:length(predicted)
              else stop("either observed or predicted must be supplied")
            }
            len = length(x)
            plot(x, y=rep(0,len), xlim = xlim, ylim = ylim, type = "n", xlab = xlab, ylab = ylab, ...)
            if(!is.null(predictionBand)) 
              polygon(c(x,rev(x)),c(predictionBand[1,],predictionBand[2,len:1]),col="moccasin",border=NA)
            # polygon(c(1:len,len:1),c(predictionBand[1,],predictionBand[2,len:1]),col="moccasin",border=NA)
            if(!is.null(confidenceBand)) 
              polygon(c(x,rev(x)),c(confidenceBand[1,],confidenceBand[2,len:1]),col="#99333380",border=NA)    
            # polygon(c(1:len,len:1),c(confidenceBand[1,],confidenceBand[2,len:1]),col="#99333380",border=NA)    
            if(!is.null(predicted)) lines(x, predicted, col = "red")
            if(!is.null(observed)) points(x, observed, col = "black", pch = 3, cex = 0.6)
          }
          predicted <- pred$posteriorPredictivePredictionInterval[2,]
          confidenceBand <- pred$posteriorPredictiveCredibleInterval[c(1,3),]
          predictionBand <- pred$posteriorPredictivePredictionInterval[c(1,3),]
          plotTimeSeries(       predicted = predicted,
                                confidenceBand = confidenceBand,
                                predictionBand = predictionBand,
                                x=bt_pred_times,
                                # xlim=c(2012,2015), # show only a subset of time line (else = NULL)
                                main=paste(easyNames[data_col], outputUnits[data_col])
          )
          # plot key prediction lines
          lines(x=bt_pred_times, y=bt_pred_Mode, col=NA)
          lines(x=bt_pred_times, y=bt_pred_ML, col="lightblue")
          lines(x=bt_pred_times, y=bt_pred_MAP, col="blue")
          # plot all data
          # keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts==0)
          # x_obs <- bt_pred_times[keeps]
          # suppressWarnings({
          #   arrows(x0=x_obs, y0=bt_obs_vals[keeps], 
          #          x1=x_obs, y1=bt_pred_MAP_obs[keeps], 
          #          col="black", lwd=1.5, angle=45, length=0.05) # residual
          #   arrows(x0=x_obs, y0=bt_obs_vals[keeps]-bt_obs_errs[keeps]*1.96, 
          #          x1=x_obs, y1=bt_obs_vals[keeps]+bt_obs_errs[keeps]*1.96, 
          #          col="grey", lwd=1.5, angle=90, code=3, length=0.05) # error bars
          # })
          # points( x=x_obs, y=bt_obs_vals[keeps], 
          #         pch=16, col="grey", cex=1.5)
          # # plot weighted data
          # keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts>0)
          # x_obs <- bt_pred_times[keeps]
          # suppressWarnings({
          #   arrows(x0=x_obs, y0=bt_obs_vals[keeps], 
          #          x1=x_obs, y1=bt_pred_MAP_obs[keeps], 
          #          col="black", lwd=1.5, angle=45, length=0.05) # residual
          #   arrows(x0=x_obs, y0=bt_obs_vals[keeps]-bt_obs_errs[keeps]*1.96, 
          #          x1=x_obs, y1=bt_obs_vals[keeps]+bt_obs_errs[keeps]*1.96, 
          #          col="darkblue", lwd=1.5, angle=90, code=3, length=0.05) # error bars
          # })  
          # points( x=x_obs, y=bt_obs_vals[keeps], 
          #         pch=16, col="darkblue", cex=1.5)
        }
        
      } # next data_col
      
      # legend and title
      plot(1, type='n', axes=FALSE, xlab="", ylab="") # empty plot with legend
      legend( "bottomright", title="Predictions", 
              legend=c("Prior Mode", "Median", "Max L",      "MAP",      "Calib Data", "Other Data", "Residuals"),
              # col   =c(NA,  "red",    "lightblue",  "blue",     "darkblue",   "grey",       "black"), 
              col   =c(NA,  "red",    "lightblue",  "blue",     "darkblue",   "grey",       "black"), 
              lty=1, lwd=1)
      sitenames <- gsub( ".R", "", sub(".*BASGRA_","",sitesettings_filenames) )
      mtext( paste("SITE ",s," (",sitenames[s],")",sep=""),
             side=3, line=1, outer=TRUE, cex=1, font=2) 
      
      # close figure
      dev.off() 
      par(oldpar)
    }
    
  } # next site
  
}

# new predictions with modified inputs ####
# code copied from previous section and slightly modified
if (FALSE){
  
  source('scripts/plotResiduals_BT.r') # replacement functions
  
  bt_predict <- function(par){ # needs s and data_col
    # use loop from BC_BASGRA_MCMC.R  
    candidatepValues_BC   <- par * sc
    # for (s in 1:nSites) {
    params         <- list_params        [[s]] # get site parameters initial values (in parameters.txt)
    matrix_weather <- list_matrix_weather[[s]] # get site weather
    days_harvest   <- list_days_harvest  [[s]] # get site harvest
    NDAYS          <- list_NDAYS         [[s]] # get site NDAYS
    # ip_BC_site[[s]] = indicies of model parameters being changed (in parameters.txt)
    # icol_pChain_site[[s]] = indices of calibration parameters being used (in parameters_BC.txt)
    params[ ip_BC_site[[s]] ] <- candidatepValues_BC[ icol_pChain_site[[s]] ]
    
    # put changes here ####
    # ii <- seq(length(days_harvest)/3*2+1, length(days_harvest))
    # days_harvest[ii] <- as.integer(days_harvest[ii]*0.9) # reduce grazing by 10%
    #  1  32  60  91 121 152 182 213 244 274 305 335
    ii <- matrix_weather[,2] %in% c(274,305,335,1,32,60,91,121)
    matrix_weather[ii,6] <- matrix_weather[ii,6] + 50.0 # irrigate
    
    output                    <- run_model(params,matrix_weather,days_harvest,NDAYS)
    # list_output[[s]]          <- output
    # }
    this_output                 <- output[,data_col] 
    this_output[is.na(this_output)] <- -999 # catch NA
    return(this_output)
  }
  
  # error function
  bt_error <- function(mean, par){
    return(rnorm(length(mean), mean=mean, sd=bt_error_constant)) # copied from VSEM vignette, weird
  }
  
  # plot predictive results for each site
  s <- 1
  for (s in 1:nSites){ 
    
    # predictins against data
    cat(file=stderr(), 'Plot new model predictions against data, site', s, "\n")
    # pdf( paste('model_outputs/BC_calibration_fits_BT_', s, '.pdf',sep=""),
    #      width=pagew, height=pageh)
    png( paste('model_outputs/BC_predictions_BT_', s, '.png',sep=""),
         width=11, height=8, units="in", type="windows", res=300)
    
    # set up plot grid
    noutputsMeasured     <- length(unique(data_index[[s]]))
    nrowsPlots           <- ceiling(sqrt(noutputsMeasured+1))
    ncolsPlots           <- ceiling((noutputsMeasured+1)/nrowsPlots)
    oldpar <- par(mfrow=c(nrowsPlots,ncolsPlots),omi=c(0,0,0.5,0), mar=c(2, 2, 2, 1) )
    
    # statistics calculations
    calc_rmse <- function(m,d){
      if (length(m)==0 && length(d)==0){
        NA_real_
      } else {
        sqrt(mean((m-d)^2, na.rm=TRUE))
      }
    }
    calc_rsq <- function(m,d){
      if (length(m)==0 && length(d)==0){
        NA_real_
      } else {
        d[is.na(m)] <- NA
        1-mean((m-d)^2, na.rm=TRUE)/var(d, na.rm=TRUE)
      }
    }
    
    # loop through calibration variables
    data_col <- 1
    bt_pred_times <- bt_predict(scparMAP_BC)
    data_col <- unique(data_index[[s]])[[1]]
    for (data_col in unique(data_index[[s]])){ 
      p <- data_col
      datap     <- which( data_name[[s]] == as.character(outputNames[p]) ) # which data points are this variable?
      bt_obs_rows <- list_output_calibr_rows[[s]]
      bt_obs_vals <- rep( as.double(NA), list_NDAYS[[s]] )
      bt_obs_vals[bt_obs_rows[datap]] <- data_value[[s]][datap]
      bt_obs_wts <- rep( 0, list_NDAYS[[s]] )
      bt_obs_wts[bt_obs_rows[datap]] <- data_weight[[s]][datap]
      # bt_obs_vals[bt_obs_wts==0] <- NA # remove unweighted data
      bt_obs_errs <- rep( as.double(NA), list_NDAYS[[s]] )
      bt_obs_errs[bt_obs_rows[datap]] <- data_sd[[s]][datap] # note: errors are constant
      bt_error_constant <- data_sd[[s]][datap][1] 
      # bt_obs_times <- data_year[[s]][datap]+(data_doy[[s]][datap]-0.5)/366
      bt_pred_MAP <- bt_predict(scparMAP_BC)
      bt_pred_MAP_obs <- bt_pred_MAP
      bt_pred_MAP_obs[is.na(bt_obs_vals)] <- NA
      keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts>0)
      rmse <- calc_rmse(bt_pred_MAP_obs[keeps], bt_obs_vals[keeps])
      rsq <- calc_rsq(bt_pred_MAP_obs[keeps], bt_obs_vals[keeps])
      keeps2 <- (!is.na(bt_obs_vals)) & (bt_obs_wts==0)
      rmse2 <- calc_rmse(bt_pred_MAP_obs[keeps2], bt_obs_vals[keeps2])
      rsq2 <- calc_rsq(bt_pred_MAP_obs[keeps2], bt_obs_vals[keeps2])
      bt_pred_ML <- bt_predict(scparMaxL_BC)
      scparMode_BC <- parmode_BC / sc
      bt_pred_Mode <- bt_predict(scparMode_BC)
      if (TRUE){
        pred <- getPredictiveIntervals(parMatrix=pChain,
                                       model=bt_predict,
                                       numSamples=1000,
                                       quantiles=c(0.05, 0.5, 0.95),
                                       error=bt_error)
        plotTimeSeries <- function(observed = NULL, predicted = NULL, x = NULL, xlim = NULL,
                                   confidenceBand = NULL, predictionBand = NULL, 
                                   xlab = "Time", ylab = "Observed / predicted values", ...){
          ylim = range(observed, predicted, confidenceBand, predictionBand,na.rm=TRUE)
          # ylim = range(observed, predicted, na.rm=TRUE)
          if (is.null(x)){
            if(!is.null(observed)) x = 1:length(observed)
            else if(!is.null(predicted)) x = 1:length(predicted)
            else stop("either observed or predicted must be supplied")
          }
          len = length(x)
          plot(x, y=rep(0,len), xlim = xlim, ylim = ylim, type = "n", xlab = xlab, ylab = ylab, ...)
          if(!is.null(predictionBand)) 
            polygon(c(x,rev(x)),c(predictionBand[1,],predictionBand[2,len:1]),col="moccasin",border=NA)
          # polygon(c(1:len,len:1),c(predictionBand[1,],predictionBand[2,len:1]),col="moccasin",border=NA)
          if(!is.null(confidenceBand)) 
            polygon(c(x,rev(x)),c(confidenceBand[1,],confidenceBand[2,len:1]),col="#99333380",border=NA)    
          # polygon(c(1:len,len:1),c(confidenceBand[1,],confidenceBand[2,len:1]),col="#99333380",border=NA)    
          if(!is.null(predicted)) lines(x, predicted, col = "red")
          if(!is.null(observed)) points(x, observed, col = "black", pch = 3, cex = 0.6)
        }
        predicted <- pred$posteriorPredictivePredictionInterval[2,]
        confidenceBand <- pred$posteriorPredictiveCredibleInterval[c(1,3),]
        predictionBand <- pred$posteriorPredictivePredictionInterval[c(1,3),]
        plotTimeSeries(       observed = bt_obs_vals, 
                              predicted = predicted,
                              confidenceBand = confidenceBand,
                              predictionBand = predictionBand,
                              x=bt_pred_times,
                              # xlim=c(2012,2015), # show only a subset of time line (else = NULL)
                              main=paste(easyNames[data_col], outputUnits[data_col], 
                                         "RSME_MAP =", signif(rmse,3), "/", signif(rmse2,3),
                                         "RSQ_MAP =", signif(rsq,3), "/", signif(rsq2,3))
        )
        # plot key prediction lines
        lines(x=bt_pred_times, y=bt_pred_Mode, col=NA)
        lines(x=bt_pred_times, y=bt_pred_ML, col="lightblue")
        lines(x=bt_pred_times, y=bt_pred_MAP, col="blue")
        # plot all data
        keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts==0)
        x_obs <- bt_pred_times[keeps]
        suppressWarnings({
          arrows(x0=x_obs, y0=bt_obs_vals[keeps], 
                 x1=x_obs, y1=bt_pred_MAP_obs[keeps], 
                 col="black", lwd=1.5, angle=45, length=0.05) # residual
          arrows(x0=x_obs, y0=bt_obs_vals[keeps]-bt_obs_errs[keeps]*1.96, 
                 x1=x_obs, y1=bt_obs_vals[keeps]+bt_obs_errs[keeps]*1.96, 
                 col="grey", lwd=1.5, angle=90, code=3, length=0.05) # error bars
        })
        points( x=x_obs, y=bt_obs_vals[keeps], 
                pch=16, col="grey", cex=1.5)
        # plot weighted data
        keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts>0)
        x_obs <- bt_pred_times[keeps]
        suppressWarnings({
          arrows(x0=x_obs, y0=bt_obs_vals[keeps], 
                 x1=x_obs, y1=bt_pred_MAP_obs[keeps], 
                 col="black", lwd=1.5, angle=45, length=0.05) # residual
          arrows(x0=x_obs, y0=bt_obs_vals[keeps]-bt_obs_errs[keeps]*1.96, 
                 x1=x_obs, y1=bt_obs_vals[keeps]+bt_obs_errs[keeps]*1.96, 
                 col="darkblue", lwd=1.5, angle=90, code=3, length=0.05) # error bars
        })  
        points( x=x_obs, y=bt_obs_vals[keeps], 
                pch=16, col="darkblue", cex=1.5)
      }
      
    } # next data_col
    
    # legend and title
    plot(1, type='n', axes=FALSE, xlab="", ylab="") # empty plot with legend
    legend( "bottomright", title="Predictions", 
            legend=c("Prior Mode", "Median", "Max L",      "MAP",      "Calib Data", "Other Data", "Residuals"),
            # col   =c(NA,  "red",    "lightblue",  "blue",     "darkblue",   "grey",       "black"), 
            col   =c(NA,  "red",    "lightblue",  "blue",     "darkblue",   "grey",       "black"), 
            lty=1, lwd=1)
    sitenames <- gsub( ".R", "", sub(".*BASGRA_","",sitesettings_filenames) )
    mtext( paste("SITE ",s," (",sitenames[s],")",sep=""),
           side=3, line=1, outer=TRUE, cex=1, font=2)   
    
    # close figure
    dev.off() 
    par(oldpar)
    
    # residual analysis
    if (FALSE){
      cat(file=stderr(), 'Plot residual analysis, site', s, "\n")
      data_col <- unique(data_index[[s]])[[1]]
      for (data_col in unique(data_index[[s]])){ 
        p <- data_col
        datap     <- which( data_name[[s]] == as.character(outputNames[p]) ) # which data points are this variable?
        bt_obs_rows <- list_output_calibr_rows[[s]]
        bt_obs_vals <- rep( as.double(NA), list_NDAYS[[s]] )
        bt_obs_vals[bt_obs_rows[datap]] <- data_value[[s]][datap]
        bt_obs_wts <- rep( 0, list_NDAYS[[s]] )
        bt_obs_wts[bt_obs_rows[datap]] <- data_weight[[s]][datap]
        bt_obs_vals[bt_obs_wts==0] <- NA # remove unweighted data
        bt_obs_errs <- rep( as.double(NA), list_NDAYS[[s]] )
        bt_obs_errs[bt_obs_rows[datap]] <- data_sd[[s]][datap] # note: errors are constant
        bt_error_constant <- data_sd[[s]][datap][1] 
        # bt_obs_times <- data_year[[s]][datap]+(data_doy[[s]][datap]-0.5)/366
        bt_pred_MAP <- bt_predict(scparMAP_BC)
        bt_pred_MAP_obs <- bt_pred_MAP
        bt_pred_MAP_obs[is.na(bt_obs_vals)] <- NA
        bt_pred_ML <- bt_predict(scparMaxL_BC)
        scparMode_BC <- parmode_BC / sc
        bt_pred_Mode <- bt_predict(scparMode_BC)
        if (TRUE){ # this doesn't work with par(mfrow) but gives analysis of residuals
          # try({ # ignore errors thrown some subplots
          # debug(plotTimeSeriesResults)
          suppressMessages({
            plotTimeSeriesResults(sampler=pChain,
                                  model=bt_predict,
                                  observed=bt_obs_vals,
                                  error=bt_error,
                                  main=paste("Site", s, easyNames[data_col]," ",outputUnits[data_col])
            )
          })
          # }, silent=TRUE)
          # save
          dev.copy(png, paste("model_outputs/Residuals_Site_", s, "_", easyNames[data_col], ".png", sep=""), 
                   width = 480*2, height = 480*2)
          dev.off()
        }
      } # next data_col
    }
    
    # plot other model outputs
    if (FALSE){
      cat(file=stderr(), 'Plot new model predictions of other outputs, site', s, "\n")
      png( paste('model_outputs/BC_predictions_other_BT_', s, '.png',sep=""),
           width=11, height=8, units="in", type="windows", res=300)
      
      # set up plot grid
      data_cols <- match(extraOutputs, outputNames)
      noutputsMeasured     <- length(data_cols)
      nrowsPlots           <- ceiling(sqrt(noutputsMeasured+1))
      ncolsPlots           <- ceiling((noutputsMeasured+1)/nrowsPlots)
      oldpar <- par(mfrow=c(nrowsPlots,ncolsPlots),omi=c(0,0,0.5,0), mar=c(2, 2, 2, 1) )
      
      # loop through other selected variables
      for (data_col in data_cols){ 
        p <- data_col
        # datap     <- which( data_name[[s]] == as.character(outputNames[p]) ) # which data points are this variable?
        # bt_obs_rows <- list_output_calibr_rows[[s]]
        # bt_obs_vals <- rep( as.double(NA), list_NDAYS[[s]] )
        # bt_obs_vals[bt_obs_rows[datap]] <- data_value[[s]][datap]
        # bt_obs_wts <- rep( 0, list_NDAYS[[s]] )
        # bt_obs_wts[bt_obs_rows[datap]] <- data_weight[[s]][datap]
        # # bt_obs_vals[bt_obs_wts==0] <- NA # remove unweighted data
        # bt_obs_errs <- rep( as.double(NA), list_NDAYS[[s]] )
        # bt_obs_errs[bt_obs_rows[datap]] <- data_sd[[s]][datap] # note: errors are constant
        bt_error_constant <- 0 
        # bt_obs_times <- data_year[[s]][datap]+(data_doy[[s]][datap]-0.5)/366
        bt_pred_MAP <- bt_predict(scparMAP_BC)
        bt_pred_MAP_obs <- bt_pred_MAP
        bt_pred_MAP_obs[is.na(bt_obs_vals)] <- NA
        bt_pred_ML <- bt_predict(scparMaxL_BC)
        scparMode_BC <- parmode_BC / sc
        bt_pred_Mode <- bt_predict(scparMode_BC)
        if (TRUE){
          pred <- getPredictiveIntervals(parMatrix=pChain,
                                         model=bt_predict,
                                         numSamples=1000,
                                         quantiles=c(0.05, 0.5, 0.95),
                                         error=bt_error)
          plotTimeSeries <- function(observed = NULL, predicted = NULL, x = NULL, xlim = NULL,
                                     confidenceBand = NULL, predictionBand = NULL, 
                                     xlab = "Time", ylab = "Observed / predicted values", ...){
            ylim = range(observed, predicted, confidenceBand, predictionBand,na.rm=TRUE)
            # ylim = range(observed, predicted, na.rm=TRUE)
            if (is.null(x)){
              if(!is.null(observed)) x = 1:length(observed)
              else if(!is.null(predicted)) x = 1:length(predicted)
              else stop("either observed or predicted must be supplied")
            }
            len = length(x)
            plot(x, y=rep(0,len), xlim = xlim, ylim = ylim, type = "n", xlab = xlab, ylab = ylab, ...)
            if(!is.null(predictionBand)) 
              polygon(c(x,rev(x)),c(predictionBand[1,],predictionBand[2,len:1]),col="moccasin",border=NA)
            # polygon(c(1:len,len:1),c(predictionBand[1,],predictionBand[2,len:1]),col="moccasin",border=NA)
            if(!is.null(confidenceBand)) 
              polygon(c(x,rev(x)),c(confidenceBand[1,],confidenceBand[2,len:1]),col="#99333380",border=NA)    
            # polygon(c(1:len,len:1),c(confidenceBand[1,],confidenceBand[2,len:1]),col="#99333380",border=NA)    
            if(!is.null(predicted)) lines(x, predicted, col = "red")
            if(!is.null(observed)) points(x, observed, col = "black", pch = 3, cex = 0.6)
          }
          predicted <- pred$posteriorPredictivePredictionInterval[2,]
          confidenceBand <- pred$posteriorPredictiveCredibleInterval[c(1,3),]
          predictionBand <- pred$posteriorPredictivePredictionInterval[c(1,3),]
          plotTimeSeries(       predicted = predicted,
                                confidenceBand = confidenceBand,
                                predictionBand = predictionBand,
                                x=bt_pred_times,
                                # xlim=c(2012,2015), # show only a subset of time line (else = NULL)
                                main=paste(easyNames[data_col], outputUnits[data_col])
          )
          # plot key prediction lines
          lines(x=bt_pred_times, y=bt_pred_Mode, col=NA)
          lines(x=bt_pred_times, y=bt_pred_ML, col="lightblue")
          lines(x=bt_pred_times, y=bt_pred_MAP, col="blue")
          # plot all data
          # keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts==0)
          # x_obs <- bt_pred_times[keeps]
          # suppressWarnings({
          #   arrows(x0=x_obs, y0=bt_obs_vals[keeps], 
          #          x1=x_obs, y1=bt_pred_MAP_obs[keeps], 
          #          col="black", lwd=1.5, angle=45, length=0.05) # residual
          #   arrows(x0=x_obs, y0=bt_obs_vals[keeps]-bt_obs_errs[keeps]*1.96, 
          #          x1=x_obs, y1=bt_obs_vals[keeps]+bt_obs_errs[keeps]*1.96, 
          #          col="grey", lwd=1.5, angle=90, code=3, length=0.05) # error bars
          # })
          # points( x=x_obs, y=bt_obs_vals[keeps], 
          #         pch=16, col="grey", cex=1.5)
          # # plot weighted data
          # keeps <- (!is.na(bt_obs_vals)) & (bt_obs_wts>0)
          # x_obs <- bt_pred_times[keeps]
          # suppressWarnings({
          #   arrows(x0=x_obs, y0=bt_obs_vals[keeps], 
          #          x1=x_obs, y1=bt_pred_MAP_obs[keeps], 
          #          col="black", lwd=1.5, angle=45, length=0.05) # residual
          #   arrows(x0=x_obs, y0=bt_obs_vals[keeps]-bt_obs_errs[keeps]*1.96, 
          #          x1=x_obs, y1=bt_obs_vals[keeps]+bt_obs_errs[keeps]*1.96, 
          #          col="darkblue", lwd=1.5, angle=90, code=3, length=0.05) # error bars
          # })  
          # points( x=x_obs, y=bt_obs_vals[keeps], 
          #         pch=16, col="darkblue", cex=1.5)
        }
        
      } # next data_col
      
      # legend and title
      plot(1, type='n', axes=FALSE, xlab="", ylab="") # empty plot with legend
      legend( "bottomright", title="Predictions", 
              legend=c("Prior Mode", "Median", "Max L",      "MAP",      "Calib Data", "Other Data", "Residuals"),
              # col   =c(NA,  "red",    "lightblue",  "blue",     "darkblue",   "grey",       "black"), 
              col   =c(NA,  "red",    "lightblue",  "blue",     "darkblue",   "grey",       "black"), 
              lty=1, lwd=1)
      sitenames <- gsub( ".R", "", sub(".*BASGRA_","",sitesettings_filenames) )
      mtext( paste("SITE ",s," (",sitenames[s],")",sep=""),
             side=3, line=1, outer=TRUE, cex=1, font=2) 
      
      # close figure
      dev.off() 
      par(oldpar)
    }
    
  } # next site
  
}
