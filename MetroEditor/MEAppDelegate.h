//
//  MEAppDelegate.h
//  MetroEditor
//
//  Created by Vasiliy Makarov on 05.02.13.
//  Copyright (c) 2013 Vasiliy Makarov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MEAppDelegate : NSObject <NSApplicationDelegate> 

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (IBAction)saveAction:(id)sender;
- (IBAction)newDocument:(id)sender;
- (IBAction)openDocument:(id)sender;

@end
