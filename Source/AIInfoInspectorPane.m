/*
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AIInfoInspectorPane.h"
#import "AIContactInfoImageViewWithImagePicker.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIDelayedTextField.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AITextAttributes.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIStatusIcons.h>
#import <Contacts/Contacts.h>

#define WIDTH_PROFILE_HEADER 100.0f

@interface AIInfoInspectorPane ()
- (void)updateUserIcon:(AIListObject *)inObject;
- (void)updateAccountName:(AIListObject *)inObject;
- (void)updateStatusIcon:(AIListObject *)inObject;
- (void)updateAlias:(AIListObject *)inObject;
- (void)addAddressBookInfoToProfileArray:(NSMutableArray *)profileArray forContact:(AIListContact *)inContact;
- (void)addTooltipEntriesToProfileArray:(NSMutableArray *)profileArray forContact:(AIListContact *)inContact;
- (NSAttributedString *)attributedStringProfileForListObject:(AIListObject *)inObject;
- (void)updateProfile:(NSAttributedString *)infoString context:(AIListObject *)object;
- (void)setAttributedString:(NSAttributedString *)infoString intoTextView:(NSTextView *)textView;
@end

@implementation AIInfoInspectorPane

- (id)init
{
	self = [super init];
	if (self != nil) {
		// Load Bundle
		[NSBundle loadNibNamed:[self nibName] owner:self];
		// Register as AIListObjectObserver
		[[AIContactObserverManager sharedManager] registerListObjectObserver:self];
		// Setup for userIcon
		[userIcon setAnimates:YES];
		[userIcon setMaxSize:NSMakeSize(256, 256)];
		[userIcon setDelegate:self];

		[aliasLabel setLocalizedString:
						AILocalizedString(
							@"Alias:",
							"Label beside the field for a contact's alias in the settings tab of the Get Info window")];
	}
	return self;
}

- (void)dealloc
{
	[inspectorContentView release];

	[[AIContactObserverManager sharedManager] unregisterListObjectObserver:self];

	[super dealloc];
}

- (NSView *)inspectorContentView
{
	return inspectorContentView;
}

- (NSString *)nibName
{
	return @"AIInfoInspectorPane";
}

- (void)updateForListObject:(AIListObject *)inObject
{
	[contactAlias fireImmediately];

	displayedObject = inObject;

	[self updateProfile:nil context:inObject];

	[self updateUserIcon:inObject];
	[self updateAccountName:inObject];
	[self updateStatusIcon:inObject];
	[self updateAlias:inObject];

	if ([inObject isKindOfClass:[AIListContact class]] && ![inObject isKindOfClass:[AIListBookmark class]]) {
		[[AIContactObserverManager sharedManager] updateListContactStatus:(AIListContact *)inObject];

		[profileProgress startAnimation:self];
		[profileProgress setHidden:NO];

		[self updateProfile:[self attributedStringProfileForListObject:inObject] context:inObject];
	}
}

- (void)updateUserIcon:(AIListObject *)inObject
{
	NSImage *currentIcon;
	NSSize userIconSize, imagePickerSize;

	// User Icon
	if (!(currentIcon = [inObject userIcon])) {
		currentIcon = [NSImage imageNamed:@"default-icon" forClass:[self class]];
	}

	/* NSScaleProportionally will lock an animated GIF into a single frame.  We therefore use NSScaleNone if
	 * we are already at the right size or smaller than the right size; otherwise we scale proportionally to
	 * fit the frame.
	 */
	userIconSize = [currentIcon size];
	imagePickerSize = [userIcon frame].size;

	[userIcon setImageScaling:(((userIconSize.width <= imagePickerSize.width) &&
								(userIconSize.height <= imagePickerSize.height))
								   ? NSScaleNone
								   : NSScaleProportionally)];
	[userIcon setImage:currentIcon];
	[userIcon
		setTitle:(inObject ? [NSString stringWithFormat:AILocalizedString(@"%@'s Image", nil), inObject.displayName]
						   : AILocalizedString(@"Image Picker", nil))];

	// Show the reset image button if a preference is set on this object, overriding its serverside icon
	[userIcon setShowResetImageButton:([inObject preferenceForKey:KEY_USER_ICON group:PREF_GROUP_USERICONS] != nil)];
}

