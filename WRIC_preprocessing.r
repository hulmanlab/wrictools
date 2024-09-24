check_code <- function(code, manual, R1_metadata, R2_metadata) {
  # Checks that the code and manual are provided correctly and extracts the subject ID (code)
  
  if (code == "id") {
    code_1 <- R1_metadata[["Subject ID"]][1]
    code_2 <- R2_metadata[["Subject ID"]][1]
    
  } else if (code == "id+comment") {
    code_1 <- paste(R1_metadata[["Subject ID"]][1], R1_metadata[["Comments"]][1], sep = "_")
    code_2 <- paste(R2_metadata[["Subject ID"]][1], R2_metadata[["Comments"]][1], sep = "_")
    
  } else if (code == "manual" || !is.null(manual)) {
    tryCatch({
      code_1 <- manual[[1]]
      code_2 <- manual[[2]]
    }, error = function(e) {
      stop("You have tried to enter a manual code. Please ensure it's a list, e.g., c('1234_visit1', '5678_visit1'), where the first entry is for subject in room 1 and the second for subject in room 2.")
    })
    
  } else {
    stop("The value for the code parameter is not valid. Please choose 'id', 'id+comment', or 'manual'. Default is 'id'.")
  }
  
  return(list(code_1, code_2))
}

extract_meta_data <- function(lines, code, manual = NULL, save_csv = TRUE, path_to_save) {
  # Extract relevant lines for Room 1 and Room 2 metadata
  header_lines <- strsplit(trimws(lines[4:7]), '\t')

  # Create named lists (like dictionaries) for Room 1 and Room 2 metadata
  data_R1 <- setNames(header_lines[[2]], header_lines[[1]][-1])
  data_R2 <- setNames(header_lines[[4]], header_lines[[3]][-1])

  # Convert lists to data frames
  R1_metadata <- as.data.frame(t(data_R1), stringsAsFactors = FALSE)
  R2_metadata <- as.data.frame(t(data_R2), stringsAsFactors = FALSE)

  # Call check_code (you'll need to define check_code function in R)
  code_values <- check_code(code, manual, R1_metadata, R2_metadata)
  code_1 <- code_values[[1]]
  code_2 <- code_values[[2]]

  # Optionally save the data frames as CSV files
  if (save_csv) {
    if (!is.null(path_to_save)) {
      room1_filename <- paste0(path_to_save, "/", code_1, "_WRIC_metadata.csv")
      room2_filename <- paste0(path_to_save, "/", code_2, "_WRIC_metadata.csv")
    } else {
      room1_filename <- paste0(code_1, "_WRIC_metadata.csv")
      room2_filename <- paste0(code_2, "_WRIC_metadata.csv")
    }

    write.csv(R1_metadata, room1_filename, row.names = FALSE)
    write.csv(R2_metadata, room2_filename, row.names = FALSE)
  }


  # Return the values
  return(list(code_1 = code_1, code_2 = code_2, R1_metadata = R1_metadata, R2_metadata = R2_metadata))
}

open_file <- function(filepath) {
  # Check that the provided filepath is a .txt file
  if (!grepl("\\.txt$", tolower(filepath))) {
    stop("The file must be a .txt file.")
  }
  
  # Try to open the file and check the contents
  tryCatch({
    lines <- readLines(filepath, warn = FALSE)
    
    if (length(lines) == 0 || !startsWith(lines[1], "OmniCal software")) {
      stop("The provided file is not the WRIC data file.")
    }
    
    return(lines)
  }, error = function(e) {
    stop("The filepath you provided does not lead to a valid file.")
  })
}

