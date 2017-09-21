//
//  GameViewController.m
//  sceneKitTest
//
//  Created by David Wehr on 8/18/17.
//  Copyright © 2017 David Wehr. All rights reserved.
//

#import "GameViewController.h"
#import <ModelIO/ModelIO.h>
#import <SceneKit/ModelIO.h>
#import <GLKit/GLKQuaternion.h>
#include <cmath>

#define COL1_POS -80
#define COL2_POS -25
#define COL3_POS 74
#define COL4_POS 118

// IDs of UISegmentedControl for scenario selection
#define SCENARIO_VARIABLE 4

@implementation GameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    scene = [SCNScene scene];
    scene.background.contents = [UIImage imageNamed:@"skywalk.jpg"];
    
//    [scene.rootNode addChildNode:arrow.root];
    
    // Make a camera
    cameraNode = [SCNNode node];
    cameraNode.camera = [SCNCamera camera];
    [scene.rootNode addChildNode:cameraNode];
    // move the camera
    cameraNode.position = SCNVector3Make(-5.5, 5, 147);
//    cameraNode.position = SCNVector3Make(-5.5, 5, 200);
    cameraNode.camera.zFar = 500;
//    cameraNode.camera.focalLength = 0.0108268; // 3.3mm
    cameraNode.camera.xFov = 45.12;
    cameraNode.camera.yFov = 57.96;
    
    SCNNode *lightNode = [SCNNode node];
    lightNode.light = [SCNLight light];
    lightNode.light.type = SCNLightTypeOmni;
    lightNode.position = SCNVector3Make(100, 50, 30);
    [scene.rootNode addChildNode:lightNode];
    
    // create and add an ambient light to the scene
    SCNNode *ambientLightNode = [SCNNode node];
    ambientLightNode.light = [SCNLight light];
    ambientLightNode.light.type = SCNLightTypeAmbient;
    ambientLightNode.light.color = [UIColor darkGrayColor];
    ambientLightNode.light.intensity = 0.7;
    [scene.rootNode addChildNode:ambientLightNode];
    
    // Get the view and set our scene to it
    SCNView *scnView = (SCNView *)self.view;
    scnView.multipleTouchEnabled = YES;
    scnView.scene = scene;
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    // Create SpriteKit scene
    scene2d = [SKScene sceneWithSize:screenRect.size];
    scene2d.delegate = self;
    scnView.overlaySKScene = scene2d;
    scene2d.userInteractionEnabled = NO;
    
    [[NSBundle mainBundle] loadNibNamed:@"View" owner:self options: nil];
    self.viewFromNib.frame = screenRect;
    printf("w: %f, h: %f\n", screenRect.size.width, screenRect.size.height);
    self.viewFromNib.contentMode = UIViewContentModeScaleToFill;
    [scnView addSubview:self.viewFromNib];
    
    // Setup home button style
    self.homeBtn.layer.borderWidth = 1.5;
    self.homeBtn.imageEdgeInsets = UIEdgeInsetsMake(3, 3, 3, 3);
    self.homeBtn.layer.borderColor = [UIColor colorWithRed:0.08235 green:0.49412 blue:0.9843 alpha:1.0].CGColor;
    self.homeBtn.layer.cornerRadius = 5;
    
    // Setup instruction box style
    self.instructionBox.layer.borderWidth = 1.5;
    self.instructionBox.textContainerInset = UIEdgeInsetsMake(5, 5, 5, 5);
    [self setupInstructions];
    
    [self setupVisualizations];
    
    // Set load visibilities to the default values
    [self setVisibilities];
    [self.loadPresetBtn sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)update:(NSTimeInterval)currentTime forScene:(SKScene *)scene {
    peopleLoad.doUpdate();
    deadLoad.doUpdate();
    for (GrabbableArrow& rcnArrow : reactionArrows) {
        rcnArrow.doUpdate();
    }
}

