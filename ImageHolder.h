//
//  ImageHolder.h
//  camera_example
//
//  Created by Nauman Qazi on 3/18/17.
//
//

#import <Foundation/Foundation.h>



#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>
#import <UIKit/UIKit.h>

#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

@interface ImageHolder : NSObject
-(id) initWithImage: (UIImage*)image :(NSString*)info;

@property (retain, nonatomic) UIImage *image;
@property (retain, nonatomic) NSString *info;

@end
