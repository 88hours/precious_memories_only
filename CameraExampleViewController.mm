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
#import "Model.h"
#import "ModelManager.h"
#import "MWPhoto+BadPhoto.h"
#import "PopUpViewController.h"
#import "MyAppSettings.h"
#import <SCLAlertView_Objective_C/SCLAlertView.h>



// If you have your own model, modify this to the file name, and make sure
// you've added the file to your app resources too.
static NSString* model_file_name = @"mmapped_kids_graph";
static NSString* model_file_type = @"pb";
// This controls whether we'll be loading a plain GraphDef proto, or a
// file created by the convert_graphdef_memmapped_format utility that wraps
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


NSString* const imageStausBlur = @"out of focus";
NSString* const  imageStausBlack = @"black";
NSString* const imageStausNoise = @"bad photos";
NSString* const  imageStausPhonescreen = @"phonescreen";


NSString* const foldersToScan = @"Selfies:Slo-mo:Time-lapse:Bursts:Screenshots:People:Places";

NSInteger iPhotoFoundCount = 0;  //Total number of photeos found in a scan
int scannedCount;

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
   // if(self.photos.count > 0){
     //   [self showResult:sender];
    //} else {
    
    currentJ = 0;
    self.lblFound.text = [NSString stringWithFormat:@"Found : %d ",0];
    self.progressView.value = 0;
    [self.photos removeAllObjects];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            [self loadAssets];
            
        }
        
        dispatch_async(dispatch_get_main_queue(), ^()
                       {
                           // call completion block on main
                           [self scanCompleted];
                       });
        
    });
    [scan setEnabled:NO];
    [viewResults setHidden:YES];
    [_posvc enableMe:NO];
    //}
}

-(void) scanCompleted
{
    //Enable Scan button for next Scan
    [scan setEnabled:YES];
    [viewResults setHidden:NO];
}

- (IBAction)viewResults:(id)sender
{
   // if(self.photos.count > 0)
    {
        [self showResult:sender];
    }
}
- (void)loadAssets {
    
    unsigned int mem = [self memoryInMB];
    //if( mem > 512)
    {   NSLog(@"Memory11 : %u", mem);
        // sleep(5);
        //   continue;
    }
    
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
    
    mem = [self memoryInMB];
    //if( mem > 512)
    {   NSLog(@"Memory12 : %u", mem);
        // sleep(5);
        //   continue;
    }
    
}

