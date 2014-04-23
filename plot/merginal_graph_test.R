# merginally friends

library(ggplot2)
library(gtable)

# loading data
df <- read.delim("./test.tab")

## scatter plot: median length vs. number of reads
scatter <- ggplot(df, aes(medianLength, numOfReads)) + 
             geom_point() +
             scale_x_continuous(expand=c(0,0)) +
             scale_y_continuous(expand=c(0,0)) +
             expand_limits(y = c(min(df$numOfReads) - .1*diff(range(df$numOfReads)),
                                 max(df$numOfReads) + .1*diff(range(df$numOfReads)))) +
             expand_limits(x = c(min(df$medianLength) - .1*diff(range(df$medianLength)),
                                 max(df$medianLength) + .1*diff(range(df$medianLength)))) +
             theme(plot.margin = unit(c(0,0,0.5,0.5), "lines"))

## remove all axis labelling
blank = element_blank()	
theme_remove_all <- theme(axis.text = blank,
                          axis.title = blank,
                          axis.ticks = blank,
                          axis.ticks.margin = unit(0,"lines"),
                          axis.ticks.length = unit(0,"cm"))

## upper histogram: median length
hist_top <- ggplot(df, aes(medianLength)) +
              geom_density() +
              scale_x_continuous(expand = c(0,0)) +
              expand_limits(x = c(min(df$medianLength) - .1*diff(range(df$medianLength)),
                                  max(df$medianLength) + .1*diff(range(df$medianLength)))) +
              theme_remove_all +
              theme(plot.margin = unit(c(0.5,0,0,0.5), "lines"))

## rightside histogram: number of reads
hist_right <- ggplot(df, aes(numOfReads)) +
                geom_density() +
                scale_x_continuous(expand = c(0,0)) +
                expand_limits(x = c(min(df$numOfReads) - .1*diff(range(df$numOfReads)),
                                    max(df$numOfReads) + .1*diff(range(df$numOfReads)))) +
                coord_flip() +
                theme_remove_all +
                theme(plot.margin = unit(c(0,0.5,0.5,0), "lines"))

## get the gtables
gt1 <- ggplot_gtable(ggplot_build(scatter))
gt2 <- ggplot_gtable(ggplot_build(hist_top))
gt3 <- ggplot_gtable(ggplot_build(hist_right))

## get max width and heights for x and y axis title and text
maxWidth = unit.pmax(gt1$widths[2:3], gt2$widths[2:3])
maxHeight = unit.pmax(gt1$heights[4:5], gt3$heights[4:5])

## set  maxs in gtables
gt1$width[2:3] <- as.list(maxWidth)
gt2$width[2:3] <- as.list(maxWidth)

gt1$heights[4:5] <- as.list(maxHeight)
gt3$heights[4:5] <- as.list(maxHeight)

## combine the scatterplot with the two marginal histograms
# create a new gtable
gt <- gtable(widths = unit(c(7,2), "null"), height = unit(c(2,7), "null"))

## insert three gts into the new gt
gt <- gtable_add_grob(gt, gt1, 2, 1)
gt <- gtable_add_grob(gt, gt2, 1, 1)
gt <- gtable_add_grob(gt, gt3, 2, 2)

## render the plot
grid.draw(gt)
