//
//  cvARManager.hpp
//  StructuralAnalysisAR
//
//  Created by David Wehr on 11/16/17.
//  Copyright © 2017 David Wehr. All rights reserved.
//

#ifndef cvARManager_hpp
#define cvARManager_hpp

// Apparently include openCV things before any other iOS-specific headers
#import <opencv2/opencv.hpp>
#import <opencv2/videoio/cap_ios.h>
// these reference openCV includes
#include "ImageMatcher.hpp"
#include "MaskedImage.hpp"

#include <stdio.h>
#include <functional>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>

#include "ARManager.h"


// This delegate object allows us to receive callbacks from OpenCV, which requires an objective-C delegate
// It just calls a provided callback
@interface CvCameraDelegateObj : NSObject <CvVideoCameraDelegate> {
    std::function<void(cv::Mat&)> callbackFunc;
}
- (id)initWithCallback:(std::function<void(cv::Mat&)>)callback;

// Function called by openCV
- (void)processImage:(cv::Mat&)image;
@end

class cvARManager : public ARManager {
public:
    cvARManager(UIView* view, SCNScene* scene);
    void initAR() override;
    bool startAR() override;
    size_t stopAR() override;
    void pauseAR() override;
    GLKMatrix4 getCameraMatrix() override;
    GLKMatrix4 getProjectionMatrix() override;
    id<MTLTexture> getBgTexture() override;
    GLKMatrix4 getBgMatrix() override;
private:
    CvVideoCamera* camera;
    CvCameraDelegateObj* camDelegate;
    int video_width, video_height;
    // Metal texture for the background video
    id<MTLTexture> videoTexture;
    
    cv::Mat intrinsic_mat;
    
    void processImage(cv::Mat& image);
    
    // holds the frame that is being
    cv::Mat working_frame;
    std::atomic<bool> worker_busy;
    std::condition_variable worker_cond_var;
    std::mutex worker_mutex;
    std::thread worker_thread;
    void performTracking();
    
    GLKMatrix4 cameraMatrix;
    // AR things
    ImageMatcher matcher;
    
};

#endif /* cvARManager_hpp */