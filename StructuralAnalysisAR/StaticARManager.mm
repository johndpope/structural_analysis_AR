//
//  StaticARManager.cpp
//  StructuralAnalysisAR
//
//  Created by David Wehr on 12/11/17.
//  Copyright © 2017 David Wehr. All rights reserved.
//

#include "StaticARManager.h"

#import <GLKit/GLKMatrix4.h>
#import <MetalKit/MetalKit.h>

StaticARManager::StaticARManager(UIView* view, SCNScene* scene, GLKMatrix4 desiredPose, NSString* bgImagePath) {
    UIImage* bgImage = [UIImage imageNamed:bgImagePath];
    int img_width = bgImage.size.width;
    int img_height = bgImage.size.height;
    
    // Load image into texture
    id<MTLDevice> gpu = MTLCreateSystemDefaultDevice();
    MTKTextureLoader* texLoader = [[MTKTextureLoader alloc] initWithDevice:gpu];
    // Set as sRGB to be correct color
    NSDictionary* mtkLoaderOptions = @{ MTKTextureLoaderOptionSRGB: @0 };
    NSError* error = [NSError alloc];
    id<MTLTexture> staticBgTex = [texLoader newTextureWithData:UIImagePNGRepresentation(bgImage) options:mtkLoaderOptions error:&error];
    if (error) {
        printf("Failed to load static background image\n");
    }
    // Set texture as background
    scene.background.contents = staticBgTex;
//    scene.background.contents = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];;

    // Calculate scaling so image is not stretched
    float aspectImage = (float)img_width / img_height;
    CGSize viewSize = view.frame.size;
    float aspectScreen = (float)viewSize.width / viewSize.height;
    float xScale, yScale;
    xScale = yScale = 1;
    if (aspectImage > aspectScreen) {
        xScale = aspectScreen / aspectImage;
    }
    else {
        yScale = aspectImage / aspectScreen;
    }
    GLKMatrix4 bgImgScale = GLKMatrix4MakeScale(xScale, yScale, 1);
    scene.background.contentsTransform = SCNMatrix4FromGLKMatrix4(bgImgScale);
    
    
    projectionMatrix = GLKMatrix4MakePerspective(36.909 * (M_PI / 180.0), aspectScreen, 0.1, 500);
    
    cameraMatrix = desiredPose;
}


GLKMatrix4 StaticARManager::getCameraMatrix() {
//    static float phase = 0;
//    phase += 0.01;
//    float angle = 0.2 * std::sin(phase);
//    GLKMatrix4 rotMat = GLKMatrix4MakeYRotation(angle);
//    return GLKMatrix4Multiply(rotMat, cameraMatrix);
    return cameraMatrix;
}

GLKMatrix4 StaticARManager::getProjectionMatrix() {
    return projectionMatrix;
}

