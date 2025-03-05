import pandas as pd
import re
import numpy as np
from config import config
from datetime import datetime
import requests
import csv
#from IPython.display import display
pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', 5)

def check_code(code, manual, R1_metadata, R2_metadata):
    """
    Extracts subject IDs from metadata, based on the provided code or manual input.

    Parameters:
    ----------
    code : str
        Type of code to use:
        - "id": Use the "Subject ID" from metadata.
        - "id+comment": Use the "Subject ID" concatenated with "Comments" from metadata.
        - "manual": Use the manual code provided.
    manual : list or None
        A list of two strings, specifying custom codes for Room 1 and Room 2 subjects.
        Should be provided if `code` is set to "manual". Default is None.
    R1_metadata, R2_metadata : pandas.DataFrame
        Metadata DataFrames for subjects in Room 1 and Room 2.

    Returns:
    -------
    tuple
        (code_1, code_2): Codes for subjects in Room 1 and Room 2.

    Raises:
    ------
    ValueError
        If `code` parameter is invalid or manual input is incorrect.
    """
    if code == "id":
        code_1 = R1_metadata["Subject ID"].iloc[0]
        code_2 = R2_metadata["Subject ID"].iloc[0]
    elif code == "id+comment":
        code_1 = R1_metadata["Subject ID"].iloc[0] + '_' + R1_metadata["Comments"].iloc[0]
        code_2 = R2_metadata["Subject ID"].iloc[0] + '_' + R2_metadata["Comments"].iloc[0]
    elif code == "manual" or manual != None:
        try:
            code_1 = manual[0]
            code_2 = manual[1]
        except ValueError as e:
            print("You have tried to enter a manual code (this is the filename that the metadata and data will be saved as). Please make sure your manual code is a list, e.g: ['1234_visit1', '5678_visit1'], where the first entry is for subject in room 1 and the second entry for subject in room 2.")
    else:
        raise ValueError("The value for the code parameter is not valid. Please choose id, id+comment or manual. Default is id.")
    
    return code_1, code_2

def extract_meta_data(lines, code, manual, save_csv, path_to_save):
    """
    Extracts metadata for two subjects from text lines and optionally saves it as CSV files.

    Parameters:
    ----------
    lines : list of str
        Text lines containing metadata, with relevant data starting from line 4.
    code : str
        Method for generating subject IDs ("id", "id+comment", or "manual").
    manual : list or None
        Custom codes for subjects in Room 1 and Room 2, required if `code` is "manual".
    save_csv : bool
        Whether to save the extracted metadata to CSV files.
    path_to_save : str or None
        Directory path for saving CSV files. Uses current directory if None.

    Returns:
    -------
    tuple
        (code_1, code_2, R1_metadata, R2_metadata): Subject codes and metadata DataFrames.
    """
    header_lines = [line.strip().split('\t') for line in lines[3:7]]

    data_R1 = dict(zip(header_lines[0][1:], header_lines[1]))
    data_R2 = dict(zip(header_lines[2][1:], header_lines[3]))

    R1_metadata = pd.DataFrame([data_R1])
    R2_metadata = pd.DataFrame([data_R2])

    code_1, code_2 = check_code(code, manual, R1_metadata, R2_metadata)
    
    if save_csv:
        room1_filename = f'{path_to_save}/{code_1}_WRIC_metadata.csv' if path_to_save else f'{code_1}_WRIC_metadata.csv'
        room2_filename = f'{path_to_save}/{code_2}_WRIC_metadata.csv' if path_to_save else f'{code_2}_WRIC_metadata.csv'
        R1_metadata.to_csv(room1_filename, index=False)
        R2_metadata.to_csv(room2_filename, index=False)
        
    return code_1, code_2, R1_metadata, R2_metadata

def open_file(filepath):
    """
    Opens a WRIC .txt file and reads its content.

    Parameters:
    ----------
    filepath : str
        Path to the .txt file.

    Returns:
    -------
    list of str
        Lines read from the file.

    Raises:
    ------
    TypeError
        If the file is not a .txt file.
    ValueError
        If the file does not start with the expected "OmniCal software" header.
    FileNotFoundError
        If the file does not exist at the given filepath.
    """
    lines = None
    if not filepath.lower().endswith('.txt'):
        raise TypeError("The file must be a .txt file.")
    try:
        with open(filepath, "r") as file:
            lines = file.readlines()
            if not lines or not lines[0].startswith("OmniCal software"):
                raise ValueError("The provided file is not the WRIC data file.")
    except FileNotFoundError as e:
        print("The filepath you provided does not lead to a file.")
    return lines

