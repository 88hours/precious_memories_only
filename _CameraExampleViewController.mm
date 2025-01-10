// Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "CameraExampleViewController.h"
#import <mach/mach.h>

#include "google/protobuf/io/coded_stream.h"
#include "google/protobuf/io/zero_copy_stream_impl.h"
#include "google/protobuf/io/zero_copy_stream_impl_lite.h"
#include "google/protobuf/message_lite.h"
#include <sys/time.h>
#include "ios_image_load.h"
#import <Photos/Photos.h>

#include <fstream>
#include <pthread.h>
#include <unistd.h>
#include <queue>
#include <sstream>
#include <string>
#include "tensorflow_utils.h"

// If you have your own model, modify this to the file name, and make sure
// you've added the file to your app resources too.
static NSString* model_file_name = @"mmapped_kids_graph";
static NSString* model_file_type = @"pb";
// This controls whether we'll be loading a plain GraphDef proto, or a
// file created by the convert_graphdef_memmapped_format utility that wraps a
// GraphDef and parameter file that can be mapped into memory from file to
// reduce overall memory usage.
const bool model_uses_memory_mapping = true;
// If you have your own model, point this to the labels file.
static NSString* labels_file_name = @"retrained_kids_label";
static NSString* labels_file_type = @"txt";
// These dimensions need to match those the model was trained with.
const int wanted_input_width = 299;
const int wanted_input_height = 299;
const int wanted_input_channels = 3;
const float input_mean = 128.0f;
const float input_std = 128.0f;
const std::string input_layer_name = "Mul";
const std::string output_layer_name = "final_result";

@implementation CameraExampleViewController

@synthesize photos,thumbs, assets;

NSString* FilePathForResourceNameDup(NSString* name, NSString* extension) {
    NSString* file_path = [[NSBundle mainBundle] pathForResource:name ofType:extension];
    if (file_path == NULL) {
        LOG(FATAL) << "Couldn't find '" << [name UTF8String] << "."
        << [extension UTF8String] << "' in bundle.";
    }
    return file_path;
}

- (IBAction)getUrl:(id)sender {
    if(self.photos.count > 0){
        [self showResult:sender];
    } else {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            [self loadAssets];
            /*
             NSString * imagePath = FilePathForResourceNameDup(@"input_1",@"jpg");
             UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
             [self RunInferenceOnImage:image :@"Test Image"];
             */
        }
    });
    }
}



- (void)loadAssets {
    if (NSClassFromString(@"PHAsset")) {
        
        // Check library permissions
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    [self findAllFiles];
                }
            }];
        } else if (status == PHAuthorizationStatusAuthorized) {
            [self findAllFiles];
        }
        
    } else {
        
        // Assets library
        [self findAllFiles];
        
    }
}

