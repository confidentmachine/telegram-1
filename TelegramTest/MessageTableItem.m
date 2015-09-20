//
//  MessageTableItem.m
//  Telegram P-Edition
//
//  Created by Dmitry Kondratyev on 1/26/14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "MessageTableItem.h"
#import "MessageTableItemServiceMessage.h"
#import "MessageTableItemText.h"
#import "MessageTableItemPhoto.h"
#import "MessageTableItemVideo.h"
#import "MessageTableItemDocument.h"
#import "MessageTableItemGeo.h"
#import "MessageTableItemContact.h"
#import "MessageTableItemAudio.h"
#import "MessageTableItemGif.h"
#import "MessagetableitemUnreadMark.h"
#import "MessageTableItemAudioDocument.h"
#import "MessageTableItemServiceMessage.h"
#import "MessageTableItemSticker.h"
#import "MessageTableItemHole.h"
#import "TGDateUtils.h"
#import "PreviewObject.h"
#import "NSString+Extended.h"
#import "MessageTableHeaderItem.h"
#import "MessageTableItemSocial.h"
#import "TL_localMessage_old32.h"
#import "TL_localMessage_old34.h"
@interface MessageTableItem()
@property (nonatomic) BOOL isChat;
@property (nonatomic) NSSize _viewSize;
@property (nonatomic,assign) BOOL autoStart;
@end

@implementation MessageTableItem

- (id)initWithObject:(TL_localMessage *)object {
    self = [super init];
    if(self) {
        self.message = object;
        
        if(object.peer.peer_id == [UsersManager currentUserId])
            object.flags&= ~TGUNREADMESSAGE;
        
        self.isForwadedMessage = (self.message.fwd_from_id != nil ) && ![self.message.media isKindOfClass:[TL_messageMediaPhoto class]] && ![self.message.media isKindOfClass:[TL_messageMediaVideo class]] && (![self.message.media isKindOfClass:[TL_messageMediaDocument class]] || (![self.message.media.document isSticker] && ![self.message.media.document.mime_type isEqualToString:@"image/gif"])) && ([self.message.media.document attributeWithClass:[TL_documentAttributeAudio class]] == nil);
        
        
        self.isChat = [self.message.to_id isKindOfClass:[TL_peerChat class]] || [self.message.to_id isKindOfClass:[TL_peerChannel class]];
        
        _containerOffset = self.message.from_id != 0 ? 79 : 29;
        
        _containerOffsetForward  = self.message.from_id != 0 ? 141 : 91;
        
        if(self.message) {
           
            self.user = [[UsersManager sharedManager] find:object.from_id];
            if(self.isForwadedMessage) {
                if([object.fwd_from_id isKindOfClass:[TL_peerUser class]]) {
                    self.fwd_user = [[UsersManager sharedManager] find:object.fwd_from_id.user_id];
                } else  {
                    self.fwd_chat = [[ChatsManager sharedManager] find:object.fwd_from_id.chat_id == 0 ? object.fwd_from_id.channel_id : object.fwd_from_id.chat_id];
                }
                
            }
            
            [self rebuildDate];
            
            [self headerStringBuilder];
        }
    }
    return self;
}

-(int)makeSize {
    return MAX(NSWidth([Telegram rightViewController].view.frame) - (self.message.from_id == 0 ? 100 : 150),100);
}

