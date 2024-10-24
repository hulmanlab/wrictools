source('wric_preprocessing.R')

result <- preprocess_WRIC_file("./example_data/data.txt")
R1_metadata <- result$R1_metadata
R2_metadata <- result$R2_metadata
df_room1 <- result$df_room1
df_room2 <- result$df_room2

print("Done")
print(df_room1)