- (void)setupVisualizations {
    SCNView *scnView = (SCNView*)self.view;
    float defaultThickness = 4;
    
    // Create live load bar
    peopleLoad = LoadMarker(3);
    peopleLoad.setInputRange(0, 1.5);
    peopleLoad.setMinHeight(15);
    peopleLoad.setMaxHeight(40);
    peopleLoad.setThickness(defaultThickness);
    peopleLoad.addAsChild(scene.rootNode);
    
    // Create dead load bar
    deadLoad = LoadMarker(7);
    deadLoad.setInputRange(0, 1.5);
    deadLoad.setLoad(1.2); // 1.2 k/ft
//    float dead_z = self.guided ? 
    deadLoad.setPosition(GLKVector3Make(COL1_POS, 22, 0), GLKVector3Make(COL4_POS, 24, 0));
    deadLoad.setMinHeight(15);
    deadLoad.setMaxHeight(25);
    deadLoad.setThickness(defaultThickness);
    deadLoad.addAsChild(scene.rootNode);
    
    reactionArrows.resize(4);
    reactionArrows[0].setPosition(GLKVector3Make(COL1_POS, 3, 0));
    reactionArrows[1].setPosition(GLKVector3Make(COL2_POS, 3, 0));
    reactionArrows[2].setPosition(GLKVector3Make(COL3_POS, 3, 0));
    reactionArrows[3].setPosition(GLKVector3Make(COL4_POS, 3, 0));
    for (int i = 0; i < reactionArrows.size(); ++i) {
        reactionArrows[i].addAsChild(scene.rootNode);
        reactionArrows[i].setFormatString(@"%.1f k");
        reactionArrows[i].setThickness(defaultThickness);
        reactionArrows[i].setMinLength(10);
        reactionArrows[i].setMaxLength(30);
        reactionArrows[i].setInputRange(0, 150);
        reactionArrows[i].setRotationAxisAngle(GLKVector4Make(0, 0, 1, 3.1416));
        reactionArrows[i].setScenes(scene2d, scnView);
    }
    
    people = PeopleVis(10, cameraNode);
    people.addAsChild(scene.rootNode);
    
    int resolution = 10;
    beamVals1.resize(2); beamVals2.resize(2); beamVals3.resize(2);
    double stepSize1 = (COL2_POS - COL1_POS) / (resolution - 1);
    double stepSize2 = (COL3_POS - COL2_POS) / (resolution - 1);
    double stepSize3 = (COL4_POS - COL3_POS) / (resolution - 1);
    for (int i = 0; i < resolution; ++i) {
        beamVals1[0].push_back(COL1_POS + stepSize1 * i);
        beamVals2[0].push_back(COL2_POS + stepSize2 * i);
        beamVals3[0].push_back(COL3_POS + stepSize3 * i);
        beamVals1[1].push_back(0);
        beamVals2[1].push_back(0);
        beamVals3[1].push_back(0);
    }
    beam1 = BezierLine(beamVals1);
    beam2 = BezierLine(beamVals2);
    beam3 = BezierLine(beamVals3);
    beam1.addAsChild(scene.rootNode);
    beam2.addAsChild(scene.rootNode);
    beam3.addAsChild(scene.rootNode);
    
    peopleLoad.setScenes(scene2d, scnView);
    deadLoad.setScenes(scene2d, scnView);
}

- (void)setupInstructions {
    if (self.guided) {
        instructions.push_back("Step 1");
        instructions.push_back("Step 2");
        instructions.push_back("Step 3");
        instructions.push_back("Step 4");
        instructions.push_back("Step 5");
        instructions.push_back("Step 6");
        curStep = 0;
        [self showInstruction:curStep];
    }
    else {
        self.instructionBox.hidden = YES;
        self.prevBtn.hidden = YES;
        self.nextBtn.hidden = YES;
    }
}

- (void)showInstruction:(int)curStep {
    self.instructionBox.text = [NSString stringWithCString:instructions[0].c_str() encoding:[NSString defaultCStringEncoding]];
}

