//
//  MainPageViewController.m
//  StructuralAnalysisAR
//
//  Created by David Wehr on 8/28/17.
//  Copyright © 2017 David Wehr. All rights reserved.
//

#import "MainPageViewController.h"
#import "GameViewController.h"

#import "SkywalkScene.h"
#import "CampanileScene.h"

@interface MainPageViewController ()

@end

@implementation MainPageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set borders on the buttons
    CGColorRef textColor = [UIColor colorWithRed:0.08235 green:0.49412 blue:0.9843 alpha:1.0].CGColor;
    float borderWidth = 2;
    float cornerRadius = 8;
    self.btnSkywalk.layer.borderWidth = borderWidth;
    self.btnSkywalk.layer.cornerRadius = cornerRadius;
    self.btnSkywalk.layer.borderColor = textColor;
    
    self.btnWaterTower.layer.borderWidth = borderWidth;
    self.btnWaterTower.layer.cornerRadius = cornerRadius;
    self.btnWaterTower.layer.borderColor = textColor;
    
    self.btnCampanile.layer.borderWidth = borderWidth;
    self.btnCampanile.layer.cornerRadius = cornerRadius;
    self.btnCampanile.layer.borderColor = textColor;
    
    // Load the property list for button visibility
    // Find out the path
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    self.prefs_path = [rootPath stringByAppendingPathComponent:@"user_prefs.plist"];
    //self.prefs_path = [[NSBundle mainBundle] pathForResource:@"user_prefs" ofType:@"plist"];
    
    // Load the file content and read the data into arrays
    NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:self.prefs_path];

    NSNumber* skywalk_hidden = [dict valueForKey:@"skywalk_hidden"];
    NSNumber* skywalk_guided_hidden = [dict valueForKey:@"skywalk_guided_hidden"];
    if (skywalk_hidden == skywalk_guided_hidden) {
        // Failed to load. Probably hasn't been saved before. Set manually
        skywalk_hidden = [NSNumber numberWithBool:NO];
        skywalk_guided_hidden = [NSNumber numberWithBool:YES];
    }
    self.btnSkywalk.hidden = [skywalk_hidden boolValue];
    self.btnWaterTower.hidden = [skywalk_guided_hidden boolValue];
    
    // Test
//    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(doSegue:) userInfo:nil repeats:NO];
}

- (void) doSegue:(NSTimer*) timer {
    [self.btnCampanile sendActionsForControlEvents:UIControlEventTouchUpInside];
//    [self.btnSkywalk sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    if ([segue.identifier isEqualToString:@"skywalkGuidedSegue"]) {
        GameViewController* viewController = (GameViewController*) [segue destinationViewController];
        viewController.sceneClass = SkywalkScene.class;
        viewController.guided = true;
    }
    else if ([segue.identifier isEqualToString:@"skywalkSegue"]) {
        GameViewController* viewController = (GameViewController*) [segue destinationViewController];
        viewController.sceneClass = SkywalkScene.class;
        viewController.guided = false;
    }
    else if ([segue.identifier isEqualToString:@"campanileSegue"]) {
        GameViewController* viewController = (GameViewController*) [segue destinationViewController];
        viewController.sceneClass = CampanileScene.class;
    }
    // Pass the selected object to the new view controller.
}

- (IBAction)backToHomepage:(UIStoryboardSegue*)unwindSegue {
    // Do things here?
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (IBAction)secretPress:(id)sender {
    [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(timeUp:) userInfo:nil repeats:NO];
}

- (void) timeUp:(NSTimer*) timer {
    if (self.superSecretButton.state == UIControlStateHighlighted) {
        self.btnSkywalk.hidden = !self.btnSkywalk.hidden;
        self.btnWaterTower.hidden = !self.btnWaterTower.hidden;
        
        // Save changes to user_prefs.plist

        NSError *error;
        NSDictionary *plistDict = @{
                                    @"skywalk_hidden": [NSNumber numberWithBool:self.btnSkywalk.hidden],
                                    @"skywalk_guided_hidden": [NSNumber numberWithBool:self.btnWaterTower.hidden]
                                    };

        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:plistDict
                                                          format:NSPropertyListXMLFormat_v1_0
                                                          options:0
                                                          error:&error];
        
        if(plistData) {
            bool write_successful = [plistData writeToFile:self.prefs_path atomically:YES];
            if (!write_successful) {
                printf("failed to write prefs\n");
            }
        }
        
        else {
            printf("aahhh!, error saving prefs!\n");
        }
    }

}

@end