int currentJ=0;
-(void) findAllFiles
{
    PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.resizeMode   = PHImageRequestOptionsResizeModeExact;
    requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    requestOptions.synchronous = true;
    requestOptions.networkAccessAllowed = NO;
    
    PHFetchOptions *options = [PHFetchOptions new];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    //set up fetch options, mediaType is image.
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d",PHAssetMediaTypeImage];
    
    //PHFetchResult *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
    PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    PHImageManager *manager = [PHImageManager defaultManager];
    
    // assets contains PHAsset objects.
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    // Sizing is very rough... more thought required in a real implementation
    CGFloat imageSize = MAX(screen.bounds.size.width, screen.bounds.size.height) * 1.5;
    CGSize imageTargetSize = CGSizeMake(imageSize * scale, imageSize * scale);
    CGSize thumbTargetSize = CGSizeMake(imageSize / 3.0 * scale, imageSize / 3.0 * scale);
    
    int maxResult = 100;
    for (NSInteger i =0; i < result.count; i++) {
        PHAssetCollection *assetCollection = result[i];
        PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
      /*  if([assetCollection.localizedTitle containsString:@"Selfies"] == false)
        {
            continue;
        }*/
        NSLog(@"Sub album title is %@, count is %ld", assetCollection.localizedTitle, assetsFetchResult.count);
        if (assetsFetchResult.count > 0) {
            
            
            for (int j =currentJ; (j < (int)assetsFetchResult.count && self.photos.count < maxResult);) {
                
                unsigned int mem = [self memoryInMB];
               // if( mem > 512)
                {   NSLog(@"%u", mem);
                //    sleep(5);
                //    continue;
                }
                 
                // Do something with the asset
                __block BOOL isICloudAsset = NO;
                PHAsset *asset =assetsFetchResult[j++];
                [manager requestImageForAsset:asset
                                   targetSize:PHImageManagerMaximumSize
                                  contentMode:PHImageContentModeDefault
                                      options:requestOptions
                                resultHandler:^void(UIImage *image, NSDictionary *dict) {
                                    if ([dict[@"PHImageResultIsInCloudKey"] isEqual:@YES]) {
                                        isICloudAsset = YES;
                                    }
                                    if(!isICloudAsset){
                                        @autoreleasepool {
                                            NSMutableDictionary *newValues = [NSMutableDictionary dictionary];
                                            
                                            bool badPhoto = [self RunInferenceOnImage:image :[dict objectForKey:@"PHImageFileURLKey"] :newValues];
                                            //image = nil;
                                            if(badPhoto){
                                                NSLog(@"Scanning Selfies: %d / %d - %lu",j,(int)assetsFetchResult.count, (unsigned long)self.photos.count);

                                                [self.photos addObject:[MWPhoto photoWithAsset:asset targetSize:thumbTargetSize]];
                                                [self.thumbs addObject:[MWPhoto photoWithAsset:asset targetSize:thumbTargetSize]];
                                            }else
                                                image = nil;
                                            
                                        }
                                    }
                                }];
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [UIView animateWithDuration: 1.f animations:^{
                        self.progressView.value = (float)(j/(float)assetsFetchResult.count) * 100;
                    }];
                    
                    self.lblFound.text = [NSString stringWithFormat:@"Found1 : %lu ",(unsigned long)self.photos.count];
                    
                });
                if(self.photos.count > maxResult){
                    currentJ = j;
                    break;
                }
            }
        }
    }
    requestOptions = nil;
    options = nil;
    result = nil;
    
}


-(unsigned) memoryInMB{
    unsigned latest = 0;
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if( kerr == KERN_SUCCESS ) {
        latest = (int)info.resident_size/1024/1024;
        
    } else {
        NSLog(@"Error with task_info(): %s", mach_error_string(kerr));
    }
    return  latest;
}

- (bool)RunInferenceOnImage: (UIImage *) image :(NSString*) info : (NSMutableDictionary *) newValues {
    
    bool isBadPhoto = false;
    int image_channels = 4;
    tensorflow::Tensor image_tensor(
                                    tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape(
                                                            {1, wanted_input_height, wanted_input_width, wanted_input_channels}));
    auto image_tensor_mapped = image_tensor.tensor<float, 4>();
    float* out = image_tensor_mapped.data();
    
    int image_height;
    int image_width;
    
    //std::vector<tensorflow::uint8> image_data = LoadImageFromFile(
    //                                                            [image_path UTF8String], &image_width,
    //&image_height, &image_channels);
    
    
    unsigned char * image_data = [ImageHelper convertUIImageToBitmapRGBA8:image :&image_width :&image_height :&image_channels];
    
    /*
     CGImageRef imageRef = [image CGImage];
     CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
     const unsigned char * buffer =  CFDataGetBytePtr(data);
     */
    assert(image_channels >= wanted_input_channels);
    tensorflow::uint8* in = image_data;
    for (int y = 0; y < wanted_input_height; ++y) {
        const int in_y = (y * image_height) / wanted_input_height;
        tensorflow::uint8* in_row = in + (in_y * image_width * image_channels);
        float* out_row = out + (y * wanted_input_width * wanted_input_channels);
        for (int x = 0; x < wanted_input_width; ++x) {
            const int in_x = (x * image_width) / wanted_input_width;
            tensorflow::uint8* in_pixel = in_row + (in_x * image_channels);
            float* out_pixel = out_row + (x * wanted_input_channels);
            for (int c = 0; c < wanted_input_channels; ++c) {
                out_pixel[c] = (in_pixel[c] - input_mean) / input_std;
            }
        }
    }
    
    if (tf_session.get()) {
        std::vector<tensorflow::Tensor> outputs;
        tensorflow::Status run_status = tf_session->Run(
                                                        {{input_layer_name, image_tensor}}, {output_layer_name}, {}, &outputs);
        if (!run_status.ok()) {
            LOG(ERROR) << "Running model failed:" << run_status;
        } else {
            tensorflow::Tensor *output = &outputs[0];
            auto predictions = output->flat<float>();
            
            for (int index = 0; index < predictions.size(); index += 1) {
                const float predictionValue = predictions(index);
                if (predictionValue > 0.5f) {
                    std::string label = labels[index % predictions.size()];
                    NSString *labelObject = [NSString stringWithCString:label.c_str()];
                    NSNumber *valueObject = [NSNumber numberWithFloat:predictionValue];
                    [newValues setObject:valueObject forKey:labelObject];
                    NSLog(@"Prediction Value: %f ", predictionValue );

                    isBadPhoto = predictionValue > 0.8f && ([labelObject containsString:@"black"] || [labelObject containsString:@"phonescreen"]) ;
                    isBadPhoto = isBadPhoto ? isBadPhoto : predictionValue > 0.8f && ([labelObject containsString:@"bad photos"]) ;
                    
                }
            }
            if(isBadPhoto){
                NSString *log = [NSString stringWithFormat:@"%@\n", newValues];
                NSLog(@"Bad Photo %@", log);
                //display new value;
                /*dispatch_async(dispatch_get_main_queue(), ^(void) {
                    self.urlContentTextView.text = [NSString stringWithFormat:@"%@\n/%@-%@", self.urlContentTextView.text, info,newValues];
                });*/
            }
        }
        
        
    }
    
    free(image_data);
    return isBadPhoto;
    
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)aTextField
{
    [aTextField resignFirstResponder];
    return YES;
}

