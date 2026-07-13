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
#import "TestAMPurpleJabberPubsubBookmarks.h"

#import "AMPurpleJabberPubsubBookmarks.h"

// Expose private XML-construction methods for testing
@interface AMPurpleJabberPubsubBookmarks (TestUtilities)

- (NSString *)_xmlForRetrieve;
- (NSString *)_xmlForPublishWithBookmarksXML:(NSString *)bookmarksXML;

@end

@implementation TestAMPurpleJabberPubsubBookmarks

- (void)testRetrieveXML
{
	AMPurpleJabberPubsubBookmarks *bookmarks = [[AMPurpleJabberPubsubBookmarks alloc] init];
	NSString *xml = [bookmarks _xmlForRetrieve];
	STAssertNotNil(xml, @"PubSub bookmarks retrieve XML should not be nil");
	STAssertTrue([xml rangeOfString:@"http://jabber.org/protocol/pubsub"].location != NSNotFound,
				 @"Retrieve stanza should contain PubSub namespace, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"urn:xmpp:bookmarks:1"].location != NSNotFound,
				 @"Retrieve stanza should contain bookmarks node name, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"type='get'"].location != NSNotFound,
				 @"Retrieve stanza should be an IQ-get, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"<items node="].location != NSNotFound,
				 @"Retrieve stanza should contain <items> element, got: %@", xml);
	[bookmarks release];
}

- (void)testPublishXML
{
	AMPurpleJabberPubsubBookmarks *bookmarks = [[AMPurpleJabberPubsubBookmarks alloc] init];
	NSString *conferenceXML =
		@"<conference xmlns='urn:xmpp:bookmarks:1' name='Test' jid='test@conference.example.org'/>";
	NSString *xml = [bookmarks _xmlForPublishWithBookmarksXML:conferenceXML];
	STAssertNotNil(xml, @"PubSub bookmarks publish XML should not be nil");
	STAssertTrue([xml rangeOfString:@"http://jabber.org/protocol/pubsub"].location != NSNotFound,
				 @"Publish stanza should contain PubSub namespace, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"urn:xmpp:bookmarks:1"].location != NSNotFound,
				 @"Publish stanza should contain bookmarks node name, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"type='set'"].location != NSNotFound,
				 @"Publish stanza should be an IQ-set, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"<publish node="].location != NSNotFound,
				 @"Publish stanza should contain <publish> element, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"item id='current'"].location != NSNotFound,
				 @"Publish stanza should contain item element with id='current', got: %@", xml);
	[bookmarks release];
}

- (void)testPublishXMLWithConference
{
	AMPurpleJabberPubsubBookmarks *bookmarks = [[AMPurpleJabberPubsubBookmarks alloc] init];
	NSString *conferenceXML = @"<conference xmlns='urn:xmpp:bookmarks:1' name='Development Chat' autojoin='true' "
							  @"jid='dev@conference.example.org'>"
							  @"<nick>Phaedrus</nick>"
							  @"</conference>"
							  @"<conference xmlns='urn:xmpp:bookmarks:1' name='Support' autojoin='false' "
							  @"jid='support@conference.example.com'/>";
	NSString *xml = [bookmarks _xmlForPublishWithBookmarksXML:conferenceXML];
	STAssertNotNil(xml, @"PubSub bookmarks publish XML should not be nil");
	STAssertTrue([xml rangeOfString:@"dev@conference.example.org"].location != NSNotFound,
				 @"Publish stanza should contain conference JID, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"Phaedrus"].location != NSNotFound,
				 @"Publish stanza should contain conference nick, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"support@conference.example.com"].location != NSNotFound,
				 @"Publish stanza should contain second conference JID, got: %@", xml);
	[bookmarks release];
}

@end
