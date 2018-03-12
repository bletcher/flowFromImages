
library(keras)
library(arrayhelpers)
library(magick)
library(mixtools)
library(tidyverse)

source('./R/flickr_photosets_getphotos.R')
source('./R/getData.R')
source('./R/imageProcessing.R')
source('./R/plotImages.R')
source('./R/getFlowCategories.R')

# Parameters --------------------------------------------------------------

batch_size <- 32
epochs <- 10
data_augmentation <- FALSE
propTestImages <- 0.2
convertToGrayscale <- TRUE

imageHeight = 500
imageWidth = imageHeight * 0.66
imageWidth = 375
###########################################
# get flow data and images
# only need to rerun if get new images

flowData <- getEnvData( startDate = '2016-12-18', gage = '01169900' )
#flowData <- getFlowCategories( flowData, boundaries = c(0,10,31,79,166,9999) ) #see getFlowCategories.R for derivation of boundaries
flowData <- getFlowCategories( flowData, boundaries = c(0,11,45,120,9999) ) #see getFlowCategories.R for derivation of boundaries

numFlowCategories <- length(unique(na.omit(flowData$flowCatNum)))

imagesData <- getImages(flowData, propTestImages = propTestImages, the_photoset_id = "72157681488505313") %>%
  select(-description)

# remove images with NA values for flow
imagesData <- imagesData %>% filter(!is.na(flowCatNum))

# remove images with ice
imagesData <- imagesData %>% removeImagesWithIce()

# remove images with bad flow estimates from visual inspection
imagesData <- imagesData %>% removeImagesWithBadFlowEst()

imagesData <- imagesData %>% removeImagesNotCentered()

save(flowData, imagesData, file = './data/flowImageData.RData')

#########################################
# Process images

# Sort by flow category and date
imagesDataSorted <- imagesData %>% arrange( flow, datetaken )
# Get images
images2 <- processImages( imagesData = imagesDataSorted, imageSize = "m", imageHeight, imageWidth )

# crop images to remove trees above the stream
images1 <- images2[,151:500,,]
# crop images to remove trees above the stream
images <- images1[,1:200,,]
# Reset image height
imageHeight <- dim(images)[2]

if(convertToGrayscale) for(i in 1:nrow(images)){ images[i,,,] <- grayscale(as.cimg(images[i,,,])) }

# Plot an image
im <- deprocess_image(images2, imageNum = 88); plot(grayscale(as.cimg(im)))
im <- deprocess_image(images1, imageNum = 88); plot(as.raster(im))
im <- deprocess_image(images, imageNum = 88); plot(as.raster(im))

#im2 <- deprocess_image(images, imageNum = 188); plot(as.raster(im2))
#im2 <- deprocess_image(images, imageNum = 288); plot(as.raster(im2))

# plot a grid of images to  files in img/imgPNGs/
#plotImageGrids(); graphics.off() #dev.off( doesn't seem to work inside a function)

###################################################

# following structure from https://keras.rstudio.com/ MNIST Example 
flowDataCategorical <- to_categorical( imagesData$flowCatNum, numFlowCategories)

x_train2 <- images[!imagesData$testImageTF,,,]
x_test2 <- images[imagesData$testImageTF,,,]

y_train2 <- imagesData$flow[!imagesData$testImageTF]
y_test2 <- imagesData$flow[imagesData$testImageTF]

# Defining Model ----------------------------------------------------------
# https://keras.rstudio.com/articles/examples/cifar10_cnn.html
# Initialize sequential model
model <- keras_model_sequential()

model %>%
  
  # Start with hidden 2D convolutional layer being fed 32x32 pixel images
  layer_conv_2d(
    filter = 32, kernel_size = c(3,3), padding = "same", 
    input_shape = c(dim(x_train2)[2],dim(x_train2)[3],dim(x_train2)[4])
  ) %>%
  layer_activation("relu") %>%
  
  # Second hidden layer
  layer_conv_2d(filter = 32, kernel_size = c(3,3)) %>%
  layer_activation("relu") %>%
  
  # Use max pooling
  layer_max_pooling_2d(pool_size = c(2,2)) %>%
  layer_dropout(0.25) %>%
  
  # 2 additional hidden 2D convolutional layers
  layer_conv_2d(filter = 32, kernel_size = c(3,3), padding = "same") %>%
  layer_activation("relu") %>%
  layer_conv_2d(filter = 32, kernel_size = c(3,3)) %>%
  layer_activation("relu") %>%
  
  # Use max pooling once more
  layer_max_pooling_2d(pool_size = c(2,2)) %>%
  layer_dropout(0.25) %>%
  
  # Flatten max filtered output into feature vector 
  # and feed into dense layer
  layer_flatten() %>%
  layer_dense(512) %>%
  layer_activation("relu") %>%
  layer_dropout(0.5) %>%
  
  # Outputs from dense layer are projected onto numFlowCategories unit output layer
  layer_dense(1)# %>%
#layer_activation("softmax")

model %>% compile(
  optimizer = "rmsprop",
  loss = "mse",
  metrics = c("mae")
)

# Training ----------------------------------------------------------------

if(!data_augmentation){
  
  history <- 
    model %>% fit(
      x_train2, y_train2,
      batch_size = batch_size,
      epochs = epochs,
      validation_data = list(x_test2, y_test2),
      shuffle = TRUE
    )
  
} else {
  
  datagen <- image_data_generator(
    featurewise_center = TRUE,
    featurewise_std_normalization = TRUE,
    rotation_range = 20,
    width_shift_range = 0.2,
    height_shift_range = 0.2,
    horizontal_flip = TRUE
  )
  
  datagen %>% fit_image_data_generator(x_train2)
  
  model %>% fit_generator(
    flow_images_from_data(x_train2, y_train2, datagen, batch_size = batch_size),
    steps_per_epoch = as.integer(50000/batch_size), 
    epochs = epochs, 
    validation_data = list(x_test2, y_test2)
  )
  
}

p <- model %>% predict(x_test2)
pp <- imagesDataSorted %>% filter(testImageTF) %>% select(imageName_m,flow)
pp$p <- p[,1]
ggplot(pp, aes( flow, p)) + geom_point()

imagesDataSorted <- left_join( imagesDataSorted, pp )
plotImageGrids_Regression(plotWPred = TRUE) #  graphics.off()