def add_relative_time(df, start_time=None):
    """
    Add Relative Time in minutes to DataFrame.

    Parameters:
    ----------
    df : pd.DataFrame 
        A DataFrame containing a 'datetime' column.
    start_time : str or pd.Timestamp, optional 
        The starting time for calculating relative time. Defaults to None, 
        in which case the first datetime in the DataFrame is used. Previous rows will be indicated negative from the start_time.

    Returns:
    -------
    pd.DataFrame: The original DataFrame with an additional column 'relative_time[min]' 
        indicating the time in minutes from the start time.
    """
    if start_time is None:
        start_time = df['datetime'].iloc[0]
    start_time = pd.to_datetime(start_time)
    df['relative_time[min]'] = (df['datetime'] - start_time).dt.total_seconds() /60
    
    return df
    
def cut_rows(df, start=None, end=None):
    """
    Filters rows in a DataFrame based on a start and end datetime range.

    Parameters:
    ----------
    df : pd.DataFrame
        DataFrame with a "datetime" column to filter.
    start : str or datetime-like or None, optional
        Start datetime; rows before this will be removed.
    end : str or datetime-like or None, optional
        End datetime; rows after this will be removed.

    Returns:
    -------
    pd.DataFrame
        DataFrame with rows between the specified start and end dates.
    """
    df['datetime'] = pd.to_datetime(df['datetime'])
    if pd.isna(start) and pd.isna(end):
        return df 
    elif pd.isna(start):
        start = df['datetime'].min()
    elif pd.isna(end):
        end = df['datetime'].max()
        
    start = pd.to_datetime(start)
    end = pd.to_datetime(end)
    
    return df[(df['datetime'] >= start) & (df['datetime'] <= end)]

def update_protocol(df, protocol_list):
    """
    Helper Function for extract_note_info() that updates the protocol column based on a list.
    Not intended for modular use.
    """
    current_protocol = 0
    current_index = 0

    for index, row in df.iterrows():
        # While there are more timestamps and the current row's datetime is greater than or equal to the timestamp
        while (current_index < len(protocol_list) and 
               row['datetime'] >= protocol_list[current_index][0]):
            current_protocol = protocol_list[current_index][1]  # Update current protocol
            current_index += 1  # Move to the next timestamp

        df.at[index, 'protocol'] = current_protocol
        
    return df

def save_dict(dict_protocol, participant, datetime, value):
    """
    Helper Function for extract_note_info() that updates a dictionary based on parameters.
    Not intended for modular use.
    """
    if participant is not None:
        dict_protocol[participant][datetime] = value
    else:
        dict_protocol[1][datetime] = value
        dict_protocol[2][datetime] = value
    return dict_protocol

def detect_start_end(notes_path):
    """
    Automatically detect enter and exit from the chamber based on the notefile and returns the times for the two participants

    Args:
        notes_path (string): path to the note file

    Returns:
        dictionary: dictionary of participant/room 1 and 2 and for each a touple (start, end) time, None if not possible to find
    """    
    keywords_dict = {
        'end': ["ud", "exit", "out"], #maybe as added safety check, check that it is the last/first note for that participant
        'start': ["ind i kammer", "enter", "ind", "entry"]
    }
    
    # read the note file into a pandas Dataframe
    notes_content = open_file(notes_path)
    lines = [line.strip().split('\t') for line in notes_content[2:]]
    df_note = pd.DataFrame(lines[2:], columns=lines[0])
    df_note = df_note.dropna()

    # combine to datetime
    df_note['datetime'] = pd.to_datetime(df_note['Date'] + ' ' + df_note['Time'], format='%m/%d/%y %H:%M:%S')
    df_note = df_note.drop(columns=['Date', 'Time'])
    
    start_end_times = {1: (None, None), 2: (None, None)}
    participants = []
    
    for index, row in df_note.iterrows():
        comment = row["Comment"].lower()
        participants = []
        if comment.startswith("1"):
            participants = [1]
        elif comment.startswith("2"):
            participants = [2]
        else:
            participants = [1,2]
        for participant in participants:           
            if start_end_times[participant][0] is None and any(word in comment for word in keywords_dict['start']):
                first_two = df_note.head(2)
                if any(row["datetime"] == time for time in first_two['datetime']):
                    start_end_times[participant] = (row["datetime"], start_end_times[participant][1])
            elif start_end_times[participant][1] is None and any(word in comment for word in keywords_dict['end']):
                last_two = df_note.tail(2)
                if any(row["datetime"] == time for time in last_two['datetime']):
                    start_end_times[participant] = (start_end_times[participant][0], row["datetime"])
                
    return start_end_times