- (void)updateAccountName:(AIListObject *)inObject
{
	if (!inObject) {
		[accountName setStringValue:@""];
		return;
	}

	NSString *displayName = inObject.formattedUID;

	if (!displayName) {
		displayName = inObject.displayName;
	}

	[accountName setStringValue:displayName];
}

- (void)updateStatusIcon:(AIListObject *)inObject
{
	if ([inObject isKindOfClass:[AIListGroup class]]) {
		[statusImage setHidden:YES];
	} else {
		[statusImage setHidden:NO];
		[statusImage setImage:[AIStatusIcons statusIconForListObject:inObject
																type:AIStatusIconList
														   direction:AIIconNormal]];
	}
}

#define KEY_KEY @"Key"
#define KEY_VALUE @"Value"
#define KEY_TYPE @"Type"

- (void)addAttributedString:(NSAttributedString *)string
					toTable:(NSTextTable *)table
						row:(NSInteger)row
						col:(NSInteger)col
					colspan:(NSInteger)colspan
					 header:(BOOL)header
					  color:(NSColor *)color
				  alignment:(NSTextAlignment)alignment
		 toAttributedString:(NSMutableAttributedString *)text
{
	NSTextTableBlock *block = [[NSTextTableBlock alloc] initWithTable:table
														  startingRow:row
															  rowSpan:1
													   startingColumn:col
														   columnSpan:colspan];
	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

	NSInteger textLength = [text length];

	[block setVerticalAlignment:NSTextBlockTopAlignment];

	[block setWidth:5.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinYEdge];
	[block setWidth:5.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMaxYEdge];
	[block setWidth:1.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];
	[block setWidth:5.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMaxXEdge];

	if (col == 0 && !header && colspan == 1) {
		[block setValue:WIDTH_PROFILE_HEADER type:NSTextBlockAbsoluteValueType forDimension:NSTextBlockWidth];
	}

	[style setTextBlocks:[NSArray arrayWithObject:block]];

	[style setAlignment:alignment];

	[text appendAttributedString:string];
	[text appendAttributedString:[NSAttributedString stringWithString:@"\n"]];

	if (header) {
		[text addAttribute:NSFontAttributeName
					 value:[NSFont boldSystemFontOfSize:13]
					 range:NSMakeRange(textLength, [text length] - textLength)];
		[block setWidth:1.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder edge:NSMaxYEdge];
		[block setBorderColor:[NSColor darkGrayColor]];
	}

	if (color) {
		[text addAttribute:NSForegroundColorAttributeName
					 value:color
					 range:NSMakeRange(textLength, [text length] - textLength)];
	}
	[text addAttribute:NSParagraphStyleAttributeName
				 value:style
				 range:NSMakeRange(textLength, [text length] - textLength)];

	[style release];
	[block release];
}

