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

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"
#import "ImageHelper.h"
#import "MWPhotoBrowser.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "MBCircularProgressBarView.h"

@interface CameraExampleViewController
    : UIViewController<MWPhotoBrowserDelegate, UITextFieldDelegate> {
        NSMutableArray *_selections;
  std::unique_ptr<tensorflow::Session> tf_session;
  std::unique_ptr<tensorflow::MemmappedEnv> tf_memmapped_env;
  std::vector<std::string> labels;
        IBOutlet UIButton			*scan;

}

    @property (nonatomic, strong) NSMutableArray *photos;
    @property (nonatomic, strong) NSMutableArray *thumbs;
    @property (nonatomic, strong) NSMutableArray *assets;
    @property (nonatomic, strong) NSMutableDictionary *selectedImages;


    @property (retain, nonatomic) IBOutlet UILabel *lblFound;
    
    @property (retain, nonatomic) IBOutlet MBCircularProgressBarView *progressView;
    
- (IBAction)getUrl:(id)sender;
- (IBAction)viewResults:(id)sender;
- (IBAction)showResult:(id)sender;
    - (void)loadAssets;



@end
