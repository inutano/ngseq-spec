# stats and plots for statistics SRA
# plot histogram template
# p <- ggplot(df, aes(x=))
# p <- p + geom_histogram(fill="white", color="", binwidth=)
# p <- p + labs(title="")
# p <- p + facet_wrap( ~ ,scale="free_y")
# print(p)
# ggsave(plot = p, file = "/Users/inutano/Desktop/ggplot", dpi = 150, width = 12.8, height = 9.6)

library(ggplot2)

argv <- commandArgs(trailingOnly = T)
pathRun <- list(argv[1], "run")
pathSample <- list(argv[2], "sample")
pathFiles <- list(pathRun, pathSample)
dir <- "/Users/inutano/Desktop/ggplot/"

for (fp in pathFiles) {
  df <- na.omit(read.delim(fp[[1]]))
  df <- subset(df, df$total_sequences > 0)
  
  pref <- fp[[2]]
  throughput <- list(log10(df$total_sequences), 0.1, "lightskyblue")
  throughput[4] <- paste(pref, "log10 throughput", sep = ", ")
  throughput[5] <- "throughput"
  
  mdlength <- list(log10(df$median_length), 0.05, "tomato")
  mdlength[4] <- paste(pref, "log 10 median read length", sep = ", ")
  mdlength[5] <- "median_length"

  mxlength <- list(log10(df$max_length), 0.05, "firebrick")
  mxlength[4] <- paste(pref, "log 10 max read length", sep = ", ")
  mxlength[5] <- "max_length"

  phred <- list(df$normalized_phred_score, 0.1, "gold")
  phred[4] <- paste(pref, "phred score", sep = ", ")
  phred[5] <- "phred_score"
  
  ncont <- list(df$total_n_content, 1, "darkslategray")
  ncont[4] <- paste(pref, "total N content", sep = ", ")
  ncont[5] <- "totalNcontent"

  duplicate <- list(df$total_duplicate_percentage, 1, "blueviolet")
  duplicate[4] <- paste(pref, "total duplicate percentage", sep = ", ")
  duplicate[5] <- "duplicate_percentage"
  
  categories <- list(throughput, mdlength, mxlength, phred, ncont, duplicate)

  layout <- list(~layout, "libraryLayout")
  platform <- list(~platform, "platform")
  strategy <- list(~lib_strategy, "libraryStrategy")
  selection <- list(~lib_selection, "librarySelection")
  source <- list(~lib_source, "librarySource")
  facets <- list(layout, platform, strategy, selection, source)
  
  for (i in categories) {
    p <- ggplot(df, aes(x = i[[1]]))
    p <- p + geom_histogram(binwidth = i[[2]], fill = "white", color = i[[3]])
    p <- p + labs(x = i[[5]], title = paste(fp[[2]], i[[4]], sep = ", "))
    ggsave(plot = p, file = paste(dir, fp[[2]], i[[5]], ".overall.png", sep = ""), dpi = 150, width = 12.8, height = 9.6)
    
    for (j in facets) {
      p <- p + facet_wrap(j[[1]], scale = "free_y")
      p <- p + labs(x = i[[5]], title = paste(i[[4]], j[[2]], sep = ", "))
      ggsave(plot = p, file = paste(dir, fp[[2]], ".", i[[5]], ".", j[[2]], ".png", sep = ""), dpi = 150, width = 12.8, height = 9.6)
    }
  }
}
