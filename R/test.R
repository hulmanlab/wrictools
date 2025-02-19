# source('config.R')
source('R/WRIC_preprocessing.R')
library(RCurl)
# TODO: Check all cases - currently problem iwth converting end from notefile to POSIXct 
no_comment_file = "/Users/au698484/Documents/data_wric_no_comment.txt"

example_dict <- list(
    sleeping = list(keywords = list(c("blabla", "sleeping", "bed", "sove", "soeve", "godnat", "night", "sleep")), value = 1), 
    eating = list(keywords = list(c("start", "begin", "began"), c("maaltid", "måltid", "eat", "meal", "food", "spis", "maal", "måd", "mad", "frokost", "morgenmad", "middag", "snack", "aftensmad")), value = 2), 
    stop_sleeping = list(keywords = list(c("vaagen", "vågen", "vaekke", "væk", "wake", "woken", "vaagnet")), value = 0), 
    stop_anything = list(keywords = list(c("faerdig", "færdig", "stop", "end ", "finished", "slut")), value = 0), 
    activity = list(keywords = list(c("start", "begin", "began"), c("step", "exercise", "physical activity", "active", "motion", "aktiv")), value = 3), 
    ree_start = list(keywords = list(c("start", "begin", "began"), c("REE", "BEE", "BMR", "RMR", "RER")), value = 4)
)


result <- preprocess_WRIC_file("./example_data/data.txt", code="id+comment", notefilepath="./example_data/note.txt", keywords_dict = example_dict)#, start="2023-11-13 11:43:00", end="2023-11-13 12:09:00") # "C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt"
R1_metadata <- result$R1_metadata
R2_metadata <- result$R2_metadata
df_room1 <- result$df_room1
df_room2 <- result$df_room2

str(df_room1)

print("Done")
#tr(df_room1)

#dataframes <- preprocess_WRIC_files('id.csv', 'upload')

# Example: Access `df_room1` for a specific record ID (e.g., record ID 12345)
#df_room1_example <- dataframes[["2"]]$df_room1
# str(df_room1_example)

# avoid cross-plattform errors by setting the certificate globally
#download.file(url = "https://curl.se/ca/cacert.pem", destfile = "cacert.pem")
#options(RCurlOptions = list(cainfo = "cacert.pem"))

#file_path <- './tmp/export.raw.txt'
#file_content <- paste(readLines(file_path), collapse = "\n")

#result <- postForm(
#    api_url,
#    token=api_token,
#    content='file',
#    action='import',
#    record='2',
#    field='upload',
#    returnFormat='json',
#    file = file_content
#)

#result = detect_start_end("C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt")
#print(result)
#print(result[1])

# notes_path = "C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt"
# returns = extract_note_info(notes_path, df_room1, df_room2)
# df_room1 <- returns$df_room1
# df_room2 <- returns$df_room2
#str(df_room1)

?extract_note_info