
- [Vignette - Pokémon Species
  Analysis](#vignette---pokémon-species-analysis)
  - [Overview](#overview)
  - [Load Required Packages](#load-required-packages)
  - [Define Functions](#define-functions)
    - [Get Data](#get-data)
    - [Data Cleaning](#data-cleaning)
    - [Other Functions](#other-functions)
  - [Basic Example](#basic-example)
  - [Analysis Example](#analysis-example)
    - [Exploratory Analysis](#exploratory-analysis)
    - [PCA and Clustering](#pca-and-clustering)

# Vignette - Pokémon Species Analysis

Benton Tripp <br> 2023-06-14

## Overview

This vignette provides a comprehensive analysis of Pokémon species data,
leveraging the Pokémon API to obtain and process the data. The primary
functions used in this analysis are designed to fetch data from the API,
clean it, and transform it into a tabular data format.

The first part of the vignette focuses on the description and usage of
the functions that are used to fetch and clean the data. The `get_data`
function is a general function used to fetch data from a specific
endpoint of the Pokémon API. For example, the `get_species` is used to
fetch data about the input Pokémon species. Data fetched from each of
the different endpoints is then cleaned and transformed using the
`clean_data` function.

The second part of the vignette provides a basic example of how to use
these functions to fetch and clean data for a specific Pokémon species.
The example demonstrates how to fetch data for the Pokémon species
“Pikachu”, clean the data, and combine the data from the species and
Pokémon endpoints in\` to a single list. oil9 The third part of the
vignette presents an advanced example where a large tabular dataset is
created by fetching and cleaning data for all Pokémon species from all
generations. This dataset is then analyzed, cleaned further, and
engineered to create new features. The analysis provides some basic
insights into the distribution of some of the variables, and where some
data is missing.

The final part of the vignette continues the analysis, and demonstrates
how to use Principal Component Analysis (PCA) and K-means clustering to
group Pokémon species based on their similarities. The results of the
clustering analysis are visualized using 2D and 3D scatter plots,
allowing users to interactively explore the clusters of Pokémon species
and their characteristics.

## Load Required Packages

Required packages:

- `httr`
- `jsonlite`
- `dplyr`
- `ggplot2`
- `tidyr`
- `stringr`
- `reshape2`
- `glue`
- `purrr`
- `caret`
- `factoextra`
- `cluster`
- `plotly`
- `htmlwidgets`

``` r
# Load required packages
library(httr)
library(jsonlite)
library(dplyr)
library(ggplot2)
library(tidyr)
library(stringr)
library(reshape2)
library(glue)
library(purrr)
library(caret)
library(factoextra)
library(cluster)
library(plotly)
library(htmlwidgets)
```

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

``` r
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
```

### Data Cleaning

The data cleaning functions are designed to process and clean the data
in a manner that enables them to be suitable for a tabular dataset. When
retrieved initially, the JSON data is read into R as nested lists. These
functions help to extract the relevant information from within the
sub-lists, and put everything into a single named list.

The `process_chain` and `clean_evolution_chain` functions process the
evolution chain data:

``` r
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
```

The `clean_pal_park_encounters` function cleans the Pal Park encounters
data:

``` r
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
```

The `clean_stats` function extracts and cleans the Pokémon stats data:

``` r
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
```

The `clean_data` function is a comprehensive function that applies all
the cleaning operations to the data:

``` r
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
```

### Other Functions

The `get_species` and `get_pokemon` functions fetch and clean data about
a specific Pokémon species and a specific Pokémon respectively, applying
the `get_data` and `clean_data` functions, as well as removing
unnecessary variables.

``` r
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
```

The `get_all_vars` function fetches a character vector of all abilities,
types, or moves:

``` r
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
```

The `get_gen_data` function fetches and cleans data for all Pokémon
species from a specific generation:

``` r
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
```

The `make_tabular_data` function transforms the data into a tabular
format:

``` r
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
```

The `get_bulk_data` function fetches and cleans data for all Pokémon
species from multiple generations:

``` r
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
```

## Basic Example

This basic example demonstrates how to fetch data for the Pokémon
species “Pikachu”, clean the data, and combine the data from the species
and Pokémon endpoints into a single dataset:

``` r
# Example usage
species_data <- get_species("pikachu")
pokemon_data <- get_pokemon("pikachu")

# Combine data from two endpoints
combined_data <- modifyList(species_data, pokemon_data)

str(combined_data)
```

    ## List of 37
    ##  $ base_happiness                : int 50
    ##  $ capture_rate                  : int 190
    ##  $ color                         : chr "yellow"
    ##  $ egg_groups                    : chr [1:2] "ground" "fairy"
    ##  $ evolution_chain               : chr "pichu, pikachu, raichu"
    ##  $ forms_switchable              : logi FALSE
    ##  $ gender_rate                   : int 4
    ##  $ genera                        : chr "Mouse Pok<U+00E9>mon"
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
to identify potential outliers. A correlation matrix of numerical
variables, and a deeper dive into some of the interactions between
variables is also done.

This section also demonstrates a potential use-case of the data use
Principal Component Analysis (PCA) and K-means clustering to group
Pokémon species based on their similarities. The results of the
clustering analysis are visualized using 2D and 3D scatter plots.

The first step of this analysis is to get the data for all 9 generations
(the default of the `get_bulk_data` function):

``` r
all_data <- get_bulk_data(verbose=T) %>%
  # Create base type (currently split into subtypes)
  mutate(primary_type = str_split(types, ",\\s*") %>% sapply("[", 1)) 
```

### Exploratory Analysis

To better understand what data is actually usable, create a bar plot
depicting “NA” counts by variable (only include variables with NA
counts):

``` r
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
```

![](README_files/figure-gfm/na-bar-1.png)<!-- -->

Create the same plot, but have the bars be stacked, and colored by the
“generation” variable:

``` r
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
```

![](README_files/figure-gfm/na-bar-stacked-1.png)<!-- -->

In this step, histograms and density plots are created for continuous
numeric variable in the dataset:

``` r
# Select variables
vars <- c(grep("^base_", names(all_data), value = T), "weight", "height", "capture_rate", "pal_park_encounters_rate")

# Reshape data to long format
long_data <- all_data %>%
  select(all_of(vars)) %>%
  gather(variable, value)

# Create a single plot with facets for each variable
ggplot(long_data, aes(x = value)) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.5, color="darkblue") +
  geom_density(color = "red", size=.5) +
  facet_wrap(~ variable, scales = "free") +
  labs(title = "Histogram and Density Plots", x = "Value", y = "Density")
```

![](README_files/figure-gfm/num-hist-1.png)<!-- -->

Create boxplots for each of the same variables in the dataset in order
to better understand if the data is symmetrical, how tightly the data is
grouped, and if and how the data is skewed:

``` r
# Create a single plot with facets for each variable
ggplot(long_data, aes(x = variable, y = value)) +
  geom_boxplot(fill = "lightblue", color = "darkblue") +
  facet_wrap(~ variable, scales = "free") +
  labs(title = "Boxplots", x = "Variable", y = "Value")
```

![](README_files/figure-gfm/box-plots-1.png)<!-- -->

Correlation between numeric variables:

``` r
# Correlation of numerical values
corr_matrix <- all_data %>%
  select(all_of(c(grep("^base_", names(all_data), value = T), "weight", "height", "capture_rate"))) %>% 
  select(-base_happiness, -base_experience) %>% # Remove since there are NA values
  cor() %>% 
  melt()

# Plot heatmap
ggplot(corr_matrix, aes(x=Var1, y=Var2, fill=value)) +
  geom_tile() +
  geom_text(aes(label = round(value, 2)), color = "white", size = 3) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0) +
  labs(title = "Correlation Heatmap", x = "", y = "") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
```

![](README_files/figure-gfm/corr-heatmap-1.png)<!-- -->

Summarize size (weight and height) by type:

``` r
# Summarize Pokémon sizes by (primary) type
all_data %>%
  group_by(primary_type) %>%
  summarize(min_weight = min(weight),
            median_weight = median(weight),
            mean_weight = mean(weight),
            max_weight = max(weight),
            min_height = min(height),
            median_height = median(height),
            mean_height = mean(height),
            max_height = max(height))
```

    ## # A tibble: 18 x 9
    ##    primary_type min_weight median_weight mean_weight max_weight min_height
    ##    <chr>             <int>         <dbl>       <dbl>      <int>      <int>
    ##  1 bug                   2         165          326.       3336          1
    ##  2 dark                 21         350          784.       8880          4
    ##  3 dragon               20         530          994.       3800          3
    ##  4 electric              3         235          456.       2400          2
    ##  5 fairy                 1          84.5        280.       2150          1
    ##  6 fighting             40         480          741.       3807          5
    ##  7 fire                 10         307          632.       4300          3
    ##  8 flying               18         275          355.        850          2
    ##  9 ghost                 1         130          380.       2500          1
    ## 10 grass                 1         130          319.       3100          2
    ## 11 ground                8         580         1329.       9500          2
    ## 12 ice                  38         502         1345        8000          3
    ## 13 normal                8         242          448.       4600          2
    ## 14 poison                7         251          639.       9500          2
    ## 15 psychic               1         150          532.       9999          1
    ## 16 rock                 57         682         1224.       8200          3
    ## 17 steel                11         810         2000.       9999          2
    ## 18 water                10         280          551.       3980          3
    ## # i 3 more variables: median_height <dbl>, mean_height <dbl>, max_height <int>

Summarize size (weight and height) by color:

``` r
# Summarize Pokémon sizes by color
all_data %>%
  group_by(color) %>%
  summarize(min_weight = min(weight),
            median_weight = median(weight),
            mean_weight = mean(weight),
            max_weight = max(weight),
            min_height = min(height),
            median_height = median(height),
            mean_height = mean(height),
            max_height = max(height))
```

    ## # A tibble: 10 x 9
    ##    color  min_weight median_weight mean_weight max_weight min_height median_height
    ##    <chr>       <int>         <dbl>       <dbl>      <int>      <int>         <dbl>
    ##  1 black          12          280         779.       8880          3          10  
    ##  2 blue            1          290         692.       9999          1          10  
    ##  3 brown           6          300         671.       9200          2           9  
    ##  4 gray            7          430         923.       8200          2          10  
    ##  5 green           3          164         650.       9999          1          10  
    ##  6 pink            3          155         340.       3100          2           7  
    ##  7 purple          1          211         554.       9500          1          10  
    ##  8 red             3          326.        706.       9500          3          10.5
    ##  9 white           1          322.        793.       8000          1          12  
    ## 10 yellow          2          234         352.       1780          1           9  
    ## # i 2 more variables: mean_height <dbl>, max_height <int>

Compare types with colors:

``` r
# Create contingency table showing primary type vs color
all_data %>%
  count(primary_type, color) %>%
  pivot_wider(names_from = color, values_from = n, values_fill = 0)
```

    ## # A tibble: 18 x 11
    ##    primary_type black  blue brown  gray green purple   red white yellow  pink
    ##    <chr>        <int> <int> <int> <int> <int>  <int> <int> <int>  <int> <int>
    ##  1 bug              2     6     5    11    10      6    19     7     15     0
    ##  2 dark            11     6     7     6     1      4     5     2      1     2
    ##  3 dragon           1     9     1     7     9      3     2     2      1     1
    ##  4 electric         4     7     0     5     3      2     3     4     26     1
    ##  5 fairy            0     2     1     0     1      1     0    11      1    11
    ##  6 fighting         0     5     8    10     1      3     4     5      3     0
    ##  7 fire             0     1    12     1     0      0    37     3      9     0
    ##  8 flying           0     3     0     0     0      3     0     1      0     1
    ##  9 ghost            9     0     5     2     1      9     0     4      1     0
    ## 10 grass            0     5    11     3    57      6     2     5      3     5
    ## 11 ground           2     1    14     8     6      3     2     0      3     0
    ## 12 ice              0     9     3     2     0      1     3    11      0     1
    ## 13 normal           6     7    42    15     2      5     4    14      5    16
    ## 14 poison           3     7     3     2     3     20     0     0      0     0
    ## 15 psychic          4     9     4     1     7      8     0     6      8    10
    ## 16 rock             3    11    15    12     4      2     3     1      3     1
    ## 17 steel            1     4     3    15     4      0     0     2      3     1
    ## 18 water            1    72     6     5     9      8    10     8      2     9

Check whether mythical and legendary the same, or if they ever overlap:

``` r
# Create contingency table showing legendary vs mythical
all_data %>%
  mutate(is_legendary = ifelse(is_legendary, "Legendary", "Not Legendary"),
         is_mythical = ifelse(is_mythical, "Mythical", "Not Mythical")) %>%
  count(is_legendary, is_mythical) %>%
  pivot_wider(names_from = is_legendary, values_from = n, values_fill = 0)
```

    ## # A tibble: 2 x 3
    ##   is_mythical  Legendary `Not Legendary`
    ##   <chr>            <int>           <int>
    ## 1 Not Mythical        58             905
    ## 2 Mythical             0              18

Compare egg groups to types:

``` r
# Get vector of unique egg groups
egg_groups <- all_data$egg_groups %>% 
  map(., ~str_split(.x, ", ")) %>% 
  unlist() %>% 
  unique() %>% 
  sort()

# Create Dummy Variables for egg_groups
egg_groups_v <- strsplit(all_data$egg_groups, ", ")
egg_groups_dummy <- lapply(egg_groups_v, function(x) table(factor(x, levels=egg_groups)))

# Convert list of tables to data frame
egg_groups_dummy <- do.call(rbind, egg_groups_dummy)
colnames(egg_groups_dummy) <- paste0("egg_group_", gsub("-", "_", colnames(egg_groups_dummy)))

# Combine
all_data %>%
  select(primary_type) %>%
  cbind(., egg_groups_dummy) %>%
  pivot_longer(cols = starts_with("egg_group_"), names_to = "egg_group", values_to = "count") %>%
  group_by(primary_type, egg_group) %>%
  summarize(n = sum(count)) %>%
  pivot_wider(names_from = primary_type, values_from = n, values_fill = 0)
```

    ## # A tibble: 15 x 19
    ##    egg_group   bug  dark dragon electric fairy fighting  fire flying ghost grass ground
    ##    <chr>     <int> <int>  <int>    <int> <int>    <int> <int>  <int> <int> <int>  <int>
    ##  1 egg_grou~    76     0      0        0     0        0     2      0     0     0      5
    ##  2 egg_grou~     0     0      0        0     0        0     0      0     0     0      0
    ##  3 egg_grou~     0     5     26        2     0        0     4      2     0     6      5
    ##  4 egg_grou~     2     3      0        7    18        1     0      0     0    11      0
    ##  5 egg_grou~     0     4      1        2     2        2     2      8     0     3      0
    ##  6 egg_grou~     0    19      1       22     5       11    40      0     2    20     21
    ##  7 egg_grou~     2     7      0        2     0       23    11      0     0     2      0
    ##  8 egg_grou~     0     0      3        5     2        0     2      0    24     0      2
    ##  9 egg_grou~     3     0      3        5     2        1     0      0     5     2      5
    ## 10 egg_grou~     0     0      7        5     0        0     4      0     0    15      5
    ## 11 egg_grou~     4     9      8       13     6        7     8      0     3     6      3
    ## 12 egg_grou~     2     0      0        0     1        0     0      0     2    77      2
    ## 13 egg_grou~     2     2      3        5     0        2     0      1     1     0      1
    ## 14 egg_grou~     0     3      1        0     0        0     0      0     0     0      0
    ## 15 egg_grou~     2     0      0        0     0        2     0      0     1     0      0
    ## # i 7 more variables: ice <int>, normal <int>, poison <int>, psychic <int>,
    ## #   rock <int>, steel <int>, water <int>

### PCA and Clustering

Applying the methods used on the egg variables in the previous section,
create dummy variables for categorical variables currently stored as
delimited strings. Then, use the `caret` package to create dummies for
additional categorical data, scale the data, and remove zero or
near-zero-variance predictors.

``` r
# Function to process dummy data
# 
# This function takes a data frame, extracts the abilities, types, moves, and egg groups, 
# and creates dummy variables for each of these categories. It then combines these dummy 
# variables with the original data frame, and removes the original variables.
#
# Args:
#   data: A data frame containing AT LEAST the variables 'abilities', 'types', 'moves', and 
#        'egg_groups'. Each of these variables should be a character string with elements 
#        separated by commas.
#
# Returns:
#   A data frame with the original variables, where abilities', 'types', 'moves', and 
#   egg_groups' are replaced by dummy variables. Each dummy variable indicates the 
#   presence or absence of a particular ability, type, move, or egg group.
#
dummy_data_processing <- function(data) {
  abilities <- get_all_vars("ability")
  types <- get_all_vars("type")
  moves <- get_all_vars("move")
  egg_groups <- data$egg_groups %>% 
    map(., ~str_split(.x, ", ")) %>% 
    unlist() %>% 
    unique() %>% 
    sort()
  
  # Create Dummy Variables for abilities, types, moves, egg_groups
  data$abilities <- strsplit(data$abilities, ", ")
  data$types <- strsplit(data$types, ", ")
  data$moves <- strsplit(data$moves, ", ")
  data$egg_groups <- strsplit(data$egg_groups, ", ")

  abilities_dummy <- lapply(data$abilities, function(x) table(factor(x, levels=abilities)))
  types_dummy <- lapply(data$types, function(x) table(factor(x, levels=types)))
  moves_dummy <- lapply(data$moves, function(x) table(factor(x, levels=moves)))
  egg_groups_dummy <- lapply(data$egg_groups, function(x) table(factor(x, levels=egg_groups)))
  
  # Convert lists of tables to data frames
  abilities_dummy <- do.call(rbind, abilities_dummy)
  types_dummy <- do.call(rbind, types_dummy)
  moves_dummy <- do.call(rbind, moves_dummy)
  egg_groups_dummy <- do.call(rbind, egg_groups_dummy)
  
  # Add prefixes and replace dashes with underscores
  colnames(abilities_dummy) <- paste0("ability_", gsub("-", "_", colnames(abilities_dummy)))
  colnames(types_dummy) <- paste0("type_", gsub("-", "_", colnames(types_dummy)))
  colnames(moves_dummy) <- paste0("move_", gsub("-", "_", colnames(moves_dummy)))
  colnames(egg_groups_dummy) <- paste0("egg_group_", gsub("-", "_", colnames(egg_groups_dummy)))
  
  # Combine
  data <- cbind(data, abilities_dummy, types_dummy, moves_dummy, egg_groups_dummy)
  
  # Drop original variables
  data$abilities <- NULL
  data$types <- NULL
  data$moves <- NULL
  data$egg_groups <- NULL

  return(data)
}

# Apply dummy data function, remove generations 8-9 and the habitat/pal fields (since they have the NA values)
df <- dummy_data_processing(all_data) %>%
  filter(!(generation %in% c("generation-viii", "generation-ix"))) %>%
  select(-habitat, -pal_park_encounters_base_score, -pal_park_encounters_rate, -pal_park_encounters_area)

# Identify constant columns
constant_columns <- sapply(df, function(col) length(unique(col)) == 1)

# Remove constant columns
df <- df[, !constant_columns]

labels <- df %>% select(name, generation, id)

df <- df %>% 
  select(-name, generation, id) %>%
  mutate(held_items = ifelse(is.na(held_items), "", held_items))

# Convert categorical variables to dummy variables
m <- model.matrix(~.-1, data = df)

# Preprocess the data: scale and remove zero- or near-zero-variance predictors
preProc <- preProcess(m, method = c("center", "scale", "nzv"))

# Transform the data using the preprocessing parameters
m_transformed <- predict(preProc, m)
```

Perform Principal Component Analysis (PCA) to reduce the dimensionality
of the data. The eigenvalues in PCA represent the amount of variance
explained by each principal component. They indicate the importance or
contribution of each component in capturing the variation in the data.

The `prcomp` function performs PCA and provides the eigenvalues
(referred to as “singular values”) in the `pca$sdev` object. The
`get_eig` and `fviz_eig` functions from the `factoextra` package are
used extract and visualize the eigenvalues. The higher the eigenvalue,
the more variance in the data is captured by the corresponding principal
component. Larger eigenvalues suggest greater importance or “goodness”
of a component in representing the data.

``` r
# Perform PCA
pca <- prcomp(m_transformed, scale. = F)

get_eig(pca) %>% head(10)
```

    ##        eigenvalue variance.percent cumulative.variance.percent
    ## Dim.1   24.912383         6.046695                    6.046695
    ## Dim.2   22.312452         5.415644                   11.462339
    ## Dim.3   18.406316         4.467552                   15.929891
    ## Dim.4   16.912337         4.104936                   20.034827
    ## Dim.5   15.525945         3.768433                   23.803260
    ## Dim.6   12.519936         3.038819                   26.842080
    ## Dim.7   11.319050         2.747342                   29.589422
    ## Dim.8   10.346559         2.511301                   32.100723
    ## Dim.9    9.905963         2.404360                   34.505083
    ## Dim.10   9.022839         2.190009                   36.695092

``` r
fviz_eig(pca, geom = "line", linecolor = "blue", choice="variance", addlabels=T) +
  labs(title = "Importance of Principal Components", x = "Principal Component", y = "Variance %") +
  theme_minimal()
```

![](README_files/figure-gfm/pca-top-10-plot-1.png)<!-- -->

Use K-means clustering to group Pokémon species based on their
similarities. Create a 2D scatterplot (using the first 2 principal
components) and 3D scatterplot (using the first 3) to allow a visual
exploration of the clusters and similarities between different Pokémon.

``` r
# Perform K-means clustering
set.seed(19)
kmeans_result <- kmeans(pca$x[,1:2], centers = 6)

# Create a data frame for plotting; Add labels to the plot data
plot_data <- data.frame(pca$x[,1:2], cluster = as.factor(kmeans_result$cluster), labels = labels$name)

dark_colors <- c("#00008B", "#006400", "#8B0000", "#008B8B", "#8B008B", "#FF8C00")

# Create a 2D plot
ggplot(plot_data, aes(x = PC1, y = PC2, color = as.factor(cluster), label = labels)) +
  geom_point() +
  # geom_text(aes(label=labels), hjust=0, vjust=0) +
  scale_color_manual(values=dark_colors) +
  labs(title = "2D Rendering of Principle Component Pokemon Kmeans Clusters",
       color = "Cluster")
```

![](README_files/figure-gfm/pca-2d-1.png)<!-- -->

To see the scatter plot as an interactive 2d plot (with Pokémon names
showing when a point is hovered over or selected), click
[here](plots/plot_2d.html). For the same plot but in 3d, click
[here](plots/plot_3d.html). Each of these plots was generated with the
following code:

``` r
# Create a 2D plot with labels
p_2d <- plot_ly(plot_data, x = ~PC1, y = ~PC2, 
        type = "scatter", 
        mode = "markers", 
        text = ~labels, 
        hoverinfo = "text",
        color = ~cluster, 
        colors = dark_colors) %>%
  layout(title = "2D Rendering of Principle Component Pokemon Kmeans Clusters",
         margin = list(t=50, b=10))


# Perform K-means clustering, this time with 3 PCs
kmeans_result_3d <- kmeans(pca$x[,1:3], centers = 6)

# Create a data frame for plotting; Add labels to the plot data
plot_data_3d <- data.frame(pca$x[,1:3], cluster = as.factor(kmeans_result$cluster), labels = labels$name)

# Create a 3D plot
p_3d <- plot_ly(plot_data_3d, x = ~PC1, y = ~PC2, z=~PC3,
        type = "scatter3d", 
        mode = "markers", 
        text = ~labels, 
        hoverinfo = "text",
        color = ~cluster, 
        colors = dark_colors) %>%
  layout(title = "3D Rendering of Principle Component Pokemon Kmeans Clusters",
         margin = list(t=50, b=10))
```

<hr>
