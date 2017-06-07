--[[----------------------------------------------------------------------------

Lightroom2Tumblr

Info.lua - Declarations for the Tumblr plugin

Copyright (c) 2012-2017 by Guido Hoss.

Lightroom2Tumblr is free software: you can redistribute it and/or 
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation, either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public
License along with this program.  If not, see
<http://www.gnu.org/licenses/>.

Git repository home: <https://github.com/ghoss/Lightroom2Tumblr>

------------------------------------------------------------------------------]]

--------------------------------------------------------------------------------
-- LOCAL CONFIGURATION
--------------------------------------------------------------------------------

-- Version number
majorV = 1
minorV = 2

-- The "Consumer Key" and "Consumer Secret", that Tumblr generated for the app
-- when registered at Tumblr.
function ConsumerSecret()
	-- Enter the value displayed in your Tumblr app settings here
	return "XXXXXX"
end
		
function ConsumerKey()
	-- Enter the value displayed in your Tumblr app settings here
	return "YYYYYY"
end

-- The info URL displayed on the plugin's page in Lightroom
function PluginInfoUrl()
	return 'http://berg.land'
end

-- The OAuth authentication callback URL to your site. This is used to get the
-- access token which must be entered in Lightroom to authorize the plugin to
-- Tumblr.
function TumblrCallbackURL()
	return 'http://berg.land/lr2tumblr.php'
end


--------------------------------------------------------------------------------
-- Tumblr API Definitions
--
-- There is no need to change any of the URLs below, unless Tumblr decides to
-- change its SPI endpoints.
--------------------------------------------------------------------------------

function TumblrRequestTokenURL()
	return 'https://www.tumblr.com/oauth/request_token'
end

function TumblrAuthorizeURL()
	return 'https://www.tumblr.com/oauth/authorize'
end

function TumblrAccessTokenURL()
	return 'https://www.tumblr.com/oauth/access_token'
end

function TumblrApiURL()
	return 'https://api.tumblr.com/v2/blog/'
end

function TumblrApiEndpoint()
	return '.tumblr.com/post'
end
	

--------------------------------------------------------------------------------
-- Return parameters to Lightroom
--------------------------------------------------------------------------------

return {
	LrSdkVersion = 4.0,
	LrSdkMinimumVersion = 2.0,

	LrToolkitIdentifier = 'lr2tumblr',
	LrPluginName = 'Tumblr',
	LrPluginInfoUrl = PluginInfoUrl(),

	LrExportServiceProvider = {
		title = 'Tumblr',
		file = 'TumblrServiceProvider.lua'
	},

	VERSION = { major = majorV, minor = minorV, revision=0, build=0 }
}
