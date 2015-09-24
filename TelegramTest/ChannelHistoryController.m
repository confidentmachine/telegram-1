//
//  ChannelHistoryController.m
//  Telegram
//
//  Created by keepcoder on 08.09.15.
//  Copyright (c) 2015 keepcoder. All rights reserved.
//

#import "ChannelHistoryController.h"
#import "MessageTableItem.h"
#import "TGChannelsPolling.h"

#import "ChannelImportantFilter.h"
#import "ChannelFilter.h"
@interface ChannelHistoryController () <TGChannelPollingDelegate>
@property (nonatomic,assign) BOOL pollingIsStarted;
@end

@implementation ChannelHistoryController


static TGChannelsPolling *channelPolling;

-(id)initWithController:(id<MessagesDelegate>)controller historyFilter:(Class)historyFilter {
    if(self = [super initWithController:controller historyFilter:historyFilter]) {
        
        
        [self.queue dispatchOnQueue:^{
            
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                channelPolling = [[TGChannelsPolling alloc] initWithDelegate:self withUpdatesLimit:50];
                
            });
            
            [channelPolling setDelegate:self];
            [channelPolling setCurrentConversation:controller.conversation];
            
            _pollingIsStarted = NO;
            
        } synchronous:YES];
        
    }
    
    return self;
}


-(void)request:(BOOL)next anotherSource:(BOOL)anotherSource sync:(BOOL)sync selectHandler:(selectHandler)selectHandler {
    
    [self.queue dispatchOnQueue:^{
        
        if([self checkState:ChatHistoryStateFull next:next] || self.isProccessing) {
            return;
        }
        
        
        self.proccessing = YES;
        
        
       // ChannelHistoryController* __weak weakSelf = self;
       
        [self.filter request:next callback:^(NSArray *result, ChatHistoryState state) {
            
         //   ChannelHistoryController* strongSelf = weakSelf;
            
          //  if(strongSelf != nil) {
            
            if([self checkState:ChatHistoryStateLocal next:next] && result.count == 0) {
                
                [self proccessResponse:result state:state next:next];
                
                [self request:next anotherSource:anotherSource sync:sync selectHandler:selectHandler];
                
                return ;
            }
            
            NSArray *converted = [self proccessResponse:result state:state next:next];
            
            [self performCallback:selectHandler result:converted range:NSMakeRange(0, converted.count)];
            
            [channelPolling checkInvalidatedMessages:converted important:[self.filter isKindOfClass:[ChannelImportantFilter class]]];
        //    } else {
          //      MTLog(@"ChatHistoryController is dealloced");
         //   }
            
           
            
        }];
        
    } synchronous:sync];
    
}


-(NSArray *)proccessResponse:(NSArray *)result state:(ChatHistoryState)state next:(BOOL)next {
    NSArray *items = [self.controller messageTableItemsFromMessages:result];
    
    
    NSArray *converted = [self filterAndAdd:items acceptToFilters:nil];
    
    
    converted = [self sortItems:converted];
    
    
    state = !next && state != ChatHistoryStateFull && ([self.filter isKindOfClass:[ChannelFilter class]] ? self.conversation.top_message <= self.server_max_id : self.conversation.top_important_message <= self.server_max_id) ? ChatHistoryStateFull : state;
    
    if(state == ChatHistoryStateFull) {
        
    }
    
        
    [self setState:state next:next];
    
    return converted;
}

-(void)setFilter:(HistoryFilter *)filter {
    
    [self.queue dispatchOnQueue:^{
        
        [super setFilter:filter];
    }];
    
    

}

-(void)pollingDidSaidTooLongWithHole:(TGMessageHole *)hole {
    
    if(hole != nil) {
        
        [self.filter setHole:hole withNext:NO];
        
        [self setState:ChatHistoryStateRemote next:NO];
        
        [self.filter request:NO callback:^(id response, ChatHistoryState state) {
            
            NSArray *converted = [self proccessResponse:response state:state next:NO];
            
            [ASQueue dispatchOnMainQueue:^{
                
                [self.controller receivedMessageList:converted inRange:NSMakeRange(0, converted.count) itsSelf:NO];
                
            }];
            
            
            
        }];
        
    }
    
    
    
}



-(void)loadAroundMessagesWithMessage:(MessageTableItem *)item limit:(int)limit selectHandler:(selectHandler)selectHandler {
    
    
    [self.queue dispatchOnQueue:^{
        
        [self addItemWithoutSavingState:item];
    
        [[Storage manager] addHolesAroundMessage:item.message];
        
        if(self.filter.class == [ChannelFilter class]) {
            [(ChannelFilter *)self.filter fillGroupHoles:@[item.message] bottom:NO];
        }
        
        [[Storage manager] insertMessage:item.message];
        
        NSMutableArray *prevResult = [NSMutableArray array];
        NSMutableArray *nextResult = [NSMutableArray array];
        
        self.proccessing = YES;
        [self loadAroundMessagesWithSelectHandler:selectHandler limit:(int)limit prevResult:prevResult nextResult:nextResult];
        
      
    } synchronous:YES];
    
    
}