- (void)dealloc {
    /*
    [_badPhotos release];
    [_showResultBtn release];
    [_maxResults release];
    [_progressView release];
    [_lblFound release];
    [_progressView release];
    [super dealloc];
     */
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Initialise
    self.assets = [NSMutableArray new];
    self.photos = [[NSMutableArray alloc] init];
    self.thumbs = [[NSMutableArray alloc] init];
    
    tensorflow::Status load_status;
    if (model_uses_memory_mapping) {
        load_status = LoadMemoryMappedModel(
                                            model_file_name, model_file_type, &tf_session, &tf_memmapped_env);
    } else {
        load_status = LoadModel(model_file_name, model_file_type, &tf_session);
    }
    if (!load_status.ok()) {
        LOG(FATAL) << "Couldn't load model: " << load_status;
    }
    // self.maxResults.delegate = self;
    tensorflow::Status labels_status =
    LoadLabels(labels_file_name, labels_file_type, &labels);
    if (!labels_status.ok()) {
        LOG(FATAL) << "Couldn't load labels: " << labels_status;
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}
#pragma mark - MWPhotoBrowserDelegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.photos.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < self.photos.count)
        return [self.photos objectAtIndex:index];
    return nil;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser thumbPhotoAtIndex:(NSUInteger)index {
    if (index < self.thumbs.count)
        return [self.thumbs objectAtIndex:index];
    return nil;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index {
    NSLog(@"Did start viewing photo at index %lu", (unsigned long)index);
}

- (BOOL)photoBrowser:(MWPhotoBrowser *)photoBrowser isPhotoSelectedAtIndex:(NSUInteger)index {
    return [[_selections objectAtIndex:index] boolValue];
}
- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index selectedChanged:(BOOL)selected {
    [_selections replaceObjectAtIndex:index withObject:[NSNumber numberWithBool:selected]];
    NSLog(@"Photo at index %lu selected %@", (unsigned long)index, selected ? @"YES" : @"NO");
}

- (void)photoBrowserDidFinishModalPresentation:(MWPhotoBrowser *)photoBrowser {
    // If we subscribe to this method we must dismiss the view controller ourselves
    NSLog(@"Did finish modal presentation");
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)showResult:(id)sender {
    MWPhotoBrowser *browser
    = [[MWPhotoBrowser alloc] initWithDelegate:self];
    
    // Set options
    browser.displayActionButton = NO; // Show action button to allow sharing, copying, etc (defaults to YES)
    browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
    browser.displaySelectionButtons = NO; // Whether selection buttons are shown on each image (defaults to NO)
    browser.zoomPhotosToFill = YES; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
    browser.alwaysShowControls = NO; // Allows to control whether the bars and controls are always visible or whether they fade away to show the photo full (defaults to NO)
    browser.enableGrid = YES; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
    browser.startOnGrid = YES; // Whether to start on the grid of thumbnails instead of the first photo (defaults to NO)
    browser.autoPlayOnAppear = NO; // Auto-play first video
    
    [browser setCurrentPhotoIndex:0];
    // Present
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:browser];
    nc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:nc animated:YES completion:nil];
}
@end
