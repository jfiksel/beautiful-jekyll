
During the second quarter of [our Advanced Data Science Course](http://jtleek.com/advdatasci16/),
we developed [Shiny apps](https://shiny.rstudio.com) for other professors in the 
School of Public Health. This was a great opportunity to connect with other
researchers in the school, in addition to learning how to make a cool Shiny
app from scratch.

The goal of my app was to improve the measurements of mouse paw lesions, based on
images taken by a lab. My approach was to allow the lab users to remove the background
of the image, and then trace out where the tumors were located on the paw. The app would then 
calculate the percentage of the paw taken up by a lesion, which would hopefully be
more accurate than doing this by subjective judgement. 

The purpose of this tutorial is to go over the code that I used to do the background cropping. 
To do this, I modified the code of my original app to build a less involved version so that the
code is more understandable. If you want to see the more detailed app that I built for the
class, check out the GitHub repo [located here](https://github.com/jfiksel/lesion_measurements). 
For some motivation, here is an example of what you will be able to do after
building this app.

### insert Gif here

I'm not going to go into detail about every step that goes into making a Shiny app,
but if you would like to learn more, there are great examples and tutorials on the
Shiny app website that I linked to earlier.

To start out with, here's the code to install all the necessary libraries. I would
only run the lines for the libraries you definitely don't have.


```r
install.packages("DT")
install.packages("imager")
install.packages("maptools")
install.packages("plotKML")
install.packages("raster")
install.packages("shiny")
install.packages("shinyjs")
install.packages("sp")
install.packages("spatstat")
```

Make a new folder for this project, and inside of this folder make two new files--`ui.R` and `server.R`. Here is
the code that I put in my `ui.R` file:


```r
library(shinyjs)
library(DT)
fluidPage(
  titlePanel("Crop Image"),
  useShinyjs(),
  sidebarLayout(
    sidebarPanel(
      fileInput("file1", "Choose Image",
                accept=c(".png",
                         ".jpg")),
      textInput("imgName", "Image Name", ""),
      actionButton("selectForeground", "Begin Crop"),
      p("Click the button to begin cropping the image"),
      actionButton("pauseCropping", "Pause Cropping"),
      p("Click the button to pause background cropping"),
      actionButton("resetCropping", "Reset Cropping"),
      p("Click the button to reset background cropping"),
      actionButton("cropBackground", "Crop Image"),
      p("Click after you have cropped out the background"),
      actionButton("downloadImage", "Download Image"),
      p("Click to download the cropped image")
    ),
    mainPanel(
      plotOutput("plot1", click="plot1_click",
                 dblclick = "plot1_dblclick",
                 brush = brushOpts(
                   id = "plot1_brush",
                   resetOnNew = TRUE
                 ))
    )
  )
)
```

The fileInput button allows the user to use a `.jpg` or `.png` image for the cropping.
Each of the action buttons will be referenced inside of the `server.R` file, and
the results of pressing each of these buttons should be pretty clear from
the description. Finally, the last code chunk plots the image, in addition
to providing the ability to double click and zoom in on a region of the image.

Now let's switch over to the `server.R` file, which contains the meat (or Tempeh, if 
you're a vegatarian) of the app. I'm not going to go over a lot of the code here, but the full file is 
available at [this app's GitHub repo](https://github.com/jfiksel/photoshop), along
with the `ui.R` file and a great test picture. I will be referencing names of
variables and functions, that will hopefully be easy to find and follow along
with if you have the code in front of you.

I use the `imager` package to read in the image. The data structure of this image
is a 3D matrix--each layer corresponds to either the red, blue, or green scale of the
image, and the rows and columns are the pixels. 

The way that I crop the image is by keeping track of the user clicks. When the
user clicks the "Begin Crop" button (internally named "selectForeground"), a
[reactive value](https://shiny.rstudio.com/reference/shiny/latest/reactiveValues.html) 
called "cropImg" is set to true. The app then starts keeping track of the clicks
with two vectors--one for the x-coordinate, and one for the y-coordinate.


```r
observeEvent(input$plot1_click, {
  # Keep track of number of clicks for line drawing
  if(v$crop.img){
    v$imgclick.x <- c(v$imgclick.x, round(input$plot1_click$x))
    v$imgclick.y <- c(v$imgclick.y, round(input$plot1_click$y))
  }
})
```

The `app.plot` function recognizes when the user has begun clicking, and connects the
clicks with a red line so that the user can see the area that they are cropping.

The reason that I have a "Pause Cropping" button is to allow the user to zoom in
on a region. If you have paused cropping, you can click and drag the mouse to create a square.
If you double click inside of this square you will zoom in, so that you can crop
the image more accurately. You can begin cropping while zoomed in, and then pause again.
Double clicking will get you back to the original view.

When the user presses "Crop Image", the `select.points` function does the heavy lifting.
The heart of the function is this line:


```r
poly <- owin(poly=list(x=x, y=y), check=F)
```

The x and y refer to the x and y-coordinates of the clicks. This line
takes our click values, and connects them to make a polygon which contains
the coordinates of the image that we want to keep. The rest of the function makes a mask,
which is a matrix of dimension equal to the dimension of our image. If an entry 
in the mask is set to 1, then we keep this pixel as is in the image. If an entry is the
mask is set to 0, we change that pixel's color to white, with the `removePoints`
function in the `server.R` file.

Finally, if you're not happy with the image, you can hit "Reset Cropping". Internally,
this just resets all of the reactive values to their original state, and resets the
image to be the original image that the user wanted to crop. 

If you look closely, under each `observeEvent()` in the `server.R` file, I have
lines that enable and disable certain action buttons. This is from the `shinyjs` package,
and this allows the user to see which button they are currently clicked on. 

Finally, clicking on the `Download Image` function takes advantage of the `imager` package's
function `save.image`, and saves the cropped image to your current working directory.

Hopefully this is a starting point for more cool image editing Shiny apps. Please
let me know if you have any improvements or add-ons that you made! As always,
feel free to get in contact with me using the links at the bottom of the page.
