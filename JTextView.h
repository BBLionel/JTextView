//
//  JTextView.h
//  JKit
//
//  Created by Jeremy Tregunna on 10-10-24.
//  Copyright (c) 2010 Jeremy Tregunna. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import "JTextCaret.h"


@class JTextView;


@protocol JTextViewDelegate
@optional
- (void)jTextView:(JTextView*)textView didReceiveURL:(NSURL*)url range:(NSRange)range;
- (void)jTextView:(JTextView*)textView didReceivePhoneNumber:(NSString*)phoneNumber range:(NSRange)range;
- (void)jTextView:(JTextView*)textView didReceiveAddress:(NSDictionary*)addressComponents range:(NSRange)range;
@end


@interface JTextView : UIScrollView <UIKeyInput>
{
	NSMutableAttributedString* _textStore;
	UIColor* _textColor;
	UIFont* _font;
	BOOL _editable;
	
	UIDataDetectorTypes _dataDetectorTypes;

	id<JTextViewDelegate> _delegate;

@private
	JTextCaret* caret;
	CTFrameRef textFrame;
}


@property (nonatomic, retain) NSMutableAttributedString* attributedText;
@property (nonatomic, retain) UIColor* textColor;
@property (nonatomic, retain) UIFont* font;
@property (nonatomic, getter=isEditable) BOOL editable;
@property (nonatomic) UIDataDetectorTypes dataDetectorTypes;
@property (assign) id<JTextViewDelegate> delegate;


@end
