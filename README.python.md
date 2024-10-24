# Example Usage in Python

This file explains how to import and use the WRIC_preprocessing function in Python. 

If you instead want to use the functions in R, please click below.

[![en](https://img.shields.io/badge/R-blue.svg)](https://github.com/NinaZiegenbein/WRIC_processing/blob/main/README.R.md)

First we need to import the python files to be able to use the functions (see Quickstart).

## Quickstart
```python
import WRIC_preprocessing as wric
R1_metadata, R2_metadata, df_room1, df_room2 = wric.preprocess_WRIC_file("./example_data/data.txt") 
```

Each function in the file has a detailed docstring explaining what the function does and which parameter it needs. The functions are modular, so you can flexibly use them how you need them.

## Preprocess Local WRIC file(s)
If you have a WRIC (txt) file locally and want to preprocess it: That means reading the metadata at the top of the file, extracting the data from the txt format into a csv format, performing a descrepancy check between s1 and s2 measurements, combining the two measurements, splitting by room1 and room2 and saving the data as a csv. Some of these actions are optional, so you can choose based on the parameters you provide.

_Note: The data.txt in the example_data folder is random data in the same form and is just to highlight the data pipeline, but should not be used for actual analysis!_

```python
R1_metadata, R2_metadata, df_room1, df_room2 = wric.preprocess_WRIC_file("./example_data/data.txt") 
display(df_room1)
```
The above code specifies only the necessary parameter "filepath" and assumes the default values for all other parameters. But you can specify these parameters for yourself, as can be seen below. As these are the default options the two function calls return exactly the same results.

```python
R1_metadata, R2_metadata, df_room1, df_room2 = wric.preprocess_WRIC_file("./example_data/data.txt", code = "id", manual = None, save_csv = True, path_to_save = None, combine = True, method = "mean") 
display(df_room1)
```

## Preprocess multiple files on RedCap
If you want to preprocess multiple files and access them on the RedCap Server using a csv-file containing the record IDs:

To access the data on RedCap you first need to set up a `config.py` file. You can use the `config_example.py` as a template and input your personal API-Token to the repository with the data (see 'Get your API Token for RedCap' below). Make sure that if the config.py file stays locally and without anyone else having access to it. When handling sensitive data it might make sense to delete the token from the file after using it.

Besides setting up the config file, you need to specify the field-name of your RedCap instrument where the raw WRIC-data is located (in the example below the field is named "WRIC_raw") and you need to provide the record IDs of the records that you want to access. They simply need to be written in a column with no further words or comments and need to match the record IDs on RedCap.

_Please note that the code below will not work for you until you 1) set up the config file, 2) create a csv with record ids and change the file path, 3) write the correct field name of your project._

```python
R1_metadata, R2_metadata, df_room1, df_room2 =  wric.preprocess_WRIC_files("./example_data/record_ids.csv", "WRIC_raw", code = "id", manual = None, save_csv = True, path_to_save = None, combine = True, method = "mean")
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