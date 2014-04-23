# stats and plots for statistics SRA
# usage: R --vanilla --slave --args /path/to/data < plot_histogram.R
# 
# plot histogram template
# p <- ggplot(df, aes(x=))
# p <- p + geom_histogram(fill="white", color="", binwidth=)
# p <- p + labs(title="")
# p <- p + facet_wrap( ~ ,scale="free_y")
# print(p)
# ggsave(plot = p, file = "/Users/inutano/Desktop/ggplot", dpi = 150, width = 12.8, height = 9.6)

## load library
library(ggplot2)

## set variables
argv <- commandArgs(trailingOnly = T)
inputFile <- argv[1]
dir <- "~/Desktop/ggplot/"
dpi <- 75
width <- 12.8
height <- 9.6

## function definition
## ggplot histogram wrapper function
histogram <- function(df, column, binwidth, color, xLab, title){
  p <- ggplot(df, aes(x = column))
  p <- p + geom_histogram(binwidth = binwidth, fill = "white", color = color)
  p <- p + labs(x = xLab, title = title)
  return(p)
}

histogramFacet <- function(p, facet, xLab, title){
  p <- p + facet_wrap(facet, scale = "free_y")
  p <- p + labs(x = xLab, title = title)
  return(p)
}

## cleaning data
dataCleaning <- function(df){
  df <- subset(df, !(df$platform %in% c("", "undefined")))
  return(df)
}

## read input table
df <- read.delim(inputFile)

## set list of parameters for each categories
numOfReads <- list(log10(df$numOfReads), 0.1, "lightskyblue", "log10 number of reads")
mdLength <- list(log10(df$medianLength), 0.05, "tomato", "log10 median read length")
mxLength <- list(log10(df$maxLength), 0.05, "firebrick", "log10 max read length")
phred <- list(df$phred, 0.1, "gold", "normalized phred score")
ncont <- list(df$nCont, 1, "darkslategray", "total N content")
dup <- list(df$duplicate, 1, "blueviolet", "total duplicate percentage")
categories <- list(numOfReads, mdLength, phred, ncont, dup)

## set list of parameters for each facets
layout <- list(~layout, "library layout")
platform <- list(~platform, "platform")
strategy <- list(~strategy, "library strategy")
selection <- list(~selection, "library selection")
source <- list(~source, "library source")
facets <- list(layout, platform, strategy, selection, source)

## draw histogram
for(i in categories){
  xLab <- i[[4]]
  #p <- histogram(df, i[[1]], i[[2]], i[[3]], xLab, inputFile)
  p <- ggplot(df, aes(x = i[[1]]))
  p <- p + geom_histogram(binwidth = i[[2]], fill = "white", color = i[[3]])
  p <- p + labs(x = xLab, title = inputFile)
  
  fileName <- gsub(" ", "_", i[[4]])
  filePath <- paste(dir, fileName, ".png", sep = "")
  ggsave(plot = p, file = filePath, dpi = dpi, width = width, height = height)
  
  for(j in facets){
    facetLab <- gsub(" ", "_", j[[2]])
    filePath <- paste(dir, fileName, "_", facetLab, ".png", sep = "")
    p <- histogramFacet(p, j[[1]], xLab, inputFile)
    ggsave(plot = p, file = filePath, dpi = dpi, width = width, height = height)
  }
}
