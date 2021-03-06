//
//  line3d.cpp
//  StructuralAnalysisAR
//
//  Created by David Wehr on 8/29/17.
//  Copyright © 2017 David Wehr. All rights reserved.
//

#include "line3d.h"

Line3d::Line3d(float hitBoxScale) {
    boxNode = [SCNNode nodeWithGeometry:[SCNCylinder cylinderWithRadius:0.5 height:1]];
    boxNode.pivot = SCNMatrix4Mult(SCNMatrix4MakeTranslation(0, 0, 0.5), SCNMatrix4MakeRotation(GLKMathDegreesToRadians(90), 1, 0, 0));
    
    hitBox = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:hitBoxScale height:hitBoxScale length:1 chamferRadius:0]];
    hitBox.pivot = SCNMatrix4MakeTranslation(0, 0, 0.5);
    // For some reason, in iOS 11, the search for hidden nodes flag is respected (hittest called in LoadMarker),
    // but in iOS 10, it doesn't work
    if (@available(iOS 11, *)) {
        hitBox.hidden = YES;
    }
    else {
        hitBox.opacity = 0;
        hitBox.geometry.firstMaterial.writesToDepthBuffer = NO;
    }

    // Containing node that the constraint will be applied to. If we didn't use this, the lookAt constraint would interfere with setting the scale
    boxContainer = [SCNNode node];
    [boxContainer addChildNode:boxNode];
    [boxContainer addChildNode:hitBox];
    
    // Node for setting the endpoint of the line
    boxLookAt = [SCNNode node];
    boxContainer.constraints = [NSArray arrayWithObject:[SCNLookAtConstraint lookAtConstraintWithTarget:boxLookAt]];
    
    // Make a material
    boxNode.geometry.firstMaterial = [SCNMaterial material];
    boxNode.geometry.firstMaterial.diffuse.contents = [UIColor redColor];
    
    setThickness(1);
}

void Line3d::addAsChild(SCNNode *scene) {
    [scene addChildNode:boxContainer];
    [scene addChildNode:boxLookAt];
}

void Line3d::setHidden(bool hidden) {
    boxContainer.hidden = hidden;
}

void Line3d::move(GLKVector3 start, GLKVector3 end) {
    // Move endpoints
    boxContainer.position = SCNVector3FromGLKVector3(start);
    // Put at the negative direction, since the lookAt constraint points the -z axis toward the target
    boxLookAt.position = SCNVector3Make(end.x, end.y, end.z);
    
    double distance = GLKVector3Length(GLKVector3Subtract(end, start));
    // Scale to the correct length
    boxNode.scale = SCNVector3Make(boxNode.scale.x, boxNode.scale.y, distance);
    hitBox.scale = SCNVector3Make(hitBox.scale.x, hitBox.scale.y, distance);
}

void Line3d::setColor(float r, float g, float b) {
    boxNode.geometry.firstMaterial.diffuse.contents = [UIColor colorWithRed:r green:g blue:b alpha:1];
}

void Line3d::setThickness(float thickness) {
    boxNode.scale = SCNVector3Make(thickness, thickness, boxNode.scale.z);
    hitBox.scale = SCNVector3Make(thickness, thickness, hitBox.scale.z);
}

bool Line3d::hasNode(SCNNode* node) {
    return node == hitBox || node == boxNode;
}