- (IBAction)prevStepPressed:(id)sender {
    if (curStep < instructions.size() - 1) {
        curStep += 1;
        [self showInstruction:curStep];
        if (curStep == instructions.size() - 1) {
            
        }
    }
}

- (IBAction)nextStepPressed:(id)sender {
}
//- (void) handleTap:(UIGestureRecognizer*)gestureRecognize
//{
//    // retrieve the SCNView
//    SCNView *scnView = (SCNView *)self.view;
//    
//    // check what nodes are tapped
//    CGPoint p = [gestureRecognize locationInView:scnView];
//    NSArray *hitResults = [scnView hitTest:p options:nil];
//    
//    // check that we clicked on at least one object
//    if([hitResults count] > 0){
//        // retrieved the first clicked object
//        SCNHitTestResult *result = [hitResults objectAtIndex:0];
//        
//        // get its material
//        SCNMaterial *material = result.node.geometry.firstMaterial;
//        
//        // highlight it
//        [SCNTransaction begin];
//        [SCNTransaction setAnimationDuration:0.5];
//        
//        // on completion - unhighlight
//        [SCNTransaction setCompletionBlock:^{
//            [SCNTransaction begin];
//            [SCNTransaction setAnimationDuration:0.5];
//            
//            material.emission.contents = [UIColor blackColor];
//            
//            [SCNTransaction commit];
//        }];
//        
//        material.emission.contents = [UIColor redColor];
//        
//        [SCNTransaction commit];
//    }
//}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (IBAction)stepperChanged:(id)sender {
//    double new_value = self.stepperControl.value;
//    
////    GLKQuaternion movement = GLKQuaternionMakeWithAngleAndAxis(0.2, 0, 0, 1.0);
////    SCNQuaternion curOrientation = arrowNode.orientation;
////    GLKQuaternion curOrientationQuat = GLKQuaternionMake(curOrientation.x, curOrientation.y, curOrientation.z, curOrientation.w);
//    
////    GLKQuaternion newOrientation = GLKQuaternionMultiply(curOrientationQuat, movement);
//    subRotation = -new_value;
//    GLKQuaternion newOrientation = GLKQuaternionMakeWithAngleAndAxis(subRotation + baseRotation, 0, 0, 1.0);
//    
//    [SCNTransaction begin];
//    arrow.root.orientation = SCNVector4Make(newOrientation.x, newOrientation.y, newOrientation.z, newOrientation.w);
//    [SCNTransaction commit];
}

- (IBAction)sliderChanged:(id)sender {
//    double new_value = self.sliderControl.value;
//    arrow.setIntensity(new_value);
}

- (IBAction)posBtnPressed:(id)sender {
//    arrowTop = !arrowTop;
//    if (arrowTop) {
//        baseRotation = 0;
//        arrow.root.position = SCNVector3Make(0, 1, 0);
//    }
//    else {
//        baseRotation = 3.1415;
//        arrow.root.position = SCNVector3Make(0, -0.15, 0);
//    }
//    arrow.root.rotation = SCNVector4Make(0, 0, 1, subRotation + baseRotation);
}

- (IBAction)wideSwitchToggled:(id)sender {
//    arrow.setWide(self.toggleControl.on);
    
//    arrowWidthFactor = self.toggleControl.on ? 1.5 : 1.0;
    // Make scale change part of an animation
}

- (IBAction)colorChanged:(id)sender {
//    switch (self.colorSelector.selectedSegmentIndex) {
//        case 0:
//            self.topTitle.textColor = UIColor.redColor;
//            break;
//        case 1:
//            self.topTitle.textColor = UIColor.greenColor;
//            break;
//        case 2:
//            self.topTitle.textColor = UIColor.blueColor;
//            break;
//        default:
//            break;
//    }
}

- (IBAction)visSwitchToggled:(id)sender {
    [self setVisibilities];
}