- (NSMutableArray *)metaContactProfileArrayForContact:(AIMetaContact *)metaContact
{
	NSMutableArray *array = [NSMutableArray array];
	NSMutableDictionary *addedKeysDict = [NSMutableDictionary dictionary];
	NSMutableDictionary *ownershipDict = [NSMutableDictionary dictionary];

	NSArray *contacts =
		metaContact.online ? metaContact.uniqueContainedObjects : metaContact.listContactsIncludingOfflineAccounts;

	for (AIListContact *listContact in contacts) {
		// If one or more contacts are online, skip offline ones
		if (metaContact.online && !listContact.online)
			continue;

		for (NSDictionary *lineDict in listContact.profileArray) {
			NSString *key = [lineDict objectForKey:KEY_KEY];
			AIUserInfoEntryType entryType = [[lineDict objectForKey:KEY_TYPE] intValue];
			NSInteger insertionIndex = -1;

			switch (entryType) {
			case AIUserInfoSectionBreak:
				/* Skip double section breaks */
				if ([[[array lastObject] objectForKey:KEY_TYPE] integerValue] == AIUserInfoSectionBreak)
					continue;
				break;
			case AIUserInfoSectionHeader:
				/* Use the most recent header if we have multiple headers in a row */
				if ([[[array lastObject] objectForKey:KEY_TYPE] integerValue] == AIUserInfoSectionHeader)
					[array removeLastObject];
				break;
			case AIUserInfoLabelValuePair:
				/* No action needed */
				break;
			}

			if (key) {
				NSMutableSet *previousDictValuesOnThisKey = [addedKeysDict objectForKey:key];
				if (previousDictValuesOnThisKey) {
					/* If any previously added dictionary has the same key and value as the this new one, skip this new
					 * one entirely */
					NSSet *existingValues = [previousDictValuesOnThisKey
						valueForKeyPath:[@"nonretainedObjectValue." stringByAppendingString:KEY_VALUE]];
					if ([existingValues containsObject:[lineDict valueForKey:KEY_VALUE]])
						continue;

					for (NSValue *prevDictValue in [[previousDictValuesOnThisKey copy] autorelease]) {
						NSDictionary *prevDict = [prevDictValue nonretainedObjectValue];
						NSMutableDictionary *newDict = [prevDict mutableCopy];
						AIListContact *ownerOfPrevDict =
							[[ownershipDict objectForKey:prevDictValue] nonretainedObjectValue];
						if (ownerOfPrevDict) {
							[newDict setObject:[NSString stringWithFormat:AILocalizedString(@"%@'s %@", nil),
																		  ownerOfPrevDict.formattedUID, key]
										forKey:KEY_KEY];
						}

						// Array of dicts which will be returned
						insertionIndex = [array indexOfObjectIdenticalTo:prevDict];
						[array replaceObjectAtIndex:insertionIndex withObject:newDict];

						// Known dictionaries on this key
						[previousDictValuesOnThisKey removeObject:prevDictValue];
						[previousDictValuesOnThisKey addObject:[NSValue valueWithNonretainedObject:newDict]];

						// Ownership of new dictionary
						[ownershipDict removeObjectForKey:prevDictValue];
						[ownershipDict setObject:[NSValue valueWithNonretainedObject:newDict]
										  forKey:[NSValue valueWithNonretainedObject:ownerOfPrevDict]];
						[newDict release];
					}

					NSMutableDictionary *newDict = [lineDict mutableCopy];
					[newDict
						setObject:[NSString stringWithFormat:AILocalizedString(
																 @"%@'s %@",
																 "(name)'s (information type), e.g. tekjew's status"),
															 listContact.formattedUID, key]
						   forKey:KEY_KEY];
					lineDict = [newDict autorelease];

					[previousDictValuesOnThisKey addObject:[NSValue valueWithNonretainedObject:lineDict]];

				} else {
					[addedKeysDict setObject:[NSMutableSet setWithObject:[NSValue valueWithNonretainedObject:lineDict]]
									  forKey:key];
				}
			}

			if (lineDict) {
				if (insertionIndex != -1) {
					// Group items with the same key together
					if ([[[array objectAtIndex:insertionIndex] objectForKey:KEY_KEY]
							compare:[lineDict objectForKey:KEY_KEY]] == NSOrderedAscending)
						insertionIndex++;

					[array insertObject:lineDict atIndex:insertionIndex];
				} else {
					[array addObject:lineDict];
				}

				[ownershipDict setObject:[NSValue valueWithNonretainedObject:listContact]
								  forKey:[NSValue valueWithNonretainedObject:lineDict]];
			}
		}
	}

	return array;
}

