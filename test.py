import WRIC_preprocessing as wric
from IPython.display import display

R1_metadata, R2_metadata, df_room1, df_room2 = wric.preprocess_WRIC_file("./example_data/data.txt") #code="id+comment",  start="2023-11-13 11:43:00", end="2023-11-13 12:09:00"

display(df_room1)

# dataframes = wric.preprocess_WRIC_files('id.csv', 'upload')

# R1_metadata, R2_metadata, df_room1, df_room2 = dataframes["2"]

# display(df_room1)