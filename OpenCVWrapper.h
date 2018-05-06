//
//  OpenCVWrapper.h
//  ProjectCampus
//
//  Created by Tiancheng Zhang on 4/5/18.
//  Copyright © 2018 Tiancheng Zhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OpenCVWrapper : NSObject

+ (NSString *)openCVVersionString;

+ (UIImage *)loadImageOfName: (NSString*)name andType: (NSString*)type;

+ (UIImage*)drawCircleOnCampusImage: (UIImage*)image atX: (CGFloat)x andY: (CGFloat)y withRadius: (CGFloat)r andColor: (UIColor*)c;

+ (UIImage*)drawPixelsOnCampusImage: (UIImage*)image atXs: (NSArray*)x andYs: (NSArray*)y withColor: (UIColor*)c;

+ (int)getTappedRegionFromImage: (UIImage*)image atX: (CGFloat)x andY: (CGFloat)y;

+ (NSString*)getPixelDescriptionFromImage:(UIImage*)image atX:(CGFloat)x andY:(CGFloat)y;

+ (NSDictionary *)getRegionPropsForIdx: (int)idx basedOnRegions: (UIImage*) region;

+ (UIImage*)drawRegionWithIdx: (int)idx basedOnRegionImage: (UIImage*)region usingImage: (UIImage*) campus;

+ (NSDictionary *)getRelativePropsUsingRegions:(UIImage*)region andNames:(NSDictionary*)names;

+ (NSMutableArray*)getAllPixelDescriptionsFromImage:(UIImage*)image;


@end
