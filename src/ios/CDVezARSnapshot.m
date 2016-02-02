/*
 * CDVezARSnapshot.m
 *
 * Copyright 2016, ezAR Technologies
 * http://ezartech.com
 *
 * By @wayne_parrott
 *
 * Licensed under a modified MIT license. 
 * Please see LICENSE or http://ezartech.com/ezarstartupkit-license for more information
 *
 */
 
#import "CDVezARSnapshot.h"
#import "MainViewController.h"

//NSString *const EZAR_ERROR_DOMAIN = @"EZAR_SNAPSHOT_ERROR_DOMAIN";
NSInteger const EZAR_SNAPSHOT_VIEW_TAG = 999;

#ifndef __CORDOVA_4_0_0
#import <Cordova/NSData+Base64.h>
#endif

//copied from cordova camera plugin
static NSString* toBase64(NSData* data) {
    SEL s1 = NSSelectorFromString(@"cdv_base64EncodedString");
    SEL s2 = NSSelectorFromString(@"base64EncodedString");
    SEL s3 = NSSelectorFromString(@"base64EncodedStringWithOptions:");
    
    if ([data respondsToSelector:s1]) {
        NSString* (*func)(id, SEL) = (void *)[data methodForSelector:s1];
        return func(data, s1);
    } else if ([data respondsToSelector:s2]) {
        NSString* (*func)(id, SEL) = (void *)[data methodForSelector:s2];
        return func(data, s2);
    } else if ([data respondsToSelector:s3]) {
        NSString* (*func)(id, SEL, NSUInteger) = (void *)[data methodForSelector:s3];
        return func(data, s3, 0);
    } else {
        return nil;
    }
}

@implementation CDVezARSnapshot
{
   
}


// INIT PLUGIN - does nothing atm
- (void) pluginInitialize
{
    [super pluginInitialize];
}

- (BOOL) isEZARAvailable
{
    return [self.viewController.view viewWithTag: EZAR_SNAPSHOT_VIEW_TAG] == nil;
}



- (AVCaptureSession *) getAVCaptureSession
{
    MainViewController *ctrl = (MainViewController *)self.viewController;
    CDVPlugin* ezarPlugin = [ctrl.pluginObjects objectForKey:@"CDVezAR"];
    
    if (!ezarPlugin) {
        return nil;
    }
    
    // Find AVCaptureSession
    NSString* methodName = @"getAVCaptureSession";
    SEL selector = NSSelectorFromString(methodName);
    AVCaptureSession* avCaptureSession = (AVCaptureSession *)[ezarPlugin performSelector:selector];
    
    
    return avCaptureSession;
}

- (UIImageView *) getCameraView
{
    UIImageView* cameraView = (UIImageView *)[self.viewController.view viewWithTag: EZAR_SNAPSHOT_VIEW_TAG];
    return cameraView;
}