create_wric_df <- function(filepath, lines, save_csv, code_1, code_2, path_to_save) {
  # Find start of data line
  data_start_index <- NA
  for (i in seq_along(lines)) {
    if (startsWith(lines[i], "Room 1 Set 1")) {
      data_start_index <- i
      break
    }
  }
  if (is.na(data_start_index)) {
    stop("Data start line 'Room 1 Set 1' not found.")
  }
  
  # Reading the data starting from where the table begins
  df <- read.csv(filepath, sep = "\t", skip = data_start_index)
  
  # Remove columns with only NA values
  df <- df[, colSums(!is.na(df)) > 0]

  # Define the new column names
  columns <- c(
    "Date", "Time", "VO2", "VCO2", "RER", "FiO2", "FeO2", "FiCO2", "FeCO2", 
    "Flow", "Activity Monitor", "Energy Expenditure (kJ/min)", "Energy Expenditure (kcal/min)", 
    "Pressure Ambient", "Temperature", "Relative Humidity"
  )
  new_columns <- c()
  for (set_num in c('S1', 'S2')) {
    for (room in c('R1', 'R2')) {
      new_columns <- c(new_columns, paste(room, set_num, columns, sep = "_"))
    }
  }
  colnames(df) <- new_columns
  
  # Check that time and date columns are consistent across rows
  date_columns <- df[, grep("Date", colnames(df))]
  time_columns <- df[, grep("Time", colnames(df))]
  
  if (any(apply(date_columns, 1, function(x) length(unique(x))) != 1) ||
      any(apply(time_columns, 1, function(x) length(unique(x))) != 1)) {
    stop("Date or Time columns do not match in some rows")
  }
  
  # Combine Date and Time to DateTime and drop all unnecessary date/time columns
  df_filtered <- data.frame(
    Date = date_columns[, 1],
    Time = time_columns[, 1]
  )
  
  df_filtered$datetime <- as.POSIXct(paste(df_filtered$Date, df_filtered$Time), format = "%m/%d/%y %H:%M:%S")
  df_filtered <- df_filtered[, "datetime", drop = FALSE]
  
  # Drop the old Date and Time columns
  df <- cbind(df_filtered, df[, !(colnames(df) %in% c(colnames(date_columns), colnames(time_columns)))])
  
  # Save separately for Room 1 and Room 2
  df_room1 <- df[, grepl("^R1", names(df))]
  df_room2 <- df[, grepl("^R2", names(df))]
  
  if (save_csv) {
    room1_filename <- if (!is.null(path_to_save)) {
      paste0(path_to_save, "/", code_1, "_WRIC_data.csv")
    } else {
      paste0(code_1, "_WRIC_data.csv")
    }
  
    room2_filename <- if (!is.null(path_to_save)) {
      paste0(path_to_save, "/", code_2, "_WRIC_data.csv")
    } else {
      paste0(code_2, "_WRIC_data.csv")
    }
    
    write.csv(df_room1, room1_filename, row.names = FALSE)
    write.csv(df_room2, room2_filename, row.names = FALSE)
  }
  
  return(df)
}

preprocess_WRIC_file <- function(filepath, code = "id", manual = NULL, save_csv = TRUE, path_to_save = NULL) { # nolint
  # Open the file and read lines
  lines <- open_file(filepath)
  
  # Extract metadata
  result <- extract_meta_data(lines, code, manual, save_csv, path_to_save)
  R1_metadata <- result$R1_metadata
  R2_metadata <- result$R2_metadata
  code_1 <- result$code_1
  code_2 <- result$code_2
  
  # Create WRIC DataFrame
  wric_data <- create_wric_df(filepath, lines, save_csv, code_1, code_2, path_to_save)
  
  return(list(R1_metadata = R1_metadata, R2_metadata = R2_metadata, wric_data = wric_data)) # nolint
}

# Load necessary libraries
#library(readr)  # For reading CSV files
library(dplyr)  # For data manipulation (if needed)

# Define the file path
filepath <- "C:/Documents/WRIC_example_data/Results_1m_copy_anonymised.txt"

# Call the preprocess_WRIC_file function
result <- preprocess_WRIC_file(filepath, code = "id+comment")

# Extract the results from the returned list
R1_metadata <- result$R1_metadata
R2_metadata <- result$R2_metadata
wric_data <- result$wric_data

# Display the strcuture of the WRIC data
print(str(wric_data))
