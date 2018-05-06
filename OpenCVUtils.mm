//
//  OpenCVUtils.m
//  ProjectCampus
//
//  Created by Tiancheng Zhang on 4/5/18.
//  Copyright © 2018 Tiancheng Zhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/opencv.hpp>
#import <vector>
#import <map>
#import <cmath>
#import "OpenCVUtils.h"

using namespace cv;
using namespace std;

@implementation OpenCVUtils

// Function lifted from https://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c
+ (cv::Mat)cvMatFromUIImage:(UIImage *)image convertColor:(Boolean)cvt
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    size_t numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault;
    
    // check whether the UIImage is greyscale already
    if (numberOfComponents == 1){
        cvMat = cv::Mat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    }
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,             // Pointer to backing data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    bitmapInfo);              // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    if(numberOfComponents == 1) {
        if(cvt) {
            Mat colorMat(rows, cols, CV_8UC4);
            cvtColor(cvMat, colorMat, CV_GRAY2BGR);
            return colorMat;
        }
    }
    
    return cvMat;
}

// Function lifted from https://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c
+(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat {
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(
                                        cvMat.cols,                 //width
                                        cvMat.rows,                 //height
                                        8,                          //bits per component
                                        8 * cvMat.elemSize(),       //bits per pixel
                                        cvMat.step[0],              //bytesPerRow
                                        colorSpace,                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                   //CGDataProviderRef
                                        NULL,                       //decode
                                        false,                      //should interpolate
                                        kCGRenderingIntentDefault   //intent
                                        );
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

-(void)getAllContoursFromRegionMat:(cv::Mat)regionMat {
    vector<int> regionIndices;
    int rows = regionMat.rows;
    int cols = regionMat.cols;
    for(int i = 0; i < rows; i ++) {
        for(int j = 0; j < cols; j ++) {
            int pixelVal = [[NSNumber numberWithUnsignedChar:regionMat.at<char>(i, j)] intValue];
            if(pixelVal > 0) {
                if(std::find(regionIndices.begin(), regionIndices.end(), pixelVal) == regionIndices.end()) {
                    regionIndices.push_back(pixelVal);
                }
            }
        }
    }
    /*
    for(int i = 0; i < regionIndices.size(); i ++) {
        NSLog(@"%d", regionIndices[i]);
    }
    */
    map<NSString*, vector<cv::Point> > tmpContours;
    for(int ii = 0; ii < regionIndices.size(); ii ++) {
        int idx = regionIndices[ii];
        Mat filledMat(regionMat);
        for(int i = 0; i < rows; i ++) {
            for(int j = 0; j < cols; j ++) {
                if([[NSNumber numberWithUnsignedChar:filledMat.at<char>(i, j)] intValue] == idx) {
                    filledMat.at<char>(i, j) = (char)128;
                } else {
                    filledMat.at<char>(i, j) = (char)0;
                }
            }
        }
        
        // Find the largest contour, which should be our building
        vector<vector<cv::Point> > contours;
        vector<Vec4i> hierarchy;
        findContours(filledMat, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE);
        double maxContourArea = 0;
        double maxContourIdx = -1;
        for(int i = 0; i < contours.size(); i ++) {
            double cArea = contourArea(contours[i]);
            if(cArea > maxContourArea) {
                maxContourIdx = i;
                maxContourArea = cArea;
            }
        }
        tmpContours[[[NSNumber numberWithInt:idx] stringValue]] = contours[maxContourIdx];
    }
    
    _regionContours = tmpContours;
}

+(cv::Mat)drawCircleOnMat:(cv::Mat)target atX:(CGFloat)x andY:(CGFloat)y withRadius:(CGFloat)r andColor:(UIColor *)c {
    CGFloat red,green,blue,alpha;
    [c getRed:&red green:&green blue:&blue alpha:&alpha];
    circle(target, cv::Point(x, y), r, Scalar(int(red * 255.0), int(green * 255.0), int(blue * 255.0), int(alpha * 255.0)), CV_FILLED, CV_AA);
    return target;
}

+ (cv::Mat)drawPixelOnMat:(cv::Mat)target atXs:(NSArray*)x andYs:(NSArray*)y withColor:(UIColor *)c {
    CGFloat red,green,blue,alpha;
    [c getRed:&red green:&green blue:&blue alpha:&alpha];
    cv::Mat retMat = target.clone();
    //cv::Scalar color(int(red * 255.0), int(green * 255.0), int(blue * 255.0), int(alpha * 255.0));
    for(int i = 0; i < x.count; i ++) {
        Vec3b color = retMat.at<Vec3b>(cv::Point([x[i] intValue], [y[i] intValue]));
        color[0] = int(red * 255.0);
        color[1] = int(green * 255.0);
        color[2] = int(blue * 255.0);
        retMat.at<Vec3b>(cv::Point([x[i] intValue], [y[i] intValue])) = color;
    }
    return retMat;
}

+(double)pointsDistanceBtwP:(cv::Point)p1 andP:(cv::Point)p2 {
    return sqrt(double((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y)));
}

+(NSString*)checkContour:(vector<cv::Point>)contour {
    // Magic numbers: contour detection related
    float TINY_THRESHOLD = 5;
    int VALIGN_THRESHOLD = 2;
    
    int nonRightAngleCount = 0;
    int tinyAngleCount = 0;
    for (int i = 0; i < contour.size(); i ++) {
        int prev = i > 0 ? (i - 1) : (int(contour.size()) - 1);
        int next = i < (int(contour.size()) - 1) ? (i + 1) : 0;
        bool isRightAngle = false;
        if((abs(contour[next].x - contour[i].x) < VALIGN_THRESHOLD) and (abs(contour[prev].y - contour[i].y) < VALIGN_THRESHOLD)) {
            isRightAngle = true;
        } else if((abs(contour[prev].x - contour[i].x) < VALIGN_THRESHOLD) and (abs(contour[next].y - contour[i].y) < VALIGN_THRESHOLD)) {
            isRightAngle = true;
        }
        if(!isRightAngle) {
            nonRightAngleCount += 1;
        }
        
        if([OpenCVUtils pointsDistanceBtwP:contour[prev] andP:contour[next]] < TINY_THRESHOLD) {
            tinyAngleCount += 1;
        }
    }
    if((nonRightAngleCount > 0) and (tinyAngleCount > 10)) {
        return @"has curved sides";
    } else if ((nonRightAngleCount > 0) and (tinyAngleCount < 5)) {
        return @"has slanted straight edges";
    }
    return @"only has horizontal and vertical straight edges";
}

+(bool)momentsAreClose:(Moments)m1 n:(Moments)m2 {
    double LOWER = 0.9;
    double UPPER = 1.1;
    if(!((m1.m00 + 0.01) / (m2.m00 + 0.01) > LOWER) and (m1.m00 + 0.01) / (m2.m00 + 0.01) < UPPER) {
        return false;
    }
    if(!((m1.m10 + 0.01) / (m2.m10 + 0.01) > LOWER) and (m1.m10 + 0.01) / (m2.m10 + 0.01) < UPPER) {
        return false;
    }
    if(!((m1.m01 + 0.01) / (m2.m01 + 0.01) > LOWER) and (m1.m01 + 0.01) / (m2.m01 + 0.01) < UPPER) {
        return false;
    }
    return true;
}

+(NSString*)checkContourSymmetry:(vector<cv::Point>)contour {
    // Checks whether a building's shape is symmetic on horizontal and vertical axes
    
    float MATCH_THRESHOLD = 0.55;
    
    bool xSymm = false;
    bool ySymm = false;
    
    NSMutableString* retStr = [NSMutableString string];
    
    // The vertical axis
    int xMin = 10000000;
    int xMax = 0;
    for(int i = 0; i < contour.size(); i ++) {
        if(contour[i].x < xMin) {
            xMin = contour[i].x;
        }
        if(contour[i].x > xMax) {
            xMax = contour[i].x;
        }
    }
    float xMidPoint = float(xMin + xMax) / 2.0;
    vector<cv::Point> leftPoints;
    vector<cv::Point> rightPoints;
    for(int i = 0; i < contour.size(); i ++) {
        if(float(contour[i].x) <= xMidPoint) {
            leftPoints.push_back(contour[i]);
        }
        if(float(contour[i].x) >= xMidPoint) {
            rightPoints.push_back(contour[i]);
        }
    }
    //NSLog(@"Left Points: %d", leftPoints.size());
    //NSLog(@"Right Points: %d", rightPoints.size());
    //[retStr appendString:[[NSNumber numberWithDouble:matchShapes(leftPoints, rightPoints, CV_CONTOURS_MATCH_I2, 0)] stringValue]];
    xSymm = (matchShapes(leftPoints, rightPoints, CV_CONTOURS_MATCH_I2, 0) < MATCH_THRESHOLD);
    
    int yMin = 10000000;
    int yMax = 0;
    for(int i = 0; i < contour.size(); i ++) {
        if(contour[i].y < yMin) {
            yMin = contour[i].y;
        }
        if(contour[i].y > yMax) {
            yMax = contour[i].y;
        }
    }
    float yMidPoint = float(yMin + yMax) / 2.0;
    vector<cv::Point> topPoints;
    vector<cv::Point> bottomPoints;
    for(int i = 0; i < contour.size(); i ++) {
        if(float(contour[i].y) <= yMidPoint) {
            topPoints.push_back(contour[i]);
        }
        if(float(contour[i].y) >= yMidPoint) {
            bottomPoints.push_back(contour[i]);
        }
    }
    //[retStr appendString:@" "];
    //[retStr appendString:[[NSNumber numberWithDouble:matchShapes(topPoints, bottomPoints, CV_CONTOURS_MATCH_I2, 0)] stringValue]];
    ySymm = (matchShapes(topPoints, bottomPoints, CV_CONTOURS_MATCH_I2, 0) < MATCH_THRESHOLD);
    
    if(xSymm and ySymm) {
        return @"symmetrical on horizontal and vertical axis";
    } else if(xSymm) {
        return @"symmetrical on the vertical axis";
    } else if(ySymm) {
        return @"symmetrical on the horizontal axis";
    }
    return @"not symmetrical on horizontal or vertical axis";
}

+(NSString*)checkContour:(vector<cv::Point>)contour isOnBoundary:(cv::Rect)boundary {
    int CLOSENESS_THRESHOLD = 10;
    cv::Rect contourRect = boundingRect(contour);
    bool westClose = (abs(contourRect.x - boundary.x) < CLOSENESS_THRESHOLD);
    bool eastClose = (abs(contourRect.x + contourRect.width - boundary.x - boundary.width) < CLOSENESS_THRESHOLD);
    bool northClose = (abs(contourRect.y - boundary.y) < CLOSENESS_THRESHOLD);
    bool southClose = (abs(contourRect.y + contourRect.height - boundary.y - boundary.height) < CLOSENESS_THRESHOLD);
    if(westClose and eastClose) {
        return @"cuts horizontally across campus";
    } else if (northClose and southClose) {
        return @"cuts vertically across campus";
    } else if(westClose and southClose) {
        return @"sits at the south-western corner of the campus";
    } else if(westClose and northClose) {
        return @"sits at the north-western corner of the campus";
    } else if(eastClose and southClose) {
        return @"sits at the south-eastern corner of the campus";
    } else if(eastClose and northClose) {
        return @"sits at the north-eastern corner of the campus";
    } else if(westClose) {
        return @"sits on the western edge of the campus";
    } else if(eastClose) {
        return @"sits on the eastern edge of the campus";
    } else if(northClose) {
        return @"sits on the northern edge of the campus";
    } else if(southClose) {
        return @"sits on the southern edge of the campus";
    }
    return @"is not near the edges of the campus";
}

+(NSString*)checkContour:(vector<cv::Point>)contour isInQuadrant:(cv::Rect)boundary {
    float BEGIN = 0.4;
    float END = 0.6;
    
    // The center of the bounding box is used here, rather than the centroid.
    // It is more intuitive to understand for the buildings.
    cv::Rect contourBounds = boundingRect(contour);
    int fakeCX = contourBounds.x + contourBounds.width / 2;
    int fakeCY = contourBounds.y + contourBounds.height / 2;
    float cXPct = (float)fakeCX / float(boundary.width);
    float cYPct = (float)fakeCY / float(boundary.height);
    if(cXPct < BEGIN) {
        if(cYPct < BEGIN) {
            return @"on the north-western side of the campus";
        } else if(cYPct < END) {
            return @"in the middle on the western side of the campus";
        } else {
            return @"on the south-western side of the campus";
        }
    } else if (cXPct < END) {
        if(cYPct < BEGIN) {
            return @"in the middle on the northern side of the campus";
        } else if (cYPct < END) {
            return @"roughly in the middle of the campus";
        } else {
            return @"in the middle on the southern side of the campus";
        }
    } else {
        if(cYPct < BEGIN) {
            return @"on the north-eastern side of the campus";
        } else if(cYPct < END) {
            return @"in the middle on the eastern side of the campus";
        } else {
            return @"on the south-eastern side of the campus";
        }
    }
    return @"";
}

+ (NSString*)checkContourLetterShape:(vector<cv::Point>)contour {
    // - shape (C/L/I) magic numbers
    int CL_CLOSENESS_THRESHOLD = 10;
    float CL_RATIO_THRESHOLD = 0.6;
    int I_PARALLEL_THRESHOLD = 5;
    
    // How much the contour fills the bounding box, for L/C description
    double maxContourArea = contourArea(contour);
    cv::Rect contourBound = boundingRect(contour);
    float fillRatio = float(maxContourArea) / float(contourBound.width * contourBound.height);
    //NSLog(@"Fill ratio is %f", fillRatio);
    
    // Convexity defects, for L/C/I-shaped buildings
    vector<int> hull;
    convexHull(contour, hull, false, false);
    vector<cv::Point> hullPoints;
    for(int i = 0; i < hull.size(); i ++) {
        hullPoints.push_back(contour[hull[i]]);
    }
    //NSLog(@"Hull area is %f", contourArea(hullPoints));
    vector<Vec4i> defects;
    convexityDefects(contour, hull, defects);
    int maxDefectIdx = -1;
    double maxDefectSize = 0;
    int secondDefectIdx = -1;
    double secondDefectSize = 0;
    for(int i = 0; i < defects.size(); i ++) {
        double defectSize = [OpenCVUtils pointsDistanceBtwP:contour[defects[i][0]] andP:contour[defects[i][1]]] * defects[i][3] / 256.0;
        if(defectSize > maxDefectSize) {
            secondDefectIdx = maxDefectIdx;
            secondDefectSize = maxDefectSize;
            maxDefectIdx = i;
            maxDefectSize = defectSize;
        } else if(defectSize > secondDefectSize) {
            secondDefectIdx = i;
            secondDefectSize = defectSize;
        }
    }
    //NSLog(@"Max defect area is %f", maxDefectSize);
    if(maxDefectIdx > -1) {
        vector<cv::Point> defectContour;
        for(int i = 0; i < 3; i ++) {
            defectContour.push_back(contour[defects[maxDefectIdx][i]]);
        }
        cv::Rect maxDefectBounds = boundingRect(defectContour);
        //NSLog(@"Building's bounding rect is (%d, %d) to (%d, %d).", contourBound.x, contourBound.y, contourBound.x + contourBound.width, contourBound.y + contourBound.height);
        //NSLog(@"Max defect's bounding rect is (%d, %d) to (%d, %d).", maxDefectBounds.x, maxDefectBounds.y, maxDefectBounds.x + maxDefectBounds.width, maxDefectBounds.y + maxDefectBounds.height);
        
        if(fillRatio < CL_RATIO_THRESHOLD) {
            // Get whether building is L or C shaped based on
            // fillRatio and the "slantedness" of the defect's hull edge.
            int xDistance = abs(defectContour[0].x - defectContour[1].x);
            int yDistance = abs(defectContour[0].y - defectContour[1].y);
            if((xDistance < CL_CLOSENESS_THRESHOLD) || (yDistance < CL_CLOSENESS_THRESHOLD)) {
                return @"C-shaped";
            } else {
                return @"L-shaped";
            }
        } else {
            // Otherwise, check if building is I-shaped based on the bounding boxes of the two largest defects
            if(secondDefectIdx > -1) {
                vector<cv::Point> secondDefectContour;
                for(int i = 0; i < 3; i ++) {
                    secondDefectContour.push_back(contour[defects[secondDefectIdx][i]]);
                }
                cv::Rect defectBound = boundingRect(defectContour);
                cv::Rect secondDefectBound = boundingRect(secondDefectContour);
                if(abs(defectBound.x - secondDefectBound.x) < I_PARALLEL_THRESHOLD) {
                    // If the two bounding boxes are aligned in the y direction
                    if(abs(defectBound.width - secondDefectBound.width) < I_PARALLEL_THRESHOLD) {
                        // and they have similar width
                        if(abs(contourBound.x + 0.5 * contourBound.width - defectBound.x - 0.5 * defectBound.width) < I_PARALLEL_THRESHOLD) {
                            // and are at roughly halfway of the building in that direction, then consider it I-shaped
                            return @"I-shaped";
                        }
                    }
                } else if(abs(defectBound.y - secondDefectBound.y) < I_PARALLEL_THRESHOLD) {
                    // Likewise for the other orientation (thankfully, there are no slanted buildings)
                    if(abs(defectBound.height - secondDefectBound.height) < I_PARALLEL_THRESHOLD) {
                        if(abs(contourBound.y + 0.5 * contourBound.height - defectBound.y - 0.5 * defectBound.height) < I_PARALLEL_THRESHOLD) {
                            return @"I-shaped";
                        }
                    }
                }
            } else {
                int xDistance = abs(defectContour[0].x - defectContour[1].x);
                int yDistance = abs(defectContour[0].y - defectContour[1].y);
                if((xDistance < CL_CLOSENESS_THRESHOLD) || (yDistance < CL_CLOSENESS_THRESHOLD)) {
                    return @"gentally C-shaped";
                }
            }
        }
    }
    return @"not letter-shaped";
}

+ (NSString*)checkContourSize:(vector<cv::Point>)contour {
    // - size magic numbers
    int LARGE_THRESHOLD = 4000;
    int MEDIUM_THRESHOLD = 2000;
    int SMALL_THRESHOLD = 500;
    
    // Area of the contour, for size
    double maxContourArea = contourArea(contour);
    if(maxContourArea > LARGE_THRESHOLD) {
        return @"large";
    } else if(maxContourArea > MEDIUM_THRESHOLD) {
        return @"medium";
    } else if(maxContourArea > SMALL_THRESHOLD) {
        return @"small";
    }
    return @"tiny";
}

+ (NSString*)checkContourRatio:(vector<cv::Point>)contour {
    // - square/rectangular magic numbers
    float SQUARE_THRESHOLD = 1.2;
    float LONG_THRESHOLD = 1.8;
    
    // Bouding rect for contour, for sqare/rectangular etc. and long/short
    cv::Rect contourBound = boundingRect(contour);
    double aspectRatio = (float)contourBound.width / (float)contourBound.height;
    //NSLog(@"Contour aspect ratio: %f", aspectRatio);
    // Make it larger than one to judge shape
    double flippedRatio = aspectRatio > 1 ? aspectRatio : (1.0 / aspectRatio);
    if(flippedRatio < SQUARE_THRESHOLD) {
        return @"square-ish";
    } else if(flippedRatio < LONG_THRESHOLD) {
        return @"broadly rectangular";
    }
    return @"long and narrow";
}

+(NSDictionary*)getPropsOfRegionWithIdx:(int)idx fromMat:(Mat)regionMat {
    // A few magic numbers
    
    NSDictionary* descriptions = [NSMutableDictionary dictionary];
    
    // Create a new image with only our region of interest colored
    Mat filledMat(regionMat);
    int rows = filledMat.rows;
    int cols = filledMat.cols;
    for(int i = 0; i < rows; i ++) {
        for(int j = 0; j < cols; j ++) {
            if([[NSNumber numberWithUnsignedChar:filledMat.at<char>(i, j)] intValue] == idx) {
                filledMat.at<char>(i, j) = (char)128;
            } else {
                filledMat.at<char>(i, j) = (char)0;
            }
        }
    }
    
    // Find the largest contour, which should be our building
    vector<vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    findContours(filledMat, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE);
    Scalar color = Scalar(255, 255, 255);
    double maxContourArea = 0;
    double maxContourIdx = -1;
    for(int i = 0; i < contours.size(); i ++) {
        double cArea = contourArea(contours[i]);
        if(cArea > maxContourArea) {
            maxContourIdx = i;
            maxContourArea = cArea;
        }
    }
    
    // Shape features
    [descriptions setValue:[OpenCVUtils checkContourSize:contours[maxContourIdx]] forKey:@"size"];
    [descriptions setValue:[OpenCVUtils checkContour:contours[maxContourIdx]] forKey:@"contour"];
    [descriptions setValue:[OpenCVUtils checkContourRatio:contours[maxContourIdx]] forKey:@"proportions"];
    [descriptions setValue:[OpenCVUtils checkContourLetterShape:contours[maxContourIdx]] forKey:@"letterShape"];
    [descriptions setValue:[OpenCVUtils checkContourSymmetry:contours[maxContourIdx]] forKey:@"symmetry"];
    
    // Spatial features
    cv::Rect campusRect = cv::Rect(0, 0, cols, rows);
    [descriptions setValue:[OpenCVUtils checkContour:contours[maxContourIdx] isOnBoundary:campusRect] forKey:@"boundary"];
    [descriptions setValue:[OpenCVUtils checkContour:contours[maxContourIdx] isInQuadrant:campusRect] forKey:@"quadrant"];
    
    return descriptions;
}

+ (bool)building:(std::vector<cv::Point>)A isEastOfBuilding:(std::vector<cv::Point>)B {
    // We are still using the center of the bounding rect as centroid.
    // A bit of a gap is needed to make the result more interpretable
    int GAP_SIZE = 20;
    cv::Rect rA = boundingRect(A);
    cv::Rect rB = boundingRect(B);
    cv::Point cA = cv::Point(rA.x + rA.width / 2, rA.y + rA.height / 2);
    cv::Point cB = cv::Point(rB.x + rB.width / 2, rB.y + rB.height / 2);
    /*
    if(cA.x - cB.x > GAP_SIZE) {
        return true;
    }
     */
    if(cA.x - cB.x >= 0.7 * abs(cA.y - cB.y)) {
        return true;
    }
    return false;
}

+ (bool)building:(std::vector<cv::Point>)A isWestOfBuilding:(std::vector<cv::Point>)B {
    // We are still using the center of the bounding rect as centroid.
    // A bit of a gap is needed to make the result more interpretable
    int GAP_SIZE = 20;
    cv::Rect rA = boundingRect(A);
    cv::Rect rB = boundingRect(B);
    cv::Point cA = cv::Point(rA.x + rA.width / 2, rA.y + rA.height / 2);
    cv::Point cB = cv::Point(rB.x + rB.width / 2, rB.y + rB.height / 2);
    /*
     if(cB.x - cA.x > GAP_SIZE) {
     return true;
     }
     */
    if(cB.x - cA.x >= 0.7 * abs(cA.y - cB.y)) {
        return true;
    }
    return false;
}

+ (bool)building:(std::vector<cv::Point>)A isNorthOfBuilding:(std::vector<cv::Point>)B {
    // We are still using the center of the bounding rect as centroid.
    // A bit of a gap is needed to make the result more interpretable
    int GAP_SIZE = 20;
    cv::Rect rA = boundingRect(A);
    cv::Rect rB = boundingRect(B);
    cv::Point cA = cv::Point(rA.x + rA.width / 2, rA.y + rA.height / 2);
    cv::Point cB = cv::Point(rB.x + rB.width / 2, rB.y + rB.height / 2);
    /*
    if(cB.y - cA.y > GAP_SIZE) {
        return true;
    }
    */
    if(cB.y - cA.y >= 0.7 * abs(cA.x - cB.x)) {
        return true;
    }
    return false;
}

+ (bool)building:(std::vector<cv::Point>)A isSouthOfBuilding:(std::vector<cv::Point>)B {
    // We are still using the center of the bounding rect as centroid.
    // A bit of a gap is needed to make the result more interpretable
    int GAP_SIZE = 20;
    cv::Rect rA = boundingRect(A);
    cv::Rect rB = boundingRect(B);
    cv::Point cA = cv::Point(rA.x + rA.width / 2, rA.y + rA.height / 2);
    cv::Point cB = cv::Point(rB.x + rB.width / 2, rB.y + rB.height / 2);
    /*
     if(cA.y - cB.y > GAP_SIZE) {
     return true;
     }
     */
    if(cA.y - cB.y >= 0.7 * abs(cA.x - cB.x)) {
        return true;
    }
    return false;
}

+ (bool)building:(std::vector<cv::Point>)A isNearBuilding:(std::vector<cv::Point>)B {
    // We use the geometric average of B's bounding rect as a scale metric
    // and see how close A is to B's center measured against that metric.
    double CLOSE_THRESHOLD = 1.5;
    cv::Rect rA = boundingRect(A);
    cv::Rect rB = boundingRect(B);
    cv::Point cA = cv::Point(rA.x + rA.width / 2, rA.y + rA.height / 2);
    cv::Point cB = cv::Point(rB.x + rB.width / 2, rB.y + rB.height / 2);
    double scaleB = sqrt(float(rB.width * rB.height));
    double distance = [OpenCVUtils pointsDistanceBtwP:cA andP:cB];
    if(distance < scaleB * CLOSE_THRESHOLD) {
        return true;
    }
    return false;
}

// Algorithm from https://cs.stackexchange.com/questions/7096/transitive-reduction-of-dag implemented here.
+ (vector<vector<bool> >)transitiveReduction:(vector<vector<bool> >)graph withSize:(int)size {
    //vector<vector<int> > result;
    vector<int> roots;
    for(int i = 0; i < size; i ++) {
        for(int j = 0; j < size; j ++) {
            if(not graph[i][j]) {
                continue;
            }
            
            // This is a DFS
            bool discovered[size];
            for(int i = 0; i < size; i ++) {
                discovered[i] = false;
            }
            
            vector<int> stack;
            stack.push_back(j);
            discovered[j] = true;
            while(stack.size() > 0) {
                int current = stack.back();
                stack.pop_back();
                discovered[current] = true;
                if(current != j) {
                    graph[i][current] = false;
                }
                for(int k = 0; k < size; k ++) {
                    if(graph[current][k] and (not discovered[k])) {
                        stack.push_back(k);
                    }
                }
            }
        }
    }
    /*
    for(int i = 0; i < size; i ++) {
        for(int j = 0; j < size; j ++) {
            if(graph[i][j]) {
                vector<int> tmp({i, j});
                result.push_back(tmp);
            }
        }
    }*/
    return graph;
}

+ (map<NSString*, vector<cv::Point> >)getAllContoursFromRegionMat:(cv::Mat)regionMat {
    vector<int> regionIndices;
    int rows = regionMat.rows;
    int cols = regionMat.cols;
    for(int i = 0; i < rows; i ++) {
        for(int j = 0; j < cols; j ++) {
            int pixelVal = [[NSNumber numberWithUnsignedChar:regionMat.at<char>(i, j)] intValue];
            if(pixelVal > 0) {
                if(std::find(regionIndices.begin(), regionIndices.end(), pixelVal) == regionIndices.end()) {
                    regionIndices.push_back(pixelVal);
                }
            }
        }
    }
    
    map<NSString*, vector<cv::Point> > contourMap;
    for(int ii = 0; ii < regionIndices.size(); ii ++) {
        NSString* key = [[NSNumber numberWithInt:regionIndices[ii]] stringValue];
        
        int idx = regionIndices[ii];
        Mat filledMat = regionMat.clone();
        for(int i = 0; i < rows; i ++) {
            for(int j = 0; j < cols; j ++) {
                if([[NSNumber numberWithUnsignedChar:filledMat.at<char>(i, j)] intValue] == idx) {
                    filledMat.at<char>(i, j) = (char)128;
                } else {
                    filledMat.at<char>(i, j) = (char)0;
                }
            }
        }
        
        // Find the largest contour, which should be our building
        vector<vector<cv::Point> > contours;
        vector<Vec4i> hierarchy;
        findContours(filledMat, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE);
        double maxContourArea = 0;
        double maxContourIdx = -1;
        for(int i = 0; i < contours.size(); i ++) {
            double cArea = contourArea(contours[i]);
            if(cArea > maxContourArea) {
                maxContourIdx = i;
                maxContourArea = cArea;
            }
        }
        contourMap[key] = contours[maxContourIdx];
    }
    
    return contourMap;
}

+ (vector<vector<bool> >)reductionOn:(vector<vector<bool> >)graph byDistanceUsingCentroids:(map<NSString*, cv::Point>)centroidMap andKeys:(vector<NSString*>)regionKeys {
    // Discards a relationship if two buildings are too far from each other.
    float DISTANCE_T = 150;
    
    for(int i = 0; i < graph.size(); i ++) {
        for(int j = 0; j < graph[i].size(); j ++) {
            if(graph[i][j]) {
                NSString* iKey = regionKeys[i];
                NSString* jKey = regionKeys[j];
                cv::Point iCentroid = centroidMap[iKey];
                cv::Point jCentroid = centroidMap[jKey];
                if([OpenCVUtils pointsDistanceBtwP:iCentroid andP:jCentroid] > DISTANCE_T) {
                    graph[i][j] = false;
                }
            }
        }
    }
    
    return graph;
}

+ (NSDictionary*)getPairsOfInterestFromRegionMat:(cv::Mat)regionMat usingNames:(NSDictionary*)names {
    vector<int> regionIndices;
    int rows = regionMat.rows;
    int cols = regionMat.cols;
    for(int i = 0; i < rows; i ++) {
        for(int j = 0; j < cols; j ++) {
            int pixelVal = [[NSNumber numberWithUnsignedChar:regionMat.at<char>(i, j)] intValue];
            if(pixelVal > 0) {
                if(std::find(regionIndices.begin(), regionIndices.end(), pixelVal) == regionIndices.end()) {
                    regionIndices.push_back(pixelVal);
                }
            }
        }
    }
    
    map<NSString*, vector<cv::Point> > contourMap;
    // Again, we are using the center of the bounding rectangle here.
    map<NSString*, cv::Point> centroidMap;
    vector<NSString*> regionKeys;
    for(int ii = 0; ii < regionIndices.size(); ii ++) {
        NSString* key = [[NSNumber numberWithInt:regionIndices[ii]] stringValue];
        regionKeys.push_back(key);
        
        int idx = regionIndices[ii];
        Mat filledMat = regionMat.clone();
        for(int i = 0; i < rows; i ++) {
            for(int j = 0; j < cols; j ++) {
                if([[NSNumber numberWithUnsignedChar:filledMat.at<char>(i, j)] intValue] == idx) {
                    filledMat.at<char>(i, j) = (char)128;
                } else {
                    filledMat.at<char>(i, j) = (char)0;
                }
            }
        }
        
        // Find the largest contour, which should be our building
        vector<vector<cv::Point> > contours;
        vector<Vec4i> hierarchy;
        findContours(filledMat, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE);
        double maxContourArea = 0;
        double maxContourIdx = -1;
        for(int i = 0; i < contours.size(); i ++) {
            double cArea = contourArea(contours[i]);
            if(cArea > maxContourArea) {
                maxContourIdx = i;
                maxContourArea = cArea;
            }
        }
        contourMap[key] = contours[maxContourIdx];
        cv::Rect contourRect = boundingRect(contours[maxContourIdx]);
        centroidMap[key] = cv::Point(contourRect.x + contourRect.width / 2, contourRect.y + contourRect.height / 2);
    }

    cv::Mat retMat = regionMat.clone();
    // For all building pairs, check if the line that connects their "centroids"
    // passes through other buildings
    // If no, then consider this a valid condition.
    vector<vector<bool> > eastRelations;
    vector<vector<bool> > westRelations;
    vector<vector<bool> > northRelations;
    vector<vector<bool> > southRelations;
    vector<vector<bool> > nearRelations;
    for(int i = 0; i < regionKeys.size(); i ++) {
        vector<bool> tmp;
        eastRelations.push_back(tmp);
        westRelations.push_back(tmp);
        northRelations.push_back(tmp);
        southRelations.push_back(tmp);
        nearRelations.push_back(tmp);
        
        for(int j = 0; j < regionKeys.size(); j ++) {
            eastRelations[i].push_back(false);
            westRelations[i].push_back(false);
            northRelations[i].push_back(false);
            southRelations[i].push_back(false);
            nearRelations[i].push_back(false);
            NSString* k1 = regionKeys[i];
            NSString* k2 = regionKeys[j];
            if(not [k1 isEqualToString:k2]) {
                /*
                if([OpenCVUtils building:contourMap[k1] isNearBuilding:contourMap[k2]]) {
                    //NSLog(@"%@ is near %@", k1, k2);
                    arrowedLine(retMat, centroidMap[k2], centroidMap[k1], Scalar(128, 128, 128));
                }
                 */
                eastRelations[i][j] = [OpenCVUtils building:contourMap[k1] isEastOfBuilding:contourMap[k2]];
                westRelations[i][j] = [OpenCVUtils building:contourMap[k1] isWestOfBuilding:contourMap[k2]];
                northRelations[i][j] = [OpenCVUtils building:contourMap[k1] isNorthOfBuilding:contourMap[k2]];
                southRelations[i][j] = [OpenCVUtils building:contourMap[k1] isSouthOfBuilding:contourMap[k2]];
                nearRelations[i][j] = [OpenCVUtils building:contourMap[k1] isNearBuilding:contourMap[k2]];
            }
        }
    }
    /*
    vector<vector<bool> > eastReduced = [OpenCVUtils transitiveReduction:eastRelations withSize:int(regionKeys.size())];
    vector<vector<bool> > westReduced = [OpenCVUtils transitiveReduction:westRelations withSize:int(regionKeys.size())];
    vector<vector<bool> > northReduced = [OpenCVUtils transitiveReduction:northRelations withSize:int(regionKeys.size())];
    vector<vector<bool> > southReduced = [OpenCVUtils transitiveReduction:southRelations withSize:int(regionKeys.size())];
    */
    
    vector<vector<bool> > eastReduced = [OpenCVUtils reductionOn:eastRelations byDistanceUsingCentroids:centroidMap andKeys:regionKeys];
    vector<vector<bool> > westReduced = [OpenCVUtils reductionOn:westRelations byDistanceUsingCentroids:centroidMap andKeys:regionKeys];
    vector<vector<bool> > northReduced = [OpenCVUtils reductionOn:northRelations byDistanceUsingCentroids:centroidMap andKeys:regionKeys];
    vector<vector<bool> > southReduced = [OpenCVUtils reductionOn:southRelations byDistanceUsingCentroids:centroidMap andKeys:regionKeys];
    
    /*
    eastReduced = [OpenCVUtils transitiveReduction:eastReduced withSize:int(regionKeys.size())];
    westReduced = [OpenCVUtils transitiveReduction:westRelations withSize:int(regionKeys.size())];
    northReduced = [OpenCVUtils transitiveReduction:northRelations withSize:int(regionKeys.size())];
    southReduced = [OpenCVUtils transitiveReduction:southRelations withSize:int(regionKeys.size())];
    */
     
    // NOTE: All the near relations are kept.
    
    /*
    for(int i = 0; i < southReduced.size(); i ++) {
        arrowedLine(retMat, centroidMap[regionKeys[southReduced[i][1]]], centroidMap[regionKeys[southReduced[i][0]]], Scalar(128, 128, 128));
    }
    */
    
    NSDictionary* descriptions = [NSMutableDictionary dictionary];
    for(int i = 0; i < regionKeys.size(); i ++) {
        NSMutableString* eastD = [NSMutableString stringWithString:@"east:"];
        int eastCount = 0;
        for(int j = 0; j < eastReduced.size(); j ++) {
            //NSLog(@"Key: %@", regionKeys[j]);
            if(eastReduced[i][j]) {
                if(eastCount > 0) {
                    [eastD appendString:@","];
                }
                [eastD appendString:regionKeys[j]];
                eastCount += 1;
            }
        }
        NSMutableString* westD = [NSMutableString stringWithString:@"west:"];
        int westCount = 0;
        for(int j = 0; j < westReduced.size(); j ++) {
            if(westReduced[i][j]) {
                if(westCount > 0) {
                    [westD appendString:@","];
                }
                [westD appendString:regionKeys[j]];
                westCount += 1;
            }
        }
        NSMutableString* northD = [NSMutableString stringWithString:@"north:"];
        int northCount = 0;
        for(int j = 0; j < northReduced.size(); j ++) {
            if(northReduced[i][j]) {
                if(northCount > 0) {
                    [northD appendString:@","];
                }
                [northD appendString:regionKeys[j]];
                northCount += 1;
            }
        }
        NSMutableString* southD = [NSMutableString stringWithString:@"south:"];
        int southCount = 0;
        for(int j = 0; j < southReduced.size(); j ++) {
            if(southReduced[i][j]) {
                if(southCount > 0) {
                    [southD appendString:@","];
                }
                [southD appendString:regionKeys[j]];
                southCount += 1;
            }
        }
        NSMutableString* nearD = [NSMutableString stringWithString:@"near:"];
        int nearCount = 0;
        for(int j = 0; j < nearRelations.size(); j ++) {
            if(nearRelations[i][j]) {
                if(nearCount > 0) {
                    [nearD appendString:@","];
                }
                [nearD appendString:regionKeys[j]];
                nearCount += 1;
            }
        }
        NSMutableString* finalD = [NSMutableString stringWithString:@""];
        int dCount = 0;
        if(eastCount > 0) {
            if(dCount > 0) {
                [finalD appendString:@"|"];
            }
            [finalD appendString:eastD];
            dCount += 1;
        }
        if(westCount > 0) {
            if(dCount > 0) {
                [finalD appendString:@"|"];
            }
            [finalD appendString:westD];
            dCount += 1;
        }
        if(northCount > 0) {
            if(dCount > 0) {
                [finalD appendString:@"|"];
            }
            [finalD appendString:northD];
            dCount += 1;
        }
        if(southCount > 0) {
            if(dCount > 0) {
                [finalD appendString:@"|"];
            }
            [finalD appendString:southD];
            dCount += 1;
        }
        if(nearCount > 0) {
            if(dCount > 0) {
                [finalD appendString:@"|"];
            }
            [finalD appendString:nearD];
            dCount += 1;
        }
        [descriptions setValue:finalD forKey:regionKeys[i]];
    }
    
    return descriptions;
}

+ (vector<vector<NSString*> >)getDescriptionAtLocationX:(int)x andY:(int)y usingContourMap:(map<NSString*, vector<cv::Point> >)contourMap andRegionMat:(cv::Mat)regionMat {
    vector<NSString*> buildings;
    NSString* location = @"inside";
    if([[NSNumber numberWithUnsignedChar:regionMat.at<char>(y, x)] intValue] > 0) {
        // If it is in a building, use that building as the descriptor
        buildings.push_back([[NSNumber numberWithUnsignedChar:regionMat.at<char>(y, x)] stringValue]);
    } else {
        // Else, describe the location using the two buildings closest to it.
        NSString* closestKey = @"";
        double closestDistance = 1000000;
        NSString* secondKey = @"";
        double secondDistance = 1000000;
        
        vector<NSString*> regionKeys;
        for(map<NSString*, vector<cv::Point> >::iterator it = contourMap.begin(); it != contourMap.end(); it ++) {
            regionKeys.push_back(it -> first);
        }
        
        for(int i = 0; i < regionKeys.size(); i ++) {
            NSString* cKey = regionKeys[i];
            cv::Rect cBox = boundingRect(contourMap[cKey]);
            cv::Point cCenter = cv::Point(cBox.x + cBox.width / 2, cBox.y + cBox.height / 2);
            double cScale = sqrt(cBox.width * cBox.height);
            double cDistance = [OpenCVUtils pointsDistanceBtwP:cCenter andP:cv::Point(x, y)];
            if(cDistance < closestDistance) {
                secondKey = [NSString stringWithString:closestKey];
                secondDistance = closestDistance;
                closestKey = [NSString stringWithString:cKey];
                closestDistance = cDistance;
            } else if(cDistance < secondDistance) {
                secondKey = [NSString stringWithString:cKey];
                secondDistance = cDistance;
            }
        }
        if(closestKey.intValue < secondKey.intValue) {
            buildings.push_back(closestKey);
            buildings.push_back(secondKey);
        } else {
            buildings.push_back(secondKey);
            buildings.push_back(closestKey);
        }
        location = @"outside";
    }
    
    int GAP_SIZE = 10;
    
    vector<vector<NSString*> > result;
    
    for(int i = 0; i < buildings.size(); i ++) {
        cv::Rect bBox = boundingRect(contourMap[buildings[i]]);
        cv::Point bCenter = cv::Point(bBox.x + bBox.width / 2, bBox.y + bBox.height / 2);
        int count = 0;
        NSMutableString* directions = [NSMutableString string];
        if(x - bCenter.x > GAP_SIZE) {
            //vector<NSString*> resultEntry({buildings[i], @"to the west", [NSString stringWithString:location]});
            //result.push_back(resultEntry);
            if(count > 0) {
                [directions appendString:@":"];
            }
            [directions appendString:@"to the east"];
            count += 1;
        }
        if(bCenter.x - x > GAP_SIZE) {
            //vector<NSString*> resultEntry({buildings[i], @"to the east", [NSString stringWithString:location]});
            //result.push_back(resultEntry);
            if(count > 0) {
                [directions appendString:@":"];
            }
            [directions appendString:@"to the west"];
            count += 1;
        }
        if(y - bCenter.y > GAP_SIZE) {
            //vector<NSString*> resultEntry({buildings[i], @"to the south", [NSString stringWithString:location]});
            //result.push_back(resultEntry);
            if(count > 0) {
                [directions appendString:@":"];
            }
            [directions appendString:@"to the south"];
            count += 1;
        }
        if(bCenter.y - y > GAP_SIZE) {
            //vector<NSString*> resultEntry({buildings[i], @"to the north", [NSString stringWithString:location]});
            //result.push_back(resultEntry);
            if(count > 0) {
                [directions appendString:@":"];
            }
            [directions appendString:@"to the north"];
            count += 1;
        }
        if(count == 0) {
            //vector<NSString*> resultEntry({buildings[i], @"near the center", [NSString stringWithString:location]});
            //result.push_back(resultEntry);
            if(count > 0) {
                [directions appendString:@":"];
            }
            [directions appendString:@"near the center"];
            count += 1;
        }
        vector<NSString*> resultEntry({buildings[i], directions, [NSString stringWithString:location]});
        result.push_back(resultEntry);
    }
    
    return result;
}

+ (vector<vector<NSString*> >)getTappedRegionsAtLocationX:(int)x andY:(int)y UsingRegionMat:(cv::Mat) regionMat {
    map<NSString*, vector<cv::Point> > contourMap = [OpenCVUtils getAllContoursFromRegionMat:regionMat];
    //NSLog(@"Got all regions.");
    
    return [OpenCVUtils getDescriptionAtLocationX:x andY:y usingContourMap:contourMap andRegionMat:regionMat];
}

+ (vector<vector<vector<NSString*> > >)getDescriptionOfAllPixelsUsingRegionMat:(cv::Mat)regionMat {
    vector<vector<vector<NSString*> > > result;
    
    map<NSString*, vector<cv::Point> > contourMap = [OpenCVUtils getAllContoursFromRegionMat:regionMat];
    
    int rows = regionMat.rows;
    int cols = regionMat.cols;
    for(int i = 0; i < cols; i ++) {
        for(int j = 0; j < rows; j ++) {
            result.push_back([OpenCVUtils getDescriptionAtLocationX:i andY:j usingContourMap:contourMap andRegionMat:regionMat]);
        }
    }
    
    return result;
}

+ (UIImage*)drawRegionWithIdx:(int)idx basedOnMat:(cv::Mat)regionMat usingMat:(cv::Mat)campusMat {
    
    //cv::Mat retMat = [OpenCVUtils getPairsOfInterestFromRegionMat:regionMat];
    
    if(idx == 0) {
        return [OpenCVUtils UIImageFromCVMat:campusMat];
    }
    
    // Create a new image with only our region of interest colored
    Mat filledMat(regionMat);
    int rows = filledMat.rows;
    int cols = filledMat.cols;
    for(int i = 0; i < rows; i ++) {
        for(int j = 0; j < cols; j ++) {
            if([[NSNumber numberWithUnsignedChar:filledMat.at<char>(i, j)] intValue] == idx) {
                filledMat.at<char>(i, j) = (char)128;
            } else {
                filledMat.at<char>(i, j) = (char)0;
            }
        }
    }
    
    // Find the largest contour, which should be our building
    vector<vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    findContours(filledMat, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE);
    Scalar color = Scalar(255, 0, 255);
    double maxContourArea = 0;
    double maxContourIdx = -1;
    for(int i = 0; i < contours.size(); i ++) {
        double cArea = contourArea(contours[i]);
        if(cArea > maxContourArea) {
            maxContourIdx = i;
            maxContourArea = cArea;
        }
    }
    
    // Area of the contour, for size
    drawContours(campusMat, contours, maxContourIdx, color);
    
    return [OpenCVUtils UIImageFromCVMat:campusMat];
}

@end
