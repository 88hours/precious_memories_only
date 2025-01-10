//
//  ImageHolder.m
//  camera_example
//
//  Created by Nauman Qazi on 3/18/17.
//
//

#import "ImageHolder.h"



@implementation ImageHolder
@synthesize image, info;

-(id) initWithImage: (UIImage*)image :(NSString*)info{
    self = [super init];
    self.image = image;
    self.info = info;
    
    return  self;
    
}
- (void)dealloc {
    [self.info release];
    [super dealloc];
}
@end
