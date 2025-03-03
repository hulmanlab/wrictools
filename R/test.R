# source('config.R')
source('R/preprocessing.R')
tryCatch({
  source("R/function_docs.R")
}, error = function(e) {
  cat("Documentation file 'function_docs.R' not found. Proceeding without documentation.\n")
})
library(RCurl)

# Then, reassign the docstrings
if (exists("function_docs", envir = .GlobalEnv)) {
  for (func_name in names(function_docs)) {
    if (exists(func_name, envir = .GlobalEnv)) {
      func <- get(func_name, envir = .GlobalEnv)
      assign(func_name, structure(func, doc = function_docs[[func_name]]), envir = .GlobalEnv)    }
  }
}
#TODO: Clean this up try to reduce the unnecessary output generated by R and add this info somewhere on the ReadMe
doc("extract_meta_data")
doc("preprocess_WRIC_file")

# no_comment_file = "/Users/au698484/Documents/data_wric_no_comment.txt"
result <- preprocess_WRIC_file("./example_data/data.txt", path_to_save = "./example_data/new_directory", notefilepath="./example_data/note.txt")#, start="2023-11-13 11:43:00", end="2023-11-13 12:09:00") # "C:/Documents/WRIC_example_data/Main_note_yyyymmddxxxx.txt"
R1_metadata <- result$R1_metadata
R2_metadata <- result$R2_metadata
df_room1 <- result$df_room1
df_room2 <- result$df_room2

# str(df_room1)



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
