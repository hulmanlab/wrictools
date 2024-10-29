source('config.R')
library(RCurl)
library(dplyr)
library(readr)
library(stringr)

check_code <- function(code, manual, R1_metadata, R2_metadata) {
#' Check the subject ID code and return corresponding Room 1 and Room 2 codes.
#' 
#' @param code Type of code to use: "id", "id+comment", or "manual".
#' @param manual A list of custom codes for Room 1 and Room 2, required if `code` is "manual".
#' @param R1_metadata, R2_metadata DataFrames for metadata of Room 1 and Room 2, containing "Subject ID" and "Comments".
#' @return A list containing the codes for Room 1 and Room 2.
  if (code == "id") {
    code_1 <- R1_metadata$`Subject.ID`[1]
    code_2 <- R2_metadata$`Subject.ID`[1]
  } else if (code == "id+comment") {
    code_1 <- paste0(R1_metadata$`Subject.ID`[1], '_', R1_metadata$`Comments`[1])
    code_2 <- paste0(R2_metadata$`Subject.ID`[1], '_', R2_metadata$`Comments`[1])
  } else if (code == "manual" && !is.null(manual)) {
    code_1 <- manual[1]
    code_2 <- manual[2]
  } else {
    stop("Invalid code parameter. Choose 'id', 'id+comment', or 'manual'.")
  }
  return(c(code_1, code_2))
}

extract_meta_data <- function(lines, code, manual, save_csv, path_to_save) {
#' Extracts metadata for two subjects from text lines and optionally saves it as CSV files.
#' 
#' @param lines List of strings containing the WRIC metadata.
#' @param code Method for generating subject IDs ("id", "id+comment", or "manual").
#' @param manual Custom codes for Room 1 and Room 2 subjects if `code` is "manual".
#' @param save_csv Logical, whether to save extracted metadata to CSV files.
#' @param path_to_save Directory path for saving CSV files, NULL uses the current directory.
#' @return A list containing the Room 1 code, Room 2 code, and DataFrames for R1_metadata and R2_metadata.
  header_lines <- lapply(lines[4:7], function(line) unlist(strsplit(trimws(line), "\t")))
  data_R1 <- setNames(as.list(header_lines[[2]]), header_lines[[1]][-1])
  data_R2 <- setNames(as.list(header_lines[[4]]), header_lines[[3]][-1])
  
  R1_metadata <- as.data.frame(data_R1, stringsAsFactors = FALSE)
  R2_metadata <- as.data.frame(data_R2, stringsAsFactors = FALSE)
  
  codes <- check_code(code, manual, R1_metadata, R2_metadata)
  
  if (save_csv) {
    room1_filename <- ifelse(!is.null(path_to_save), paste0(path_to_save, "/", codes[[1]], "_WRIC_metadata.csv"), paste0(codes[[1]], "_WRIC_metadata.csv"))
    room2_filename <- ifelse(!is.null(path_to_save), paste0(path_to_save, "/", codes[[2]], "_WRIC_metadata.csv"), paste0(codes[[2]], "_WRIC_metadata.csv"))
    write.csv(R1_metadata, room1_filename, row.names = FALSE)
    write.csv(R2_metadata, room2_filename, row.names = FALSE)
  }
  
  return(list(code_1 = codes[1], code_2 = codes[2], R1_metadata = R1_metadata, R2_metadata = R2_metadata))
}

open_file <- function(filepath) {
#' Opens a WRIC .txt file and reads its contents.
#' 
#' @param filepath Path to the WRIC .txt file.
#' @return A list of strings representing the lines of the file.
#' @note Raises an error if the file is not a valid WRIC data file.
  if (!grepl("\\.txt$", tolower(filepath))) {
    stop("The file must be a .txt file.")
  }
  lines <- readLines(filepath)
  if (length(lines) == 0 || !grepl("^OmniCal software", lines[1])) {
    stop("The provided file is not a valid WRIC data file.")
  }
  return(lines)
}

