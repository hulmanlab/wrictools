import WRIC_preprocessing as wric
import pandas as pd
import os

# This file includes helpful functions to process and analyze the data
# It is important that you have preprocessed your WRIC data before by running preprocess_WRIC_file(filepath) to create the necessary processed files

folder_path = "D:/Simon_CIRCLE/WRIC/processed"
protocol_dict = {"normal" : 0, "sleep" : 1, "eat" : 2, "active" : 3, "ree" : 4}

# choose the protocol you want (takes first) and number, if there are multiple specify the occurence (@Nina: start counting at 1!)
def tmp_func_name(folder_path, protocol, occurence = 1, add_start = 0, add_end = 0, save_path=None):
    # add_start, add_end in minutes
    wric_files = [f for f in os.listdir(folder_path) if f.endswith("_data.csv")]
    try:
        protocol_num = protocol_dict[protocol]
    except:
        print("ERROR: Please provide a valid protocol instance: normal, sleep, eat, active, ree")
        return
    # create folder to save the new df to
    folder = save_path if not pd.isna(save_path) else f'{folder_path}/{protocol}_{occurence}'
    os.makedirs(folder, exist_ok=True)
    
    dfs = {}
    
    for file in wric_files:
        df = pd.read_csv(folder_path +"/" + file)
        
        if "protocol" not in df.columns:
            print(f"ERROR: 'protocol' column is missing in file: {file}. This file will be skipped.")
            continue
        is_protocol = df["protocol"] == protocol_num
        transitions = is_protocol & (~is_protocol.shift(fill_value=False))
        if occurence > len(transitions[transitions]):
            raise IndexError(f"""Only {len(transitions[transitions])} transitions found, but occurrence {occurence} was requested. 
                             Check wether your file {file} is empty, the protocol is properly documented in the corresponding note file 
                             or you chose a protocol activity and/or number of ocurrence that does not exist.""")
    
        occurence_index = transitions[transitions].index[occurence-1]
        start_datetime = df.loc[occurence_index, "datetime"]
        
        end_transitions = (~is_protocol) & is_protocol.shift(fill_value=False)
        try:
            end_index = end_transitions[end_transitions].index[occurence -1]
            end_datetime = df.loc[end_index, "datetime"]
        except IndexError:
            end_datetime = None
        
        start = pd.to_datetime(start_datetime) - pd.Timedelta(minutes=add_start)
        end = pd.to_datetime(end_datetime) + pd.Timedelta(minutes=add_end)
        
        # Check if start/end is earlier/later than the earliest/latest datetime in the DataFrame
        if start < pd.to_datetime(df["datetime"].min()):
            print(f"Warning: Start time {start} is earlier than the earliest data point. Using {df['datetime'].min()} instead.")
            start = pd.to_datetime(df["datetime"].min())
        if end > pd.to_datetime(df["datetime"].max()):
            print(f"Warning: End time {end} is later than the latest data point. Using {df['datetime'].max()} instead.")
            end = pd.to_datetime(df["datetime"].max())
          
        df = wric.cut_rows(df, start, end)
        #print(df.head())
        if (set(df["protocol"].unique()) != {0, protocol_num}):
            print(f"WARNING: The time you specified ({start}, {end}) includes other protocols than normal and {protocol}. Be aware of that for your analysis!")
            #print(pd.isna(start), pd.isna(end))
        df.drop(columns=["relative_time[min]"])
           
        df = wric.add_relative_time(df)
        
        # save as csv and append to dictionary
        df.to_csv(f'{folder}/{file}_{protocol}_{occurence}' )
        dfs[file[:7]] = df
    
    return dfs
        
tmp_func_name(folder_path, "sleep", occurence=2)       

# output warning if changed to other protocol_num than 0 (interference)
# extrcat and save them as new DataFrames