def extract_note_info(notes_path, df_room1, df_room2):
    """
    Extracts and processes note information from a specified notes file, categorizing events 
    based on predefined keywords, and updates two DataFrames with protocol information for 
    different participants.

    Parameters:
    ----------
    notes_path : str
        The file path to the notes file containing event data.
    df_room1 : pd.DataFrame
        DataFrame associated with participant 1, to be updated with extracted protocol information.
    df_room2 : pd.DataFrame
        DataFrame associated with participant 2, to be updated with extracted protocol information.

    Returns:
    -------
    tuple
        A tuple containing two updated DataFrames: 
        - df_room1: Updated DataFrame for participant 1 with protocol data.
        - df_room2: Updated DataFrame for participant 2 with protocol data.

    Notes:
    -----
    - The 'Comment' field is expected to start with '1' or '2' to indicate the participant, 
      or it can be empty for both.
    - The keywords dictionary can be modified to suit specific study protocols and includes 
      multi-group checks for keyword matching.
    """
    
    # Extend or change this dictionary to suit your study protocol. Words will be matched case-insensitive.
    keywords_dict = {
        'sleeping': (["seng", "sleeping", "bed", "sove", "soeve", "godnat", "night", "sleep"], 1),
        'eating': ([["start", "begin", "began"],["maaltid", "måltid", "eat", "meal", "food", "spis", "maal", "måd", "mad", "frokost", "morgenmad", "middag", "snack", "aftensmad"]], 2),
        'stop_sleeping' : (["vaagen", "vågen", "vaekke", "væk", "wake", "woken", "vaagnet"], 0),
        'stop_anything': (["faerdig", "færdig", "stop", "end ", "finished", "slut"], 0),
        'activity': ([["start", "begin", "began"], ["step", "exercise", "physicial activity", "active", "motion", "aktiv"]], 3),
        'ree_start': ([["start", "begin", "began"], ["REE", "BEE", "BMR", "RMR", "RER"]], 4),
    }
    
    # read the note file into a pandas Dataframe
    notes_content = open_file(notes_path)
    lines = [line.strip().split('\t') for line in notes_content[2:]]
    df_note = pd.DataFrame(lines[2:], columns=lines[0])
    df_note = df_note.dropna()

    # combine to datetime
    df_note['datetime'] = pd.to_datetime(df_note['Date'] + ' ' + df_note['Time'], format='%m/%d/%y %H:%M:%S')
    df_note = df_note.drop(columns=['Date', 'Time'])

    time_pattern = r"([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5]\d"
    drift_pattern = r"^\d{2}:\d{2}(:\d{2})?$"
    dict_protocol = {1:{}, 2:{}}
    drift = None

    for index, row in df_note.iterrows():
        participant = None
        if row["Comment"].startswith("1"):
            participant = 1
        elif row["Comment"].startswith("2"):
            participant = 2
        for category, (keywords, value) in keywords_dict.items():
            # Multi-group check: at least one keyword from each sublist must match
            if isinstance(keywords[0], list):
                if all(any(word.lower() in row['Comment'].lower() for word in group) for group in keywords):
                    # check if a different timestamp is written in the message and save the value there 
                    # only checks first time stamp and only in format 6:45 or 06:45
                    match = re.search(time_pattern, row['Comment'])
                    if match:
                        time_str = match[0]
                        date_str = row['datetime'].date()
                        new_datetime = pd.Timestamp(datetime.combine(date_str, datetime.strptime(time_str, "%H:%M").time()))
                        dict_protocol = save_dict(dict_protocol, participant, new_datetime, value)
                    else:
                        dict_protocol = save_dict(dict_protocol, participant, row["datetime"], value)
            # Single-group check: only one keyword needs to match
            elif any(word.lower() in row['Comment'].lower() for word in keywords):
                    match = re.search(time_pattern, row['Comment'])
                    if match:
                        time_str = match[0]
                        date_str = row['datetime'].date()
                        new_datetime = pd.Timestamp(datetime.combine(date_str, datetime.strptime(time_str, "%H:%M").time()))
                        dict_protocol = save_dict(dict_protocol, participant, new_datetime, value)
                    else:
                        dict_protocol = save_dict(dict_protocol, participant, row["datetime"], value)
            # no keyword matches, but it is the first entry -> check for time drift parameter
            elif index == 0:
                if re.fullmatch(drift_pattern, row['Comment']):
                    date_str = row['datetime'].date()
                    new_datetime = pd.Timestamp(datetime.combine(date_str, pd.Timestamp(row["Comment"]).time()))
                    drift = new_datetime - row["datetime"]
                    print("drift", drift)

                    # Add drift to all datetimes in the normal dataframe as well!
                    df_room1["datetime"] = df_room1["datetime"] + drift
                    df_room2["datetime"] = df_room2["datetime"] + drift
                break
            
                
                
    protocol_list_1 = sorted(dict_protocol[1].items())
    protocol_list_2 = sorted(dict_protocol[2].items())

    # Adding the time drift parameter
    if drift != None:
        protocol_list_1 = [(ts + drift, value) for ts, value in protocol_list_1]
        protocol_list_2 = [(ts + drift, value) for ts, value in protocol_list_2]

    df_room1 = update_protocol(df_room1, protocol_list_1)
    df_room2 = update_protocol(df_room2, protocol_list_2)

    return df_room1, df_room2

