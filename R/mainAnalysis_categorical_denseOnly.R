
library(keras)
library(arrayhelpers)
library(magick)
library(mixtools)
library(imager)
library(tidyverse)

# will convert these to functions in the project package
source('./R/flickr_photosets_getphotos.R')
source('./R/getData.R')
source('./R/imageProcessing.R')
source('./R/plotImages.R')
source('./R/getFlowCategories.R')
source('./R/adjFlowsVisually.R')

# Parameters --------------------------------------------------------------

batch_size <- 32
epochs <- 100 # of 'iterations'
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

# adjust flow estimates based on visual inspection of images. Comment out for no adjustment
flowData <- adjustFlowsVisually(flowData)

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

# standardize flow data for training data (!flowData$testImageTF) only
meanFlow <- mean(imagesData$flow[!imagesData$testImageTF],na.rm = T)
sdFlow <- sd(imagesData$flow[!imagesData$testImageTF], na.rm = T)
imagesData$flowStd <- (imagesData$flow - meanFlow) / sdFlow

save(flowData, imagesData, file = './data/flowImageData.RData')

#########################################
# Process images

# Sort by flow category and date
imagesDataSorted <- imagesData %>% arrange( flow, datetaken )
# Get images
images2 <- processImages( imagesData = imagesDataSorted, imageSize = "m", imageHeight, imageWidth )

# crop images to remove trees above the stream
images1 <- images2[,151:500,,]
# crop images to remove the lower part of the stream
images <- images1[,1:200,,]
# Reset image height
imageHeight <- dim(images)[2]

numColors <- 3

# convert image to grayscale
if(convertToGrayscale){
  for(i in 1:nrow(images)){ 
    images[i,,,] <- grayscale(as.cimg(images[i,,,])) 
  }
  # reduce color index dim to one (all three are the same grayscale)
  # seems to cause problems with the layer_2d_conv
  #images <- array(images, dim=c(dim(images)[1],dim(images)[2],dim(images)[3]))
  numColors <- 1
  images <- array_reshape(images[,,,1],c(dim(images)[1],dim(images)[2],dim(images)[3],numColors))
}  


# Plot an image
im <- deprocess_image(images2, imageNum = 88); plot(as.raster(im))
im <- deprocess_image(images1, imageNum = 88); plot(as.raster(im))
im <- deprocess_image(images, imageNum = 88); plot(as.raster(im))

#im2 <- deprocess_image(images, imageNum = 188); plot(as.raster(im2))
#im2 <- deprocess_image(images, imageNum = 288); plot(as.raster(im2))

# plot a grid of images to  files in img/imgPNGs/
#plotImageGrids(); graphics.off() #dev.off( doesn't seem to work inside a function)

###################################################

# following structure from https://keras.rstudio.com/ MNIST Example 
flowDataCategorical <- to_categorical( imagesData$flowCatNum, numFlowCategories)

numTrain <- dim(images[!imagesData$testImageTF,,,])[1]
numTest <- dim(images[imagesData$testImageTF,,,])[1]

y_train2 <- flowDataCategorical[!imagesData$testImageTF,]
y_test2 <- flowDataCategorical[imagesData$testImageTF,]

x_train2 <- array_reshape(images[!imagesData$testImageTF,,,],c(numTrain,dim(images)[2] * dim(images)[3])) 
x_test2 <- array_reshape(images[imagesData$testImageTF,,,],c(numTest,dim(images)[2] * dim(images)[3]))

model <- keras_model_sequential()
model %>%
  layer_dense(units=256,
              input_shape = c(dim(x_train2)[2])) %>%
  layer_activation("relu") %>%
  layer_dropout(0.5) %>%
  
  layer_dense(128) %>%
  layer_activation("relu") %>%
  layer_dropout(0.4) %>%
  
  layer_dense(64) %>%
  layer_activation("relu") %>%
  layer_dropout(0.25) %>%
  
  layer_dense(numFlowCategories) %>%
  layer_activation("softmax")  

opt <- optimizer_rmsprop(lr = 0.0001, decay = 1e-6)

model %>% compile(
  loss = "categorical_crossentropy",
  optimizer = optimizer_rmsprop(), #opt,
  metrics = c("accuracy")
)

# Training ----------------------------------------------------------------

history <- 
  model %>% fit(
    x_train2, y_train2,
    batch_size = 32,
    epochs = 9,
    validation_data = list(x_test2, y_test2),
    shuffle = TRUE
)






p <- model %>% predict_classes(x_test2)
pp <- imagesDataSorted %>% filter(testImageTF) %>% select(imageName_m,flowCatNum) %>% mutate(p=p)
ggplot(pp, aes( flowCatNum, p)) + geom_jitter()

imagesDataSorted <- left_join( imagesDataSorted, pp )
plotImageGrids(plotWPred = TRUE) #  graphics.off()