- (void) headerStringBuilder {
//    if(!self.headerString) {
//        self.headerString = [[NSMutableAttributedString alloc] init];
//    }
//    
//    [[self.headerString mutableString] setString:@""];
    
    
    NSString *name = self.isChat ? self.user.fullName : self.user.dialogFullName;
    
    
    if(self.message.from_id == 0)
    {
        name = self.message.conversation.chat.title;
    }
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    
    static NSColor * colors[6];
    static NSMutableDictionary *cacheColorIds;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colors[0] = NSColorFromRGB(0xce5247);
        colors[1] = NSColorFromRGB(0xcda322);
        colors[2] = NSColorFromRGB(0x5eaf33);
        colors[3] = NSColorFromRGB(0x468ec4);
        colors[4] = NSColorFromRGB(0xac6bc8);
        colors[5] = NSColorFromRGB(0xe28941);
        
        cacheColorIds = [[NSMutableDictionary alloc] init];
    });
    
    
   
    
    NSColor *nameColor = LINK_COLOR;
    
    
    int uid = self.user.n_id;
    
    if(self.isChat && self.user.n_id != [UsersManager currentUserId]) {
        
        
       int colorMask = [TMAvatarImageView colorMask:self.user];
        
        nameColor = colors[colorMask % (sizeof(colors) / sizeof(colors[0]))];
        
    }
    
    
    
    NSMutableAttributedString *header = [[NSMutableAttributedString alloc] init];
    
    [header appendString:name withColor:nameColor];
    
//    if(self.message.from_id == 0) {
//        [header appendAttributedString:[NSAttributedString attributedStringWithAttachment:channelIconAttachment()]];
//    }
    
    [header setFont:[NSFont fontWithName:@"HelveticaNeue-Medium" size:13] forRange:header.range];
    
    [header addAttribute:NSLinkAttributeName value:[TMInAppLinks userProfile:uid] range:header.range];
    
    self.headerName = header;
    
    
    
    if([self isReplyMessage])
    {
        _replyObject = [[TGReplyObject alloc] initWithReplyMessage:self.message.replyMessage fromMessage:self.message tableItem:self];
            
    }
    
    
    if(self.isForwadedMessage) {
        self.forwardMessageAttributedString = [[NSMutableAttributedString alloc] init];
//        [self.forwardMessageAttributedString appendString:NSLocalizedString(@"Message.ForwardedFrom", nil) withColor:NSColorFromRGB(0x909090)];
        
        NSString *title = self.fwd_user ? self.fwd_user.fullName : self.fwd_chat.title;
        
        NSRange rangeUser = NSMakeRange(0, 0);
        if(title) {
            rangeUser = [self.forwardMessageAttributedString appendString:title withColor:LINK_COLOR];
            [self.forwardMessageAttributedString setLink:[TMInAppLinks peerProfile:self.message.fwd_from_id] forRange:rangeUser];
            
        }
        [self.forwardMessageAttributedString appendString:@"  " withColor:NSColorFromRGB(0x909090)];
    
        [self.forwardMessageAttributedString appendString:[TGDateUtils stringForLastSeen:self.message.fwd_date] withColor:NSColorFromRGB(0xbebebe)];
        
        [self.forwardMessageAttributedString setFont:[NSFont fontWithName:@"HelveticaNeue" size:12] forRange:self.forwardMessageAttributedString.range];
        [self.forwardMessageAttributedString setFont:[NSFont fontWithName:@"HelveticaNeue-Medium" size:13] forRange:rangeUser];
        [self.forwardMessageAttributedString addAttribute:NSParagraphStyleAttributeName value:style range:self.forwardMessageAttributedString.range];
    }
}

static NSTextAttachment *channelIconAttachment() {
    static NSTextAttachment *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [NSMutableAttributedString textAttachmentByImage:[image_newConversationBroadcast() imageWithInsets:NSEdgeInsetsMake(0, 1, 0, 4)]];
    });
    return instance;
}

- (void)setViewSize:(NSSize)viewSize {
    self._viewSize = viewSize;
}

- (NSSize)viewSize {
    NSSize viewSize = self._viewSize;
    
    if(!self.message.hole && ![self isKindOfClass:[MessageTableItemServiceMessage class]] && ![self isKindOfClass:[MessageTableItemUnreadMark class]] && ![self isKindOfClass:[MessageTableHeaderItem class]]) {
        if(self.isHeaderMessage) {
            viewSize.height += 32;
            
            if(self.isForwadedMessage)
                viewSize.height += 24;
            
            if(viewSize.height < 44)
                viewSize.height = 44;
        } else {
            viewSize.height += 10;
            
            if(self.isForwadedMessage)
                viewSize.height += 24;
        }
        
        if([self isReplyMessage]) {
            viewSize.height +=self.replyObject.containerHeight+10;
        }
        
        if(self.isForwadedMessage && self.isHeaderForwardedMessage)
            viewSize.height += FORWARMESSAGE_TITLE_HEIGHT;
    }
    
    
    return viewSize;
}

