//
//  CampanileScene.cpp
//  StructuralAnalysisAR
//
//  Created by David Wehr on 1/9/18.
//  Copyright © 2018 David Wehr. All rights reserved.
//

#include "CampanileScene.h"

#include "VuforiaARManager.h"
#include "StaticARManager.h"

@implementation CampanileScene

- (id)initWithController:(id<ARViewController>)controller {
    managingParent = controller;
    return [self init];
}

- (SCNNode *)createScene:(SCNView *)the_scnView skScene:(SKScene *)skScene withCamera:(SCNNode *)camera {
    scnView = the_scnView;
    cameraNode = camera;
    SCNNode* rootNode = [SCNNode node];
    
    auto addLight = [rootNode] (float x, float y, float z, float intensity) {
        SCNNode *lightNode = [SCNNode node];
        lightNode.light = [SCNLight light];
        lightNode.light.type = SCNLightTypeOmni;
        lightNode.light.intensity = intensity;
        lightNode.position = SCNVector3Make(x, y, z);
        [rootNode addChildNode:lightNode];
    };
    addLight(100, 50, 50, 700);
    addLight(0, 30, 100, 500);
    
    // create and add an ambient light to the scene
    SCNNode *ambientLightNode = [SCNNode node];
    ambientLightNode.light = [SCNLight light];
    ambientLightNode.light.type = SCNLightTypeAmbient;
    ambientLightNode.light.color = [UIColor darkGrayColor];
    ambientLightNode.light.intensity = 0.8;
    [rootNode addChildNode:ambientLightNode];
    
    float load_min_h = 15; float load_max_h = 40;
    float input_range[2] = {0, 2};
    float thickness = 3;
    
    const float base_width = 16;
    const float base_height = 89 + 2.f / 12;
    const float roof_height = 20 + 4.5 / 12;
    const float roof_angle = 1.1965977338;
    
    windwardSideLoad = LoadMarker(5);
    windwardSideLoad.setPosition(GLKVector3Make(-base_width/2, 0, 0));
    windwardSideLoad.setOrientation(GLKQuaternionMakeWithAngleAndAxis(M_PI/2.f, 0, 0, 1));
    windwardSideLoad.setEnds(0, 89 + 2.f/12);

    windwardRoofLoad = LoadMarker(3);
    windwardRoofLoad.setPosition(GLKVector3Make(-base_width/2, base_height, 0));
    windwardRoofLoad.setOrientation(GLKQuaternionMakeWithAngleAndAxis(roof_angle, 0, 0, 1));
    float roof_length = roof_height / std::sin(roof_angle);
    windwardRoofLoad.setEnds(0, roof_length);
    
    leewardRoofLoad = LoadMarker(3, true);
    leewardRoofLoad.setPosition(GLKVector3Make(base_width/2, base_height, 0));
    leewardRoofLoad.setOrientation(GLKQuaternionMakeWithAngleAndAxis(M_PI - roof_angle, 0, 0, 1));
    leewardRoofLoad.setEnds(0, roof_length);
    
    leewardSideLoad = LoadMarker(5, true);
    leewardSideLoad.setPosition(GLKVector3Make(base_width/2, 0, 0));
    leewardSideLoad.setOrientation(GLKQuaternionMakeWithAngleAndAxis(M_PI/2.f, 0, 0, 1));
    leewardSideLoad.setEnds(0, 89 + 2.f/12);

    std::vector<LoadMarker*> loads = {&windwardSideLoad, &windwardRoofLoad, &leewardSideLoad, &leewardRoofLoad};
    for (LoadMarker* load : loads) {
        load->setScenes(skScene, scnView);
        load->setInputRange(input_range[0], input_range[1]);
        load->setMinHeight(load_min_h);
        load->setMaxHeight(load_max_h);
        load->setThickness(thickness);
        load->addAsChild(rootNode);
        load->setLoad(0.5);
    }

    return rootNode;
}

- (void)scnRendererUpdate { 
    
}

- (void)setCameraLabelPaused:(bool)isPaused {
    if (isPaused) {
        [self.freezeFrameBtn setTitle:@"Resume Camera" forState:UIControlStateNormal];
    }
    else {
        [self.freezeFrameBtn setTitle:@"Pause Camera" forState:UIControlStateNormal];
    }
}

- (void)setupUIWithScene:(SCNView *)scnView screenBounds:(CGRect)screenRect isGuided:(bool)guided {
    [[NSBundle mainBundle] loadNibNamed:@"campanileView" owner:self options: nil];
    self.viewFromNib.frame = screenRect;
    self.viewFromNib.contentMode = UIViewContentModeScaleToFill;
    [scnView addSubview:self.viewFromNib];
    
    CGColor* textColor = [UIColor colorWithRed:0.08235 green:0.49412 blue:0.9843 alpha:1.0].CGColor;
    // Setup home button style
    self.homeBtn.layer.borderWidth = 1.5;
    self.homeBtn.imageEdgeInsets = UIEdgeInsetsMake(3, 3, 3, 3);
    self.homeBtn.layer.borderColor = textColor;
    self.homeBtn.layer.cornerRadius = 5;
    
    // Setup freeze frame button
    self.freezeFrameBtn.layer.borderWidth = 1.5;
    self.freezeFrameBtn.layer.borderColor = textColor;
    self.freezeFrameBtn.layer.cornerRadius = 5;
}

- (void)skUpdate { 
    windwardSideLoad.doUpdate();
    windwardRoofLoad.doUpdate();
    leewardSideLoad.doUpdate();
    leewardRoofLoad.doUpdate();
}


// Make various AR Managers
- (ARManager*)makeStaticTracker {
    GLKMatrix4 trans_mat = GLKMatrix4MakeTranslation(0, 50, 210);
    GLKMatrix4 rot_x_mat = GLKMatrix4MakeXRotation(0.3);
    GLKMatrix4 cameraMatrix = GLKMatrix4Multiply(rot_x_mat, trans_mat);
    return new StaticARManager(scnView, scnView.scene, cameraMatrix);
}

- (ARManager*)makeIndoorTracker {
    return nullptr;
}

- (ARManager*)makeOutdoorTracker {
    return nullptr;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { 
    
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { 
    
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { 
    
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { 
    
}


- (IBAction)freezePressed:(id)sender {
    // TODO
//    [managingParent freezePressed:sender freezeBtn:self.freezeFrameBtn curtain:self.processingCurtainView];
}

- (IBAction)homeBtnPressed:(id)sender {
    return [managingParent homeBtnPressed:sender];
}

- (IBAction)trackingModeChanged:(id)sender {
    enum TrackingMode new_mode = static_cast<TrackingMode>(self.trackingModeBtn.selectedSegmentIndex);
    // temporarily disable button to indicate we are switching
    self.trackingModeBtn.enabled = NO;
    
    [managingParent setTrackingMode:new_mode];
    [self setCameraLabelPaused:NO];
    
    self.trackingModeBtn.enabled = YES;
}

- (IBAction)windSpeedChanged:(id)sender {
}

@end