- (void)setVisibilities {
    peopleLoad.setHidden(!self.liveLoadSwitch.on);
    deadLoad.setHidden(!self.deadLoadSwitch.on);
    for (int i = 0; i < reactionArrows.size(); ++i) {
        reactionArrows[i].setHidden(!self.rcnForceSwitch.on);
    }
}

- (IBAction)loadPresetSet:(id)sender {
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.5];
    const float top_posL = 22;
    const float top_posR = 24;
    activeScenario = self.loadPresetBtn.selectedSegmentIndex;

    switch (self.loadPresetBtn.selectedSegmentIndex) {
        case 0: // none
            peopleLoad.setPosition(GLKVector3Make(COL1_POS, top_posL, 0), GLKVector3Make(COL4_POS, top_posR, 0));
            peopleLoad.setLoad(0);
            people.setPosition(GLKVector3Make(COL1_POS, top_posL - 12, 0));
            people.setLength(COL4_POS - COL1_POS);
            people.setWeight(0);
            reactionArrows[0].setIntensity(17.644);
            reactionArrows[1].setIntensity(108.071);
            reactionArrows[2].setIntensity(103.97);
            reactionArrows[3].setIntensity(7.914);
            break;
        case 1: // uniform
            peopleLoad.setPosition(GLKVector3Make(COL1_POS, top_posL, 0), GLKVector3Make(COL4_POS, top_posR, 0));
            peopleLoad.setLoad(0.8);
            people.setPosition(GLKVector3Make(COL1_POS, top_posL - 12, 0));
            people.setLength(COL4_POS - COL1_POS);
            people.setWeight((COL4_POS - COL1_POS) * 0.8 * 1000);
            reactionArrows[0].setIntensity(29.407);
            reactionArrows[1].setIntensity(180.118);
            reactionArrows[2].setIntensity(173.284);
            reactionArrows[3].setIntensity(13.191);
            break;
        case 2: // left
            peopleLoad.setPosition(GLKVector3Make(COL1_POS, top_posL, 0), GLKVector3Make(COL2_POS, top_posL, 0));
            peopleLoad.setLoad(0.8);
            people.setPosition(GLKVector3Make(COL1_POS, top_posL - 12, 0));
            people.setLength(COL2_POS - COL1_POS);
            people.setWeight((COL2_POS - COL1_POS) * 0.8 * 1000);
            reactionArrows[0].setIntensity(37.441);
            reactionArrows[1].setIntensity(113.919);
            reactionArrows[2].setIntensity(101.376);
            reactionArrows[3].setIntensity(8.863);
            break;
        case 3: // right
            peopleLoad.setPosition(GLKVector3Make(COL3_POS, top_posR, 0), GLKVector3Make(COL4_POS, top_posR, 0));
            peopleLoad.setLoad(0.8);
            people.setPosition(GLKVector3Make(COL3_POS, top_posR - 12, 0));
            people.setLength(COL4_POS - COL3_POS);
            people.setWeight((COL4_POS - COL3_POS) * 0.8 * 1000);
            reactionArrows[0].setIntensity(18.033);
            reactionArrows[1].setIntensity(106.792);
            reactionArrows[2].setIntensity(123.978);
            reactionArrows[3].setIntensity(23.997);
            break;
        case SCENARIO_VARIABLE: // variable
//            peopleLoad.setPosition(GLKVector3Make(COL1_POS, top_posL, 0), GLKVector3Make(COL4_POS, top_posR, 0));
            break;
        default:
            break;
    }
    people.shuffle();
    [self updateBeamForces];
    [SCNTransaction commit];
}

- (IBAction)homeBtnPressed:(id)sender {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MainPageViewController *myNewVC = (MainPageViewController *)[storyboard instantiateViewControllerWithIdentifier:@"mainPage"];
    [self presentViewController:myNewVC animated:YES completion:nil];
}

// Touch handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // retrieve the SCNView
    SCNView *scnView = (SCNView *)self.view;
    
