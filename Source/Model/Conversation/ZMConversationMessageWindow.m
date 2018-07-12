// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


#import "ZMConversation+Internal.h"
#import "ZMConversationMessageWindow.h"
#import "ZMConversationMessageWindow+Internal.h"
#import "ZMChangedIndexes.h"
#import "ZMOrderedSetState.h"
#import "ZMMessage+Internal.h"
#import "ZMOTRMessage.h"
#import <WireDataModel/WireDataModel-Swift.h>

@interface ZMConversationMessageWindow ()

- (instancetype)initWithConversation:(ZMConversation *)conversation size:(NSUInteger)size;

@property (nonatomic) NSUInteger size;
@property (nonatomic, readonly) NSMutableOrderedSet *mutableMessages;

@end


@implementation ZMConversationMessageWindow


- (instancetype)initWithConversation:(ZMConversation *)conversation size:(NSUInteger)size;
{
    self = [super init];
    if(self) {
        
        _conversation = conversation;
        _mutableMessages = [NSMutableOrderedSet orderedSet];
        
        self.size = size;
        
        // find first unread, offset size from there
        if (conversation.firstUnreadMessage != nil) {
            const NSUInteger firstUnreadIndex = [conversation.messages indexOfObject:conversation.firstUnreadMessage];
            self.size = MAX(0u, conversation.messages.count - firstUnreadIndex + size);
        }
            
        [self recalculateMessages];
        [conversation.managedObjectContext.messageWindowObserverCenter windowWasCreated: self];
    }
    return self;
}

- (void)dealloc
{
    if (self.conversation.managedObjectContext.zm_isValidContext) {
        [self.conversation.managedObjectContext.messageWindowObserverCenter removeMessageWindow: self];
    }
}


- (NSUInteger)activeSize;
{
    return MIN(self.size, self.conversation.messages.count);
}

- (NSOrderedSet *)messages
{
    return self.mutableMessages.reversedOrderedSet;
}

-(void)moveUpByMessages:(NSUInteger)amountOfMessages
{
    NSUInteger oldSize = self.activeSize;
    self.size += amountOfMessages;
    if(oldSize != self.activeSize) {
        [self recalculateMessages];
        [self.conversation.managedObjectContext.messageWindowObserverCenter windowDidScroll:self];
    }
}

-(void)moveDownByMessages:(NSUInteger)amountOfMessages
{
    NSUInteger oldSize = self.activeSize;
    self.size -= MIN(amountOfMessages, MAX(self.size, 1u) - 1u);
    if (oldSize != self.activeSize) {
        [self recalculateMessages];
    }
    
}

@end


@implementation ZMConversation (ConversationWindow)

- (ZMConversationMessageWindow *)conversationWindowWithSize:(NSUInteger)size
{
    ///TODO: recalc at this point?
    return [[ZMConversationMessageWindow alloc] initWithConversation:self size:size];
}

@end