add_relative_time <- function(df, start_time=NULL) {
#' Add Relative Time in minutes to DataFrame. Rows before the start_time will be indicated negative.
#'
#' @param df A data frame containing a 'datetime' column.
#' @param start_time Optional; the starting time for calculating relative time. 
#'                   Should be in a format compatible with POSIXct (eg. "2023-11-13 11:40:00")
#' @return A data frame with an additional column 'relative_time[min]' indicating
#'         the time in minutes from the start time.
  if (is.null(start_time)) {
    start_time <- df$datetime[1]
  }
  start_time <- as.POSIXct(start_time)
  df$`relative_time[min]` <- as.numeric(difftime(df$datetime, start_time, units = "mins"))
  return(df)
}

cut_rows <- function(df, start = NULL, end = NULL) {
  #' Filters rows in a DataFrame based on an optional start and end datetime range.
  #'
  #' @param df data.frame
  #'   DataFrame with a "datetime" column to filter.
  #' @param start character or POSIXct or NULL, optional; 
  #'    Start datetime; rows before this will be removed. If NULL, uses the earliest datetime in the DataFrame.
  #' @param end character or POSIXct or NULL, optional
  #'   End datetime; rows after this will be removed. If NULL, uses the latest datetime in the DataFrame.
  #'
  #' @return data.frame
  #'   DataFrame with rows between the specified start and end dates, or the full DataFrame if both are NULL.
  
  df$datetime <- as.POSIXct(df$datetime)
  
  if (is.null(start) && is.null(end)) {
    return(df) 
  } else if (is.null(start)) {
    start <- min(df$datetime, na.rm = TRUE) 
  } else if (is.null(end)) {
    end <- max(df$datetime, na.rm = TRUE)
  }
  
  start <- as.POSIXct(start)
  end <- as.POSIXct(end)
  
  return(df[df$datetime >= start & df$datetime <= end, ])
}


create_wric_df <- function(filepath, lines, save_csv, code_1, code_2, path_to_save, start, end) {
#' Creates DataFrames for WRIC data from a file and optionally saves them as CSV files.
#' 
#' @param filepath Path to the WRIC .txt file.
#' @param lines List of strings read from the file to locate the data start.
#' @param save_csv Logical, whether to save DataFrames as CSV files.
#' @param code_1, code_2 Strings representing the codes for Room 1 and Room 2.
#' @param path_to_save Directory path for saving CSV files, NULL uses the current directory.
#' @return A list containing DataFrames for Room 1 and Room 2 measurements.
#' @note Raises an error if Date or Time columns are inconsistent across rows.
#' 

  data_start_index <- which(grepl("^Room 1 Set 1", lines)) + 1
  df <- read_tsv(filepath, skip = data_start_index, col_names = FALSE)

    # Drop columns with all NA values
  df <- df %>% select(where(~ !all(is.na(.))))
  
  # Define new column names
  columns <- c("Date", "Time", "VO2", "VCO2", "RER", "FiO2", "FeO2", "FiCO2", "FeCO2", "Flow", 
               "Activity Monitor", "Energy Expenditure (kcal/min)", "Energy Expenditure (kJ/min)", 
               "Pressure Ambient", "Temperature", "Relative Humidity")
  new_columns <- c()
  for (set_num in c('S1', 'S2')) {
    for (room in c('R1', 'R2')) {
      new_columns <- c(new_columns, paste0(room, "_", set_num, "_", columns))
    }
  }
  colnames(df) <- new_columns

  # Check for consistent Date and Time columns
  date_columns <- df %>% select(contains('Date'))
  time_columns <- df %>% select(contains('Time'))
  if (!all(apply(date_columns, 1, function(x) length(unique(x)) == 1)) || 
      !all(apply(time_columns, 1, function(x) length(unique(x)) == 1))) {
    stop("Date or Time columns do not match in some rows")
  }
  
  # Combine Date and Time to DateTime
  df <- df %>%
    mutate(
        R1_S1_Date = as.character(R1_S1_Date),
        R1_S1_Time = as.character(R1_S1_Time)
    )
  datetime <- as.POSIXct(paste(df$R1_S1_Date, df$R1_S1_Time), format = "%m/%d/%y %H:%M:%S")
  df$datetime <- datetime

  # delete now unnecessary date and time columns
  columns_to_drop <- c(grep("Time", names(df), ignore.case=FALSE, value = TRUE), grep("Date", names(df), ignore.case=FALSE, value = TRUE))
  df <- df %>% select(-all_of(columns_to_drop))

  df <- cut_rows(df, start, end)

  df <- add_relative_time(df)

  df_room1 <- df %>%
    select(contains('R1')) %>%
    mutate(datetime = df$datetime) %>%
    mutate(`relative_time[min]` = df$`relative_time[min]`) 
  df_room2 <- df %>%
    select(contains('R2')) %>%
    mutate(datetime = df$datetime) %>%
    mutate(`relative_time[min]` = df$`relative_time[min]`) 
  
  if (save_csv) {
    room1_filename <- ifelse(!is.null(path_to_save), paste0(path_to_save, "/", code_1, "_WRIC_data.csv"), paste0(code_1, "_WRIC_data.csv"))
    room2_filename <- ifelse(!is.null(path_to_save), paste0(path_to_save, "/", code_2, "_WRIC_data.csv"), paste0(code_2, "_WRIC_data.csv"))
    write.csv(df_room1, room1_filename, row.names = FALSE)
    write.csv(df_room2, room2_filename, row.names = FALSE)
  }
  
  return(list(df_room1 = df_room1, df_room2 = df_room2))
}

