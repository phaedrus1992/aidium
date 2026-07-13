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

@class ESPurpleJabberAccount;

NS_ASSUME_NONNULL_BEGIN

/// XEP-0048 Bookmarks
///
/// Stores and retrieves conference room bookmarks using Private XML Storage
/// (XEP-0049). Bookmarks are persisted as a \c <storage> element in the
/// \c storage:bookmarks namespace.
@interface AMPurpleJabberBookmarks : NSObject {
	ESPurpleJabberAccount *_account;
}

/// Initialize with the owning Jabber account.
///
/// @param account The ESPurpleJabberAccount that owns this controller
/// @return An initialized instance
- (id)initWithAccount:(ESPurpleJabberAccount *)account;

/// Retrieve stored bookmarks from the server via Private XML Storage.
- (void)retrieveBookmarks;

/// Store a set of bookmarks on the server via Private XML Storage.
///
/// @param xml The XML string containing the \c <storage> element
- (void)storeBookmarksWithXML:(NSString *)xml;

@end

NS_ASSUME_NONNULL_END
