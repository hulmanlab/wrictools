if (file.exists("config.R")) {
  source("config.R")
} else {
  cat("RedCap API configuration file 'config.R' not found. Proceeding without.\n")
}


library(RCurl)
library(dplyr)
library(readr)
library(stringr)
library(roxygen2)

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

  # Standardize lengths to avoid errors - might have to rename your documents manually if there are eg IDs missing
  adjust_length <- function(data, reference) {
    length_diff <- length(reference) - length(data)
    if (length_diff > 0) {
      data <- c(data, rep(NA, length_diff))  # Pad with NAs if too short (no comment)
    } else if (length_diff < 0) {
      data <- data[1:length(reference)]  # Truncate if too long (new lines in comment)
    }
    return(data)
  }

  header_lines[[2]] <- adjust_length(header_lines[[2]], header_lines[[1]][-1])
  header_lines[[4]] <- adjust_length(header_lines[[4]], header_lines[[3]][-1])

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
  df$`relative_time` <- as.numeric(difftime(df$datetime, start_time, units = "mins"))
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
  if ((is.null(start) || is.na(start)) && (is.null(end) || is.na(end))){
    return(df) 
  } else if (is.na(start)) {
    start <- min(df$datetime, na.rm = TRUE) 
  } else if (is.na(end)) {
    end <- max(df$datetime, na.rm = TRUE)
  }
  start <- as.POSIXct(start)
  end <- as.POSIXct(end)
  
  return(df[df$datetime >= start & df$datetime <= end, ])
}

update_protocol <- function(df, protocol_list) {
  # Helper function for extract_note_info() that updates the protocol column based on a data frame.
  # Not intended for modular use.
  current_protocol <- 0
  current_index <- 1 
  
  # Ensure protocol_list is a data frame and check for empty data frame
  if (nrow(protocol_list) == 0) {
    return(df)  # If no protocols, return original DataFrame
  }
  
  for (i in seq_len(nrow(df))) {
    # While there are more timestamps and the current row's datetime is greater than or equal to the timestamp
    while (current_index <= nrow(protocol_list) &&
           df$datetime[i] >= protocol_list[current_index, "timestamp"]) {
      current_protocol <- protocol_list[current_index, "protocol"]  # Update current protocol
      current_index <- current_index + 1  # Move to the next timestamp
    }
    
    df$protocol[i] <- current_protocol
  }
  
  return(df)
}

save_dict <- function(dict_protocol, participant, datetime, value) {
  # Helper function for extract_note_info() that updates a list based on parameters.
  # Not intended for modular use.
  
  if (!is.null(participant)) {
    dict_protocol[[as.character(participant)]][[as.character(datetime)]] <- value
  } else {
    dict_protocol[["1"]][[as.character(datetime)]] <- value
    dict_protocol[["2"]][[as.character(datetime)]] <- value
  }
  
  return(dict_protocol)
}

