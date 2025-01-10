//
//  MWPhoto+BadPhoto.m
//  camera_example
//
//  Created by Zeeshan on 24/08/2017.
//
//

#import "MWPhoto+BadPhoto.h"
#import <objc/runtime.h>


@implementation MWPhoto (BadPhoto)

static char UIB_PROPERTY_PHOTOURL;

@dynamic photoUrl;

- (void)setPhotoUrl:(NSURL *)photoUrl {

    objc_setAssociatedObject(self, &UIB_PROPERTY_PHOTOURL, photoUrl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL *)photoUrl {
    return (NSURL *)objc_getAssociatedObject(self, &UIB_PROPERTY_PHOTOURL);
}

@end