def create_wric_df(filepath, lines, save_csv, code_1, code_2, path_to_save, start, end, notefilepath):
    """
    Creates DataFrames for WRIC data from a file and optionally saves them as CSV files.

    Parameters:
    ----------
    filepath : str
        Path to the .txt file containing WRIC data.
    lines : list of str
        Lines read from the file to locate the data start.
    save_csv : bool
        Whether to save the DataFrames as CSV files.
    code_1, code_2 : str
        Codes for subjects in Room 1 and Room 2, used for naming the output files.
    path_to_save : str or None
        Directory path for saving CSV files. Uses current directory if None.

    Returns:
    -------
    tuple
        (df_room1, df_room2): DataFrames containing data for Room 1 and Room 2.

    Raises:
    ------
    ValueError
        If Date or Time columns are inconsistent across rows.
    """
    # find start of data line
    for i, line in enumerate(lines):
        if line.startswith("Room 1 Set 1"):  # Detect where the actual data starts
            data_start_index = i + 1  # First data row starts after this
            break
    df = pd.read_csv(filepath, sep="\t", skiprows=data_start_index)
    # there are NaN rows after each Room&Set combination that need to be deleted
    df = df.dropna(axis=1, how='all')

    # define the new column names
    # CAREFUL: Maastricht Instruments confused EE kcal and kJ in their original file, so if they ever fix this, the order of kcal and kJ should be reversed (again) here!
    columns = [
        "Date", "Time", "VO2", "VCO2", "RER", "FiO2", "FeO2", "FiCO2", "FeCO2", 
        "Flow", "Activity Monitor", "Energy Expenditure (kcal/min)", "Energy Expenditure (kJ/min)", 
        "Pressure Ambient", "Temperature", "Relative Humidity"
    ]
    new_columns = []
    for set_num in ['S1', 'S2']:
        for room in ['R1', 'R2']:
            for col in columns:
                new_columns.append(f"{room}_{set_num}_{col}")
    df.columns = new_columns

    # Check that time and date columns are consistent across rows
    date_columns, time_columns = df.filter(like='Date'), df.filter(like='Time')
    if not (date_columns.nunique(axis=1).eq(1).all() and time_columns.nunique(axis=1).eq(1).all()):
        raise ValueError("Date or Time columns do not match in some rows")

    # Combine Date and Time to DateTime and drop all unecessary date/time columns
    df_filtered = df.filter(like='Date').iloc[:, 0].to_frame(name="Date").join(df.filter(like='Time').iloc[:, 0].to_frame(name="Time"))
    df_filtered['datetime'] = pd.to_datetime(df_filtered['Date'] + ' ' + df_filtered['Time'], format='%m/%d/%y %H:%M:%S')
    df_filtered = df_filtered.drop(columns=['Date', 'Time'])
    df = df_filtered.join(df.drop(columns=df.filter(like='Date').columns).drop(columns=df.filter(like='Time').columns))
    
    
    # Split dataset by room and add datetime to both
    df_room1 = df.filter(like='R1')
    df_room1['datetime'] = df['datetime']
    df_room2 = df.filter(like='R2')
    df_room2['datetime'] = df['datetime']
    
    # Cut to only include desired rows (do before setting the relative time) 
    if start and end:
        df_room1 = cut_rows(df_room1, start, end)
        df_room2 = cut_rows(df_room1, start, end)
    elif notefilepath:
        se_times = detect_start_end(notefilepath)
        start_1, end_1 = se_times[1]
        start_2, end_2 = se_times[2]
        if start:
            start_1 = start
            start_2 = start
        if end:
            end_1 = end
            end_2 = end
        df_room1 = cut_rows(df_room1, start_1, end_1)
        df_room2 = cut_rows(df_room2, start_2, end_2)
        print("Starting time for room 1 is", start_1, "and end", end_1, "and for room 2 start is", start_2, "and end", end_2)
    else:
        df_room1 = cut_rows(df_room1, start, end)
        df_room2 = cut_rows(df_room1, start, end)
        
    df_room1 = add_relative_time(df_room1)
    df_room2 = add_relative_time(df_room2)
        
    return df_room1, df_room2

