//
//  MyTiledLayer.m
//  tube
//
//  Created by Vasiliy Makarov on 20.01.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MyTiledLayer.h"

@implementation MyTiledLayer

-(id)init
{
    if((self = [super init])) {
        self.tileSize = CGSizeMake(1024, 1024);
    }
    return self;
}

// выключаем фейд рисуемых участков, чем экономим 1/4 секунды на участок
+(CFTimeInterval)fadeDuration
{
    return 0.001;
}

@end