check_discrepancies <- function(df, threshold = 0.05, individual = FALSE) {
#' @description Checks for discrepancies between S1 and S2 measurements in the DataFrame and prints them to the console.
#' This function is not included in the big pre-processing function, as it is more intended to 
#' perform a quality check on your data and not to automatically inform the processing of the data.
#' @param df DataFrame containing WRIC data with columns for S1 and S2 measurements.
#' @param threshold Numeric threshold percentage for mean relative delta discrepancies (default 0.05).
#' @param individual Logical, if TRUE checks and reports individual row discrepancies beyond the threshold (default FALSE).
#' @return None. Prints discrepancies to the console.
  env_params <- c('Pressure Ambient', 'Temperature', 'Relative Humidity', 'Activity Monitor')
  df_filtered <- df %>% select(-contains(env_params))
  
  s1_columns <- df_filtered %>% select(contains('_S1_')) %>% names()
  s2_columns <- df_filtered %>% select(contains('_S2_')) %>% names()
  
  discrepancies <- c()
  
  for (i in seq_along(s1_columns)) {
    s1_values <- df[[s1_columns[i]]]
    s2_values <- df[[s2_columns[i]]]
    avg_values <- (s1_values + s2_values) / 2
    
    relative_deltas <- (s1_values - s2_values) / avg_values
    mean_relative_delta <- mean(relative_deltas, na.rm = TRUE)
    
    discrepancies <- c(discrepancies, sprintf("%s and %s have a mean relative delta of %.4f.", s1_columns[i], s2_columns[i], mean_relative_delta))
    
    if (abs(mean_relative_delta) > (threshold / 100)) {
      discrepancies <- c(discrepancies, sprintf("%s and %s exceed the %.2f%% threshold.", s1_columns[i], s2_columns[i], threshold))
    } else {
      discrepancies <- c(discrepancies, sprintf("%s and %s are within the %.2f%% threshold.", s1_columns[i], s2_columns[i], threshold))
    }
    
    if (individual) {
      for (j in seq_along(relative_deltas)) {
        if (abs(relative_deltas[j]) > (threshold / 100)) {
          discrepancies <- c(discrepancies, sprintf("Row %d: %s and %s differ by a relative delta of %.4f.", j, s1_columns[i], s2_columns[i], relative_deltas[j]))
        }
      }
    }
  }
  
  cat(discrepancies, sep = "\n")
}