//
//
//
- (void) snapshot:(CDVInvokedUrlCommand*)command
{
    // Find the ezAR CameraView
    UIImageView *cameraView = self.getCameraView;
    if (!cameraView) {
       [self snapshotViewHierarchy:nil cameraView:nil command:command];
        return;
    }
    
    // Find the current ezAR AVCaptureSession
    AVCaptureSession* captureSession = [self getAVCaptureSession];
    if (!captureSession || !captureSession.isRunning) {
        [self snapshotViewHierarchy:nil cameraView:nil command:command];
        return;
    }
 
    //configure to capture a video frame
    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [stillImageOutput setOutputSettings:outputSettings];
    [captureSession addOutput: stillImageOutput];
    
    //
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    //workaround for xxx
    //Capture video frame as image. The image will not include the webview content.
    //Temporarily set the cameraView image to the video frame (a jpg) long enough
    //to capture the entire view hierarcy as an image.
    //
    //NSLog(@"about to request a capture from: %@", stillImageOutput);
    [stillImageOutput captureStillImageAsynchronouslyFromConnection: videoConnection
                       completionHandler: ^(CMSampleBufferRef imageBuffer, NSError *error) {
                        
        [captureSession removeOutput: stillImageOutput];
                           
        if (error) {
            //fix me
            /*
            NSDictionary* errorResult = [self makeErrorResult: 1 withError: error];
                                                          
            CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                messageAsDictionary: errorResult];
                                                          
            return  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            */
        }
               
                                                      
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageBuffer];
        UIImage *cameraImage = [[UIImage alloc] initWithData:imageData];
                           
        //rotate image to match device orientation
        //UIDeviceOrientation devOrient = [[UIDevice currentDevice] orientation];
        /*
         switch (devOrient) {
            case UIDeviceOrientationLandscapeLeft:
                cameraImage = [UIImage imageWithCGImage: [cameraImage CGImage] scale:1.0 orientation:UIImageOrientationUp];
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                cameraImage = [UIImage imageWithCGImage: [cameraImage CGImage] scale:1.0 orientation:UIImageOrientationLeft];
                break;
            case UIDeviceOrientationLandscapeRight:
                cameraImage = [UIImage imageWithCGImage: [cameraImage CGImage] scale:1.0 orientation:UIImageOrientationDown];
                break;
            default:
                //portrait orient; do nothing
                break;
        }
         */
        
        switch (self.viewController.interfaceOrientation) {
            case UIInterfaceOrientationPortrait:
                cameraImage = [UIImage imageWithCGImage: [cameraImage CGImage] scale:1.0 orientation:UIImageOrientationRight];
                break;
            case UIInterfaceOrientationLandscapeLeft:
                cameraImage = [UIImage imageWithCGImage: [cameraImage CGImage] scale:1.0 orientation:UIImageOrientationDown];
                break;
            case UIInterfaceOrientationPortraitUpsideDown:
                cameraImage = [UIImage imageWithCGImage: [cameraImage CGImage] scale:1.0 orientation:UIImageOrientationLeft];
                break;
            case UIInterfaceOrientationLandscapeRight:
                cameraImage = [UIImage imageWithCGImage: [cameraImage CGImage] scale:1.0 orientation:UIImageOrientationUp];
                break;
            
        }
        
        [self snapshotViewHierarchy:cameraImage cameraView:cameraView command:command];
        
    }];
}


- (void) snapshotViewHierarchy:(UIImage*)cameraImage cameraView:(UIImageView*)cameraView command:(CDVInvokedUrlCommand*)command
{
    BOOL saveToPhotoAlbum = [[command argumentAtIndex:1 withDefault:@(NO)] boolValue];
    EZAR_IMAGE_ENCODING encodingType = [[command argumentAtIndex:0 withDefault:@(EZAR_IMAGE_ENCODING_JPG)] unsignedIntegerValue];
    
    saveToPhotoAlbum = YES;
    
    //assign the video frame image to the cameraView image
    if (cameraImage) {
        cameraView.image = cameraImage;
        cameraView.contentMode = UIViewContentModeScaleAspectFill;
    }
    
    //capture the entire view hierarchy
    UIView *view = self.viewController.view;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0);
    [view drawViewHierarchyInRect: view.bounds afterScreenUpdates: YES];
    UIImage* screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //clear camera view image
    if (cameraImage) {
        cameraView.image = nil;
    }
    
    if (saveToPhotoAlbum) { //save image to gallery
        //todo: handling error saving to photo gallery
        UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil);
    }
    
    //format image for return
    NSData *screenshotData = nil;
    if (encodingType == EZAR_IMAGE_ENCODING_JPG) {
        screenshotData = UIImageJPEGRepresentation(screenshot, 1.0);
    } else {
        screenshotData = UIImagePNGRepresentation(screenshot);
    }
    
    CDVPluginResult* pluginResult =
    [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:
     toBase64(screenshotData)];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}



- (void) snapshotxxxx:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: @"ALL OK"];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
