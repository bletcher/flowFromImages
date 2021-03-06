# https://livebook.manning.com/#!/book/deep-learning-with-r/chapter-5/320

library(grid)
library(gridExtra)

deprocess_image <- function(x) {
  dms <- dim(x)
  x <- x - mean(x)                        
  x <- x / (sd(x) + 1e-5)                 
  x <- x * 0.1                            
  x <- x + 0.5                            
  x <- pmax(0, pmin(x, 1))                
  array(x, dim = dms)                     
}

generate_pattern <- function(layer_name, filter_index, size = 150) {
  layer_output <- model$get_layer(layer_name)$output                      
  loss <- k_mean(layer_output[,,,filter_index])                           
  grads <- k_gradients(loss, model$input)[[1]]                            
  grads <- grads / (k_sqrt(k_mean(k_square(grads))) + 1e-5)               
  iterate <- k_function(list(model$input), list(loss, grads))             
  input_img_data <-                                                       
  array(runif(size * size * 3), dim = c(1, size, size, 3)) * 20 + 128   
  step <- 1                                                               
  for (i in 1:40) {                                                       
    c(loss_value, grads_value) %<-% iterate(list(input_img_data))         
    input_img_data <- input_img_data + (grads_value * step)               
  }                                                                       
  img <- input_img_data[1,,,]
  deprocess_image(img)
}


# try one
grid.raster(generate_pattern("block1_conv2d_5", 1))

# make a grid
#dir.create("vgg_filters")
for (layer_name in c("block1_conv1", "block2_conv1",
                     "block3_conv1", "block4_conv1")) {
  size <- 140
  
  png(paste0("./img/imgFilters/", layer_name, ".png"),
      width = 8 * size, height = 8 * size)
  
  grobs <- list()
  for (i in 0:7) {
    for (j in 0:7) {
      pattern <- generate_pattern(layer_name, i + (j*8) + 1, size = size)
      grob <- rasterGrob(pattern,
                         width = unit(0.9, "npc"),
                         height = unit(0.9, "npc"))
      grobs[[length(grobs)+1]] <- grob
    }
  }
  
  grid.arrange(grobs = grobs, ncol = 8)
  dev.off()
}


