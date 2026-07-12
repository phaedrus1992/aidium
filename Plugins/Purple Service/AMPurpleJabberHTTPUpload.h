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

#import <Foundation/Foundation.h>

@class ESPurpleJabberAccount, ESFileTransfer;

NS_ASSUME_NONNULL_BEGIN

@interface AMPurpleJabberHTTPUpload : NSObject {
	ESPurpleJabberAccount *_account;

	// Discovery state
	NSString *_discoveryItemsID;
	NSMutableSet *_discoveryInfoIDs;
	NSString *_uploadServiceJID;
	long long _maxFileSize;

	// Slot request state
	NSString *_slotQueryID;

	// Upload state
	ESFileTransfer *_activeFileTransfer;
	NSURL *_getURL;
	NSURL *_putURL;
	NSURLSession *_session;
}

- (id)initWithAccount:(ESPurpleJabberAccount *)account;
- (void)startDiscovery;
- (BOOL)isUploadAvailableForFileSize:(unsigned long long)fileSize;
- (BOOL)sendFileTransfer:(ESFileTransfer *)fileTransfer;

@end

NS_ASSUME_NONNULL_END