//    NSAssert(touches.count == 1, @"number of touches != 1");
    
    CGPoint p = [[touches anyObject] locationInView:scnView];
    // Use bounding boxes to increase the area that can be touched
    NSDictionary* hitOptions = @{
                                 SCNHitTestBoundingBoxOnlyKey: @YES
                                 };
    NSArray *hitResults = [scnView hitTest:p options:hitOptions];
//    for (SCNHitTestResult *hit in hitResults) {
//        const char* the_name = hit.node.name != nil ? [hit.node.name UTF8String] : "<unknown>";
//        printf("Hit node %s\n", the_name);
//    }
    
//    arrow.touchBegan(hitResults.firstObject);
//    if (activeScenario == SCENARIO_VARIABLE) {
    peopleLoad.touchBegan(SCNVector3ToGLKVector3(cameraNode.position), hitResults.firstObject);
//    }
    if (peopleLoad.draggingMode() != LoadMarker::none) {
        activeScenario = SCENARIO_VARIABLE;
        self.loadPresetBtn.selectedSegmentIndex = SCENARIO_VARIABLE;
    }
    return;
}


- (void)touchesMoved:(NSSet<UITouch *> *) touches withEvent:(UIEvent *)event {
    SCNView *scnView = (SCNView *)self.view;
    
//    NSAssert(touches.count == 1, @"number of touches != 1");
//    printf("%lu touches\n", touches.count);
    
    CGPoint p = [[touches anyObject] locationInView:scnView];
    GLKVector3 farClipHit = SCNVector3ToGLKVector3([scnView unprojectPoint:SCNVector3Make(p.x, p.y, 1.0)]);
    GLKVector3 cameraPos = SCNVector3ToGLKVector3(cameraNode.position);
    GLKVector3  touchRay = GLKVector3Normalize(GLKVector3Subtract(farClipHit, cameraPos));
    
    //GLKVector3 cameraDir = GLKVector3Make(cameraNode.transform.m13, cameraNode.transform.m23, cameraNode.transform.m33);
    
    
    if (activeScenario == SCENARIO_VARIABLE) {
        float dragValue = peopleLoad.getDragValue(cameraPos, touchRay);
        peopleLoad.setLoad(dragValue);
        std::pair<GLKVector3, GLKVector3> sideDragPosition = peopleLoad.getDragPosition(cameraPos, touchRay);
//        printf("drag pos: %f, %f\n", sideDragMovement.first, sideDragMovement.second);
        peopleLoad.setPosition(sideDragPosition.first, sideDragPosition.second);
        people.setPosition(GLKVector3Make(sideDragPosition.first.x, 10, 0));
        people.setLength(GLKVector3Length(GLKVector3Subtract(sideDragPosition.first, sideDragPosition.second)));
        [self updateBeamForces];
    }
//    self.sliderControl.value = dragValue;
}

- (void)touchesEnded:(NSSet<UITouch *> *) touches withEvent:(UIEvent *)event {
    if (activeScenario == SCENARIO_VARIABLE) {
        if (peopleLoad.draggingMode() != LoadMarker::none && peopleLoad.draggingMode() != LoadMarker::horizontally) {
            [SCNTransaction begin];
            [SCNTransaction setAnimationDuration:0.5];
            people.setWeight(1000 * peopleLoad.getLoad(0) * (peopleLoad.getEndPos().x - peopleLoad.getStartPos().x));
            people.shuffle();
            [SCNTransaction commit];
        }
        peopleLoad.touchEnded();
    }
}
- (void)touchesCancelled:(NSSet<UITouch *> *) touches withEvent:(UIEvent *)event {
    if (activeScenario == SCENARIO_VARIABLE) {
        peopleLoad.touchCancelled();
    }
}

