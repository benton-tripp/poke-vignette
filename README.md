-   [Vignette - Pokémon Species
    Analysis](#vignette---pokémon-species-analysis)
    -   [Overview](#overview)
    -   [Load Required Packages](#load-required-packages)
    -   [Define Functions](#define-functions)
        -   [Get Data](#get-data)
        -   [Data Cleaning](#data-cleaning)
        -   [Other Functions](#other-functions)
    -   [Basic Example](#basic-example)
    -   [Analysis Example](#analysis-example)

# Vignette - Pokémon Species Analysis

Benton Tripp <br> 2023-06-14

## Overview

## Load Required Packages

Required packages:

-   httr
-   jsonlite
-   dplyr
-   ggplot2
-   tidyr
-   stringr
-   glue
-   purrr

<!-- -->

    # Load required packages
    library(httr)
    library(jsonlite)
    library(dplyr)
    library(ggplot2)
    library(tidyr)
    library(stringr)
    library(glue)
    library(purrr)

## Define Functions

This section defines a series of functions for retrieving and cleaning
data from the Pokémon API. These functions are designed to interact with
different endpoints of the Pokémon API, process the data, and perform
various operations that will be used in the subsequent analysis example.

### Get Data

These are the primary functions being used to fetch data from the
Pokémon API. The `get_from_url` function fetches data from a given URL
directly, while the `get_data` function fetches data from a using the
base URL and a user-defined endpoint (using the `get_from_url`
function). The `get_generation` function fetches the names of all
Pokémon species from a specific generation. These functions are the
“backbone” of the data retrieval process.

    # Function to get data from a specific URL
    # Args:
    #   url: A string representing the URL from which to fetch data.
    # Returns:
    #   A list containing the data fetched from the URL, parsed from JSON format.
    get_from_url <- function(url) {
      # Send a GET request to the specified URL
      response <- GET(url)
      
      # Parse the response content from JSON format, flatten the list, and return it
      fromJSON(content(response, "text"), flatten=T)
    }

    # Function to get data from a specific endpoint of the Pokémon API
    # Args:
    #   endpoint: A string representing the endpoint of the Pokémon API from which to fetch data.
    #   id_or_name: A string or integer representing the ID or name of the Pokémon species to fetch data for.
    #   base_url: A string representing the base URL of the Pokémon API. Defaults to "https://pokeapi.co/api/v2/".
    # Returns:
    #   A list containing the data fetched from the specified endpoint of the Pokémon API, parsed from JSON format.
    get_data <- function(endpoint, id_or_name, base_url="https://pokeapi.co/api/v2/") {
      # Construct the full URL by appending the endpoint and ID/name to the base URL
      url <- paste0(base_url, endpoint, "/", id_or_name)
      
      # Try to fetch data from the URL, and return NULL if an error occurs
      tryCatch(
        {
          get_from_url(url)
        },
        error = function(e) NULL
      )
    }

    # Function to get the names of all Pokémon species from a specific generation
    # Args:
    #   gen_id: A string representing the ID of the generation to fetch Pokémon species names for.
    # Returns:
    #   A character vector containing the names of all Pokémon species from the specified generation.
    get_generation <- function(gen_id) {
      # Fetch data from the "generation" endpoint of the Pokémon API for the specified ID
      # and extract the names of all Pokémon species
      get_data("generation", gen_id)$pokemon_species$name
    }

### Data Cleaning

The data cleaning functions are designed to process and clean the data
in a manner that enables them to be suitable for a tabular dataset. When
retrieved initially, the JSON data is read into R as nested lists. These
functions help to extract the relevant information from within the
sub-lists, and put everything into a single named list.

The `process_chain` and `clean_evolution_chain` functions process the
evolution chain data:

    # Recursive function to process the evolution chain
    # Args:
    #   chain: A list representing the evolution chain to process.
    #   level: An integer representing the current level of the evolution chain. Defaults to 1.
    # Returns:
    #   A data frame containing the species and evolution level for each stage of the evolution chain.
    process_chain <- function(chain, level = 1) {
      # Extract the species and evolution details
      if ("species.name" %in% names(chain)) {
        species <- chain$species.name
      } else {
        species <- chain$species$name
      }
      evolution_details <- tryCatch(expr={
        if ("evolution_details" %in% names(chain$evolves_to)) {
            chain$evolves_to
          } else {
            chain$evolves_to[[1]]
          }
      }, error = function(e) NULL)
      
      if (is.null(evolution_details)) return(-1)
      
      # Create a data frame for the current level
      df <- data.frame(species = species, 
                       ev.level = level, 
                       stringsAsFactors = F)
      
      # If there are more levels, process them recursively
      if (length(evolution_details) > 0) {
        df_next <- process_chain(evolution_details, level + 1)
        df <- rbind(df, df_next)
      }
      return(df)
    }

    # Function to clean the evolution chain data
    # Args:
    #   data: A list representing the Pokémon data to clean.
    # Returns:
    #   The cleaned Pokémon data with the evolution chain data replaced by a string and a progress value.
    clean_evolution_chain <- function(data) {
      # Extract evolution_chain data
      e.chain <- get_from_url(data$evolution_chain$url)$chain %>% 
        process_chain()
      if (is.data.frame(e.chain)) {
        e.chain.str <- paste(e.chain$species, collapse=", ")
        e.chain <- subset(e.chain, species==data$name)$ev.level / max(e.chain$ev.level)
      } else {
        e.chain.str <- ""
      }
      # Replace evolution_chain 
      data$evolution_progress <- e.chain
      data$evolution_chain <- e.chain.str
      return(data)
    }

The `clean_pal_park_encounters` function cleans the Pal Park encounters
data:

    # Function to clean the Pal Park encounters data
    # Args:
    #   data: A list representing the Pokémon data to clean.
    # Returns:
    #   The cleaned Pokémon data with the Pal Park encounters data replaced by separate fields.
    clean_pal_park_encounters <- function(data) {
      ppe <- data$pal_park_encounters
      data$pal_park_encounters <- NULL
      data$pal_park_encounters_base_score <- ppe$base_score
      data$pal_park_encounters_rate <- ppe$rate
      data$pal_park_encounters_area <- ppe$area.name
      return(data)
    }

The `clean_stats` function extracts and cleans the Pokémon stats data:

    # Function to clean the Pokémon stats data
    # Args:
    #   data: A list representing the Pokémon data to clean.
    # Returns:
    #   The cleaned Pokémon data with the stats data replaced by separate fields.
    clean_stats <- function(data) {
      pokemon_stats <- data$stats
      data$stats <- NULL
      # Extract stat names from pokemon_stats
      stat_names <- unique(pokemon_stats$stat.name)
      # Create new names by prepending "base_" to stat names
      new_names <- paste0("base_", gsub("-", "_", stat_names))
      for (i in seq_along(stat_names)) {
        data[[new_names[i]]] <- subset(pokemon_stats, stat.name == stat_names[i])$base_stat
      }
      return(data)
    }

The `clean_data` function is a comprehensive function that applies all
the cleaning operations to the data:

    # Comprehensive function to clean the Pokémon data
    # Args:
    #   data: A list representing the Pokémon data to clean.
    #   data_group: A string representing the group of the data. Can be "species" or "pokemon". Defaults to "species".
    # Returns:
    #   The cleaned Pokémon data with all the cleaning operations applied.
    clean_data <- function(data, data_group="species") {
      data <- map(data, function(selected) {
        if (is.data.frame(selected)) {
          if ("language.name" %in% names(selected)) {
            selected <- selected %>%
              filter(language.name == "en")
          } 
        }
        
        if ("name" %in% names(selected)) {
          return(selected$name)
        } else if ("genus" %in% names(selected)) {
          return(selected$genus)
        } else {
          return(selected)
        }
      })
      if (data_group == "species") {
        data <- data %>% 
          clean_evolution_chain() %>%
          clean_pal_park_encounters()
      } else if (data_group == "pokemon") {
        data <- data %>% clean_stats()
        data$moves <- data$moves$move.name
        data$held_items <- data$held_items$item.name
        data$types <- data$types$type.name
        data$abilities <- data$abilities$ability.name
      }
      return(data)
    }

### Other Functions

The `get_species` and `get_pokemon` functions fetch and clean data about
a specific Pokémon species and a specific Pokémon respectively, applying
the `get_data` and `clean_data` functions, as well as removing
unnecessary variables.

    # Function to get and clean data about a Pokémon species
    # Args:
    #   id_or_name: A string or numeric representing the ID or name of the Pokémon species.
    # Returns:
    #   A cleaned list of data about the Pokémon species.
    get_species <- function(id_or_name) {
      id_or_name <- tolower(as.character(id_or_name))
      data <- get_data("pokemon-species", id_or_name)
      data <- data[!(names(data) %in% c("flavor_text_entries", "pokedex_numbers", "varieties", 
                                        "names", "form_descriptions", "evolves_from_species",
                                        "order", "past_types", "is_default", "forms"))] %>%
        clean_data()
      return(data)
    }

    # Function to get and clean data about a specific Pokémon
    # Args:
    #   id_or_name: A string or numeric representing the ID or name of the Pokémon.
    # Returns:
    #   A cleaned list of data about the Pokémon.
    get_pokemon <- function(id_or_name) {
      id_or_name <- tolower(as.character(id_or_name))
      data <- get_data("pokemon", id_or_name)
      data <- data[!(names(data) %in% c("sprites", "order", "location_area_encounters", 
                                        "game_indices", "is_default", "forms", "past_types",
                                        "past_abilities"))] %>%
        clean_data(data_group="pokemon")
      return(data)
    }

The `get_all_vars` function fetches a character vector of all abilities,
types, or moves:

    # Function to get a character vector of all abilities, types, or moves
    # Args:
    #   v: A string representing the type of data to fetch. Can be "ability", "type", or "move". Defaults to "ability".
    #   base_url: A string representing the base URL of the API. Defaults to "https://pokeapi.co/api/v2/".
    # Returns:
    #   A character vector of all abilities, types, or moves.
    get_all_vars <- function(v=c("ability", "type", "move"), base_url="https://pokeapi.co/api/v2/") {
      v <- tolower(v)
      v <- match.arg(v) 
      get_from_url(paste0(base_url, glue("/{v}?offset=0&limit=1000")))$results$name 
    }

The `get_gen_data` function fetches and cleans data for all Pokémon
species from a specific generation:

    # Function to get and clean data for all Pokémon species from a specific generation
    # Args:
    #   generation_id: A string or numeric representing the ID of the generation.
    #   cache: A boolean indicating whether to use cached data if available. Defaults to TRUE.
    #   cache_loc: A string representing the location of the cache. Defaults to "data".
    #   verbose: A boolean indicating whether to print progress messages. Defaults to TRUE.
    # Returns:
    #   A cleaned list of data for all Pokémon species from the specified generation.
    get_gen_data <- function(generation_id, cache=T, cache_loc="data", verbose=T) {
      if (cache) {
        fpath <- file.path(cache_loc, paste0(generation_id, ".RDS"))
        if (file.exists(fpath)) {
          return(readRDS(fpath))
        } 
      } 
      gen_names <- get_generation(generation_id)
      if (verbose) cat(glue("{Sys.time()} - Getting species data for {generation_id}...\n\n"))
      gen_species_data <- map(gen_names, ~get_species(.x))
      if (verbose) cat(glue("{Sys.time()} - Getting pokemon data for {generation_id}...\n\n"))
      gen_pokemon_data <- map(gen_names, ~get_pokemon(.x))
      names(gen_species_data) <- gen_names
      # Remove uncommon cases where multiple varieties of same species
      mask <- map_lgl(gen_pokemon_data, ~length(.x) > 0)
      gen_species_data <- gen_species_data[mask]
      gen_pokemon_data <- gen_pokemon_data[mask]
      # Combine data from two endpoints
      combined_data <- modifyList(gen_species_data, gen_pokemon_data)
      if (cache) {
        if (!dir.exists(cache_loc)) dir.create(cache_loc)
        saveRDS(combined_data, fpath)
      }
      return(combined_data)
    }

The `make_tabular_data` function transforms the data into a tabular
format:

    # Function to transform the data into a tabular format
    # Args:
    #   data: A list representing the Pokémon data to transform.
    # Returns:
    #   A data frame representing the Pokémon data in a tabular format.
    make_tabular_data <- function(data) {
      data <- lapply(data, function(x) {
        lapply(x, function(y) {
          if (is.vector(y) && length(y) > 1) {
            return(paste(y, collapse = ", "))
          } else {
            return(y)
          }
        })
      })
      
      df <- map_df(data, ~.x)

      return(df)
    }

The `get_bulk_data` function fetches and cleans data for all Pokémon
species from multiple generations:

    # Function to get and clean data for all Pokémon species from multiple generations
    # Args:
    #   gen_ids: A character vector representing the IDs of the generations. Defaults to all generations.
    #   cache: A boolean indicating whether to use cached data if available. Defaults to TRUE.
    #   cache_loc: A string representing the location of the cache. Defaults to "data".
    #   verbose: A boolean indicating whether to print progress messages. Defaults to TRUE.
    # Returns:
    #   A cleaned data frame of data for all Pokémon species from the specified generations.
    get_bulk_data <- function(gen_ids=c("generation-i", "generation-ii", "generation-iii",
                                        "generation-iv", "generation-v", "generation-vi",
                                        "generation-vii", "generation-viii", "generation-ix"), 
                              cache=T, cache_loc="data", verbose=T) {
      
      data <- map(gen_ids, ~get_gen_data(.x, cache, cache_loc, verbose)) %>% 
        unlist(recursive=F) %>% 
        make_tabular_data()
      
      return(data)
    }

## Basic Example

This basic example demonstrates how to fetch data for the Pokémon
species “Pikachu”, clean the data, and combine the data from the species
and Pokémon endpoints into a single dataset:

    # Example usage
    species_data <- get_species("pikachu")
    pokemon_data <- get_pokemon("pikachu")

    # Combine data from two endpoints
    combined_data <- modifyList(species_data, pokemon_data)

    str(combined_data)

    ## List of 37
    ##  $ base_happiness                : int 50
    ##  $ capture_rate                  : int 190
    ##  $ color                         : chr "yellow"
    ##  $ egg_groups                    : chr [1:2] "ground" "fairy"
    ##  $ evolution_chain               : chr "pichu, pikachu, raichu"
    ##  $ forms_switchable              : logi FALSE
    ##  $ gender_rate                   : int 4
    ##  $ genera                        : chr "Mouse Pokémon"
    ##  $ generation                    : chr "generation-i"
    ##  $ growth_rate                   : chr "medium"
    ##  $ habitat                       : chr "forest"
    ##  $ has_gender_differences        : logi TRUE
    ##  $ hatch_counter                 : int 10
    ##  $ id                            : int 25
    ##  $ is_baby                       : logi FALSE
    ##  $ is_legendary                  : logi FALSE
    ##  $ is_mythical                   : logi FALSE
    ##  $ name                          : chr "pikachu"
    ##  $ shape                         : chr "quadruped"
    ##  $ evolution_progress            : num 0.667
    ##  $ pal_park_encounters_base_score: int 80
    ##  $ pal_park_encounters_rate      : int 10
    ##  $ pal_park_encounters_area      : chr "forest"
    ##  $ abilities                     : chr [1:2] "static" "lightning-rod"
    ##  $ base_experience               : int 112
    ##  $ height                        : int 4
    ##  $ held_items                    : chr [1:2] "oran-berry" "light-ball"
    ##  $ moves                         : chr [1:101] "mega-punch" "pay-day" "thunder-punch" "slam" ...
    ##  $ species                       : chr "pikachu"
    ##  $ types                         : chr "electric"
    ##  $ weight                        : int 60
    ##  $ base_hp                       : int 35
    ##  $ base_attack                   : int 55
    ##  $ base_defense                  : int 40
    ##  $ base_special_attack           : int 50
    ##  $ base_special_defense          : int 50
    ##  $ base_speed                    : int 90

## Analysis Example

In this section, a more comprehensive analysis of the data fetched from
the Pokémon API is conducted. The analysis includes data cleaning,
feature engineering, exploratory data analysis, and clustering. We
create histograms, density plots, and boxplots for different variables
in the dataset. This provides insights into data distribution and helps
to identify potential outliers.

This section also demonstrates a potential use-case of the data use
Principal Component Analysis (PCA) and K-means clustering to group
Pokémon species based on their similarities. The results of the
clustering analysis are visualized using 2D and 3D scatter plots.

The first step of this analysis is to get the data for all 9 generations
(the default of the `get_bulk_data` function):

    all_data <- get_bulk_data(verbose=T)

To better understand what data is actually usable, create a bar plot
depicting “NA” counts by variable (only include variables with NA
counts):

    # Calculate NA counts
    na_counts <- sapply(all_data, function(x) sum(is.na(x)))

    # Keep only variables with NA counts
    na_counts <- na_counts[na_counts > 0]

    # Convert to data frame for plotting
    na_counts_df <- data.frame(variable = names(na_counts), count = na_counts)

    # Create bar plot
    ggplot(na_counts_df, aes(x = variable, y = count)) +
      geom_bar(stat = "identity", fill="darkblue") +
      theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
      labs(title = "NA Counts by Variable", x = "Variable", y = "Count of NAs")

![](README_files/figure-markdown_strict/na-bar-1.png)

Create the same plot, but have the bars be stacked, and colored by the
“generation” variable:

    # Calculate proportion of NAs in each column for each generation
    na_prop <- all_data %>%
      group_by(generation) %>%
      summarise(across(everything(), ~mean(is.na(.))))

    # Reshape data for plotting
    na_prop_long <- na_prop %>%
      pivot_longer(-generation, names_to = "variable", values_to = "prop_na")

    # Filter to include only variables with NAs
    na_prop_long <- na_prop_long %>%
      filter(prop_na > 0)

    # Create stacked bar plot
    ggplot(na_prop_long, aes(x = variable, y = prop_na, fill = generation)) +
      geom_bar(stat = "identity") +
      scale_fill_brewer(palette = "Paired") +
      theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
      labs(title = "Proportion of NAs by Variable and Generation", x = "Variable", y = "Proportion of NAs")

![](README_files/figure-markdown_strict/na-bar-stacked-1.png)

<hr>
