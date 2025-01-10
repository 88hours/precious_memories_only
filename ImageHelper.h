//
//  ImageHelper.h
//  camera_example
//
//  Created by Nauman Qazi on 3/18/17.
//
//

#ifndef ImageHelper_h
#define ImageHelper_h

#import <Foundation/Foundation.h>


#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>
#import <UIKit/UIKit.h>

#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
@interface ImageHelper : NSObject {
    
}

/** Converts a UIImage to RGBA8 bitmap.
 @param image - a UIImage to be converted
 @return a RGBA8 bitmap, or NULL if any memory allocation issues. Cleanup memory with free() when done.
 */
+ (unsigned char *) convertUIImageToBitmapRGBA8:(UIImage *)image :(int*)width :(int*)height :(int*)channel;

/** A helper routine used to convert a RGBA8 to UIImage
 @return a new context that is owned by the caller
 */
+ (CGContextRef) newBitmapRGBA8ContextFromImage:(CGImageRef)image;


/** Converts a RGBA8 bitmap to a UIImage.
 @param buffer - the RGBA8 unsigned char * bitmap
 @param width - the number of pixels wide
 @param height - the number of pixels tall
 @return a UIImage that is autoreleased or nil if memory allocation issues
 */
+ (UIImage *) convertBitmapRGBA8ToUIImage:(unsigned char *)buffer
                                withWidth:(int)width
                               withHeight:(int)height;

@end
#endif /* ImageHelper_h */
