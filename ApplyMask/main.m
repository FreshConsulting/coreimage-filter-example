//
//  main.m
//  ApplyMask
//
//  Created by Matthew Wymore on 2/15/14.
//  Copyright (c) 2014 Uncorked Studios. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>

CGImageRef makeGradientMask(CGSize maskSize, CGFloat startingPosition, CGFloat endingPosition);
void writeOutputImage(NSString *path, CGImageRef image);
CGImageRef imageRefCreateFromBytes(UInt8 *bytes, size_t totalBytes, CGSize imageSize);

CFDataRef imageDataCreateFromFile(const char *path, CGSize *imageSize);
CGImageRef imageRefCreateWithMask(const UInt8 *sourceBytes, const UInt8 *imageMaskBytes, CGSize imageSize, size_t totalSourceBytes);

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        if (argc != 5)
        {
            NSString *message = @"Usage: ApplyMask source_image_path gradient_start_percentage gradient_width_percentage output_image";
            NSLog(@"%@", message);
            return 1;
        }
        
        
        NSString *sourceImagePath = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:sourceImagePath])
        {
            NSLog(@"Source image not found. Aborting....");
            return 1;
        }
        
        NSString *gradientStartString = [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding];
        CGFloat gradientStartPercentage = [gradientStartString floatValue];
        
        NSString *gradientWidthString = [NSString stringWithCString:argv[3] encoding:NSUTF8StringEncoding];
        CGFloat gradientWidthPercentage = [gradientWidthString floatValue];
        
        NSString *outputImageName = [NSString stringWithCString:argv[4] encoding:NSUTF8StringEncoding];
        
        
        //Read in the source image and get its bytes
        CGSize imageSize;
        CFDataRef sourceData = imageDataCreateFromFile(argv[1], &imageSize);
        CFIndex sourceBytesCount = CFDataGetLength(sourceData);
        const UInt8 *sourceBytes = CFDataGetBytePtr(sourceData);
        
        
        //Create a gradient that we will use to mask pixels in the image and get its bytes
        CGFloat gradientStartFade = gradientStartPercentage / 100.0;
        CGFloat gradientEndFade = gradientStartFade + gradientWidthPercentage / 100.0;
        CGImageRef gradientImage = makeGradientMask(imageSize, gradientStartFade, gradientEndFade);
        CGDataProviderRef gradientProvider = CGImageGetDataProvider(gradientImage);
        CFDataRef gradientData = CGDataProviderCopyData(gradientProvider);
        CFIndex gradientBytesCount = CFDataGetLength(gradientData);
        const UInt8 *gradientBytes = CFDataGetBytePtr(gradientData);
        
        if (sourceBytesCount != gradientBytesCount)
        {
            NSLog(@"source image and gradient image have different byte counts. Aborting....");
            CFRelease(sourceData);
            CFRelease(gradientData);
            return 1;
        }
        
        CGImageRef maskImage = imageRefCreateWithMask(sourceBytes, gradientBytes, imageSize, sourceBytesCount);
        
        writeOutputImage(outputImageName, maskImage);
        
        CFRelease(sourceData);
        CFRelease(gradientData);
        CFRelease(maskImage);
    }
    return 0;
}

#pragma mark - Image Reading