- (void) setBlockSize:(NSSize)blockSize {
    self->_blockSize = blockSize;
    
    self.viewSize = NSMakeSize(blockSize.width, blockSize.height);
}

+ (id) messageItemFromObject:(TL_localMessage *)message {
    id objectReturn = nil;

    
    if(message.class == [TL_localMessage_old34 class] || message.class == [TL_localMessage_old32 class] || message.class == [TL_localMessage class] || message.class == [TL_destructMessage class]) {
        
        
        if((message.media == nil || [message.media isKindOfClass:[TL_messageMediaEmpty class]]) || [message.media isMemberOfClass:[TL_messageMediaWebPage class]]) {
            
          objectReturn = [[MessageTableItemText alloc] initWithObject:message];
            
        } else if([message.media isKindOfClass:[TL_messageMediaUnsupported class]]) {
            
            message.message = @"This message is not supported on your version of Telegram. Update the app to view: https://telegram.org/dl/osx";
            objectReturn = [[MessageTableItemText alloc] initWithObject:message ];
            
        } else if([message.media isKindOfClass:[TL_messageMediaPhoto class]]) {
            
            objectReturn = [[MessageTableItemPhoto alloc] initWithObject:message ];
            
        } else if([message.media isKindOfClass:[TL_messageMediaVideo class]]) {

            objectReturn = [[MessageTableItemVideo alloc] initWithObject:message ];
            
        } else if([message.media isKindOfClass:[TL_messageMediaDocument class]]) {
            
            TLDocument *document = message.media.document;
            
            if([document.mime_type isEqualToString:@"image/gif"] && ![document.thumb isKindOfClass:[TL_photoSizeEmpty class]]) {
                objectReturn = [[MessageTableItemGif alloc] initWithObject:message];
            } else if([document.mime_type hasPrefix:@"audio/"]) {
                 objectReturn = [[MessageTableItemAudioDocument alloc] initWithObject:message];
            } else if([document isSticker]) {
                objectReturn = [[MessageTableItemSticker alloc] initWithObject:message];
            } else {
                 objectReturn = [[MessageTableItemDocument alloc] initWithObject:message];
            }
            
        } else if([message.media isKindOfClass:[TL_messageMediaContact class]]) {
            
            objectReturn = [[MessageTableItemContact alloc] initWithObject:message];
            
        } else if([message.media isKindOfClass:[TL_messageMediaGeo class]] || [message.media isKindOfClass:[TL_messageMediaVenue class]]) {
            
            objectReturn = [[MessageTableItemGeo alloc] initWithObject:message];
            
        } else if([message.media isKindOfClass:[TL_messageMediaAudio class]]) {
            
            objectReturn = [[MessageTableItemAudio alloc] initWithObject:message];
            
        }
    } else if(message.hole != nil) {
        objectReturn = [[MessageTableItemHole alloc] initWithObject:message];
    } else if([message isKindOfClass:[TL_localMessageService class]] || [message isKindOfClass:[TL_secretServiceMessage class]]) {
        objectReturn = [[MessageTableItemServiceMessage alloc] initWithObject:message ];
    }
    
    
    return objectReturn;
}

+(Class)socialClass:(NSString *)message {
    
    if(message == nil)
        return [NSNull class];
    
    NSDataDetector *detect = [[NSDataDetector alloc] initWithTypes:1ULL << 5 error:nil];
    
    
    NSArray *results = [detect matchesInString:message options:0 range:NSMakeRange(0, [message length])];

    
    if(results.count != 1)
        return [NSNull class];
    
    NSRange range = [results[0] range];
    
    if(range.location != 0 || range.length != message.length)
        return [NSNull class];

    // youtube checker
    
     NSString *vid = [YoutubeServiceDescription idWithURL:message];
    
    
    if(vid.length > 0)
        return [YoutubeServiceDescription class];
    
    
    NSString *iid = [InstagramServiceDescription idWithURL:message];
    
    if(iid.length > 0)
        return [InstagramServiceDescription class];
    
    return [NSNull class];
    
    
}

