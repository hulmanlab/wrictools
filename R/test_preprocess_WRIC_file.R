library(testthat)

# Assuming preprocess_WRIC_file is sourced or loaded from your package

test_that("preprocess_WRIC_file does not throw errors with various inputs", {
  
  # Test with only filepath and default parameters
  expect_error({
    result <- preprocess_WRIC_file("./example_data/data.txt")
  }, NA)

  # Test with specific filepath and code parameter
  expect_error({
    result <- preprocess_WRIC_file("/Users/au698484/Documents/data_wric_no_comment.txt")
  }, NA)

  # Test with filepath, code and notefilepath
  expect_error({
    result <- preprocess_WRIC_file("./example_data/data.txt", 
                                   code = "id+comment", 
                                   notefilepath = "./example_data/note.txt")
  }, NA)

  # Test with filepath, code, notefilepath, and start & end time
  expect_error({
    result <- preprocess_WRIC_file("./example_data/data.txt", 
                                   code = "id+comment", 
                                   notefilepath = "./example_data/note.txt", 
                                   start = "2023-11-13 11:43:00", 
                                   end = "2023-11-13 12:09:00")
  }, NA)

  # Test with filepath, method and code
  expect_error({
    result <- preprocess_WRIC_file("./example_data/data.txt", 
                                   code = "id", 
                                   method = "mean")
  }, NA)

  # Test with filepath, start & end time
  expect_error({
    result <- preprocess_WRIC_file("./example_data/data.txt", 
                                   code = "id+comment", 
                                   start = "2023-11-13 11:43:00", 
                                   end = "2023-11-13 12:09:00")
  }, NA)

  # Test with filepath, code, and manual custom codes (assuming this applies for code == "manual")
  expect_error({
    result <- preprocess_WRIC_file("./example_data/data.txt", 
                                   code = "manual", 
                                   manual = list(Room1 = c("R1_code1", "R1_code2"), Room2 = c("R2_code1", "R2_code2")))
  }, NA)

  # Test with filepath, save_csv and path_to_save
  expect_error({
    result <- preprocess_WRIC_file("./example_data/data.txt", 
                                   save_csv = TRUE, 
                                   path_to_save = "./example_data/")
  }, NA)
  
  # Test with filepath and combine = TRUE
  expect_error({
    result <- preprocess_WRIC_file("./example_data/data.txt", 
                                   combine = TRUE)
  }, NA)
  
})
