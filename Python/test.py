import WRIC_preprocessing as wric
import pandas as pd
pd.options.mode.chained_assignment = None  # Disable the warning
# from IPython.display import display

#notefilepath="/media/nina/SUNSHINE/Simon_CIRCLE/WRIC/Notes_Processed/02LK_v2_treat0_wric1min_04HH_v2_treat1_note.txt"
#with open(notefilepath, "r") as file:
#    lines = file.readlines()
#    print(lines)

# R1_metadata, R2_metadata, df_room1, df_room2 = wric.preprocess_WRIC_file("./example_data/data.txt", 
#     notefilepath="/media/nina/SUNSHINE/Simon_CIRCLE/WRIC/Notes_Processed/02LK_v2_treat0_wric1min_04HH_v2_treat1_note.txt") 
    #code="id+comment",  start="2023-11-13 11:43:00", end="2023-11-13 12:09:00", C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt
    # /media/nina/SUNSHINE/Simon_CIRCLE/WRIC/05PM_wric1min_v2_treat1.txt"

#print(df_room1)
#print(df_room2)

# dataframes = wric.preprocess_WRIC_files('id.csv', 'upload')

# R1_metadata, R2_metadata, df_room1, df_room2 = dataframes["2"]

# display(df_room1)

#result = wric.detect_start_end("C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt")
#print(result[1])
#print(result[2])
wric_dict = {'01JJ_wric1min_v1_treat0.txt' : '01JJ_wric1min_v1_note_treat0.txt', 
    '01JJ_wric1min_v2_treat1.txt' : '01JJ_wric1min_v2_note_treat1.txt', 
    '02LK_v2_treat0_wric1min_04HH_v2_treat1.txt' : '02LK_v2_treat0_wric1min_04HH_v2_treat1_note.txt', 
    '02LK_wric1min_v1_treat1.txt' : '02LK_wric1min_v1_note_treat1.txt', 
    '03HA_v1_treat1_wric1min_04HH_v1_treat0.txt' : '03HA_v1_treat1_wric1min_04HH_v1_treat0_note.txt', 
    '03HA_wric1min_v2_treat0.txt' : '03HA_wric1min_v2_note_treat0.txt', 
    #'05PM_wric1min_v1_treat0.txt' : '05PM_wric1min_v1_note_treat0.txt', #date and time sync issues across measure and rooms (also the switcheroo patient)
    '05PM_wric1min_v2_treat1.txt' : '05PM_wric1min_v2_note_treat1.txt', 
    '06ML_v2_treat1_wric1min_09NQ_v1_treat1.txt' : '06ML_v2_treat1_wric1min_09NQ_v1_treat1_note.txt', 
    '06ML_wric1min_v1_treat0.txt' : '06ML_wric1min_v1_note_treat0.txt', 
    '07AB_v1_treat1_wric1min_08MG_v2_treat0.txt' : '07AB_v1_treat1_wric1min_08MG_v2_treat0_note.txt', 
    '07AB_wric1min_v2_treat0.txt' : '07AB_wric1min_v2_note_treat0.txt', 
    '08MG_wric1min_v1_treat1.txt' : '08MG_wric1min_v1_note_treat1.txt', 
    '09NQ_wric1min_v2_treat0.txt' : '09NQ_wric1min_v2_note_treat0.txt', 
    '10JK_wric1min_v1_treat0.txt' : '10JK_wric1min_v1_note_treat0.txt', 
    '10JK_wric1min_v2_treat1.txt' : '10JK_wric1min_v2_note_treat1.txt'}

ds = ["01JJ", "02LK", "03HA", "04HH", "05PM", "06ML", "07AB", "08MG", "09NQ", "10JK"]
treatments = [0, 1]
#base_folder = "/media/nina/SUNSHINE/Simon_CIRCLE/WRIC/"
#note_base_folder = "/media/nina/SUNSHINE/Simon_CIRCLE/WRIC/Notes_Processed/"
#path_to_save = "/media/nina/SUNSHINE/Simon_CIRCLE/WRIC/processed"

base_folder = "D:/Simon_CIRCLE/WRIC/"
note_base_folder = "D:/Simon_CIRCLE/WRIC/Notes_Processed/"
path_to_save = "D:/Simon_CIRCLE/WRIC/processed"

for filepath, notepath in wric_dict.items():
    print(filepath, notepath)
    R1_metadata, R2_metadata, df_room1, df_room2 = wric.preprocess_WRIC_file(base_folder+filepath, code="id+comment", path_to_save=path_to_save, notefilepath=note_base_folder+notepath)