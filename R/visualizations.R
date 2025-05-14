library(ggplot2)
library(dplyr)
library(readr)

visualize_with_protocol <- function(csv_file, plot = "RER", protocol_colors_labels = NULL, save_png = FALSE, path_to_save = NULL) {
#' Visualizes time-series data from a WRIC CSV file, highlighting protocol changes and optionally saving the plot.
#'
#' @param csv_file Path to the CSV file containing time-series data.
#' @param plot A string specifying the column to plot. Defaults to "RER". This can be any valid column name in the CSV file.
#' @param protocol_colors_labels A data frame containing the protocol codes, colors, and labels. If `NULL`, defaults to a predefined set of protocols.
#' @param save_png Logical, whether to save the plot as a PNG file. Defaults to `FALSE`.
#' @param path_to_save Directory path for saving the PNG file. If `NULL`, saves in the current working directory.
#' @return A ggplot2 object visualizing the specified data with protocol highlights. Optionally saves the plot to a file if `save_png` is `TRUE`.
#' 
#' @examples
#' visualize_with_protocol("path/to/data.csv", plot = "Energy Expenditure (kcal/min)", save_png = TRUE)

  if (is.null(protocol_colors_labels)) {
    # Default protocol colors and labels
    protocol_colors_labels <- data.frame(
      protocol = c(0, 1, 2, 3, 4),
      color = c("white", "blue", "orange", "yellow", "green"),
      label = c("Normal", "Sleep", "Eating", "Exercise", "REE")
    )
  }
  df <- read_csv(csv_file, show_col_types = FALSE)
  #dataframes[[substr(basename(csv_file), 1, 7)]] <- df
  file_name = sub("\\.[^\\.]+$", "", basename(csv_file))
  
  p <- ggplot(df, aes(x = `relative_time`, y = .data[[plot]])) +
      geom_line(color = "blue") +
      labs(title = paste(plot, "Over Time for", basename(csv_file)),
          x = "Relative Time (min)",
          y = plot) +
      theme_minimal() 
  
  # If RER zoom to only physiologically possible values
  if (plot == "RER") {
    p <- p + coord_cartesian(ylim = c(0.5, 1.2))  # Zoom if plot is "RER"
  }

  # Add protocol highlighting
  p <- p +
      geom_rect(data = df, aes(xmin = `relative_time`, 
                              xmax = lead(`relative_time`, default = max(`relative_time`)), 
                              ymin = -Inf, ymax = Inf, 
                              fill = factor(protocol)), alpha = 0.3) +
      scale_fill_manual(values = setNames(protocol_colors_labels$color, as.character(protocol_colors_labels$protocol)),
                      labels = protocol_colors_labels$label, name = "Protocol")  
  print(p)  # Display the plot

  if (save_png) {
    if (plot == "Energy Expenditure (kcal/min)") {
      plot <- "EnergyExpenditureKcal"
    } else if (plot == "Energy Expenditure (kJ/min)") {
       plot <- "EnergyExpenditureKJ"
    }
    plot_filename <- ifelse(!is.null(path_to_save), 
                            paste0(path_to_save, "/", file_name, "_", plot, "_plot.png"), 
                            paste0(file_name, "_", plot, "_plot.png"))
    print(plot_filename)
    ggsave(plot_filename, plot = p, width = 12, height = 6, dpi = 600)
  }
}