#pragma mark TensorFlow Model
int currentJ=0;
ModelManager *mgrObj;
NSMutableDictionary *tst;
-(void) findAllFiles
{
    NSDate *methodStart = [NSDate date];
    //-------- xb -------------
    mgrObj=[ModelManager getInstance];
    //-------- xb -------------
    tst =[[NSMutableDictionary alloc]init];
    tst = [mgrObj retrieveAllData];
    __block int iBlurImagesCount = 0, iBlackImageCount = 0, iNoisyImageCount=0;
    

    
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
    
    int maxResult = 1500;
    scannedCount = [self calculateTotalImagestoScan];
      int pValue =0;
    
    for (NSInteger i =0; i < result.count; i++) {
        
        
        PHAssetCollection *assetCollection = result[i];
        PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
        
        NSLog(@">>>>>>>>>>>>>>>>>>>>>The Asset Folder : %@", assetCollection.localizedTitle);
        
        if ([foldersToScan rangeOfString:assetCollection.localizedTitle options:NSCaseInsensitiveSearch].location == NSNotFound)
        {
            continue;
        }
        
        NSLog(@"Sub album title is %@, count is %ld", assetCollection.localizedTitle, assetsFetchResult.count);
        if (assetsFetchResult.count > 0) {
            
            
            //-------- xb -------------
            Model *picData = [[Model alloc]init];
            //-------- xb -------------
            MyAppSettings *settings = [[MyAppSettings alloc] init];
            [settings loadPrefs];
          
            
            for (int j =currentJ; (j < (int)assetsFetchResult.count && self.photos.count < maxResult);)
            {
             
                pValue++;
                // This autorelease pool seems good (a1)
                @autoreleasepool {
                    
                unsigned int mem = [self memoryInMB];
                //if( mem > 512)
                {   NSLog(@"Memory : %u", mem);
                   // sleep(5);
                 //   continue;
                }
                
                // Do something with the asset
                __block BOOL isICloudAsset = NO;
                PHAsset *asset =assetsFetchResult[j++];
                NSLog(@"the Local Identifier name is : %@", asset.localIdentifier);

                [manager requestImageForAsset:asset
                                   targetSize:PHImageManagerMaximumSize
                                  contentMode:PHImageContentModeDefault
                                      options:requestOptions
                                resultHandler:^void(UIImage *image, NSDictionary *dict)
                                {
                                    
                                    if ([dict[@"PHImageResultIsInCloudKey"] isEqual:@YES])
                                    {
                                        isICloudAsset = YES;
                                    }
                                    
                                    if(!isICloudAsset)
                                    {
                                        @autoreleasepool
                                        {
                                            NSMutableDictionary *newValues = [NSMutableDictionary dictionary];
                                            
                                            //-------- xb -------------
                                            //picData.URL = [dict objectForKey:@"PHImageFileURLKey"];
                                            picData.URL = asset.localIdentifier;
                                            //-------- xb -------------
                                            
                                            //NSString *url = [NSString stringWithFormat:@"%@", [dict objectForKey:@"PHImageFileURLKey"]];
                                            NSString *url = [NSString stringWithFormat:@"%@", asset.localIdentifier];
                                            Model *obj = [mgrObj getRecord:tst withName:url];
                                            
                                            bool badPhoto = false;
                                            
                                            //New image or already scnned one
                                            if (!obj)//New
                                            {
                                                badPhoto = [self RunInferenceOnImage:image :[dict objectForKey:@"PHImageFileURLKey"] :newValues];
                                                id value = [newValues objectForKey:@""];
                                                
                                                NSArray *keys=[newValues allKeys];
                                                
                                                if(keys!=NULL)
                                                {
                                                    if(keys.count > 0)
                                                    {
                                                        //Either add photo for view or not
                                                        NSString *strImageCategory = keys[0];
                                                        NSNumber *predictionVlaue = [newValues objectForKey:strImageCategory];
                                                        
                                                        picData.predictionValue = predictionVlaue;
                                                        
                                                        if([strImageCategory containsString:imageStausBlack])
                                                        {
                                                            iBlackImageCount++;
                                                        }
                                                        else if ([strImageCategory containsString:imageStausPhonescreen])
                                                        {
                                                            iBlurImagesCount++;
                                                        }
                                                        else if ([strImageCategory containsString:imageStausNoise] || [strImageCategory containsString:imageStausBlur])
                                                        {
                                                            iNoisyImageCount++;
                                                        }

                                                        badPhoto = true;
                                                        
                                                        picData.bad_image = strImageCategory;
                                                        
                                                    }
                                                }
                                                
                                            }
                                            else//Already scanned
                                            {
                                                
                                                if([obj.bad_image containsString:imageStausBlack])
                                                {
                                                    iBlackImageCount++;
                                                    badPhoto = true;

                                                }
                                                else if ([obj.bad_image containsString:imageStausPhonescreen])
                                                {
                                                    iBlurImagesCount++;
                                                    badPhoto = true;

                                                }
                                                else if([obj.bad_image containsString:imageStausNoise] || [obj.bad_image containsString:imageStausBlur])
                                                {
                                                    iNoisyImageCount++;
                                                    badPhoto = true;

                                                }

                                            }  //End of image scan

                                           //-------- xb -------------
                                            picData.state = @"0";
                                            
                                            NSDate *currDate = [NSDate date];
                                            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
                                            [dateFormatter setDateFormat:@"dd.MM.YY HH:mm:ss"];
                                            
                                            picData.scan_date = [dateFormatter stringFromDate:currDate];
                                            if (!obj)
                                            {
                                                [mgrObj insertData:picData];
                                            }
                                            //-------- xb -------------
                                            
                                            //image = nil;
                                            if(badPhoto)
                                            {
                                                NSLog(@"Scanning Selfies: %d / %d - %lu",j,(int)assetsFetchResult.count, (unsigned long)self.photos.count);
                                                MWPhoto *photo = [MWPhoto photoWithAsset:asset targetSize:thumbTargetSize];

                                                photo.photoUrl = [NSURL URLWithString:asset.localIdentifier];//[dict objectForKey:@"PHImageFileURLKey"];

                                               [self.photos addObject:photo];
                                              
                                                [_selections addObject:[NSNumber numberWithBool:0]];
                                                 
                                               [self.thumbs addObject:[MWPhoto photoWithAsset:asset targetSize:thumbTargetSize]];
                                            }
                                            else
                                                image = nil;
                                            
                                        }//Auto Release pole
                                        
                                    } // End of if(!isICloudAsset)

                                }];   //end manager requestImageForAsset  handler
                    
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [UIView animateWithDuration: 1.f animations:^{
                        self.progressView.value = (float)(pValue/(float)scannedCount) * 100;
                    }];
                    iPhotoFoundCount = self.photos.count;
                    self.lblFound.text = [NSString stringWithFormat:@"Found : %lu / %lu",(unsigned long)iPhotoFoundCount,(unsigned long)scannedCount];
                    
                });
                
                if(self.photos.count > maxResult)
                {
                    currentJ = j;
                    break;
                }
                
                    settings.blackImagesTotal = iBlackImageCount;
                    settings.blurImagesTotal = iBlurImagesCount;
                    settings.noisyImagesTotal = iNoisyImageCount;
                    [settings writePrefs];
            }
                
            
            }//End of folder Scanning
        }
    }
    requestOptions = nil;
    options = nil;
    result = nil;
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"executionTime = %f", executionTime);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_posvc enableMe:YES];
    });
    
}//End of findAllFiles

