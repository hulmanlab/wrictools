import WRIC_preprocessing as wric
from IPython.display import display

R1_metadata, R2_metadata, df_room1, df_room2 = wric.preprocess_WRIC_file("./example_data/data.txt", notefilepath="C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt") #code="id+comment",  start="2023-11-13 11:43:00", end="2023-11-13 12:09:00"

display(df_room1)
display(df_room2)

# dataframes = wric.preprocess_WRIC_files('id.csv', 'upload')

# R1_metadata, R2_metadata, df_room1, df_room2 = dataframes["2"]

# display(df_room1)

notes_path = "C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt"
wric.extract_note_info(notes_path, df_room1, df_room2)

#result = wric.detect_start_end("C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt")
#print(result[1])
#print(result[2])