def check_discrepancies(df, threshold=0.05, individual=False):
    """
    Checks for discrepancies between S1 and S2 measurements in the DataFrame and prints them to the terminal.

    Parameters:
    ----------
    df : pandas.DataFrame
        DataFrame containing WRIC data with columns for S1 and S2 measurements.
    threshold : float, optional
        Threshold percentage for mean relative delta discrepancies. Default is 0.05 (5%).
    individual : bool, optional
        If True, checks and reports individual row discrepancies beyond the threshold. Default is False.
        
    Notes:
    ------
    - This function is not included in the big pre-processing function, as it is more intended to 
    perform a quality check on your data and not to automatically inform the processing of the data. 
    """
    env_params = ['Pressure Ambient', 'Temperature', 'Relative Humidity', 'Activity Monitor']
    df_filtered = df.loc[:, ~df.columns.str.contains('|'.join(env_params))]
    
    s1_columns = df_filtered.filter(like='_S1_').columns
    s2_columns = df_filtered.filter(like='_S2_').columns
    
    discrepancies = []
    
    for s1_col, s2_col in zip(s1_columns, s2_columns):
        s1_values = df[s1_col]
        s2_values = df[s2_col]
        avg_values = (s1_values + s2_values) / 2

        # Calculate the mean relative difference
        relative_deltas = (s1_values - s2_values) / avg_values
        mean_relative_delta = np.mean(relative_deltas)
        
        discrepancies.append(f"{s1_col} and {s2_col} have a mean relative delta of {mean_relative_delta:.4f}.")

        # Check if the mean relative delta exceeds the threshold
        if np.abs(mean_relative_delta) > (threshold / 100):
            discrepancies.append(
                f"{s1_col} and {s2_col} have a mean relative delta of {mean_relative_delta:.4f}, "
                f"which exceeds the {threshold}% threshold."
            )
        else:
            discrepancies.append(
                f"{s1_col} and {s2_col} have a mean relative delta of {mean_relative_delta:.4f}, "
                f"which is within the {threshold}% threshold."
            )

        # Check individual values for relative discrepancies beyond the threshold
        if individual:
            for i, (rel_delta) in enumerate(relative_deltas):
                if np.abs(rel_delta) > (threshold / 100):
                    discrepancies.append( f"Row {i+1}: {s1_col} and {s2_col} differ by a relative delta of {rel_delta:.4f}.")
    
    # Output the discrepancies
    if discrepancies:
        for discrepancy in discrepancies:
            print(discrepancy)
    else:
        print("No discrepancies found.")
    
        
