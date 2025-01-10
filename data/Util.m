//
//  Util.m
//  DataBaseDemo
//
//  Created by TheAppGuruz-New-6 on 22/02/14.
//  Copyright (c) 2014 TheAppGuruz-New-6. All rights reserved.
//

#import "Util.h"

@implementation Util

+(NSString *) getFilePath :(NSString *)fileName
{
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:fileName];
}


+(void) copyFile:(NSString *)file
{
    NSLog(@"in method");
    NSString *toPath=[self getFilePath:file];
    NSFileManager *fileManager=[NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:toPath])
    {
        NSString *fromPath=[[NSBundle mainBundle] pathForResource:@"tenserflow" ofType:@"sqlite"];
        [fileManager copyItemAtPath:fromPath toPath:toPath error:nil];
    }
}

@end
