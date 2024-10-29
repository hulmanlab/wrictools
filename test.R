source('config.R')
source('wric_preprocessing.R')
library(RCurl)

result <- preprocess_WRIC_file("./example_data/data.txt", code="id+comment", start="2023-11-13 11:43:00", end="2023-11-13 12:09:00")
R1_metadata <- result$R1_metadata
R2_metadata <- result$R2_metadata
df_room1 <- result$df_room1
df_room2 <- result$df_room2

print("Done")
str(df_room1)

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