def combine_measurements(df, method='mean'):
    """
    Combines S1 and S2 measurements in the DataFrame using the specified method.

    Parameters:
    ----------
    df : pandas.DataFrame
        DataFrame containing WRIC data with S1 and S2 measurement columns.
    method : str, optional
        Method for combining measurements. Options are:
        - 'mean': Average of S1 and S2 (default).
        - 'median': Median of S1 and S2.
        - 's1': Take S1 measurements.
        - 's2': Take S2 measurements.
        - 'min': Minimum of S1 and S2.
        - 'max': Maximum of S1 and S2.

    Returns:
    -------
    pandas.DataFrame
        A DataFrame with combined measurements.
    
    Raises:
    ------
    ValueError
        If an unsupported combination method is provided.
    """
    s1_columns = df.filter(like='_S1_').columns
    s2_columns = df.filter(like='_S2_').columns
    # find all columns that do not have two measurements (e.g. datetime)
    non_s_columns = df.loc[:, ~df.columns.isin(s1_columns.union(s2_columns))]
    
    combined = pd.DataFrame(non_s_columns)
    
    for s1_col, s2_col in zip(s1_columns, s2_columns):
        if method == 'mean':
            combined_values = (df[s1_col] + df[s2_col]) / 2
        elif method == 'median':
            combined_values = np.median([df[s1_col], df[s2_col]], axis=0)
        elif method == 's1':
            combined_values = df[s1_col]
        elif method == 's2':
            combined_values = df[s1_col]
        elif method == 'min':
            combined_values = np.minimum(df[s1_col], df[s2_col])
        elif method == 'max':
            combined_values = np.maximum(df[s1_col], df[s2_col])
        else:
            raise ValueError(f"Method '{method}' is not supported. Use 'mean', 'median', 's1', 's2', 'min', or 'max'.")

        # Add the combined values to a new DataFrame
        column_name = re.sub(r'^.*?_S[12]_', '', s1_col)
        combined[column_name] = combined_values
        
    return combined

def preprocess_WRIC_file(filepath, code = "id", manual = None, save_csv = True, path_to_save = None, combine = True, method = "mean", start=None, end=None, notefilepath = None):
    """
    Preprocesses a WRIC data file, extracting metadata, creating DataFrames, and optionally saving results.

    Parameters:
    ----------
    filepath : str
        Path to the WRIC .txt file.
    code : str, optional
        Method for generating subject IDs ("id", "id+comment", or "manual"). Default is "id".
    manual : list or None, optional
        Custom codes for subjects in Room 1 and Room 2 if `code` is "manual". Default is None.
    save_csv : bool, optional
        Whether to save extracted metadata and data to CSV files. Default is True.
    path_to_save : str or None, optional
        Directory path for saving CSV files. Uses current directory if None. Default is None.
    combine : bool, optional
        Whether to combine S1 and S2 measurements. Default is True.
    method: str, optional
        Method for combining measurements. Options are:
        - 'mean': Average of S1 and S2 (default).
        - 'median': Median of S1 and S2.
        - 's1': Take S1 measurements.
        - 's2': Take S2 measurements.
        - 'min': Minimum of S1 and S2.
        - 'max': Maximum of S1 and S2.
    start: str or datetime or None, optional
        Start datetime; rows before this will be removed. If None, uses the earliest datetime in the DataFrame.
    end: str or datetime or None, optional
        End datetime; rows after this will be removed. If None, uses the latest datetime in the DataFrame.
    notefilepath: str, optional
        Path to corresponding notefile (txt)

    Returns:
    -------
    tuple
        (R1_metadata, R2_metadata, df_room1, df_room2):
        - Metadata DataFrames for Room 1 and Room 2.
        - DataFrames with combined or separate measurements for each room (depending on parameter 'combine')
    """     
    lines = open_file(filepath)
    code_1, code_2, R1_metadata, R2_metadata = extract_meta_data(lines, code, manual, save_csv, path_to_save)
    df_room1, df_room2 = create_wric_df(filepath, lines, save_csv, code_1, code_2, path_to_save, start, end, notefilepath)
    if combine:
        df_room1 = combine_measurements(df_room1, method)
        df_room2 = combine_measurements(df_room2, method)
        
    if notefilepath:
        df_room1, df_room2 = extract_note_info(notefilepath, df_room1, df_room2)
        
    if save_csv:
        room1_filename = f'{path_to_save}/{code_1}_WRIC_data.csv' if path_to_save else f'{code_1}_WRIC_data.csv'
        room2_filename = f'{path_to_save}/{code_2}_WRIC_data.csv' if path_to_save else f'{code_2}_WRIC_data.csv'
        df_room1.to_csv(room1_filename, index=False)
        df_room2.to_csv(room2_filename, index=False)
    
    return R1_metadata, R2_metadata, df_room1, df_room2
    
