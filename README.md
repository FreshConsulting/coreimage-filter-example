coreimage-filter-example
-----


This is an example of using Core Graphics for writing filters for image processing. This app is a Mac app, but the code only uses Core Graphics functions and nothing specific to OSX, so the code can easily be ported to iOS.

This app reads in an input image and applies a gradient filter to the image. The alpha values of pixels in the source image are multiplied by the gradient value to smoothly fade out the image and set pixels in the top of the image to be transparent.

###Notes
Please note that this project is meant to serve as an example and has some known issues:
* There is not a lot of error checking in this code. 
* This app assumes that that your input image meets the following criteria:
   * PNG format.
   * 8 bits per channel/32 bits per pixel.
   * Has an alpha channel.
* The command line options for the app are:
   * source\_image\_path: Full path to the input image.
   * gradient\_start\_percentage: Percentage from the bottom of the image where the filter gradient should start. For example, if you want the filter to begin 25% from the bottom of the image, specify 25 for this parameter.
   * gradient\_width\_percentage: Percentage of the image height that the gradient should span. For example, if you want the gradient to span 10% of the height of the image specify 10 for this parameter.
   * output_image: Full path to the output image. May be the same path as the input.