-(void)clean {
    [self.messageSender cancel];
    self.messageSender = nil;
    [self.downloadItem cancel];
    self.downloadItem = nil;
}

-(void)setDownloadItem:(DownloadItem *)downloadItem {
    self->_downloadItem = downloadItem;
    
    self.downloadListener = [[DownloadEventListener alloc] init];
    
    [self.downloadItem addEvent:self.downloadListener];
}

-(void)rebuildDate {
    self.date = [NSDate dateWithTimeIntervalSince1970:self.message.date];
    
    int time = self.message.date;
    time -= [[MTNetwork instance] getTime] - [[NSDate date] timeIntervalSince1970];
    
    self.dateStr = [TGDateUtils stringForMessageListDate:time];
    NSSize dateSize = [self.dateStr sizeWithAttributes:@{NSFontAttributeName: [NSFont fontWithName:@"HelveticaNeue" size:12]}];
    dateSize.width = roundf(dateSize.width);
    dateSize.height = roundf(dateSize.height);
    self.dateSize = dateSize;
    
    NSDateFormatter *formatter = [NSDateFormatter new];
    
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.message.date];
    
    self.fullDate = [formatter stringFromDate:date];
}


- (Class)downloadClass {
    return [NSNull class];
}

- (BOOL)canDownload {
    return NO;
}

- (BOOL)isset {
    return YES;
}

-(BOOL)canShare {
    return NO;
}

-(NSURL *)shareObject {
    return [NSURL fileURLWithPath:mediaFilePath(self.message.media)];;
}

- (BOOL)needUploader {
    return NO;
}

- (void)doAfterDownload {
 
}


- (void)checkStartDownload:(SettingsMask)setting size:(int)size {
    self.autoStart = [SettingsArchiver checkMaskedSetting:setting];
    
    if(size > [SettingsArchiver autoDownloadLimitSize])
        self.autoStart = NO;
    
    if(!self.downloadItem || self.downloadItem.downloadState == DownloadStateCompleted || self.downloadItem.downloadState == DownloadStateCanceled)
        if(![self isset])
            self.downloadItem = [[[self downloadClass] alloc] initWithObject:self.message];
    
    
    if((self.autoStart && !self.downloadItem && !self.isset) || (self.downloadItem && self.downloadItem.downloadState != DownloadStateCanceled)) {
        [self startDownload:NO force:NO];
    }
    
    
}

-(id)identifier {
    return @(self.message.n_id);
}


-(NSString *)string {
    return ((MessageTableItemText *)self).textAttributed.string;
}

- (void)startDownload:(BOOL)cancel force:(BOOL)force {
    
    if(!self.downloadItem) {
        self.downloadItem = [[[self downloadClass] alloc] initWithObject:self.message];
    }
    
    if((self.downloadItem.downloadState == DownloadStateCanceled || self.downloadItem.downloadState == DownloadStateWaitingStart) && (force || self.autoStart))
        [self.downloadItem start];
    
}


-(BOOL)isReplyMessage {
    return self.message.reply_to_msg_id != 0 && ![self.message.replyMessage isKindOfClass:[TL_localEmptyMessage class]];
}

-(BOOL)isFwdMessage {
    return self.message.fwd_from_id != 0;
}

- (BOOL)makeSizeByWidth:(int)width {
    _blockWidth = width;
    return NO;
}

-(int)fontSize {
    return [SettingsArchiver checkMaskedSetting:BigFontSetting] ? 15 : 13;
}

-(void)dealloc {

}


+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateF = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateF = [[NSDateFormatter alloc] init];
    });
    return dateF;
}

@end