combine_measurements <- function(df, method = 'mean') {
#' Combines S1 and S2 measurements in the DataFrame using the specified method.
#' 
#' @param df DataFrame containing WRIC data with S1 and S2 measurement columns.
#' @param method String specifying the method to combine measurements ("mean", "median", "s1", "s2", "min", "max").
#' @return A DataFrame with combined measurements.
  s1_columns <- df %>% select(contains('_S1_')) %>% names()
  s2_columns <- df %>% select(contains('_S2_')) %>% names()
  non_s_columns <- names(df)[!names(df) %in% c(s1_columns, s2_columns)]
  
  combined <- df[, non_s_columns]
  combined <- as.data.frame(combined)
  
  for (i in seq_along(s1_columns)) {
    if (method == 'mean') {
      combined_values <- (df[[s1_columns[i]]] + df[[s2_columns[i]]]) / 2
    } else if (method == 'median') {
      combined_values <- apply(cbind(df[[s1_columns[i]]], df[[s2_columns[i]]]), 1, median)
    } else if (method == 's1') {
      combined_values <- df[[s1_columns[i]]]
    } else if (method == 's2') {
      combined_values <- df[[s2_columns[i]]]
    } else if (method == 'min') {
      combined_values <- pmin(df[[s1_columns[i]]], df[[s2_columns[i]]], na.rm = TRUE)
    } else if (method == 'max') {
      combined_values <- pmax(df[[s1_columns[i]]], df[[s2_columns[i]]], na.rm = TRUE)
    } else {
      stop("Method not supported. Use 'mean', 'median', 's1', 's2', 'min', or 'max'.")
    }
    column_name <- sub("^.*?_S[12]_", "", s1_columns[i])
    combined[[column_name]] <- combined_values
  }
  
  return(combined)
}

preprocess_WRIC_file <- function(filepath, code = "id", manual = NULL, save_csv = TRUE, path_to_save = NULL, combine = TRUE, method = "mean", start = NULL, end = NULL) {
#' Preprocesses a WRIC data file, extracting metadata, creating DataFrames, and optionally saving results.
#' 
#' @param filepath Path to the WRIC .txt file.
#' @param code Method for generating subject IDs ("id", "id+comment", or "manual").
#' @param manual Custom codes for subjects in Room 1 and Room 2 if `code` is "manual".
#' @param save_csv Logical, whether to save extracted metadata and data to CSV files.
#' @param path_to_save Directory path for saving CSV files, NULL uses the current directory.
#' @param combine Logical, whether to combine S1 and S2 measurements.
#' @param method Method for combining measurements ("mean", "median", "s1", "s2", "min", "max").
#' @param start character or POSIXct or NULL, rows before this will be removed, if NULL takes first row e.g "2023-11-13 11:43:00"
#' @param end character or POSIXct or NULL, rows after this will be removed, if NULL takes last rows e.g "2023-11-13 11:43:00"
#' @return A list containing the metadata and DataFrames for Room 1 and Room 2.
  lines <- open_file(filepath)
  result <- extract_meta_data(lines, code, manual, save_csv, path_to_save)
  R1_metadata <- result$R1_metadata
  R2_metadata <- result$R2_metadata
  code_1 <- result$code_1
  code_2 <- result$code_2
  result <- create_wric_df(filepath, lines, save_csv, code_1, code_2, path_to_save, start, end)
  df_room1 <- result$df_room1
  df_room2 <- result$df_room2
  
  if (combine) {
    df_room1 <- combine_measurements(df_room1, method)
    df_room2 <- combine_measurements(df_room2, method)
  }
  
  if (save_csv) {
    room1_filename <- ifelse(!is.null(path_to_save), paste0(path_to_save, "/", code_1, "_WRIC_data_combined.csv"), paste0(code_1, "_WRIC_data_combined.csv"))
    room2_filename <- ifelse(!is.null(path_to_save), paste0(path_to_save, "/", code_2, "_WRIC_data_combined.csv"), paste0(code_2, "_WRIC_data_combined.csv"))
    write.csv(df_room1, room1_filename, row.names = FALSE)
    write.csv(df_room2, room2_filename, row.names = FALSE)
  }

  return(list(R1_metadata = R1_metadata , R2_metadata = R2_metadata, df_room1 = df_room1, df_room2 = df_room2))
}