- (void)removeDuplicateEntriesFromProfileArray:(NSMutableArray *)array
{
	NSInteger i;
	NSUInteger count = [array count];
	for (i = 0; i < (count - 1); i++) {
		NSDictionary *lineDict = [array objectAtIndex:i];
		// Look only for label/value pairs
		if ([[lineDict objectForKey:KEY_TYPE] integerValue] == AIUserInfoLabelValuePair) {
			NSInteger j;
			NSString *thisKey = [[lineDict objectForKey:KEY_KEY] lowercaseString];
			for (j = i + 1; j < count; j++) {
				NSDictionary *otherLineDict = [array objectAtIndex:j];

				if (([[otherLineDict objectForKey:KEY_TYPE] integerValue] == AIUserInfoLabelValuePair) &&
					[[[otherLineDict objectForKey:KEY_KEY] lowercaseString] isEqualToString:thisKey]) {
					/* Same key. Compare values, which may be NSString or NSAttributedString objects */
					id thisValue = [lineDict objectForKey:KEY_VALUE];
					id otherValue = [otherLineDict objectForKey:KEY_VALUE];

					if ([thisValue isKindOfClass:[otherValue class]]) {
						/* Same class. Compare directly. */
						if ([thisValue isEqual:otherValue]) {
							[array removeObjectAtIndex:j];
							count--;
						}
					} else {
						/* Different class. Go to NSAttributedString to compare. */
						NSAttributedString *thisAttributedValue =
							([thisValue isKindOfClass:[NSAttributedString class]]
								 ? thisValue
								 : (thisValue ? [NSAttributedString stringWithString:thisValue] : nil));
						NSAttributedString *otherAttributedValue =
							([otherValue isKindOfClass:[NSAttributedString class]]
								 ? otherValue
								 : (otherValue ? [NSAttributedString stringWithString:otherValue] : nil));
						if ([thisAttributedValue isEqualToAttributedString:otherAttributedValue]) {
							[array removeObjectAtIndex:j];
							count--;
						}
					}
				}
			}
		}
	}
}

- (NSAttributedString *)attributedStringProfileForListObject:(AIListObject *)inObject
{
	NSMutableArray *profileArray;

	// We don't know what to do for non-list contacts.
	if (![inObject isKindOfClass:[AIListContact class]]) {
		return [NSAttributedString stringWithString:@""];
	}

	// XXX Case out if we only have HTML (nothing currently does this)

	if ([inObject isKindOfClass:[AIMetaContact class]]) {
		profileArray = [self metaContactProfileArrayForContact:(AIMetaContact *)inObject];
	} else {
		profileArray = [[[(AIListContact *)inObject profileArray] mutableCopy] autorelease];
	}

	if (!profileArray)
		profileArray = [NSMutableArray array];

	[self addTooltipEntriesToProfileArray:profileArray forContact:(AIListContact *)inObject];
	[self addAddressBookInfoToProfileArray:profileArray forContact:(AIListContact *)inObject];

	// Don't do anything if we have nothing to display.
	if ([profileArray count] == 0) {
		AILogWithSignature(@"No profile array items found for %@", inObject);
		return [NSAttributedString stringWithString:@""];
	}

	[self removeDuplicateEntriesFromProfileArray:profileArray];

	// Create the table
	NSTextTable *table = [[[NSTextTable alloc] init] autorelease];

	[table setNumberOfColumns:2];
	[table setLayoutAlgorithm:NSTextTableAutomaticLayoutAlgorithm];
	[table setHidesEmptyCells:YES];

	NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
	NSEnumerator *enumerator = [profileArray objectEnumerator];
	NSDictionary *lineDict;

	BOOL shownAnyContent = NO;

	for (NSInteger row = 0; (lineDict = [enumerator nextObject]); row++) {
		if ([[lineDict objectForKey:KEY_TYPE] integerValue] == AIUserInfoSectionBreak && shownAnyContent == NO) {
			continue;
		}

		NSAttributedString *value = nil, *key = nil;

		if ([lineDict objectForKey:KEY_VALUE]) {
			id theValue = [lineDict objectForKey:KEY_VALUE];
			if ([theValue isKindOfClass:[NSString class]]) {
				value = [AIHTMLDecoder decodeHTML:(NSString *)theValue];
			} else if ([theValue isKindOfClass:[NSAttributedString class]]) {
				value = (NSAttributedString *)theValue;
			} else {
				NSLog(@"*** WARNING! Invalid value passed in profile array: %@", lineDict);
			}

			value = [adium.contentController filterAttributedString:value
													usingFilterType:AIFilterDisplay
														  direction:AIFilterIncoming
															context:inObject];
		}

		if ([lineDict objectForKey:KEY_KEY]) {
			// We don't need to filter the key.
			key = [NSAttributedString stringWithString:[[lineDict objectForKey:KEY_KEY] lowercaseString]];
		}

		switch ([[lineDict objectForKey:KEY_TYPE] integerValue]) {
		case AIUserInfoLabelValuePair:
			if (key) {
				[self addAttributedString:key
								  toTable:table
									  row:row
									  col:0
								  colspan:1
								   header:NO
									color:[NSColor grayColor]
								alignment:NSRightTextAlignment
					   toAttributedString:result];
			}

			if (value) {
				[self addAttributedString:value
								  toTable:table
									  row:row
									  col:(key ? 1 : 0)colspan
										 :(key ? 1 : 2) /* If there's no key, we need to fill both columns. */
								   header:NO
									color:nil
								alignment:NSLeftTextAlignment
					   toAttributedString:result];
			}
			break;

		case AIUserInfoSectionHeader:
			[self addAttributedString:key
							  toTable:table
								  row:row
								  col:0
							  colspan:2
							   header:YES
								color:[NSColor darkGrayColor]
							alignment:NSLeftTextAlignment
				   toAttributedString:result];
			break;

		case AIUserInfoSectionBreak:
			[self addAttributedString:[NSAttributedString stringWithString:@" "]
							  toTable:table
								  row:row
								  col:0
							  colspan:2
							   header:NO
								color:[NSColor controlTextColor]
							alignment:NSLeftTextAlignment
				   toAttributedString:result];
			break;
		}

		shownAnyContent = YES;
	}

	return result;
}

