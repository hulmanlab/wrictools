import WRIC_preprocessing as wric
# from IPython.display import display

#notefilepath="/media/nina/SUNSHINE/Simon_CIRCLE/WRIC/Notes_Processed/02LK_v2_treat0_wric1min_04HH_v2_treat1_note.txt"
#with open(notefilepath, "r") as file:
#    lines = file.readlines()
#    print(lines)

R1_metadata, R2_metadata, df_room1, df_room2 = wric.preprocess_WRIC_file("./example_data/data.txt", 
    notefilepath="/media/nina/SUNSHINE/Simon_CIRCLE/WRIC/Notes_Processed/02LK_v2_treat0_wric1min_04HH_v2_treat1_note.txt") 
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