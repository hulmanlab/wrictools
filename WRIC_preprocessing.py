import pandas as pd
import re
import numpy as np
from config import config
import requests
import csv
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

def create_wric_df(filepath, lines, save_csv, code_1, code_2, path_to_save):
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
    
    # Split dataset by room
    df_room1 = df.filter(like='R1')
    df_room2 = df.filter(like='R2')

    if save_csv:
        room1_filename = f'{path_to_save}/{code_1}_WRIC_data.csv' if path_to_save else f'{code_1}_WRIC_data.csv'
        room2_filename = f'{path_to_save}/{code_2}_WRIC_data.csv' if path_to_save else f'{code_2}_WRIC_data.csv'
        df_room1.to_csv(room1_filename, index=False)
        df_room2.to_csv(room2_filename, index=False)
        
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
    
    combined = pd.DataFrame()
    
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

def preprocess_WRIC_file(filepath, code = "id", manual = None, save_csv = True, path_to_save = None, combine = True, method = "mean"):
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

    Returns:
    -------
    tuple
        (R1_metadata, R2_metadata, df_room1, df_room2):
        - Metadata DataFrames for Room 1 and Room 2.
        - DataFrames with combined or separate measurements for each room (depending on parameter 'combine')
    """     
    lines = open_file(filepath)
    code_1, code_2, R1_metadata, R2_metadata = extract_meta_data(lines, code, manual, save_csv, path_to_save)
    df_room1, df_room2 = create_wric_df(filepath, lines, save_csv, code_1, code_2, path_to_save)
    if combine:
        df_room1 = combine_measurements(df_room1, method)
        df_room2 = combine_measurements(df_room2, method)
        
    if save_csv:
        room1_filename = f'{path_to_save}/{code_1}_WRIC_data_combined.csv' if path_to_save else f'{code_1}_WRIC_data_combined.csv'
        room2_filename = f'{path_to_save}/{code_2}_WRIC_data_combined.csv' if path_to_save else f'{code_2}_WRIC_data_combined.csv'
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
    
def preprocess_WRIC_files(csv_file, fieldname, code = "id", manual = None, save_csv = True, path_to_save = None, combine = True, method = "mean"):
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
        R1_metadata, R2_metadata, df_room1, df_room2 = preprocess_WRIC_file('./tmp/export.raw.txt', code, manual, save_csv, path_to_save, combine, method)
        dataframes[record_id] = (R1_metadata, R2_metadata, df_room1, df_room2)
    
    return dataframes