- (void)updateAlias:(AIListObject *)inObject
{
	NSString *currentAlias = nil;

	if ([inObject isKindOfClass:[AIListContact class]]) {
		AIListContact *parentContact = [(AIListContact *)inObject parentContact];

		currentAlias = [parentContact preferenceForKey:@"Alias" group:PREF_GROUP_ALIASES];

		if (inObject == parentContact) {
			AILogWithSignature(@"%@: current alias %@.", inObject, currentAlias);

		} else {
			AILogWithSignature(@"updating alias for %@; parent %@ --> current alias %@.", inObject,
							   [(AIListContact *)inObject parentContact], currentAlias);
		}
	} else {
		currentAlias = [inObject preferenceForKey:@"Alias" group:PREF_GROUP_ALIASES];
	}

	if (!currentAlias && ![inObject.displayName isEqualToString:inObject.formattedUID]) {
		[[contactAlias cell] setPlaceholderString:inObject.displayName];
	} else {
		[[contactAlias cell] setPlaceholderString:nil];
	}

	// Fill in the current alias
	if (currentAlias) {
		[contactAlias setStringValue:currentAlias];
	} else {
		[contactAlias setStringValue:@""];
	}
}

- (IBAction)setAlias:(id)sender
{
	if (!displayedObject)
		return;

	AIListObject *contactToUpdate = displayedObject;

	if ([contactToUpdate isKindOfClass:[AIListContact class]]) {
		contactToUpdate = [(AIListContact *)contactToUpdate parentContact];
	}

	NSString *currentAlias = [contactAlias stringValue];
	[contactToUpdate setDisplayName:currentAlias];

	[self updateAccountName:displayedObject];
}

- (void)updateProfile:(NSAttributedString *)infoString context:(AIListObject *)object
{
	if (infoString) {
		[profileProgress stopAnimation:self];
		[profileProgress setHidden:YES];
	}

	[self setAttributedString:infoString intoTextView:profileView];
}

