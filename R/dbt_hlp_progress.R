#' dbt_hlp_progress
#'
#' @param i ith iteration / item / job / query
#' @param ii number of iterations / ... in total
#' @param start start time
#' @param redraw ?
#' @param now ?
#' @param m ?
#'
#' @export
#'
#' @examples
#'
#' dbt_hlp_progress(1)
#' dbt_hlp_progress(3, 10, Sys.time()-10)
#'
dbt_hlp_progress <-
  function(i = NULL, ii = NULL, start = NULL, redraw = FALSE, now = Sys.time(), m = ""){
    if(redraw){
      cat("\r")
    }else{
      cat("\n")
    }
    cat( as.character(now) )

    if( !is.null(i) ){
      cat(" |", format(i, big.mark = ",") )
    }

    if( !is.null(ii) ){
      cat(" /", format(ii, big.mark = ","))
    }

    if( !is.null(start) ){
      cat(
        " | elapsed:",
        as.character(
          hms::as.hms(
            max(
              1,
              round(
                difftime(now, start, units="sec")
              )
            )
          )
        )
      )
    }

    if( !is.null(start) & !is.null(i) & !is.null(ii)){
      time_elapsed <- max(0.0001, as.integer(difftime(now, start, units="sec")))
      time_eta     <- (time_elapsed / i) * (ii - i)
      percent_done <- time_elapsed / (time_elapsed + time_eta)
      time_elapsed <- round(time_elapsed)

      cat(" | eta:", as.character(hms::as.hms(round(time_eta))))

      cat(
        " |",
        rep("=",   max(0, min(round(percent_done*10), 10)) ) ,
        rep(".",   max(0, min(round((1-percent_done)*10), 10)) ) ,
        "| ",
        m,
        sep = ""
      )
    }else{
      cat(" |", m)
    }
  }
