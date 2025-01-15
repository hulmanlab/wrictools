# Example Usage in R

This file explains how to import and use the WRIC_preprocessing function in R. 

If you instead want to use the functions in Python, please click below.

[![pt-br](https://img.shields.io/badge/Python-yellow.svg)](https://github.com/NinaZiegenbein/WRIC_processing/blob/main/README.python.md)

First we need to import the R file as a source to be able to use the functions (see Quickstart).

## Quickstart
```R
source('wric_processor.R')
```

Each function in the file has a detailed docstring explaining what the function does and which parameter it needs. The functions are modular, so you can flexibly use them how you need them. 

You can read the docstring in the file or get it shown using the [docstring package](https://cran.r-project.org/web/packages/docstring/vignettes/docstring_intro.html). Install using `install.package("docstring")` and call any function `docstring(function_name)` or shortly `?function_name` to see the docstring.

## Dependencies
The code needs the following packages. You can easily install them with `install.packages("package_name")` in the terminal.
- [dplyr](https://dplyr.tidyverse.org/)
- [readr](https://readr.tidyverse.org/)
- [RCurl](https://cran.r-project.org/web/packages/RCurl/index.html)
- [stringr](https://stringr.tidyverse.org/)

## Preprocess Local WRIC file(s)
If you have a WRIC (txt) file locally and want to preprocess it: That means reading the metadata at the top of the file, extracting the data from the txt format into a csv format, only including certain rows between start and end of the study, adding a relative time measurement, combining the two measurements, splitting by room1 and room2 and saving the data as a csv. Some of these actions are optional, so you can choose based on the parameters you provide.

_Note: The data.txt in the example_data folder is random data in the same form and is just to highlight the data pipeline, but should not be used for actual analysis!_

```R
result <- preprocess_WRIC_file("./example_data/data.txt")
R1_metadata <- result$R1_metadata
R2_metadata <- result$R2_metadata
df_room1 <- result$df_room1
df_room2 <- result$df_room2
```

The above code specifies only the necessary parameter "filepath" and assumes the default values for all other parameters. But you can specify these parameters for yourself, as can be seen below. As these are the default options the two function calls return exactly the same results.

```R
result <- preprocess_WRIC_file(
    "./example_data/data.txt", 
    code="id", 
    manual=NULL, 
    save_csv=TRUE, 
    path_to_save=NULL, 
    combine=NULL, 
    method="mean",
    start=NULL,
    end=NULL,
    notefilepath= NULL
)
```
Here are explanations and options to all parameters you can specify:
- **filepath:** [String, filepath] Directory path to the WRIC .txt file.
- **code** [String] Method for generating subject IDs. Default is "id", also possible to specify "id+comment", where both ID and comment values are combined or "manual", where you can specify your own.
- **manual** [String] Custom codes for subjects in Room 1 and Room 2 if `code` is "manual".
- **save_csv** [Logical], whether to save extracted metadata and data to CSV files or not. Default is True
- **path_to_save** [String] Directory path for saving CSV files, NULL uses the current directory, NULL is Deafult.
- **combine** [Logical], whether to combine S1 and S2 measurements. Default is True
- **method** [String] Method for combining measurements ("mean", "median", "s1", "s2", "min", "max").
- **start** [character or POSIXct or NULL], rows before this will be removed, if NULL takes first row e.g "2023-11-13 11:43:00"
- **end** [character or POSIXct or NULL], rows after this will be removed, if NULL takes last rows e.g "2023-11-13 11:43:00"
- **notefilepath:**
If you specify a path to the corresponding notefile, the code will try to automatically extract the datetime and current protocol specification (sleeping, exercising, eating etc). If possible please read the "How To Note" *(#TODO: Link to file)* File, before you start your study for consistent note taking. If there is a TimeStamp in the note e.g "Participants starts eating at 16:10", the time of the creation of the note will be overwritten with the time specified in the free-text of the note. The "protocol" is extracted by keyword search. You can check currently included keywords and extend them by checking the keywords_dict in the extract_note_info() function of the WRIC_preprocessing.R file. 
*#TODO: Add functionality to add keywords just for a single run (e.g. when package on CRAN has to be that way)*

The function returns a list with "R1_metadata", "R2_metadata", "df_room1" and "df_room2". Each item of the list is a DataFrame of either the metadata or the preprocessed actual data for either room 1 or 2. If ´save_csv` is True, then the DataFrames will be saved as csv files with "id_visit_WRIC_data.csv" or "id_visit_WRIC_metadata.csv".



## Preprocess multiple files on RedCap
If you want to preprocess multiple files and access them on the RedCap Server using a csv-file containing the record IDs:

To access the data on RedCap you first need to set up a `config.r` file. You can use the `config_example.r` as a template and input your personal API-Token to the repository with the data (see 'Get your API Token for RedCap' below). Make sure that if the config.r file stays locally and without anyone else having access to it. When handling sensitive data it might make sense to delete the token from the file after using it.

Besides setting up the config file, you need to specify the field-name of your RedCap instrument where the raw WRIC-data is located (in the example below the field is named "WRIC_raw") and you need to provide the record IDs of the records that you want to access. They simply need to be written in a column with no further words or comments and need to match the record IDs on RedCap.

_Please note that the code below will not work for you until you 1) set up the config file, 2) create a csv with record ids and change the file path, 3) write the correct field name of your project._

```R
result <- preprocess_WRIC_files("./example_data/record_ids.csv", "WRIC_raw", code = "id", manual = NULL, save_csv = True, path_to_save = NULL, combine = True, method = "mean", start = NULL, end = NULL)
R1_metadata <- result$R1_metadata
R2_metadata <- result$R2_metadata
df_room1 <- result$df_room1
df_room2 <- result$df_room2
```

## Get your API Token for RedCap
- Go to your project and click on **API** in the menu on the left hand side
  - If you can not find the API option in the menu, you might have to adjust the rights to your project by clicking on **User Rights** and adjusting your API rights (or the creator of the project, if that is not you)
- You have to request the generation of an API Token (in my experience takes only a couple hours)
- At the same place you can find your Token after your request has been approved and the token generated

## Uploading Data to RedCap
You can use function `upload_file_to_redcap(fielpath, record_id, fieldname)` to upload a file to a specific record and fieldname in RedCap. You need to have set-up your config file.

# Support, Maintenance and Future Work
For any issues, questions, or suggestions feel free to reach out to Nina Ziegenbein at nina.ziegenbein@rm.dk.

If you encounter any bugs or issues while using this project, please open an issue on the GitHub repository with a detailed description, including steps to reproduce the problem, the expected behavior, and the actual outcome.

I plan to incorporate more functions, including functions for data analysis, methane-burn tests and visualizations in the near future. If you would like to contribute or have feature requests, feel free to submit a pull request with your suggested additions. 