CFDataRef imageDataCreateFromFile(const char *path, CGSize *imageSize)
{
    CGDataProviderRef sourceDataProvider = CGDataProviderCreateWithFilename(path);
    CGImageRef sourceImage = CGImageCreateWithPNGDataProvider(sourceDataProvider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(sourceDataProvider);
    CGDataProviderRef sourceProvider = CGImageGetDataProvider(sourceImage);
    size_t width = CGImageGetWidth(sourceImage);
    size_t height = CGImageGetHeight(sourceImage);
    *imageSize = CGSizeMake(width, height);
    
    CFDataRef sourceData = CGDataProviderCopyData(sourceProvider);
    CFRelease(sourceImage);
    
    return sourceData;
}

CGImageRef imageRefCreateFromBytes(UInt8 *bytes, size_t totalBytes, CGSize imageSize)
{
    //When you create a bitmap context, if you want RGBA you have to have premultiplied alpha.
    //See this table for details of supported pixel formats: https://developer.apple.com/library/mac/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB
    //Since the context expects premultiplied alpha, we have to multiply pixel values by an alpha factor before
    //creating the context
    
    UInt8 *premultipliedBuffer = calloc(totalBytes, 1);
    memcpy(premultipliedBuffer, bytes, totalBytes);
    for (int i = 0; i < totalBytes; i += 4)
    {
        UInt8 red = premultipliedBuffer[i];
        UInt8 green = premultipliedBuffer[i + 1];
        UInt8 blue = premultipliedBuffer[i + 2];
        UInt8 alpha = premultipliedBuffer[i + 3];
        float alphaFactor = alpha / 255.0;
        
        UInt8 premultipliedRed = (UInt8)nearbyintf(alphaFactor * red);
        UInt8 premultipliedGreen = (UInt8)nearbyintf(alphaFactor * green);
        UInt8 premultipliedBlue = (UInt8)nearbyintf(alphaFactor * blue);
        
        premultipliedBuffer[i] = premultipliedRed;
        premultipliedBuffer[i + 1] = premultipliedGreen;
        premultipliedBuffer[i + 2] = premultipliedBlue;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
    CGContextRef bitmapContext = CGBitmapContextCreate(
                                                       premultipliedBuffer,
                                                       imageSize.width,
                                                       imageSize.height,
                                                       8,
                                                       4 * imageSize.width,
                                                       colorSpace,
                                                       kCGImageAlphaPremultipliedLast);
#pragma clang diagnostic pop
    
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    
    CFRelease(bitmapContext);
    CFRelease(colorSpace);
    free(premultipliedBuffer);
    
    return cgImage;
}

#pragma mark - Creating Gradient Mask

CGImageRef makeGradientMask(CGSize maskSize, CGFloat startingPosition, CGFloat endingPosition)
{
    CGColorSpaceRef gradientColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    
    CGFloat gradientLocations[4] = {0.0, startingPosition, endingPosition, 1.0};
    CGFloat gradientColors[16] = {  1.0, 1.0, 1.0, 1.0,
                                    1.0, 1.0, 1.0, 1.0,
                                    0.0, 0.0, 0.0, 1.0,
                                    0.0, 0.0, 0.0, 1.0};
    
    CGGradientRef maskGradient = CGGradientCreateWithColorComponents(gradientColorSpace, gradientColors, gradientLocations, 4);
    
    void *imageBuffer = calloc(maskSize.width * maskSize.height, 4);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
    CGContextRef context = CGBitmapContextCreate(imageBuffer, maskSize.width, maskSize.height, 8, 4 * maskSize.width, gradientColorSpace, kCGImageAlphaPremultipliedLast);
#pragma clang diagnostic pop
    
    CGPoint startingPoint = CGPointMake(maskSize.width / 2.0, 0.0);
    CGPoint endingPoint = CGPointMake(maskSize.width / 2.0, maskSize.height);
    CGContextDrawLinearGradient(context, maskGradient, startingPoint, endingPoint, 0);
    
    CGImageRef gradientImage = CGBitmapContextCreateImage(context);
    CFAutorelease(gradientImage);
    CFRelease(maskGradient);
    CFRelease(gradientColorSpace);
    CFRelease(context);
    free(imageBuffer);
    
    return gradientImage;
}

#pragma mark - Apply Image Mask

CGImageRef imageRefCreateWithMask(const UInt8 *sourceBytes, const UInt8 *imageMaskBytes, CGSize imageSize, size_t totalSourceBytes)
{
    if (totalSourceBytes == 0)
    {
        return NULL;
    }
    
    //create a new buffer for the output image.
    //For this example, output pixels are: O.red = I.red  O.green = I.green  O.blue = I.blue  O.alpha = I.alpha * G.value
    //where O is output pixel, I is input pixel and G is the gradient we use to mask the image
    UInt8 *maskedBytes = calloc(totalSourceBytes, 1);
    
    for (int i = 0; i < totalSourceBytes; i += 4)
    {
        UInt8 red = sourceBytes[i];
        UInt8 green = sourceBytes[i + 1];
        UInt8 blue = sourceBytes[i + 2];
        UInt8 alpha = sourceBytes[i + 3];
        
        UInt8 gradientValue = imageMaskBytes[i]; //Can just use red component of gradient since R, G, B are equal in this gradient
        float alphaFactor = gradientValue / 255.0;
        UInt8 maskedAlpha = (UInt8)nearbyintf(alphaFactor * alpha);
        maskedBytes[i] = red;
        maskedBytes[i + 1] = green;
        maskedBytes[i + 2] = blue;
        maskedBytes[i + 3] = maskedAlpha;
    }
    
    
    CGImageRef filteredImage = imageRefCreateFromBytes(maskedBytes, totalSourceBytes, imageSize);
    free(maskedBytes);
    
    return filteredImage;
}

#pragma mark - Image Output

void writeOutputImage(NSString *path, CGImageRef image)
{
    CFURLRef outputUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(outputUrl, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, image, NULL);
    
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
}