-(void)loadAroundMessagesWithSelectHandler:(selectHandler)selectHandler limit:(int)limit prevResult:(NSMutableArray *)prevResult nextResult:(NSMutableArray *)nextResult {
    
    
    BOOL nextLoaded = nextResult.count >= limit/2 || self.nextState == ChatHistoryStateFull;
    BOOL prevLoaded = prevResult.count >= limit/2 || self.prevState == ChatHistoryStateFull;
    
    
    if(nextLoaded && prevLoaded) {
        
        NSArray *result = [self selectAllItems];
        
        [self performCallback:selectHandler result:result range:NSMakeRange(0, result.count)];

        [channelPolling checkInvalidatedMessages:result important:[self.filter isKindOfClass:[ChannelImportantFilter class]]];
        
        self.proccessing = NO;
        return;
    }
    
    BOOL nextRequest = prevLoaded;
    
    
    
    [self.filter request:nextRequest callback:^(NSArray *result, ChatHistoryState state) {
        
        NSArray *converted = [self proccessResponse:result state:state next:nextRequest];
        
        if(nextRequest) {
            [nextResult addObjectsFromArray:converted];
        } else {
            [prevResult addObjectsFromArray:converted];
        }
        
    
        [self loadAroundMessagesWithSelectHandler:selectHandler limit:(int)limit prevResult:prevResult nextResult:nextResult];
        
    }];
    
}



-(void)pollingReceivedUpdates:(id)updates endPts:(int)pts {
    
}



-(void)startChannelPolling {
    
    if(!channelPolling.isActive) {
        [channelPolling start];
        _pollingIsStarted = YES;
    }
}

-(void)startChannelPollingIfAlreadyStoped {
    if(!channelPolling.isActive && _pollingIsStarted) {
        [channelPolling start];
    }
}

-(void)stopChannelPolling {
    [channelPolling stop];
}


-(int)min_id {
    
    NSArray *allItems = [self selectAllItems];
    
    if(allItems.count == 0)
        return 0;
    
    
    __block MessageTableItem *lastObject;
    
    [allItems enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(MessageTableItem *obj, NSUInteger idx, BOOL *stop) {
        
        if(obj.message.n_id > 0)
        {
            lastObject = obj;
            *stop = YES;
        }
        
    }];
    
    return lastObject.message.n_id;
    
}

-(int)minDate {
    NSArray *allItems = [self selectAllItems];
    
    if(allItems.count == 0)
        return 0;
    
    
    __block MessageTableItem *lastObject;
    
    [allItems enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(MessageTableItem *obj, NSUInteger idx, BOOL *stop) {
        
        if(obj.message.n_id > 0)
        {
            lastObject = obj;
            *stop = YES;
        }
        
    }];
    
    return lastObject.message.date ;
    
}



-(int)max_id {
    
    NSArray *allItems = [self selectAllItems];
    
    
    if(allItems.count == 0)
        return self.conversation.last_marked_message;
    
    
    
    __block MessageTableItem *firstObject;
    
    [allItems enumerateObjectsWithOptions:0 usingBlock:^(MessageTableItem *obj, NSUInteger idx, BOOL *stop) {
        
        if(obj.message.n_id > 0)
        {
            firstObject = obj;
            *stop = YES;
        }
        
    }];
    
    return firstObject.message.n_id;
}

-(int)maxDate {
    NSArray *allItems = [self selectAllItems];
    
    if(allItems.count == 0)
        return self.conversation.last_marked_date;
    
    __block MessageTableItem *firstObject;
    
    [allItems enumerateObjectsWithOptions:0 usingBlock:^(MessageTableItem *obj, NSUInteger idx, BOOL *stop) {
        
        if(obj.message.n_id > 0)
        {
            firstObject = obj;
            *stop = YES;
        }
        
    }];
    
    return firstObject.message.date;
}

-(int)server_min_id {
    
    NSArray *allItems = [self selectAllItems];
    
    
    __block int msgId;
    
    [allItems enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(MessageTableItem *obj, NSUInteger idx, BOOL *stop) {
        
        
        if(obj.message.n_id > 0 && obj.message.n_id < TGMINFAKEID)
        {
            msgId = obj.message.n_id;
            *stop = YES;
        }
        
    }];
    
    return msgId;
    
}

-(int)server_max_id {
    
    NSArray *allItems = [self selectAllItems];
    
    
    __block MessageTableItem *item;
    
    [allItems enumerateObjectsUsingBlock:^(MessageTableItem *obj, NSUInteger idx, BOOL *stop) {
        
        if(obj.message.n_id > 0 && obj.message.n_id < TGMINFAKEID)
        {
            item = obj;
            *stop = YES;
        }
        
    }];
    
    return item.message.n_id;
    
}

-(void)drop:(BOOL)dropMemory {
    
    [super drop:YES];
}

-(void)dealloc {
    [channelPolling stop];
}


@end
