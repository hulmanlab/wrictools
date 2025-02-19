# Example Usage in R

This file explains how to import and use the WRIC_preprocessing function in R. 

If you instead want to use the functions in Python, please click below.

[![pt-br](https://img.shields.io/badge/Python-yellow.svg)](https://github.com/NinaZiegenbein/WRIC_processing/blob/main/README.python.md)

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

## Getting Started

To get started with the WRIC preprocessing code in R, follow these steps:

### 1. **Download the File (or Entire Repository)**
If you only want the functions for (pre)processing your files, it is enough to download [this R file](https://github.com/hulmanlab/WRIC_processing/blob/main/R/WRIC_preprocessing.R). If you want to also check out test files, use the example data, config example etc. I would recommend downloading the entire repository. There are two options to do so:

- **Clone the repository with Git:**  
  If you don't have Git installed, follow the [installation instructions here](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).  
  Once Git is installed, run the following command in your terminal or command prompt to clone the repository:
  
  `git clone https://github.com/hulmanlab/WRIC_processing.git`

  The advantage is that you just need to run `git pull` and all updates I have "pushed" (uploaded to the repository) will be downloaded aka updated.

- **Download the repository as a ZIP file:**  
  Alternatively, you can download the repository as a ZIP file from [here](https://github.com/hulmanlab/WRIC_processing/archive/refs/heads/main.zip) and unzip it on your local machine without needing to install GitHub and making an account etc.

### 2. **Set Your Working Directory in RStudio**
After you’ve downloaded or cloned the repository, open RStudio. You will need to set your working directory to the folder where the R files are located (or the folder containing the repository you downloaded). This ensures R can locate the necessary files and dependencies without error messages.

- To set your working directory, you can use the following command in the RStudio console:
  
  `setwd("/path/to/WRIC_processing.R")`
  
  Replace `/path/to/WRIC_processing.R` with the actual path to the folder where the repository is located on your machine. You can also navigate to the desired directory manually in RStudio:
  - Go to the **Session** menu.
  - Click **Set Working Directory** > **Choose Directory**.
  - Select the folder where the repository is located.

If you do not want to do that, you can also specify the path infront of the source command you see below.

### 3. **Import the Script**
Once your working directory is set, you can load the script to access the functions.

In the RStudio console, type the following command: `source('WRIC_preprocessing.R')`

or `source('R/WRIC_preprocessing.R')` if you have downloaded the entire repository.
  
This imports the file so you can start using the functions inside it.

### 4. **Run the Functions**
Now that the script is loaded, you can start using the functions as described below. If you need more detailed usage, refer to the function docstrings or use `?function_name` to access the documentation for each function.


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
    notefilepath= NULL,
    keywords_dict=NULL
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
If you specify a path to the corresponding notefile, the code will try to automatically extract the datetime and current protocol specification (sleeping, exercising, eating etc). If possible please read the [How To Note File](https://github.com/hulmanlab/WRIC_processing/blob/main/HowToNoteFile.pdf), before you start your study for consistent note taking. If there is a TimeStamp in the note e.g "Participants starts eating at 16:10", the time of the creation of the note will be overwritten with the time specified in the free-text of the note. The "protocol" is extracted by keyword search. You can check currently included keywords and extend them by checking the keywords_dict in the extract_note_info() function of the WRIC_preprocessing.R file. 
- **keywords_dict:** [Nested List] A "dictionary" with keywords for extracting protocol information out of the notefile.

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
You can use function `upload_file_to_redcap(filepath, record_id, fieldname)` to upload a file to a specific record and fieldname in RedCap. You need to have set-up your config file.

# Support, Maintenance and Future Work
For any issues, questions, or suggestions feel free to reach out to Nina Ziegenbein at nina.ziegenbein@rm.dk.

If you encounter any bugs or issues while using this project, please open an issue on the GitHub repository with a detailed description, including steps to reproduce the problem, the expected behavior, and the actual outcome.

I plan to incorporate more functions, including functions for data analysis, methane-burn tests and visualizations in the near future. If you would like to contribute or have feature requests, feel free to submit a pull request with your suggested additions. 