- (void)setAttributedString:(NSAttributedString *)infoString intoTextView:(NSTextView *)textView
{
	NSColor *backgroundColor = nil;

	if (infoString && [infoString length]) {
		[[textView textStorage] setAttributedString:infoString];
		backgroundColor = [infoString attribute:AIBodyColorAttributeName
										atIndex:0
						  longestEffectiveRange:nil
										inRange:NSMakeRange(0, [infoString length])];
	} else {
		[[textView textStorage] setAttributedString:[NSAttributedString stringWithString:@""]];
	}
	[textView setInsertionPointColor:(backgroundColor ? backgroundColor : [NSColor whiteColor])];
	[textView setBackgroundColor:(backgroundColor ? backgroundColor : [NSColor whiteColor])];
	[[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:textView];
}

- (NSSet *)updateListObject:(AIListObject *)inObject keys:(NSSet *)inModifiedKeys silent:(BOOL)silent
{
	// Update if our object or an object contained by our metacontact (if applicable) was updated
	if ([displayedObject isKindOfClass:[AIMetaContact class]] &&
		((inObject != displayedObject) && ![(AIMetaContact *)displayedObject containsObject:inObject]))
		return nil;
	else if (inObject != displayedObject)
		return nil;

	// Update the status icon if it changes.
	if (inModifiedKeys == nil || [inModifiedKeys containsObject:@"isOnline"] ||
		[inModifiedKeys containsObject:@"idleSince"] || [inModifiedKeys containsObject:@"signedOff"] ||
		[inModifiedKeys containsObject:@"isMobile"] || [inModifiedKeys containsObject:@"IsBlocked"] ||
		[inModifiedKeys containsObject:@"listObjectStatusType"]) {
		[self updateStatusIcon:displayedObject];
	}

	// Update the profile if it changes.
	if (inModifiedKeys == nil || [inModifiedKeys containsObject:@"ProfileArray"]) {
		[self updateProfile:[self attributedStringProfileForListObject:displayedObject] context:displayedObject];
	}

	// Cause everything to update if everything's probably changed.
	if ([inModifiedKeys containsObject:@"notAStranger"] || [inModifiedKeys containsObject:@"serverDisplayName"]) {
		[self updateForListObject:displayedObject];
	}

	return nil;
}

#pragma mark AIImageViewWithImagePicker Delegate
// AIImageViewWithImagePicker Delegate ---------------------------------------------------------------------
- (void)imageViewWithImagePicker:(AIImageViewWithImagePicker *)sender didChangeToImageData:(NSData *)imageData
{
	if (displayedObject) {
		[displayedObject setUserIconData:imageData];
	}

	[self updateUserIcon:displayedObject];
}

- (void)deleteInImageViewWithImagePicker:(AIImageViewWithImagePicker *)sender
{
	if (displayedObject) {
		// Remove the preference
		[displayedObject setUserIconData:nil];

		[self updateUserIcon:displayedObject];
	}
}

/*
 If the userIcon was bigger than our image view's frame, it will have been clipped before being passed
 to the AIImageViewWithImagePicker.  This delegate method lets us pass the original, unmodified userIcon.
 */
- (NSImage *)imageForImageViewWithImagePicker:(AIImageViewWithImagePicker *)picker
{
	return ([displayedObject userIcon]);
}

- (NSImage *)emptyPictureImageForImageViewWithImagePicker:(AIImageViewWithImagePicker *)picker
{
	return [AIServiceIcons serviceIconForObject:displayedObject type:AIServiceIconLarge direction:AIIconNormal];
}

- (NSString *)fileNameForImageInImagePicker:(AIImageViewWithImagePicker *)picker
{
	NSString *fileName = [displayedObject.displayName safeFilenameString];
	if ([fileName hasPrefix:@"."]) {
		fileName = [fileName substringFromIndex:1];
	}
	return fileName;
}

#pragma mark Address Book

- (void)addAddressBookInfoToProfileArray:(NSMutableArray *)profileArray forContact:(AIListContact *)inContact
{
	CNContact *person = [inContact contactPerson];
	if (person == nil) {
		return;
	}

	// Fetch the contact with keys needed for profile display
	CNContactStore *store = [[CNContactStore alloc] init];
	NSArray *keys = @[
		CNContactNamePrefixKey, CNContactGivenNameKey, CNContactMiddleNameKey, CNContactFamilyNameKey,
		CNContactNameSuffixKey, CNContactJobTitleKey, CNContactDepartmentNameKey, CNContactOrganizationNameKey,
		CNContactUrlAddressesKey, CNContactEmailAddressesKey, CNContactPhoneNumbersKey, CNContactPostalAddressesKey,
		CNContactBirthdayKey, CNContactDatesKey, CNContactRelatedNamesKey
	];

	NSError *error = nil;
	CNContact *fullPerson = [store unifiedContactWithIdentifier:person.identifier keysToFetch:keys error:&error];
	if (fullPerson == nil) {
		AILogWithSignature(@"Error fetching contact for profile: %@", error);
		[store release];
		return;
	}

	// Build full name from components
	NSMutableString *name = [NSMutableString string];
	if ([fullPerson.namePrefix length] > 0) {
		[name appendString:fullPerson.namePrefix];
		if ([fullPerson.givenName length] > 0 || [fullPerson.middleName length] > 0 ||
			[fullPerson.familyName length] > 0) {
			[name appendString:@" "];
		}
	}
	if ([fullPerson.givenName length] > 0) {
		[name appendString:fullPerson.givenName];
		if ([fullPerson.middleName length] > 0 || [fullPerson.familyName length] > 0) {
			[name appendString:@" "];
		}
	}
	if ([fullPerson.middleName length] > 0) {
		[name appendString:fullPerson.middleName];
		if ([fullPerson.familyName length] > 0) {
			[name appendString:@" "];
		}
	}
	if ([fullPerson.familyName length] > 0) {
		[name appendString:fullPerson.familyName];
	}
	if ([fullPerson.nameSuffix length] > 0) {
		if ([name length] > 0) {
			[name appendString:@", "];
		}
		[name appendString:fullPerson.nameSuffix];
	}

	if ([name length] > 0) {
		[profileArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:AILocalizedString(@"Full Name", nil),
																		   KEY_KEY, name, KEY_VALUE, nil]];
	}

	// Single-value properties
	NSDictionary *labelMap = [[NSDictionary alloc]
		initWithObjectsAndKeys:AILocalizedString(@"Job Title", nil), CNContactJobTitleKey,
							   AILocalizedString(@"Department", nil), CNContactDepartmentNameKey,
							   AILocalizedString(@"Organization", nil), CNContactOrganizationNameKey, nil];
	for (NSString *key in labelMap) {
		NSString *value = [fullPerson valueForKey:key];
		if ([value length] > 0) {
			[profileArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:[labelMap objectForKey:key], KEY_KEY,
																			   value, KEY_VALUE, nil]];
		}
	}
	[labelMap release];

	// Email addresses
	for (CNLabeledValue *labeledValue in fullPerson.emailAddresses) {
		NSString *label = [labeledValue label];
		NSString *value = (NSString *)[labeledValue value];
		if ([value length] > 0) {
			NSString *propertyName = AILocalizedString(@"Email", nil);
			NSString *key = (label != nil) ? [NSString stringWithFormat:@"%@ (%@)", propertyName, label] : propertyName;
			[profileArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, KEY_KEY, value, KEY_VALUE, nil]];
		}
	}

	// Phone numbers
	for (CNLabeledValue *labeledValue in fullPerson.phoneNumbers) {
		NSString *label = [labeledValue label];
		NSString *value = [(CNPhoneNumber *)[labeledValue value] stringValue];
		if ([value length] > 0) {
			NSString *propertyName = AILocalizedString(@"Phone", nil);
			NSString *key = (label != nil) ? [NSString stringWithFormat:@"%@ (%@)", propertyName, label] : propertyName;
			[profileArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, KEY_KEY, value, KEY_VALUE, nil]];
		}
	}

	// URLs
	for (CNLabeledValue *labeledValue in fullPerson.urlAddresses) {
		NSString *label = [labeledValue label];
		NSString *value = (NSString *)[labeledValue value];
		if ([value length] > 0) {
			NSString *propertyName = AILocalizedString(@"Home Page", nil);
			NSString *key = (label != nil) ? [NSString stringWithFormat:@"%@ (%@)", propertyName, label] : propertyName;
			[profileArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, KEY_KEY, value, KEY_VALUE, nil]];
		}
	}

	// Postal addresses
	for (CNLabeledValue *labeledValue in fullPerson.postalAddresses) {
		NSString *label = [labeledValue label];
		NSString *value =
			[CNPostalAddressFormatter stringFromPostalAddress:(CNPostalAddress *)[labeledValue value]
														style:CNPostalAddressFormatterStyleMailingAddress];
		if ([value length] > 0) {
			NSString *propertyName = AILocalizedString(@"Address", nil);
			NSString *key = (label != nil) ? [NSString stringWithFormat:@"%@ (%@)", propertyName, label] : propertyName;
			[profileArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, KEY_KEY, value, KEY_VALUE, nil]];
		}
	}

	// Birthday
	if (fullPerson.birthday != nil) {
		NSDateComponents *components = fullPerson.birthday;
		NSCalendar *calendar =
			[NSCalendar calendarWithIdentifier:([components calendar] ?: NSCalendarIdentifierGregorian)];
		NSDate *birthdayDate = [calendar dateFromComponents:components];
		if (birthdayDate != nil) {
			NSString *formattedDate = [NSDateFormatter localizedStringFromDate:birthdayDate
																	 dateStyle:NSDateFormatterMediumStyle
																	 timeStyle:NSDateFormatterNoStyle];
			[profileArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:AILocalizedString(@"Birthday", nil),
																			   KEY_KEY, formattedDate, KEY_VALUE, nil]];
		}
	}

	// Other dates
	for (CNLabeledValue *labeledValue in fullPerson.dates) {
		NSString *label = [labeledValue label];
		NSDateComponents *components = (NSDateComponents *)[labeledValue value];
		NSCalendar *calendar =
			[NSCalendar calendarWithIdentifier:([components calendar] ?: NSCalendarIdentifierGregorian)];
		NSDate *date = [calendar dateFromComponents:components];
		if (date != nil) {
			NSString *formattedDate = [NSDateFormatter localizedStringFromDate:date
																	 dateStyle:NSDateFormatterMediumStyle
																	 timeStyle:NSDateFormatterNoStyle];
			NSString *propertyName = AILocalizedString(@"Date", nil);
			NSString *key = (label != nil) ? [NSString stringWithFormat:@"%@ (%@)", propertyName, label] : propertyName;
			[profileArray
				addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, KEY_KEY, formattedDate, KEY_VALUE, nil]];
		}
	}

	// Related names
	for (CNLabeledValue *labeledValue in fullPerson.relatedNames) {
		NSString *label = [labeledValue label];
		NSString *value = (NSString *)[labeledValue value];
		if ([value length] > 0) {
			NSString *propertyName = AILocalizedString(@"Related Name", nil);
			NSString *key = (label != nil) ? [NSString stringWithFormat:@"%@ (%@)", propertyName, label] : propertyName;
			[profileArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, KEY_KEY, value, KEY_VALUE, nil]];
		}
	}

	// Note: CNContactNoteKey requires restricted entitlement — intentionally excluded
	// per Contacts.framework migration spec (§3.5)

	[store release];
}

- (void)addTooltipEntriesToProfileArray:(NSMutableArray *)profileArray forContact:(AIListContact *)inContact
{
	NSArray *tooltipEntries = [[adium.interfaceController contactListTooltipPrimaryEntries]
		arrayByAddingObjectsFromArray:[adium.interfaceController contactListTooltipSecondaryEntries]];
	for (id<AIContactListTooltipEntry> tooltipEntry in tooltipEntries) {
		if ([tooltipEntry shouldDisplayInContactInspector]) {
			id label, value;
			if ((label = [tooltipEntry labelForObject:inContact]) &&
				(value = [tooltipEntry entryForObject:inContact])) {
				[profileArray
					addObject:[NSDictionary dictionaryWithObjectsAndKeys:label, KEY_KEY, value, KEY_VALUE, nil]];
			}
		}
	}
}

@end
