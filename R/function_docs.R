function_docs <- list(
  check_code = "Check the subject ID code and return corresponding Room 1 and Room 2 codes.\n\n
  @param code Type of code to use: \"id\", \"id+comment\", or \"manual\".\n
  @param manual A list of custom codes for Room 1 and Room 2, required if `code` is \"manual\".\n
  @param R1_metadata, R2_metadata DataFrames for metadata of Room 1 and Room 2, containing \"Subject ID\" and \"Comments\".\n
  @return A list containing the codes for Room 1 and Room 2.",
  
  extract_meta_data = "Extracts metadata for two subjects from text lines and optionally saves it as CSV files.\n\n
  @param lines List of strings containing the WRIC metadata.\n
  @param code Method for generating subject IDs (\"id\", \"id+comment\", or \"manual\").\n
  @param manual Custom codes for Room 1 and Room 2 subjects if `code` is \"manual\".\n
  @param save_csv Logical, whether to save extracted metadata to CSV files.\n
  @param path_to_save Directory path for saving CSV files, NULL uses the current directory.\n
  @return A list containing the Room 1 code, Room 2 code, and DataFrames for R1_metadata and R2_metadata.",
  
  open_file = "Opens a WRIC .txt file and reads its contents.\n\n
  @param filepath Path to the WRIC .txt file.\n
  @return A list of strings representing the lines of the file.\n
  @note Raises an error if the file is not a valid WRIC data file.",
  
  add_relative_time = "Add Relative Time in minutes to DataFrame. Rows before the start_time will be indicated negative.\n\n
  @param df A data frame containing a 'datetime' column.\n
  @param start_time Optional; the starting time for calculating relative time. 
                   Should be in a format compatible with POSIXct (eg. \"2023-11-13 11:40:00\")\n
  @return A data frame with an additional column 'relative_time[min]' indicating the time in minutes from the start time.",
  
  cut_rows = "Filters rows in a DataFrame based on an optional start and end datetime range.\n\n
  @param df data.frame\n
  DataFrame with a \"datetime\" column to filter.\n
  @param start character or POSIXct or NULL, optional; 
  Start datetime; rows before this will be removed. If NULL, uses the earliest datetime in the DataFrame.\n
  @param end character or POSIXct or NULL, optional
  End datetime; rows after this will be removed. If NULL, uses the latest datetime in the DataFrame.\n
  @return data.frame
  DataFrame with rows between the specified start and end dates, or the full DataFrame if both are NULL.",
  
  detect_start_end = "Automatically detect enter and exit from the chamber based on the notefile.\n
  Returns the start and end times for two participants.\n\n
  @param notes_path string - path to the note file\n
  @return list - A list of two elements (\"1\" and \"2\"), each containing a tuple (start, end) time.\n
  Returns NA if not possible to find start or end time.\n
  @keywords chamber entry exit detection",
  
  extract_note_info = "Extracts and processes note information from a specified notes file, categorizing events 
  based on predefined keywords, and updates two DataFrames with protocol information for 
  different participants.\n\n
  @param notes_path string - The file path to the notes file containing event data.\n
  @param df_room1 DataFrame - DataFrame for participant 1, to be updated with protocol info.\n
  @param df_room2 DataFrame - DataFrame for participant 2, to be updated with protocol info.\n
  @param keywords_dict nested list - used to identify keywords to extract protocol values\n
  @return list - A list containing two updated DataFrames:
  - `df_room1`: Updated DataFrame for participant 1 with protocol data.
  - `df_room2`: Updated DataFrame for participant 2 with protocol data.",
  
  create_wric_df = "Creates DataFrames for WRIC data from a file and optionally saves them as CSV files.\n\n
  @param filepath Path to the WRIC .txt file.\n
  @param lines List of strings read from the file to locate the data start.\n
  @param save_csv Logical, whether to save DataFrames as CSV files.\n
  @param code_1, code_2 Strings representing the codes for Room 1 and Room 2.\n
  @param path_to_save Directory path for saving CSV files, NULL uses the current directory.\n
  @return A list containing DataFrames for Room 1 and Room 2 measurements.\n
  @note Raises an error if Date or Time columns are inconsistent across rows.",
  
  check_discrepancies = "Checks for discrepancies between S1 and S2 measurements in the DataFrame and prints them to the console.\n
  This function is not included in the big pre-processing function, as it is more intended to 
  perform a quality check on your data and not to automatically inform the processing of the data.\n\n
  @param df DataFrame containing WRIC data with columns for S1 and S2 measurements.\n
  @param threshold Numeric threshold percentage for mean relative delta discrepancies (default 0.05).\n
  @param individual Logical, if TRUE checks and reports individual row discrepancies beyond the threshold (default FALSE).\n
  @return None. Prints discrepancies to the console.",
  
  combine_measurements = "Combines S1 and S2 measurements in the DataFrame using the specified method.\n\n
  @param df DataFrame containing WRIC data with S1 and S2 measurement columns.\n
  @param method String specifying the method to combine measurements (\"mean\", \"median\", \"s1\", \"s2\", \"min\", \"max\").\n
  @return A DataFrame with combined measurements.",
  
  preprocess_WRIC_file = "Preprocesses a WRIC data file, extracting metadata, creating DataFrames, and optionally saving results.\n\n
  @param filepath Path to the WRIC .txt file.\n
  @param code Method for generating subject IDs (\"id\", \"id+comment\", or \"manual\").\n
  @param manual Custom codes for subjects in Room 1 and Room 2 if `code` is \"manual\".\n
  @param save_csv Logical, whether to save extracted metadata and data to CSV files.\n
  @param path_to_save Directory path for saving CSV files, NULL uses the current directory.\n
  @param combine Logical, whether to combine S1 and S2 measurements.\n
  @param method Method for combining measurements (\"mean\", \"median\", \"s1\", \"s2\", \"min\", \"max\").\n
  @param start character or POSIXct or NULL, rows before this will be removed, if NULL takes first row e.g \"2023-11-13 11:43:00\"\n
  @param end character or POSIXct or NULL, rows after this will be removed, if NULL takes last rows e.g \"2023-11-13 11:43:00\"\n
  @param notefilepath String, Directory path of the corresponding note file (.txt)\n
  @param keywords_dict Nested List, used to extract protocol values from note file\n
  @return A list containing the metadata and DataFrames for Room 1 and Room 2.",
  
  export_file_from_redcap = "Exports a file from REDCap based on the specified record ID and field name.\n\n
  @param record_id String containing the unique identifier for the record in REDCap.\n
  @param fieldname Field name from which to export the file.\n
  @param path File path where the exported file will be saved.\n
  @return None. The file is saved to the specified path.",
  
  upload_file_to_redcap = "Uploads a file to REDCap for a specified record ID and field name.\n\n
  @param filepath Path to the file to be uploaded.\n
  @param record_id String containing the unique identifier for the record in REDCap.\n
  @param fieldname Field name to which the file should be uploaded.\n
  @return None. The file is uploaded to the specified record and field in REDCap.",

  preprocess_WRIC_file = "Preprocesses a WRIC data file, extracting metadata, creating DataFrames, and optionally saving results.\n\n
@param filepath Path to the WRIC .txt file.\n
@param code Method for generating subject IDs (\"id\", \"id+comment\", or \"manual\").\n
@param manual Custom codes for subjects in Room 1 and Room 2 if `code` is \"manual\".\n
@param save_csv Logical, whether to save extracted metadata and data to CSV files.\n
@param path_to_save Directory path for saving CSV files, NULL uses the current directory.\n
@param combine Logical, whether to combine S1 and S2 measurements.\n
@param method Method for combining measurements (\"mean\", \"median\", \"s1\", \"s2\", \"min\", \"max\").\n
@param start character or POSIXct or NULL, rows before this will be removed, if NULL takes first row e.g \"2023-11-13 11:43:00\"\n
@param end character or POSIXct or NULL, rows after this will be removed, if NULL takes last rows e.g \"2023-11-13 11:43:00\"\n
@param notefilepath String, Directory path of the corresponding note file (.txt)\n
@param keywords_dict Nested List, used to extract protocol values from note file\n
@return A list containing the metadata and DataFrames for Room 1 and Room 2.",

doc = "Generates documentation for a function in a structured format for easy reference.\n\n
@param func Function name (character string) for which to generate documentation.\n
@param params List of parameters with descriptions.\n
@param return_desc Description of the return value from the function.\n
@return A character string containing formatted documentation for the specified function.\n
@note Useful for creating consistent documentation for custom R functions.",

visualize_with_protocol = "Visualizes data from a CSV file with a specified plot type, optionally saving the plot as a PNG file.\n\n
@param csv_file Path to the CSV file containing the data to be visualized.\n
@param plot String specifying which variable to plot (default is \"RER\").\n
@param protocol_colors_labels A data frame specifying protocol colors and labels (optional). If NULL, default values will be used.\n
@param save_png Logical, whether to save the plot as a PNG file.\n
@param path_to_save Directory path for saving the PNG file, NULL uses the current directory.\n
@return A ggplot2 plot displaying the data with protocol highlighting, and optionally saves the plot as a PNG file."

)