- (void)updateBeamForces {
    // Beam 1
    float loadStart = peopleLoad.getStartPos().x;
    float loadEnd = peopleLoad.getEndPos().x;
    float load = peopleLoad.getLoad(0);
    
    // Reaction forces
    double beam1_rcn, beam2_rcn, beam3_rcn, beam4_rcn;
    beam1_rcn = beam2_rcn = beam3_rcn = beam4_rcn = 0;
    
    // Calculate
    [self calculateDeflection:beamVals1[1] forValues:beamVals1[0] rcnL:beam1_rcn rcnR:beam2_rcn beamStarts:COL1_POS beamEnds:COL2_POS loadStarts:loadStart loadEnds:loadEnd loadMagnitude:load];
    [self calculateDeflection:beamVals2[1] forValues:beamVals2[0] rcnL:beam2_rcn rcnR:beam3_rcn beamStarts:COL2_POS beamEnds:COL3_POS loadStarts:loadStart loadEnds:loadEnd loadMagnitude:load];
    [self calculateDeflection:beamVals3[1] forValues:beamVals3[0] rcnL:beam3_rcn rcnR:beam4_rcn beamStarts:COL3_POS beamEnds:COL4_POS loadStarts:loadStart loadEnds:loadEnd loadMagnitude:load];
    
    beam1.updatePath(beamVals1);
    beam2.updatePath(beamVals2);
    beam3.updatePath(beamVals3);
    reactionArrows[0].setIntensity(beam1_rcn);
    reactionArrows[1].setIntensity(beam2_rcn);
    reactionArrows[2].setIntensity(beam3_rcn);
    reactionArrows[3].setIntensity(beam4_rcn);
}

- (void)calculateDeflection:(std::vector<float>&)deflection forValues:(const std::vector<float>&)vals rcnL:(double&)rcnL rcnR:(double&)rcnR beamStarts:(double)beamStart beamEnds:(double)beamEnd loadStarts:(double)loadStart loadEnds:(double)loadEnd loadMagnitude:(double)totalLoad {
    assert(vals.size() == deflection.size());
    float magnification = 2;
    double L = beamEnd - beamStart;
    double a = std::max(0.0, loadStart - beamStart); // Don't let load extend beyond start of beam
    double b = std::min(loadEnd, beamEnd) - std::max(loadStart, beamStart); // Don't let load extend beyond end of beam
    double proportion = b / (loadEnd - loadStart); // Proportion of load on this beam
    double w = proportion * totalLoad;
    double L3 = L*L*L;
    for (int i = 0; i < vals.size(); ++i) {
        double x = vals[i] - beamStart;
        double x2 = x * x;
        double x3 = x * x * x;
        double delta;
        // Load isn't on beam at all. Dead load only
        if (b <= 0) {
            delta = -1.04758E-6 * 1.2 * x * (L3 - 2*L*x2 + x3);
        }
        else if (x < a) {
            delta = -1.04758E-6 *
                (
                    1.2 * x * (L3 - 2*L*x2 + x3) +
                    w * (
                         (x * b * (2*L-2*a - b) / L) *
                         (-2*x2 + 2*a*(2*L - a) + b*(2*L - 2*a - b))
                        )
                 );
        }
        else if (x <= a + b) {
            delta = -1.04758E-6 *
                (
                    1.2 * x * (L3 - 2*L*x2 + x3) +
                    w * (
                         std::pow(x-a, 4) +
                         (x * b * (2*L - 2*a - b) / L) *
                         (-2*x2 + 2*a*(2*L - a) + b*(2*L - 2*a - b))
                        )
                 );
        }
        else {
            delta = -1.04758E-6 *
                (
                    1.2 * x * (L3 - 2*L*x2 + x3) +
                    w * (
                         ((L-x) * b*(b + 2*a) / L) *
                         (
                           -2 * std::pow((L-x), 2) +
                           2 * (L - a - b) * (L + a + b) +
                           b * (b + 2*a)
                         )
                        )
                 );
        }
        deflection[i] = magnification * delta / 12;
    }
    
    if (b <= 0) {
        rcnL += 0.6*L;
        rcnR += 0.6*L;
    }
    else {
        rcnL += 0.6*L + w * b * (2*L - 2*a - b) / (2*L);
        rcnR += 0.6*L + w * b * (2*a + b) / (2*L);
    }
}

@end
