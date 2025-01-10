//
//  ModelManager.m
//  DataBaseDemo
//
//  Created by TheAppGuruz-New-6 on 22/02/14.
//  Copyright (c) 2014 TheAppGuruz-New-6. All rights reserved.
//

#import "ModelManager.h"


@implementation ModelManager

static ModelManager *instance=nil;
NSString *databasePath;

static sqlite3 *database = nil;
static sqlite3_stmt *statement = nil;

@synthesize database=_database;

+(ModelManager *) getInstance
{
    
    if(!instance)
    {
        instance=[[ModelManager alloc]init];
        instance.database=[FMDatabase databaseWithPath:[Util getFilePath:@"tenserflow.sqlite"]];
    }
    return instance;
}

-(void)insertData:(Model *)data
{
    [instance.database open];
    BOOL isInserted=[instance.database executeUpdate:@"INSERT INTO imagedata (url,state,badimage,scandate) VALUES (?,?,?,?)",data.URL,data.state,data.bad_image,data.scan_date];
    [instance.database close];
    
    if(isInserted)
        NSLog(@"Inserted Successfully");
    else
        NSLog(@"Error occured while inserting");
}

-(void)updateData:(Model *)data
{
    //    [instance.database open];
    //    BOOL isUpdated=[instance.database executeUpdate:@"UPDATE image_data SET Name=? WHERE mobile=?",data.Name,data.mobile];
    //    [instance.database close];
    //
    //    if(isUpdated)
    //        NSLog(@"Updated Successfully");
    //    else
    //        NSLog(@"Error occured while Updating");
}

-(void)deleteData:(Model *)data
{
    //    [instance.database open];
    //    BOOL isDeleted=[instance.database executeUpdate:@"DELETE FROM image_data WHERE mobile=?",data.mobile];
    //    [instance.database close];
    //
    //    if(isDeleted)
    //        NSLog(@"Deleted Successfully");
    //    else
    //        NSLog(@"Error occured while Deleting");
}

-(void) displayData
{
    
    
    [instance.database open];
    FMResultSet *resultSet=[instance.database executeQuery:@"SELECT * FROM imagedata"];
    if(resultSet)
    {
        while([resultSet next])
            NSLog(@"URL : %@    state : %@    bad_image : %@    scan_date : %@",[resultSet stringForColumn:@"url"],[resultSet stringForColumn:@"state"],[resultSet stringForColumn:@"badimage"],[resultSet stringForColumn:@"scandate"]);
    }
    [instance.database close];
}
-(NSMutableDictionary*) retrieveAllData
{
    
    NSMutableDictionary *wholeData = [NSMutableDictionary dictionary];
    
    [instance.database open];
    FMResultSet *resultSet=[instance.database executeQuery:@"SELECT * FROM imagedata"];
    if(resultSet)
    {
        while([resultSet next])
        {   //   NSLog(@"URL : %@    state : %@    bad_image : %@    scan_date : %@",[resultSet stringForColumn:@"url"],[resultSet stringForColumn:@"state"],[resultSet stringForColumn:@"badimage"],[resultSet stringForColumn:@"scandate"]);
        Model *obj =[[Model alloc]init];
        obj.URL = [resultSet stringForColumn:@"url"];
        obj.bad_image = [resultSet stringForColumn:@"badimage"];
        obj.scan_date = [resultSet stringForColumn:@"scandate"];
        obj.state = [resultSet stringForColumn:@"state"];
        
        
        
        [wholeData setObject:obj forKey:[resultSet stringForColumn:@"url"]];
        }
    }
    [instance.database close];
    NSLog(@"Data Parsed");
    return wholeData;
}
-(Model *)getRecord:(NSMutableDictionary *)data withName:(NSString *)image{
   
    NSLog(@" %@ --- %lu ",image,(unsigned long)[data allKeys].count);
    Model *obj = [[Model alloc]init];
    
    obj = NULL;
    obj = [data objectForKey:image];
    
    //if([data objectForKey:image]) {
    if(obj) {
        obj = [data objectForKey:image]; // The key existed...
        NSLog(@"Object found...");
    }
    else {
        NSLog(@"Object NOT  found...");
        obj = NULL;
    }
    return obj;
}
-(void)deleteAllData
{
    [instance.database open];
    BOOL isDeleted=[instance.database executeUpdate:@"DELETE FROM imagedata"];
    [instance.database close];
    
    if(isDeleted)
        NSLog(@"Deleted Successfully");
    else
        NSLog(@"Error occured while Deleting");
}


@end