-(int) calculateTotalImagestoScan
{
    int iTotalImagasToScan = 0;

    //Scan All Desired folders to be scanned and Count the images
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
    //PHImageManager *manager = [PHImageManager defaultManager];
    
    
    for (NSInteger i =0; i < result.count; i++) {
        
        
        PHAssetCollection *assetCollection = result[i];
        PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
        
        NSLog(@">>>>>>>>>>>>>>>>>>>>>The Asset Folder : %@ : count : %lu", assetCollection.localizedTitle, (unsigned long)assetsFetchResult.count);
        //Only Work For Selfies
        //if([assetCollection.localizedTitle containsString:@"Selfies"] == false)
        //    if([foldersToScan containsString:assetCollection.localizedTitle] == false)
        
        if ([foldersToScan rangeOfString:assetCollection.localizedTitle options:NSCaseInsensitiveSearch].location == NSNotFound)
        {
            continue;
        }
        
        iTotalImagasToScan += assetsFetchResult.count;
    }
    
    return iTotalImagasToScan;
    
}
-(bool) retreiveImages
{
    
    [self.photos removeAllObjects];
    [_selections removeAllObjects];
    [self.thumbs removeAllObjects];
    
    // assets contains PHAsset objects.
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    // Sizing is very rough... more thought required in a real implementation
    CGFloat imageSize = MAX(screen.bounds.size.width, screen.bounds.size.height) * 1.5;
    CGSize imageTargetSize = CGSizeMake(imageSize * scale, imageSize * scale);
    CGSize thumbTargetSize = CGSizeMake(imageSize / 3.0 * scale, imageSize / 3.0 * scale);
    
    //Retrive images from DB
    //-------- xb -------------
    ModelManager *mgrObj=[ModelManager getInstance];
    //-------- xb -------------
    NSMutableDictionary *filteredImages =[[NSMutableDictionary alloc]init];
    filteredImages = [mgrObj retrieveDataByFilters];
    
    NSMutableArray *photoesToFetch =  [[NSMutableArray alloc] init];

    if(filteredImages)
    {
        NSLog(@"Filter Data retrived : %d", filteredImages.count);
        
            if(filteredImages.count == 0)
           {
               
               return false;
           }
        
    }
    
    for (NSString* key in filteredImages)
    {
        Model *picObj = [filteredImages objectForKey:key];
         [photoesToFetch addObject:picObj.URL];

    }

    
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:photoesToFetch options:nil];
    
    if (result.count > 0)
    {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, result.count)];
        
        //Get Assets from the specified indexes
        NSArray *assetToShow= [result objectsAtIndexes:indexSet];
        
        for(int iIndex = 0; iIndex < assetToShow.count; iIndex++)
        {
            PHAsset *asset = assetToShow[iIndex];
            
            MWPhoto *photo = [MWPhoto photoWithAsset:asset targetSize:thumbTargetSize];
        
            photo.photoUrl = [NSURL URLWithString:asset.localIdentifier];//[dict objectForKey:@"PHImageFileURLKey"];
        
            [self.photos addObject:photo];
        
            [_selections addObject:[NSNumber numberWithBool:0]];
        
            [self.thumbs addObject:[MWPhoto photoWithAsset:asset targetSize:thumbTargetSize]];
        }
        
    }
    
    return true;
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
    
    if (tf_session.get())
    {
        std::vector<tensorflow::Tensor> outputs;
        tensorflow::Status run_status = tf_session->Run(
                                                        {{input_layer_name, image_tensor}}, {output_layer_name}, {}, &outputs);
        if (!run_status.ok())
        {
            LOG(ERROR) << "Running model failed:" << run_status;
        }
        else
        {
            tensorflow::Tensor *output = &outputs[0];
            auto predictions = output->flat<float>();
            
            //Load filters
            MyAppSettings *setting = [[MyAppSettings alloc] init];
            [setting loadPrefs];
            
            for (int index = 0; index < predictions.size(); index += 1)
            {
                const float predictionValue = predictions(index);
                
                if (predictionValue > 0.5f)
                {
                    std::string label = labels[index % predictions.size()];
                    NSString *labelObject = [NSString stringWithCString:label.c_str()];
                    NSNumber *valueObject = [NSNumber numberWithFloat:predictionValue];
                    [newValues setObject:valueObject forKey:labelObject];
                    NSLog(@"Prediction Value: %f ", predictionValue );
                    NSLog(@"image status : %@", labelObject);
                    NSLog(@"Filer Values : [Blure :  %d] [Black :  %d] [Noise :  %d]", setting.IsBlur,setting.IsBlack,setting.IsNoise);
                  
                  /*  if(predictionValue > 0.8f)
                    {
                        
                        if((setting.IsBlack && [labelObject containsString:imageStausBlack]) || (setting.IsBlur && [labelObject containsString:imageStausBlur]) || (setting.IsNoise && [labelObject containsString:imageStausNoise]))
                        {
                                isBadPhoto = YES;
                        }
                    }
                    else
                    {
                        isBadPhoto = NO;
                    }*/
                    
                    isBadPhoto = predictionValue > 0.85f && ([labelObject containsString:@"black"] || [labelObject containsString:@"phonescreen"]) ;
                    isBadPhoto = isBadPhoto ? isBadPhoto : predictionValue > 0.85f && ([labelObject containsString:@"bad photos"]) ;
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

    
    //------------------------------------------------------
    //Only to prompt for permissions to access the photo gallery
      PHImageManager *manager = [PHImageManager defaultManager];
    //--------------------------------------------------------

    MyAppSettings *appSettings = [[MyAppSettings alloc] init];
    [appSettings loadPrefs];
    
    //Screen Width and Height
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat hieght = [UIScreen mainScreen].bounds.size.height;
   
    if(!appSettings.IsAppLaunchedAlready)

    {

        [appSettings setDefaultSettings];
        appSettings.IsAppLaunchedAlready = YES;
        
        [appSettings writePrefs];
        
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:nil];
        _popOverVC = [storyboard instantiateViewControllerWithIdentifier:@"sbPopUpID"];
    
        _popOverVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        [self addChildViewController:_popOverVC];
        _popOverVC.view.frame = CGRectMake((width/2-150), (hieght/2-150), 300, 300);
        [self.view addSubview:_popOverVC.view];
        [_popOverVC didMoveToParentViewController:self];
    }
    else
    {
        [scan setEnabled:YES];
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:nil];
    _posvc = [storyboard instantiateViewControllerWithIdentifier:@"filterViewID"];
    
    _posvc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    [self addChildViewController:_posvc];
    _posvc.view.frame = CGRectMake((width-37), (hieght/2-150), 294, 186);
    [self.view addSubview:_posvc.view];
    [_posvc didMoveToParentViewController:self];
    [_posvc enableMe:NO];
    
    [super viewDidLoad];
    // Initialise
    self.assets = [NSMutableArray new];
    self.photos = [[NSMutableArray alloc] init];
    _selections = [[NSMutableArray alloc] init];
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
    
    //Register Notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enableScanning:)
                                                 name:@"EnableScanning"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(UpdateUI:)
                                                 name:@"UpdateUI"
                                               object:nil];
    
    NSLog(@"admob start");
    //----------------GoogleMobAds---------------
    
    [self load_BannerAd];
    //----------------GoogleMobAds---------------
    NSLog(@"admob end");
    
   }

- (void)viewDidUnload {
    [super viewDidUnload];
}

#pragma mark Notification Center

-(void)enableScanning:(NSNotification *)notification
{
    NSLog(@"????????????????recieved");

    [scan setEnabled:YES];
}

-(void) UpdateUI :(NSNotification *)notification
{
    self.lblFound.text = [NSString stringWithFormat:@"Found : %lu / %lu",(unsigned long)iPhotoFoundCount,(unsigned long)scannedCount];
}

-(void)load_BannerAd{
    
    self.bannerView = [[GADBannerView alloc]
                       initWithAdSize:kGADAdSizeBanner];
    [self.view addSubview:self.bannerView];
    // Constraint keeps ad at the bottom of the screen at all times.
    [self.view addConstraint:
     [NSLayoutConstraint constraintWithItem:self.bannerView
                                  attribute:NSLayoutAttributeBottom
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:self.view
                                  attribute:NSLayoutAttributeBottom
                                 multiplier:1.0
                                   constant:0]];
    
    // Constraint keeps ad in the center of the screen at all times.
    [self.view addConstraint:
     [NSLayoutConstraint constraintWithItem:self.bannerView
                                  attribute:NSLayoutAttributeCenterX
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:self.view
                                  attribute:NSLayoutAttributeCenterX
                                 multiplier:1.0
                                   constant:0]];
    
    self.bannerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    
    self.bannerView.adUnitID = @"ca-app-pub-5800951218190212/6525833106";
    self.bannerView.rootViewController = self;
    [self.bannerView loadRequest:[GADRequest request]];
    
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
    
    
    
    NSString *key = [NSString stringWithFormat:@"%li", (unsigned long)index];
 
    
    if ([_selectedImages objectForKey:key]) {
     
        [_selectedImages setObject:key  forKey: key];
        
    }

    //     NSLog(@"selection count -------- %@",_selections.count);
   
    
    
    NSLog(@"%lu",(unsigned long)_selections.count);
    NSLog(@"Photo at index %lu selected %@", (unsigned long)index, selected ? @"YES" : @"NO");
}

- (void)photoBrowserDidFinishModalPresentation:(MWPhotoBrowser *)photoBrowser {
    // If we subscribe to this method we must dismiss the view controller ourselves
    NSLog(@"Did finish modal presentation");
  
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)photoBrowserDidRemoveFinishModalPresentation:(MWPhotoBrowser *)photoBrowser {
    // If we subscribe to this method we must dismiss the view controller ourselves
    int iBlackImageTobeDeleted = 0;
    int iBlurImagesTobeDeleted = 0;
    int iNoisyImageTobeDeleted = 0;

   
    NSLog(@"Did remove finish modal presentation");
    
  NSLog(@"in loop");
    
    NSMutableArray *photoesToDelete =  [[NSMutableArray alloc] init];
    for (int i = self.photos.count - 1; i >= 0; i--)
    {
         NSLog(@"index %d value %@",i,_selections[i]);
        
        if ([_selections objectAtIndex:i] == [NSNumber numberWithBool:1] )
        {
            NSLog(@"Deleting %d coz value %@",i,_selections[i]);
            
            [_selections replaceObjectAtIndex:i withObject:[NSNumber numberWithBool:false]];
    
            NSString *key = [NSString stringWithFormat:@"%li", (unsigned long)i];
            
            if ([_selectedImages objectForKey:key])
            {
                [_selectedImages setObject:key  forKey: key];
            }
            
            

            

            //Delete Image from Photo Liberary
            MWPhoto *asset = [photos objectAtIndex:i];
            [photoesToDelete addObject:asset.photoUrl.absoluteString];
            NSLog(@"%@", asset.photoUrl);
            
            //Count different category images
            NSString *url = [NSString stringWithFormat:@"%@", asset.photoUrl.absoluteString];
            Model *obj = [mgrObj getRecord:tst withName:url];
            
            if([obj.bad_image containsString:imageStausBlack])
            {
                iBlackImageTobeDeleted++;
            }
            else if ([obj.bad_image containsString:imageStausPhonescreen])
            {
                iBlurImagesTobeDeleted++;
            }
            else if ([obj.bad_image containsString:imageStausNoise] || [obj.bad_image containsString:imageStausBlur])
            {
                iNoisyImageTobeDeleted++;
            }
            
            
            //Remove from Browser collection as well
            [photos removeObjectAtIndex:i];
            [thumbs removeObjectAtIndex:i];
        
        }//End IF Block for Item selection for deletion
        
    }//End For Loop
    
    
    //Update Settings
    MyAppSettings *setting = [[MyAppSettings alloc] init];
    [setting loadPrefs];
    setting.blackImagesTotal = setting.blackImagesTotal - iBlackImageTobeDeleted;
    setting.blurImagesTotal = setting.blurImagesTotal - iBlurImagesTobeDeleted;
    setting.noisyImagesTotal = setting.noisyImagesTotal - iNoisyImageTobeDeleted;
    [setting writePrefs];
   
    //Remove photoes from the library
    [self deleteAssetWithLocalIdentifiers:photoesToDelete];

    [self dismissViewControllerAnimated:YES completion:nil];
} //End of photoBrowserDidRemoveFinishModalPresentation

-(void)deleteAssetWithLocalIdentifiers:(NSMutableArray*)assetObjects
{
    if (assetObjects == nil)
    {
        return;
    }
    
    if(assetObjects.count == 0)
    {
        
        return;
    }
    
     NSLog(@" deleting objects: %d", assetObjects.count);
    
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:assetObjects options:nil];

    if (result.count > 0)
    {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, result.count)];
        
        //Get Assets from the specified indexes
        NSArray *assetToBeDeleted = [result objectsAtIndexes:indexSet];
        
        // PHAsset *phAsset = result.firstObject;
       // if ((phAsset != nil) && ([phAsset canPerformEditOperation:PHAssetEditOperationDelete]))
        {
            NSLog(@" Last delete objects req: %d", assetToBeDeleted.count);

            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^
             {
                 [PHAssetChangeRequest deleteAssets:assetToBeDeleted];
             }
                                              completionHandler:^(BOOL success, NSError *error)
             {
                 
                 NSLog(@" Last delete objects req33333: %d", assetToBeDeleted.count);

                 
                 if ((!success) && (error != nil))
                 {
                     NSLog(@"Error deleting asset: %@", [error description]);
                 }
                 else
                 {
                     NSLog(@"Done with deleting asset:");
                     iPhotoFoundCount = iPhotoFoundCount - assetToBeDeleted.count;

                     dispatch_async(dispatch_get_main_queue(), ^{
                         self.lblFound.text = [NSString stringWithFormat:@"Found : %lu / %lu",(unsigned long)iPhotoFoundCount,(unsigned long)scannedCount];
                         
                     });

                 }
             }];
        }
        
    }//End of if (result.count > 0)
    
}//ENd of deleteAssetWithLocalIdentifiers

- (IBAction)showResult:(id)sender {
    
    
    if([self retreiveImages])
    {
    
    //Initilize selected images dic
    _selectedImages =[[NSMutableDictionary alloc] init];

    MWPhotoBrowser *browser
    = [[MWPhotoBrowser alloc] initWithDelegate:self];
    
    // Set options
    browser.displayActionButton = NO; // Show action button to allow sharing, copying, etc (defaults to YES)
    browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
   //browser.displaySelectionButtons = NO; // Whether selection buttons are shown on each image (defaults to NO)
    browser.displaySelectionButtons = YES;
    browser.zoomPhotosToFill = NO; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
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
    else
    {
        NSLog(@"No Filter Data retrived");
        
/*        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"No Filter is Selected"
                                                                       message:@"Please select a filter to view the images."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];*/
        
        SCLAlertView *alert = [[SCLAlertView alloc] init];

        [alert showInfo:self title:@"No data to display " subTitle:@"Please select a filter to view the images or scan images first." closeButtonTitle:@"OK" duration:0.0f]; // Error

    }
}



@end