def export_file_from_redcap(record_id, fieldname, path = None):
    """
    Exports a file from REDCap based on the specified record ID and field name.

    Parameters:
    ----------
    record_id : str
        The unique identifier for the record in REDCap.
    fieldname : str
        The field name from which to export the file.
    path : str or None, optional
        The file path where the exported file will be saved. If None, defaults to './tmp/export.raw.txt'.

    Notes:
    ------
    - The requests library validates the SSL certficate by default to avoid 'Man in the Middle Attacks'
    - The function prints the HTTP status code of the export request.
    - If a path is not provided, the exported file will be saved in a temporary location,
      which will be overwritten if the function is called again.
    """
    fields = {
            'token': config['api_token'],
            'content': 'file',
            'action': 'export',
            'record': record_id,
            'field': fieldname,
        }

    r = requests.post(config['api_url'], data=fields)
    print('HTTP Status: ' + str(r.status_code))

    # This is not intended as downloading and storing the data, but only a temporary saving spot for further processing.
    # If you do not want the data to be overwritten, please specify a path yourself.
    filepath = path if path else './tmp/export.raw.txt'
    f = open(filepath, 'wb')
    f.write(r.content)
    f.close()
    
def upload_file_to_redcap(filepath, record_id, fieldname):
    """
    Uploads a file to REDCap for a specified record ID and field name.

    Parameters:
    ----------
    filepath : str
        The path to the file to be uploaded.
    record_id : str
        The unique identifier for the record in REDCap.
    fieldname : str
        The field name to which the file will be uploaded.

    Notes:
    ------
    - The requests library validates the SSL certficate by default to avoid 'Man in the Middle Attacks'
    - The function prints the HTTP status code of the upload request.
    """

    fields = {
        'token': config['api_token'],
        'content': 'file',
        'action': 'import',
        'record': record_id,
        'field': fieldname,
        'returnFormat': 'json'
    }

    file_obj = open(filepath, 'rb')
    r = requests.post(config['api_url'],data=fields,files={'file':file_obj})
    file_obj.close()

    print('HTTP Status: ' + str(r.status_code))
    
def preprocess_WRIC_files(csv_file, fieldname, code = "id", manual = None, save_csv = True, path_to_save = None, combine = True, method = "mean", start = None, end= None):
    """
    Iterates through records based on record IDs in a CSV file, exporting and processing WRIC data from REDCap.

    Parameters:
    ----------
    csv_file : str
        Path to the CSV file containing record IDs.
    fieldname : str
        The field name from which to export the WRIC data.
    code : str, optional
        Method for generating subject IDs ("id", "id+comment", or "manual"). Default is "id".
    manual : list or None, optional
        Custom codes for subjects in Room 1 and Room 2 if `code` is "manual". Default is None.
    save_csv : bool, optional
        Whether to save extracted metadata and data to CSV files. Default is True.
    path_to_save : str or None, optional
        Directory path for saving CSV files. Uses current directory if None. Default is None.
    combine : bool, optional
        Whether to combine S1 and S2 measurements into a single DataFrame. Default is True.
    method: str, optional
        Method for combining measurements. Options are:
        - 'mean': Average of S1 and S2 (default).
        - 'median': Median of S1 and S2.
        - 's1': Take S1 measurements.
        - 's2': Take S2 measurements.
        - 'min': Minimum of S1 and S2.
        - 'max': Maximum of S1 and S2.

    Returns:
    -------
    dict
        A dictionary where each key is a record ID and each value is a tuple containing:
        (R1_metadata, R2_metadata, df_room1, df_room2) for each record.

    Notes:
    ------
    - Requires a valid API access token configured in `config['api_token']` to interact with REDCap (see ReadMe)
    - Ensure the CSV file contains valid record IDs in the first column.
    """

    record_ids = []
    with open(csv_file, mode='r', newline='', encoding='utf-8') as file:
        reader = csv.reader(file)
        for row in reader:
            # Assuming the record IDs are in the first column
            record_ids.append(str(row[0])) 

    dataframes = dict()

    for record_id in record_ids:

        export_file_from_redcap(record_id, fieldname, path = None)
        R1_metadata, R2_metadata, df_room1, df_room2 = preprocess_WRIC_file('./tmp/export.raw.txt', code, manual, save_csv, path_to_save, combine, method, start, end)
        dataframes[record_id] = (R1_metadata, R2_metadata, df_room1, df_room2)
    
    return dataframes

