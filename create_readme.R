# Use the render function to convert the .Rmd file to the README.md file
rmarkdown::render("btripp-project1.Rmd", output_format = "md_document", output_file="README.md")