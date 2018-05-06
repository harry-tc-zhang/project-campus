//
//  OpenCVWrapper.m
//  ProjectCampus
//
//  Created by Tiancheng Zhang on 4/5/18.
//  Copyright © 2018 Tiancheng Zhang. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import <UIKit/UIKit.h>
#import <vector>
#import <map>

#import "OpenCVWrapper.h"
#import "OpenCVUtils.h"

using namespace cv;
using namespace std;

@implementation OpenCVWrapper

+ (NSString *)openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

+ (UIImage *)loadImageOfName: (NSString*)name andType: (NSString*)type {
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"mainBundle" ofType:@"bundle"];
    NSString *imageName = [[NSBundle bundleWithPath:bundlePath] pathForResource:name ofType:type];
    UIImage *campusImage = [[UIImage alloc] initWithContentsOfFile:imageName];
    //return [OpenCVUtils UIImageFromCVMat:[OpenCVUtils cvMatFromUIImage:campusImage]];
    return campusImage;
}

+ (UIImage*)drawCircleOnCampusImage: (UIImage*)image atX: (CGFloat)x andY: (CGFloat)y withRadius: (CGFloat)r andColor: (UIColor*)c {
    Mat campusMat = [OpenCVUtils cvMatFromUIImage:image convertColor:true];
    Mat circledCampus = [OpenCVUtils drawCircleOnMat:campusMat atX:x andY:y withRadius:r andColor:c];
    return [OpenCVUtils UIImageFromCVMat:circledCampus];
}

+ (UIImage*)drawPixelsOnCampusImage: (UIImage*)image atXs: (NSArray*)x andYs: (NSArray*)y withColor: (UIColor*)c {
    Mat campusMat = [OpenCVUtils cvMatFromUIImage:image convertColor:true];
    Mat paintedMat = [OpenCVUtils drawPixelOnMat:campusMat atXs:x andYs:y withColor:c];
    return [OpenCVUtils UIImageFromCVMat:paintedMat];
}

+ (int)getTappedRegionFromImage: (UIImage*)image atX: (CGFloat)x andY: (CGFloat)y{
    Mat regionMat = [OpenCVUtils cvMatFromUIImage:image convertColor:false];
    NSLog(@"%f, %f", x, y);
    vector<vector<NSString*> > descriptors = [OpenCVUtils getTappedRegionsAtLocationX:x andY:y UsingRegionMat:regionMat];
    for(int i = 0; i < descriptors.size(); i ++) {
        NSLog(@"Descriptor: %@, %@, %@", descriptors[i][0], descriptors[i][1], descriptors[i][2]);
    }
    int regionIdx = [[NSNumber numberWithUnsignedChar:regionMat.at<char>(y, x)] intValue];
    return regionIdx;
}

+ (NSString*)getPixelDescriptionFromImage:(UIImage*)image atX:(CGFloat)x andY:(CGFloat)y {
    Mat regionMat = [OpenCVUtils cvMatFromUIImage:image convertColor:false];
    vector<vector<NSString*> > descriptors = [OpenCVUtils getTappedRegionsAtLocationX:x andY:y UsingRegionMat:regionMat];
    NSMutableString* retStr = [NSMutableString string];
    for(int i = 0; i < descriptors.size(); i ++) {
        [retStr appendString:[NSString stringWithFormat:@"%@, %@, %@", descriptors[i][0], descriptors[i][1], descriptors[i][2]]];
    }
    return retStr;
}

+ (NSMutableArray*)getAllPixelDescriptionsFromImage:(UIImage*)image {
    NSMutableArray* ret = [NSMutableArray array];
    Mat regionMat = [OpenCVUtils cvMatFromUIImage:image convertColor:false];
    vector<vector<vector<NSString*> > > results = [OpenCVUtils getDescriptionOfAllPixelsUsingRegionMat:regionMat];
    for(int i = 0; i < results.size(); i ++) {
        NSMutableString* retStr = [NSMutableString string];
        for(int j = 0; j < results[i].size(); j ++) {
            if(j > 0) {
                [retStr appendString:@"|"];
            }
            [retStr appendString:[NSString stringWithFormat:@"%@-%@-%@", results[i][j][0], results[i][j][1], results[i][j][2]]];
        }
        [ret addObject:retStr];
    }
    return ret;
}

+ (NSDictionary *)getRegionPropsForIdx: (int)idx basedOnRegions: (UIImage*) region {
    return [OpenCVUtils getPropsOfRegionWithIdx:idx fromMat:[OpenCVUtils cvMatFromUIImage:region convertColor:false]];
}

+ (NSDictionary *)getRelativePropsUsingRegions:(UIImage*)region andNames:(NSDictionary*)names {
    return [OpenCVUtils getPairsOfInterestFromRegionMat:[OpenCVUtils cvMatFromUIImage:region convertColor:false] usingNames:names];
}

+ (UIImage*)drawRegionWithIdx: (int)idx basedOnRegionImage: (UIImage*)region usingImage: (UIImage*) campus{
    //[OpenCVUtils getAllContoursFromRegionMat:[OpenCVUtils cvMatFromUIImage:region convertColor:false]];
    return [OpenCVUtils drawRegionWithIdx:idx basedOnMat:[OpenCVUtils cvMatFromUIImage:region convertColor:false] usingMat:[OpenCVUtils cvMatFromUIImage:campus convertColor:true]];
}

@end