detect_start_end <- function(notes_path) {
#' Automatically detect enter and exit from the chamber based on the notefile.
#' Returns the start and end times for two participants.
#'
#' @param notes_path string - path to the note file
#' @return list - A list of two elements ("1" and "2"), each containing a tuple (start, end) time.
#'                Returns NA if not possible to find start or end time.
#' @keywords chamber entry exit detection
  
  keywords_dict <- list(
    end = c("ud", "exit", "out"),
    start = c("ind i kammer", "enter", "ind", "entry")
  )
  
  # Read the note file and create a DataFrame
  notes_content <- readLines(notes_path)
  lines <- strsplit(notes_content[-c(1, 2)], "\t")
  df_note <- data.frame(matrix(unlist(lines), ncol = length(lines[[1]]), byrow = TRUE))
  colnames(df_note) <- unlist(lines[[1]])
  df_note <- na.omit(df_note)
  
  # Combine to datetime
  df_note$datetime <- as.POSIXct(
    paste(df_note$Date, df_note$Time), format = "%m/%d/%y %H:%M:%S"
  )
  df_note <- df_note[, !(names(df_note) %in% c("Date", "Time"))]
  
  start_end_times <- list("1" = c(NA, NA), "2" = c(NA, NA))
  
  for (i in seq_len(nrow(df_note))) {
    comment <- tolower(df_note$Comment[i])
    participants <- if (grepl("^1", comment)) {
      c("1")
    } else if (grepl("^2", comment)) {
      c("2")
    } else {
      c("1", "2")
    }
    
    for (participant in participants) {
      if (is.na(start_end_times[[participant]][1]) &&
          any(grepl(paste(keywords_dict$start, collapse = "|"), comment))) {
        first_three <- head(df_note$datetime, 4) #there is one empty line, one for clock check and then up to two saying when there going in, rest is not searched
        if (df_note$datetime[i] %in% first_three) {
          start_end_times[[participant]][1] <- df_note$datetime[i]
        }
      } else if (is.na(start_end_times[[participant]][2]) &&
                 any(grepl(paste(keywords_dict$end, collapse = "|"), comment))) {
        last_two <- tail(df_note$datetime, 2) #only checking the last two rows
        if (df_note$datetime[i] %in% last_two) {
          start_end_times[[participant]][2] <- df_note$datetime[i]
        }
      }
    }
  }
  # convert back to POSIXct datetime format
  start_end_times <- lapply(start_end_times, function(times) {
    lapply(times, function(t) as.POSIXct(t, origin = "1970-01-01"))
  })
  return(start_end_times)
}
extract_note_info <- function(notes_path, df_room1, df_room2, keywords_dict = NULL) {
  #' Extracts and processes note information from a specified notes file, categorizing events 
  #' based on predefined keywords, and updates two DataFrames with protocol information for 
  #' different participants.
  #'
  #' @param notes_path string - The file path to the notes file containing event data.
  #' @param df_room1 DataFrame - DataFrame for participant 1, to be updated with protocol info.
  #' @param df_room2 DataFrame - DataFrame for participant 2, to be updated with protocol info.
  #' @param keywords_dict nested list - used to identify keywords to extract protocol values
  #' @return list - A list containing two updated DataFrames:
  #'         - `df_room1`: Updated DataFrame for participant 1 with protocol data.
  #'         - `df_room2`: Updated DataFrame for participant 2 with protocol data.
  #'
  #' @note
  #' - The 'Comment' field should start with '1' or '2' to indicate the participant, 
  #'   or it may be empty to indicate both.
  #' - The `keywords_dict` can be modified to fit specific study protocols, 
  #'   with multi-group checks for keyword matching.

  # Define keywords dictionary
  if (is.null(keywords_dict)) {
    keywords_dict <- list(
      sleeping = list(keywords = list(c("seng", "sleeping", "bed", "sove", "soeve", "godnat", "night", "sleep")), value = 1), 
      eating = list(keywords = list(c("start", "begin", "began"), c("maaltid", "måltid", "eat", "meal", "food", "spis", "maal", "måd", "mad", "frokost", "morgenmad", "middag", "snack", "aftensmad")), value = 2), 
      stop_sleeping = list(keywords = list(c("vaagen", "vågen", "vaekke", "væk", "wake", "woken", "vaagnet")), value = 0), 
      stop_anything = list(keywords = list(c("faerdig", "færdig", "stop", "end ", "finished", "slut")), value = 0), 
      activity = list(keywords = list(c("start", "begin", "began"), c("step", "exercise", "physical activity", "active", "motion", "aktiv")), value = 3), 
      ree_start = list(keywords = list(c("start", "begin", "began"), c("REE", "BEE", "BMR", "RMR", "RER")), value = 4)
    )
  }

  # Load note file and create DataFrame
  notes_content <- readLines(notes_path, encoding = "UTF-8")
  lines <- strsplit(notes_content[-(1:2)], "\t")
  df_note <- as.data.frame(do.call(rbind, lines[-(1:2)]), stringsAsFactors = FALSE)
  colnames(df_note) <- unlist(lines[[1]])
  df_note <- na.omit(df_note)

  # Convert to datetime
  df_note$datetime <- as.POSIXct(paste(df_note$Date, df_note$Time), format = "%m/%d/%y %H:%M:%S")
  df_note <- df_note[, !names(df_note) %in% c("Date", "Time")]

  # Time pattern and dictionary for protocols
  time_pattern <- "([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5]\\d"
  drift_pattern <- "^\\d{2}:\\d{2}(:\\d{2})?$"
  dict_protocol <- list("1" = list(), "2" = list())
  drift <- NULL
  
  for (i in seq_len(nrow(df_note))) {
    row <- df_note[i, ]
    comment <- tolower(row$Comment)
    comment <- iconv(comment, to = "UTF-8")
    participant <- ifelse(grepl("^1", comment), "1", ifelse(grepl("^2", comment), "2", c("1", "2")))

    # Check for time drift in the first entry
    if (i == 1 && grepl(drift_pattern, row$Comment)) {
      new_datetime <- as.POSIXct(paste(as.Date(row$datetime), row$Comment), format = "%Y-%m-%d %H:%M:%S")
      drift <- new_datetime - row$datetime
      
      message("Drift: ", drift)
      # Apply drift to dataframes
      df_room1$datetime <- df_room1$datetime + drift
      df_room2$datetime <- df_room2$datetime + drift
      next
    }

    for (category in names(keywords_dict)) {
      entry <- keywords_dict[[category]]
      keywords <- entry$keywords
      value <- entry$value
      
      if (length(keywords) > 1) {
        # Multi-group keyword check
        if (all(sapply(keywords, function(group) any(grepl(paste(group, collapse = "|"), comment, ignore.case = TRUE))))) {
          match <- regmatches(comment, regexpr(time_pattern, comment))
          
          if (length(match) > 0) {
            new_datetime <- as.POSIXct(paste(as.Date(row$datetime), match), format = "%Y-%m-%d %H:%M")
            dict_protocol[[participant]] <- append(dict_protocol[[participant]], list(list(timestamp = new_datetime, protocol = value)))
          } else {
            dict_protocol[[participant]] <- append(dict_protocol[[participant]], list(list(timestamp = row$datetime, protocol = value)))
          }
        }
      } else {
        # Single-group keyword check
        if (any(sapply(keywords, function(group) any(grepl(paste(group, collapse = "|"), comment, ignore.case = TRUE))))) {
          match <- regmatches(comment, regexpr(time_pattern, comment))
          
          if (length(match) > 0) {
            new_datetime <- as.POSIXct(paste(as.Date(row$datetime), match), format = "%Y-%m-%d %H:%M")
            dict_protocol[[participant]] <- append(dict_protocol[[participant]], list(list(timestamp = new_datetime, protocol = value)))
          } else {
            dict_protocol[[participant]] <- append(dict_protocol[[participant]], list(list(timestamp = row$datetime, protocol = value)))
          }
        }
      }
    }
  }

  # Convert dict_protocol into a data frame and sort it
  protocol_list_1 <- do.call(rbind, lapply(dict_protocol[["1"]], function(x) data.frame(timestamp = x$timestamp, protocol = x$protocol)))
  protocol_list_2 <- do.call(rbind, lapply(dict_protocol[["2"]], function(x) data.frame(timestamp = x$timestamp, protocol = x$protocol)))
  
  # Sort by timestamp
  protocol_list_1 <- protocol_list_1[order(protocol_list_1$timestamp), ]
  protocol_list_2 <- protocol_list_2[order(protocol_list_2$timestamp), ]

  # Adding the time drift parameter
  if (!is.null(drift)){
    protocol_list_1$timestamp <- protocol_list_1$timestamp + drift
    protocol_list_2$timestamp <- protocol_list_2$timestamp + drift
  }
  # Update DataFrames with sorted protocol lists
  df_room1 <- update_protocol(df_room1, protocol_list_1)
  df_room2 <- update_protocol(df_room2, protocol_list_2)

  return(list(df_room1 = df_room1, df_room2 = df_room2))
}




