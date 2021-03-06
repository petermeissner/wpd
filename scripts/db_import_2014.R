

# packages
library(wpd)
library(dplyr)
library(future)
library(future.apply)


# options
plan("multisession", workers = 3)
import_date <- "2014"



# get distribution of jobs
topology <- wpd_db_topology()


# filter
topo <-
  topology %>%
  select(
    task_date,
    task_lang,
    job_status,
    job_progress,
    job_run_node,
    job_end_ts
  ) %>%
  filter(
    substring(task_date, 1, 4) == import_date
  ) %>%
  group_by(
    task_date,
    task_lang
  ) %>%
  mutate(
    progress_max = max(job_progress),
    ts_max       = max(job_end_ts),
    n            = n()
  ) %>%
  filter(
    job_progress == progress_max,
    ts_max       == ts_max,
    job_status   == "done"
  )

topo <-
  topo[!duplicated(topo[, c("task_date", "task_lang")]), ] %>%
  ungroup()



sql <-
  wpd_sql(
    "CREATE TABLE if not exists page_views_%s_%s_import (
    page_id int4 NULL,
    page_view_date date NULL,
    page_view_count int4 NULL
  )
    ;
    ",
    wpd_languages,
    import_date
    )
for(i in seq_along(sql)) wpd_get_query_master(sql[i])


wpd_get_query_master(
  "create table if not exists import_jobs (
  page_view_lang varchar,
  page_view_date date,
  import_status varchar,
  import_update_ts timestamp default now(),
  import_start_ts timestamp default now()
)"
)


sql_list <- list()
for( i in seq_len(nrow(topo)) ){

  if( topo$job_run_node[i] == "" ){
    sql <- ""
  } else if( wpd_nodes[topo$job_run_node[i]] == Sys.info()["nodename"] ){
    sql <-
      wpd_sql(
        "insert into page_views_%s_%s_import
        select page_id, page_view_date, sum(page_view_count)
        from page_views_%s where page_view_date = '%s'::date
        group by page_id, page_view_date
        ;
        ",
        topo$task_lang[i],
        import_date,
        topo$task_lang[i],
        topo$task_date[i]
      )
  }else{
    sql <-
      wpd_sql(
        "insert into page_views_%s_%s_import
        select page_id, page_view_date, sum(page_view_count) from
        dblink(
        'dbname=wikipedia port=5432 host=%s user=%s password=%s',
        'select * from page_views_%s where page_view_date = ''%s''::date')
        as dings(page_id int4, page_view_date date, page_view_count int4)
        group by page_id, page_view_date
        ;
        ",
        topo$task_lang[i],
        import_date,
        wpd_nodes[topo$job_run_node[i]],
        Sys.getenv("wpd_user"),
        Sys.getenv("wpd_password"),
        topo$task_lang[i],
        topo$task_date[i]
      )
  }

  sql_list[[ length(sql_list) + 1 ]] <-
    data_frame(
      page_view_date = topo$task_date[i],
      page_view_lang = topo$task_lang[i],
      node           = topo$job_run_node[i],
      sql            = sql
    )
}


sql_df      <- do.call(rbind, sql_list)
sql_df      <- sample_n(sql_df, nrow(sql_df))
sql_df_list <- split(sql_df, seq_len(nrow(sql_df)))







results <-
  do.call(
    rbind,
    future_lapply(
      X   = sql_df_list,
      FUN =
        function(df){


          jobs <-
            wpd_get_query_master(
              wpd_sql(
                "select * from import_jobs
                where page_view_date ='%s'::date and
                page_view_lang = '%s'
                ",
                df$page_view_date,
                df$page_view_lang
              )
            )$return

          if ( nrow(jobs) == 0 ){
            wpd_get_query_master(
              wpd_sql(
                "insert into import_jobs (page_view_lang, page_view_date, import_status)
                values ('%s', '%s', '%s')",
                df$page_view_lang,
                df$page_view_date,
                "init"
              )
            )
            jobs <-
              wpd_get_query_master(
                wpd_sql(
                  "select * from import_jobs
                  where page_view_date ='%s'::date and
                  page_view_lang = '%s'
                  ",
                  df$page_view_date,
                  df$page_view_lang
                )
              )$return
          }

          if ( jobs$import_status %in% c("start", "done") ){

            message("done already: ", df$page_view_date, " ", df$page_view_lang)
            df$sql    <- NULL
            df$status <- "done already"
            return(df)

          } else {

            message(
              "started:   ", df$page_view_date, " ", df$page_view_lang,
              " -- ", as.character(Sys.time()), " -- start"
            )

            if ( jobs$import_status %in% "error" ) {
              wpd_get_query_master(
                wpd_sql(
                  "delete from page_views_%s_%s_import where page_view_date = '%s'::date",
                  df$page_view_lang,
                  import_date,
                  df$page_view_date
                )
              )
            }

            wpd_get_query_master(
              wpd_sql(
                "update import_jobs
                set import_status = 'start',
                import_update_ts = now()
                where page_view_date = '%s'::date and page_view_lang = '%s'",
                df$page_view_date,
                df$page_view_lang
              )
            )


            res <- wpd_get_query_master(df$sql)
            if ( res$status$errorMsg == "OK" ){
              status <- "done"
            }else{
              status <- "error"
            }


            wpd_get_query_master(
              wpd_sql(
                "update import_jobs set import_status = '%s',
                import_update_ts = now()
                where page_view_date = '%s'::date and page_view_lang = '%s'",
                status,
                df$page_view_date,
                df$page_view_lang
              )
            )

            message(
              "processed: ", df$page_view_date, " ", df$page_view_lang,
              " -- ", as.character(Sys.time()), " -- ",status
            )
            df$sql    <- NULL
            df$status <- status
            return(df)
          }

        }
            )
            )
results










