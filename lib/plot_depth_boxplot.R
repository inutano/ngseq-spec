# stats and plots for statistics SRA
# plot boxplot template
# p <- ggplot(df, aes(x=))
# p <- p + geom_boxplot()
# p <- p + stat_summary(fun.y = mean, geom = "line", aes(group = 1))
# p <- p + labs(title="")
# p <- p + facet_wrap( ~ ,scale="free_y")
# print(p)
# ggsave(plot = p, file = "/Users/inutano/Desktop/ggplot", dpi = 150, width = 12.8, height = 9.6)

library(ggplot2)

argv <- commandArgs(trailingOnly = T)
pathRun <- list(argv[1], "run")
pathExp <- list(argv[2], "experiment")
pathFiles <- list(pathRun, pathExp)
dir <- "/Users/inutano/Desktop/boxplot/"

give.n <- function(x){ return(c(y=mean(x) * 1.3, label = length(x))) }

for (fp in pathFiles) {
  df <- na.omit(read.delim(fp[[1]]))
  df <- subset(df, df$total_sequences > 0)
  df <- subset(df, !(df$layout %in% c("single,paired","paired,single")))
  
  df <- subset(df, !(df$platform %in% c("", "undefined")))
  df <- subset(df, df$lib_strategy %in% c("WGS","AMPLICON","RNA-Seq","ChIP-Seq","WXS","EST","CLONE","Bisulfite-Seq"))
  
  df$date <- as.POSIXct(df$date, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  df <- df[!is.na(df$date),]
  df$qtr <- paste(format(df$date, "%y"), quarters(df$date), sep="/")
  
  df <- df[!is.na(df$gsize),]
  df$depth <- round(((df$r_throughput * df$mean_length) / df$gsize), 2)
  #df <- subset(df, df$depth < 250)
  
  pref <- fp[[2]]
  
  categories <- list(throughput, mdlength, mxlength, phred, depth)

  layout <- list(~layout, "libraryLayout")
  platform <- list(~platform, "platform")
  strategy <- list(~lib_strategy, "libraryStrategy")
  facets <- list(layout, platform, strategy)
  
  for (i in categories) {
    p <- ggplot(df, aes(x = df$qtr, y = i[[1]]))
    p <- p + geom_boxplot(outlier.shape = NA, color = i[[2]])
    p <- p + stat_summary(fun.y = mean, geom = "line", aes(group = 1))
    p <- p + stat_summary(fun.data = give.n, geom = "text", size = 2)
    p <- p + labs(x = "quarter", y = i[[3]], title = paste(fp[[2]], i[[4]], sep = ", "))
    ggsave(plot = p, file = paste(dir, fp[[2]], ".boxplot.", i[[3]], ".overall.png", sep = ""), dpi = 75, width = 12.8, height = 9.6)
    
    for (j in facets) {
      p <- p + facet_wrap(j[[1]], scale = "free_y")
      p <- p + labs(x = "quarter", y = i[[3]], title = paste(i[[4]], j[[2]], sep = ", "))
      ggsave(plot = p, file = paste(dir, fp[[2]], ".boxplot.", i[[3]], ".", j[[2]], ".png", sep = ""), dpi = 75, width = 12.8, height = 9.6)
    }
  }
}