create_wric_df <- function(filepath, lines, save_csv, code_1, code_2, path_to_save, start, end, notefilepath) {
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

  df_room1 <- df %>%
    select(contains('R1')) %>%
    mutate(datetime = df$datetime)
  df_room2 <- df %>%
    select(contains('R2')) %>%
    mutate(datetime = df$datetime)

  
  
  # Cut to only include desired rows (do before setting the relative time)    
  if (!is.null(start) && !is.null(end)) {
    df_room1 <- cut_rows(df_room1, start, end)
    df_room2 <- cut_rows(df_room2, start, end)
  } else if (!is.null(notefilepath)) {
    se_times <- detect_start_end(notefilepath)
    start_1 <- as.POSIXct(se_times[[1]][[1]], origin = "1970-01-01")
    end_1 <- as.POSIXct(se_times[[1]][[2]], origin = "1970-01-01")
    start_2 <- as.POSIXct(se_times[[2]][[1]], origin = "1970-01-01")
    end_2 <- as.POSIXct(se_times[[2]][[2]], origin = "1970-01-01")

    if (!is.null(start)) {
        start_1 <- start
        start_2 <- start
    }
    if (!is.null(end)) {
      end_1 <- end
      end_2 <- end
    }
    df_room1 <- cut_rows(df_room1, start_1, end_1)
    df_room2 <- cut_rows(df_room2, start_2, end_2)
    print(paste("Starting time for room 1 is", start_1, "and end", end_1, 
                "and for room 2 start is", start_2, "and end", end_2))
  } else {
    df_room1 <- cut_rows(df_room1, start, end)
    df_room2 <- cut_rows(df_room2, start, end)
  }
  df_room1 <- add_relative_time(df_room1)
  df_room2 <- add_relative_time(df_room2)
  
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

preprocess_WRIC_file <- function(filepath, code = "id", manual = NULL, save_csv = TRUE, path_to_save = NULL, combine = TRUE, method = "mean", start = NULL, end = NULL, notefilepath = NULL, keywords_dict = NULL) {
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
#' @param notefilepath String, Directory path of the corresponding note file (.txt)
#' @param keywords_dict Nested List, used to extract protocol values from note file
#' @return A list containing the metadata and DataFrames for Room 1 and Room 2.
  lines <- open_file(filepath)
  result <- extract_meta_data(lines, code, manual, save_csv, path_to_save)
  R1_metadata <- result$R1_metadata
  R2_metadata <- result$R2_metadata
  code_1 <- result$code_1
  code_2 <- result$code_2
  result <- create_wric_df(filepath, lines, save_csv, code_1, code_2, path_to_save, start, end, notefilepath)
  df_room1 <- result$df_room1
  df_room2 <- result$df_room2
  
  if (combine) {
    df_room1 <- combine_measurements(df_room1, method)
    df_room2 <- combine_measurements(df_room2, method)
  }

  if (!is.null(notefilepath)) {
    result <- extract_note_info(notefilepath, df_room1, df_room2, keywords_dict)
    df_room1 <- result$df_room1
    df_room2 <- result$df_room2
  }
  
  if (save_csv) {
    room1_filename <- ifelse(!is.null(path_to_save), paste0(path_to_save, "/", code_1, "_WRIC_data.csv"), paste0(code_1, "_WRIC_data.csv"))
    room2_filename <- ifelse(!is.null(path_to_save), paste0(path_to_save, "/", code_2, "_WRIC_data.csv"), paste0(code_2, "_WRIC_data.csv"))
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

doc <- function(func_name) {
#' Returns the documentation for this function from the function_docs.R file. This is a temporary option, until this is made into a package.
#' 
#' @param funcname String, name of the function
  func <- get(func_name, envir = .GlobalEnv)
  doc <- attr(func, "doc")
  if (!is.null(doc)) {
    cat(doc, "\n")
  } else {
    cat("No documentation available.\n")
  }
}


# Dynamically attach documentation to all functions (if doc_strings is available)
if (exists("doc_strings", envir = .GlobalEnv)) {
  print(doc_strings)
  for (func_name in names(doc_strings)) {
    if (exists(func_name, envir = .GlobalEnv)) {
      func <- get(func_name, envir = .GlobalEnv)
      attr(func, "doc") <- doc_strings[[func_name]]
    }
  }
}