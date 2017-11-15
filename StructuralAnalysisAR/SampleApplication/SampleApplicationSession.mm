/*===============================================================================
 Copyright (c) 2015-2017 PTC Inc. All Rights Reserved. Confidential and Proprietary -
 Protected under copyright and other laws.
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/

#import "SampleApplicationSession.h"
#import "SampleApplicationUtils.h"
#import <Vuforia/Vuforia.h>
#import <Vuforia/Vuforia_iOS.h>
#import <Vuforia/Tool.h>
#import <Vuforia/Renderer.h>
#import <Vuforia/CameraDevice.h>
#import <Vuforia/VideoBackgroundConfig.h>
#import <Vuforia/UpdateCallback.h>

#import <UIKit/UIKit.h>

#define DEBUG_SAMPLE_APP 1

namespace {
    // --- Data private to this unit ---
    
    // instance of the seesion
    // used to support the Vuforia callback
    // there should be only one instance of a session
    // at any given point of time
    SampleApplicationSession* instance = nil;
    
    // Vuforia initialisation flags (passed to Vuforia before initialising)
    int mVuforiaInitFlags;
    
    // camera to use for the session
    Vuforia::CameraDevice::CAMERA_DIRECTION mCamera = Vuforia::CameraDevice::CAMERA_DIRECTION_DEFAULT;
    
    // class used to support the Vuforia callback mechanism
    class VuforiaApplication_UpdateCallback : public Vuforia::UpdateCallback {
        virtual void Vuforia_onUpdate(Vuforia::State& state);
    } vuforiaUpdate;

    // NSerror domain for errors coming from the Sample application template classes
    NSString * SAMPLE_APPLICATION_ERROR_DOMAIN = @"vuforia_sample_application";
    
    const float orthoProjectionMatrix[] =
    {
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, -1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    };
}

@interface SampleApplicationSession ()

@property (nonatomic, readwrite) UIInterfaceOrientation mARViewOrientation;
@property (nonatomic, readwrite) BOOL mIsActivityInPortraitMode;
@property (nonatomic, readwrite) BOOL cameraIsActive;
@property (nonatomic, readwrite) BOOL mIsMetalRendering;
// *** Metal ***
// Projection matrix scale factors, used when rendering with Metal if the
// aspect ratios of the viewport and video do not match due to the viewport
// bounds being limited by the size of the render buffer (screen)
//
@property (nonatomic, readwrite) float projectionScaleX;
@property (nonatomic, readwrite) float projectionScaleY;
@property (nonatomic, readwrite) float orthoProjScaleX;
@property (nonatomic, readwrite) float orthoProjScaleY;


// SampleApplicationControl delegate (receives callbacks in response to particular
// events, such as completion of Vuforia initialisation)
@property (nonatomic, assign) SampleApplicationControlCpp* delegate;

@end


@implementation SampleApplicationSession
@synthesize viewport;

- (id)initWithDelegate:(SampleApplicationControlCpp*) delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        
        // we keep a reference of the instance in order to implemet the Vuforia callback
        instance = self;
    }
    return self;
}

//- (void)setDelegate:(id<SampleApplicationControl>) delegate {
//    self.delegate = delegate;
//}

// build a NSError
- (NSError *) NSErrorWithCode:(int) code {
    return [NSError errorWithDomain:SAMPLE_APPLICATION_ERROR_DOMAIN code:code userInfo:nil];
}

- (NSError *) NSErrorWithCode:(NSString *) description code:(NSInteger)code {
    NSDictionary *userInfo = @{
                           NSLocalizedDescriptionKey: description
                           };
    return [NSError errorWithDomain:SAMPLE_APPLICATION_ERROR_DOMAIN
                                     code:code
                                 userInfo:userInfo];
}

- (NSError *) NSErrorWithCode:(int) code error:(NSError **) error{
    if (error != NULL) {
        *error = [self NSErrorWithCode:code];
        return *error;
    }
    return nil;
}

// Determine whether the device has a retina display
- (BOOL)isRetinaDisplay
{
    // If UIScreen mainScreen responds to selector
    // displayLinkWithTarget:selector: and the scale property is larger than 1.0, then this
    // is a retina display
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] && 1.0 < [UIScreen mainScreen].scale);
}

// Initialize the Vuforia SDK
- (void) initAR:(int) VuforiaInitFlags orientation:(UIInterfaceOrientation) ARViewOrientation {
    self.cameraIsActive = NO;
    self.cameraIsStarted = NO;
    mVuforiaInitFlags = VuforiaInitFlags;
    self.isRetinaDisplay = [self isRetinaDisplay];
    self.mARViewOrientation = ARViewOrientation;
    self.mIsMetalRendering = (mVuforiaInitFlags == Vuforia::METAL);

    // Initialising Vuforia is a potentially lengthy operation, so perform it on a
    // background thread
    [self performSelectorInBackground:@selector(initVuforiaInBackground) withObject:nil];
}

// Initialise Vuforia
// (Performed on a background thread)
- (void)initVuforiaInBackground
{
    // Background thread must have its own autorelease pool
    @autoreleasepool {
        Vuforia::setInitParameters(mVuforiaInitFlags,"AYEwhQz/////AAAAGTZcgWbk50U0n2D78X5cCAAPgZGulkobbe6X/fas2trQXnEkwk9P4vfA/iZpiQhLbdkhCsVkgtlF45pE0IdyEc3cZpUBiC1SB8fvZACyBCiJkSYjx2e1Kyg6otgFnrqIzsZMARdF0XoOsdkynvzEMwFSjFPa7eU1nnYjaAdLmxsd2D69Vtdnq8KAhVvocUxJ2xwRQejylvw8okDk43jUkpBBHc2+8hrD6CDunE69CHzgIDX/J1EOKMX4hUxoTRaEHYowezEc/WKFJYBoVWWNURhRc7mfyr0drvpQ1QDYI+eLFLoeg1F+ccUqRfftbHJWCgtsKHXYmufZ6MJRKcLT4zOHy6hC2hvJTSW8+qEg4/iT");
        
        // Vuforia::init() will return positive numbers up to 100 as it progresses
        // towards success.  Negative numbers indicate error conditions
        NSInteger initSuccess = 0;
        do {
            initSuccess = Vuforia::init();
        } while (0 <= initSuccess && 100 > initSuccess);
        
        if (100 == initSuccess) {
            // We can now continue the initialization of Vuforia
            // (on the main thread)
            [self performSelectorOnMainThread:@selector(prepareAR) withObject:nil waitUntilDone:NO];
        }
        else {
            // Failed to initialise Vuforia:
            if (Vuforia::INIT_NO_CAMERA_ACCESS == initSuccess) {
                // On devices running iOS 8+, the user is required to explicitly grant
                // camera access to an App.
                // If camera access is denied, Vuforia::init will return
                // Vuforia::INIT_NO_CAMERA_ACCESS.
                // This case should be handled gracefully, e.g.
                // by warning and instructing the user on how
                // to restore the camera access for this app
                // via Device Settings > Privacy > Camera
                [self performSelectorOnMainThread:@selector(showCameraAccessWarning) withObject:nil waitUntilDone:YES];
            }
            else {
                NSError * error;
                switch(initSuccess) {
                    case Vuforia::INIT_LICENSE_ERROR_NO_NETWORK_TRANSIENT:
                        error = [self NSErrorWithCode:NSLocalizedString(@"INIT_LICENSE_ERROR_NO_NETWORK_TRANSIENT", nil) code:initSuccess];
                        break;
                        
                    case Vuforia::INIT_LICENSE_ERROR_NO_NETWORK_PERMANENT:
                        error = [self NSErrorWithCode:NSLocalizedString(@"INIT_LICENSE_ERROR_NO_NETWORK_PERMANENT", nil) code:initSuccess];
                        break;
                        
                    case Vuforia::INIT_LICENSE_ERROR_INVALID_KEY:
                        error = [self NSErrorWithCode:NSLocalizedString(@"INIT_LICENSE_ERROR_INVALID_KEY", nil) code:initSuccess];
                        break;
                        
                    case Vuforia::INIT_LICENSE_ERROR_CANCELED_KEY:
                        error = [self NSErrorWithCode:NSLocalizedString(@"INIT_LICENSE_ERROR_CANCELED_KEY", nil) code:initSuccess];
                        break;
                        
                    case Vuforia::INIT_LICENSE_ERROR_MISSING_KEY:
                        error = [self NSErrorWithCode:NSLocalizedString(@"INIT_LICENSE_ERROR_MISSING_KEY", nil) code:initSuccess];
                        break;
                        
                    case Vuforia::INIT_LICENSE_ERROR_PRODUCT_TYPE_MISMATCH:
                        error = [self NSErrorWithCode:NSLocalizedString(@"INIT_LICENSE_ERROR_PRODUCT_TYPE_MISMATCH", nil) code:initSuccess];
                        break;
                        
                    case Vuforia::INIT_DEVICE_NOT_SUPPORTED:
                        error = [self NSErrorWithCode:NSLocalizedString(@"INIT_DEVICE_NOT_SUPPORTED", nil) code:initSuccess];
                        break;
                        
                    default:
                        error = [self NSErrorWithCode:NSLocalizedString(@"INIT_default", nil) code:initSuccess];
                        break;
                        
                }
                // Vuforia initialization error
                // [self.delegate onInitARDone:error];
                self.delegate->onInitARDone(error);
            }
        }
    }
}

// Prompts a dialog to warn the user that
// the camera access was not granted to this App and
// to provide instructions on how to restore it.
-(void) showCameraAccessWarning
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    NSString *message = [NSString stringWithFormat:@"User denied camera access to this App. To restore camera access, go to: \nSettings > Privacy > Camera > %@ and turn it ON as well as \nSettings > General > Restrictions > Camera and turn it ON.", appName];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Camera Access Warning" message:message delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil, nil];
    
    [alert show];
}

// Quit App when user dismisses the camera access alert dialog
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Camera Access Warning"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kDismissAppViewController" object:nil];
    }
}

// Resume Vuforia
- (bool) resumeAR:(NSError **)error {
    Vuforia::onResume();
    
    // if the camera was previously started, but not currently active, then
    // we restart it
    if ((self.cameraIsStarted) && (! self.cameraIsActive)) {
        
        // initialize the camera
        if (! Vuforia::CameraDevice::getInstance().init(mCamera)) {
            [self NSErrorWithCode:E_INITIALIZING_CAMERA error:error];
            return NO;
        }
        
        // start the camera
        if (!Vuforia::CameraDevice::getInstance().start()) {
            [self NSErrorWithCode:E_STARTING_CAMERA error:error];
            return NO;
        }
        
        self.cameraIsActive = YES;
    }
    return YES;
}


// Pause Vuforia
- (bool)pauseAR:(NSError **)error {
    if (self.cameraIsActive) {
        // Stop and deinit the camera
        if(! Vuforia::CameraDevice::getInstance().stop()) {
            [self NSErrorWithCode:E_STOPPING_CAMERA error:error];
            return NO;
        }
        if(! Vuforia::CameraDevice::getInstance().deinit()) {
            [self NSErrorWithCode:E_DEINIT_CAMERA error:error];
            return NO;
        }
        self.cameraIsActive = NO;
    }
    Vuforia::onPause();
    return YES;
}

- (void) Vuforia_onUpdate:(Vuforia::State *) state {
    if (self.delegate) {
        self.delegate->onVuforiaUpdate(state);
    }
    // if ((self.delegate != nil) && [self.delegate respondsToSelector:@selector(onVuforiaUpdate:)]) {
    //     [self.delegate onVuforiaUpdate:state];
    // }
}

- (CGSize)getCurrentARViewBoundsSize
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGSize viewSize = screenBounds.size;

    viewSize.width *= [UIScreen mainScreen].nativeScale;
    viewSize.height *= [UIScreen mainScreen].nativeScale;
    return viewSize;
}

- (void) prepareAR  {
    // we register for the Vuforia callback
    Vuforia::registerCallback(&vuforiaUpdate);
    
    // Tell Vuforia we've created a drawing surface
    Vuforia::onSurfaceCreated();
    
    CGSize viewBoundsSize = [self getCurrentARViewBoundsSize];
    int smallerSize = MIN(viewBoundsSize.width, viewBoundsSize.height);
    int largerSize = MAX(viewBoundsSize.width, viewBoundsSize.height);
    
    // Frames from the camera are always landscape, no matter what the
    // orientation of the device.  Tell Vuforia to rotate the video background (and
    // the projection matrix it provides to us for rendering our augmentation)
    // by the proper angle in order to match the EAGLView orientation
    if (self.mARViewOrientation == UIInterfaceOrientationPortrait)
    {
        Vuforia::onSurfaceChanged(smallerSize, largerSize);
        Vuforia::setRotation(Vuforia::ROTATE_IOS_90);
        
        self.mIsActivityInPortraitMode = YES;
    }
    else if (self.mARViewOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        Vuforia::onSurfaceChanged(smallerSize, largerSize);
        Vuforia::setRotation(Vuforia::ROTATE_IOS_270);
        
        self.mIsActivityInPortraitMode = YES;
    }
    else if (self.mARViewOrientation == UIInterfaceOrientationLandscapeLeft)
    {
        Vuforia::onSurfaceChanged(largerSize, smallerSize);
        Vuforia::setRotation(Vuforia::ROTATE_IOS_180);
        
        self.mIsActivityInPortraitMode = NO;
    }
    else if (self.mARViewOrientation == UIInterfaceOrientationLandscapeRight)
    {
        Vuforia::onSurfaceChanged(largerSize, smallerSize);
        Vuforia::setRotation(Vuforia::ROTATE_IOS_0);
        
        self.mIsActivityInPortraitMode = NO;
    }
    
    [self initTracker];
}

- (void) initTracker {
    // ask the application to initialize its trackers
    if (! self.delegate->doInitTrackers()) {
        self.delegate->onInitARDone([self NSErrorWithCode:E_INIT_TRACKERS]);
        return;
    }
    [self loadTrackerData];
}


- (void) loadTrackerData {
    // Loading tracker data is a potentially lengthy operation, so perform it on
    // a background thread
    [self performSelectorInBackground:@selector(loadTrackerDataInBackground) withObject:nil];
}

// *** Performed on a background thread ***
- (void)loadTrackerDataInBackground
{
    // Background thread must have its own autorelease pool
    @autoreleasepool {
        // the application can now prepare the loading of the data
        if(! self.delegate->doLoadTrackersData()) {
            self.delegate->onInitARDone([self NSErrorWithCode:E_LOADING_TRACKERS_DATA]);
            return;
        }
    }
    
    self.delegate->onInitARDone(nil);
}

// Configure Vuforia with the video background size
- (void)configureVideoBackgroundWithViewWidth:(float)viewWidth andHeight:(float)viewHeight
{
    // Get the default video mode
    Vuforia::CameraDevice& cameraDevice = Vuforia::CameraDevice::getInstance();
    self.videoMode = cameraDevice.getVideoMode(Vuforia::CameraDevice::MODE_DEFAULT);
    
    // Configure the video background
    Vuforia::VideoBackgroundConfig config;
//    config.mEnabled = true;
    config.mEnabled = true;
    config.mPosition.data[0] = 0.0f;
    config.mPosition.data[1] = 0.0f;
    
    // *** Metal ***
    // When using Metal, the viewport cannot extend outside the area of the
    // render buffer, so we must scale the projection matrix to compensate when
    // the aspect ratio of the video and the viewport do not match.
    // Default to a scale factor of 1.0f for both X and Y
    self.projectionScaleX = 1.0f;
    self.projectionScaleY = 1.0f;
    self.orthoProjScaleX = 1.0f;
    self.orthoProjScaleY = 1.0f;
    
    // Determine the orientation of the view.  Note, this simple test assumes
    // that a view is portrait if its height is greater than its width.  This is
    // not always true: it is perfectly reasonable for a view with portrait
    // orientation to be wider than it is high.  The test is suitable for the
    // dimensions used in this sample
    if (self.mIsActivityInPortraitMode) {
        // --- View is portrait ---
        
        // Compare aspect ratios of video and screen.  If they are different we
        // use the full screen size while maintaining the video's aspect ratio,
        // which naturally entails some cropping of the video
        float aspectRatioVideo = (float)self.videoMode.mWidth / (float)self.videoMode.mHeight;
        float aspectRatioView = viewHeight / viewWidth;
        
        if (aspectRatioVideo < aspectRatioView) {
            // Video (when rotated) is wider than the view: crop left and right
            // (top and bottom of video)
            
            // --============--
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // --============--
            
            config.mSize.data[0] = (int)self.videoMode.mHeight * (viewHeight / (float)self.videoMode.mWidth);
            config.mSize.data[1] = (int)viewHeight;
        }
        else {
            // Video (when rotated) is narrower than the view: crop top and
            // bottom (left and right of video).  Also used when aspect ratios
            // match (no cropping)
            
            // ------------
            // -          -
            // -          -
            // ============
            // =          =
            // =          =
            // =          =
            // =          =
            // =          =
            // =          =
            // =          =
            // =          =
            // ============
            // -          -
            // -          -
            // ------------
            
            config.mSize.data[0] = (int)viewWidth;
            config.mSize.data[1] = (int)self.videoMode.mWidth * (viewWidth / (float)self.videoMode.mHeight);
        }
        
        if (self.mIsMetalRendering) {
            // *** Metal ***
            // Calculate the projection scale for aspect ratio correction when the
            // required viewport size is larger than the render buffer.  Note that
            // the viewport position must also be considered in this calculation, if
            // it is not 0, 0
            if (config.mSize.data[1] > viewHeight) {
                self.projectionScaleX = static_cast<float>(config.mSize.data[1]) / viewHeight;
                self.orthoProjScaleY = self.projectionScaleX;
            }
            
            if (config.mSize.data[0] > viewWidth) {
                self.projectionScaleY = static_cast<float>(config.mSize.data[0]) / viewWidth;
                self.orthoProjScaleX = self.projectionScaleY;
            }
            
            // Scale first, then rotate
            SampleApplicationUtils::scalePoseMatrix(self.orthoProjScaleX, self.orthoProjScaleY, 1.0f, _orthoProjMatrix.data);
            SampleApplicationUtils::rotatePoseMatrix(-90.0f, 0.0f, 0.0f, 1.0f, _orthoProjMatrix.data);
            
        }
    }
    else {
        // --- View is landscape ---
        if (viewWidth < viewHeight) {
            // Swap width/height: this is neded on iOS7 and below
            // as the view width is always reported as if in portrait.
            // On IOS 8, the swap is not needed, because the size is
            // orientation-dependent; so, this swap code in practice
            // will only be executed on iOS 7 and below.
            float temp = viewWidth;
            viewWidth = viewHeight;
            viewHeight = temp;
        }
        
        // Compare aspect ratios of video and screen.  If they are different we
        // use the full screen size while maintaining the video's aspect ratio,
        // which naturally entails some cropping of the video
        float aspectRatioVideo = (float)self.videoMode.mWidth / (float)self.videoMode.mHeight;
        float aspectRatioView = viewWidth / viewHeight;
        
        if (aspectRatioVideo < aspectRatioView) {
            // Video is taller than the view: crop top and bottom
            
            // --------------------
            // ====================
            // =                  =
            // =                  =
            // =                  =
            // =                  =
            // ====================
            // --------------------
            
            config.mSize.data[0] = (int)viewWidth;
            config.mSize.data[1] = (int)self.videoMode.mHeight * (viewWidth / (float)self.videoMode.mWidth);
        }
        else {
            // Video is wider than the view: crop left and right.  Also used
            // when aspect ratios match (no cropping)
            
            // ---====================---
            // -  =                  =  -
            // -  =                  =  -
            // -  =                  =  -
            // -  =                  =  -
            // ---====================---
            
            config.mSize.data[0] = (int)self.videoMode.mWidth * (viewHeight / (float)self.videoMode.mHeight);
            config.mSize.data[1] = (int)viewHeight;
        }
        
        if (self.mIsMetalRendering) {
            // *** Metal ***
            // Metal: calculate the projection scale for aspect ratio correction
            // when the required viewport size is larger than the render buffer.
            // Note that the viewport position must also be considered in this
            // calculation, if it is not 0, 0
            if (config.mSize.data[0] > viewWidth) {
                self.projectionScaleX = static_cast<float>(config.mSize.data[0]) / viewWidth;
                self.orthoProjScaleX = self.projectionScaleX;
            }
            
            if (config.mSize.data[1] > viewHeight) {
                self.projectionScaleY = static_cast<float>(config.mSize.data[1]) / viewHeight;
                self.orthoProjScaleY = self.projectionScaleY;
            }
            
            SampleApplicationUtils::scalePoseMatrix(self.orthoProjScaleX, self.orthoProjScaleY, 1.0f, _orthoProjMatrix.data);
            
        }
    }
    
    // Calculate the viewport for the app to use when rendering
    viewport.posX = ((viewWidth - config.mSize.data[0]) / 2) + config.mPosition.data[0];
    viewport.posY = (((int)(viewHeight - config.mSize.data[1])) / (int) 2) + config.mPosition.data[1];
    viewport.sizeX = config.mSize.data[0];
    viewport.sizeY = config.mSize.data[1];
    
#ifdef DEBUG_SAMPLE_APP
    NSLog(@"VideoBackgroundConfig: size: %d,%d", config.mSize.data[0], config.mSize.data[1]);
    NSLog(@"VideoMode:w=%d h=%d", self.videoMode.mWidth, self.videoMode.mHeight);
    NSLog(@"width=%7.3f height=%7.3f", viewWidth, viewHeight);
    NSLog(@"ViewPort: X,Y: %d,%d Size X,Y:%d,%d", viewport.posX,viewport.posY,viewport.sizeX,viewport.sizeY);
#endif
    
    // Set the config
    Vuforia::Renderer::getInstance().setVideoBackgroundConfig(config);
}


// Start Vuforia camera with the specified view size
- (bool)startCamera:(Vuforia::CameraDevice::CAMERA_DIRECTION)camera viewWidth:(float)viewWidth andHeight:(float)viewHeight error:(NSError **)error
{
    // initialize the camera
    if (! Vuforia::CameraDevice::getInstance().init(camera)) {
        [self NSErrorWithCode:-1 error:error];
        return NO;
    }
    
    // select the default video mode
    if(! Vuforia::CameraDevice::getInstance().selectVideoMode(Vuforia::CameraDevice::MODE_DEFAULT)) {
        [self NSErrorWithCode:-1 error:error];
        return NO;
    }
    
    // Copy the orthographic projection matrix constant data (used for
    // video background when operating in bindVideoBackground mode)
    memcpy(_orthoProjMatrix.data, orthoProjectionMatrix, sizeof(_orthoProjMatrix.data));
    
    // configure Vuforia video background
    [self configureVideoBackgroundWithViewWidth:viewWidth andHeight:viewHeight];
    
    // set the FPS to its recommended value
    int recommendedFps = Vuforia::Renderer::getInstance().getRecommendedFps();
    Vuforia::Renderer::getInstance().setTargetFps(recommendedFps);
    
    // start the camera
    if (!Vuforia::CameraDevice::getInstance().start()) {
        [self NSErrorWithCode:-1 error:error];
        return NO;
    }
    
    // we keep track of the current camera to restart this
    // camera when the application comes back to the foreground
    mCamera = camera;
    
    // ask the application to start the tracker(s)
    if(! self.delegate->doStartTrackers() ) {
        [self NSErrorWithCode:-1 error:error];
        return NO;
    }
    
    // Cache the projection matrix
    const Vuforia::CameraCalibration& cameraCalibration = Vuforia::CameraDevice::getInstance().getCameraCalibration();
    _projectionMatrix = Vuforia::Tool::getProjectionGL(cameraCalibration, 2.0f, 5000.0f);
    SampleApplicationUtils::scalePoseMatrix(self.projectionScaleX, self.projectionScaleY, 1.0f, _projectionMatrix.data);

    return YES;
}


- (bool) startAR:(Vuforia::CameraDevice::CAMERA_DIRECTION)camera error:(NSError **)error {
    CGSize ARViewBoundsSize = [self getCurrentARViewBoundsSize];
    
    // Start the camera.  This causes Vuforia to locate our EAGLView in the view
    // hierarchy, start a render thread, and then call renderFrameVuforia on the
    // view periodically
    if (! [self startCamera: camera viewWidth:ARViewBoundsSize.width andHeight:ARViewBoundsSize.height error:error]) {
        return NO;
    }
    self.cameraIsActive = YES;
    self.cameraIsStarted = YES;

    return YES;
}

// Stop Vuforia camera
- (bool)stopAR:(NSError **)error {
    // Stop the camera
    if (self.cameraIsActive) {
        // Stop and deinit the camera
        Vuforia::CameraDevice::getInstance().stop();
        Vuforia::CameraDevice::getInstance().deinit();
        self.cameraIsActive = NO;
    }
    self.cameraIsStarted = NO;

    // ask the application to stop the trackers
    if(! self.delegate->doStopTrackers()) {
        [self NSErrorWithCode:E_STOPPING_TRACKERS error:error];
        return NO;
    }
    
    // ask the application to unload the data associated to the trackers
    if(! self.delegate->doUnloadTrackersData()) {
        [self NSErrorWithCode:E_UNLOADING_TRACKERS_DATA error:error];
        return NO;
    }
    
    // ask the application to deinit the trackers
    if(! self.delegate->doDeinitTrackers()) {
        [self NSErrorWithCode:E_DEINIT_TRACKERS error:error];
        return NO;
    }
    
    // Pause and deinitialise Vuforia
    Vuforia::onPause();
    Vuforia::deinit();
    
    self.delegate = nil;
    return YES;
}

// stop the camera
- (bool) stopCamera:(NSError **)error {
    if (self.cameraIsActive) {
        // Stop and deinit the camera
        Vuforia::CameraDevice::getInstance().stop();
        Vuforia::CameraDevice::getInstance().deinit();
        self.cameraIsActive = NO;
    } else {
        [self NSErrorWithCode:E_CAMERA_NOT_STARTED error:error];
        return NO;
    }
    self.cameraIsStarted = NO;
    
    // Stop the trackers
    if(! self.delegate->doStopTrackers()) {
        [self NSErrorWithCode:E_STOPPING_TRACKERS error:error];
        return NO;
    }

    return YES;
}

- (void) errorMessage:(NSString *) message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SAMPLE_APPLICATION_ERROR_DOMAIN
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

////////////////////////////////////////////////////////////////////////////////
// Callback function called by the tracker when each tracking cycle has finished
void VuforiaApplication_UpdateCallback::Vuforia_onUpdate(Vuforia::State& state)
{
    if (instance != nil) {
        [instance Vuforia_onUpdate:&state];
    }
}

@end
