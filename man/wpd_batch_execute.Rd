% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/wpd_batch_execute.R
\name{wpd_batch_execute}
\alias{wpd_batch_execute}
\title{wpd_batch_execute}
\usage{
wpd_batch_execute(SQL_GEN_FUNCTION, BATCH_SIZE = c(10000, 1000, 100, 1),
  CON = NULL, ...)
}
\arguments{
\item{SQL_GEN_FUNCTION}{a function that will generate a SQL statement for a batch length of each dot parameter and that will be called for each batch to be executed}

\item{BATCH_SIZE}{a series of batch sizes to go through - errors in the SQL execution will lead to going down the batch size list}

\item{CON}{an optional connection object - if NULL, wpd_connect will be used to establish a new connection}

\item{...}{parameter passed through to sql_gen_function}
}
\description{
wpd_batch_execute
}
