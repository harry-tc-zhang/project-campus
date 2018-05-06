//
//  OpenCVUtils.h
//  ProjectCampus
//
//  Created by Tiancheng Zhang on 4/5/18.
//  Copyright © 2018 Tiancheng Zhang. All rights reserved.
//

// For helper functions that requires input of OpenCV types, which cannot appear in the wrapper.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <opencv2/opencv.hpp>
#import <vector>
#import <map>

@interface OpenCVUtils : NSObject

@property std::map<NSString*, std::vector<cv::Point> > regionContours;

+ (cv::Mat)cvMatFromUIImage:(UIImage *)image convertColor:(Boolean)cvt;

+ (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat;

- (void)getAllContoursFromRegionMat:(cv::Mat)regionMat;

+ (cv::Mat)drawCircleOnMat:(cv::Mat)target atX:(CGFloat)x andY:(CGFloat)y withRadius:(CGFloat)r andColor:(UIColor *)c;

+ (cv::Mat)drawPixelOnMat:(cv::Mat)target atXs:(NSArray*)x andYs:(NSArray*)y withColor:(UIColor *)c;

+ (double)pointsDistanceBtwP:(cv::Point)p1 andP:(cv::Point)p2;

+ (bool)momentsAreClose:(cv::Moments)m1 n:(cv::Moments)m2;

+ (NSString*)checkContourSymmetry:(std::vector<cv::Point>)contour;

+ (NSString*)checkContour:(std::vector<cv::Point>)contour;

+ (NSString*)checkContour:(std::vector<cv::Point>)contour isOnBoundary:(cv::Rect)boundary;

+ (NSString*)checkContour:(std::vector<cv::Point>)contour isInQuadrant:(cv::Rect)boundary;

+ (NSString*)checkContourLetterShape:(std::vector<cv::Point>)contour;

+ (NSString*)checkContourSize:(std::vector<cv::Point>)contour;

+ (NSString*)checkContourRatio:(std::vector<cv::Point>)contour;

+ (NSDictionary*)getPropsOfRegionWithIdx:(int)idx fromMat:(cv::Mat)regionMat;

+ (bool)building:(std::vector<cv::Point>)A isEastOfBuilding:(std::vector<cv::Point>)B;

+ (bool)building:(std::vector<cv::Point>)A isWestOfBuilding:(std::vector<cv::Point>)B;

+ (bool)building:(std::vector<cv::Point>)A isNorthOfBuilding:(std::vector<cv::Point>)B;

+ (bool)building:(std::vector<cv::Point>)A isSouthOfBuilding:(std::vector<cv::Point>)B;

+ (bool)building:(std::vector<cv::Point>)A isNearBuilding:(std::vector<cv::Point>)B;

+ (NSDictionary*)getPairsOfInterestFromRegionMat:(cv::Mat)regionMat usingNames:(NSDictionary*)names;

+ (std::vector<std::vector<std::vector<NSString*> > >)getDescriptionOfAllPixelsUsingRegionMat:(cv::Mat)regionMat;

+ (std::vector<std::vector<NSString*> >)getTappedRegionsAtLocationX:(int)x andY:(int)y UsingRegionMat:(cv::Mat)regionMat;

+ (UIImage*)drawRegionWithIdx:(int)idx basedOnMat:(cv::Mat)regionMat usingMat:(cv::Mat)campusMat;

@end