export_file_from_redcap <- function(record_id, fieldname, path = './tmp/export.raw.txt') {
#' Exports a file from REDCap based on the specified record ID and field name.
#' 
#' @param record_id String containing the unique identifier for the record in REDCap.
#' @param fieldname Field name from which to export the file.
#' @param path File path where the exported file will be saved.
#' @return None. The file is saved to the specified path.

  # avoid cross-plattform errors by setting the certificate globally
  download.file(url = "https://curl.se/ca/cacert.pem", destfile = "cacert.pem")
  options(RCurlOptions = list(cainfo = "cacert.pem"))

  result <- postForm(
    api_url,
    token=api_token,
    content='file',
    action='export',
    record=record_id,
    field=fieldname
  )
  
  filepath <- if (!is.null(path)) path else "./tmp/export.raw.txt"

  f <- file(filepath, "wb")
  writeLines(result, f)
  close(f)
  
}

upload_file_to_redcap <- function(filepath, record_id, fieldname) {
#' Uploads a file to REDCap for a specified record ID and field name.
#' 
#' @param filepath Path to the file to be uploaded.
#' @param record_id String containing the unique identifier for the record in REDCap.
#' @param fieldname Field name to which the file will be uploaded.
#' @return None. Prints the HTTP status code of the request.
 
  # avoid cross-plattform errors by setting the certificate globally
  download.file(url = "https://curl.se/ca/cacert.pem", destfile = "cacert.pem")
  options(RCurlOptions = list(cainfo = "cacert.pem"))
  
  file_content <- paste(readLines(filepath), collapse = "\n")
  result <- postForm(
    api_url,
    token=api_token,
    content='file',
    action='import',
    record=record_id,
    field=fieldname,
    returnFormat='json',
    file = file_content
  )
}

preprocess_WRIC_files <- function(csv_file, fieldname, code = "id", manual = NULL, 
                                  save_csv = TRUE, path_to_save = NULL, combine = TRUE, method = "mean", start = NULL, end = NULL) {
#' Preprocesses a WRIC data file, extracting metadata, creating DataFrames, and optionally saving results.
#' 
#' @param csv_file Path to the CSV file containing record IDs.
#' @param fieldname The field name for exporting WRIC data.
#' @param code Method for generating subject IDs ("id", "id+comment", or "manual").
#' @param manual Custom codes for subjects in Room 1 and Room 2 if `code` is "manual".
#' @param save_csv Logical, whether to save extracted metadata and data to CSV files.
#' @param path_to_save Directory path for saving CSV files, NULL uses the current directory.
#' @param combine Logical, whether to combine S1 and S2 measurements.
#' @param method Method for combining measurements ("mean", "median", "s1", "s2", "min", "max").
#' #' @param start character or POSIXct or NULL, rows before this will be removed, if NULL takes first row e.g "2023-11-13 11:43:00"
#' @param end character or POSIXct or NULL, rows after this will be removed, if NULL takes last rows e.g "2023-11-13 11:43:00"
#' @return A list where each key is a record ID and each value is a list with: (R1_metadata, R2_metadata, df_room1, df_room2).
  
  # Read record IDs from CSV
  record_ids <- read_csv(csv_file, col_names = FALSE)$X1
  
  # Initialize list to store data for each record ID
  dataframes <- list()
  
  for (record_id in record_ids) {
    # Assume export_file_from_redcap is a defined function
    export_file_from_redcap(record_id, fieldname)
    
    # Call preprocess_WRIC_file function (this should be defined elsewhere)
    result <- preprocess_WRIC_file("./tmp/export.raw.txt", code, manual, save_csv, path_to_save, combine, method, start, end)
    
    # Store the results for the record ID
    dataframes[[as.character(record_id)]] <- list(
      R1_metadata = result$R1_metadata,
      R2_metadata = result$R2_metadata,
      df_room1 = result$df_room1,
      df_room2 = result$df_room2
    )
  }
  
  return(dataframes)
}
